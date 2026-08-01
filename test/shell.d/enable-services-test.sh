#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/install/helpers"
printf '%s\n' 'ui_warn() { :; }' >"$tmp_dir/install/helpers/ui.sh"
cat >"$tmp_dir/bin/systemctl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$SYSTEMCTL_CALLS"
SCRIPT
chmod +x "$tmp_dir/bin/systemctl"

SYSTEMCTL_CALLS="$tmp_dir/systemctl-calls" \
  FEDORY_INSTALL="$tmp_dir/install" \
  PATH="$tmp_dir/bin:$PATH" \
  bash "$ROOT_DIR/install/config/enable-services.sh"

gdm_call=$(grep 'gdm.service' "$tmp_dir/systemctl-calls")
assert_eq "disable gdm.service" "$gdm_call" "GDM is disabled without terminating the live desktop"

sddm_call=$(grep 'sddm.service' "$tmp_dir/systemctl-calls")
assert_eq "enable sddm.service" "$sddm_call" "SDDM is enabled for the next boot"

finish
