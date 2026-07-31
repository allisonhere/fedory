# Install mise itself. Fedora has no mise package (source-build status in
# packaging/package-map.tsv, unlike Arch's AUR/community package) -- mise's
# own official install script is the documented path, and it's inherently
# per-user (installs to ~/.local/bin), which is why this lives here in
# install/user/ rather than alongside the rest of install/fedory-base.packages
# in install/config/base-packages.sh. Runs before mise-work.sh and mise.sh,
# both of which assume mise is already on PATH -- fedory-finalize-user puts
# ~/.local/bin on PATH before running any install/user/*.sh leaf, so this
# only needs to install the binary, not export anything itself (each leaf
# runs in its own subshell -- see install/helpers/logging.sh's run_logged --
# so an export here wouldn't reach the leaves that need it anyway).

if fedory-cmd-missing mise; then
  curl https://mise.run | sh
fi
