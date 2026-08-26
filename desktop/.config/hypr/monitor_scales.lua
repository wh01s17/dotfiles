local M = {}

local function state_file()
	local state_home = os.getenv("XDG_STATE_HOME")
	if state_home then
		return state_home .. "/omarchy/monitor-scaling.log"
	end

	local home = os.getenv("HOME")
	return home and (home .. "/.local/state/omarchy/monitor-scaling.log") or nil
end

function M.read(path)
	local scales = {}
	local file = path and io.open(path, "r") or nil
	if not file then
		return scales
	end

	for line in file:lines() do
		local output = line:match("\tmonitor=([%w._-]+)\t")
		local scale = tonumber(line:match("\tnew=([0-9]+%.?[0-9]*)\t"))

		if output and scale and scale >= 1 and scale <= 4 then
			scales[output] = scale
		end
	end

	file:close()
	return scales
end

function M.load()
	return M.read(state_file())
end

return M
