-- Display layout picked in the shell's Display panel: extend, mirror, internal
-- (laptop panel only) or external (external outputs only). The panel writes
-- `layout=NAME` and `internal=OUTPUT` lines to the state file below and reloads
-- Hyprland; monitors.lua applies the layout on top of the profile's own rules.
-- A missing file leaves the profile's arrangement untouched.
local M = {}

local layouts = { extend = true, mirror = true, internal = true, external = true }

local function state_file()
	local state_home = os.getenv("XDG_STATE_HOME")
	if state_home then
		return state_home .. "/omarchy/monitor-layout.conf"
	end

	local home = os.getenv("HOME")
	return home and (home .. "/.local/state/omarchy/monitor-layout.conf") or nil
end

function M.read(path)
	local state = {}
	local file = path and io.open(path, "r") or nil
	if not file then
		return state
	end

	for line in file:lines() do
		local layout = line:match("^layout=(%a+)%s*$")
		local internal = line:match("^internal=([%w._-]+)%s*$")
		if layout and layouts[layout] then
			state.layout = layout
		end
		if internal then
			state.internal = internal
		end
	end

	file:close()
	return state
end

function M.load()
	return M.read(state_file())
end

-- Run `configure` while recording every hl.monitor rule it emits, so apply()
-- can re-target the profile's outputs without each profile knowing layouts.
function M.capture(configure)
	local rules = {}
	local monitor = hl.monitor

	hl.monitor = function(rule)
		rules[#rules + 1] = rule
		return monitor(rule)
	end
	local ok, err = pcall(configure)
	hl.monitor = monitor

	if not ok then
		error(err, 0)
	end
	return rules
end

-- Later rules for the same output win, so these overrides only need to follow
-- the profile. `""` is Hyprland's catch-all, covering outputs no profile names
-- (a projector on a port nobody planned for).
function M.apply(state, rules, mode_for, scale_for)
	local layout, internal = state.layout, state.internal
	if not layout or not internal then
		return
	end

	local internal_rule
	local externals = {}
	for _, rule in ipairs(rules) do
		if rule.output == internal then
			internal_rule = rule
		elseif rule.output ~= "" then
			externals[rule.output] = rule
		end
	end

	local internal_scale = internal_rule and internal_rule.scale or scale_for(internal, 1)
	if not internal_rule and (layout == "mirror" or layout == "internal") then
		-- The catch-all below must not land on the panel itself.
		hl.monitor({
			output = internal,
			mode = mode_for(internal, "preferred"),
			position = "0x0",
			scale = internal_scale,
		})
	end

	if layout == "mirror" then
		hl.monitor({ output = "", mode = "preferred", position = "auto", scale = internal_scale, mirror = internal })
		for output, rule in pairs(externals) do
			hl.monitor({ output = output, mode = rule.mode or "preferred", position = "auto", scale = internal_scale, mirror = internal })
		end
	elseif layout == "internal" then
		hl.monitor({ output = "", disabled = true })
		for output in pairs(externals) do
			hl.monitor({ output = output, disabled = true })
		end
	else
		-- extend/external: undo profile mirrors (hp-gray mirrors by default).
		-- Rules for one output merge, so the mirror has to be cleared explicitly.
		-- External-only also sets Omarchy's internal-monitor-disable toggle,
		-- which the clamshell watcher honours instead of re-enabling the panel.
		for output, rule in pairs(externals) do
			if rule.mirror then
				hl.monitor({ output = output, mode = rule.mode or "preferred", position = "auto-right", scale = rule.scale, mirror = "" })
			end
		end
	end
end

return M
