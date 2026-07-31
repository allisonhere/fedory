# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/fedory/themes

if [[ ! -s $HOME/.local/state/fedory/current/theme.name ]]; then
  if [[ ${FEDORY_SETUP_CONTEXT:-runtime} == "bootstrap" ]]; then
    FEDORY_THEME_HEADLESS=1 fedory-theme-set "Tokyo Night"
  else
    fedory-theme-set "Tokyo Night"
  fi
fi

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/fedory/current/theme/btop.theme" ~/.config/btop/themes/current.theme
