echo "Repairing the Fedory Vesper background and mise tool wrappers"

for wrapper in "$HOME/.local/bin/"*; do
  [[ -f $wrapper ]] || continue

  if grep -qE '^mise use -g ".+" \|\| exit 1$' "$wrapper" &&
    grep -qE '^exec mise x "[^"]+" -- "[^"]+" "\$@"$' "$wrapper"; then
    sed -i \
      -e '/^mise use -g ".*" || exit 1$/d' \
      -e 's/^exec mise x /exec mise --quiet x /' \
      "$wrapper"
  fi
done

theme_name=$(cat "$HOME/.local/state/fedory/current/theme.name" 2>/dev/null || true)
current_background=$(readlink -f "$HOME/.local/state/fedory/current/background" 2>/dev/null || true)

if [[ $theme_name == "fedory-vesper" &&
  ( $current_background == *.webp || ! -f $current_background ) ]]; then
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    fedory-theme-set "Fedory Vesper"
  else
    FEDORY_THEME_HEADLESS=1 fedory-theme-set "Fedory Vesper"
  fi
fi
