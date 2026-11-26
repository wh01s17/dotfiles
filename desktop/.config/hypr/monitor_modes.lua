-- Per-output modes chosen from the shell's Display panel. The panel writes
-- `OUTPUT=WIDTHxHEIGHT@RATE` lines to the state file below and reloads
-- Hyprland; monitors.lua reads them back so the choice survives every reload,
-- theme switch and reboot. A missing file simply leaves the defaults in place.
local M = {}

local function state_file()
	local state_home = os.getenv("XDG_STATE_HOME")
	if state_home then
		return state_home .. "/wh01s17/monitor-modes.conf"
	end

	local home = os.getenv("HOME")
	return home and (home .. "/.local/state/wh01s17/monitor-modes.conf") or nil
end

-- Resolutions the kernel parsed from the EDID of whatever display is plugged
-- into `output` right now, preferred mode first (DRM sorts it to the top).
-- nil when the connector doesn't exist or nothing is connected, so callers
-- fall back to their defaults instead of guessing.
function M.connector_modes(output, root)
	if not tostring(output or ""):match("^[%w._-]+$") then
		return nil
	end

	root = root or "/sys/class/drm"
	for card = 0, 15 do
		local file = io.open(string.format("%s/card%d-%s/modes", root, card, output), "r")
		if file then
			local modes = {}
			for line in file:lines() do
				local width, height = line:match("^(%d+)x(%d+)")
				if width then
					modes[#modes + 1] = { width = tonumber(width), height = tonumber(height) }
				end
			end
			file:close()
			return #modes > 0 and modes or nil
		end
	end
	return nil
end

local function supports(modes, width, height)
	for _, mode in ipairs(modes) do
		if mode.width == width and mode.height == height then
			return true
		end
	end
	return false
end

-- Modes are saved per connector, not per display: drop a saved mode the
-- display now on that connector can't do (e.g. a 4K pick left behind after
-- swapping in a 1080p monitor), so it comes up at its own preferred mode.
function M.read(path, sysfs_root)
	local modes = {}
	local file = path and io.open(path, "r") or nil
	if not file then
		return modes
	end

	for line in file:lines() do
		local output, mode = line:match("^([%w._-]+)=(%d+x%d+@[%d.]+)%s*$")
		if output and mode then
			local available = M.connector_modes(output, sysfs_root)
			local width, height = mode:match("^(%d+)x(%d+)@")
			if not available or supports(available, tonumber(width), tonumber(height)) then
				modes[output] = mode
			end
		end
	end

	file:close()
	return modes
end

function M.load()
	return M.read(state_file())
end

-- Width/height of a mode string, for profiles that lay outputs out relative to
-- each other and must follow a resolution change. "preferred" (or any mode
-- without a size) resolves to the connected display's native resolution when
-- `output` is given, so layouts follow whatever monitor is plugged in.
function M.size(mode, fallback_width, fallback_height, output)
	local width, height = tostring(mode or ""):match("^(%d+)x(%d+)@")
	if width then
		return tonumber(width), tonumber(height)
	end

	local available = output and M.connector_modes(output) or nil
	if available then
		return available[1].width, available[1].height
	end
	return fallback_width, fallback_height
end

return M
