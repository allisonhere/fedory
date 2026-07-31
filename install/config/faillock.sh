# Fedora manages /etc/pam.d/system-auth through authselect, so unlike
# upstream (which seds pam_faillock's `preauth`/`authfail` lines directly),
# editing that file by hand here would get silently reverted the next time
# authselect apply-changes runs. Use authselect's own faillock feature and
# tune the shared /etc/security/faillock.conf instead -- this is the
# Fedora-native equivalent of upstream's increase-lockout-limit.sh.
if command -v authselect >/dev/null 2>&1; then
  if ! authselect current 2>/dev/null | grep -q 'with-faillock'; then
    authselect enable-feature with-faillock
  fi
fi

FAILLOCK_CONF=/etc/security/faillock.conf
if [[ -f $FAILLOCK_CONF ]]; then
  if grep -qE '^\s*deny\s*=' "$FAILLOCK_CONF"; then
    sed -i -E 's/^\s*deny\s*=.*/deny = 10/' "$FAILLOCK_CONF"
  else
    printf '%s\n' 'deny = 10' >>"$FAILLOCK_CONF"
  fi

  if grep -qE '^\s*unlock_time\s*=' "$FAILLOCK_CONF"; then
    sed -i -E 's/^\s*unlock_time\s*=.*/unlock_time = 120/' "$FAILLOCK_CONF"
  else
    printf '%s\n' 'unlock_time = 120' >>"$FAILLOCK_CONF"
  fi
fi

# /etc/pam.d/sddm-autologin is application-specific, not one of the files
# authselect regenerates, so it's safe to edit directly (same as upstream).
if [[ -f /etc/pam.d/sddm-autologin ]]; then
  sed -i '/pam_faillock\.so preauth/d'  /etc/pam.d/sddm-autologin
  sed -i '/pam_faillock\.so authsucc/d' /etc/pam.d/sddm-autologin
  sed -i '/auth.*pam_permit\.so/a auth        required    pam_faillock.so authsucc' \
             /etc/pam.d/sddm-autologin
fi
