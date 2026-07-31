# Update the locate database so `locate`/`fedory-file-select`-style lookups
# can find the installed system files immediately.
if command -v updatedb >/dev/null 2>&1; then
  updatedb
fi
