-- HP Gray: classroom setup with the projector mirroring the laptop panel.
return function(scale_for)
	hl.monitor({ output = "eDP-1", mode = "1920x1080@60.056", position = "0x0", scale = scale_for("eDP-1", 1) })
	hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = scale_for("HDMI-A-1", 1), mirror = "eDP-1" })
end
