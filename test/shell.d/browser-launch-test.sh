#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

fake_bin=$(mktemp -d)
fake_home=$(mktemp -d)
launch_log="$fake_home/launch.log"
cleanup() { rm -rf "$fake_bin" "$fake_home"; }
trap cleanup EXIT

cat > "$fake_bin/xdg-settings" <<'EOF'
#!/bin/bash
echo org.chromium.Chromium.desktop
EOF
cat > "$fake_bin/setsid" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > "$launch_log"
EOF
cat > "$fake_bin/systemd-run" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > "$launch_log"
EOF
cat > "$fake_bin/flatpak" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > "$launch_log"
EOF
chmod +x "$fake_bin/xdg-settings" "$fake_bin/setsid" "$fake_bin/systemd-run" "$fake_bin/flatpak"

export HOME="$fake_home"
export PATH="$fake_bin:$ROOT_DIR/bin:$PATH"
unset HYPRLAND_INSTANCE_SIGNATURE

fedory-launch-webapp https://example.com >/dev/null
webapp_launch=$(<"$launch_log")
assert_eq "uwsm app -- fedory-launch-chromium --app=https://example.com" \
  "$webapp_launch" "Flatpak Chromium receives the web-app URL after its app ID"

fedory-launch-browser --private https://example.com >/dev/null
browser_launch=$(<"$launch_log")
if [[ $browser_launch == *"uwsm app -- fedory-launch-chromium --incognito https://example.com" ]]; then
  echo "ok: Flatpak Chromium receives browser flags after its app ID"
else
  echo "FAIL: Flatpak Chromium browser launch is malformed: $browser_launch"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

mkdir -p "$HOME/.config"
printf '%s\n' '# comment' '--enable-wayland-ime' '--wayland-text-input-version=3' \
  '--load-extension=/usr/share/fedory/missing' >"$HOME/.config/chromium-flags.conf"
fedory-launch-chromium https://example.com
chromium_launch=$(<"$launch_log")
assert_eq "run org.chromium.Chromium --enable-wayland-ime --wayland-text-input-version=3 https://example.com" \
  "$chromium_launch" "Flatpak Chromium receives configured host flags"

finish
