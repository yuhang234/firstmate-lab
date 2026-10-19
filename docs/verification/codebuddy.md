# Verification: the codebuddy (CodeBuddy CLI) crewmate/scout adapter

Audience: maintainer verification.

Active empirical facts for firstmate's codebuddy adapter.
The skill tree rooted at [`.agents/skills/harness-adapters/SKILL.md`](../../.agents/skills/harness-adapters/SKILL.md) owns the operating facts through [`references/harness/codebuddy.md`](../../.agents/skills/harness-adapters/references/harness/codebuddy.md); this record owns how they were established.

## Operating facts

| Field | Value |
|---|---|
| Verified | 2026-10-19 |
| Binary | `codebuddy` from PATH |
| Harness | `codebuddy` |
| Autonomy | `--dangerously-skip-permissions` |
| Launch | `codebuddy --dangerously-skip-permissions --model <id> --effort <level> "<brief>"` (the brief is a POSITIONAL argument; there is no `--prompt`) |
| Interrupt | `Escape` |
| Exit | `/exit` |
| Trust | `trustedDirectories` in `~/.codebuddy/settings.json`, pre-registered by `bin/fm-harness-trust.sh` |
| Busy state | `codebuddy-regex` matching the animated status line's parenthesized elapsed-time phase, e.g. `✹ Beeping… (9s · waiting for model)` |

## Detection and liveness

Detection is ancestry-driven in `bin/fm-harness.sh`, matching the anchored executable name `codebuddy`.
The agent process classifier `bin/fm-agent-process-lib.sh` identifies `codebuddy` as `agent` and distinguishes it from shell and unrelated processes.
Foreign markers like `CLAUDECODE` and `CURSOR_AGENT` are cleared at the launch boundary so nested invocations detect cleanly.

## Lifecycle control

Interrupt delivers `Escape`, which cancels a running turn without repolluting the composer.
Exit delivers `/exit`, which terminates the CLI session cleanly.
Secondmate and primary execution paths are unsupported and deliberately refused by `bin/fm-spawn.sh` and `bin/fm-control-lib.sh`.

## Launch shape: positional brief, no `--prompt`

`codebuddy 2.169.0` takes the initial message as a positional argument; `--prompt` is not a flag.
A first launch that passed `--prompt "<brief>"` printed `error: unknown option '--prompt'` and exited before reading anything, which is why `bin/fm-spawn.sh` now passes the encoded launch-brief positionally.
`--effort` accepts `minimal`, `low`, `medium`, `high`, `xhigh`, and `max`.

## Trust prompt: pre-registered before launch

A first launch in a fresh worktree parks on a folder-trust prompt with four numbered options, and the pane cannot be steered past it reliably.
CodeBuddy honours a `trustedDirectories` entry written to `~/.codebuddy/settings.json` ahead of launch, so `bin/fm-spawn.sh` runs `bin/fm-harness-trust.sh codebuddy <worktree> <project>` before launch.
That helper applies the same structural scope test as the claude and agy helpers (a linked worktree of the spawning project, never a primary checkout, a subdirectory, a plain directory, or the home directory), creates the store when it is absent, preserves every other key, and writes atomically with a fingerprint and readback check.
Verified live: a worktree registered only by the helper launched straight into its turn and answered `hello, my master` with no prompt, while the same binary in an unregistered directory showed the prompt.
Because CodeBuddy exposes no hook surface and no readiness probe firstmate could use to answer the prompt from the pane, a failed registration is fatal to the spawn rather than a warning.

## Busy state

The fallback matches the animated status line CodeBuddy pins above its input box while a turn runs.
Verified live on 2.169.0 in three phases: `✹ Beeping… (9s · waiting for model)`, `✸ Chilling… (5s · running REPL)`, and `✹ Calculating… (11s · running REPL ·   18 tokens)`.
The durable marker is therefore the parenthesized elapsed-time phase, not any single phase word.
Both busy layers carry the same pattern, `\([0-9]+s[^)]*\)|esc to (cancel|interrupt)`: the classifier in `bin/fm-busy-lib.sh` and the delivery guard's `FM_DELIVERY_CODEBUDDY_BUSY_REGEX_DEFAULT` in `bin/fm-composer-lib.sh`.
The `[^)]*` tail covers the separator glyph and the phase words, so a new phase name needs no change here.
The bare words `thinking` and `generating` are deliberately not matched: CodeBuddy persists a `∴ Thought` transcript label per reasoning block, so an earlier signature that matched them reported a finished pane as busy.
An idle pane renders `✔ Worked for <n>s` with an empty `>` composer and no parenthesized phase, so it classifies as unknown rather than idle, which is the documented backstop behaviour for every rendered-tail-only harness.
