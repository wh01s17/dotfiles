-- Personal media keys. These do not replace any Omarchy default binding.
o.bind("CTRL + ALT + A", "Volume up", "omarchy audio output volume raise", { repeating = true })
o.bind("CTRL + ALT + Z", "Volume down", "omarchy audio output volume lower", { repeating = true })
o.bind("CTRL + ALT + O", "Play/pause", "omarchy shell media playPause")
o.bind("CTRL + ALT + P", "Next track", "omarchy shell media next")
o.bind("CTRL + ALT + I", "Previous track", "omarchy shell media previous")

-- WayScriber annotation controls.
o.bind("SUPER + ALT + A", "WayScriber - Show/hide", "wayscriber --daemon-toggle")
o.bind("SUPER + ALT + P", "WayScriber - Passthrough", "wayscriber --light-toggle")
o.bind("SUPER + ALT + D", "WayScriber - Draw/interact", "wayscriber --light-draw-toggle")
