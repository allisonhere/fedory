# Prevent password-based SDDM logins from creating an encrypted login keyring
# that conflicts with Fedory's passwordless default keyring behavior.
# bootstrap.sh owns autologin/session state since it knows whether the target
# is encrypted.
if [[ -f /etc/pam.d/sddm ]]; then
  sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
  sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
fi

# Fedory is currently installed as a source checkout rather than an RPM-owned
# /usr/share tree. Persist that exact path for login shells and uwsm, then
# install the system entry points that must exist before the user's session.
fedory_path=${FEDORY_PATH//\\/\\\\}
fedory_path=${fedory_path//\"/\\\"}
fedory_path=${fedory_path//\$/\\\$}
fedory_path=${fedory_path//\`/\\\`}
printf 'export FEDORY_PATH="%s"\n' "$fedory_path" >/etc/fedory.conf

install -Dm644 "$FEDORY_PATH/default/uwsm/env.d/10-fedory" \
  /usr/share/uwsm/env.d/10-fedory
install -Dm644 "$FEDORY_PATH/default/bash/env-bootstrap" \
  /etc/profile.d/fedory.sh
install -Dm644 "$FEDORY_PATH/default/wayland-sessions/fedory.desktop" \
  /usr/share/wayland-sessions/fedory.desktop

rm -rf /usr/share/sddm/themes/fedory
cp -r "$FEDORY_PATH/default/sddm/fedory" /usr/share/sddm/themes/fedory
mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/fedory.conf <<'EOF'
[Theme]
Current=fedory
EOF

# SDDM's lastUser is empty until its first successful login. The Fedory theme
# uses it to prefill the account, so seed the state for bootstrap installs.
install -d -o sddm -g sddm -m 0750 /var/lib/sddm
printf '[Last]\nSession=fedory.desktop\nUser=%s\n' "$FEDORY_INSTALL_USER" \
  >/var/lib/sddm/state.conf
chown sddm:sddm /var/lib/sddm/state.conf
chmod 0600 /var/lib/sddm/state.conf
