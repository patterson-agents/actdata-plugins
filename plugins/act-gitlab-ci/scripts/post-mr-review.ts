#!/usr/bin/env bun
/**
 * post-mr-review -- run an AI review engine over a merge request and deliver
 * the findings to GitLab.
 *
 * Zero dependencies, node: builtins only, run under bun.
 *
 * Designed to run inside a GitLab CI merge-request pipeline, copied into the
 * target repository (CI cannot resolve plugin paths). The engine produces
 * findings; this script does everything with side effects: it builds the
 * prompt, spawns the engine, validates the output against the findings
 * contract (see review-rubric.md), and posts the review.
 *
 * Modes (AI_REVIEW_MODE, default "inline"):
 *   inline   one positioned discussion per finding + a sticky summary note;
 *            findings whose position GitLab rejects degrade to plain notes
 *   summary  a single sticky summary note
 *   log      job log + artifacts only; the automatic fallback when no
 *            GITLAB_TOKEN is set, because CI_JOB_TOKEN cannot create MR notes
 *
 * Engines (AI_REVIEW_ENGINE, default "docker-agent"):
 *   docker-agent | claude | codex | copilot | custom via AI_REVIEW_ENGINE_CMD
 *
 * The engine subprocess never receives GITLAB_TOKEN: merge-request code is
 * untrusted input to the model, and a prompt-injected engine must have nothing
 * to exfiltrate and no way to post.
 *
 * Sticky semantics: every body this script posts carries an HTML marker with
 * the reviewed head SHA. On re-push it resolves its own stale discussions,
 * posts fresh ones, and updates the summary note in place. A marker matching
 * the current head SHA makes the run a no-op, so pipeline retries are free.
 *
 * Usage:
 *   bun post-mr-review.ts                  # normal CI entry point
 *   bun post-mr-review.ts --extract FILE   # parse engine output, print JSON
 *     [--report]                           # human-readable report instead
 *     [--blocking]                         # exit 1 when blockers found
 *
 * Exit: 0 review delivered (or nothing to do), 1 engine/contract failure,
 *       2 configuration error. Never nonzero for findings alone unless
 *       --blocking asked for it.
 */

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

// ---------------------------------------------------------------------------
// Findings contract
// ---------------------------------------------------------------------------

export type Severity = "blocker" | "warning" | "nit";

export interface Finding {
  path: string;
  new_line: number | null;
  old_line: number | null;
  severity: Severity;
  title: string;
  body: string;
}

export interface Review {
  summary: string;
  findings: Finding[];
}

const SEVERITIES: readonly string[] = ["blocker", "warning", "nit"];

export function validateReview(value: unknown): { review: Review | null; errors: string[] } {
  const errors: string[] = [];
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return { review: null, errors: ["not an object"] };
  }
  const obj = value as Record<string, unknown>;
  if (typeof obj.summary !== "string" || obj.summary.length === 0) {
    errors.push("summary: required string");
  }
  if (!Array.isArray(obj.findings)) {
    errors.push("findings: required array");
    return { review: null, errors };
  }
  const findings: Finding[] = [];
  obj.findings.forEach((raw, i) => {
    if (typeof raw !== "object" || raw === null) {
      errors.push(`findings[${i}]: not an object`);
      return;
    }
    const f = raw as Record<string, unknown>;
    const where = `findings[${i}]`;
    if (typeof f.path !== "string" || f.path.length === 0) errors.push(`${where}.path: required string`);
    if (typeof f.title !== "string" || f.title.length === 0) errors.push(`${where}.title: required string`);
    if (typeof f.body !== "string" || f.body.length === 0) errors.push(`${where}.body: required string`);
    if (!SEVERITIES.includes(f.severity as string)) errors.push(`${where}.severity: must be blocker|warning|nit`);
    const newLine = f.new_line === undefined || f.new_line === null ? null : f.new_line;
    const oldLine = f.old_line === undefined || f.old_line === null ? null : f.old_line;
    if (newLine !== null && (typeof newLine !== "number" || !Number.isInteger(newLine) || newLine < 1)) {
      errors.push(`${where}.new_line: must be a positive integer or null`);
    }
    if (oldLine !== null && (typeof oldLine !== "number" || !Number.isInteger(oldLine) || oldLine < 1)) {
      errors.push(`${where}.old_line: must be a positive integer or null`);
    }
    if (newLine === null && oldLine === null) {
      errors.push(`${where}: needs new_line (or old_line for a deletion)`);
    }
    findings.push({
      path: String(f.path),
      new_line: newLine as number | null,
      old_line: oldLine as number | null,
      severity: f.severity as Severity,
      title: String(f.title),
      body: String(f.body),
    });
  });
  if (errors.length > 0) return { review: null, errors };
  return { review: { summary: String(obj.summary), findings }, errors: [] };
}

