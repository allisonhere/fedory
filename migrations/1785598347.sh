echo "Refreshing the default screensaver logo"

branding="$HOME/.config/fedory/branding/screensaver.txt"

if [[ -f $branding ]]; then
  if cmp -s "$branding" <(printf '%s\n' \
    '' \
    '  ==============================================' \
    '   F E D O R Y' \
    '   A beautiful, modern & opinionated Hyprland' \
    '   desktop for Fedora.' \
    '  ==============================================') || \
    cmp -s "$branding" <(printf '%s\n' \
      '    ______ __________  ____  ______  __' \
      '   / ____// ____/ __ \/ __ \/ __ \ \/ /' \
      '  / /_   / __/ / / / / / / /_/ /\  /' \
      ' / __/  / /___/ /_/ / /_/ / _, _/ / /' \
      '/_/    /_____/_____/\____/_/ |_| /_/' \
      '' \
      '            FEDORA. REFINED.'); then
    cp "$FEDORY_PATH/logo.txt" "$branding"
  fi
fi
