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
# The echoed [n/5] markers are load-bearing, not decoration: run_logged's
# progress renderer parses them out of the leaf's stdout (see
# fedory_task_progress in logging.sh) to drive the CURRENT bar. Emitting the
# final marker *before* dracut is deliberate -- at n == total the renderer
# switches to an animated bar with a running clock, which is what tells the
# user that a silent 30-60s initramfs rebuild is still alive.

# fedory_apply_plymouth_theme
#   Installs the theme, smooths its display handoffs, selects it, and rebuilds
#   every initramfs.
#   Runs commands directly when already root, via sudo otherwise.
fedory_apply_plymouth_theme() {
  # FEDORY_PLYMOUTH_THEME_DIR exists so the test suite can point the install at
  # a throwaway directory. Production never sets it.
  local theme_dir="${FEDORY_PLYMOUTH_THEME_DIR:-/usr/share/plymouth/themes/fedory}"
  local source_dir="${FEDORY_PATH:-}/default/plymouth"
  local drm_class_dir="${FEDORY_DRM_CLASS_DIR:-/sys/class/drm}"
  local dracut_config="${FEDORY_PLYMOUTH_DRACUT_CONFIG:-/etc/dracut.conf.d/fedory-early-kms.conf}"
  local quit_override_dir="${FEDORY_PLYMOUTH_QUIT_OVERRIDE_DIR:-/etc/systemd/system/plymouth-quit.service.d}"
  local card driver force_line
  local -a early_drivers=()
  local run=()

  if [[ ! -d $source_dir ]]; then
    echo "Plymouth theme source '$source_dir' is missing; skipping boot splash setup" >&2
    return 1
  fi

  (( EUID == 0 )) || run=(sudo)

  echo "[1/5] Installing the Fedory boot splash theme"
  "${run[@]}" mkdir -p "$theme_dir" || return 1
  "${run[@]}" cp -r "$source_dir/." "$theme_dir/" || return 1

  # default/plymouth/fedory.plymouth declares ModuleName=script, which needs
  # the script renderer from plymouth-plugin-script -- the plymouth package
  # alone does not ship script.so. Without it plymouth-set-default-theme fails
  # with a bare "/usr/lib64/plymouth/script.so does not exist", which says
  # nothing about which package is missing.
  # FEDORY_PLYMOUTH_PLUGIN_GLOB lets the test suite exercise both branches
  # without depending on whether the test host happens to have the plugin.
  # Production never sets it.
  if ! compgen -G "${FEDORY_PLYMOUTH_PLUGIN_GLOB:-/usr/lib*/plymouth/script.so}" >/dev/null; then
    echo "The Fedory theme needs plymouth-plugin-script, which is not installed." >&2
    echo "It is listed in install/fedory-base.packages; check that step's output." >&2
    return 1
  fi

  echo "[2/5] Loading the native graphics driver before Plymouth"
  for card in "$drm_class_dir"/card[0-9]*; do
    [[ -e $card/device/driver/module ]] || continue
    driver=$(basename "$(readlink -f "$card/device/driver/module")")

    case "$driver" in
      amdgpu|i915|xe)
        [[ " ${early_drivers[*]} " == *" $driver "* ]] || early_drivers+=("$driver")
        ;;
    esac
  done

  if ((${#early_drivers[@]})); then
    printf -v force_line 'force_drivers+=" %s "' "${early_drivers[*]}"
    "${run[@]}" mkdir -p "$(dirname "$dracut_config")" || return 1
    printf '%s\n' "$force_line" | "${run[@]}" tee "$dracut_config" >/dev/null || return 1
  else
    # This file belongs exclusively to Fedory. Remove stale Intel/AMD state if
    # the machine was reconfigured with a different graphics driver.
    "${run[@]}" rm -f "$dracut_config" || return 1
  fi

  echo "[3/5] Retaining the splash until the login screen takes over"
  "${run[@]}" mkdir -p "$quit_override_dir" || return 1
  printf '%s\n' \
    '[Service]' \
    'ExecStart=' \
    'ExecStart=-/usr/bin/plymouth quit --retain-splash' | \
    "${run[@]}" tee "$quit_override_dir/fedory.conf" >/dev/null || return 1

  echo "[4/5] Selecting Fedory as the default boot splash"
  "${run[@]}" plymouth-set-default-theme fedory || return 1

  # dracut prints almost nothing on a normal run, so the progress marker above
  # is the only thing standing between the user and an apparently frozen
  # terminal for the next half-minute.
  echo "[5/5] Regenerating the initramfs (dracut) -- this takes a minute"
  "${run[@]}" dracut --regenerate-all --force || return 1
}
