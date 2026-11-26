-- Omen: main display on DP-1, laptop panel to its right, and a second display
-- above it on HDMI. External outputs default to whatever monitor is plugged in
-- (its preferred mode); the Display panel can override the mode per output.
local function scaled_position(x, y, scale)
	return string.format("%gx%g", x / scale, y / scale)
end

return function(scale_for, mode_for, mode_size)
	local desktop_scale = scale_for("DP-1", 1)
	local laptop_scale = scale_for("eDP-1", 1)
	local upper_scale = scale_for("HDMI-A-1", 1)

	local desktop_mode = mode_for("DP-1", "preferred")
	local laptop_mode = mode_for("eDP-1", "1920x1080@120")
	local upper_mode = mode_for("HDMI-A-1", "preferred")

	-- Neighbours sit relative to the main display's width and the upper
	-- display's height, so a resolution change has to move them with it.
	local desktop_width = mode_size(desktop_mode, 3840, 2160, "DP-1")
	local _, upper_height = mode_size(upper_mode, 1920, 1080, "HDMI-A-1")

	hl.monitor({ output = "DP-1", mode = desktop_mode, position = "0x0", scale = desktop_scale })
	hl.monitor({
		output = "eDP-1",
		mode = laptop_mode,
		position = scaled_position(desktop_width, 0, desktop_scale),
		scale = laptop_scale,
	})
	hl.monitor({
		output = "HDMI-A-1",
		mode = upper_mode,
		position = scaled_position(0, -upper_height, upper_scale),
		scale = upper_scale,
	})
end
