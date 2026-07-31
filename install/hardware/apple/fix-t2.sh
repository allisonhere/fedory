# Detect T2 MacBook models using PCI IDs
# Vendor: 106b (Apple), Device IDs: 1801 or 1802 (T2 Security Chip)
#
# Fedora-native rewrite: linux-t2/linux-t2-headers/apple-t2-audio-config/
# apple-bcm-firmware/t2fanrd/tiny-dfr all come from the t2linux.org
# project's own Fedora repo rather than Arch's official+AUR mix (see
# packaging/package-map.tsv) -- fedory-pkg-add can't add that repo itself
# (unlike a COPR, it isn't a single `dnf copr enable` away), so this
# leaf stops short and points at t2linux's install docs instead of
# guessing at repo URLs, matching t2-repo.sh's same reasoning.
source "$FEDORY_INSTALL/helpers/ui.sh"

if lspci -nn | grep -q "106b:180[12]"; then
  ui_info "Detected MacBook with T2 chip."
  ui_warn "Fedora T2 Mac support (kernel + firmware + fan/keyboard daemons) needs the t2linux.org project's own Fedora repo -- see https://wiki.t2linux.org. This installer does not add that repo automatically since it replaces the running kernel."
fi
