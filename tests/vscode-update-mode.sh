#!/usr/bin/env bash
# Behavior tests for pkgs/vscode-update-mode.
# Usage: tests/vscode-update-mode.sh PATH_TO_vscode-update-mode
set -euo pipefail

BIN="$1"
WORK="$(mktemp -d)"
trap 'chmod -R u+rwx "$WORK"; rm -rf "$WORK"' EXIT
FAILED_TESTS=0
TOTAL_TESTS=0

print_result() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

# check DESCRIPTION EXPECTED_EXIT FILE EXPECTED_CONTENT [FLAG...]
# Runs the script with FLAGs on FILE, then compares its exit code and FILE's
# content.
check() {
  local description="$1" expected_exit="$2" file="$3" expected="$4"
  shift 4
  local status=0 actual
  "$BIN" "$@" "$file" >"$WORK/out" 2>&1 || status=$?
  actual="$(cat "$file" 2>/dev/null || true)"
  if [ "$status" -eq "$expected_exit" ] && [ "$actual" = "$expected" ]; then
    print_result 0 "$description"
  else
    print_result 1 "$description (exit $status)"
    cat "$WORK/out"
    echo "$actual"
  fi
}

# check_warns DESCRIPTION FILE EXPECTED_CONTENT [ENV...]
# Default (activation) mode: exits 0, leaves FILE as EXPECTED_CONTENT, warns.
check_warns() {
  local description="$1" file="$2" expected="$3"
  shift 3
  local status=0
  env "$@" "$BIN" "$file" >"$WORK/out" 2>&1 || status=$?
  if [ "$status" -eq 0 ] && [ "$(cat "$file" 2>/dev/null || true)" = "$expected" ] && grep -q 'vscode-update-mode: warning:' "$WORK/out"; then
    print_result 0 "$description"
  else
    print_result 1 "$description (exit $status)"
    cat "$WORK/out"
  fi
}

# Missing file, in a missing directory: created with just the key.
missing="$WORK/missing/Code/User/settings.json"
check "missing file is created" 0 "$missing" "$(printf '{\n  "update.mode": "none"\n}')"

# File without the key: key added first, everything else kept as written.
printf '{\n  "b": 1,\n  "a": {"x": [1, 2]},\n  "n": 1.000000000000000001\n}\n' >"$WORK/nokey.json"
chmod 640 "$WORK/nokey.json"
check "key is added, other keys kept" 0 "$WORK/nokey.json" "$(printf '{\n  "update.mode": "none",\n  "b": 1,\n  "a": {"x": [1, 2]},\n  "n": 1.000000000000000001\n}')"
if [ "$(stat -c %a "$WORK/nokey.json" 2>/dev/null || stat -f %Lp "$WORK/nokey.json")" = 640 ]; then
  print_result 0 "file mode is kept"
else
  print_result 1 "file mode is kept"
fi

# Tab-indented file: the key is indented the same way.
printf '{\n\t"a": 1\n}' >"$WORK/tabs.json"
check "tab indentation is followed" 0 "$WORK/tabs.json" "$(printf '{\n\t"update.mode": "none",\n\t"a": 1\n}')"

# Key with another value: only the value changes.
printf '{\n  "a": 1,\n  "update.mode": "default" // why\n}' >"$WORK/other.json"
check "other value is replaced" 0 "$WORK/other.json" "$(printf '{\n  "a": 1,\n  "update.mode": "none" // why\n}')"

# Key already set: the file is not rewritten, and nothing is printed.
printf '{ "a": 1,   "update.mode": "none", }\n' >"$WORK/set.json"
touch -t 200001010000 "$WORK/set.json"
check "already-set file is untouched" 0 "$WORK/set.json" '{ "a": 1,   "update.mode": "none", }'
if [ -z "$(find "$WORK/set.json" -newermt 2000-01-02)" ]; then
  print_result 0 "already-set file is not rewritten"
else
  print_result 1 "already-set file is not rewritten"
fi

# Empty file: treated as {}.
: >"$WORK/empty.json"
check "empty file gets the key" 0 "$WORK/empty.json" "$(printf '{\n  "update.mode": "none"\n}')"

# JSONC (comments, trailing commas): edited in place, comments kept.
printf '{\n  // comment\n  /* block */\n  "a": {\n    "b": 1,\n  },\n}' >"$WORK/jsonc.json"
check "JSONC is edited, comments and trailing commas kept" 0 "$WORK/jsonc.json" "$(printf '{\n  "update.mode": "none",\n  // comment\n  /* block */\n  "a": {\n    "b": 1,\n  },\n}')"

