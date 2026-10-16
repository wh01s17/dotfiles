-- Restore workspace layouts saved by wh01s17-hyprland-workspace-layout-toggle.

local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local layouts_dir = paths.state_home .. "/wh01s17/workspace-layouts"

require_all.files(layouts_dir, "wh01s17.workspace-layouts", { reload = true })
