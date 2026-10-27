package.path = "desktop/.config/?.lua;" .. package.path
local layout = require("hypr.monitor_layout")
local emitted = {}
hl = { monitor = function(rule) emitted[#emitted + 1] = rule end }

local path = os.tmpname()
local file = assert(io.open(path, "w"))
file:write("layout=external\ninternal=eDP-1\nexternal=DP-1\nexternal=HDMI-A-1\nexternal=bad output\n")
file:close()
local state = layout.read(path)
os.remove(path)
assert(state.layout == "external" and state.internal == "eDP-1")
assert(state.externals["DP-1"] and state.externals["HDMI-A-1"])
assert(not state.externals["bad output"])

local rules = {
	{ output = "eDP-1", mode = "1920x1080@120", scale = 1, position = "3840x0" },
	{ output = "DP-1", mode = "3840x2160@60", scale = 1.25, position = "0x0" },
	{ output = "HDMI-A-1", mode = "1920x1080@60", scale = 1, position = "0x-1080" },
}
local arrangement = { root = "eDP-1", links = {
	{ output = "DP-1", anchor = "eDP-1", side = "left", offset = 0 },
	{ output = "HDMI-A-1", anchor = "DP-1", side = "above", offset = 0 },
} }
layout.load_arrangement = function() return arrangement end
local function mode_for(_, fallback) return fallback end
local function scale_for(_, fallback) return fallback end
local function apply(selection, kind)
	emitted = {}
	layout.apply({ layout = kind or "external", internal = "eDP-1", externals = selection }, rules, mode_for, scale_for)
	local final = {}
	for _, rule in ipairs(emitted) do final[rule.output] = rule end
	return final
end

local one = apply({ ["DP-1"] = true })
assert(one[""].disabled and one["HDMI-A-1"].disabled)
assert(one["DP-1"].disabled == false and one["DP-1"].scale == 1.25)
assert(one["DP-1"].position == "-3072x0") -- preserved arrangement
assert(one["eDP-1"].disabled == false) -- guarded shell toggle disables it later
local two = apply({ ["DP-1"] = true, ["HDMI-A-1"] = true })
assert(two["DP-1"].disabled == false and two["HDMI-A-1"].disabled == false)
local unknown = apply({ ["DP-9"] = true })
assert(unknown["DP-1"].disabled and unknown["HDMI-A-1"].disabled)
assert(unknown["DP-9"].disabled == false and unknown["DP-9"].mode == "preferred")
assert(unknown["eDP-1"].disabled == false)
local legacy = apply(nil)
assert(legacy[""] == nil and legacy["DP-1"].disabled ~= true)
local extend = apply({ ["DP-1"] = true }, "extend")
assert(extend[""] == nil and extend["HDMI-A-1"].disabled ~= true)
local laptop = apply({ ["DP-1"] = true }, "internal")
assert(laptop["DP-1"].disabled and laptop["HDMI-A-1"].disabled)
print("External display layout passed")
