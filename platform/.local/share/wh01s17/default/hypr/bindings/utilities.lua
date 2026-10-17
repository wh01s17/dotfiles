o.bind("SUPER + SPACE", "wh01s17 menu", "wh01s17-menu toggle")
o.bind("SUPER + ALT + SPACE", "Apps menu", "wh01s17-menu toggle apps")
o.bind("SUPER + CTRL + E", "Emojis", "wh01s17-shell shell toggle core.emojis")
o.bind("SUPER + CTRL + C", "Capture menu", "wh01s17-menu toggle capture")
o.bind("SUPER + CTRL + O", "Toggle menu", "wh01s17-menu toggle toggle")
o.bind("SUPER + CTRL + H", "Hardware menu", "wh01s17-menu toggle hardware")
o.bind("SUPER + SHIFT + code:201", "wh01s17 menu", "wh01s17-menu toggle root")
o.bind("SUPER + ESCAPE", "System menu", "wh01s17-menu toggle system")
o.bind("XF86PowerOff", "Power menu", "wh01s17-menu toggle system", { locked = true })
o.bind("SUPER + K", "Keybindings", "wh01s17-menu-keybindings")
o.bind("SUPER + ALT + K", "Tmux keybindings", "wh01s17-menu-tmux-keybindings")
o.bind("SUPER + CTRL + K", "Herdr keybindings", "wh01s17-menu-herdr-keybindings")

o.bind_toggle("SUPER + SHIFT + SPACE", "Toggle top bar", "bar")
o.bind("SUPER + CTRL + SPACE", "Background switcher", "wh01s17-menu toggle background")
o.bind("SUPER + SHIFT + CTRL + SPACE", "Theme menu", "wh01s17-menu toggle theme")
o.bind("SUPER + BACKSPACE", "Toggle window transparency", "wh01s17-hyprland-window-transparency-toggle")
o.bind("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", "wh01s17-hyprland-window-gaps-toggle")
o.bind("SUPER + CTRL + BACKSPACE", "Toggle single-window square aspect", "wh01s17-hyprland-window-single-square-aspect-toggle")

-- xkbcommon names the comma keysym "comma"; the upper-case "COMMA" does not match.
o.bind("SUPER + comma", "Dismiss last notification", "wh01s17-shell notifications dismissOne")
o.bind("SUPER + SHIFT + comma", "Dismiss all notifications", "wh01s17-shell notifications dismissAll")
o.bind_toggle("SUPER + CTRL + comma", "Toggle silencing notifications", "notification-silencing")
o.bind("SUPER + ALT + comma", "Invoke last notification", "wh01s17-shell notifications invokeLast")
o.bind("SUPER + SHIFT + ALT + comma", "Open notification history", "wh01s17-shell notifications showHistory")

o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")
o.bind("SUPER + CTRL + Delete", "Toggle laptop display", "wh01s17-hyprland-monitor-internal toggle")
o.bind("SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", "wh01s17-hyprland-monitor-internal-mirror toggle")
o.bind("switch:on:Lid Switch", nil, "wh01s17-system-lid-close", { locked = true })
o.bind("switch:off:Lid Switch", nil, "wh01s17-system-lid-open", { locked = true })

o.bind("PRINT", "Screenshot", "wh01s17-capture-screenshot")
o.bind("ALT + PRINT", "Screenrecording", "wh01s17-capture-screenrecording --stop-recording || wh01s17-menu toggle trigger.capture.screenrecord")
o.bind("SUPER + ALT + code:34", "Make webcam overlay smaller", "wh01s17-capture-webcam-resize smaller")
o.bind("SUPER + ALT + code:35", "Make webcam overlay larger", "wh01s17-capture-webcam-resize larger")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", "wh01s17-capture-text")

