# Install the core Fedory desktop: Hyprland, Quickshell, terminal, fonts,
# and the rest of install/fedory-base.packages, plus Docker CE (which needs
# its own dnf repo, not a package-map entry -- see that file's header for
# why). This is the step bootstrap.sh was missing entirely: previously
# nothing installed the actual desktop, only git+gum before handing off to
# fedory-setup-system. Runs first in install/config/all.sh since later
# leaves (docker.sh, theme-system.sh, etc.) assume this software exists.

source "$FEDORY_INSTALL/helpers/ui.sh"

mapfile -t base_packages < <(grep -v '^#' "$FEDORY_PATH/install/fedory-base.packages" | grep -v '^$')
ui_info "Installing ${#base_packages[@]} core Fedory packages (this takes a while on first run)..."
fedory-pkg-add "${base_packages[@]}"

if fedory-cmd-missing docker; then
  # Not idempotent on every dnf5 version -- a rerun where the repo file
  # already exists from a previous attempt can error here. That shouldn't
  # block the rest of this leaf (or worse, silently skip straight to
  # `fedory-pkg-add docker-ce ...` against an unconfigured repo, which is
  # what actually happened: the addrepo call failed with nothing checking
  # it, docker-ce/docker-ce-cli/containerd.io were then requested with no
  # matching repo enabled, --skip-unavailable let dnf quietly drop them,
  # and enable-services.sh only found that out later as "Unit docker.socket
  # does not exist" -- by which point it had already aborted before
  # reaching the GDM->SDDM switch further down that same script).
  if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
    ui_info "Adding the Docker CE dnf repo..."
    dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo \
      || ui_warn "could not add the Docker CE dnf repo -- Docker packages below will likely fail to install"
  fi
  fedory-pkg-add docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if fedory-cmd-present docker; then
  systemctl enable docker || ui_warn "could not enable the docker service"
else
  ui_warn "docker did not install -- skipping docker.service enable (see the Docker CE repo message above)"
fi
