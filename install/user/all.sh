run_logged "$FEDORY_INSTALL/user/theme.sh"
run_logged "$FEDORY_INSTALL/user/chromium.sh"
run_logged "$FEDORY_INSTALL/user/git.sh"
run_logged "$FEDORY_INSTALL/user/xcompose.sh"
run_logged "$FEDORY_INSTALL/user/mise-work.sh"

# Vendor-specific per-user hardware fixups land here in Phase 8 (see
# install/user/hardware/ once populated), mirroring upstream's
# install/user/hardware/<vendor>/*.sh layout.

run_logged "$FEDORY_INSTALL/user/default-keyring.sh"
run_logged "$FEDORY_INSTALL/user/mise.sh"
