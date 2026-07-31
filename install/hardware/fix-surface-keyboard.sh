# Detect Surface devices which require additional modules for the keyboard to work.
# Module list derived from Chris McLeod's manual install instructions
# https://chrismcleod.dev/blog/installing-arch-linux-with-secure-boot-on-a-microsoft-surface-laptop-studio/
#
# Fedora-native rewrite: mkinitcpio.conf.d's MODULES=(...) array becomes a
# dracut.conf.d drop-in using force_drivers+=, dracut's equivalent
# early-inclusion directive; a `dracut -f` (or reboot, since a fresh install
# rebuilds initramfs anyway) picks it up.
source "$FEDORY_INSTALL/helpers/ui.sh"

if fedory-hw-surface; then
  product_name="$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
  ui_info "Detected Surface Device"

  # Modules already exist in the rootfs for the default kernel.
  if [[ $product_name != "Surface Laptop 3" ]]; then
    ui_warn "Untested Surface Device: $product_name, additional modules may be required for your device."
  fi

  ui_info "Attempting to autodetect required pinctrl module"
  pinctrl_module=$(lsmod | grep pinctrl_ | cut -f 1 -d" " || true)
  if [[ -z $pinctrl_module ]]; then
    ui_warn "Failed to autodetect pinctrl module."
  else
    ui_info "Detected pinctrl module: $pinctrl_module"
    mkdir -p /etc/dracut.conf.d
    echo "force_drivers+=\" ${pinctrl_module} surface_aggregator surface_aggregator_registry surface_aggregator_hub surface_hid_core surface_hid surface_kbd intel_lpss_pci 8250_dw \"" > \
      /etc/dracut.conf.d/surface-device-modules.conf
    dracut -f
  fi
fi
