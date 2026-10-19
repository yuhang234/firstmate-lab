#!/usr/bin/env bash
# Behavior tests for bin/fm-harness-trust.sh, the shared folder-trust
# pre-registration that lets a codebuddy or qoder crewmate reach its brief in a
# fresh isolated worktree instead of parking on its own folder-trust dialog.
#
# The safety property is the scope test inherited from bin/fm-agy-trust.sh: a
# legitimate fresh task worktree is recorded in the harness's own store so the
# agent starts with no human, and every out-of-scope path is REFUSED rather than
# warned about or quietly skipped.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

TMP_ROOT=$(fm_test_tmproot fm-harness-trust)

TRUST="$ROOT/bin/fm-harness-trust.sh"

# make_case <name>: a project with one linked worktree plus an isolated HOME.
# Echoes "<proj>|<wt>|<home>".
make_case() {
  local name=$1 case_dir proj wt home
  case_dir="$TMP_ROOT/$name"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  home="$case_dir/home"
  mkdir -p "$home"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  printf '%s|%s|%s\n' "$proj" "$wt" "$home"
}

read_case() {
  IFS='|' read -r PROJ WT HOME_DIR <<EOF
$1
EOF
}

# run_trust <harness> <worktree> <project> <home>: invoke with an isolated HOME
# so the real user store is never touched.
run_trust() {
  local harness=$1 wt=$2 proj=$3 home=$4
  HOME="$home" "$TRUST" "$harness" "$wt" "$proj" 2>&1
}

# trusted_paths <store> <key-path-json>: the recorded array, one path per line.
trusted_paths() {
  node -e '
    const fs = require("node:fs");
    const [store, keyPathJson] = process.argv.slice(1);
    if (!fs.existsSync(store)) process.exit(0);
    let node = JSON.parse(fs.readFileSync(store, "utf8"));
    for (const key of JSON.parse(keyPathJson)) {
      node = node === undefined || node === null ? undefined : node[key];
    }
    for (const entry of Array.isArray(node) ? node : []) console.log(entry);
  ' "$1" "$2"
}

assert_trusted() {  # <store> <key-path> <path> <msg>
  trusted_paths "$1" "$2" | grep -Fqx "$3" || fail "$4"
}

assert_not_trusted() {  # <store> <key-path> <path> <msg>
  trusted_paths "$1" "$2" | grep -Fqx "$3" && fail "$4"
  return 0
}

# assert_refused <output> <expected-fragment> <msg>
assert_refused() {
  case "$1" in
    *"$2"*) ;;
    *) fail "$3 (got: $1)" ;;
  esac
}

CB_STORE=.codebuddy/settings.json
CB_KEY='["trustedDirectories"]'
QD_STORE=.qoder/settings.json
QD_KEY='["permissions","trustDirectories"]'

# --- recording trust --------------------------------------------------------

test_codebuddy_worktree_is_trusted() {
  local case
  case=$(make_case cb-ok)
  read_case "$case"
  local out
  out=$(run_trust codebuddy "$WT" "$PROJ" "$HOME_DIR") || fail "codebuddy registration failed: $out"
  case "$out" in
    "trusted: $WT in $HOME_DIR/$CB_STORE") ;;
    *) fail "codebuddy registration printed an unexpected line: $out" ;;
  esac
  assert_trusted "$HOME_DIR/$CB_STORE" "$CB_KEY" "$WT" "codebuddy did not record the worktree"
  assert_not_trusted "$HOME_DIR/$CB_STORE" "$CB_KEY" "$PROJ" "codebuddy recorded the primary checkout"
  pass "codebuddy worktree is trusted"
}

test_qoder_worktree_is_trusted() {
  local case
  case=$(make_case qd-ok)
  read_case "$case"
  local out
  out=$(run_trust qoder "$WT" "$PROJ" "$HOME_DIR") || fail "qoder registration failed: $out"
  case "$out" in
    "trusted: $WT in $HOME_DIR/$QD_STORE") ;;
    *) fail "qoder registration printed an unexpected line: $out" ;;
  esac
  assert_trusted "$HOME_DIR/$QD_STORE" "$QD_KEY" "$WT" "qoder did not record the worktree"
  pass "qoder worktree is trusted"
}

test_store_is_created_private() {
  local case
  case=$(make_case created)
  read_case "$case"
  run_trust codebuddy "$WT" "$PROJ" "$HOME_DIR" >/dev/null ||
    fail "registration into an absent store failed"
  [ -f "$HOME_DIR/$CB_STORE" ] || fail "the settings store was not created"
  local mode
  mode=$(stat -c '%a' "$HOME_DIR/$CB_STORE") || fail "could not stat the created store"
  [ "$mode" = 600 ] || fail "the created store is not private (mode $mode)"
  pass "an absent store is created private"
}

test_registration_is_idempotent() {
  local case
  case=$(make_case idem)
  read_case "$case"
  run_trust codebuddy "$WT" "$PROJ" "$HOME_DIR" >/dev/null || fail "first registration failed"
  run_trust codebuddy "$WT" "$PROJ" "$HOME_DIR" >/dev/null || fail "second registration failed"
  local count
  count=$(trusted_paths "$HOME_DIR/$CB_STORE" "$CB_KEY" | grep -Fxc "$WT")
  [ "$count" = 1 ] || fail "a repeated registration duplicated the entry ($count copies)"
  pass "registration is idempotent"
}

