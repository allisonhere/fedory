# Display fix for ASUS ExpertBook B9406 (Panther Lake / Xe3 iGPU).
#
# Panel Replay is Xe3-new, default-on in the xe driver, and has a broken
# exit/wake path on this eDP panel: the panel latches the last-presented
# frame in self-refresh and never wakes for subsequent atomic commits, so
# the screen only updates on a full modeset (e.g. a VT switch). The older
# xe.enable_psr=0 knob does not cover Panel Replay.
#
# Fedora-native rewrite: Limine's limine-entry-tool.d KERNEL_CMDLINE
# drop-ins become a grubby --update-kernel=ALL --args= call (same pattern
# as fedory-hibernation-setup).

if fedory-hw-asus-expertbook-b9406; then
  sudo grubby --update-kernel=ALL --args="xe.enable_panel_replay=0"
fi
