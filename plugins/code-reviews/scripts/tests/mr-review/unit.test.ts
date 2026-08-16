/**
 * Unit tests for post-mr-review.ts pure functions. No network, no engines:
 * everything runs against fixtures and injected stubs. run-tests.sh drives
 * this file with `bun test` and covers the CLI surface separately.
 */

import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  type Action,
  type DiffRefs,
  type Finding,
  buildPrompt,
  engineChildEnv,
  engineSpec,
  executeActions,
  extractReview,
  markerKindOf,
  markerShaOf,
  parseGitDiff,
  planActions,
  positionFor,
  renderSummary,
  resolveMode,
  truncateDiff,
  validateReview,
} from "../../post-mr-review.ts";

const FIXTURES = join(import.meta.dir, "fixtures");
const fixture = (name: string): string => readFileSync(join(FIXTURES, name), "utf8");

const REFS: DiffRefs = {
  base_sha: "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678",
  head_sha: "beefbeefbeefbeefbeefbeefbeefbeefbeefbeef",
  start_sha: "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678",
};

describe("extractReview", () => {
  test("parses a bare findings-contract object", () => {
    const review = extractReview('{"summary":"ok","findings":[]}');
    expect(review).not.toBeNull();
    expect(review!.findings).toHaveLength(0);
  });

  test("finds structured output nested in a docker-agent ndjson stream", () => {
    const review = extractReview(fixture("transcript.ndjson"));
    expect(review).not.toBeNull();
    expect(review!.findings).toHaveLength(2);
    expect(review!.findings[0].severity).toBe("blocker");
    expect(review!.findings[1].old_line).toBe(17);
  });

  test("unwraps a claude --output-format json result", () => {
    const review = extractReview(fixture("claude-output.json"));
    expect(review).not.toBeNull();
    expect(review!.findings[0].path).toBe("src/queue/retry.ts");
  });

  test("reads a fenced json block inside prose", () => {
    const raw = 'Here is the review:\n```json\n{"summary":"clean","findings":[]}\n```\nDone.';
    expect(extractReview(raw)).not.toBeNull();
  });

  test("returns null for a malformed transcript", () => {
    expect(extractReview(fixture("transcript-malformed.ndjson"))).toBeNull();
  });
});

describe("validateReview", () => {
  test("rejects an unknown severity", () => {
    const { review, errors } = validateReview({
      summary: "s",
      findings: [{ path: "a.ts", new_line: 1, old_line: null, severity: "critical", title: "t", body: "b" }],
    });
    expect(review).toBeNull();
    expect(errors.join(" ")).toContain("severity");
  });

  test("rejects a finding with neither line", () => {
    const { review } = validateReview({
      summary: "s",
      findings: [{ path: "a.ts", new_line: null, old_line: null, severity: "nit", title: "t", body: "b" }],
    });
    expect(review).toBeNull();
  });

  test("accepts an empty findings array as a clean review", () => {
    expect(validateReview({ summary: "clean", findings: [] }).review).not.toBeNull();
  });
});

describe("resolveMode", () => {
  test("keeps inline when a token is present", () => {
    expect(resolveMode("inline", true)).toEqual({ mode: "inline", downgraded: false });
  });
  test("downgrades comment modes to log without a token", () => {
    expect(resolveMode("inline", false)).toEqual({ mode: "log", downgraded: true });
    expect(resolveMode("summary", false)).toEqual({ mode: "log", downgraded: true });
  });
  test("log mode never needs a token", () => {
    expect(resolveMode("log", false)).toEqual({ mode: "log", downgraded: false });
  });
  test("defaults to inline", () => {
    expect(resolveMode(undefined, true).mode).toBe("inline");
  });
  test("rejects unknown modes instead of escalating to inline", () => {
    expect(() => resolveMode("summry", true)).toThrow("unknown CODEREVIEW_MODE");
  });
});

describe("engineSpec", () => {
  test("each named engine produces its documented argv shape", () => {
    expect(engineSpec("docker-agent", {}).argv).toEqual([
      "docker-agent", "run", "--exec", ".gitlab/codereview/review-agent.yaml", "--json", "--safety", "restricted", "-",
    ]);
    expect(engineSpec("claude", {}).argv).toEqual([
      "claude", "-p", "--output-format", "json", "--max-turns", "25", "--allowedTools", "Read Grep Glob",
    ]);
    expect(engineSpec("codex", {}).argv).toEqual(["codex", "exec", "--json"]);
    expect(engineSpec("copilot", {})).toEqual({ argv: ["copilot", "-p"], promptVia: "arg" });
  });

  test("CODEREVIEW_ENGINE_CMD runs through a shell, matching codereview.sh", () => {
    const spec = engineSpec("docker-agent", { CODEREVIEW_ENGINE_CMD: "my-engine --flag 'quoted arg'" });
    expect(spec.argv).toEqual(["sh", "-c", "my-engine --flag 'quoted arg'"]);
    expect(spec.promptVia).toBe("stdin");
  });

  test("a whitespace-only override falls back to the named engine", () => {
    expect(engineSpec("codex", { CODEREVIEW_ENGINE_CMD: "   " }).argv[0]).toBe("codex");
  });

  test("an unknown engine throws instead of guessing", () => {
    expect(() => engineSpec("gpt", {})).toThrow("unknown CODEREVIEW_ENGINE");
  });
});

