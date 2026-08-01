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
export FEDORY_PROGRESS_INTERVAL=0.02
export FEDORY_PROGRESS_BAR_WIDTH=10
run_logged "$FEDORY_INSTALL/config/theme-system.sh" >"$tmp_dir/progress-output"
run_logged "$FEDORY_INSTALL/config/firewall.sh" >"$tmp_dir/failure-output" 2>&1

printf '[10/10] Complete\n' >"$tmp_dir/completed-task.log"
fedory_render_progress 1 2 "Apply the system theme" \
  "$tmp_dir/completed-task.log" "$(date +%s)" 3 >"$tmp_dir/finishing-output"

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

finish
