# MiniMax Code CLI

MiniMax Code agent CLI (`mcode`), verified as a CREWMATE and SCOUT adapter only.
`../../../../../bin/fm-spawn.sh` refuses a secondmate launch on it because `../../../../../docs/supervision-protocols/` carries no mcode wake protocol.
`../../../../../docs/verification/mcode.md` owns how every fact below was established.

## Operating facts

| Fact | Value |
|---|---|
| Binary | Absolute `mcode` resolved from `PATH`, refused if absent; the process name is `mcode`. |
| Launch | `mcode --model <id> --effort <level> "<brief>"`, with the resolved binary; the brief is POSITIONAL, and `--prompt` does not exist. |
| Trust | Implicit; no separate folder trust registration store is required. |
| Busy state | Rendered-tail fallback `mcode-regex` in `../../../../../bin/fm-busy-lib.sh` matches `esc to cancel` or `esc to interrupt` or elapsed runtime in status row. |
| Turn end | Arrives through the worker status protocol and rendered tail transition to idle. |
| Exit | `/exit`, one Enter; the process exits. |
| Interrupt | Single `Escape`, which cancels a running turn and leaves an idle prompt. |
| Skill | Discovered skills or natural language invocation. |
| Autonomy | Interactive confirmation model by default; no `--yolo` or `--dangerously-skip-permissions` bypass flag. |
| Marker | Ancestry is authoritative; process name `mcode` outranks inherited markers. |
| Model | `--model <id>`. |
| Effort | `--effort <level>` (low, medium, high, xhigh, max). |

## Primary integration

Unsupported and unverified.
`../../../../../docs/supervision-protocols/` carries no mcode protocol; do not launch a primary or secondmate with this adapter.
