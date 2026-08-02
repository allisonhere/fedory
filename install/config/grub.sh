# Brand the GRUB boot menu. bin/fedory-refresh-grub holds the logic so the
# same code serves both bootstrap and a later manual refresh.
#
# Non-fatal on purpose. A machine that boots by some other means -- systemd-boot,
# a UEFI stub, an installer layout with no grub2-mkconfig -- still has a
# perfectly working desktop, and the boot menu's appearance is not worth failing
# setup over. run_logged records the failure either way.

source "$FEDORY_INSTALL/helpers/ui.sh"

if ! command -v grub2-mkconfig >/dev/null 2>&1; then
  ui_warn "grub2-mkconfig is not installed; skipping the GRUB boot menu theme"
  return 0 2>/dev/null || exit 0
fi

if [[ ! -d /boot/grub2 ]]; then
  ui_warn "/boot/grub2 is absent, so this system does not boot via GRUB; skipping its theme"
  return 0 2>/dev/null || exit 0
fi

fedory-refresh-grub
