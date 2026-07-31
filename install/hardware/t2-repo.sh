# Fedora-native replacement for upstream's pacman.sh: adding a custom
# hardware-specific pacman repo (arch-mact2, for the MacBook T2 touchpad/
# keyboard driver) has no direct Fedora equivalent -- dnf repos aren't
# interchangeable with pacman repos, and no Fedora mirror of that specific
# repo is known to exist.
#
# The general problem this solves (T2 Mac hardware support) does have a
# real Fedora path: the t2linux.org project publishes its own Fedora repo
# covering the whole T2 stack (patched kernel, Broadcom firmware, T2 audio
# config, fan control, function-key daemon) -- see the apple-bcm-firmware /
# apple-t2-audio-config / linux-t2 / t2fanrd / tiny-dfr rows in
# packaging/package-map.tsv, all marked external-repo pointing at
# t2linux.org. This leaf intentionally does not add that repo automatically
# (it replaces the running kernel, which shouldn't happen without explicit
# user intent) -- point affected users at t2linux.org's own install
# instructions instead.

source "$FEDORY_INSTALL/helpers/ui.sh"

if lspci -nn | grep -q "106b:180[12]"; then
  ui_info "T2 Mac Wi-Fi/Bluetooth controller detected."
  ui_warn "Fedora T2 Mac support is not automated here -- see https://wiki.t2linux.org for the t2linux.org project's Fedora repo and install instructions."
fi
