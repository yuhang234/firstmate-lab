# Verification: the mcode (MiniMax Code CLI) crewmate/scout adapter

Audience: maintainer verification.

Active empirical facts for firstmate's mcode adapter.
The skill tree rooted at [`.agents/skills/harness-adapters/SKILL.md`](../../.agents/skills/harness-adapters/SKILL.md) owns the operating facts through [`references/harness/mcode.md`](../../.agents/skills/harness-adapters/references/harness/mcode.md); this record owns how they were established.

## Operating facts

| Field | Value |
|---|---|
| Verified | 2026-10-19 |
| Binary | `mcode` from PATH |
| Harness | `mcode` |
| Autonomy | Interactive confirmation model by default; no `--yolo` or `--dangerously-skip-permissions` |
| Launch | `mcode --model <id> --effort <level> "<brief>"` (the brief is a POSITIONAL query; there is no `--prompt`) |
| Interrupt | `Escape` |
| Exit | `/exit` |
| Trust | Implicit; no separate folder trust registration store is required |
| Busy state | `mcode-regex` matching `esc to cancel` or `esc to interrupt` or elapsed time in status row |

## Detection and liveness

Detection is ancestry-driven in `bin/fm-harness.sh`, matching the anchored executable name `mcode`.
The agent process classifier `bin/fm-agent-process-lib.sh` identifies `mcode` as `agent` and distinguishes it from shell and unrelated processes.
Foreign markers like `CLAUDECODE` and `CURSOR_AGENT` are cleared at the launch boundary so nested invocations detect cleanly.

## Lifecycle control

Interrupt delivers `Escape`, which cancels a running turn without repolluting the composer.
Exit delivers `/exit`, which terminates the CLI session cleanly.
Secondmate and primary execution paths are unsupported and deliberately refused by `bin/fm-spawn.sh` and `bin/fm-control-lib.sh`.

## Launch shape: positional query, `--effort`

`mcode` takes the initial message as a positional query; `--prompt` does not exist.
`bin/fm-spawn.sh` passes the encoded launch-brief positionally and maps effort through `--effort`, which accepts `low`, `medium`, `high`, `xhigh`, and `max`.

## Busy state

The fallback matches `esc to cancel`, `esc to interrupt`, or elapsed time in the status row while a turn runs.
Both busy layers carry the same pattern: the classifier in `bin/fm-busy-lib.sh` and the delivery guard's `FM_DELIVERY_MCODE_BUSY_REGEX_DEFAULT` in `bin/fm-composer-lib.sh`.
An idle pane classifies as unknown rather than idle, which is the documented backstop behaviour for rendered-tail-only harnesses.
