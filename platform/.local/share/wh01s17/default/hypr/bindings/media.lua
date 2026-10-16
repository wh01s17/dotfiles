-- Volume, brightness, keyboard backlight, and touchpad controls.
o.bind("XF86AudioRaiseVolume", "Volume up", "wh01s17-audio-output-volume raise", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "wh01s17-audio-output-volume lower", { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", "wh01s17-audio-output-volume mute-toggle", { locked = true })
o.bind("XF86AudioMicMute", "Mute microphone", "wh01s17-audio-input-mute", { locked = true })
o.bind("XF86MonBrightnessUp", "Brightness up", "wh01s17-brightness-display +5%", { locked = true, repeating = true })
o.bind("XF86MonBrightnessDown", "Brightness down", "wh01s17-brightness-display 5%-", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessUp", "Brightness maximum", "wh01s17-brightness-display 100%", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessDown", "Brightness minimum", "wh01s17-brightness-display 1%", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessUp", "Keyboard brightness up", "wh01s17-brightness-keyboard up", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessDown", "Keyboard brightness down", "wh01s17-brightness-keyboard down", { locked = true, repeating = true })
o.bind("XF86KbdLightOnOff", "Keyboard backlight cycle", "wh01s17-brightness-keyboard cycle", { locked = true })
o.bind_toggle("XF86TouchpadToggle", "Toggle touchpad", "touchpad", { locked = true })
o.bind("XF86TouchpadOn", "Enable touchpad", "wh01s17-toggle-touchpad on", { locked = true })
o.bind("XF86TouchpadOff", "Disable touchpad", "wh01s17-toggle-touchpad off", { locked = true })

-- Precise volume and brightness controls.
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "wh01s17-audio-output-volume +1", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "wh01s17-audio-output-volume -1", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessUp", "Brightness up precise", "wh01s17-brightness-display +1%", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessDown", "Brightness down precise", "wh01s17-brightness-display 1%-", { locked = true, repeating = true })

-- Media controls.
o.bind("XF86AudioNext", "Next track", "wh01s17-shell media next", { locked = true })
o.bind("ALT + XF86AudioPlay", "Next track", "wh01s17-shell media next", { locked = true })
o.bind("XF86AudioPause", "Pause", "wh01s17-shell media playPause", { locked = true })
o.bind("XF86AudioPlay", "Play", "wh01s17-shell media playPause", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "wh01s17-shell media previous", { locked = true })
o.bind("ALT + SHIFT + XF86AudioPlay", "Previous track", "wh01s17-shell media previous", { locked = true })
o.bind("XF86Eject", "Eject media", "eject", { locked = true })

o.bind("SHIFT + XF86AudioMute", "Switch audio output", "wh01s17-audio-output-switch", { locked = true })
o.bind("SHIFT + XF86AudioPause", "Switch media source", "wh01s17-audio-source-switch", { locked = true })
o.bind("SHIFT + XF86AudioPlay", "Switch media source", "wh01s17-audio-source-switch", { locked = true })
