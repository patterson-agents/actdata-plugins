#!/usr/bin/env node
/**
 * check-pipeline -- a GitLab CI pipeline checker for the derived pipeline
 * standards.
 *
 * Zero dependencies, node: builtins only, run with node (v24+).
 *
 * Usage:
 *   node check-pipeline.ts <file-or-directory>
 *
 * Output: LEVEL|file|line|rule|message
 * Exit:   0 no errors, 1 ERROR findings, 2 could not evaluate
 *
 * WHAT THIS IS NOT
 * ----------------
 * A regex scanner over raw lines, not a YAML parser. It therefore cannot:
 *
 *   - follow `include:` or `extends:`, so a scan defined in a template reads as
 *     missing (and the standard *requires* templates, so this is the largest
 *     source of false positives)
 *   - see anything configured in the GitLab UI rather than in a file, which is
 *     where approval rules usually live
 *   - tell whether a scan gates the pipeline or runs with allow_failure: true
 *   - check least privilege, per-environment credential separation, or whether
 *     the artifact promoted to production is the one built earlier
 *
 * A clean run means "nothing obvious found". It never means "compliant".
 *
 * Every rule below cites the reference file that documents it. A rule with no
 * citation is a bug -- see skills/pipeline-standards/_SOURCES.md.
 */

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

type Level = "ERROR" | "WARN" | "INFO";

interface Finding {
  level: Level;
  file: string;
  line: number;
  rule: string;
  message: string;
}

/** Required scans. Source: references/required-scans.md */
const REQUIRED_SCANS: { key: string; label: string; pattern: RegExp }[] = [
  { key: "sast", label: "SAST", pattern: /\bsast\b|checkmarx/i },
  { key: "sca", label: "SCA", pattern: /\bsca\b|dependency[_-]?scanning|checkmarx/i },
  { key: "dast", label: "DAST", pattern: /\bdast\b/i },
  { key: "secret-scanning", label: "secret scanning", pattern: /gitleaks|secret[_-]?detection|secret[_-]?scan/i },
  { key: "api-scanning", label: "API scanning", pattern: /api[_-]?scan|checkmarx/i },
  { key: "container-scanning", label: "container scanning", pattern: /trivy|container[_-]?scanning|checkmarx/i },
  { key: "iac-scanning", label: "IaC scanning", pattern: /iac[_-]?scan|checkmarx/i },
];

/** Container scanners that are not Trivy or Checkmarx. Source: references/required-scans.md */
const UNAPPROVED_CONTAINER_SCANNERS = /\b(grype|clair|anchore)\b/i;

