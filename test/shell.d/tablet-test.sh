#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"
export ROOT_DIR

tmp=$(mktemp -d)
fake_bin="$tmp/bin"
fake_sys="$tmp/sys"
fake_home="$tmp/home"
log="$tmp/log"
mkdir -p "$fake_bin" "$fake_sys/class/dmi/id" "$fake_home"
trap 'rm -rf "$tmp"' EXIT

make_fake() {
  local name=$1 body=$2
  printf '#!/bin/bash\n%s\n' "$body" >"$fake_bin/$name"
  chmod +x "$fake_bin/$name"
}

make_fake fedory-hw-touchscreen '[[ ${TOUCHSCREEN:-0} == "1" ]]'
make_fake fedory-hw-accelerometer 'exec "$ROOT_DIR/bin/fedory-hw-accelerometer" "$@"'

printf '30\n' >"$fake_sys/class/dmi/id/chassis_type"
if PATH="$fake_bin:$PATH" FEDORY_SYS_ROOT="$fake_sys" TOUCHSCREEN=1 "$ROOT_DIR/bin/fedory-hw-tablet"; then
  echo "ok: chassis type 30 with touch is detected as a tablet"
else
  echo "FAIL: tablet chassis with touch was not detected"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

printf '10\n' >"$fake_sys/class/dmi/id/chassis_type"
if PATH="$fake_bin:$PATH" FEDORY_SYS_ROOT="$fake_sys" TOUCHSCREEN=1 "$ROOT_DIR/bin/fedory-hw-tablet"; then
  echo "FAIL: touchscreen-only notebook was detected as a tablet"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: touchscreen-only notebook is not detected as a tablet"
fi

mkdir -p "$fake_sys/bus/iio/devices/iio:device0"
touch "$fake_sys/bus/iio/devices/iio:device0/in_accel_x_raw"
if PATH="$fake_bin:$PATH" FEDORY_SYS_ROOT="$fake_sys" TOUCHSCREEN=1 "$ROOT_DIR/bin/fedory-hw-tablet"; then
  echo "ok: touchscreen plus accelerometer is detected as a tablet"
else
  echo "FAIL: touchscreen plus accelerometer was not detected"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if PATH="$fake_bin:$PATH" FEDORY_SYS_ROOT="$fake_sys" TOUCHSCREEN=0 "$ROOT_DIR/bin/fedory-hw-tablet"; then
  echo "FAIL: accelerometer without touch was detected as a tablet"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: accelerometer without touch is not detected as a tablet"
fi

fake_input="$tmp/input"
mkdir -p "$fake_input/event0/device/id"
printf '0b05\n' >"$fake_input/event0/device/id/vendor"
printf '1a30\n' >"$fake_input/event0/device/id/product"
if FEDORY_INPUT_ROOT="$fake_input" "$ROOT_DIR/bin/fedory-tablet-keyboard-watch" --keyboard-attached; then
  echo "ok: the Z13 detachable keyboard is detected while attached"
else
  echo "FAIL: the attached Z13 keyboard was not detected"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
printf 'ffff\n' >"$fake_input/event0/device/id/product"
if FEDORY_INPUT_ROOT="$fake_input" "$ROOT_DIR/bin/fedory-tablet-keyboard-watch" --keyboard-attached; then
  echo "FAIL: an unrelated keyboard was detected as the Z13 keyboard"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: unrelated keyboards do not trigger attachment mode"
fi

make_fake hyprctl '
if [[ $1 == "monitors" ]]; then
  printf '\''%s\n'\'' '\''[{"name":"eDP-1","width":1920,"height":1200,"refreshRate":60.0,"x":100,"y":20,"scale":1.25},{"name":"DP-1","width":2560,"height":1440,"refreshRate":144.0,"x":0,"y":0,"scale":1.0}]'\''
elif [[ $1 == "devices" ]]; then
  printf '\''%s\n'\'' '\''{"touch":[{"name":"touch one"}],"tablets":[{"name":"pen one"}]}'\''
