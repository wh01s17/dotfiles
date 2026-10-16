# Upgrades must not delete the version a running process is executing from:
# mise up would prune the old install dir out from under a live session.
mise settings set upgrade.auto_prune false

# wh01s17: install the tools listed in ~/.config/mise/config.toml (Stow
# package `apps`) instead of wh01s17's full AI tool list.
if [[ -f $HOME/.config/mise/config.toml ]]; then
  # A Stow link resolves into ~/dotfiles, which mise treats as untrusted.
  mise trust "$HOME/.config/mise/config.toml"
  mise install --yes || echo 'Warning: mise install failed; run it again later' >&2
fi
