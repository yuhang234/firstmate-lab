# Qoder CLI

Qoder agent CLI (`qoder`), verified as a CREWMATE and SCOUT adapter only.
`../../../../../bin/fm-spawn.sh` refuses a secondmate launch on it because `../../../../../docs/supervision-protocols/` carries no qoder wake protocol.
`../../../../../docs/verification/qoder.md` owns how every fact below was established.

## Operating facts

| Fact | Value |
|---|---|
| Binary | Absolute `qoder` resolved from `PATH`, refused if absent; the process name is `qoder`. |
| Launch | `qoder --yolo --model <id> --effort <level> --prompt "<brief>"`, with the resolved binary. |
| Busy state | Rendered-tail fallback `qoder-regex` in `../../../../../bin/fm-busy-lib.sh` matches `esc to cancel`, `esc to interrupt`, `thinking`, or `generating`. |
| Turn end | Arrives through the worker status protocol and rendered tail transition to idle. |
| Exit | `/quit` (or `/exit`), one Enter; the process exits. |
| Interrupt | Single `Escape`, which cancels a running turn and leaves an idle prompt. |
| Skill | Discovered skills or natural language invocation. |
| Autonomy | `--yolo` bypasses all permission prompts. |
| Marker | Ancestry is authoritative; process name `qoder` outranks inherited markers. |
| Model | `--model <id>`. |
| Effort | `--effort <level>` (low, medium, high, xhigh, max). |

## Primary integration

Unsupported and unverified.
`../../../../../docs/supervision-protocols/` carries no qoder protocol; do not launch a primary or secondmate with this adapter.
