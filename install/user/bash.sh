# Add Fedory's shell integrations without replacing an existing Fedora or
# user-maintained Bash configuration.

bashrc="$HOME/.bashrc"
source_line='[[ -n ${FEDORY_PATH:-} && -r $FEDORY_PATH/default/bash/init ]] && source "$FEDORY_PATH/default/bash/init"'

touch "$bashrc"
if ! grep -qxF "$source_line" "$bashrc"; then
  printf '\n# Fedory shell integrations\n%s\n' "$source_line" >> "$bashrc"
fi
