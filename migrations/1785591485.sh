echo "Install missing portable tools and repair Fedora application launchers"

bash "$FEDORY_PATH/install/user/source-tools.sh"
bash "$FEDORY_PATH/install/user/bash.sh"

mkdir -p "$HOME/.config"
if [[ ! -e $HOME/.config/starship.toml ]]; then
  cp "$FEDORY_PATH/config/starship.toml" "$HOME/.config/starship.toml"
fi

imv_config="$HOME/.config/imv/config"
if [[ -f $imv_config ]]; then
  sed -i 's/tensaku-edit/pinta/g' "$imv_config"
fi

if [[ $(env -u BROWSER xdg-settings get default-web-browser) == "chromium.desktop" ]]; then
  env -u BROWSER xdg-settings set default-web-browser org.chromium.Chromium.desktop
fi
