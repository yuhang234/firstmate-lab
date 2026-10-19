#!/usr/bin/env bash
# Pre-register a harness's own folder-trust store for the isolated task worktree
# a ship/scout spawn is about to launch a codebuddy or qoder crewmate into, so
# the worker reaches its brief in that worktree instead of parking on the
# folder-trust dialog before it has read anything.
#
# Usage: fm-harness-trust.sh <harness> <worktree> <project>
#   <harness>   codebuddy | qoder
#   <worktree>  the isolated task worktree this spawn launches into
#   <project>   the primary checkout that worktree belongs to
# Prints one line naming what it registered; refuses loudly on anything else.
#
# WHY THIS EXISTS. codebuddy 2.169.0 gates a folder it has never seen behind
# "Do you trust the files in this folder?" and no launch flag suppresses it
# (`codebuddy --help` lists none; --dangerously-skip-permissions covers tool
# approvals, not the folder). Answering appends the folder to the
# `trustedDirectories` array of ${HOME}/.codebuddy/settings.json, and the store
# is read before the dialog decision: a path already listed there launches
# straight into the brief. Verified 2026-10-19 on the cb-hello smoke test, whose
# first launch parked on the dialog in an isolated worktree that no entry
# covered, and whose relaunch after the dialog was answered started immediately
# with /home/Yuhang/.treehouse/firstmate-lab-0d0014/1/firstmate-lab recorded in
# that array. qoder 1.1.73 records the same consent as `permissions.
# trustDirectories` in ${HOME}/.qoder/settings.json; the qd-hello smoke test
# never rendered its dialog because the parent /home/Yuhang was already listed
# there, so an entry covering the worktree's own path is what keeps a fresh
# machine's first launch from parking (that fresh-store behaviour is inferred
# from the recorded store, not yet observed on an untrusted parent).
#
# THE SCOPE TEST IS THE SAFETY PROPERTY and mirrors bin/fm-agy-trust.sh: a
# <worktree> must be a LINKED git worktree - its own git dir, sharing
# <project>'s common dir - whose top level is exactly the resolved argument.
# A primary checkout, a worktree of an unrelated repo, a subdirectory of a
# worktree, a plain directory, and a home directory are each refused with a
# non-zero exit, never a warning and never a silent skip. Only the launching
# user's own store is written, it must be a regular file this uid owns, every
# unrelated key and entry is preserved, and the replacement is atomic with a
# fingerprint check before the rename and a readback after it, so a store that
# moved under us (both CLIs rewrite it themselves) is retried once and then
# refused rather than clobbered.
set -u
unset CDPATH \
  GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_INDEX_FILE \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES GIT_NAMESPACE \
  GIT_DISCOVERY_ACROSS_FILESYSTEM GIT_CONFIG GIT_CONFIG_GLOBAL \
  GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM GIT_CONFIG_COUNT

[ "$#" -eq 3 ] || { echo "usage: fm-harness-trust.sh <harness> <worktree> <project>" >&2; exit 2; }
HARNESS=$1
WT_ARG=$2
PROJ_ARG=$3

refuse() { echo "error: refusing to pre-register $HARNESS trust: $1" >&2; exit 1; }

case "$HARNESS" in
codebuddy)
  STORE_SUBPATH=".codebuddy/settings.json"
  # Top-level array of trusted folder paths.
  KEY_PATH_JSON='["trustedDirectories"]'
  ;;
qoder)
  STORE_SUBPATH=".qoder/settings.json"
  # Nested under permissions, alongside the CLI's other permission settings.
  KEY_PATH_JSON='["permissions","trustDirectories"]'
  ;;
*) refuse "unknown harness '$HARNESS' (expected codebuddy or qoder)" ;;
esac

real_dir() { (cd -P -- "$1" 2>/dev/null && pwd -P); }
logical_dir() { (cd -- "$1" 2>/dev/null && pwd -L); }
real_file() { node -e 'process.stdout.write(require("node:fs").realpathSync(process.argv[1]))' "$1" 2>/dev/null; }

common_dir_of() {
  local dir=$1 common
  common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
  (cd -P -- "$dir" && real_dir "$common")
}

WT_REAL=$(real_dir "$WT_ARG") || true
[ -n "$WT_REAL" ] || refuse "worktree '$WT_ARG' is not an accessible directory"
WT_LOGICAL=$(logical_dir "$WT_ARG") || true
[ -n "$WT_LOGICAL" ] || WT_LOGICAL=$WT_REAL
PROJ_REAL=$(real_dir "$PROJ_ARG") || true
[ -n "$PROJ_REAL" ] || refuse "project '$PROJ_ARG' is not an accessible directory"

[ -n "${HOME:-}" ] || refuse "HOME is not set, so $HARNESS's settings store cannot be located"
HOME_REAL=$(real_dir "$HOME") || true
[ -n "$HOME_REAL" ] || refuse "HOME '$HOME' is not an accessible directory"
[ "$WT_REAL" != "$HOME_REAL" ] || refuse "'$WT_REAL' is the home directory, not a task worktree"

WT_TOP=$(git -C "$WT_REAL" rev-parse --show-toplevel 2>/dev/null) || true
[ -n "$WT_TOP" ] || refuse "'$WT_REAL' is not inside a git repository"
WT_TOP_REAL=$(real_dir "$WT_TOP") || true
[ "$WT_TOP_REAL" = "$WT_REAL" ] || refuse "'$WT_REAL' is not a worktree root (its root is '${WT_TOP_REAL:-unresolvable}')"

