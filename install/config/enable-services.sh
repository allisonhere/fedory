source "$FEDORY_INSTALL/helpers/ui.sh"

# Fedora Workstation ships and enables GDM by default. Hyprland runs under
# SDDM (upstream's assumption throughout), so swap the default display
# manager rather than leaving both enabled after the next reboot. Do not stop
# GDM here: bootstrap runs inside the user's current desktop, and --now would
# terminate that live session before installation has finished. Deliberately
# first in this
# script and independently fault-tolerant: a real bootstrap run showed
# `systemctl enable docker.socket` below failing (Docker CE hadn't actually
# installed) and aborting the rest of the script under -e -- since this was
# originally the *last* thing in the file, the switch that matters most
# never ran, and the reboot landed right back on GDM/GNOME with no visible
# change at all.
systemctl disable gdm.service >/dev/null 2>&1 || true
systemctl enable sddm.service || ui_warn "could not enable sddm.service"

# Everything below is independently best-effort for the same reason: one
# unit not existing (Docker CE failing to install, an optional service not
# present on this install, etc.) shouldn't stop the rest of these from
# being enabled.
systemctl enable cups.service || ui_warn "could not enable cups.service"
systemctl enable cups-browsed.service || ui_warn "could not enable cups-browsed.service"
systemctl enable avahi-daemon.service || ui_warn "could not enable avahi-daemon.service"
systemctl enable docker.socket || ui_warn "could not enable docker.socket (see the Docker CE messages in config/base-packages.sh above)"
systemctl enable NetworkManager.service || ui_warn "could not enable NetworkManager.service"
# Don't let network-online.target (pulled in by cups-browsed) hold up
# graphical.target waiting for DHCP/Wi-Fi association. Nothing in the session
# needs to block on the network. Mirrors the systemd-networkd-wait-online mask
# in install/hardware/network.sh.
systemctl mask NetworkManager-wait-online.service || ui_warn "could not mask NetworkManager-wait-online.service"
systemctl enable power-profiles-daemon.service || ui_warn "could not enable power-profiles-daemon.service"

# Unlike Arch (no default kernel-modules-hook / systemd-resolved setup),
# Fedora's dnf already handles kernel module bookkeeping on its own, and
# NetworkManager manages DNS directly without systemd-resolved by default.
# Enabling systemd-resolved here would fight NetworkManager's resolv.conf
# management, so it's intentionally left alone. See docs/scope.md if this
# needs revisiting.
