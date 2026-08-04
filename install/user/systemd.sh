# Install user units before first-run enables them in the live graphical
# session. Keep this copy non-destructive so local unit customizations survive
# a bootstrap rerun; migrations carry compatibility repairs for older units.
unit_dir="$HOME/.config/systemd/user"
mkdir -p "$unit_dir"
cp -n "$FEDORY_PATH/default/systemd/user/fedory-sleep-lock.service" "$unit_dir/"
