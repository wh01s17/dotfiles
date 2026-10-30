# Source this file from ~/.zshrc:
# source "$HOME/.config/wh01s17/bar/scripts/git-branch-hook.zsh"
#
# Tracks the last directory this shell cd'd into so the bar's git-branch
# module knows which repo to report on.

_wh01s17_bar_track_cwd() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/wh01s17/bar/git-branch"
  mkdir -p "$state_dir"
  print -r -- "$PWD" > "$state_dir/cwd"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _wh01s17_bar_track_cwd
_wh01s17_bar_track_cwd
