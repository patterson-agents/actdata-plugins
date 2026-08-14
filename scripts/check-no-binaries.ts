#!/usr/bin/env node
/**
 * check-no-binaries.ts -- no-tracked-binaries validator for a Patterson marketplace repo.
 *
 * Usage:  node check-no-binaries.ts <path>
 *
 * Flags tracked files (per `git ls-files`) that are fonts, office/PDF documents, archives,
 * or raster images above a size threshold. SVG is exempt at any size -- it is the only
 * raster-adjacent format this catalog ships (logos, diagrams) and it is text, not binary.
 *
 * Zero third-party dependencies: `node:child_process` to shell out to `git`, `node:fs` and
 * `node:path` for extension/size checks, erasable-syntax TypeScript only.
 *
 * Output: one finding per offending file, "LEVEL|file|line|rule|message" (line is always 0).
 * Exit:   0 = pass (no ERROR findings)   1 = ERROR findings present   2 = could not evaluate
 */
import { execFileSync } from "node:child_process";
import { statSync } from "node:fs";
import * as path from "node:path";

const RASTER_LIMIT_BYTES = 50 * 1024; // 50 KiB

const FONT_EXT = new Set([".woff", ".woff2", ".ttf", ".otf", ".eot"]);
const ARCHIVE_EXT = new Set([".zip"]);
const RASTER_EXT = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp"]);
// doc*, xls*, ppt* (word/excel/powerpoint, legacy and OOXML alike) plus PDF.
const OFFICE_PREFIX = ["doc", "xls", "ppt"];
const PDF_EXT = ".pdf";

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

function isOfficeExt(ext: string): boolean {
  const bare = ext.replace(/^\./, "");
  return OFFICE_PREFIX.some((prefix) => bare.startsWith(prefix));
}

function checkFile(rel: string, abs: string, out: string[]): void {
  const ext = path.extname(rel).toLowerCase();
  if (ext === ".svg") return; // always allowed, regardless of size

  if (FONT_EXT.has(ext)) {
    emit(
      out,
      "ERROR",
      rel,
      0,
      "binaries/font",
      `font binary tracked (${ext}); fonts must be loaded from a licensed CDN kit, never shipped`,
    );
    return;
  }

  if (ext === PDF_EXT || isOfficeExt(ext)) {
    emit(
      out,
      "ERROR",
      rel,
      0,
      "binaries/office",
      `office/PDF document tracked (${ext}); convert to a text format or link externally`,
    );
    return;
  }

  if (ARCHIVE_EXT.has(ext)) {
    emit(
      out,
      "ERROR",
      rel,
      0,
      "binaries/archive",
      `archive tracked (${ext}); commit contents individually, not as an archive`,
    );
    return;
  }

  if (RASTER_EXT.has(ext)) {
    const fileStat = tryStat(abs);
    const size = fileStat?.size ?? 0;
    if (size > RASTER_LIMIT_BYTES) {
      emit(
        out,
        "ERROR",
        rel,
        0,
        "binaries/oversized-raster",
        `raster image ${size} bytes exceeds the ${RASTER_LIMIT_BYTES}-byte (50 KiB) limit; ` +
          "prefer SVG or reduce dimensions",
      );
    }
  }
}

function main(argv: string[]): number {
  if (argv.length !== 2) {
    process.stderr.write("usage: check-no-binaries.ts <path>\n");
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

  const out: string[] = [];
  for (const rel of relFiles.sort()) {
    checkFile(rel, path.join(target, rel), out);
  }
  if (out.length === 0) {
    emit(out, "INFO", target, 0, "binaries/none-found", "no tracked binaries found");
  }

  for (const line of out) process.stdout.write(line + "\n");
  return out.some((l) => l.startsWith("ERROR|")) ? 1 : 0;
}

process.exitCode = main(process.argv.slice(1));
