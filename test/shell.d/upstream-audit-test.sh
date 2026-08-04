#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

upstream_repo="$tmp_dir/omarchy"
mkdir -p "$upstream_repo"
git -C "$upstream_repo" init -q -b main
git -C "$upstream_repo" config user.name "Fedory Test"
git -C "$upstream_repo" config user.email "fedory-test@example.com"

mkdir -p "$upstream_repo/bin" "$upstream_repo/config" "$upstream_repo/.claude"
printf '%s\n' '#!/bin/bash' 'echo old' >"$upstream_repo/bin/omarchy-example"
printf '%s\n' 'old=true' >"$upstream_repo/config/example.conf"
printf '%s\n' 'ignored' >"$upstream_repo/.claude/settings"
git -C "$upstream_repo" add .
git -C "$upstream_repo" commit -q -m "Initial upstream state"
base_commit=$(git -C "$upstream_repo" rev-parse HEAD)

printf '%s\n' '#!/bin/bash' 'echo new' >"$upstream_repo/bin/omarchy-example"
printf '%s\n' 'new=true' >"$upstream_repo/config/new.conf"
printf '%s\n' 'changed' >"$upstream_repo/.claude/settings"
git -C "$upstream_repo" add .
git -C "$upstream_repo" commit -q -m "Change commands and config"
target_commit=$(git -C "$upstream_repo" rev-parse HEAD)

version_file="$tmp_dir/UPSTREAM_VERSION"
cat >"$version_file" <<EOF
repository=$upstream_repo
ref=main
commit=$base_commit
reviewed_at=2026-07-31
EOF

report="$tmp_dir/report.md"
audit_status=0
FEDORY_PATH="$ROOT_DIR" \
  FEDORY_UPSTREAM_VERSION_FILE="$version_file" \
  FEDORY_UPSTREAM_CACHE="$tmp_dir/cache.git" \
  "$ROOT_DIR/bin/fedory-dev-upstream-audit" \
    --target main \
    --output "$report" \
    --exit-code || audit_status=$?

assert_eq "10" "$audit_status" "upstream drift has a distinct exit status"
assert_eq "3" "$(sed -n 's/^- Changed paths: //p' "$report")" "audit counts changed paths"

if rg -F '| `M` | `bin/omarchy-example` | `bin/omarchy-example` |' "$report" >/dev/null; then
  echo "FAIL: Omarchy command path was not translated to Fedory"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
elif rg -F '| `M` | `bin/omarchy-example` | `bin/fedory-example` |' "$report" >/dev/null; then
  echo "ok: command changes require a Fedora rewrite with a translated path"
else
  echo "FAIL: command change is missing its Fedora rewrite classification"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if rg -F '| `A` | `config/new.conf` | `config/new.conf` |' "$report" >/dev/null; then
  echo "ok: config changes are direct port candidates"
else
  echo "FAIL: config change is missing its direct-port classification"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if rg -F '| `M` | `.claude/settings` | `-` |' "$report" >/dev/null; then
  echo "ok: ignored upstream metadata remains visible in the report"
else
  echo "FAIL: ignored metadata is not reported"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if rg -F '## Manual review' "$report" >/dev/null; then
  echo "FAIL: audit renders an empty manual-review section"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: audit omits empty policy sections"
fi

sed -i "s/^commit=.*/commit=$target_commit/" "$version_file"
audit_status=0
FEDORY_PATH="$ROOT_DIR" \
  FEDORY_UPSTREAM_VERSION_FILE="$version_file" \
  FEDORY_UPSTREAM_CACHE="$tmp_dir/cache.git" \
  "$ROOT_DIR/bin/fedory-dev-upstream-audit" \
    --target main \
    --output "$report" \
    --exit-code || audit_status=$?

assert_eq "0" "$audit_status" "matching upstream checkpoint exits successfully"
assert_eq "0" "$(sed -n 's/^- Changed paths: //p' "$report")" "matching checkpoint reports no drift"

finish