-- Keyboard control for the slurp region picker (see wh01s17-capture-region).
-- The binds live exactly as long as a selection layer is on screen (slurp
-- opens one per monitor), so they cannot leak or get stuck.
-- Unbinding by key would take a same-key binding out of the user's own config
-- with it, so each handle is kept and removed individually.
local selection_layers = 0
local selection_binds = {}

hl.on("layer.opened", function(layer)
  if layer.namespace == "selection" then
    selection_layers = selection_layers + 1
    if selection_layers == 1 then
      selection_binds = {
        hl.bind("RETURN", hl.dsp.exec_cmd("wh01s17-capture-region --take-window"), { description = "Capture highlighted window" }),
        hl.bind("CTRL + RETURN", hl.dsp.exec_cmd("wh01s17-capture-region --take-fullscreen"), { description = "Capture entire screen" }),
        hl.bind("TAB", hl.dsp.exec_cmd("wh01s17-capture-region --select-window next"), { description = "Select next window to capture" }),
        hl.bind("CTRL + TAB", hl.dsp.exec_cmd("wh01s17-capture-region --select-window prev"), { description = "Select previous window to capture" }),
      }
      for _, direction in ipairs({ "left", "right", "up", "down" }) do
        table.insert(
          selection_binds,
          hl.bind(direction:upper(), hl.dsp.exec_cmd("wh01s17-capture-region --select-window " .. direction), { description = "Select window to capture" })
        )
      end
    end
  end
end)

hl.on("layer.closed", function(layer)
  if layer.namespace == "selection" and selection_layers > 0 then
    selection_layers = selection_layers - 1
    if selection_layers == 0 then
      for _, keybind in ipairs(selection_binds) do
        keybind:unbind()
      end
      selection_binds = {}
    end
  end
end)

o.bind("SUPER + CTRL + S", "Share", "wh01s17-menu toggle share")

o.bind("SUPER + CTRL + PERIOD", "Transcode", "wh01s17-transcode")

o.bind("SUPER + CTRL + R", "Set reminder", "wh01s17-menu toggle reminder-set")
o.bind("SUPER + CTRL + ALT + R", "Show reminders", "wh01s17-reminder show")
o.bind("SUPER + SHIFT + CTRL + R", "Clear reminders", "wh01s17-reminder clear")

o.bind("SUPER + CTRL + ALT + T", "Show time", "wh01s17-notification-time")
o.bind("SUPER + CTRL + ALT + B", "Show battery remaining", "wh01s17-notification-battery")
o.bind("SUPER + CTRL + ALT + W", "Toggle weather", "wh01s17-notification-weather")

o.bind("SUPER + SHIFT + CTRL + A", "Agent", "wh01s17-agent --pick")
o.bind("SUPER + CTRL + A", "Audio", "wh01s17-shell shell toggle core.audio")
o.bind("SUPER + CTRL + B", "Bluetooth", "wh01s17-shell shell toggle core.bluetooth")
o.bind("SUPER + CTRL + D", "Display", "wh01s17-shell shell toggle core.monitor")
o.bind("SUPER + CTRL + ALT + D", "Calendar", "wh01s17-shell shell toggle core.clock")
o.bind("SUPER + CTRL + W", "Network", "wh01s17-shell shell toggle core.network")
o.bind("SUPER + CTRL + P", "Power", "wh01s17-shell shell toggle core.power")
o.bind("SUPER + CTRL + T", "Activity", { tui = "btop" })

-- The letters above name a panel; the numbers count them. 1 is the leftmost
-- panel in the bar's right section, and a widget with no panel of its own (the
-- tray) is not counted, so the number matches the icon a user would point at.
-- A bar with fewer panels than this leaves the tail of the range doing nothing.
for panel = 1, 9 do
  o.bind(
    "SUPER + CTRL + code:" .. tostring(panel + 9),
    "Bar panel " .. panel,
    "wh01s17-shell -q shell togglePanelAt right " .. panel
  )
end

o.bind("SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)

o.bind("SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)

o.bind("SUPER + CTRL + L", "Lock system", "wh01s17-system-lock")
