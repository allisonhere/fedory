#!/bin/bash
# Sanity-checks the Phase 0 repo scaffold itself.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

assert_file_exists "$ROOT_DIR/AGENTS.md"
assert_file_exists "$ROOT_DIR/README.md"
assert_file_exists "$ROOT_DIR/LICENSE"
assert_file_exists "$ROOT_DIR/version"

version=$(<"$ROOT_DIR/version")
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "ok: version file is semver-ish: $version"
else
  echo "FAIL: version file is not semver-ish: $version"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

for dir in bin install packaging migrations config default etc applications themes shell test; do
  assert_file_exists "$ROOT_DIR/$dir"
done

finish
