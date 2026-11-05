#!/usr/bin/env bash
# Behavior tests for pkgs/vscode-update-mode.
# Usage: tests/vscode-update-mode.sh PATH_TO_vscode-update-mode
set -euo pipefail

BIN="$1"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
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

# check DESCRIPTION EXPECTED_EXIT FILE EXPECTED_CONTENT
# Runs the script on FILE, then compares its exit code and FILE's content.
check() {
  local status=0
  "$BIN" "$3" >"$WORK/out" 2>&1 || status=$?
  if [ "$status" -eq "$2" ] && [ "$(cat "$3")" = "$4" ]; then
    print_result 0 "$1"
  else
    print_result 1 "$1 (exit $status)"
    cat "$WORK/out"
    cat "$3"
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

# Key already set: the file is not rewritten.
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

# Invalid input: refused, file untouched.
printf '{"a": ' >"$WORK/invalid.json"
check "invalid JSON is refused" 1 "$WORK/invalid.json" '{"a": '
printf '[1]' >"$WORK/array.json"
check "non-object JSON is refused" 1 "$WORK/array.json" '[1]'
printf '// only a comment' >"$WORK/comment.json"
check "comment-only file is refused" 1 "$WORK/comment.json" '// only a comment'
printf '{} {}' >"$WORK/two.json"
check "multiple JSON values are refused" 1 "$WORK/two.json" '{} {}'
printf '{"update.mode": "default", "update.mode": "manual"}' >"$WORK/dup.json"
check "duplicate key is refused" 1 "$WORK/dup.json" '{"update.mode": "default", "update.mode": "manual"}'

# Symlink (e.g. from programs.vscode.userSettings): refused, target untouched.
printf '{}' >"$WORK/target.json"
ln -s "$WORK/target.json" "$WORK/link.json"
check "symlink is refused" 1 "$WORK/link.json" '{}'

# No temporary files are left behind.
if [ -z "$(find "$WORK" -name '*.tmp')" ]; then
  print_result 0 "no temporary files left behind"
else
  print_result 1 "no temporary files left behind"
fi

echo "$((TOTAL_TESTS - FAILED_TESTS))/$TOTAL_TESTS passed"
[ "$FAILED_TESTS" -eq 0 ]
