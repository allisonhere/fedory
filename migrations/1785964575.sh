echo "Install default coding agent mise wrappers"

if [[ ! -f $HOME/.local/state/fedory/preinstalls-removed ]]; then
  fedory-mise-install github:can1357/oh-my-pi omp
  fedory-mise-install npm:@xai-official/grok grok
  fedory-mise-install crush
elif [[ -f $HOME/.local/bin/omp ]] && grep -Fq 'mise --quiet x "oh-my-pi"' "$HOME/.local/bin/omp"; then
  rm -f "$HOME/.local/bin/omp"
fi