WT_GIT_DIR=$(git -C "$WT_REAL" rev-parse --absolute-git-dir 2>/dev/null) || true
[ -n "$WT_GIT_DIR" ] || refuse "'$WT_REAL' has no resolvable git directory"
WT_GIT_DIR=$(real_dir "$WT_GIT_DIR") || true
[ -n "$WT_GIT_DIR" ] || refuse "'$WT_REAL' has an unresolvable git directory"
WT_COMMON=$(common_dir_of "$WT_REAL") || true
[ -n "$WT_COMMON" ] || refuse "'$WT_REAL' has no resolvable git common directory"
[ "$WT_GIT_DIR" != "$WT_COMMON" ] || refuse "'$WT_REAL' is a primary checkout, not an isolated worktree"

PROJ_COMMON=$(common_dir_of "$PROJ_REAL") || true
[ -n "$PROJ_COMMON" ] || refuse "project '$PROJ_REAL' is not inside a git repository"
[ "$WT_COMMON" = "$PROJ_COMMON" ] || refuse "'$WT_REAL' is not a worktree of project '$PROJ_REAL'"

command -v node >/dev/null 2>&1 || refuse "node is required to record folder trust and was not found on PATH"

STORE="$HOME_REAL/$STORE_SUBPATH"
mkdir -p "$(dirname "$STORE")" 2>/dev/null || true
STORE_DIR=$(real_dir "$(dirname "$STORE")") || true
[ -n "$STORE_DIR" ] || refuse "$HARNESS settings directory '$(dirname "$STORE")' does not exist and could not be created"
STORE="$STORE_DIR/$(basename "$STORE")"
if [ -L "$STORE" ]; then
  STORE_REAL=$(real_file "$STORE") || true
  [ -n "$STORE_REAL" ] || refuse "'$STORE' is a symlink whose target cannot be resolved"
  STORE=$STORE_REAL
fi
if [ -e "$STORE" ]; then
  [ -f "$STORE" ] || refuse "'$STORE' is not a regular file"
  [ -O "$STORE" ] || refuse "'$STORE' is not owned by this user"
  [ -w "$STORE" ] || refuse "'$STORE' is not writable"
fi

if ! node - "$STORE" "$KEY_PATH_JSON" "$WT_LOGICAL" "$WT_REAL" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const [store, keyPathJson, ...wanted] = process.argv.slice(2);
const keyPath = JSON.parse(keyPathJson);
const paths = [...new Set(wanted)];
const readStore = () => {
  try {
    return fs.readFileSync(store);
  } catch (err) {
    if (err.code === "ENOENT") return null;
    throw err;
  }
};
const fingerprint = (buf) =>
  buf === null ? "absent" : crypto.createHash("sha256").update(buf).digest("hex");
// Resolve the owning container of the trusted-path array, creating the object
// chain when a store has no such section yet.
const container = (root) => {
  let node = root;
  for (const key of keyPath.slice(0, -1)) {
    if (node[key] === undefined || node[key] === null) node[key] = {};
    if (typeof node[key] !== "object" || Array.isArray(node[key])) {
      throw new Error(`${store} has a non-object "${keyPath.join(".")}" parent`);
    }
    node = node[key];
  }
  const leaf = keyPath[keyPath.length - 1];
  if (node[leaf] === undefined || node[leaf] === null) node[leaf] = [];
  if (!Array.isArray(node[leaf])) {
    throw new Error(`${store} has a non-array "${keyPath.join(".")}" value`);
  }
  return node[leaf];
};
const listed = (root) => {
  try {
    const list = container(root);
    return paths.every((p) => list.includes(p));
  } catch {
    return false;
  }
};
const attempt = () => {
  const original = readStore();
  const before = fingerprint(original);
  let root = {};
  if (original !== null) {
    const raw = original.toString("utf8");
    if (raw.trim() !== "") {
      root = JSON.parse(raw);
      if (root === null || typeof root !== "object" || Array.isArray(root)) {
        throw new Error(`${store} is not a JSON object`);
      }
    }
  }
  if (listed(root)) return "recorded";
  const list = container(root);
  for (const p of paths) {
    if (!list.includes(p)) list.push(p);
  }
  const unique = `${process.pid}.${crypto.randomBytes(8).toString("hex")}`;
  const tmp = path.join(path.dirname(store), `.settings.json.fm-trust.${unique}`);
  fs.writeFileSync(tmp, `${JSON.stringify(root, null, 2)}\n`, { mode: 0o600, flag: "wx" });
  let renamed = false;
  try {
    if (fingerprint(readStore()) !== before) return "moved";
    fs.renameSync(tmp, store);
    renamed = true;
  } finally {
    if (!renamed) fs.rmSync(tmp, { force: true });
  }
  return listed(JSON.parse(fs.readFileSync(store, "utf8"))) ? "recorded" : "dropped";
};
try {
  for (let i = 0; i < 3; i += 1) {
    const result = attempt();
    if (result === "recorded") process.exit(0);
    if (result === "moved" && i >= 1) {
      console.error(`error: ${store} was modified while trust was being recorded; refusing to overwrite it`);
      process.exit(1);
    }
  }
} catch (err) {
  console.error(`error: ${err.message}`);
  process.exit(1);
}
console.error(`error: ${store} did not retain trust for ${paths.join(", ")} after 3 attempts`);
process.exit(1);
NODE
then
  refuse "could not record trust for '$WT_LOGICAL' in '$STORE'"
fi

if [ "$WT_LOGICAL" != "$WT_REAL" ]; then
  echo "trusted: $WT_LOGICAL ($WT_REAL) in $STORE"
else
  echo "trusted: $WT_REAL in $STORE"
fi
