# Install Vulkan drivers matching detected GPU hardware
# (NVIDIA Vulkan is handled by nvidia.sh via the RPM Fusion NVIDIA driver)
#
# Fedora-native rewrite: Arch splits Vulkan ICDs per-vendor (vulkan-intel,
# vulkan-radeon); Fedora bundles Intel+AMD into one mesa-vulkan-drivers
# package, so there's no per-vendor lspci branch needed for those two.
# vulkan-asahi (Apple Silicon) has no Fedora package -- see
# packaging/package-map.tsv -- so that branch is dropped rather than
# guessed at.

if lspci | grep -iE "(VGA|Display).*(Intel|AMD)" > /dev/null; then
  fedory-pkg-add mesa-vulkan-drivers
fi
