# Enable services only. Installs are followed by reboot, so don't start/reload
# daemons mid-install. Firewall and hardware-gated services stay in their own
# scripts.
systemctl enable cups.service
systemctl enable cups-browsed.service
systemctl enable avahi-daemon.service
systemctl enable docker.socket
systemctl enable NetworkManager.service
# Don't let network-online.target (pulled in by cups-browsed) hold up
# graphical.target waiting for DHCP/Wi-Fi association. Nothing in the session
# needs to block on the network. Mirrors the systemd-networkd-wait-online mask
# in install/hardware/network.sh.
systemctl mask NetworkManager-wait-online.service
systemctl enable power-profiles-daemon.service

# Fedora Workstation ships and enables GDM by default. Hyprland runs under
# SDDM (upstream's assumption throughout), so swap the default display
# manager rather than leaving both enabled.
systemctl disable --now gdm.service >/dev/null 2>&1 || true
systemctl enable sddm.service

# Unlike Arch (no default kernel-modules-hook / systemd-resolved setup),
# Fedora's dnf already handles kernel module bookkeeping on its own, and
# NetworkManager manages DNS directly without systemd-resolved by default.
# Enabling systemd-resolved here would fight NetworkManager's resolv.conf
# management, so it's intentionally left alone. See docs/scope.md if this
# needs revisiting.
