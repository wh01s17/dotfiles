-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- machine-profile.lua is intentionally local and ignored by Git. A missing
-- selector leaves the safe preferred/automatic rule above in effect.
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

	require(profile_module)
elseif not tostring(machine_profile):find("module 'hypr.machine-profile' not found", 1, true) then
	error(machine_profile)
end
