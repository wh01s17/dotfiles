-- Essential application bindings.
o.bind("SUPER + RETURN", "Terminal", { wh01s17 = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { wh01s17 = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { wh01s17 = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { wh01s17 = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { wh01s17 = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { wh01s17 = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { wh01s17 = "editor" })

if o.preinstalled_bindings_enabled() then
  -- Bindings for preinstalled wh01s17 applications, TUIs, and web apps.
  o.bind("SUPER + ALT + RETURN", "Tmux", { wh01s17 = "terminal-tmux" })
  o.bind("SUPER + CTRL + RETURN", "Herdr", { wh01s17 = "terminal-herdr" })
  o.bind("SUPER + SHIFT + M", "Music", { wh01s17 = "spotify" })
  o.bind("SUPER + SHIFT + ALT + M", "Music TUI", { tui = "cliamp", focus = true })
  o.bind("SUPER + SHIFT + D", "Docker", { tui = "wh01s17-launch-docker-tui" })
  o.bind("SUPER + SHIFT + O", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })

  o.bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
  o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
end
