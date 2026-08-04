#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text())' \
  "$ROOT_DIR/applications/fedory-calculator/calculator.py" || {
  echo "FAIL: Fedory calculator Python source does not compile"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
}

if rg -q 'omarchy|\.config/omarchy|OmaCalc' "$ROOT_DIR/applications/fedory-calculator/calculator.py"; then
  echo "FAIL: calculator retains an upstream runtime path or name"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: calculator uses Fedory runtime paths and names"
fi

if rg -q 'Exec=fedory-calculator' "$ROOT_DIR/applications/fedory-calculator/calculator.py"; then
  echo "ok: calculator installs a stable Fedory autostart command"
else
  echo "FAIL: calculator autostart does not use its Fedory wrapper"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

fake_home=$(mktemp -d)
trap 'rm -rf "$fake_home"' EXIT
mkdir -p "$fake_home/.local/state/fedory/current/theme" "$fake_home/.claude"
printf '%s\n' '{"name":"Fedory"}' >"$fake_home/.local/state/fedory/current/theme/claude.json"
printf '%s\n' '{"theme":"dark","other":true}' >"$fake_home/.claude/settings.json"

HOME="$fake_home" "$ROOT_DIR/bin/fedory-theme-set-claude" --activate
assert_file_exists "$fake_home/.claude/themes/fedory.json"
assert_eq "custom:fedory" "$(jq -r .theme "$fake_home/.claude/settings.json")" \
  "Claude activates the generated Fedory theme"
assert_eq "true" "$(jq -r .other "$fake_home/.claude/settings.json")" \
  "Claude theme activation preserves unrelated settings"

finish
