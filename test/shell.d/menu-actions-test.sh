#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

menu_file="$ROOT_DIR/default/fedory/fedory-menu.jsonc"

run_node_test <<'JS'
const fs = require('fs')
const MenuModel = requireFromRoot('shell/plugins/menu/MenuModel.js')
const menuPath = path.join(root, 'default/fedory/fedory-menu.jsonc')
const items = MenuModel.parseMenuJsonc(fs.readFileSync(menuPath, 'utf8'))

assert(items.length > 0, 'the default menu JSONC parses into rows')
assert(items.some(item => item.id === 'apps'), 'the parsed menu contains its Apps root row')
JS

mapfile -t referenced_commands < <(
  rg -o 'fedory-[a-z0-9-]+' "$menu_file" \
    | sort -u \
    | rg -v '^fedory-webapp-handler$'
)

missing_commands=()
for command in "${referenced_commands[@]}"; do
  [[ -x $ROOT_DIR/bin/$command ]] || missing_commands+=("$command")
done

if (( ${#missing_commands[@]} == 0 )); then
  echo "ok: every Fedory command referenced by the menu exists"
else
  printf 'FAIL: menu references missing command: %s\n' "${missing_commands[@]}"
  ASSERT_FAILURES=$((ASSERT_FAILURES + ${#missing_commands[@]}))
fi

unsupported_ids=(
  setup.direct-boot
  install.browser.brave-origin
  install.service.once
  install.service.bitwarden
  install.editor.cursor
  install.editor.sublime
  install.ai
  install.gaming.minecraft
)

for id in "${unsupported_ids[@]}"; do
  if rg -F "\"$id\":" "$menu_file" >/dev/null; then
    echo "FAIL: unsupported menu action remains visible: $id"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  else
    echo "ok: unsupported menu action is hidden: $id"
  fi
done

stale_packages=(
  brave-bin
  brave-origin-bin
  cursor-bin
  heroic-games-launcher-bin
  lmstudio-bin
  microsoft-edge-stable-bin
  minecraft-launcher
  once-bin
  sublime-text-4
  ttf-cascadia-mono-nerd
  ttf-firacode-nerd
  visual-studio-code-bin
  zen-browser-bin
)

for package in "${stale_packages[@]}"; do
  if rg -F "$package" "$menu_file" >/dev/null; then
    echo "FAIL: menu still uses upstream-only package name: $package"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  else
    echo "ok: menu does not use upstream-only package name: $package"
  fi
done

if rg 'JSON::PP' "$ROOT_DIR"/bin/fedory-menu{,-select,-input} >/dev/null; then
  echo "FAIL: menu launchers still require the optional Perl JSON module"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: menu launchers use the base jq dependency for JSON"
fi

fake_bin=$(mktemp -d)
capture_file=$(mktemp)
trap 'rm -rf "$fake_bin"; rm -f "$capture_file"' EXIT

cat >"$fake_bin/fedory-shell" <<'FAKE_SHELL'
#!/bin/bash
set -euo pipefail

payload="${!#}"
printf '%s' "$payload" >"$FEDORY_TEST_CAPTURE"

done_file=$(jq -r '.doneFile // empty' <<<"$payload")
if [[ -n $done_file ]]; then
  selection_file=$(jq -r '.selectionFile' <<<"$payload")
  printf '%s' "${FEDORY_TEST_SELECTION:-}" >"$selection_file"
  touch "$done_file"
fi
FAKE_SHELL
chmod +x "$fake_bin/fedory-shell"

PATH="$fake_bin:$PATH" FEDORY_TEST_CAPTURE="$capture_file" \
  "$ROOT_DIR/bin/fedory-menu" summon 'style.quo"te'
assert_eq 'style.quo"te' "$(jq -r '.menu' "$capture_file")" "menu routes are JSON encoded"

selection=$(
  PATH="$fake_bin:$PATH" \
    FEDORY_TEST_CAPTURE="$capture_file" \
    FEDORY_TEST_SELECTION=$'snow \u2603' \
    "$ROOT_DIR/bin/fedory-menu-select" 'Pick "one"' alpha $'snow \u2603' -- --width 400 --maxheight 500
)
assert_eq $'snow \u2603' "$selection" "menu select returns Unicode choices"
assert_eq 'Pick "one"' "$(jq -r '.prompt' "$capture_file")" "menu select escapes its prompt"
assert_eq $'snow \u2603' "$(jq -r '.options[1]' "$capture_file")" "menu select preserves Unicode options"
assert_eq "400:500" "$(jq -r '"\(.width):\(.maxHeight)"' "$capture_file")" "menu select sends numeric dimensions"

selection=$(
  PATH="$fake_bin:$PATH" \
    FEDORY_TEST_CAPTURE="$capture_file" \
    FEDORY_TEST_SELECTION='five minutes' \
    "$ROOT_DIR/bin/fedory-menu-input" 'Reminder "when"' --width 360
)
assert_eq "five minutes" "$selection" "menu input returns entered text"
assert_eq 'Reminder "when"' "$(jq -r '.prompt' "$capture_file")" "menu input escapes its prompt"
assert_eq "360" "$(jq -r '.width' "$capture_file")" "menu input sends a numeric width"

finish
