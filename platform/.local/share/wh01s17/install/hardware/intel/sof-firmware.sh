# Install Sound Open Firmware for Intel audio DSPs. The sof-audio-pci-intel-*
# driver family requires this firmware; without it PipeWire exposes only a
# Dummy Output sink.

if wh01s17-hw-intel-sof; then
  wh01s17-pkg-add sof-firmware
fi