/**
 * Pull a Review out of whatever an engine printed.
 *
 * Engines differ: docker-agent --json emits newline-delimited events, claude
 * --output-format json wraps its answer in a result object, others print
 * prose around a fenced JSON block. Try, in order: the whole text as JSON,
 * each ndjson line, fenced ```json blocks, and the outermost brace slice.
 * String fields of intermediate objects are searched recursively, and the
 * LAST valid candidate wins (later events supersede earlier ones).
 */
export function extractReview(raw: string, depth = 0): Review | null {
  if (depth > 4 || raw.length === 0) return null;
  let last: Review | null = null;

  const consider = (candidate: unknown): void => {
    const direct = validateReview(candidate).review;
    if (direct) {
      last = direct;
      return;
    }
    if (typeof candidate === "object" && candidate !== null) {
      for (const v of Object.values(candidate as Record<string, unknown>)) {
        if (typeof v === "string" && v.includes("{")) {
          const nested = extractReview(v, depth + 1);
          if (nested) last = nested;
        } else if (typeof v === "object" && v !== null) {
          consider(v);
        }
      }
    }
  };

  const tryParse = (text: string): void => {
    try {
      consider(JSON.parse(text));
    } catch {
      /* not JSON; other strategies below */
    }
  };

  tryParse(raw.trim());
  if (last) return last;

  for (const line of raw.split("\n")) {
    const t = line.trim();
    if (t.startsWith("{") && t.endsWith("}")) tryParse(t);
  }
  if (last) return last;

  for (const m of raw.matchAll(/```(?:json)?\s*\n([\s\S]*?)```/g)) {
    tryParse(m[1].trim());
  }
  if (last) return last;

  const first = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (first !== -1 && end > first) tryParse(raw.slice(first, end + 1));

  return last;
}

// ---------------------------------------------------------------------------
// Mode and engine resolution
// ---------------------------------------------------------------------------

export type Mode = "inline" | "summary" | "log";

export function resolveMode(requested: string | undefined, hasToken: boolean): { mode: Mode; downgraded: boolean } {
  const wanted = (requested || "inline").toLowerCase();
  if (wanted !== "inline" && wanted !== "summary" && wanted !== "log") {
    // A typo must not silently escalate to the most-privileged posting mode.
    throw new Error(`unknown AI_REVIEW_MODE "${requested}" (inline|summary|log)`);
  }
  const mode = wanted as Mode;
  if (mode !== "log" && !hasToken) return { mode: "log", downgraded: true };
  return { mode, downgraded: false };
}

export interface EngineSpec {
  argv: string[];
  promptVia: "stdin" | "arg";
}

/**
 * The engine allowlist. docker-agent and claude are the tested pair; codex
 * and copilot are best-effort (their headless flags move fast -- verify with
 * `codex exec --help` / `copilot --help` and override with
 * AI_REVIEW_ENGINE_CMD when they drift).
 */
