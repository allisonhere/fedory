# Shared helpers for test/shell.d/*-test.sh. Sourced, not executed --
# intentionally no shebang (see AGENTS.md conventions for install/migrations,
# extended here since this file follows the same sourced-helper pattern).

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ROOT_DIR

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

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  local description=$1 detail=${2:-}

  [[ -n $detail ]] && printf '%s\n' "$detail" >&2
  printf 'not ok - %s\n' "$description" >&2
  exit 1
}

require_command() {
  local command=$1

  command -v "$command" >/dev/null || fail "required command is available: $command"
}

run_node_test() {
  require_command node

  {
    cat <<'JS_PRELUDE'
const path = require('path')
const root = process.env.ROOT_DIR

function fail(description, detail) {
  if (detail) console.error(detail)
  console.error(`not ok - ${description}`)
  process.exit(1)
}

function pass(description) {
  console.log(`ok - ${description}`)
}

function assert(condition, description, detail) {
  if (!condition) fail(description, detail)
  pass(description)
}

function assertEqual(actual, expected, description) {
  assert(actual === expected, description, `expected: ${expected}\nactual:   ${actual}`)
}

function assertDeepEqual(actual, expected, description) {
  const actualJson = JSON.stringify(actual)
  const expectedJson = JSON.stringify(expected)
  assert(actualJson === expectedJson, description, `expected: ${expectedJson}\nactual:   ${actualJson}`)
}

function requireFromRoot(relativePath) {
  return require(path.join(root, relativePath))
}
JS_PRELUDE
    cat
  } | node
}

finish() {
  if (( ASSERT_FAILURES > 0 )); then
    exit 1
  fi
  exit 0
}