test_unrelated_store_content_is_preserved() {
  local case
  case=$(make_case preserve)
  read_case "$case"
  mkdir -p "$HOME_DIR/.codebuddy" "$HOME_DIR/.qoder"
  printf '{"model":"step-5-preview","trustedDirectories":["/somewhere/else"]}\n' >"$HOME_DIR/$CB_STORE"
  printf '{"permissions":{"trustDirectories":["/somewhere/else"],"deny":["Bash(rm)"]}}\n' >"$HOME_DIR/$QD_STORE"
  run_trust codebuddy "$WT" "$PROJ" "$HOME_DIR" >/dev/null || fail "codebuddy registration over an existing store failed"
  run_trust qoder "$WT" "$PROJ" "$HOME_DIR" >/dev/null || fail "qoder registration over an existing store failed"
  assert_trusted "$HOME_DIR/$CB_STORE" "$CB_KEY" "/somewhere/else" "codebuddy dropped a pre-existing trusted path"
  assert_trusted "$HOME_DIR/$QD_STORE" "$QD_KEY" "/somewhere/else" "qoder dropped a pre-existing trusted path"
  local model deny
  model=$(node -e 'process.stdout.write(String(JSON.parse(require("node:fs").readFileSync(process.argv[1],"utf8")).model))' "$HOME_DIR/$CB_STORE")
  deny=$(node -e 'process.stdout.write(JSON.parse(require("node:fs").readFileSync(process.argv[1],"utf8")).permissions.deny.join(","))' "$HOME_DIR/$QD_STORE")
  [ "$model" = step-5-preview ] || fail "codebuddy dropped an unrelated key (model=$model)"
  [ "$deny" = 'Bash(rm)' ] || fail "qoder dropped an unrelated permission key (deny=$deny)"
  pass "unrelated store content is preserved"
}

# --- scope refusals ---------------------------------------------------------

test_primary_checkout_is_refused() {
  local case
  case=$(make_case primary)
  read_case "$case"
  local out
  if out=$(run_trust codebuddy "$PROJ" "$PROJ" "$HOME_DIR"); then
    fail "a primary checkout was accepted: $out"
  fi
  assert_refused "$out" "is a primary checkout, not an isolated worktree" "a primary checkout was refused for the wrong reason"
  assert_not_trusted "$HOME_DIR/$CB_STORE" "$CB_KEY" "$PROJ" "a refused primary checkout was still recorded"
  pass "a primary checkout is refused"
}

test_worktree_subdirectory_is_refused() {
  local case
  case=$(make_case subdir)
  read_case "$case"
  mkdir -p "$WT/sub"
  local out
  if out=$(run_trust qoder "$WT/sub" "$PROJ" "$HOME_DIR"); then
    fail "a worktree subdirectory was accepted: $out"
  fi
  assert_refused "$out" "is not a worktree root" "a worktree subdirectory was refused for the wrong reason"
  pass "a worktree subdirectory is refused"
}

test_non_git_directory_is_refused() {
  local case plain out
  case=$(make_case plain)
  read_case "$case"
  plain="$TMP_ROOT/plain"
  mkdir -p "$plain"
  if out=$(run_trust codebuddy "$plain" "$plain" "$HOME_DIR"); then
    fail "a plain directory was accepted: $out"
  fi
  assert_refused "$out" "is not inside a git repository" "a plain directory was refused for the wrong reason"
  pass "a non-git directory is refused"
}

test_home_directory_is_refused() {
  local case out
  case=$(make_case homedir)
  read_case "$case"
  if out=$(run_trust qoder "$HOME_DIR" "$PROJ" "$HOME_DIR"); then
    fail "a home directory was accepted: $out"
  fi
  assert_refused "$out" "is the home directory, not a task worktree" "a home directory was refused for the wrong reason"
  pass "a home directory is refused"
}

test_unknown_harness_is_refused() {
  local case out
  case=$(make_case harness)
  read_case "$case"
  if out=$(run_trust claude "$WT" "$PROJ" "$HOME_DIR"); then
    fail "an unknown harness was accepted: $out"
  fi
  assert_refused "$out" "unknown harness 'claude'" "an unknown harness was refused for the wrong reason"
  pass "an unknown harness is refused"
}

test_argument_count_is_refused() {
  local out
  if out=$(HOME="$TMP_ROOT" "$TRUST" codebuddy "$TMP_ROOT" 2>&1); then
    fail "a short argument list was accepted: $out"
  fi
  assert_refused "$out" "usage: fm-harness-trust.sh <harness> <worktree> <project>" "a short argument list was refused for the wrong reason"
  pass "a short argument list is refused"
}

test_codebuddy_worktree_is_trusted
test_qoder_worktree_is_trusted
test_store_is_created_private
test_registration_is_idempotent
test_unrelated_store_content_is_preserved
test_primary_checkout_is_refused
test_worktree_subdirectory_is_refused
test_non_git_directory_is_refused
test_home_directory_is_refused
test_unknown_harness_is_refused
test_argument_count_is_refused
