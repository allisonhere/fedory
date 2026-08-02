# Chromium ships in the base packages, so it never goes through
# fedory-install-browser, and fresh installs mark every migration as already
# applied. Without this, the bundled extensions load but have no native
# messaging host to talk to.
fedory-install-chromium-copy-url
fedory-install-chromium-ytdlp

# Flathub Chromium does not read the host's chromium-flags.conf. Override its
# desktop entry so app-launcher starts go through Fedory's flag-aware wrapper.
mkdir -p ~/.local/share/applications
sed -e 's#^Exec=.*org\.chromium\.Chromium @@u %U @@$#Exec=fedory-launch-chromium %U#' \
  -e 's#^Exec=.*org\.chromium\.Chromium --incognito$#Exec=fedory-launch-chromium --incognito#' \
  -e 's#^Exec=.*org\.chromium\.Chromium$#Exec=fedory-launch-chromium#' \
  /var/lib/flatpak/exports/share/applications/org.chromium.Chromium.desktop \
  >~/.local/share/applications/org.chromium.Chromium.desktop
