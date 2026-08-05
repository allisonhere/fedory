#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
test_home="$test_tmp/home"
mkdir -p "$mock_bin" "$test_home"

cat >"$mock_bin/fedory-pkg-add" <<'SH'
#!/bin/bash
printf 'pkg:%s\n' "$*" >>"$FEDORY_TEST_LOG"
exit "${FEDORY_TEST_PKG_STATUS:-0}"
SH

for command in fedory-pkg-copr-add fedory-install-editor-emacs omazed fedory-theme-set-vscode fedory-install-gaming-gpu-lib32; do
  cat >"$mock_bin/$command" <<'SH'
#!/bin/bash
exit 0
SH
done

cat >"$mock_bin/setsid" <<'SH'
#!/bin/bash
printf 'launch:%s\n' "$*" >>"$FEDORY_TEST_LOG"
SH

cat >"$mock_bin/sudo" <<'SH'
#!/bin/bash
shift 2>/dev/null || true
exec "$@"
SH

cat >"$mock_bin/rpm" <<'SH'
#!/bin/bash
exit 0
SH

cat >"$mock_bin/dnf" <<'SH'
#!/bin/bash
exit 0
SH

cat >"$mock_bin/fedory-launch-floating-terminal-with-presentation" <<'SH'
#!/bin/bash
printf '%s\n' "$1" >"$FEDORY_TEST_PRESENTATION"
SH

chmod +x "$mock_bin"/*

export HOME="$test_home"
export FEDORY_TEST_LOG="$test_tmp/launch.log"
export FEDORY_TEST_PRESENTATION="$test_tmp/presentation"
export PATH="$mock_bin:$PATH"

wait_for_launch() {
  local expected="$1"

  for ((attempt = 0; attempt < 100; attempt++)); do
    grep -Fxq "$expected" "$FEDORY_TEST_LOG" && return 0
    sleep 0.01
  done

  return 1
}

# Fedory uses "uwsm app --" (with space), not "uwsm-app" (hyphenated)
check_uwsm_launch() {
  local script="$1" command="$2"

  : >"$FEDORY_TEST_LOG"
  bash "$ROOT_DIR/bin/$script"

  wait_for_launch "launch:uwsm app -- $command" ||
    fail "$script launches through uwsm app in its own scope"
  pass "$script launches its application in its own scope"
}

check_flatpak_launch() {
  local script="$1" flatpak_id="$2"

  grep -Fq "setsid flatpak run $flatpak_id" "$ROOT_DIR/bin/$script" ||
    fail "$script detaches a flatpak launch"
  pass "$script detaches its flatpak launch"
}

# Emacs: direct binary through uwsm app
check_uwsm_launch fedory-install-editor-emacs emacs
# VSCode and Steam: gtk-launch through uwsm app
check_uwsm_launch fedory-install-editor-vscode "gtk-launch code"
check_uwsm_launch fedory-install-gaming-steam "gtk-launch steam"
# Zed and Heroic: flatpak
check_flatpak_launch fedory-install-editor-zed dev.zed.Zed
check_flatpak_launch fedory-install-gaming-heroic com.heroicgameslauncher.hgl

bash "$ROOT_DIR/bin/fedory-install-and-launch" "Example App" "alpha beta" "Disk Usage"
presentation_command=$(<"$FEDORY_TEST_PRESENTATION")

[[ $presentation_command == *'echo Installing\ Example\ App...;'* ]] ||
  fail "generic installer shell-quotes the display name" "$presentation_command"
[[ $presentation_command == *'fedory-pkg-add alpha beta && (setsid uwsm app -- gtk-launch Disk\ Usage >/dev/null 2>&1 &)'* ]] ||
  fail "generic installer waits for packages and detaches only the scoped launch" "$presentation_command"
pass "generic installer waits for packages and detaches only the scoped launch"

: >"$FEDORY_TEST_LOG"
bash -c "$presentation_command"
grep -Fxq 'pkg:alpha beta' "$FEDORY_TEST_LOG" ||
  fail "generic installer passes every package to the package helper"
wait_for_launch 'launch:uwsm app -- gtk-launch Disk Usage' ||
  fail "generic installer preserves a desktop ID containing spaces"
pass "generic installer preserves a desktop ID containing spaces"

: >"$FEDORY_TEST_LOG"
if FEDORY_TEST_PKG_STATUS=1 bash -c "$presentation_command"; then
  fail "generic installer propagates package installation failure"
fi
if grep -q '^launch:' "$FEDORY_TEST_LOG"; then
  fail "generic installer does not launch after package installation failure"
fi
pass "generic installer does not launch after package installation failure"
