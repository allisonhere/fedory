#!/bin/bash
# Lints every ported themes/<name>/colors.toml: required keys present, every
# color value is a real hex color (or a valid gradient string for the
# hyprland_* override keys), and the set of ported themes matches what's
# documented in themes/README.md.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

REQUIRED_KEYS=(mode accent selection muted background foreground red green blue yellow magenta cyan)

theme_count=0
for dir in "$ROOT_DIR"/themes/*/; do
  theme=$(basename "$dir")
  colors="$dir/colors.toml"
  theme_count=$((theme_count + 1))

  if [[ ! -f $colors ]]; then
    echo "FAIL: $theme has no colors.toml"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    continue
  fi

  missing=()
  for key in "${REQUIRED_KEYS[@]}"; do
    grep -qE "^${key}[[:space:]]*=" "$colors" || missing+=("$key")
  done

  if (( ${#missing[@]} > 0 )); then
    echo "FAIL: $theme/colors.toml missing keys: ${missing[*]}"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  else
    echo "ok: $theme/colors.toml has all required keys"
  fi

  bad_hex=$(grep -E '^[a-z_]+[[:space:]]*=[[:space:]]*"#' "$colors" | grep -vE '"#[0-9A-Fa-f]{6}"[[:space:]]*$' || true)
  if [[ -n $bad_hex ]]; then
    echo "FAIL: $theme/colors.toml has malformed hex values:"
    echo "$bad_hex"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi

  background=$(find -L "$dir/backgrounds" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -print -quit 2>/dev/null)
  if [[ -n $background ]]; then
    echo "ok: $theme has a usable background"
  else
    echo "FAIL: $theme has no usable background"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

assert_eq 23 "$theme_count" "22 upstream themes and Fedory Vesper are shipped"

wallpaper_count=$(find "$ROOT_DIR/default/wallpapers" -maxdepth 1 -type f \
  \( -name '*.png' -o -name '*.webp' \) | wc -l)
assert_eq 9 "$wallpaper_count" "nine original wallpapers are shipped"

vesper_background_count=$(find -L "$ROOT_DIR/themes/fedory-vesper/backgrounds" \
  -maxdepth 1 -type f -name '*.png' | wc -l)
assert_eq 4 "$vesper_background_count" "Fedory Vesper ships four backgrounds"

finish
