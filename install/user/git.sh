# Set identification from install inputs
if [[ -n ${FEDORY_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$FEDORY_USER_NAME"
fi

if [[ -n ${FEDORY_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$FEDORY_USER_EMAIL"
fi
