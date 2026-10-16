# Install MIPI camera support for Intel IPU7 hardware

if grep -q "OVTI08F4" /sys/bus/acpi/devices/*/hid 2>/dev/null; then
  wh01s17-pkg-add intel-ipu7-camera
fi
