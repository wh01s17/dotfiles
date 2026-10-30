-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- wh01s17's bootstrap keeps path setup out of this user config.
dofile((os.getenv("WH01S17_PATH") or (os.getenv("HOME") .. "/.local/share/wh01s17")) .. "/default/hypr/bootstrap.lua")

-- Disable all wh01s17 default bindings. Add your own in hypr/bindings.lua.
-- wh01s17_default_bindings = false
--
-- Or disable only bindings for wh01s17's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- wh01s17_preinstalled_bindings = false

-- Load wh01s17 defaults.
require("default.hypr.wh01s17")

-- Put your personal overrides in these files. They're loaded after wh01s17's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
