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
run_logged "$FEDORY_INSTALL/config/theme-system.sh"
run_logged "$FEDORY_INSTALL/config/firewall.sh"

assert_file_exists "$tmp_dir/success-marker"
assert_file_exists "$tmp_dir/failure-marker"
assert_eq "2" "$(<"$FEDORY_PROGRESS_FILE")" \
  "installer progress advances across successful and failed tasks"
assert_eq "1" "${#FEDORY_FAILED_LEAVES[@]}" \
  "failed spinner tasks remain recorded for the final report"

if rg -F "intentional test failure" "$FEDORY_INSTALL_LOG_FILE" >/dev/null; then
  echo "ok: spinner task output is retained in the install log"
else
  echo "FAIL: spinner task output is missing from the install log"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

assert_eq "Install core desktop packages" \
  "$(fedory_task_label "$FEDORY_INSTALL/config/base-packages.sh")" \
  "internal package script has a human-readable label"
assert_eq "Hardware / Nvidia" \
  "$(fedory_task_label "$FEDORY_INSTALL/hardware/nvidia.sh")" \
  "hardware scripts receive a readable category label"

finish