export function engineSpec(engine: string, env: Record<string, string | undefined>): EngineSpec {
  const custom = env.AI_REVIEW_ENGINE_CMD;
  if (custom && custom.trim().length > 0) {
    // Through a shell, same as ai-review.sh, so pipes and quoting behave
    // identically on both surfaces.
    return { argv: ["sh", "-c", custom.trim()], promptVia: "stdin" };
  }
  const maxTurns = env.AI_REVIEW_MAX_TURNS || "25";
  const config = env.AI_REVIEW_AGENT_CONFIG || ".gitlab/ai-review/review-agent.yaml";
  const safety = env.AI_REVIEW_ENGINE_FLAGS || "--safety restricted";
  switch (engine) {
    case "claude":
      return {
        argv: ["claude", "-p", "--output-format", "json", "--max-turns", maxTurns, "--allowedTools", "Read Grep Glob"],
        promptVia: "stdin",
      };
    case "codex":
      return { argv: ["codex", "exec", "--json"], promptVia: "stdin" };
    case "copilot":
      return { argv: ["copilot", "-p"], promptVia: "arg" };
    case "docker-agent":
      return {
        argv: ["docker-agent", "run", "--exec", config, "--json", ...safety.split(/\s+/), "-"],
        promptVia: "stdin",
      };
    default:
      throw new Error(`unknown AI_REVIEW_ENGINE "${engine}" (docker-agent|claude|codex|copilot)`);
  }
}

// ---------------------------------------------------------------------------
// Diff handling
// ---------------------------------------------------------------------------

export interface FileDiff {
  old_path: string;
  new_path: string;
  diff: string;
}

export function truncateDiff(
  files: FileDiff[],
  maxFileLines: number,
  maxTotalLines: number,
): { text: string; truncated: string[] } {
  const truncated: string[] = [];
  const parts: string[] = [];
  let total = 0;
  for (const f of files) {
    if (total >= maxTotalLines) {
      truncated.push(f.new_path);
      continue;
    }
    const header = `diff --git a/${f.old_path} b/${f.new_path}\n--- a/${f.old_path}\n+++ b/${f.new_path}`;
    const lines = f.diff.split("\n");
    let body = f.diff;
    if (lines.length > maxFileLines) {
      body = lines.slice(0, maxFileLines).join("\n");
      truncated.push(f.new_path);
    }
    const bodyLines = Math.min(lines.length, maxFileLines);
    if (total + bodyLines > maxTotalLines) {
      body = lines.slice(0, maxTotalLines - total).join("\n");
      truncated.push(f.new_path);
    }
    total += body.split("\n").length;
    parts.push(`${header}\n${body}`);
  }
  return { text: parts.join("\n"), truncated: [...new Set(truncated)] };
}

export function buildPrompt(
  rubric: string,
  mr: { title: string; description: string },
  diffText: string,
  truncated: string[],
): string {
  const note =
    truncated.length > 0
      ? `\nNote: the following files were truncated or omitted for size; say so in the summary: ${truncated.join(", ")}\n`
      : "";
  return [
    rubric.trim(),
    "",
    "Respond with ONLY the findings-contract JSON object. No prose before or after it.",
    note,
    `Merge request title: ${mr.title}`,
    `Merge request description:\n${mr.description || "(none)"}`,
    "",
    "Diff under review:",
    "```diff",
    diffText,
    "```",
  ].join("\n");
}

// ---------------------------------------------------------------------------
// Rendering and sticky markers
// ---------------------------------------------------------------------------

// The kind matters: summary notes and per-finding fallback notes both carry a
// marker, and GitLab lists notes newest-first. Matching on sha alone would let
// the newest fallback note be mistaken for the summary and get overwritten.
export type MarkerKind = "summary" | "finding";

const MARKER_RE = /<!-- act-gitlab-ci:mr-review sha=([0-9a-f]{7,40})(?: kind=([a-z]+))? -->/;