describe("engineChildEnv", () => {
  test("strips every GitLab token and keeps the rest", () => {
    const child = engineChildEnv({
      GITLAB_TOKEN: "secret",
      GITLAB_ACCESS_TOKEN: "secret2",
      CI_JOB_TOKEN: "secret3",
      ANTHROPIC_API_KEY: "provider-key",
      CI_PROJECT_ID: "123",
    });
    expect(child.GITLAB_TOKEN).toBeUndefined();
    expect(child.GITLAB_ACCESS_TOKEN).toBeUndefined();
    expect(child.CI_JOB_TOKEN).toBeUndefined();
    // Positive controls: stripping must not mean "empty env".
    expect(child.ANTHROPIC_API_KEY).toBe("provider-key");
    expect(child.CI_PROJECT_ID).toBe("123");
  });

  test("telemetry defaults off and an explicit value wins", () => {
    expect(engineChildEnv({}).TELEMETRY_ENABLED).toBe("false");
    expect(engineChildEnv({ TELEMETRY_ENABLED: "true" }).TELEMETRY_ENABLED).toBe("true");
  });
});

describe("parseGitDiff", () => {
  const raw = [
    "diff --git a/src/app.ts b/src/app.ts",
    "index 1111111..2222222 100644",
    "--- a/src/app.ts",
    "+++ b/src/app.ts",
    "@@ -1,2 +1,2 @@",
    "-old",
    "+new",
    'diff --git "a/with space.ts" "b/with space.ts"',
    "@@ -1 +1 @@",
    "+x",
  ].join("\n");

  test("bodies start at the first hunk so truncateDiff headers are not duplicated", () => {
    const files = parseGitDiff(raw);
    expect(files).toHaveLength(1);
    expect(files[0].new_path).toBe("src/app.ts");
    expect(files[0].diff.startsWith("@@")).toBe(true);
    expect(files[0].diff).not.toContain("+++ b/");
  });

  test("quoted paths are skipped, not mangled", () => {
    expect(parseGitDiff(raw).some((f) => f.new_path.includes("space"))).toBe(false);
  });
});

describe("buildPrompt", () => {
  test("names truncated files so a partial review cannot pose as a full one", () => {
    const prompt = buildPrompt("RUBRIC", { title: "t", description: "d" }, "+x", ["big.ts"]);
    expect(prompt).toContain("truncated or omitted for size");
    expect(prompt).toContain("big.ts");
  });
  test("carries no truncation note when nothing was cut", () => {
    expect(buildPrompt("RUBRIC", { title: "t", description: "d" }, "+x", [])).not.toContain("truncated or omitted");
  });
});

describe("truncateDiff", () => {
  const file = (path: string, lines: number) => ({
    old_path: path,
    new_path: path,
    diff: Array.from({ length: lines }, (_, i) => `+line ${i}`).join("\n"),
  });

  test("keeps small diffs whole", () => {
    const { text, truncated } = truncateDiff([file("a.ts", 10)], 100, 1000);
    expect(truncated).toHaveLength(0);
    expect(text).toContain("+line 9");
  });

  test("caps a single oversized file and reports it", () => {
    const { text, truncated } = truncateDiff([file("big.ts", 500)], 100, 1000);
    expect(truncated).toEqual(["big.ts"]);
    expect(text).not.toContain("+line 400");
  });

  test("drops files past the total budget and reports them", () => {
    const { truncated } = truncateDiff([file("a.ts", 900), file("b.ts", 900)], 1000, 1000);
    expect(truncated).toContain("b.ts");
  });
});

