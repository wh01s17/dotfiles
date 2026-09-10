-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local default_gdk_scale = 1
local default_monitor_scale = 1
local output_scales = require("hypr.monitor_scales").load()
local monitor_modes = require("hypr.monitor_modes")
local output_modes = monitor_modes.load()

local function scale_for(output, fallback)
	return output_scales[output] or fallback
end

-- Resolution picked in the shell's Display panel, falling back to whatever the
-- profile hardcodes.
local function mode_for(output, fallback)
	return output_modes[output] or fallback
end

-- machine-profile.lua is intentionally local and ignored by Git. A missing
-- selector leaves the safe preferred/automatic rules below in effect.
local loaded, machine_profile = pcall(require, "hypr.machine-profile")

if loaded then
	local profiles = {
		["hp-gray"] = "hypr.profiles.hp-gray",
		omen = "hypr.profiles.omen",
	}

	local profile_module = profiles[machine_profile]
	if not profile_module then
		error("Unknown machine profile: " .. tostring(machine_profile))
	end

	local configure_profile = require(profile_module)

	-- GDK_SCALE is global, so keep it neutral for mixed-DPI profiles and let
	-- Hyprland apply the persisted compositor scale to each output.
	hl.env("GDK_SCALE", tostring(default_gdk_scale))
	configure_profile(scale_for, mode_for, monitor_modes.size)
elseif not tostring(machine_profile):find("module 'hypr.machine-profile' not found", 1, true) then
	error(machine_profile)
else
	hl.env("GDK_SCALE", tostring(default_gdk_scale))
	hl.monitor({ output = "", mode = "preferred", position = "auto", scale = default_monitor_scale })

	local tuned = {}
	for output in pairs(output_scales) do
		tuned[output] = true
	end
	for output in pairs(output_modes) do
		tuned[output] = true
	end

	for output in pairs(tuned) do
		hl.monitor({
			output = output,
			mode = mode_for(output, "preferred"),
			position = "auto",
			scale = scale_for(output, default_monitor_scale),
		})
	end
end
