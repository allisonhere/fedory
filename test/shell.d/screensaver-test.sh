#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

assert_file_exists "$ROOT_DIR/default/alacritty/screensaver.toml"
assert_file_exists "$ROOT_DIR/default/foot/screensaver.ini"
assert_file_exists "$ROOT_DIR/default/ghostty/screensaver"

mkdir -p "$tmp_dir/home"
if HOME="$tmp_dir/home" FEDORY_PATH="$tmp_dir/missing-fedory" \
  "$ROOT_DIR/bin/fedory-screensaver" >"$tmp_dir/output" 2>&1; then
  echo "FAIL: screensaver starts without its branding source"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  assert_eq "1" "$(wc -l <"$tmp_dir/output")" \
    "missing screensaver branding fails once instead of looping"
fi

finish
