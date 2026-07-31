source "$FEDORY_INSTALL/helpers/ui.sh"

# The docker group only exists once docker-ce actually installed
# (config/base-packages.sh, which runs before this leaf) -- if that failed
# for any reason, don't let this leaf's failure block anything after it.
if getent group docker >/dev/null; then
  usermod -aG docker "$FEDORY_INSTALL_USER"
else
  ui_warn "docker group doesn't exist yet -- skipping (see the Docker CE messages in config/base-packages.sh above)"
fi
