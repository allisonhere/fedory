#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

fake_home=$(mktemp -d)
fake_bin=$(mktemp -d)
notification_log="$fake_home/notifications"
cleanup() { rm -rf "$fake_home" "$fake_bin"; }
trap cleanup EXIT

cat > "$fake_bin/fedory-notification-send" <<EOF
#!/bin/bash
echo shown >> "$notification_log"
EOF
chmod +x "$fake_bin/fedory-notification-send"

export HOME="$fake_home"
export PATH="$fake_bin:$ROOT_DIR/bin:$PATH"

# Existing users have already seen this invitation, so the update migration
# records it before first-run retries on their next login.
bash -euo pipefail "$ROOT_DIR/migrations/1785591425.sh" >/dev/null
assert_file_exists "$fake_home/.local/state/fedory/done/learn-keybindings-invitation"
rm "$fake_home/.local/state/fedory/done/learn-keybindings-invitation"

bash "$ROOT_DIR/install/user/first-run/welcome.sh"
bash "$ROOT_DIR/install/user/first-run/welcome.sh"

assert_file_exists "$fake_home/.local/state/fedory/done/learn-keybindings-invitation"
notification_count=$(wc -l < "$notification_log")
assert_eq 1 "$notification_count" "the keybindings invitation is only shown once"

# --- the update invitation -------------------------------------------------
#
# Reported symptom: after updating and rebooting, the "Update System" toast
# kept coming back on a machine with nothing to update. Two causes -- the toast
# never checked whether updates existed, and unlike welcome.sh it had no
# once-marker, so every fedory-first-run retry re-sent it.

cat > "$fake_bin/ping" <<'EOF'
#!/bin/bash
exit 0
EOF
cat > "$fake_bin/fedory-launch-floating-terminal-with-presentation" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$fake_bin/ping" "$fake_bin/fedory-launch-floating-terminal-with-presentation"

set_updates_available() {
  cat > "$fake_bin/fedory-update-available" <<EOF
#!/bin/bash
exit $1
EOF
  chmod +x "$fake_bin/fedory-update-available"
}

# Nothing to update: the toast must not appear at all.
: > "$notification_log"
set_updates_available 1
bash "$ROOT_DIR/install/user/first-run/wifi.sh"
sleep 0.5
assert_eq 0 "$(wc -l < "$notification_log")" \
  "no update toast when there is nothing to update"

# With updates pending it appears -- once, however many times first-run retries.
: > "$notification_log"
rm -f "$fake_home/.local/state/fedory/done/update-system-invitation"
set_updates_available 0
bash "$ROOT_DIR/install/user/first-run/wifi.sh"
sleep 0.5
assert_eq 1 "$(wc -l < "$notification_log")" \
  "the update invitation appears when updates are pending"

bash "$ROOT_DIR/install/user/first-run/wifi.sh"
bash "$ROOT_DIR/install/user/first-run/wifi.sh"
sleep 0.5
assert_eq 1 "$(wc -l < "$notification_log")" \
  "the update invitation is not repeated on first-run retries"

# --- steps that must not fail the whole run --------------------------------
#
# fedory-first-run only marks itself complete when every step succeeds, so a
# step that fails on every machine keeps first-run replaying forever. These two
# did exactly that: the user units are not ported yet, and no audio tunings
# ship at all.

cat > "$fake_bin/systemctl" <<'EOF'
#!/bin/bash
# No unit files exist in this environment.
[[ ${1:-} == "--user" && ${2:-} == "cat" ]] && exit 1
exit 0
EOF
chmod +x "$fake_bin/systemctl"

units_output=$(bash "$ROOT_DIR/install/user/first-run/enable-user-units.sh" 2>&1)
units_status=$?
assert_eq 0 "$units_status" "missing user units do not fail first-run"
case "$units_output" in
  *"Not installed on this system"*) echo "ok: missing user units are reported, not hidden" ;;
  *) echo "FAIL: missing units were skipped silently (got: $units_output)"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

empty_fedory=$(mktemp -d)
FEDORY_PATH="$empty_fedory" bash "$ROOT_DIR/bin/fedory-audio-tuning" on >/dev/null 2>&1
tuning_status=$?
rm -rf "$empty_fedory"
assert_eq 0 "$tuning_status" "shipping no audio tunings does not fail first-run"

finish
