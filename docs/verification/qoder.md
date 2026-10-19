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
| Autonomy | `--yolo` |
| Launch | `qoder --yolo --model <id> --effort <level> --prompt "<brief>"` |
| Interrupt | `Escape` |
| Exit | `/quit` |
| Busy state | `qoder-regex` matching `esc to cancel|esc to interrupt|thinking|generating` |

## Detection and liveness

Detection is ancestry-driven in `bin/fm-harness.sh`, matching the anchored executable name `qoder`.
The agent process classifier `bin/fm-agent-process-lib.sh` identifies `qoder` as `agent` and distinguishes it from shell and unrelated processes.
Foreign markers like `CLAUDECODE` and `CURSOR_AGENT` are cleared at the launch boundary so nested invocations detect cleanly.

## Lifecycle control

Interrupt delivers `Escape`, which cancels a running turn without repolluting the composer.
Exit delivers `/quit`, which terminates the CLI session cleanly.
Secondmate and primary execution paths are unsupported and deliberately refused by `bin/fm-spawn.sh` and `bin/fm-control-lib.sh`.
