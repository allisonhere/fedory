# Prevent password-based SDDM logins from creating an encrypted login keyring
# that conflicts with Fedory's passwordless default keyring behavior.
# bootstrap.sh owns autologin/session state since it knows whether the target
# is encrypted.
if [[ -f /etc/pam.d/sddm ]]; then
  sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
  sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
fi
