#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

logo="$ROOT_DIR/logo.txt"
assert_file_exists "$logo"
assert_file_exists "$ROOT_DIR/bin/fedory-branding-gradient"

if ! rg -F '▄████████' "$logo" >/dev/null || ! rg -F '▀██████▀' "$logo" >/dev/null; then
  echo "FAIL: terminal logo is missing its block-character letterforms"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: terminal logo uses Omarchy-style block characters"
fi

max_width=$(wc -L <"$logo")
if (( max_width <= 72 )); then
  echo "ok: terminal logo fits within 72 columns"
else
  echo "FAIL: terminal logo is $max_width columns wide"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

for line in \
  '   ▄████████  ▄████████ ████████▄   ▄██████▄     ▄████████ ▄██   ▄' \
  '  ███    ███ ███    ███ ███   ▀███ ███    ███   ███    ███ ███   ██▄' \
  '  ███    █▀  ███    █▀  ███    ███ ███    ███   ███    ███ ███▄▄▄███' \
  ' ▄███▄▄▄    ▄███▄▄▄     ███    ███ ███    ███  ▄███▄▄▄▄██▀ ▀▀▀▀▀▀███' \
  '▀▀███▀▀▀   ▀▀███▀▀▀     ███    ███ ███    ███ ▀▀███▀▀▀▀▀   ▄██   ███' \
  '  ███        ███    █▄  ███    ███ ███    ███ ▀███████████ ███   ███' \
  '  ███        ███    ███ ███   ▄███ ███    ███   ███    ███ ███   ███' \
  '  ███        ██████████ ████████▀   ▀██████▀    ███    ███  ▀█████▀' \
  '                                                ███    ███'; do
  if rg -F "$line" "$ROOT_DIR/bootstrap.sh" >/dev/null; then
    echo "ok: bootstrap ships logo row"
  else
    echo "FAIL: bootstrap logo is missing a canonical row"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

fake_bin=$(mktemp -d)
trap 'rm -rf "$fake_bin"' EXIT

cat >"$fake_bin/fedory-theme-color" <<'FAKE_THEME_COLOR'
#!/bin/bash
case "$1" in
  accent) echo "#010203" ;;
  magenta) echo "#111213" ;;
  cyan) echo "#212223" ;;
esac
FAKE_THEME_COLOR
chmod +x "$fake_bin/fedory-theme-color"

gradient=$(printf 'ABC\n' | PATH="$fake_bin:$PATH" "$ROOT_DIR/bin/fedory-branding-gradient" --force)
if [[ $gradient == *$'\033[1;38;2;1;2;3mA'* &&
  $gradient == *$'\033[1;38;2;17;18;19mB'* &&
  $gradient == *$'\033[1;38;2;33;34;35mC'* ]]; then
  echo "ok: gradient renderer reaches all three theme color stops"
else
  echo "FAIL: gradient renderer did not use the complete theme palette"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

plain=$(printf 'ABC\n' | PATH="$fake_bin:$PATH" "$ROOT_DIR/bin/fedory-branding-gradient")
assert_eq "ABC" "$plain" "redirected logo output remains plain text"

plain=$(printf 'ABC\n' | NO_COLOR=1 PATH="$fake_bin:$PATH" "$ROOT_DIR/bin/fedory-branding-gradient")
assert_eq "ABC" "$plain" "NO_COLOR keeps logo output plain"

for color in 51a2da 8b5cf6 22d3ee; do
  if rg -F "$color" "$ROOT_DIR/bootstrap.sh" >/dev/null; then
    echo "ok: bootstrap includes fallback gradient stop $color"
  else
    echo "FAIL: bootstrap is missing fallback gradient stop $color"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

sddm_logo="$ROOT_DIR/default/sddm/fedory/logo.png"
plymouth_logo="$ROOT_DIR/default/plymouth/logo.png"
assert_file_exists "$sddm_logo"
assert_file_exists "$plymouth_logo"

if cmp -s "$sddm_logo" "$plymouth_logo"; then
  echo "ok: boot and login screens share the current Fedory logo"
else
  echo "FAIL: boot and login screens use different Fedory logos"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if file "$sddm_logo" | rg -F '800 x 188, 8-bit/color RGBA' >/dev/null; then
  echo "ok: pre-session logo preserves its transparent 800x188 contract"
else
  echo "FAIL: pre-session logo has the wrong dimensions or color format"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

login_logo_migration="$ROOT_DIR/migrations/1785601083.sh"
assert_file_exists "$login_logo_migration"
if rg -F '845786a24f19b693de561137b6e489b3afd9c0f27f18aee41623c126d9a103ba' \
  "$login_logo_migration" >/dev/null &&
  rg -F 'pkexec install -m 0644' "$login_logo_migration" >/dev/null; then
  echo "ok: migration updates only the untouched legacy login logo"
else
  echo "FAIL: login logo migration does not guard the privileged replacement"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

migration_home="$fake_bin/migration-home"
branding="$migration_home/.config/fedory/branding/screensaver.txt"
mkdir -p "$(dirname "$branding")"
printf '%s\n' \
  '' \
  '  ==============================================' \
  '   F E D O R Y' \
  '   A beautiful, modern & opinionated Hyprland' \
  '   desktop for Fedora.' \
  '  ==============================================' >"$branding"
HOME="$migration_home" FEDORY_PATH="$ROOT_DIR" \
  bash -euo pipefail "$ROOT_DIR/migrations/1785598347.sh" >/dev/null
if cmp -s "$ROOT_DIR/logo.txt" "$branding"; then
  echo "ok: migration refreshes untouched legacy branding"
else
  echo "FAIL: migration did not refresh untouched legacy branding"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

printf '%s\n' \
  '    ______ __________  ____  ______  __' \
  '   / ____// ____/ __ \/ __ \/ __ \ \/ /' \
  '  / /_   / __/ / / / / / / /_/ /\  /' \
  ' / __/  / /___/ /_/ / /_/ / _, _/ / /' \
  '/_/    /_____/_____/\____/_/ |_| /_/' \
  '' \
  '            FEDORA. REFINED.' >"$branding"
HOME="$migration_home" FEDORY_PATH="$ROOT_DIR" \
  bash -euo pipefail "$ROOT_DIR/migrations/1785598347.sh" >/dev/null
if cmp -s "$ROOT_DIR/logo.txt" "$branding"; then
  echo "ok: migration refreshes the previous slanted Fedory logo"
else
  echo "FAIL: migration did not refresh the previous slanted Fedory logo"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

printf 'my custom logo\n' >"$branding"
HOME="$migration_home" FEDORY_PATH="$ROOT_DIR" \
  bash -euo pipefail "$ROOT_DIR/migrations/1785598347.sh" >/dev/null
assert_eq "my custom logo" "$(<"$branding")" "migration preserves customized branding"

finish
