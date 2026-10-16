# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run wh01s17-restart-xcompose to apply changes

# Include fast emoji access
include "%H/.local/share/wh01s17/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$WH01S17_USER_NAME"
<Multi_key> <space> <e> : "$WH01S17_USER_EMAIL"
EOF
