#!/bin/bash
# Headless end-to-end check of the theme templating engine: runs
# fedory-theme-set-templates against a fake $HOME for two real themes (one
# that leans on the hypr_gradient fallback, one that defines an explicit
# gradient) and asserts the generated output is well-formed. No display or
# Hyprland session required -- see AGENTS.md Tests section.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

export FEDORY_PATH="$ROOT_DIR"
export PATH="$ROOT_DIR/bin:$PATH"

if rg -F 'cp -rL "$FEDORY_THEMES_PATH/$THEME_NAME/"*' \
  "$ROOT_DIR/bin/fedory-theme-set" >/dev/null; then
  echo "ok: theme activation carries linked first-party backgrounds"
else
  echo "FAIL: theme activation does not dereference shared backgrounds"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if rg -F 'fedory-notification-send "No images found"' \
  "$ROOT_DIR/bin/fedory-menu-images" >/dev/null; then
  echo "ok: empty image selectors report why they cannot open"
else
  echo "FAIL: empty image selectors still fail silently"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if [[ $(rg -c 'fedory-theme-set "Fedory Vesper"' "$ROOT_DIR/install/user/theme.sh") == "2" ]] &&
  ! rg -F 'fedory-theme-set "Tokyo Night"' "$ROOT_DIR/install/user/theme.sh" >/dev/null; then
  echo "ok: fresh users default to Fedory Vesper"
else
  echo "FAIL: fresh users do not consistently default to Fedory Vesper"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

vesper_migration_home=$(mktemp -d)
vesper_migration_bin=$(mktemp -d)
mkdir -p "$vesper_migration_home/.local/state/fedory/current"
printf 'fedory-vesper\n' >"$vesper_migration_home/.local/state/fedory/current/theme.name"
ln -s "$vesper_migration_home/missing-background.webp" \
  "$vesper_migration_home/.local/state/fedory/current/background"
cat >"$vesper_migration_bin/fedory-theme-set" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$vesper_migration_home/theme-set"
EOF
chmod +x "$vesper_migration_bin/fedory-theme-set"
HOME="$vesper_migration_home" PATH="$vesper_migration_bin:$PATH" FEDORY_PATH="$ROOT_DIR" \
  bash -euo pipefail "$ROOT_DIR/migrations/1785602840.sh" >/dev/null
assert_eq "Fedory Vesper" "$(<"$vesper_migration_home/theme-set")" \
  "existing Fedory Vesper users migrate away from unsupported WebP"
rm -rf "$vesper_migration_home" "$vesper_migration_bin"

run_templater_for() {
  local theme="$1"
  local fake_home
  fake_home=$(mktemp -d)
  mkdir -p "$fake_home/.local/state/fedory/current/next-theme"
  cp "$ROOT_DIR/themes/$theme/colors.toml" "$fake_home/.local/state/fedory/current/next-theme/"
  HOME="$fake_home" fedory-theme-set-templates
  echo "$fake_home"
}

# tokyo-night has no hyprland_active_border override -- hypr_gradient should
# fall back to `accent` and render a quoted solid color, not a gradient table.
out=$(run_templater_for tokyo-night)
assert_file_exists "$out/.local/state/fedory/current/next-theme/hyprland.lua"
line1=$(head -1 "$out/.local/state/fedory/current/next-theme/hyprland.lua")
if [[ $line1 == 'local active_border_color = "#7aa2f7"' ]]; then
  echo "ok: tokyo-night hypr_gradient fallback renders a solid color"
else
  echo "FAIL: tokyo-night hyprland.lua line 1 was: $line1"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
rm -rf "$out"

# hackerman defines an explicit two-stop gradient -- hypr_gradient should
# render a Lua gradient table with both stops and the angle.
out=$(run_templater_for hackerman)
line1=$(head -1 "$out/.local/state/fedory/current/next-theme/hyprland.lua")
if [[ $line1 == *'colors = { "rgba(26a269ee)", "rgba(2ec27eee)" }'* && $line1 == *'angle = 45'* ]]; then
  echo "ok: hackerman hypr_gradient renders a two-stop gradient table"
else
  echo "FAIL: hackerman hyprland.lua line 1 was: $line1"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
rm -rf "$out"

# Every template should produce output for a theme with no per-file overrides.
out=$(run_templater_for nord)
expected_count=$(ls "$ROOT_DIR/default/themed"/*.tpl | wc -l)
actual_count=$(find "$out/.local/state/fedory/current/next-theme" -maxdepth 1 -type f ! -name colors.toml | wc -l)
assert_eq "$expected_count" "$actual_count" "every .tpl file produces an output file"
rm -rf "$out"

finish
