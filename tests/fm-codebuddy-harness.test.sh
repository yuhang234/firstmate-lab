#!/usr/bin/env bash
# Portable CodeBuddy worker adapter regression.
# Tests process identity, lifecycle control contract, busy matching, and spawn template.
set -u
# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"
# shellcheck source=bin/fm-control-lib.sh
. "$ROOT/bin/fm-control-lib.sh"
# shellcheck source=bin/fm-busy-lib.sh
. "$ROOT/bin/fm-busy-lib.sh"
# shellcheck source=bin/fm-composer-lib.sh
. "$ROOT/bin/fm-composer-lib.sh"
# shellcheck source=bin/fm-agent-process-lib.sh
. "$ROOT/bin/fm-agent-process-lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-codebuddy-harness)
HARNESS="$ROOT/bin/fm-harness.sh"

unset CLAUDECODE PI_CODING_AGENT GROK_AGENT CURSOR_AGENT CURSOR_INVOKED_AS GEMINI_CLI FM_OMP_HARNESS ATLASSIAN_AGENT_TYPE ROVODEV_CLI

# --- 1. Process identity and ancestry ----------------------------------------
mkdir -p "$TMP_ROOT/names"
for name in codebuddy codebuddy-helper; do ln -s /bin/bash "$TMP_ROOT/names/$name"; done
# shellcheck disable=SC2016
out=$(CLAUDECODE=1 "$TMP_ROOT/names/codebuddy" -c '"$1"; :' _ "$HARNESS")
[ "$out" = codebuddy ] || fail "native CodeBuddy ancestry must beat foreign CLAUDECODE: $out"
# shellcheck disable=SC2016
out=$("$TMP_ROOT/names/codebuddy-helper" -c '"$1" ancestry "$$"; :' _ "$HARNESS")
[ "$out" != 'comm codebuddy' ] || fail "unrelated codebuddy-helper claimed the adapter"
[ "$(fm_agent_process_classify_name /usr/bin/codebuddy)" = agent ] || fail "liveness lost CodeBuddy"
[ "$(fm_agent_process_classify_name codebuddy-helper)" = other ] || fail "liveness claims unrelated executable"
pass "CodeBuddy native identity; anchored liveness"

# --- 2. Control plane contract ------------------------------------------------
[ "$(fm_control_interrupt_key codebuddy)" = Escape ] || fail 'wrong interrupt key'
[ "$(fm_control_interrupt_repeat codebuddy)" = 1 ] || fail 'wrong interrupt repeat'
[ -z "$(fm_control_interrupt_arm_signal codebuddy)" ] || fail 'a single press needs no arm proof'
[ -z "$(fm_control_interrupt_clear_key codebuddy)" ] || fail 'codebuddy must not erase a composer draft'
[ "$(fm_control_exit_command codebuddy)" = /exit ] || fail 'wrong exit command'
[ "$(fm_control_harness_family codebuddy)" = codebuddy ] || fail 'recorded family lost'
fm_control_harness_supports_kind codebuddy ship || fail 'ship refused'
fm_control_harness_supports_kind codebuddy scout || fail 'scout refused'
! fm_control_harness_supports_kind codebuddy secondmate || fail 'secondmate accepted'
pass "worker-only resolution, single-press interrupt, and lifecycle capabilities"

# --- 3. Busy signal matching --------------------------------------------------
# The durable busy marker is the animated status line's parenthesized
# elapsed-time phase; its phase word cycles, so the word itself is not matched.
for signal in '✹ Beeping… (9s · waiting for model)' '✸ Chilling… (5s · running REPL)' '✷ Notifying… (36s · running REPL · 18 tokens)' 'esc to cancel'; do
  printf '%s\n' "$signal" | fm_busy_lines_match codebuddy || fail "independent delivery signal lost: $signal"
done
# A finished turn keeps a persisted `∴ Thought` label and an idle footer, so
# matching bare `thinking` would read every idle pane as busy.
for idle in '∴ Thought' '● Command finished successfully after 25 seconds.' '✔ Worked for 34s' '> Proceed with the next task or command   ↵ send' '⏵⏵ bypass permissions on'; do
  ! printf '%s\n' "$idle" | fm_busy_lines_match codebuddy || fail "idle read as busy: $idle"
done
pass "CodeBuddy busy signal matching"

# --- 4. Spawn template generation --------------------------------------------
case_dir="$TMP_ROOT/spawn"
fakebin=$(make_spawn_fakebin "$case_dir/fake" claude)
fm_fake_exit0 "$fakebin" codebuddy
home="$case_dir/home"
proj="$case_dir/project"
wt="$case_dir/wt"
fm_test_spawn_home "$home" codebuddy
fm_git_worktree "$proj" "$wt" codebuddy-test

spawn_case() {  # <id> <model> <effort>
  fm_test_spawn_brief "$home" "$1"
  FM_FAKE_LAUNCH_LOG="$case_dir/$1.launch" fm_test_run_spawn "$home" "$wt" "$fakebin" "$1" "$proj" \
    --scout --harness codebuddy --model "$2" --effort "$3" 2>&1
}

out=$(spawn_case cb-1 cb-model medium) || fail "spawn failed: $out"
launch=$(cat "$case_dir/cb-1.launch")
assert_contains "$launch" '--dangerously-skip-permissions' 'autonomous execution flag missing'
assert_contains "$launch" "--model 'cb-model' --effort 'medium' " 'model or verified effort lost'
# CodeBuddy takes the brief as a POSITIONAL argument; `--prompt` does not exist.
case "$launch" in
  *'--prompt'*) fail 'launch passed --prompt, which CodeBuddy rejects' ;;
esac
assert_contains "$launch" "launch-brief" 'positional brief missing'
# A fresh worktree is recorded in CodeBuddy's own trust store before launch, so
# the agent never parks on its folder-trust dialog. fm_test_run_spawn launches
# with a throwaway HOME at $home/user-home.
node -e '
  const fs = require("node:fs");
  const [store, wt] = process.argv.slice(1);
  const listed = JSON.parse(fs.readFileSync(store, "utf8")).trustedDirectories || [];
  if (!listed.includes(wt)) { console.error("missing " + wt); process.exit(1); }
' "$home/user-home/.codebuddy/settings.json" "$wt" || fail 'the worktree was not pre-registered for CodeBuddy trust'

if out=$(fm_test_run_spawn "$home" "$wt" "$fakebin" cb-sm "$proj" --secondmate --harness codebuddy 2>&1)
then fail 'CodeBuddy secondmate launch accepted'; fi
pass "CodeBuddy spawn template and secondmate rejection"
