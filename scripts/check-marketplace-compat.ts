#!/usr/bin/env bun
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(process.argv[2] ?? ".");
const problems: string[] = [];

function json(path: string): Record<string, any> {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    problems.push(`${path}: ${error instanceof Error ? error.message : String(error)}`);
    return {};
  }
}

const claudePath = join(root, ".claude-plugin", "marketplace.json");
const openaiPath = join(root, ".agents", "plugins", "marketplace.json");
const copilotPath = join(root, ".github", "plugin", "marketplace.json");
for (const path of [claudePath, openaiPath, copilotPath]) {
  if (!existsSync(path)) problems.push(`${path}: required marketplace is missing`);
}

const claude = json(claudePath);
const openai = json(openaiPath);
const copilot = json(copilotPath);
const claudeEntries = new Map((claude.plugins ?? []).map((entry: any) => [entry.name, entry]));
const openaiEntries = new Map((openai.plugins ?? []).map((entry: any) => [entry.name, entry]));
const copilotEntries = new Map((copilot.plugins ?? []).map((entry: any) => [entry.name, entry]));
for (const [host, entries] of [["OpenAI", openaiEntries], ["Copilot", copilotEntries]] as const) {
  for (const name of entries.keys()) {
    if (!claudeEntries.has(name)) problems.push(`${String(name)}: present only in ${host} marketplace`);
  }
}

for (const dir of readdirSync(join(root, "plugins"), { withFileTypes: true })) {
  if (!dir.isDirectory()) continue;
  const pluginRoot = join(root, "plugins", dir.name);
  const claudeManifestPath = join(pluginRoot, ".claude-plugin", "plugin.json");
  if (!existsSync(claudeManifestPath)) continue;

  const manifests = [
    ["Claude", claudeManifestPath],
    ["OpenAI", join(pluginRoot, ".codex-plugin", "plugin.json")],
    ["Copilot", join(pluginRoot, "plugin.json")],
  ] as const;
  const versions = new Set<string>();
  for (const [host, path] of manifests) {
    if (!existsSync(path)) {
      problems.push(`${dir.name}: missing ${host} manifest ${path}`);
      continue;
    }
    const manifest = json(path);
    if (manifest.name !== dir.name) problems.push(`${path}: name must equal ${dir.name}`);
    if (typeof manifest.version !== "string") problems.push(`${path}: version is required`);
    else versions.add(manifest.version);
  }
  if (versions.size > 1) problems.push(`${dir.name}: manifest versions disagree (${[...versions].join(", ")})`);
  const version = [...versions][0];

  const ce: any = claudeEntries.get(dir.name);
  const oe: any = openaiEntries.get(dir.name);
  const ge: any = copilotEntries.get(dir.name);
  if (!ce || !oe || !ge) {
    problems.push(`${dir.name}: missing from one or more marketplaces`);
    continue;
  }
  if (ce.version !== version || ge.version !== version) problems.push(`${dir.name}: catalog version does not match ${version}`);
  if (oe.policy?.installation !== "AVAILABLE") problems.push(`${dir.name}: OpenAI installation policy must be AVAILABLE`);
  if (oe.policy?.authentication !== "ON_INSTALL") problems.push(`${dir.name}: OpenAI authentication policy must be ON_INSTALL`);
  if (typeof oe.category !== "string" || !oe.category) problems.push(`${dir.name}: OpenAI category is required`);

const openaiSource = oe.source?.path;
if (oe.source?.source !== "local" || typeof openaiSource !== "string" || resolve(root, openaiSource) !== pluginRoot) {
  problems.push(`${dir.name}: OpenAI source must resolve to the plugin directory`);
}
if (typeof ge.source !== "string" || resolve(root, ge.source) !== pluginRoot) {
  problems.push(`${dir.name}: Copilot source must resolve to the plugin directory`);
}

for (const problem of problems) console.log(`ERROR|marketplace|0|compat|${problem}`);
if (problems.length) process.exit(1);
console.log(`INFO|marketplace|0|compat|${claudeEntries.size} plugin(s) agree across Claude, OpenAI, and Copilot`);
