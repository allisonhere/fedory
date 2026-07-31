# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run fedory-restart-xcompose to apply changes

# Include fast emoji access
include "/usr/share/fedory/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$FEDORY_USER_NAME"
<Multi_key> <space> <e> : "$FEDORY_USER_EMAIL"
EOF