describe("positions and markers", () => {
  const added: Finding = { path: "a.ts", new_line: 42, old_line: null, severity: "blocker", title: "t", body: "b" };
  const deleted: Finding = { path: "d.ts", new_line: null, old_line: 17, severity: "warning", title: "t", body: "b" };

  test("an added line maps to new_line only", () => {
    const p = positionFor(added, REFS);
    expect(p.new_line).toBe(42);
    expect(p.old_line).toBeUndefined();
    expect(p.base_sha).toBe(REFS.base_sha);
  });

  test("a deleted line maps to old_line only", () => {
    const p = positionFor(deleted, REFS);
    expect(p.old_line).toBe(17);
    expect(p.new_line).toBeUndefined();
  });

  test("the summary carries a typed marker the parser reads back", () => {
    const body = renderSummary({ summary: "s", findings: [] }, [], REFS.head_sha);
    expect(markerShaOf(body)).toBe(REFS.head_sha);
    expect(markerKindOf(body)).toBe("summary");
  });

  test("markers without a kind still yield their sha", () => {
    expect(markerShaOf("<!-- code-reviews:mr-review sha=abc123abc123 -->")).toBe("abc123abc123");
    expect(markerKindOf("<!-- code-reviews:mr-review sha=abc123abc123 -->")).toBeNull();
  });
});

describe("planActions", () => {
  const review = {
    summary: "s",
    findings: [
      { path: "a.ts", new_line: 1, old_line: null, severity: "blocker", title: "t1", body: "b1" },
      { path: "b.ts", new_line: 2, old_line: null, severity: "nit", title: "t2", body: "b2" },
    ] as Finding[],
  };
  const notesWithMarker = JSON.parse(fixture("notes-with-marker.json")) as { id: number; body: string }[];
  const staleDiscussions = (JSON.parse(fixture("discussions-stale.json")) as {
    id: string;
    notes: { body: string; resolved: boolean }[];
  }[]).map((d) => ({ id: d.id, resolved: d.notes[0].resolved, body: d.notes[0].body }));

  const ctx = {
    headSha: REFS.head_sha,
    diffRefs: REFS,
    truncated: [] as string[],
    existingNotes: notesWithMarker,
    existingDiscussions: staleDiscussions,
  };

  test("inline: resolves stale bot threads before posting, then updates the sticky note", () => {
    const actions = planActions(review, { ...ctx, mode: "inline" });
    const types = actions.map((a) => a.type);
    expect(types).toEqual(["resolve_discussion", "create_discussion", "create_discussion", "update_note"]);
    expect((actions[0] as Extract<Action, { type: "resolve_discussion" }>).discussion_id).toBe(
      "d1f2e3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0",
    );
  });

  test("inline: never touches human threads", () => {
    const actions = planActions(review, { ...ctx, mode: "inline" });
    const resolved = actions.filter((a) => a.type === "resolve_discussion");
    expect(resolved).toHaveLength(1);
  });

  test("summary: a single note action, updated in place when the marker exists", () => {
    const actions = planActions(review, { ...ctx, mode: "summary" });
    expect(actions).toHaveLength(1);
    expect(actions[0].type).toBe("update_note");
  });

  test("the newest fallback note never captures the summary update", () => {
    // The notes fixture lists a kind=finding fallback note (id 60) before the
    // kind=summary note (id 101), matching GitLab's newest-first ordering.
    const actions = planActions(review, { ...ctx, mode: "summary" });
    expect((actions[0] as Extract<Action, { type: "update_note" }>).note_id).toBe(101);
  });

  test("summary: creates the note when no marker exists yet", () => {
    const bare = JSON.parse(fixture("notes-without-marker.json")) as { id: number; body: string }[];
    const actions = planActions(review, { ...ctx, mode: "summary", existingNotes: bare });
    expect(actions[0].type).toBe("create_note");
  });

  test("log: plans nothing", () => {
    expect(planActions(review, { ...ctx, mode: "log" })).toHaveLength(0);
  });
});

describe("executeActions", () => {
  test("degrades a rejected position to a plain note", async () => {
    const calls: { method: string; path: string }[] = [];
    let discussionCalls = 0;
    const http = async (method: string, path: string) => {
      calls.push({ method, path });
      if (path === "/discussions" && method === "POST") {
        discussionCalls += 1;
        return { status: discussionCalls === 1 ? 400 : 201, body: null };
      }
      return { status: 200, body: null };
    };
    const actions: Action[] = [
      { type: "create_discussion", body: "one", position: {}, fallback_body: "one-fallback" },
      { type: "create_discussion", body: "two", position: {}, fallback_body: "two-fallback" },
      { type: "create_note", body: "summary" },
    ];
    const { posted, fallbacks } = await executeActions(actions, http);
    expect(posted).toBe(1);
    expect(fallbacks).toBe(1);
    expect(calls.filter((c) => c.path === "/notes")).toHaveLength(2);
  });

  test("surfaces non-400 failures instead of swallowing them", async () => {
    const http = async () => ({ status: 500, body: null });
    const actions: Action[] = [{ type: "create_discussion", body: "x", position: {}, fallback_body: "y" }];
    await expect(executeActions(actions, http)).rejects.toThrow("500");
  });
});
