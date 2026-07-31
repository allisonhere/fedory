SNAPPER_CONFIG_PATH="${FEDORY_SNAPPER_CONFIG_PATH:-/etc/snapper/configs/root}"
SNAPPER_CONF_PATH="${FEDORY_SNAPPER_CONF_PATH:-/etc/conf.d/snapper}"
template="${FEDORY_SNAPPER_TEMPLATE:-${FEDORY_PATH:-/usr/share/fedory}/default/snapper/root}"

source "$FEDORY_INSTALL/helpers/ui.sh"
ui_info "Configuring Fedory Snapper snapshot retention"

# Fedora Workstation defaults to Btrfs since Fedora 33 with a root subvolume
# layout snapper can manage directly, same as upstream's assumption. If the
# root filesystem isn't Btrfs (custom partitioning at install time), skip
# quietly rather than fail the whole install over an optional feature.
if ! findmnt -no FSTYPE / | grep -q btrfs; then
  ui_warn "Root filesystem is not Btrfs; skipping Snapper setup."
  return 0 2>/dev/null || exit 0
fi

# A real bootstrap run showed this leaf assumed `snapper` was already on
# PATH and failed outright ("snapper: command not found") -- nothing in
# the base package list installs it.
fedory-pkg-add snapper

if [[ ! -f $SNAPPER_CONFIG_PATH ]]; then
  mkdir -p "$(dirname "$SNAPPER_CONFIG_PATH")"

  if [[ ${FEDORY_SNAPPER_CONFIGURE_TEST:-0} == "1" ]]; then
    : >"$SNAPPER_CONFIG_PATH"
  else
    snapper --no-dbus -c root create-config / >/dev/null 2>&1 || snapper -c root create-config / >/dev/null
  fi
fi

install -m 0644 "$template" "$SNAPPER_CONFIG_PATH"

mkdir -p "$(dirname "$SNAPPER_CONF_PATH")"
printf '%s\n' 'SNAPPER_CONFIGS="root"' >"$SNAPPER_CONF_PATH"
chmod 0644 "$SNAPPER_CONF_PATH"

systemctl disable --now snapper-timeline.timer >/dev/null 2>&1 || true
systemctl enable --now snapper-cleanup.timer >/dev/null 2>&1 || true

# Upstream also syncs snapshots into the Limine boot menu
# (limine-snapper-sync.service), which is Arch/Limine-specific. Fedora's
# equivalent is grub2-btrfs (boots directly into a snapshot from the GRUB
# menu) -- not enabled by default here since it requires regenerating
# grub.cfg and isn't packaged in every Fedora repo config. See
# packaging/package-map.tsv for status; this is a good Phase 8+ addition
# once that's resolved.
