# Upstream's post-install/pacman.sh exists to restore the final, online
# pacman.conf/mirrorlist after the ISO's offline target install used a
# temporary offline config in the chroot -- see docs/scope.md for why Fedory
# has no offline-chroot install phase at all: bootstrap.sh runs directly
# against a live, already-online Fedora system, so dnf's repo configuration
# never needs a post-install restore step.
#
# Intentionally a no-op. Kept as a named stage (rather than removed from
# install/post-install/all.sh) so the stage list stays a legible 1:1 map
# against upstream's, and so a future Fedora-specific post-package-install
# fixup has an obvious home instead of getting bolted onto an unrelated
# script.
:
