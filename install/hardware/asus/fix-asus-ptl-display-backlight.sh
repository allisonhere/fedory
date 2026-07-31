# Display backlight fix for ASUS Panther Lake / Xe3 iGPU laptops.
# Enabled only for ExpertBook B9406 and Zenbook UX5406AA for now.
# Other models need confirmation whether the issue exists there too.
#
# The panel's EDID on eDP-1 reads as empty, so xe takes backlight type from
# VBT (which says PWM) but the panel actually wants DPCD AUX backlight.
# Without xe.enable_dpcd_backlight=1, intel_backlight sysfs writes succeed
# but produce no visible change; brightness is effectively binary.
#
# Fedora-native rewrite: grubby instead of Limine's limine-entry-tool.d
# (same pattern as fix-asus-ptl-b9406-display.sh).

if fedory-hw-asus-expertbook-b9406 || fedory-hw-asus-zenbook-ux5406aa; then
  sudo grubby --update-kernel=ALL --args="xe.enable_dpcd_backlight=1"
fi
