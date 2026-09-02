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

-- Resize the focused window from the keyboard, the same job SUPER + right drag
-- does with the mouse. Repeating so holding an arrow scales smoothly.
o.bind("SUPER + CTRL + SHIFT + RIGHT", "Widen window", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + CTRL + SHIFT + LEFT", "Narrow window", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + CTRL + SHIFT + DOWN", "Heighten window", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })
o.bind("SUPER + CTRL + SHIFT + UP", "Shorten window", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
