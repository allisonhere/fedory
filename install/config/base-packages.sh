# Install the core Fedory desktop: Hyprland, Quickshell, terminal, fonts,
# and the rest of install/fedory-base.packages, plus Docker CE (which needs
# its own dnf repo, not a package-map entry -- see that file's header for
# why). This is the step bootstrap.sh was missing entirely: previously
# nothing installed the actual desktop, only git+gum before handing off to
# fedory-setup-system. Runs first in install/config/all.sh since later
# leaves (docker.sh, theme-system.sh, etc.) assume this software exists.

source "$FEDORY_INSTALL/helpers/ui.sh"
source "$FEDORY_INSTALL/helpers/groups.sh"

# Fedora 44 Workstation uses tuned-ppd as its Power Profiles D-Bus provider,
# while Fedory's runtime commands use powerprofilesctl from
# power-profiles-daemon. The two providers conflict. Remove only the shim and
# preserve tuned's dependencies; a normal dnf remove would autoremove tuned,
# kernel-tools, and other still-useful packages with it.
if rpm -q tuned-ppd &>/dev/null; then
  ui_info "Replacing tuned-ppd with power-profiles-daemon"
  dnf remove -y --no-autoremove tuned-ppd
fi

mapfile -t base_packages < <(grep -v '^#' "$FEDORY_PATH/install/fedory-base.packages" | grep -v '^$')

# Optional groups the user can decline at install time. fedory_group_packages
# prints nothing for a disabled group, so this appends only what was chosen --
# and with no choice recorded it appends everything, which is the pre-groups
# behaviour. Installed in the same transaction as the base list so dnf resolves
# the lot once rather than per group.
for fedory_group in office-media printing; do
  mapfile -t group_packages < <(fedory_group_packages "$fedory_group")
  if (( ${#group_packages[@]} > 0 )); then
    base_packages+=("${group_packages[@]}")
  else
    ui_info "Skipping the $fedory_group package group (declined at install)"
  fi
done

ui_info "Installing ${#base_packages[@]} core Fedory packages (this takes a while on first run)..."
fedory-pkg-add "${base_packages[@]}"

if ! fedory_group_enabled docker; then
  ui_info "Skipping Docker CE (declined at install)"
elif ! rpm -q docker-ce &>/dev/null; then
  # Checking for a `docker` command on PATH (fedory-cmd-missing docker) is
  # not enough: a real bootstrap run showed the Docker CE install block
  # never even ran, no "Adding the Docker CE dnf repo..." message printed
  # anywhere, docker.socket/docker group never created -- because `docker`
  # already resolved to something else on that system (podman-docker's
  # shim is the likely culprit; Fedora Workstation can ship it by default).
  # rpm -q docker-ce checks for the actual Docker CE package specifically.
  #
  # Also not idempotent on every dnf5 version -- a rerun where the repo
  # file already exists from a previous attempt can error here. That
  # shouldn't block the rest of this leaf.
  if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
    ui_info "Adding the Docker CE dnf repo..."
    dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo \
      || ui_warn "could not add the Docker CE dnf repo -- Docker packages below will likely fail to install"
  fi
  fedory-pkg-add docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if ! fedory_group_enabled docker; then
  : # Declined above; not installing it is the expected outcome, not a problem.
elif rpm -q docker-ce &>/dev/null; then
  systemctl enable docker || ui_warn "could not enable the docker service"
else
  ui_warn "docker-ce did not install -- skipping docker.service enable (see the Docker CE repo message above)"
fi
