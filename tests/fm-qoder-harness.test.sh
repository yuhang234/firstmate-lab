#!/usr/bin/env bash
# Portable Qoder worker adapter regression.
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

TMP_ROOT=$(fm_test_tmproot fm-qoder-harness)
HARNESS="$ROOT/bin/fm-harness.sh"

unset CLAUDECODE PI_CODING_AGENT GROK_AGENT CURSOR_AGENT CURSOR_INVOKED_AS GEMINI_CLI FM_OMP_HARNESS ATLASSIAN_AGENT_TYPE ROVODEV_CLI

# --- 1. Process identity and ancestry ----------------------------------------
mkdir -p "$TMP_ROOT/names"
for name in qoder qoder-helper; do ln -s /bin/bash "$TMP_ROOT/names/$name"; done
# shellcheck disable=SC2016
out=$(CLAUDECODE=1 "$TMP_ROOT/names/qoder" -c '"$1"; :' _ "$HARNESS")
[ "$out" = qoder ] || fail "native Qoder ancestry must beat foreign CLAUDECODE: $out"
# shellcheck disable=SC2016
out=$("$TMP_ROOT/names/qoder-helper" -c '"$1" ancestry "$$"; :' _ "$HARNESS")
[ "$out" != 'comm qoder' ] || fail "unrelated qoder-helper claimed the adapter"
[ "$(fm_agent_process_classify_name /usr/bin/qoder)" = agent ] || fail "liveness lost Qoder"
[ "$(fm_agent_process_classify_name qoder-helper)" = other ] || fail "liveness claims unrelated executable"
pass "Qoder native identity; anchored liveness"

# --- 2. Control plane contract ------------------------------------------------
[ "$(fm_control_interrupt_key qoder)" = Escape ] || fail 'wrong interrupt key'
[ "$(fm_control_interrupt_repeat qoder)" = 1 ] || fail 'wrong interrupt repeat'
[ -z "$(fm_control_interrupt_arm_signal qoder)" ] || fail 'a single press needs no arm proof'
[ -z "$(fm_control_interrupt_clear_key qoder)" ] || fail 'qoder must not erase a composer draft'
[ "$(fm_control_exit_command qoder)" = /quit ] || fail 'wrong exit command'
[ "$(fm_control_harness_family qoder)" = qoder ] || fail 'recorded family lost'
fm_control_harness_supports_kind qoder ship || fail 'ship refused'
fm_control_harness_supports_kind qoder scout || fail 'scout refused'
! fm_control_harness_supports_kind qoder secondmate || fail 'secondmate accepted'
pass "worker-only resolution, single-press interrupt, and lifecycle capabilities"

# --- 3. Busy signal matching --------------------------------------------------
# Qoder pins the `esc to cancel` token in the status row above its input box
# while a turn runs; its idle row shows `? for shortcuts` instead.
for signal in '⠋ Generating... (esc to cancel, 6s)' '⠋ Generating... (esc to cancel, 14s)'; do
  printf '%s\n' "$signal" | fm_busy_lines_match qoder || fail "independent delivery signal lost: $signal"
done
# A finished turn leaves its ` Thinking` reasoning label and the composer
# placeholder in the tail, so matching the bare word would read idle as busy.
for idle in ' Thinking' '▪ The command completed successfully.' '? for shortcuts' '*   Type your message or @path/to/file' 'YOLO Shift+Tab to Auto Mode'; do
  ! printf '%s\n' "$idle" | fm_busy_lines_match qoder || fail "idle read as busy: $idle"
done
pass "Qoder busy signal matching"

# --- 4. Spawn template generation --------------------------------------------
case_dir="$TMP_ROOT/spawn"
fakebin=$(make_spawn_fakebin "$case_dir/fake" claude)
fm_fake_exit0 "$fakebin" qoder
home="$case_dir/home"
proj="$case_dir/project"
wt="$case_dir/wt"
fm_test_spawn_home "$home" qoder
fm_git_worktree "$proj" "$wt" qoder-test

spawn_case() {  # <id> <model> <effort>
  fm_test_spawn_brief "$home" "$1"
  FM_FAKE_LAUNCH_LOG="$case_dir/$1.launch" fm_test_run_spawn "$home" "$wt" "$fakebin" "$1" "$proj" \
    --scout --harness qoder --model "$2" --effort "$3" 2>&1
}

out=$(spawn_case qd-1 qd-model high) || fail "spawn failed: $out"
launch=$(cat "$case_dir/qd-1.launch")
assert_contains "$launch" '--dangerously-skip-permissions' 'autonomous execution flag missing'
case "$launch" in
  *'--yolo'*) fail 'launch passed --yolo, which Qoder rejects' ;;
esac
# Qoder spells effort `--reasoning-effort` and takes the brief positionally.
assert_contains "$launch" "--model 'qd-model' --reasoning-effort 'high' " 'model or verified effort lost'
case "$launch" in
  *'--prompt'*|*"--effort '"*) fail 'launch passed a flag Qoder rejects' ;;
esac
assert_contains "$launch" "launch-brief" 'positional brief missing'

# A firstmate effort level Qoder does not accept is recorded and omitted rather
# than passed through or silently downgraded to a level it does accept.
out=$(spawn_case qd-2 qd-model xhigh) || fail "spawn failed: $out"
launch=$(cat "$case_dir/qd-2.launch")
case "$launch" in
  *'--reasoning-effort'*) fail 'an unsupported effort level reached the Qoder command line' ;;
esac
assert_contains "$launch" "--model 'qd-model' " 'model lost when the effort level was omitted'

# A fresh worktree is recorded in Qoder's own trust store before launch, so the
# agent never parks on its folder-trust dialog. fm_test_run_spawn launches with a
# throwaway HOME at $home/user-home.
node -e '
  const fs = require("node:fs");
  const [store, wt] = process.argv.slice(1);
  const listed = (JSON.parse(fs.readFileSync(store, "utf8")).permissions || {}).trustDirectories || [];
  if (!listed.includes(wt)) { console.error("missing " + wt); process.exit(1); }
' "$home/user-home/.qoder/settings.json" "$wt" || fail 'the worktree was not pre-registered for Qoder trust'

if out=$(fm_test_run_spawn "$home" "$wt" "$fakebin" qd-sm "$proj" --secondmate --harness qoder 2>&1)
then fail 'Qoder secondmate launch accepted'; fi
pass "Qoder spawn template and secondmate rejection"
