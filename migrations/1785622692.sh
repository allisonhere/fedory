echo "Repairing tablet rotation and on-screen keyboard support"

[[ -f $HOME/.local/state/fedory/tablet/enabled ]] || exit 0

fedory-install-tablet-keyboard

unit_dir="$HOME/.config/systemd/user"
mkdir -p "$unit_dir"
cp -f "$FEDORY_PATH/config/systemd/user/fedory-tablet-keyboard.service" "$unit_dir/"
cp -f "$FEDORY_PATH/config/systemd/user/fedory-tablet-rotation.service" "$unit_dir/"

chromium_flags="$HOME/.config/chromium-flags.conf"
if [[ -f $chromium_flags ]]; then
  grep -qxF -- '--enable-wayland-ime' "$chromium_flags" || printf '%s\n' '--enable-wayland-ime' >>"$chromium_flags"
  grep -qxF -- '--wayland-text-input-version=3' "$chromium_flags" || printf '%s\n' '--wayland-text-input-version=3' >>"$chromium_flags"
fi

chromium_desktop=/var/lib/flatpak/exports/share/applications/org.chromium.Chromium.desktop
if [[ -f $chromium_desktop ]]; then
  mkdir -p "$HOME/.local/share/applications"
  sed -e 's#^Exec=.*org\.chromium\.Chromium @@u %U @@$#Exec=fedory-launch-chromium %U#' \
    -e 's#^Exec=.*org\.chromium\.Chromium --incognito$#Exec=fedory-launch-chromium --incognito#' \
    -e 's#^Exec=.*org\.chromium\.Chromium$#Exec=fedory-launch-chromium#' \
    "$chromium_desktop" >"$HOME/.local/share/applications/org.chromium.Chromium.desktop"
  update-desktop-database "$HOME/.local/share/applications"
fi

systemctl --user daemon-reload
systemctl --user try-restart fedory-tablet-keyboard.service fedory-tablet-rotation.service
