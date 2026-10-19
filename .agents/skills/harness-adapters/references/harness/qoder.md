# Qoder CLI

Qoder agent CLI (`qoder`), verified as a CREWMATE and SCOUT adapter only.
`../../../../../bin/fm-spawn.sh` refuses a secondmate launch on it because `../../../../../docs/supervision-protocols/` carries no qoder wake protocol.
`../../../../../docs/verification/qoder.md` owns how every fact below was established.

## Operating facts

| Fact | Value |
|---|---|
| Binary | Absolute `qoder` resolved from `PATH`, refused if absent; the process name is `qoder`. |
| Launch | `qoder --dangerously-skip-permissions --model <id> --reasoning-effort <level> "<brief>"`, with the resolved binary; the brief is POSITIONAL, and neither `--prompt` nor `--effort` exists. |
| Trust | `../../../../../bin/fm-harness-trust.sh qoder <worktree> <project>` pre-registers the worktree in `~/.qoder/settings.json` `permissions.trustDirectories` before launch, because the pane cannot be steered past the folder-trust prompt; a failed registration refuses the launch. |
| Busy state | Rendered-tail fallback `qoder-regex` in `../../../../../bin/fm-busy-lib.sh` matches `esc to cancel` in the pinned status row (`⠋ Generating... (esc to cancel, 14s)`); the bare words `thinking`/`generating` are not matched because a persisted ` Thinking` label makes them false positives on an idle pane. |
| Turn end | Arrives through the worker status protocol and rendered tail transition to idle. |
| Exit | `/quit` (or `/exit`), one Enter; the process exits. |
| Interrupt | Single `Escape`, which cancels a running turn and leaves an idle prompt. |
| Skill | Discovered skills or natural language invocation. |
| Autonomy | `--dangerously-skip-permissions` bypasses all permission prompts; there is no `--yolo` flag. |
| Marker | Ancestry is authoritative; process name `qoder` outranks inherited markers. |
| Model | `--model <id>`. |
| Effort | `--reasoning-effort <level>` (low, medium, high); a higher firstmate level is recorded and omitted rather than passed as an unsupported flag. |

## Primary integration

Unsupported and unverified.
`../../../../../docs/supervision-protocols/` carries no qoder protocol; do not launch a primary or secondmate with this adapter.
