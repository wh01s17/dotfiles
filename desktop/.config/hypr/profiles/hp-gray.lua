-- HP Gray: laptop panel plus the classroom projector on HDMI. Whether the
-- projector mirrors or extends comes from the Display panel's layout selector.
return function(scale_for, mode_for)
	hl.monitor({
		output = "eDP-1",
		mode = mode_for("eDP-1", "1920x1080@60.056"),
		position = "0x0",
		scale = scale_for("eDP-1", 1),
	})
	hl.monitor({
		output = "HDMI-A-1",
		mode = mode_for("HDMI-A-1", "1920x1080@60"),
		position = "auto-right",
		scale = scale_for("HDMI-A-1", 1),
	})
end
