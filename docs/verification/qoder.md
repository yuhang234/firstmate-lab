# Verification: the qoder (Qoder CLI) crewmate/scout adapter

Audience: maintainer verification.

Active empirical facts for firstmate's qoder adapter.
The skill tree rooted at [`.agents/skills/harness-adapters/SKILL.md`](../../.agents/skills/harness-adapters/SKILL.md) owns the operating facts through [`references/harness/qoder.md`](../../.agents/skills/harness-adapters/references/harness/qoder.md); this record owns how they were established.

## Operating facts

| Field | Value |
|---|---|
| Verified | 2026-10-19 |
| Binary | `qoder` from PATH |
| Harness | `qoder` |
| Autonomy | `--dangerously-skip-permissions` (there is no `--yolo`) |
| Launch | `qoder --dangerously-skip-permissions --model <id> --reasoning-effort <level> "<brief>"` (the brief is a POSITIONAL query; there is no `--prompt` or `--effort`) |
| Interrupt | `Escape` |
| Exit | `/quit` |
| Trust | `permissions.trustDirectories` in `~/.qoder/settings.json`, pre-registered by `bin/fm-harness-trust.sh` |
| Busy state | `qoder-regex` matching `esc to cancel` in the pinned status row |

## Detection and liveness

Detection is ancestry-driven in `bin/fm-harness.sh`, matching the anchored executable name `qoder`.
The agent process classifier `bin/fm-agent-process-lib.sh` identifies `qoder` as `agent` and distinguishes it from shell and unrelated processes.
Foreign markers like `CLAUDECODE` and `CURSOR_AGENT` are cleared at the launch boundary so nested invocations detect cleanly.

## Lifecycle control

Interrupt delivers `Escape`, which cancels a running turn without repolluting the composer.
Exit delivers `/quit`, which terminates the CLI session cleanly.
Secondmate and primary execution paths are unsupported and deliberately refused by `bin/fm-spawn.sh` and `bin/fm-control-lib.sh`.

## Launch shape: positional query, `--reasoning-effort`

`qoder 1.1.73` takes the initial message as a positional query; neither `--prompt` nor `--effort` exists, and autonomy is `--dangerously-skip-permissions` rather than `--yolo`.
`bin/fm-spawn.sh` passes the encoded launch-brief positionally and maps effort through `--reasoning-effort`, which accepts `low`, `medium`, and `high`; a higher firstmate effort level is recorded and omitted rather than translated into a flag Qoder rejects.

## Trust prompt: pre-registered before launch

A first launch in a fresh worktree parks on a folder-trust prompt.
Qoder honours a `permissions.trustDirectories` entry written to `~/.qoder/settings.json` ahead of launch, so `bin/fm-spawn.sh` runs `bin/fm-harness-trust.sh qoder <worktree> <project>` before launch.
That helper applies the same structural scope test as the claude and agy helpers (a linked worktree of the spawning project, never a primary checkout, a subdirectory, a plain directory, or the home directory), creates the store when it is absent, preserves every other key, and writes atomically with a fingerprint and readback check.
Verified live: a worktree registered only by the helper launched straight into its turn and answered `hello, my master` with no prompt, while the same binary in an unregistered directory showed the prompt.
Because Qoder exposes no hook surface and no readiness probe firstmate could use to answer the prompt from the pane, a failed registration is fatal to the spawn rather than a warning.

## Busy state

The fallback matches the `esc to cancel` token in the status row Qoder pins above its input box while a turn runs.
Verified live on 1.1.73: `⠋ Generating... (esc to cancel, 14s)`, with the idle status row showing `? for shortcuts` instead.
Both busy layers carry the same pattern, `esc to (cancel|interrupt)`: the classifier in `bin/fm-busy-lib.sh` and the delivery guard's `FM_DELIVERY_QODER_BUSY_REGEX_DEFAULT` in `bin/fm-composer-lib.sh`.
The bare words `thinking` and `generating` are deliberately not matched: Qoder persists a ` Thinking` transcript label per reasoning block, so an earlier signature that matched them reported a finished pane as busy.
An idle pane therefore classifies as unknown rather than idle, which is the documented backstop behaviour for every rendered-tail-only harness.
