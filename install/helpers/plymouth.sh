# Deploy the Fedory Plymouth boot splash.
#
# Shared by install/config/plymouth.sh (bootstrap, running as root) and
# bin/fedory-refresh-plymouth (run by hand, as the user). The theme shipped in
# default/plymouth/ used to have no installer at all: the plymouth package was
# in fedory-base.packages and fedory-refresh-plymouth could deploy the theme,
# but nothing ever called it, so a fresh install booted with Fedora's stock
# bgrt theme. On hardware with no firmware logo -- a VM, most notably -- bgrt
# draws nothing, and with `rhgb quiet` on the kernel command line that reads as
# a black screen for the whole boot.
#
# The echoed [n/3] markers are load-bearing, not decoration: run_logged's
# progress renderer parses them out of the leaf's stdout (see
# fedory_task_progress in logging.sh) to drive the CURRENT bar. Emitting the
# final marker *before* dracut is deliberate -- at n == total the renderer
# switches to an animated bar with a running clock, which is what tells the
# user that a silent 30-60s initramfs rebuild is still alive.

# fedory_apply_plymouth_theme
#   Installs the theme, selects it, and rebuilds every initramfs.
#   Runs commands directly when already root, via sudo otherwise.
fedory_apply_plymouth_theme() {
  # FEDORY_PLYMOUTH_THEME_DIR exists so the test suite can point the install at
  # a throwaway directory. Production never sets it.
  local theme_dir="${FEDORY_PLYMOUTH_THEME_DIR:-/usr/share/plymouth/themes/fedory}"
  local source_dir="${FEDORY_PATH:-}/default/plymouth"
  local run=()

  if [[ ! -d $source_dir ]]; then
    echo "Plymouth theme source '$source_dir' is missing; skipping boot splash setup" >&2
    return 1
  fi

  (( EUID == 0 )) || run=(sudo)

  echo "[1/3] Installing the Fedory boot splash theme"
  "${run[@]}" mkdir -p "$theme_dir" || return 1
  "${run[@]}" cp -r "$source_dir/." "$theme_dir/" || return 1

  echo "[2/3] Selecting Fedory as the default boot splash"
  "${run[@]}" plymouth-set-default-theme fedory || return 1

  # dracut prints almost nothing on a normal run, so the progress marker above
  # is the only thing standing between the user and an apparently frozen
  # terminal for the next half-minute.
  echo "[3/3] Regenerating the initramfs (dracut) -- this takes a minute"
  "${run[@]}" dracut --regenerate-all --force || return 1
}
