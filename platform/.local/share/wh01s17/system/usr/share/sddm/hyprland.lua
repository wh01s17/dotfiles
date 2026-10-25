-- Minimal Hyprland config for the SDDM Wayland greeter.
-- SDDM starts the greeter itself after the compositor is ready.
-- Scale 1 like the session profiles; left on auto, Hyprland scales a 1080p
-- laptop panel up and the greeter looks oversized.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },

  animations = {
    enabled = false,
  },
})
