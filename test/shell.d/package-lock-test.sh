#!/bin/bash
# Covers install/helpers/package-lock.sh, the guard that keeps a Fedory dnf
# transaction from racing one that already holds RPM's database lock.
#
# Regression origin: a bootstrap run lost this race against PackageKit's
# boot-time refresh. dnf aborted the whole 386-package transaction with
# "Failed to obtain rpm transaction lock", 65 packages including sddm never
# installed, and the only visible error was install/login/sddm.sh failing to
# copy its theme into a /usr/share/sddm that had never been created. The guard
# existed at the time, but only bin/fedory-migrate used it.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

fake_bin=$(mktemp -d)
work_dir=$(mktemp -d)
cleanup() { rm -rf "$fake_bin" "$work_dir"; }
trap cleanup EXIT

# Fake sleep keeps the timeout cases instant instead of making the suite wait.
cat > "$fake_bin/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF

# fuser reports the lock as held for as many calls as $work_dir/hold says,
# counting down on each call. 0 means "lock is free".
cat > "$fake_bin/fuser" <<'EOF'
#!/bin/bash
hold_file="$FEDORY_TEST_WORK/hold"
remaining=$(<"$hold_file")
if (( remaining > 0 )); then
  printf '%s\n' "$(( remaining - 1 ))" > "$hold_file"
  exit 0
fi
exit 1
EOF

# An idle packagekitd must not read as an active transaction.
cat > "$fake_bin/pgrep" <<'EOF'
#!/bin/bash
[[ $* == *"packagekitd"* ]]
EOF

chmod +x "$fake_bin/sleep" "$fake_bin/fuser" "$fake_bin/pgrep"
export PATH="$fake_bin:$PATH"
export FEDORY_TEST_WORK="$work_dir"

# Point the guard at a lock file that exists, so the fuser branch is reachable
# on a non-Fedora test host.
export FEDORY_RPM_LOCK="$work_dir/.rpm.lock"
touch "$FEDORY_RPM_LOCK"

source "$ROOT_DIR/install/helpers/package-lock.sh"

# An unheld lock should return immediately and print nothing.
printf '0\n' > "$work_dir/hold"
output=$(wait_for_package_transaction "test" 5)
status=$?
assert_eq 0 "$status" "returns 0 when no transaction holds the lock"
assert_eq "" "$output" "stays quiet when there is nothing to wait for"

# A lock held for a few polls should be waited out, then succeed.
printf '3\n' > "$work_dir/hold"
output=$(wait_for_package_transaction "test" 30)
status=$?
assert_eq 0 "$status" "returns 0 once a held lock is released"
case "$output" in
  *"Waiting for a dnf/rpm transaction"*)
    echo "ok: announces that it is waiting on the lock" ;;
  *)
    echo "FAIL: did not announce waiting (got: $output)"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

# Regression: the first version printed one line and then waited silently for
# up to 15 minutes, which read as a hung installer. Each poll must emit a
# [waited/timeout] marker so run_logged's renderer shows the wait counting
# down rather than a frozen screen.
case "$output" in
  *'[0/30]'*) echo "ok: the wait emits progress markers" ;;
  *) echo "FAIL: no [waited/timeout] marker in the wait output (got: $output)"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

# The default ceiling must stay short enough that a stuck lock does not look
# like a hang. Called with no explicit timeout, a never-clearing lock has to
# give up promptly rather than sit for a quarter of an hour.
printf '999\n' > "$work_dir/hold"
default_output=$(wait_for_package_transaction "test")
case "$default_output" in
  *'/120]'*) echo "ok: the default wait ceiling is 120s" ;;
  *) echo "FAIL: unexpected default timeout (got: $(printf '%s' "$default_output" | head -1))"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

# A lock that never clears must give up and return 1 -- not exit, which would
# kill whichever script sourced the helper.
printf '999\n' > "$work_dir/hold"
wait_for_package_transaction "test" 3 >/dev/null
status=$?
assert_eq 1 "$status" "returns 1 (does not exit) when the lock never clears"

# Regression: an idle packagekitd daemon is not a transaction. With the lock
# file absent the guard falls through to pgrep, which must ignore packagekitd.
rm -f "$FEDORY_RPM_LOCK"
wait_for_package_transaction "test" 3 >/dev/null
status=$?
assert_eq 0 "$status" "an idle packagekitd is not treated as an active transaction"

finish
