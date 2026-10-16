# Chromium ships in the base packages, so it never goes through
# wh01s17-install-browser, and fresh installs mark every migration as already
# applied. Without this, the bundled extensions load but have no native
# messaging host to talk to.
wh01s17-install-chromium-copy-url
wh01s17-install-chromium-ytdlp