else
  printf '\''%s\n'\'' "$*" >>"$FEDORY_TEST_LOG"
fi'

PATH="$fake_bin:$PATH" FEDORY_TEST_LOG="$log" "$ROOT_DIR/bin/fedory-tablet-rotate" left-up
rotate_log=$(<"$log")
if [[ $rotate_log == *'output = "eDP-1"'* && $rotate_log == *'position = "100x20"'* && $rotate_log == *'scale = 1.25'* && $rotate_log == *'transform = 1'* ]]; then
  echo "ok: rotation preserves the built-in monitor geometry"
else
  echo "FAIL: rotation did not preserve the built-in monitor geometry"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
if [[ $rotate_log == *'name = "touch one"'* && $rotate_log == *'name = "pen one"'* && $rotate_log != *'output = "DP-1"'* ]]; then
  echo "ok: rotation maps touch and pen devices only to the built-in display"
else
  echo "FAIL: rotation did not map tablet input devices correctly"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

rm -f "$log"
PATH="$fake_bin:$PATH" FEDORY_TEST_LOG="$log" "$ROOT_DIR/bin/fedory-tablet-rotate" right-up
rotate_log=$(<"$log")
if [[ $rotate_log == *'transform = 3'* ]]; then
  echo "ok: sensor portrait orientations rotate the output in the matching direction"
else
  echo "FAIL: right-up sensor orientation used the wrong output transform"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

rm -f "$log"
make_fake fedory-hw-touchscreen 'exit 0'
make_fake fedory-hw-accelerometer 'exit 0'
make_fake fedory-pkg-add 'printf '\''pkg %s\n'\'' "$*" >>"$FEDORY_TEST_LOG"'
make_fake fedory-install-tablet-keyboard 'printf '\''install tablet keyboard\n'\'' >>"$FEDORY_TEST_LOG"'
make_fake fedory-display-text-size '
state="$HOME/text-size"
if (($#)); then printf '\''%s\n'\'' "$1" >"$state"; else printf '\''text size: %s px\n'\'' "$(cat "$state")"; fi'
make_fake systemctl 'printf '\''systemctl %s\n'\'' "$*" >>"$FEDORY_TEST_LOG"; [[ $* != *"is-active"* ]]'
make_fake fedory-restart-shell 'printf '\''restart shell\n'\'' >>"$FEDORY_TEST_LOG"'
make_fake hyprctl 'printf '\''hyprctl %s\n'\'' "$*" >>"$FEDORY_TEST_LOG"'
printf '12\n' >"$fake_home/text-size"

HOME="$fake_home" PATH="$fake_bin:$PATH" FEDORY_PATH="$ROOT_DIR" FEDORY_TEST_LOG="$log" \
  "$ROOT_DIR/bin/fedory-setup-tablet" enable
assert_file_exists "$fake_home/.local/state/fedory/tablet/enabled"
assert_file_exists "$fake_home/.local/state/fedory/toggles/hypr/tablet.lua"
assert_eq "16" "$(<"$fake_home/text-size")" "tablet setup increases the shared text size"
assert_eq "12" "$(<"$fake_home/.local/state/fedory/tablet/previous-text-size")" "tablet setup records the previous text size"

HOME="$fake_home" PATH="$fake_bin:$PATH" FEDORY_PATH="$ROOT_DIR" FEDORY_TEST_LOG="$log" \
  "$ROOT_DIR/bin/fedory-setup-tablet" disable
assert_eq "12" "$(<"$fake_home/text-size")" "tablet disable restores the previous text size"
if [[ ! -e $fake_home/.local/state/fedory/tablet/enabled && ! -e $fake_home/.local/state/fedory/toggles/hypr/tablet.lua ]]; then
  echo "ok: tablet disable removes profile state"
else
  echo "FAIL: tablet disable left profile state behind"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
