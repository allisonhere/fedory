# Enable Flexible Return and Event Delivery on Intel Panther Lake.
#
# Fedora-native rewrite: grubby instead of Limine's limine-entry-tool.d
# (same pattern as the ASUS Panther Lake fixes).

if fedory-hw-intel-ptl; then
  if ! grubby --info=DEFAULT 2>/dev/null | grep -q 'fred=on'; then
    sudo grubby --update-kernel=ALL --args="fred=on"
  fi
fi
