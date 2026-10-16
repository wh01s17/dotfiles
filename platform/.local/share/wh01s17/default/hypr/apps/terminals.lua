-- Define terminal tag so themes and bindings can single terminals out. wh01s17
-- launches TUIs and its own terminal windows under dedicated app-ids
-- (org.wh01s17.btop, org.wh01s17.terminal, TUI.float, ...), so match those too.
-- The class is matched in full, so foot's other app-id needs spelling out.
o.window(
  "(Alacritty|kitty|com.mitchellh.ghostty|foot|org\\.codeberg\\.dnkl\\.foot|wezterm|org\\.wh01s17\\..*|TUI\\..*)",
  { tag = "+terminal" }
)
