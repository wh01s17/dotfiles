-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Laptop panel with an optional mirrored projector.
hl.monitor({ output = "eDP-1", mode = "1920x1080@60.056", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1, mirror = "eDP-1" })

-- Alternative layouts kept as Lua examples:
-- Omen 4K + laptop:
-- hl.monitor({ output = "DP-1", mode = "3840x2160@60", position = "0x0", scale = 1 })
-- hl.monitor({ output = "eDP-1", mode = "1920x1080@120", position = "3840x0", scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x-1080", scale = 1 })
--
-- HP 4K + laptop:
-- hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "0x0", scale = 1 })
-- hl.monitor({ output = "eDP-1", mode = "1920x1080@60.056", position = "3840x0", scale = 1 })
--
-- Projector to the right instead of mirrored:
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1200@59.95", position = "1920x0", scale = 1 })
