# Fedora-native rewrite of upstream's nvidia.sh.
#
# Arch differences this replaces:
#   - nvidia-open-dkms / nvidia-580xx-dkms (branch-specific DKMS packages,
#     built immediately by pacman's hook)              -> akmod-nvidia (RPM
#     Fusion). akmods builds the kernel module via akmods.service on next
#     boot rather than synchronously during install, so there's nothing to
#     force-build here; that's expected, not a bug.
#   - nvidia-utils / nvidia-580xx-utils / lib32-*-utils -> xorg-x11-drv-
#     nvidia-cuda (RPM Fusion bundles the userspace libs+CUDA together) and
#     xorg-x11-drv-nvidia-libs.i686 for 32-bit (matches
#     fedory-install-gaming-gpu-lib32's convention)
#   - kernel-headers detection via `pacman -Qqs`         -> kernel-devel is
#     enough; akmods resolves the running kernel itself, no manual
#     "-headers" package name to compute
#   - /etc/mkinitcpio.conf.d/nvidia.conf                 -> not needed:
#     akmod-nvidia's own post-install scripting integrates with dracut/
#     kernel-install automatically, unlike mkinitcpio which needs an
#     explicit MODULES+= drop-in
#
# RPM Fusion's non-GSP legacy driver story (pre-Turing cards) is less
# mature than Arch's own nvidia-580xx split -- very old cards may need
# akmod-nvidia-470xx or akmod-nvidia-390xx instead of plain akmod-nvidia.
# This installs the current akmod-nvidia branch in both cases and flags the
# legacy path for follow-up rather than guessing at an unverified package
# name.

source "$FEDORY_INSTALL/helpers/ui.sh"

if lspci | grep -qi 'nvidia'; then
  fedory-pkg-add kernel-devel

  if fedory-hw-nvidia-gsp; then
    PACKAGES=(akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs.i686)
  elif fedory-hw-nvidia-without-gsp; then
    ui_warn "This GPU predates NVIDIA's GSP firmware. RPM Fusion's plain akmod-nvidia may not support it -- verify whether akmod-nvidia-470xx or akmod-nvidia-390xx is needed instead (see this script's header)."
    PACKAGES=(akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs.i686)
  fi

  # Bail if no supported GPU
  if [[ -z ${PACKAGES+x} ]]; then
    ui_warn "No compatible driver for your NVIDIA GPU."
    exit 0
  fi

  fedory-pkg-add "${PACKAGES[@]}"

  # Per-session Hyprland NVIDIA env vars are handled by default/hypr/nvidia.lua.

  # Configure modprobe for early KMS
  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
EOF

  ui_info "NVIDIA akmod will build on first boot after this install completes (or run: sudo akmods --force), then reboot."
fi
