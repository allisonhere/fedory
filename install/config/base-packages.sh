# Install the core Fedory desktop: Hyprland, Quickshell, terminal, fonts,
# and the rest of install/fedory-base.packages, plus Docker CE (which needs
# its own dnf repo, not a package-map entry -- see that file's header for
# why). This is the step bootstrap.sh was missing entirely: previously
# nothing installed the actual desktop, only git+gum before handing off to
# fedory-setup-system. Runs first in install/config/all.sh since later
# leaves (docker.sh, theme-system.sh, etc.) assume this software exists.

echo "Installing core Fedory packages (this takes a while on first run)..."

mapfile -t base_packages < <(grep -v '^#' "$FEDORY_PATH/install/fedory-base.packages" | grep -v '^$')
fedory-pkg-add "${base_packages[@]}"

if fedory-cmd-missing docker; then
  echo "Adding the Docker CE dnf repo..."
  dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
  fedory-pkg-add docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable docker
