# Enable thermald for Intel laptops (Sandy Bridge and newer)
# Thermald is useful for Intel Sandy Bridge (2nd gen Core, model 42/45) and newer CPUs.

if wh01s17-hw-intel; then
  # Check if Sandy Bridge or newer (model >= 42). Sandy Bridge: model 42 (mobile), 45 (desktop)
  cpu_model=$(grep -m1 "^model\s*:" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | tr -d ' ')
  cpu_model=${cpu_model:-0}
  if ((cpu_model >= 42)) && wh01s17-battery-present; then
    wh01s17-pkg-add thermald
    sudo systemctl enable thermald.service
  fi
fi
