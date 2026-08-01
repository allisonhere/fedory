#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/fedory/applications" "$tmpdir/home" "$tmpdir/bin"
cat >"$tmpdir/bin/update-desktop-database" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$tmpdir/bin/update-desktop-database"

if HOME="$tmpdir/home" FEDORY_PATH="$tmpdir/fedory" PATH="$tmpdir/bin:$PATH" \
  bash "$ROOT_DIR/bin/fedory-refresh-applications"; then
  echo "ok: application refresh accepts an empty launcher directory"
else
  echo "FAIL: application refresh failed for an empty launcher directory"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

touch "$tmpdir/fedory/applications/example.desktop"
HOME="$tmpdir/home" FEDORY_PATH="$tmpdir/fedory" PATH="$tmpdir/bin:$PATH" \
  bash "$ROOT_DIR/bin/fedory-refresh-applications"
assert_file_exists "$tmpdir/home/.local/share/applications/example.desktop"

finish
