#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/fedory-cmd-present" <<'EOF'
#!/bin/bash
exit 1
EOF

cat >"$fake_bin/update-noop" <<'EOF'
#!/bin/bash
exit 0
EOF

cat >"$fake_bin/fedory-snapshot" <<'EOF'
#!/bin/bash
exit 127
EOF

cat >"$fake_bin/fedory-update-dev" <<'EOF'
#!/bin/bash
echo "update fallback reached the update body"
EOF

chmod +x "$fake_bin"/*
ln -s /usr/bin/tee "$fake_bin/tee"

noop_commands=(
  fedory-hook
  fedory-migrate
  fedory-update-analyze-logs
  fedory-update-keyring
  fedory-update-lock
  fedory-update-mise
  fedory-update-orphan-pkgs
  fedory-update-requires-free-space
  fedory-update-restart
  fedory-update-status
  fedory-update-stay-awake
  fedory-update-system-pkgs
)

for command in "${noop_commands[@]}"; do
  ln -s update-noop "$fake_bin/$command"
done

update_log="$tmp_dir/update.log"
output=$(
  PATH="$fake_bin" \
    FEDORY_UPDATE_LOG_FILE="$update_log" \
    "$ROOT_DIR/bin/fedory-update" -y
)

assert_eq "update fallback reached the update body" "$output" \
  "updates run without Fedora's optional script command"
assert_eq "$output" "$(<"$update_log")" \
  "the compatibility path still records an update log"

if rg -Fx 'util-linux-script' "$ROOT_DIR/install/fedory-base.packages" >/dev/null; then
  echo "ok: clean installs include the update session logger"
else
  echo "FAIL: clean installs omit util-linux-script"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
