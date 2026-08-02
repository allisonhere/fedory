#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/install/helpers"
printf '%s\n' 'ui_warn() { :; }' >"$tmp_dir/install/helpers/ui.sh"
# The real group predicate, so this exercises the same logic the installer uses
# rather than a stub that could drift from it.
cp "$ROOT_DIR/install/helpers/groups.sh" "$tmp_dir/install/helpers/groups.sh"
cat >"$tmp_dir/bin/systemctl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$SYSTEMCTL_CALLS"
SCRIPT
chmod +x "$tmp_dir/bin/systemctl"

# run_services <disabled-groups> -> path to the recorded systemctl calls
run_services() {
  local calls="$tmp_dir/calls.$RANDOM"
  SYSTEMCTL_CALLS="$calls" \
    FEDORY_INSTALL="$tmp_dir/install" \
    FEDORY_PATH="$ROOT_DIR" \
    FEDORY_DISABLED_GROUPS="$1" \
    FEDORY_GROUPS_STATE="$tmp_dir/no-such-state" \
    PATH="$tmp_dir/bin:$PATH" \
    bash "$ROOT_DIR/install/config/enable-services.sh"
  printf '%s' "$calls"
}

# --- nothing declined ------------------------------------------------------

all_calls=$(run_services "")

gdm_call=$(grep 'gdm.service' "$all_calls")
assert_eq "disable gdm.service" "$gdm_call" "GDM is disabled without terminating the live desktop"

sddm_call=$(grep 'sddm.service' "$all_calls")
assert_eq "enable sddm.service" "$sddm_call" "SDDM is enabled for the next boot"

for unit in cups.service cups-browsed.service avahi-daemon.service docker.socket; do
  if grep -qF "enable $unit" "$all_calls"; then
    echo "ok: $unit is enabled when nothing is declined"
  else
    echo "FAIL: $unit was not enabled despite nothing being declined"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

# --- printing declined -----------------------------------------------------

no_printing=$(run_services "printing")

# cups-browsed and avahi-daemon listen on the network; a user who declined
# printing must not end up running them.
for unit in cups.service cups-browsed.service avahi-daemon.service; do
  if grep -qF "enable $unit" "$no_printing"; then
    echo "FAIL: $unit was enabled after printing was declined"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  else
    echo "ok: $unit is skipped when printing is declined"
  fi
done

if grep -qF "enable docker.socket" "$no_printing"; then
  echo "ok: declining printing leaves docker.socket alone"
else
  echo "FAIL: declining printing also skipped docker.socket"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# --- docker declined -------------------------------------------------------

no_docker=$(run_services "docker")

if grep -qF "enable docker.socket" "$no_docker"; then
  echo "FAIL: docker.socket was enabled after docker was declined"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: docker.socket is skipped when docker is declined"
fi

# Unrelated units must be unaffected by any decline.
for unit in sddm.service NetworkManager.service power-profiles-daemon.service; do
  if grep -qF "enable $unit" "$no_docker"; then
    echo "ok: $unit is enabled regardless of declined groups"
  else
    echo "FAIL: $unit was skipped after an unrelated group was declined"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done

finish
