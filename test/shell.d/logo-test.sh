#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

logo="$ROOT_DIR/logo.txt"
assert_file_exists "$logo"

if LC_ALL=C rg '[^ -~\n]' "$logo" >/dev/null; then
  echo "FAIL: terminal logo contains non-ASCII characters"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: terminal logo is pure ASCII"
fi

max_width=$(wc -L <"$logo")
if (( max_width <= 50 )); then
  echo "ok: terminal logo fits within 50 columns"
else
  echo "FAIL: terminal logo is $max_width columns wide"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

for line in \
  '    ______ __________  ____  ______  __' \
  '   / ____// ____/ __ \/ __ \/ __ \ \/ /' \
  '  / /_   / __/ / / / / / / /_/ /\  /' \
  ' / __/  / /___/ /_/ / /_/ / _, _/ / /' \
  '/_/    /_____/_____/\____/_/ |_| /_/'; do
  if rg -F "$line" "$ROOT_DIR/bootstrap.sh" >/dev/null; then
    echo "ok: bootstrap ships logo row"
  else
    echo "FAIL: bootstrap logo is missing a canonical row"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

finish
