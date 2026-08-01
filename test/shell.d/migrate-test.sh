#!/bin/bash
# Headless end-to-end check of the migration runner: no shipped migrations
# exist yet (see migrations/README.md for why), so this exercises
# fedory-migrate against a synthetic migration in a throwaway
# FEDORY_PATH/HOME, proving the runner mechanism itself works --
# per-user completion markers, --pending reporting, and idempotency on
# rerun -- independent of any specific migration's content.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

export PATH="$ROOT_DIR/bin:$PATH"

fake_fedory_path=$(mktemp -d)
fake_home=$(mktemp -d)
fake_bin=$(mktemp -d)
cleanup() { rm -rf "$fake_fedory_path" "$fake_home" "$fake_bin"; }
trap cleanup EXIT

# Simulate an idle PackageKit daemon. The migration guard must not treat the
# daemon's presence as an active transaction; PackageKit activity is detected
# through RPM's database lock instead. Fake sleep keeps a regression fast
# rather than making the test wait through the full timeout.
cat > "$fake_bin/fuser" <<'EOF'
#!/bin/bash
exit 1
EOF
cat > "$fake_bin/pgrep" <<'EOF'
#!/bin/bash
[[ $* == *"packagekitd"* ]]
EOF
cat > "$fake_bin/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$fake_bin/fuser" "$fake_bin/pgrep" "$fake_bin/sleep"
export PATH="$fake_bin:$PATH"

mkdir -p "$fake_fedory_path/migrations"
marker_file="$fake_home/migration-ran"

# A synthetic migration in the upstream-documented format: 0644, no
# shebang, starts with an echo, idempotent.
cat > "$fake_fedory_path/migrations/1700000000.sh" <<EOF
echo "Synthetic test migration"
echo ran >> "$marker_file"
EOF
chmod 644 "$fake_fedory_path/migrations/1700000000.sh"

export FEDORY_PATH="$fake_fedory_path"
export HOME="$fake_home"

# --pending should report the one pending migration and exit 0.
pending_output=$(fedory-migrate --pending)
pending_status=$?
assert_eq 0 "$pending_status" "fedory-migrate --pending exits 0 when migrations are pending"
assert_eq "1700000000.sh" "$pending_output" "fedory-migrate --pending names the pending migration"

# Running it should execute the migration exactly once and mark it done.
fedory-migrate >/dev/null
assert_file_exists "$fake_home/.local/state/fedory/migrations/1700000000.sh"
if [[ -f $marker_file && $(<"$marker_file") == "ran" ]]; then
  echo "ok: migration body actually executed"
else
  echo "FAIL: migration body did not execute (or ran more than once)"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --pending should now report nothing pending (exit 1, no output).
if fedory-migrate --pending >/tmp/fedory-migrate-test-pending.out 2>&1; then
  echo "FAIL: fedory-migrate --pending exited 0 after the only migration was applied"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
elif [[ -s /tmp/fedory-migrate-test-pending.out ]]; then
  echo "FAIL: fedory-migrate --pending printed output with nothing pending"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: fedory-migrate --pending reports nothing pending after completion"
fi
rm -f /tmp/fedory-migrate-test-pending.out

# Rerunning fedory-migrate must not re-execute the completed migration
# (idempotency: the marker file should still contain exactly one "ran" line).
fedory-migrate >/dev/null
run_count=$(grep -c ran "$marker_file" 2>/dev/null || echo 0)
assert_eq 1 "$run_count" "completed migrations are not re-run on a second fedory-migrate invocation"

finish
