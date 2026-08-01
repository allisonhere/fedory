echo "Refreshing the Fedory login logo"

installed_logo="/usr/share/sddm/themes/fedory/logo.png"
new_logo="$FEDORY_PATH/default/sddm/fedory/logo.png"
legacy_logo_sha="845786a24f19b693de561137b6e489b3afd9c0f27f18aee41623c126d9a103ba"

[[ -f $installed_logo && -f $new_logo ]] || exit 0

installed_logo_sha=$(sha256sum "$installed_logo" | cut -d ' ' -f 1)
if [[ $installed_logo_sha == $legacy_logo_sha ]]; then
  pkexec install -m 0644 "$new_logo" "$installed_logo"
fi
