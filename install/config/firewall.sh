# Fedora Workstation ships firewalld, not ufw -- this is the Fedora-native
# translation of upstream's ufw-based firewall.sh, same intent (deny
# incoming, allow outgoing, allow LocalSend, allow Docker's embedded DNS).
FEDORY_ZONE="${FEDORY_FIREWALL_ZONE:-FedoraWorkstation}"

firewall-cmd --set-default-zone="$FEDORY_ZONE" >/dev/null 2>&1 || true

# Allow ports for LocalSend.
firewall-cmd --permanent --zone="$FEDORY_ZONE" --add-port=53317/udp
firewall-cmd --permanent --zone="$FEDORY_ZONE" --add-port=53317/tcp

# Allow Docker containers to use DNS on host. firewalld's default zone
# already denies unsolicited incoming traffic, so this is additive, not a
# policy flip like ufw's `default deny incoming`.
firewall-cmd --permanent --zone="$FEDORY_ZONE" \
  --add-rich-rule='rule family="ipv4" source address="172.16.0.0/12" port port="53" protocol="udp" destination address="172.17.0.1" accept'
firewall-cmd --permanent --zone="$FEDORY_ZONE" \
  --add-rich-rule='rule family="ipv4" source address="192.168.0.0/16" port port="53" protocol="udp" destination address="172.17.0.1" accept'

# Route Docker's bridge interface through the trusted zone so container
# traffic isn't dropped by the host zone's default policy. This is
# firewalld's equivalent of ufw-docker's after.rules patch -- no separate
# package needed, since firewalld's docker integration is a zone assignment,
# not extra iptables rules to install.
firewall-cmd --permanent --zone=trusted --add-interface=docker0 >/dev/null 2>&1 || true

# Installs are followed by reboot; --permanent rules above take effect once
# firewalld (re)starts, so just make sure it's enabled to start on boot.
systemctl enable firewalld
