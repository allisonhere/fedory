# Set links for Nautilus action icons
mkdir -p /usr/share/icons/Yaru/scalable/actions
ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg \
          /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg \
          /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg
gtk-update-icon-cache /usr/share/icons/Yaru &>/dev/null || true

# Chromium policy directory for theme. Fedora doesn't ship Chromium in its
# official repos; fedory-pkg-add resolves it to Flathub's
# org.chromium.Chromium. The Flatpak sandbox reads its own policy path
# (~/.var/app/org.chromium.Chromium/config/chromium/policies/managed), not
# /etc/chromium, so this system-wide policy dir is a no-op unless a native
# Chromium build (e.g. from a COPR) is installed instead. See
# packaging/package-map.tsv.
mkdir -p /etc/chromium/policies/managed
chmod a+rw /etc/chromium/policies/managed

# Default Chromium to follow system appearance ("device") instead of dark
mkdir -p /usr/lib/chromium
echo '{"browser":{"theme":{"color_scheme":0,"color_scheme2":0}}}' > \
  /usr/lib/chromium/initial_preferences
