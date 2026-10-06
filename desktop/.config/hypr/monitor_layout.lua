-- Display layout picked in the shell's Display panel: extend, mirror, internal
-- (laptop panel only) or external (external outputs only). The panel writes
-- `layout=NAME` and `internal=OUTPUT` lines to the state file below and reloads
-- Hyprland; monitors.lua applies the layout on top of the profile's own rules.
-- Extend (also a missing file) keeps the profile's placement unless the panel's
-- arrangement editor saved one.
local monitor_modes = require("hypr.monitor_modes")

local M = {}

local layouts = { extend = true, mirror = true, internal = true, external = true }

local function state_file(name)
	local state_home = os.getenv("XDG_STATE_HOME")
	if state_home then
		return state_home .. "/omarchy/" .. name
	end

	local home = os.getenv("HOME")
	return home and (home .. "/.local/state/omarchy/" .. name) or nil
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
	return M.read(state_file("monitor-layout.conf"))
end

-- Extend arrangement drawn in the Display panel's editor: `root=OUTPUT` plus
-- `OUTPUT=ANCHOR,SIDE,OFFSET` lines, each anchored to an output listed before
-- it. Relations rather than coordinates, so outputs stay touching after a
-- scale or resolution change.
local sides = { right = true, left = true, above = true, below = true }

function M.read_arrangement(path)
	local arrangement = { links = {} }
	local file = path and io.open(path, "r") or nil
	if not file then
		return arrangement
	end

	for line in file:lines() do
		local root = line:match("^root=([%w._-]+)%s*$")
		local output, anchor, side, offset = line:match("^([%w._-]+)=([%w._-]+),(%a+),(-?%d+)%s*$")
		if root then
			arrangement.root = root
		elseif output and sides[side] then
			table.insert(arrangement.links, { output = output, anchor = anchor, side = side, offset = tonumber(offset) })
		end
	end

	file:close()
	return arrangement
end

function M.load_arrangement()
	return M.read_arrangement(state_file("monitor-arrangement.conf"))
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- Logical size Hyprland lays the output out with: mode divided by scale.
local function geometry(output, rule, mode_for, scale_for)
	local mode = rule and rule.mode or mode_for(output, "preferred")
	local scale = tonumber(rule and rule.scale) or scale_for(output, 1)
	local width, height = monitor_modes.size(mode, 1920, 1080)
	return math.floor(width / scale + 0.5), math.floor(height / scale + 0.5), mode, scale
end

-- Place the root at 0x0 and every other output flush against its anchor. The
-- offset is clamped so the shared edge never shrinks to nothing when sizes
-- changed since the arrangement was saved.
function M.arrange(arrangement, rules, mode_for, scale_for)
	if not arrangement.root then
		return
	end

	local by_output = {}
	for _, rule in ipairs(rules) do
		if rule.output ~= "" then
			by_output[rule.output] = rule
		end
	end

	local placed = {}
	local function place(output, x, y)
		local width, height, mode, scale = geometry(output, by_output[output], mode_for, scale_for)
		placed[output] = { x = x, y = y, w = width, h = height }
		hl.monitor({ output = output, mode = mode, position = string.format("%dx%d", x, y), scale = scale })
	end

	place(arrangement.root, 0, 0)
	for _, link in ipairs(arrangement.links) do
		local anchor = placed[link.anchor]
		if anchor and not placed[link.output] then
			local width, height = geometry(link.output, by_output[link.output], mode_for, scale_for)
			local x, y
			if link.side == "right" or link.side == "left" then
				x = link.side == "right" and anchor.x + anchor.w or anchor.x - width
				y = anchor.y + clamp(link.offset, 1 - height, anchor.h - 1)
			else
				x = anchor.x + clamp(link.offset, 1 - width, anchor.w - 1)
				y = link.side == "below" and anchor.y + anchor.h or anchor.y - height
			end
			place(link.output, x, y)
		end
	end
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
	local layout, internal = state.layout or "extend", state.internal
	-- External-only switches the panel off through Omarchy's
	-- internal-monitor-disable toggle (set by the Display panel), which the
	-- clamshell watcher honours rather than re-enabling it every 2s.
	if layout == "extend" or layout == "external" then
		M.arrange(M.load_arrangement(), rules, mode_for, scale_for)
		return
	end
	if not internal then
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
	if not internal_rule then
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
	end
end

return M
