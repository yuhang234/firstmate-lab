#!/usr/bin/env bash
# Portable MiniMax Code (mcode) worker adapter regression.
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

TMP_ROOT=$(fm_test_tmproot fm-mcode-harness)
HARNESS="$ROOT/bin/fm-harness.sh"

unset CLAUDECODE PI_CODING_AGENT GROK_AGENT CURSOR_AGENT CURSOR_INVOKED_AS GEMINI_CLI FM_OMP_HARNESS ATLASSIAN_AGENT_TYPE ROVODEV_CLI

# --- 1. Process identity and ancestry ----------------------------------------
mkdir -p "$TMP_ROOT/names"
for name in mcode mcode-helper; do ln -s /bin/bash "$TMP_ROOT/names/$name"; done
# shellcheck disable=SC2016
out=$(CLAUDECODE=1 "$TMP_ROOT/names/mcode" -c '"$1"; :' _ "$HARNESS")
[ "$out" = mcode ] || fail "native mcode ancestry must beat foreign CLAUDECODE: $out"
# shellcheck disable=SC2016
out=$("$TMP_ROOT/names/mcode-helper" -c '"$1" ancestry "$$"; :' _ "$HARNESS")
[ "$out" != 'comm mcode' ] || fail "unrelated mcode-helper claimed the adapter"
[ "$(fm_agent_process_classify_name /usr/bin/mcode)" = agent ] || fail "liveness lost mcode"
[ "$(fm_agent_process_classify_name mcode-helper)" = other ] || fail "liveness claims unrelated executable"
pass "mcode native identity; anchored liveness"

# --- 2. Control plane contract ------------------------------------------------
[ "$(fm_control_interrupt_key mcode)" = Escape ] || fail 'wrong interrupt key'
[ "$(fm_control_interrupt_repeat mcode)" = 1 ] || fail 'wrong interrupt repeat'
[ -z "$(fm_control_interrupt_arm_signal mcode)" ] || fail 'a single press needs no arm proof'
[ -z "$(fm_control_interrupt_clear_key mcode)" ] || fail 'mcode must not erase a composer draft'
[ "$(fm_control_exit_command mcode)" = /exit ] || fail 'wrong exit command'
[ "$(fm_control_harness_family mcode)" = mcode ] || fail 'recorded family lost'
fm_control_harness_supports_kind mcode ship || fail 'ship refused'
fm_control_harness_supports_kind mcode scout || fail 'scout refused'
! fm_control_harness_supports_kind mcode secondmate || fail 'secondmate accepted'
pass "worker-only resolution, single-press interrupt, and lifecycle capabilities"

# --- 3. Busy signal matching --------------------------------------------------
for signal in 'esc to cancel' 'esc to interrupt' '⠋ Generating... (esc to cancel, 14s)' '(9s · running tool)'; do
  printf '%s\n' "$signal" | fm_busy_lines_match mcode || fail "independent delivery signal lost: $signal"
done
for idle in 'Thinking' '▪ The command completed successfully.' '? for shortcuts' '* Type your message'; do
  ! printf '%s\n' "$idle" | fm_busy_lines_match mcode || fail "idle read as busy: $idle"
done
pass "mcode busy signal matching"

# --- 4. Spawn template generation --------------------------------------------
case_dir="$TMP_ROOT/spawn"
fakebin=$(make_spawn_fakebin "$case_dir/fake" claude)
fm_fake_exit0 "$fakebin" mcode
home="$case_dir/home"
proj="$case_dir/project"
wt="$case_dir/wt"
fm_test_spawn_home "$home" mcode
fm_git_worktree "$proj" "$wt" mcode-test

spawn_case() {  # <id> <model> <effort>
  fm_test_spawn_brief "$home" "$1"
  FM_FAKE_LAUNCH_LOG="$case_dir/$1.launch" fm_test_run_spawn "$home" "$wt" "$fakebin" "$1" "$proj" \
    --scout --harness mcode --model "$2" --effort "$3" 2>&1
}

out=$(spawn_case mc-1 mc-model high) || fail "spawn failed: $out"
launch=$(cat "$case_dir/mc-1.launch")
assert_contains "$launch" "--model 'mc-model' --effort 'high' " 'model or effort flag lost'
case "$launch" in
  *'--prompt'*) fail 'launch passed --prompt, but mcode expects positional brief' ;;
esac
assert_contains "$launch" "launch-brief" 'positional brief missing'

if out=$(fm_test_run_spawn "$home" "$wt" "$fakebin" mc-sm "$proj" --secondmate --harness mcode 2>&1)
then fail 'mcode secondmate launch accepted'; fi
pass "mcode spawn template and secondmate rejection"
