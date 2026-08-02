# Install the Fedory boot splash. The theme ships in default/plymouth/ but
# nothing in the install path ever deployed it -- see
# install/helpers/plymouth.sh for the full rationale and for the [n/3] markers
# that drive this leaf's progress bar.

source "$FEDORY_INSTALL/helpers/plymouth.sh"

fedory_apply_plymouth_theme
