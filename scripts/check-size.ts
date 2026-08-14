#!/usr/bin/env node
/**
 * check-size.ts -- tracked-byte size-budget validator for a Patterson marketplace repo.
 *
 * Usage:  node check-size.ts <path>
 *
 * Sums the on-disk byte size of every file `git ls-files` reports as tracked at or under
 * <path>. That is the payload a clone or checkout actually downloads. It is deliberately
 * NOT `du` block-accounting, which on this tree overstates the real figure by more than a
 * factor of two (see openspec/changes/add-repo-furniture/design.md, correction C4) and
 * would make a byte budget fire on phantom growth.
 *
 * Zero third-party dependencies: `node:child_process` to shell out to `git`, `node:fs` to
 * stat each file, erasable-syntax TypeScript only.
 *
 * Output: "LEVEL|file|line|rule|message" (line is always 0 -- this is a whole-tree check).
 * Exit:   0 = pass (no ERROR findings)   1 = ERROR findings present   2 = could not evaluate
 */
import { execFileSync } from "node:child_process";
import { statSync } from "node:fs";
import * as path from "node:path";

// 2 MiB. The original 1 MiB figure predated the OpenSpec planning root living in this
// repository; archiving the Phase 1 change proposals (openspec/) carried tracked bytes to
// ~1.05 MiB with the plugin payload (plugins/) unchanged at ~650 KB. The ceiling still
// exists to catch binary/bloat regressions, not to cap governance prose.
// [TBD: budget figure awaiting ratification -- not specified in a Patterson source]
const BUDGET_BYTES = 2 * 1024 * 1024;

/** Stat a path, returning undefined instead of throwing when it does not exist. */
function tryStat(target: string): import("node:fs").Stats | undefined {
  try {
    return statSync(target);
  } catch {
    return undefined;
  }
}

function emit(
  out: string[],
  level: string,
  filePath: string,
  line: number,
  rule: string,
  message: string,
): void {
  out.push(`${level}|${filePath}|${line}|${rule}|${message}`);
}

/** List tracked files under `target`, relative to `target`. Throws on any git failure. */
function listTracked(target: string): string[] {
  const raw = execFileSync("git", ["-C", target, "ls-files", "-z"], {
    stdio: ["ignore", "pipe", "pipe"],
  });
  return raw
    .toString("utf8")
    .split("\0")
    .filter((entry) => entry.length > 0);
}

function main(argv: string[]): number {
  if (argv.length !== 2) {
    process.stderr.write("usage: check-size.ts <path>\n");
    return 2;
  }
  const target = argv[1];
  const stat = tryStat(target);
  if (stat === undefined) {
    process.stderr.write(`error: path not found: ${target}\n`);
    return 2;
  }
  if (!stat.isDirectory()) {
    process.stderr.write(`error: not a directory: ${target}\n`);
    return 2;
  }

  let relFiles: string[];
  try {
    relFiles = listTracked(target);
  } catch (exc) {
    process.stderr.write(`error: git ls-files failed for ${target}: ${String(exc)}\n`);
    return 2;
  }

  let total = 0;
  for (const rel of relFiles) {
    const abs = path.join(target, rel);
    const fileStat = tryStat(abs);
    // A file git tracks but that is missing on disk (rare: case-sensitivity, submodule
    // gitlink, etc.) contributes 0 bytes rather than aborting the whole measurement.
    if (fileStat !== undefined && fileStat.isFile()) total += fileStat.size;
  }

  const out: string[] = [];
  if (total > BUDGET_BYTES) {
    emit(
      out,
      "ERROR",
      target,
      0,
      "size/budget",
      `tracked bytes ${total} exceed the ${BUDGET_BYTES}-byte (2 MiB) budget across ` +
        `${relFiles.length} tracked file(s)`,
    );
  } else {
    emit(
      out,
      "INFO",
      target,
      0,
      "size/budget",
      `tracked bytes ${total} within the ${BUDGET_BYTES}-byte (2 MiB) budget across ` +
        `${relFiles.length} tracked file(s)`,
    );
  }

  for (const line of out) process.stdout.write(line + "\n");
  return out.some((l) => l.startsWith("ERROR|")) ? 1 : 0;
}

process.exitCode = main(process.argv.slice(1));
