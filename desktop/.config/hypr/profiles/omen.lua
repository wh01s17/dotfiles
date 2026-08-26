-- Omen: 4K display, laptop panel to its right, and 1080p display above it.
local function scaled_position(x, y, scale)
	return string.format("%gx%g", x / scale, y / scale)
end

return function(scale_for)
	local desktop_scale = scale_for("DP-1", 1)
	local laptop_scale = scale_for("eDP-1", 1)
	local upper_scale = scale_for("HDMI-A-1", 1)

	hl.monitor({ output = "DP-1", mode = "3840x2160@60", position = "0x0", scale = desktop_scale })
	hl.monitor({ output = "eDP-1", mode = "1920x1080@120", position = scaled_position(3840, 0, desktop_scale), scale = laptop_scale })
	hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = scaled_position(0, -1080, upper_scale), scale = upper_scale })
end
