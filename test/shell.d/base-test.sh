# Shared helpers for test/shell.d/*-test.sh. Sourced, not executed --
# intentionally no shebang (see AGENTS.md conventions for install/migrations,
# extended here since this file follows the same sourced-helper pattern).

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

ASSERT_FAILURES=0

assert_eq() {
  local expected=$1 actual=$2 msg=${3:-}
  if [[ $expected == "$actual" ]]; then
    echo "ok: ${msg:-$expected == $actual}"
  else
    echo "FAIL: ${msg:-assert_eq} (expected [$expected], got [$actual])"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

assert_file_exists() {
  local path=$1
  if [[ -e $path ]]; then
    echo "ok: exists: $path"
  else
    echo "FAIL: missing: $path"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

finish() {
  if (( ASSERT_FAILURES > 0 )); then
    exit 1
  fi
  exit 0
}
