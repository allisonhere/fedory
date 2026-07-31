# Seed ~/.config with Fedory's shipped user configs. Upstream Omarchy gets
# this for free from /etc/skel (populated by the omarchy/omarchy-settings
# pacman packages themselves) -- Fedory has no package install to piggyback
# on (see docs/scope.md), so bootstrapping onto an existing $HOME needs its
# own explicit seed step.
#
# Non-destructive: -n skips any file the user already has, so reruns (e.g.
# a second bootstrap after adding hardware quirks) never clobber existing
# customizations. fedory-reinstall-configs is the explicit, destructive
# "reset to shipped defaults" path -- see that script for the overwrite
# behavior /etc/skel gives upstream for free on a fresh useradd.

mkdir -p ~/.config
cp -rn "$FEDORY_PATH/config/." ~/.config/
