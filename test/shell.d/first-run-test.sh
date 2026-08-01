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

bash "$ROOT_DIR/install/user/first-run/welcome.sh"
bash "$ROOT_DIR/install/user/first-run/welcome.sh"

assert_file_exists "$fake_home/.local/state/fedory/done/learn-keybindings-invitation"
notification_count=$(wc -l < "$notification_log")
assert_eq 1 "$notification_count" "the keybindings invitation is only shown once"

finish
