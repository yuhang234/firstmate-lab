# CodeBuddy CLI

Tencent Cloud's CodeBuddy CLI (`codebuddy`), verified as a CREWMATE and SCOUT adapter only.
`../../../../../bin/fm-spawn.sh` refuses a secondmate launch on it because `../../../../../docs/supervision-protocols/` carries no codebuddy wake protocol.
`../../../../../docs/verification/codebuddy.md` owns how every fact below was established.

## Operating facts

| Fact | Value |
|---|---|
| Binary | Absolute `codebuddy` resolved from `PATH`, refused if absent; the process name is `codebuddy`. |
| Launch | `codebuddy --dangerously-skip-permissions --model <id> --effort <level> "<brief>"`, with the resolved binary; the brief is POSITIONAL and `--prompt` does not exist. |
| Trust | `../../../../../bin/fm-harness-trust.sh codebuddy <worktree> <project>` pre-registers the worktree in `~/.codebuddy/settings.json` `trustedDirectories` before launch, because the pane cannot be steered past the folder-trust prompt; a failed registration refuses the launch. |
| Busy state | Rendered-tail fallback `codebuddy-regex` in `../../../../../bin/fm-busy-lib.sh` matches the animated status line's parenthesized elapsed-time phase (`✹ Beeping… (9s · waiting for model)`) or `esc to cancel`; the bare words `thinking`/`generating` are not matched because a persisted `∴ Thought` label makes them false positives on an idle pane. |
| Turn end | Arrives through the worker status protocol and rendered tail transition to idle. |
| Exit | `/exit` (or `/quit`), one Enter; the process exits. |
| Interrupt | Single `Escape`, which cancels a running turn and leaves an idle prompt. |
| Skill | Discovered skills or natural language invocation. |
| Autonomy | `--dangerously-skip-permissions` auto-approves tool calls and file edits. |
| Marker | Ancestry is authoritative; process name `codebuddy` outranks inherited markers. |
| Model | `--model <id>`. |
| Effort | `--effort <level>` (minimal, low, medium, high, xhigh, max). |

## Primary integration

Unsupported and unverified.
`../../../../../docs/supervision-protocols/` carries no codebuddy protocol; do not launch a primary or secondmate with this adapter.
