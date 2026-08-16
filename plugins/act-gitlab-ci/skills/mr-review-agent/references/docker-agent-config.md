# docker-agent for merge-request review

How the shipped `review-agent.yaml` uses docker-agent, and what is safe to change.
Upstream documentation: https://docker.github.io/docker-agent/

## What docker-agent is here

A declarative agent runner: a YAML file names a model, an instruction, and toolsets; the binary
runs the loop. The review integration uses its headless mode only:

```sh
docker-agent run --exec review-agent.yaml --json - < prompt.md
```

- `--exec` runs without the interactive TUI and exits when the conversation ends.
- `--json` emits newline-delimited JSON events (messages, tool calls, results). The wrapper's
  parser reads the review out of this stream and saves it whole as `transcript.ndjson`.
- `-` takes the prompt on stdin, which avoids argv length limits on large diffs.

The binary is standalone. `DOCKER_AGENT_VERSION` pins the GitHub release the CI job downloads
(asset `docker-agent-linux-amd64`); no Docker daemon, docker-in-docker, or `docker` CLI is
involved despite the name.

## Config anatomy

```yaml
agents:
  root:
    model: anthropic/claude-opus-5       # example; the shipped template says REPLACE_ME
    instruction: |
      ...persona and output discipline...
    toolsets:
      - type: filesystem
        tools: ["read_file", "search_files_content"]
      - type: script
        shell:
          recent_history:
            description: The last 30 commits
            cmd: git log --oneline -n 30
```

The shipped template keeps the instruction short on purpose: the rubric and the diff arrive in the
prompt the wrapper builds, so the config only pins persona, output discipline, and capability.

## Swapping providers

Change `model:` and set the provider's key as a masked CI/CD variable. The engine reads standard
env var names (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, and so on -- see the
provider pages upstream). Local models via Docker Model Runner or compatible endpoints work the
same way with a `dmr/...` or custom provider model string; those need no key at all.

## Toolsets: the security boundary

The review agent runs unattended over untrusted diff content, so capability is bounded in the
config rather than by approval prompts:

| Allowed | Why |
|---|---|
| `filesystem` with `read_file`, `search_files_content` | Judging a changed line often needs surrounding code |
| `script` with fixed, argument-free commands | Context (history) without an open shell |

| Excluded | Why |
|---|---|
| `shell` | An open shell plus prompt injection equals arbitrary execution |
| `fetch` / remote `mcp` | Network egress is an exfiltration channel for anything in the environment |
| any write-capable tool | A reviewer that can edit is an actor, and belongs to `claude-code-ci-jobs` instead |

Widening the toolset is a security decision, not a convenience: everything in the job's
environment (provider key included) is within reach of a prompt-injected agent with a shell.

## Safety flags

| Flag | Behavior | Use |
|---|---|---|
| `--safety restricted` | Denies tool calls outside configured permissions without prompting | The default (`AI_REVIEW_ENGINE_FLAGS`) |
| `--yolo` | Auto-approves everything | Fallback if a version denies the read-only tools under `restricted`; acceptable only because the toolset is already read-only |
| `--sandbox` | Runs the agent in a VM | Not usable inside typical CI containers (no nested virtualization) |

## Structured output

docker-agent has a structured-output feature (upstream: configuration/structured-output) that can
force the findings schema at the model layer. The shipped setup does not depend on it: the
instruction demands a JSON-only answer and the wrapper's parser tolerates events, fences, and
wrappers. On a docker-agent version whose structured output proves stable, adding it to
`review-agent.yaml` tightens the contract without changing anything downstream.

## Version pinning

`DOCKER_AGENT_VERSION` is pinned in `mr-review-job.yml` (`v1.124.0` as shipped). Headless flags
and event shapes are young and move between releases: bump deliberately, re-run the test suite,
and re-check `--safety` behavior when doing so. For stronger supply-chain footing, verify the
downloaded binary against a recorded checksum before `chmod +x` and fail the job on mismatch.