# Refusals: with --strict they fail; by default (activation) they warn and
# exit 0. Either way the file is left as it was.
refuse() {
  local description="$1" file="$2" content="$3"
  printf '%s' "$content" >"$file"
  check "$description is refused with --strict" 1 "$file" "$content" --strict
  check_warns "$description only warns by default" "$file" "$content"
}
refuse "invalid JSON" "$WORK/invalid.json" '{"a": '
refuse "non-object JSON" "$WORK/array.json" '[1]'
refuse "comment-only file" "$WORK/comment.json" '// only a comment'
refuse "multiple JSON values" "$WORK/two.json" '{} {}'
refuse "duplicate key" "$WORK/dup.json" '{"update.mode": "default", "update.mode": "manual"}'

# Symlink (e.g. from programs.vscode.userSettings): skipped, target untouched.
printf '{}' >"$WORK/target.json"
ln -s "$WORK/target.json" "$WORK/link.json"
check "symlink is refused with --strict" 1 "$WORK/link.json" '{}' --strict
check_warns "symlink only warns by default" "$WORK/link.json" '{}'

# Unexpected errors (EACCES) only warn by default, and fail with --strict.
printf '{"a": 1}' >"$WORK/unreadable.json"
chmod 000 "$WORK/unreadable.json"
if [ -r "$WORK/unreadable.json" ]; then
  echo "SKIP: unreadable file (running as root)"
else
  check "unreadable file fails with --strict" 1 "$WORK/unreadable.json" "" --strict
  check_warns "unreadable file only warns by default" "$WORK/unreadable.json" ""
fi
chmod 600 "$WORK/unreadable.json"
mkdir "$WORK/readonly"
printf '{"a": 1}' >"$WORK/readonly/settings.json"
chmod 555 "$WORK/readonly"
if [ -w "$WORK/readonly" ]; then
  echo "SKIP: read-only directory (running as root)"
else
  check_warns "read-only directory only warns by default" "$WORK/readonly/settings.json" '{"a": 1}'
fi
chmod 755 "$WORK/readonly"

# Races with a concurrent writer such as VS Code, injected with a preload
# hook: the writer wins and the script only warns.
cat >"$WORK/hook.js" <<'EOF'
const fs = require("fs");
const target = process.env.HOOK_TARGET;
const once = (name, action) => {
  const original = fs[name];
  fs[name] = function (...args) {
    fs[name] = original;
    const result = original.apply(this, args);
    action();
    return result;
  };
};
switch (process.env.HOOK) {
  case "create": // the file appears after the directory is created
    once("mkdirSync", () => fs.writeFileSync(target, '{"vscode": 1}'));
    break;
  case "size": // the file is rewritten after the temp file is synced
    once("fsyncSync", () => fs.writeFileSync(target, '{"vscode": 22}'));
    break;
  case "mtime": // same size, new modification time
    once("fsyncSync", () => fs.utimesSync(target, 1e9, 1e9));
    break;
}
EOF
check_warns "file created concurrently is left to the other writer" "$WORK/race-create/settings.json" '{"vscode": 1}' \
  NODE_OPTIONS="--require $WORK/hook.js" HOOK=create HOOK_TARGET="$WORK/race-create/settings.json"
printf '{"a": 1}' >"$WORK/race-size.json"
check_warns "file rewritten during the update is left alone" "$WORK/race-size.json" '{"vscode": 22}' \
  NODE_OPTIONS="--require $WORK/hook.js" HOOK=size HOOK_TARGET="$WORK/race-size.json"
printf '{"a": 1}' >"$WORK/race-mtime.json"
check_warns "file touched during the update is left alone" "$WORK/race-mtime.json" '{"a": 1}' \
  NODE_OPTIONS="--require $WORK/hook.js" HOOK=mtime HOOK_TARGET="$WORK/race-mtime.json"

# No temporary files are left behind.
if [ -z "$(find "$WORK" -name '*.tmp')" ]; then
  print_result 0 "no temporary files left behind"
else
  print_result 1 "no temporary files left behind"
fi

echo "$((TOTAL_TESTS - FAILED_TESTS))/$TOTAL_TESTS passed"
[ "$FAILED_TESTS" -eq 0 ]
