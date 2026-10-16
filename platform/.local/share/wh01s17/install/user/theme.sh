# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/wh01s17/themes

if [[ ! -s $HOME/.local/state/wh01s17/current/theme.name ]]; then
  # iso-chroot and provision-owner both run without a live session to notify.
  if [[ ${WH01S17_SETUP_CONTEXT:-runtime} != "runtime" ]]; then
    WH01S17_THEME_HEADLESS=1 wh01s17-theme-set "${WH01S17_DEFAULT_THEME:-wh01s17}"
    rm -f ~/.config/chromium/SingletonLock # otherwise archiso owns the Chromium singleton
  else
    wh01s17-theme-set "${WH01S17_DEFAULT_THEME:-wh01s17}"
  fi
fi
wh01s17-theme-set-pi --activate

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/wh01s17/current/theme/btop.theme" ~/.config/btop/themes/current.theme
