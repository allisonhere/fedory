#!/bin/bash
# Covers the Fedory boot splash install.
#
# Regression origin: default/plymouth/ shipped a complete theme and
# bin/fedory-refresh-plymouth knew how to deploy it, but nothing in install/
# or bootstrap.sh ever called it. A fresh install therefore booted on Fedora's
# stock bgrt theme, which draws nothing without a firmware logo -- on a VM,
# with `rhgb quiet` set, that is a black screen for the whole boot.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

fake_bin=$(mktemp -d)
theme_dir=$(mktemp -d)/fedory
work_dir=$(mktemp -d)
cleanup() { rm -rf "$fake_bin" "$(dirname "$theme_dir")" "$work_dir"; }
trap cleanup EXIT

# Record invocations instead of touching the real boot configuration.
for tool in plymouth-set-default-theme dracut; do
  cat > "$fake_bin/$tool" <<EOF
#!/bin/bash
printf '%s %s\n' "$tool" "\$*" >> "$work_dir/calls"
EOF
  chmod +x "$fake_bin/$tool"
done
# The helper shells out through sudo whenever it isn't already root, which is
# the path a manual `fedory-refresh-plymouth` takes. Pass straight through so
# the test neither needs privileges nor skips that branch.
cat > "$fake_bin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
chmod +x "$fake_bin/sudo"
export PATH="$fake_bin:$PATH"

# The leaf must actually be wired into the install run -- the whole bug was a
# correct script that nothing invoked.
if grep -q 'config/plymouth.sh' "$ROOT_DIR/install/config/all.sh"; then
  echo "ok: the boot splash leaf runs during install"
else
  echo "FAIL: install/config/all.sh never runs config/plymouth.sh"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

export FEDORY_PATH="$ROOT_DIR"
export FEDORY_PLYMOUTH_THEME_DIR="$theme_dir"
source "$ROOT_DIR/install/helpers/plymouth.sh"

output=$(fedory_apply_plymouth_theme 2>&1)
status=$?
assert_eq 0 "$status" "applying the boot splash succeeds"

# The theme has to land where Plymouth looks for it.
assert_file_exists "$theme_dir/fedory.plymouth"
assert_file_exists "$theme_dir/logo.png"

# Both boot-config commands must have run, in order.
calls=$(<"$work_dir/calls")
case "$calls" in
  *"plymouth-set-default-theme fedory"*) echo "ok: selects fedory as the default theme" ;;
  *) echo "FAIL: never set the default theme (calls: $calls)"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac
case "$calls" in
  *"dracut --regenerate-all --force"*) echo "ok: rebuilds the initramfs" ;;
  *) echo "FAIL: never regenerated the initramfs (calls: $calls)"
     ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
esac

# The [n/3] markers are what drive run_logged's progress bar. Without the
# final one landing before dracut, a silent 30-60s rebuild renders as a frozen
# terminal.
for marker in '[1/3]' '[2/3]' '[3/3]'; do
  case "$output" in
    *"$marker"*) echo "ok: emits progress marker $marker" ;;
    *) echo "FAIL: missing progress marker $marker"
       ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
  esac
done

dracut_line=$(printf '%s\n' "$output" | grep -n 'dracut' | cut -d: -f1)
marker_line=$(printf '%s\n' "$output" | grep -n '\[3/3\]' | cut -d: -f1)
assert_eq "$marker_line" "$dracut_line" "the final marker announces dracut before it runs"

# Progress rendering: the task needs its own label and an activity row, and
# the renderer and the watcher's cursor cleanup must agree on that row.
source "$ROOT_DIR/install/helpers/logging.sh"
export FEDORY_INSTALL="$ROOT_DIR/install"
assert_eq "Set up the boot splash" \
  "$(fedory_task_label "$ROOT_DIR/install/config/plymouth.sh")" \
  "the boot splash step has a readable label"
assert_eq "STEP" "$(fedory_task_activity_label "Set up the boot splash")" \
  "the boot splash step gets a live activity row"
assert_eq "PACKAGE" "$(fedory_task_activity_label "Install core desktop packages")" \
  "the package step keeps its existing activity row"
assert_eq "" "$(fedory_task_activity_label "Configure Git")" \
  "short steps get no activity row"

finish
