#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/install/config"

cat >"$tmp_dir/bin/gum" <<'EOF'
#!/bin/bash
mode=$1
shift

if [[ $mode == "spin" ]]; then
  while (($#)); do
    if [[ $1 == "--" ]]; then
      shift
      exec "$@"
    fi
    case $1 in
      --spinner|--spinner.foreground|--title.foreground|--title)
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
elif [[ $mode == "style" ]]; then
  while (($#)); do
    if [[ $1 == "--" ]]; then
      shift
      printf '%s\n' "$*"
      exit 0
    fi
    case $1 in
      --foreground)
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
fi

exit 0
EOF
chmod +x "$tmp_dir/bin/gum"

cat >"$tmp_dir/install/config/theme-system.sh" <<EOF
printf '[ 2/10] Installing package files\n'
sleep 0.06
printf '[10/10] Complete\n'
printf 'success ran\n' >"$tmp_dir/success-marker"
EOF

cat >"$tmp_dir/install/config/firewall.sh" <<EOF
printf 'failure ran\n' >"$tmp_dir/failure-marker"
echo 'intentional test failure'
false
EOF

export PATH="$tmp_dir/bin:$PATH"
export FEDORY_INSTALL="$tmp_dir/install"
export FEDORY_INSTALL_LOG_FILE="$tmp_dir/install.log"
export FEDORY_PROGRESS_FILE="$tmp_dir/progress"
export FEDORY_PROGRESS_TOTAL=2
printf '0\n' >"$FEDORY_PROGRESS_FILE"

source "$ROOT_DIR/install/helpers/logging.sh"
start_install_log
export FEDORY_PROGRESS_UI=always
# These assertions are about layout -- row order, labels, parsed counts -- not
# about which glyphs fill the bars. Pin them to the ASCII fallback so they stay
# readable and locale-independent; progress-bar-test.sh covers the block-drawing
# rendering itself.
export FEDORY_PROGRESS_ASCII=1
export FEDORY_PROGRESS_INTERVAL=0.02
export FEDORY_PROGRESS_BAR_WIDTH=10
run_logged "$FEDORY_INSTALL/config/theme-system.sh" >"$tmp_dir/progress-output"
run_logged "$FEDORY_INSTALL/config/firewall.sh" >"$tmp_dir/failure-output" 2>&1

printf '[10/10] Complete\n' >"$tmp_dir/completed-task.log"
fedory_render_progress 1 2 "Apply the system theme" \
  "$tmp_dir/completed-task.log" "$(date +%s)" 3 >"$tmp_dir/finishing-output"

cat >"$tmp_dir/package-task.log" <<'EOF'
Downloading Packages:
[121/443] foot-1.22.3-1.fc44.x86_64        100% | 2.1 MiB/s | 1.2 MiB | 00m01s
Running transaction
[271/443] Installing quickshell-git-0.2.1-1.fc44.x86_64 100% | 4.0 KiB/s | 8.0 KiB | 00m00s
EOF
package_snapshot=$(fedory_task_progress "$tmp_dir/package-task.log")
assert_eq "271|443|Installing quickshell-git-0.2.1-1.fc44.x86_64" \
  "$package_snapshot" "installer extracts the current DNF package"

printf '[34/115] Checking installed package: foot\n' >"$tmp_dir/package-task.log"
verification_snapshot=$(fedory_task_progress "$tmp_dir/package-task.log")
assert_eq "34|115|Checking installed package: foot" \
  "$verification_snapshot" "installer reports post-DNF package verification"

FEDORY_PROGRESS_COLUMNS=80 fedory_render_progress 1 2 \
  "Install core desktop packages" "$tmp_dir/package-task.log" \
  "$(date +%s)" 0 >"$tmp_dir/package-progress-output"

assert_file_exists "$tmp_dir/success-marker"
assert_file_exists "$tmp_dir/failure-marker"
assert_eq "2" "$(<"$FEDORY_PROGRESS_FILE")" \
  "installer progress advances across successful and failed tasks"
assert_eq "1" "${#FEDORY_FAILED_LEAVES[@]}" \
  "failed progress tasks remain recorded for the final report"

if rg -F "intentional test failure" "$FEDORY_INSTALL_LOG_FILE" >/dev/null; then
  echo "ok: live progress task output is retained in the install log"
else
  echo "FAIL: live progress task output is missing from the install log"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if sed $'s/\033\\[[0-9;?]*[[:alpha:]]//g' "$tmp_dir/progress-output" \
  | rg -F 'TOTAL    [----------] 00/02' >/dev/null; then
  echo "ok: installer renders an overall progress bar"
else
  echo "FAIL: installer overall progress bar is missing"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if sed $'s/\033\\[[0-9;?]*[[:alpha:]]//g' "$tmp_dir/package-progress-output" \
  | rg -F 'PACKAGE  Checking installed package: foot' >/dev/null; then
  echo "ok: core package progress renders a stable package activity line"
else
  echo "FAIL: core package progress activity line is missing"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if sed $'s/\033\\[[0-9;?]*[[:alpha:]]//g' "$tmp_dir/progress-output" \
  | rg -F 'PACKAGE  ' >/dev/null; then
  echo "FAIL: non-package tasks unexpectedly render a package activity line"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
else
  echo "ok: non-package tasks retain the two-line progress display"
fi

if sed $'s/\033\\[[0-9;?]*[[:alpha:]]//g' "$tmp_dir/finishing-output" \
  | rg -F 'finishing 00:00  Apply the system theme' >/dev/null; then
  echo "ok: completed transactions show finishing activity until the task exits"
else
  echo "FAIL: completed transaction appears frozen while follow-up checks run"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if sed $'s/\033\\[[0-9;?]*[[:alpha:]]//g' "$tmp_dir/progress-output" \
  | rg -F 'CURRENT  [##--------] 2/10  Apply the system theme' >/dev/null; then
  echo "ok: installer renders parsed current-task progress"
else
  echo "FAIL: installer current-task progress bar is missing"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

assert_eq "Install core desktop packages" \
  "$(fedory_task_label "$FEDORY_INSTALL/config/base-packages.sh")" \
  "internal package script has a human-readable label"
assert_eq "Hardware / Nvidia" \
  "$(fedory_task_label "$FEDORY_INSTALL/hardware/nvidia.sh")" \
  "hardware scripts receive a readable category label"

cat >"$tmp_dir/install/config/base-packages.sh" <<'EOF'
sleep 0.03
EOF
run_logged "$FEDORY_INSTALL/config/base-packages.sh" >"$tmp_dir/package-notice-output" 2>&1
assert_eq "1" "$(rg -c 'This is the longest install step' "$tmp_dir/package-notice-output")" \
  "core package warning appears once before progress"

FEDORY_RUN_LOGGED_STEP=7
chmod 0400 "$FEDORY_PROGRESS_FILE"
assert_eq "7" "$(fedory_progress_advance)" \
  "an unwritable progress counter falls back without failing setup"

if rg -F 'FEDORY_PROGRESS_DIR=$(mktemp -d)' "$ROOT_DIR/bootstrap.sh" >/dev/null; then
  echo "ok: bootstrap keeps the cross-privilege counter outside sticky /tmp"
else
  echo "FAIL: bootstrap creates the cross-privilege counter directly in sticky /tmp"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

if rg -F -- '-f $HOME/.config/fedory/branding/screensaver.txt' "$ROOT_DIR/bootstrap.sh" >/dev/null &&
  rg -F 'setup_mode=(--upgrade)' "$ROOT_DIR/bootstrap.sh" >/dev/null &&
  rg -F 'fedory-migrate || had_issues=1' "$ROOT_DIR/bootstrap.sh" >/dev/null; then
  echo "ok: bootstrap reruns apply migrations to existing user state"
else
  echo "FAIL: bootstrap reruns can skip migrations for existing user state"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

finish
