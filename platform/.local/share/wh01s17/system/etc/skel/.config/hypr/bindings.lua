-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   wh01s17 menu keybindings --print

-- To disable every wh01s17 default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.wh01s17"), then add
-- only the bindings you want below:
--   wh01s17_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   wh01s17_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the wh01s17 root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "wh01s17 menu", "wh01s17-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "wh01s17-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "wh01s17-shell shell toggle core.emojis")