export function marker(sha: string, kind: MarkerKind): string {
  return `<!-- act-gitlab-ci:mr-review sha=${sha} kind=${kind} -->`;
}

export function markerShaOf(body: string): string | null {
  const m = body.match(MARKER_RE);
  return m ? m[1] : null;
}

export function markerKindOf(body: string): string | null {
  const m = body.match(MARKER_RE);
  return m ? m[2] || null : null;
}

const SEVERITY_LABEL: Record<Severity, string> = {
  blocker: "Blocker",
  warning: "Warning",
  nit: "Nit",
};

export function renderFinding(f: Finding, sha: string): string {
  return `**[${SEVERITY_LABEL[f.severity]}]** ${f.title}\n\n${f.body}\n\n${marker(sha, "finding")}`;
}

export function renderFallbackNote(f: Finding, sha: string): string {
  const line = f.new_line !== null ? f.new_line : f.old_line;
  return `**[${SEVERITY_LABEL[f.severity]}]** \`${f.path}:${line}\` -- ${f.title}\n\n${f.body}\n\n${marker(sha, "finding")}`;
}

export function renderSummary(review: Review, truncated: string[], sha: string): string {
  const counts: Record<Severity, number> = { blocker: 0, warning: 0, nit: 0 };
  for (const f of review.findings) counts[f.severity] += 1;
  const lines: string[] = ["## Automated code review", ""];
  if (review.findings.length === 0) {
    lines.push("No findings. " + review.summary);
  } else {
    lines.push(review.summary, "");
    lines.push(`| Severity | Count |`, `|---|---|`);
    (Object.keys(counts) as Severity[]).forEach((s) => {
      if (counts[s] > 0) lines.push(`| ${SEVERITY_LABEL[s]} | ${counts[s]} |`);
    });
    lines.push("", "| Finding | Location |", "|---|---|");
    for (const f of review.findings) {
      const line = f.new_line !== null ? f.new_line : f.old_line;
      lines.push(`| [${SEVERITY_LABEL[f.severity]}] ${f.title.replaceAll("|", "\\|")} | \`${f.path}:${line}\` |`);
    }
  }
  if (truncated.length > 0) {
    lines.push("", `Truncated for size and reviewed partially or not at all: ${truncated.map((t) => `\`${t}\``).join(", ")}`);
  }
  lines.push("", `Reviewed commit ${sha.slice(0, 12)}. Generated review; verify findings before acting on them.`, "", marker(sha, "summary"));
  return lines.join("\n");
}

export function renderReport(review: Review): string {
  const lines: string[] = [review.summary, ""];
  for (const f of review.findings) {
    const line = f.new_line !== null ? f.new_line : f.old_line;
    lines.push(`[${f.severity.toUpperCase()}] ${f.path}:${line} ${f.title}`);
    lines.push(`  ${f.body.replaceAll("\n", "\n  ")}`, "");
  }
  if (review.findings.length === 0) lines.push("No findings.");
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Action planning
// ---------------------------------------------------------------------------

export interface DiffRefs {
  base_sha: string;
  head_sha: string;
  start_sha: string;
}

export interface ExistingNote {
  id: number;
  body: string;
}

export interface ExistingDiscussion {
  id: string;
  resolved: boolean;
  body: string;
}

export type Action =
  | { type: "resolve_discussion"; discussion_id: string }
  | { type: "create_discussion"; body: string; position: Record<string, unknown>; fallback_body: string }
  | { type: "create_note"; body: string }
  | { type: "update_note"; note_id: number; body: string };

export function positionFor(f: Finding, refs: DiffRefs): Record<string, unknown> {
  const position: Record<string, unknown> = {
    position_type: "text",
    base_sha: refs.base_sha,
    head_sha: refs.head_sha,
    start_sha: refs.start_sha,
    new_path: f.path,
    old_path: f.path,
  };
  if (f.new_line !== null) position.new_line = f.new_line;
  if (f.old_line !== null) position.old_line = f.old_line;
  return position;
}

export interface PlanContext {
  mode: Mode;
  headSha: string;
  diffRefs: DiffRefs | null;
  truncated: string[];
  existingNotes: ExistingNote[];
  existingDiscussions: ExistingDiscussion[];
}

export function planActions(review: Review, ctx: PlanContext): Action[] {
  if (ctx.mode === "log") return [];
  const actions: Action[] = [];

  if (ctx.mode === "inline") {
    for (const d of ctx.existingDiscussions) {
      const sha = markerShaOf(d.body);
      if (sha !== null && sha !== ctx.headSha && !d.resolved) {
        actions.push({ type: "resolve_discussion", discussion_id: d.id });
      }
    }
    if (ctx.diffRefs) {
      for (const f of review.findings) {
        actions.push({
          type: "create_discussion",
          body: renderFinding(f, ctx.headSha),
          position: positionFor(f, ctx.diffRefs),
          fallback_body: renderFallbackNote(f, ctx.headSha),
        });
      }
    }
  }

  const summaryBody = renderSummary(review, ctx.truncated, ctx.headSha);
  const existing = ctx.existingNotes.find((n) => markerKindOf(n.body) === "summary");
  if (existing) {
    actions.push({ type: "update_note", note_id: existing.id, body: summaryBody });
  } else {
    actions.push({ type: "create_note", body: summaryBody });
  }
  return actions;
}

// ---------------------------------------------------------------------------
// GitLab API execution (injected for tests)
// ---------------------------------------------------------------------------

export interface HttpResponse {
  status: number;
  body: unknown;
}

export type HttpFn = (method: string, path: string, payload?: unknown) => Promise<HttpResponse>;

export async function executeActions(actions: Action[], http: HttpFn): Promise<{ posted: number; fallbacks: number }> {
  let posted = 0;
  let fallbacks = 0;
  for (const a of actions) {
    switch (a.type) {
      case "resolve_discussion":
        await http("PUT", `/discussions/${a.discussion_id}`, { resolved: true });
        break;
      case "create_discussion": {
        const res = await http("POST", "/discussions", { body: a.body, position: a.position });
        if (res.status >= 200 && res.status < 300) {
          posted += 1;
        } else if (res.status === 400) {
          // GitLab rejects positions it cannot map onto the diff (context
          // lines, renames, and similar). Deliver the finding as a plain
          // note rather than dropping it.
          await http("POST", "/notes", { body: a.fallback_body });
          fallbacks += 1;
        } else {
          throw new Error(`create_discussion failed with HTTP ${res.status}`);
        }
        break;
      }
      case "create_note":
        await http("POST", "/notes", { body: a.body });
        break;
      case "update_note":
        await http("PUT", `/notes/${a.note_id}`, { body: a.body });
        break;
    }
  }
  return { posted, fallbacks };
}

function gitlabHttp(env: Record<string, string | undefined>): HttpFn {
  const base = `${env.CI_API_V4_URL}/projects/${encodeURIComponent(env.CI_PROJECT_ID as string)}/merge_requests/${env.CI_MERGE_REQUEST_IID}`;
  const token = env.GITLAB_TOKEN as string;
  return async (method, path, payload) => {
    const res = await fetch(`${base}${path}`, {
      method,
      headers: { "PRIVATE-TOKEN": token, "Content-Type": "application/json" },
      body: payload === undefined ? undefined : JSON.stringify(payload),
    });
    let body: unknown = null;
    try {
      body = await res.json();
    } catch {
      body = null;
    }
    return { status: res.status, body };
  };
}

// ---------------------------------------------------------------------------
// CI entry point
// ---------------------------------------------------------------------------

function fail(message: string, code: 1 | 2): never {
  console.error(`post-mr-review: ${message}`);
  process.exit(code);
}

function readJsonFile(path: string): unknown {
  return JSON.parse(readFileSync(path, "utf8"));
}

/**
 * The environment an engine subprocess may see. No GitLab token of any kind:
 * the engine processes untrusted MR content, and posting is this script's
 * job. The rest of the job environment (provider key included) necessarily
 * remains reachable.
 */
export function engineChildEnv(env: Record<string, string | undefined>): Record<string, string> {
  const STRIPPED = ["GITLAB_TOKEN", "GITLAB_ACCESS_TOKEN", "CI_JOB_TOKEN"];
  const childEnv: Record<string, string> = {};
  for (const [k, v] of Object.entries(env)) {
    if (v !== undefined && !STRIPPED.includes(k)) childEnv[k] = v;
  }
  childEnv.TELEMETRY_ENABLED = childEnv.TELEMETRY_ENABLED || "false";
  return childEnv;
}

// Linux caps a single argv element at 128 KiB (MAX_ARG_STRLEN). Prompts ride
// argv only for engines with no stdin mode; refuse before the kernel does.
const MAX_ARG_PROMPT_BYTES = 120_000;

function runEngine(spec: EngineSpec, prompt: string, env: Record<string, string | undefined>): string {
  const childEnv = engineChildEnv(env);
  const argv = [...spec.argv];
  if (spec.promptVia === "arg") {
    if (Buffer.byteLength(prompt, "utf8") > MAX_ARG_PROMPT_BYTES) {
      fail(
        `the prompt (${Buffer.byteLength(prompt, "utf8")} bytes) exceeds the OS argument limit for this ` +
          `engine; lower AI_REVIEW_MAX_DIFF_LINES or use AI_REVIEW_ENGINE_CMD with a stdin-reading command`,
        2,
      );
    }
    argv.push(prompt);
  }
  const result = spawnSync(argv[0], argv.slice(1), {
    input: spec.promptVia === "stdin" ? prompt : undefined,
    env: childEnv,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.error) fail(`could not run engine "${argv[0]}": ${result.error.message}`, 1);
  const out = `${result.stdout || ""}\n${result.stderr || ""}`;
  if (typeof result.status === "number" && result.status !== 0 && !extractReview(result.stdout || "")) {
    console.error(out);
    fail(`engine exited ${result.status} without usable output`, 1);
  }
  return result.stdout || "";
}

function localDiff(baseSha: string): FileDiff[] {
  const result = spawnSync("git", ["diff", "--no-color", `${baseSha}...HEAD`], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0) {
    fail(`git diff against ${baseSha} failed (shallow clone? set GIT_DEPTH: "0"): ${result.stderr}`, 2);
  }
  return parseGitDiff(result.stdout || "");
}

/**
 * Split a raw `git diff` back into per-file chunks so truncation budgets
 * apply per file, same as the API path. The body starts at the first hunk:
 * truncateDiff() adds its own header lines, so keeping git's index/---/+++
 * metadata would duplicate them in the prompt. Paths that git quotes
 * (spaces, non-ASCII) do not match and are skipped -- a documented
 * limitation of tokenless mode.
 */
export function parseGitDiff(raw: string): FileDiff[] {
  const files: FileDiff[] = [];
  for (const chunk of raw.split(/^diff --git /m).slice(1)) {
    const m = chunk.match(/^a\/(\S+) b\/(\S+)/);
    if (!m) continue;
    const lines = chunk.split("\n").slice(1);
    const hunkStart = lines.findIndex((l) => l.startsWith("@@"));
    const body = (hunkStart === -1 ? lines : lines.slice(hunkStart)).join("\n");
    files.push({ old_path: m[1], new_path: m[2], diff: body });
  }
  return files;
}

async function main(): Promise<void> {
  const env = process.env;
  const dryRun = env.AI_REVIEW_DRY_RUN === "1";
  const artifactsDir = env.AI_REVIEW_ARTIFACTS || "ai-review-artifacts";
  const hasToken = Boolean(env.GITLAB_TOKEN);
  let resolved: { mode: Mode; downgraded: boolean };
  try {
    resolved = resolveMode(env.AI_REVIEW_MODE, hasToken);
  } catch (err) {
    fail(err instanceof Error ? err.message : String(err), 2);
  }
  const { mode, downgraded } = resolved;
  if (downgraded) {
    console.error(
      `post-mr-review: AI_REVIEW_MODE=${env.AI_REVIEW_MODE || "inline"} requires GITLAB_TOKEN ` +
        `(CI_JOB_TOKEN cannot create MR notes); falling back to log mode.`,
    );
  }

  const iid = env.CI_MERGE_REQUEST_IID;
  if (!iid && !dryRun) fail("not a merge request pipeline (CI_MERGE_REQUEST_IID unset)", 2);

  const headSha = env.CI_MERGE_REQUEST_SOURCE_BRANCH_SHA || env.CI_COMMIT_SHA || "unknown";
  const http: HttpFn = dryRun
    ? async (method, path, payload) => {
        console.log(JSON.stringify({ planned: { method, path, payload } }));
        return { status: 200, body: null };
      }
    : gitlabHttp(env);

  // Gather MR state (token modes only).
  let diffRefs: DiffRefs | null = null;
  let files: FileDiff[] = [];
  let mrTitle = env.CI_MERGE_REQUEST_TITLE || "";
  let mrDescription = env.CI_MERGE_REQUEST_DESCRIPTION || "";
  let existingNotes: ExistingNote[] = [];
  let existingDiscussions: ExistingDiscussion[] = [];

  if (mode !== "log") {
    const mrRaw = dryRun && env.AI_REVIEW_FIXTURE_CHANGES
      ? readJsonFile(env.AI_REVIEW_FIXTURE_CHANGES)
      : (await http("GET", "/changes")).body;
    const mr = (mrRaw || {}) as {
      title?: string;
      description?: string;
      draft?: boolean;
      work_in_progress?: boolean;
      diff_refs?: DiffRefs;
      changes?: FileDiff[];
    };
    if (mr.draft === true || mr.work_in_progress === true) {
      console.log("post-mr-review: draft merge request, skipping review.");
      return;
    }
    mrTitle = mr.title || mrTitle;
    mrDescription = mr.description || mrDescription;
    diffRefs = mr.diff_refs || null;
    files = mr.changes || [];

    const notesRaw = dryRun && env.AI_REVIEW_FIXTURE_NOTES
      ? readJsonFile(env.AI_REVIEW_FIXTURE_NOTES)
      : (await http("GET", "/notes?per_page=100")).body;
    existingNotes = ((notesRaw as { id: number; body: string }[]) || []).map((n) => ({ id: n.id, body: n.body }));

    const discussionsRaw = dryRun && env.AI_REVIEW_FIXTURE_DISCUSSIONS
      ? readJsonFile(env.AI_REVIEW_FIXTURE_DISCUSSIONS)
      : (await http("GET", "/discussions?per_page=100")).body;
    existingDiscussions = ((discussionsRaw as { id: string; notes?: { body: string; resolved?: boolean }[] }[]) || [])
      .filter((d) => (d.notes || []).length > 0)
      .map((d) => ({
        id: d.id,
        resolved: Boolean(d.notes && d.notes[0].resolved),
        body: d.notes && d.notes[0] ? d.notes[0].body : "",
      }));

    // Same head already reviewed: a pipeline retry, not a new push.
    const summaryNote = existingNotes.find((n) => markerKindOf(n.body) === "summary");
    if (summaryNote && markerShaOf(summaryNote.body) === headSha) {
      console.log(`post-mr-review: head ${headSha.slice(0, 12)} already reviewed, nothing to do.`);
      return;
    }
  } else {
    const baseSha = env.CI_MERGE_REQUEST_DIFF_BASE_SHA;
    if (!baseSha && !dryRun) fail("log mode needs CI_MERGE_REQUEST_DIFF_BASE_SHA for a local diff", 2);
    if (baseSha) files = localDiff(baseSha);
  }

  const maxFileLines = Number(env.AI_REVIEW_MAX_FILE_LINES || 1500);
  const maxTotalLines = Number(env.AI_REVIEW_MAX_DIFF_LINES || 6000);
  const { text: diffText, truncated } = truncateDiff(files, maxFileLines, maxTotalLines);
  if (diffText.trim().length === 0 && !env.AI_REVIEW_FIXTURE_OUTPUT) {
    console.log("post-mr-review: empty diff, nothing to review.");
    return;
  }

  const rubricPath = env.AI_REVIEW_RUBRIC || ".gitlab/ai-review/review-rubric.md";
  let rubric = "";
  try {
    rubric = readFileSync(rubricPath, "utf8");
  } catch {
    // A saved engine output makes the prompt (and so the rubric) unused.
    if (!env.AI_REVIEW_FIXTURE_OUTPUT) fail(`rubric not found at ${rubricPath}`, 2);
  }
  const prompt = buildPrompt(rubric, { title: mrTitle, description: mrDescription }, diffText, truncated);

  mkdirSync(artifactsDir, { recursive: true });
  let rawOutput: string;
  if (env.AI_REVIEW_FIXTURE_OUTPUT) {
    rawOutput = readFileSync(env.AI_REVIEW_FIXTURE_OUTPUT, "utf8");
  } else {
    const engine = env.AI_REVIEW_ENGINE || "docker-agent";
    let spec: EngineSpec;
    try {
      spec = engineSpec(engine, env);
    } catch (err) {
      // A typo'd engine is a configuration error, same as a typo'd mode.
      fail(err instanceof Error ? err.message : String(err), 2);
    }
    rawOutput = runEngine(spec, prompt, env);
  }
  writeFileSync(join(artifactsDir, "transcript.ndjson"), rawOutput);

  const review = extractReview(rawOutput);
  if (!review) {
    fail("engine output did not contain a valid findings-contract object (transcript saved to artifacts)", 1);
  }
  writeFileSync(join(artifactsDir, "findings.json"), JSON.stringify(review, null, 2));
  writeFileSync(join(artifactsDir, "review.md"), renderSummary(review, truncated, headSha));

  if (mode === "log") {
    console.log(renderReport(review));
    return;
  }

  const actions = planActions(review, {
    mode,
    headSha,
    diffRefs,
    truncated,
    existingNotes,
    existingDiscussions,
  });
  const { posted, fallbacks } = await executeActions(actions, http);
  console.log(
    `post-mr-review: delivered ${review.findings.length} finding(s) in ${mode} mode` +
      (mode === "inline" ? ` (${posted} positioned, ${fallbacks} as plain notes)` : "") +
      ".",
  );
}

// ---------------------------------------------------------------------------
// --extract: parse a saved engine output file (used by ai-review.sh)
// ---------------------------------------------------------------------------

function extractCli(args: string[]): void {
  const file = args.find((a) => !a.startsWith("--"));
  if (!file) fail("--extract needs a file argument", 2);
  const review = extractReview(readFileSync(file, "utf8"));
  if (!review) fail("no valid findings-contract object in engine output", 1);
  if (args.includes("--report")) {
    console.log(renderReport(review));
  } else {
    console.log(JSON.stringify(review, null, 2));
  }
  if (args.includes("--blocking") && review.findings.some((f) => f.severity === "blocker")) {
    process.exit(1);
  }
}

if (import.meta.main) {
  const args = process.argv.slice(2);
  if (args[0] === "--extract") {
    extractCli(args.slice(1));
  } else {
    main().catch((err) => fail(err instanceof Error ? err.message : String(err), 1));
  }
}
