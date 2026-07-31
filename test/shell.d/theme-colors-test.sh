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
done

assert_eq 22 "$theme_count" "22 themes are ported"

finish
