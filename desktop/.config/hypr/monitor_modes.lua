-- Per-output modes chosen from the shell's Display panel. The panel writes
-- `OUTPUT=WIDTHxHEIGHT@RATE` lines to the state file below and reloads
-- Hyprland; monitors.lua reads them back so the choice survives every reload,
-- theme switch and reboot. A missing file simply leaves the defaults in place.
local M = {}

local function state_file()
	local state_home = os.getenv("XDG_STATE_HOME")
	if state_home then
		return state_home .. "/omarchy/monitor-modes.conf"
	end

	local home = os.getenv("HOME")
	return home and (home .. "/.local/state/omarchy/monitor-modes.conf") or nil
end

function M.read(path)
	local modes = {}
	local file = path and io.open(path, "r") or nil
	if not file then
		return modes
	end

	for line in file:lines() do
		local output, mode = line:match("^([%w._-]+)=(%d+x%d+@[%d.]+)%s*$")
		if output and mode then
			modes[output] = mode
		end
	end

	file:close()
	return modes
end

function M.load()
	return M.read(state_file())
end

-- Width/height of a mode string, for profiles that lay outputs out relative to
-- each other and must follow a resolution change.
function M.size(mode, fallback_width, fallback_height)
	local width, height = tostring(mode or ""):match("^(%d+)x(%d+)@")
	return tonumber(width) or fallback_width, tonumber(height) or fallback_height
end

return M
