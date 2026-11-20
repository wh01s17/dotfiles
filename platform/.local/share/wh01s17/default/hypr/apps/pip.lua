-- Picture-in-picture overlays.
o.window({ title = "(Picture.?in.?[Pp]icture)" }, { tag = "+pip" })
o.window({ tag = "pip" }, {
  tag = "-default-opacity",
  float = true,
  pin = true,
  size = { 600, 338 },
  keep_aspect_ratio = true,
  border_size = 0,
  opacity = "1 1",
  move = { "(monitor_w-window_w-40)", "(monitor_h*0.04)" },
})

-- Google Meet PiP uses the meeting title instead of "Picture-in-Picture".
-- A regular browser window opened on Meet is titled "Meet - Google Chrome"
-- too, so drop windows carrying the browser's own title suffix: only the
-- PiP window lacks it.
o.window({ tag = "chromium-based-browser", title = "^Meet - .+" }, { tag = "+meet-pip" })
o.window({ tag = "meet-pip", title = " - (Google Chrome|Chromium|Brave|Microsoft.?Edge|Vivaldi|Helium)$" }, { tag = "-meet-pip" })
o.window({ tag = "meet-pip" }, {
  tag = "-default-opacity",
  float = true,
  pin = true,
  size = { 600, 338 },
  keep_aspect_ratio = true,
  border_size = 0,
  opacity = "1 1",
  move = { "(monitor_w-window_w-40)", "(monitor_h-window_h-40)" },
})