/** Credential patterns rejected on sight. Source: references/credentials-and-secrets.md */
const NON_FEDERATED: { rule: string; pattern: RegExp; message: string }[] = [
  {
    rule: "credentials/service-principal-key",
    pattern: /ServicePrincipalKey/,
    message: "service principal key authentication; federated credentials are required",
  },
  {
    rule: "credentials/arm-client-secret",
    pattern: /ARM_CLIENT_SECRET/,
    message: "ARM_CLIENT_SECRET; use OIDC (ARM_USE_OIDC / use_oidc) instead",
  },
  {
    rule: "credentials/client-secret",
    pattern: /client[-_]?secret\s*[:=]/i,
    message: "a client secret is used to obtain a pipeline identity; federated credentials are required",
  },
  {
    rule: "credentials/creds-blob",
    pattern: /creds\s*:\s*\$\{\{?\s*secrets\./,
    message: "a full credentials blob from a secret store; federated credentials are required",
  },
  {
    rule: "credentials/service-principal-scheme",
    pattern: /authenticationScheme\s*:\s*ServicePrincipal/,
    message: "service principal authentication scheme backed by a secret",
  },
];

/** Inline credential literals. Source: references/credentials-and-secrets.md */
const INLINE_SECRETS: { rule: string; pattern: RegExp; message: string }[] = [
  {
    rule: "secrets/inline-literal",
    // No leading \b: an underscore is a word character, so \b would not match
    // the "PASSWORD" in "DB_PASSWORD", which is how these are usually named.
    pattern: /(password|passwd|pwd|api[-_]?key|access[-_]?key|secret[-_]?key)\s*[:=]\s*["']?[^\s"'$#{<][^\s"']{7,}/i,
    message: "a credential literal appears inline; secrets belong in a secrets manager",
  },
  {
    rule: "secrets/storage-key",
    pattern: /(AccountKey|SharedAccessKey)\s*=/,
    message: "a storage account key appears inline",
  },
  {
    rule: "secrets/token-literal",
    pattern: /\b(gh[pousr]_[A-Za-z0-9]{16,}|glpat-[A-Za-z0-9_-]{16,})\b/,
    message: "an access token literal appears inline",
  },
];

/** Placeholders that are not real credentials. */
const PLACEHOLDER =
  /(\$\{|\$[A-Z_]|<[^>]+>|CHANGE_?ME|REPLACE_?ME|xxx+|\*\*\*|example|placeholder|your[-_])/i;

const FEDERATED_MARKER =
  /id_tokens|WorkloadIdentityFederation|id-token\s*:\s*write|ARM_USE_OIDC|use_oidc|assume-role-with-web-identity|external_account/i;

const CLOUD_LOGIN = /azure\/login|azurerm|aws\s+sts|gcloud\s+auth|azureSubscription/i;

function stripComment(line: string): string {
  // Not YAML-aware. Good enough to avoid flagging commented-out examples, and
  // deliberately conservative: a '#' inside a quoted string truncates the line,
  // which can only cause a missed finding, never a false one.
  const hash = line.indexOf("#");
  return hash === -1 ? line : line.slice(0, hash);
}

function checkFile(path: string, displayPath: string): Finding[] {
  const findings: Finding[] = [];
  let raw: string;

  try {
    raw = readFileSync(path, "utf8");
  } catch (err) {
    findings.push({
      level: "ERROR",
      file: displayPath,
      line: 0,
      rule: "io/unreadable",
      message: `could not read: ${(err as Error).message}`,
    });
    return findings;
  }

  const lines = raw.split(/\r?\n/);
  const code = lines.map(stripComment);
  const body = code.join("\n");

  // --- required scans -------------------------------------------------------
  for (const scan of REQUIRED_SCANS) {
    if (!scan.pattern.test(body)) {
      findings.push({
        level: "ERROR",
        file: displayPath,
        line: 0,
        rule: `required-scan/${scan.key}`,
        message: `no ${scan.label} stage found; all seven scans are required`,
      });
    }
  }

  // --- container scanner allowlist -----------------------------------------
  if (UNAPPROVED_CONTAINER_SCANNERS.test(body) && !/trivy|checkmarx/i.test(body)) {
    const idx = code.findIndex((l) => UNAPPROVED_CONTAINER_SCANNERS.test(l));
    findings.push({
      level: "ERROR",
      file: displayPath,
      line: idx + 1,
      rule: "container-scanner/not-approved",
      message: "container scanning must use Trivy or Checkmarx; found a different scanner",
    });
  }

  // --- GitLab native scanners are not on the approved list ------------------
  if (/template\s*:\s*Security\/|Jobs\/(SAST|Secret-Detection|Dependency-Scanning|Container-Scanning)/i.test(body)) {
    const idx = code.findIndex((l) => /template\s*:\s*Security\/|Jobs\/(SAST|Secret-Detection|Dependency-Scanning|Container-Scanning)/i.test(l));
    findings.push({
      level: "WARN",
      file: displayPath,
      line: idx + 1,
      rule: "scanner/gitlab-native-not-approved",
      message:
        "GitLab's built-in security templates are not on the approved tools list; Checkmarx, GitLeaks and Trivy are required",
    });
  }

  // --- credentials ----------------------------------------------------------
  code.forEach((line, i) => {
    for (const check of NON_FEDERATED) {
      if (check.pattern.test(line)) {
        findings.push({
          level: "ERROR",
          file: displayPath,
          line: i + 1,
          rule: check.rule,
          message: check.message,
        });
      }
    }
    for (const check of INLINE_SECRETS) {
      if (check.pattern.test(line) && !PLACEHOLDER.test(line)) {
        findings.push({
          level: "ERROR",
          file: displayPath,
          line: i + 1,
          rule: check.rule,
          message: check.message,
        });
      }
    }
  });

  if (CLOUD_LOGIN.test(body) && !FEDERATED_MARKER.test(body)) {
    const idx = code.findIndex((l) => CLOUD_LOGIN.test(l));
    findings.push({
      level: "WARN",
      file: displayPath,
      line: idx + 1,
      rule: "credentials/federation-unconfirmed",
      message: "a cloud login is present with no federated-credential marker nearby",
    });
  }

  // --- approvals ------------------------------------------------------------
  const approvalMatch = body.match(
    /(?:approvals_before_merge|minimumApproverCount|required_approving_review_count|required-approvals)\s*[:=]\s*(\d+)/,
  );
  if (approvalMatch) {
    const count = Number(approvalMatch[1]);
    if (count < 2) {
      const idx = code.findIndex((l) => /approvals_before_merge|minimumApproverCount|required_approving_review_count|required-approvals/.test(l));
      findings.push({
        level: "ERROR",
        file: displayPath,
        line: idx + 1,
        rule: "mr-policy/approvers",
        message: `approver count is ${count}; the standard requires 2`,
      });
    }
  } else {
    findings.push({
      level: "WARN",
      file: displayPath,
      line: 0,
      rule: "mr-policy/approvers-unverifiable",
      message:
        "no approver count in this file; GitLab approval rules are usually set in the UI and cannot be verified here",
    });
  }

  // --- build once, promote --------------------------------------------------
  const buildSteps = code.filter((l) =>
    /\b(docker\s+build|podman\s+build|kaniko|buildah\s+bud|npm\s+run\s+build|mvn\s+package|gradle\s+build)\b/i.test(l),
  );
  if (buildSteps.length > 1) {
    findings.push({
      level: "WARN",
      file: displayPath,
      line: code.findIndex((l) => /docker\s+build|podman\s+build|kaniko|buildah\s+bud/i.test(l)) + 1,
      rule: "build/one-build-many-artifacts",
      message: `${buildSteps.length} build steps found; build once and promote the same artifact`,
    });
  }

  if (!/\b(test|pytest|jest|vitest|go\s+test|mvn\s+test|gradle\s+test|bun\s+test)\b/i.test(body)) {
    findings.push({
      level: "WARN",
      file: displayPath,
      line: 0,
      rule: "build/unit-tests",
      message: "no test step found; unit testing is required",
    });
  }

  // --- deployment. Only meaningful if the file deploys at all. ---------------
  if (/\bdeploy/i.test(body) || /\benvironment\s*:/i.test(body)) {
    if (!/blue[-_]?green|canary|rolling/i.test(body)) {
      findings.push({
        level: "WARN",
        file: displayPath,
        line: 0,
        rule: "deploy/strategy",
        message: "no approved deployment strategy found; use blue-green, canary or rolling",
      });
    }
    if (!/rollback/i.test(body)) {
      findings.push({
        level: "WARN",
        file: displayPath,
        line: 0,
        rule: "deploy/rollback",
        message: "no rollback step found; automated rollback is required",
      });
    }
    if (!/smoke/i.test(body)) {
      findings.push({
        level: "WARN",
        file: displayPath,
        line: 0,
        rule: "deploy/smoke-test",
        message: "no smoke test found; a smoke test is required after every deploy",
      });
    }
  }

  // --- templates the validator cannot follow --------------------------------
  if (/^\s*(include|extends)\s*:/m.test(body)) {
    findings.push({
      level: "INFO",
      file: displayPath,
      line: code.findIndex((l) => /^\s*(include|extends)\s*:/.test(l)) + 1,
      rule: "coverage/includes-not-followed",
      message:
        "this file uses include/extends, which this checker cannot follow; scans defined in templates will read as missing",
    });
  }

  return findings;
}

function collect(target: string): string[] {
  const st = statSync(target);
  if (st.isFile()) return [target];

  const out: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === "node_modules" || entry.name === ".git") continue;
      const full = join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (/\.(ya?ml)$/i.test(entry.name)) out.push(full);
    }
  };
  walk(target);
  return out;
}

function main(): number {
  const target = process.argv[2];
  if (!target) {
    console.error("usage: node check-pipeline.ts <file-or-directory>");
    return 2;
  }

  let files: string[];
  try {
    files = collect(target);
  } catch (err) {
    console.error(`cannot evaluate ${target}: ${(err as Error).message}`);
    return 2;
  }

  if (files.length === 0) {
    console.error(`no YAML files found under ${target}`);
    return 2;
  }

  const base = statSync(target).isDirectory() ? target : ".";
  let errors = 0;

  for (const file of files) {
    for (const f of checkFile(file, relative(base, file) || file)) {
      console.log(`${f.level}|${f.file}|${f.line}|${f.rule}|${f.message}`);
      if (f.level === "ERROR") errors++;
    }
  }

  return errors > 0 ? 1 : 0;
}

process.exit(main());
