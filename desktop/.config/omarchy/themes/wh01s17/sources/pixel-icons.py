#!/usr/bin/env python3
"""Build wh01s17 Pixel Icons: Pixelarticons drawn at Nerd Font code points.

The shell, its menu and user menu extensions name their icons by Nerd Font
code point. This font puts a Pixelarticons glyph at each code point listed in
ICONS, so fontconfig (apps/.config/fontconfig/conf.d) can slot it in front of
the Nerd Font fallback and every mapped icon turns 8-bit without touching the
QML or the menu JSONC. Code points left out keep their Nerd Font glyph.

Glyphs are moved down three icon pixels so the 24-pixel icons sit centred on
Departure Mono's capitals instead of on its ascender. CUSTOM draws the few
icons Pixelarticons lacks, on its 12x12 grid of two-unit pixels.

Requires fontTools (pacman -S python-fonttools).
Usage: python3 sources/pixel-icons.py
  (writes apps/.local/share/fonts/wh01s17/wh01s17-pixel-icons.ttf)
"""

from pathlib import Path

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

FAMILY = "wh01s17 Pixel Icons"
DROP = 125  # three of the 24 icon pixels in a 1000-unit em

# Nerd Font code point -> Pixelarticons icon, grouped as the shell uses them.
ICONS = {
    # Menu: root and system
    0xF003B: "grid-3x3",  # md-apps: Apps
    0xF09D1: "book-open",  # md-brain: Learn
    0xF14DE: "zap",  # md-rocket_launch: Trigger
    0xEBCF: "wand",  # cod-wand: Style
    0xE615: "settings-cog",  # seti-config: Setup, Config
    0xF0249: "save",  # md-floppy: Install
    0xF0B4C: "trash",  # md-tab_remove: Remove
    0xF021: "refresh",  # fa-refresh: Update
    0xEA74: "info-box",  # cod-info: About
    0xF011: "power",  # fa-power_off: System
    0xF023: "lock",  # fa-lock: Lock
    0xF0343: "logout",  # md-logout: Logout
    0xF0425: "power-off",  # md-power: Shutdown
    0xF0709: "reload",  # md-restart: Reboot
    0xF0453: "reload",  # md-reload: Reset Computer
    0xF04B2: "moon",  # md-sleep: Suspend
    0xF0901: "snowflake",  # md-power_cycle: Hibernate
    0xF1104: "tv",  # md-monitor_shimmer: Screensaver
    # Menu: style and setup
    0xF0E0C: "colors-swatch",  # md-palette_outline: Theme
    0xF00C9: "pipette",  # md-border_color: Color
    0xF03E: "image",  # fa-picture_o: Background
    0xE659: "heading",  # seti-font: Font
    0xF00B5: "invert",  # md-blur: Transparency
    0xE62A: "layout",  # custom-windows: Window Gaps
    0xF10AC: "dock",  # md-dock_window: Workspace Layout
    0xF2D0: "window-frame",  # fa-window_maximize: 1-Window Ratio
    0xF047: "move",  # fa-arrows_up_down_left_right: Position
    0xF18F4: "expand",  # md-fit_to_screen: Plymouth
    0xF359: "layout-glyph",  # linux-hyprland: Hyprland
    0xF050E: "moon",  # md-theme_light_dark: Nightlight
    0xF035C: "menu",  # md-menu: Menu Bar, Shell
    0xF0431: "shapes",  # md-puzzle: Plugins
    0xF005: "star",  # fa-star: Defaults
    0xF040: "pencil",  # fa-pencil: Custom
    0xF044: "pen-square",  # fa-pencil_square_o: Edit Text
    0xF46A: "undo",  # oct-sync: Restore Default
    0xEFBA: "mouse",  # fa-computer_mouse: Input
    0xF07F8: "tablet",  # md-trackpad: Touchpad
    0xF01BD: "pointer",  # md-cursor_pointer: Touchscreen
    0xF11C: "keyboard",  # fa-keyboard_o: Keybindings
    0xF030C: "keyboard",  # md-keyboard: Touchpad Haptics
    0xF0785: "sticker",  # md-sticker_emoji: XCompose
    0xF0379: "monitor",  # md-monitor: Monitors
    0xF037A: "monitor",  # md-monitor_multiple
    0xF06E7: "laptop",  # md-laptop_off: Laptop Display
    0xF0079: "battery",  # md-battery: Battery Percentage
    0xEB01: "globe",  # cod-globe: Timezone
    0xE383: "clock",  # weather-time: Time
    0xEB11: "key",  # cod-key: Security
    0xF07F5: "unlock",  # md-form_textbox_password: Unlock, Passwordless Sudo
    0xEF70: "tools",  # fa-screwdriver_wrench: Hardware
    0xF01C5: "pc-case",  # md-desktop_tower: Hardware
    0xEC19: "gpu",  # cod-chip: Hybrid GPU
    0xEA78: "download",  # cod-desktop_download: Firmware
    0xF03A: "bulletlist",  # fa-list: Direct Boot
    0xF02CA: "database",  # md-harddisk: Disk Speed Test
    0xF04C5: "speed-fast",  # md-speedometer: Speed Test
    0xF052B: "signal",  # md-traffic_light: Channel
    0xF0D6E: "code",  # md-dev_to: Development
    0xF06F3: "modem",  # md-network: Network
    0xF16BE: "wifi",  # md-wifi_cog: Wi-Fi
    0xF01D6: "server",  # md-dns: DNS
    0xF0A5F: "hash",  # md-ip: DHCP
    0xF08C0: "server",  # md-ssh: SSHD
    0xF0868: "docker",  # md-docker: Sudoless Docker
    0xF08C7: "linux",  # md-arch: Arch, AUR, Package
    0xF03D3: "package",  # md-package: Preinstalls
    0xF03D6: "box",  # md-package_variant: ONCE
    0xF487: "package",  # oct-package: Service, Tailscale
    0xE638: "volume-3",  # seti-audio: Audio
    0xEC12: "mic",  # cod-mic: Dictation
    0xF0045: "arrow-down",  # md-arrow_down: Bottom
    0xF004D: "arrow-left",  # md-arrow_left: Left
    0xF0054: "arrow-right",  # md-arrow_right: Right
    0xF005D: "arrow-up",  # md-arrow_up: Top
    # Menu: trigger and capture
    0xF030: "camera",  # fa-camera: Capture, Screenshot
    0xF03D: "video",  # fa-video_camera: Screenrecord
    0xF07F: "clipboard",  # fa-clipboard_alt: Clipboard
    0xF118: "smile",  # fa-smile_o: Emoji
    0xF50E: "share",  # oct-share: Share
    0xF0966: "download",  # md-file_download_outline: Receive
    0xEA7B: "file",  # cod-file: File
    0xF114: "folder",  # fa-folder_o: Folder
    0xF0D11: "text-cursor",  # md-format_textbox: Text
    0xF0432: "qr-code",  # md-qrcode: QR Code
    0xF09F8: "images",  # md-image_move: Transcode
    0xF088C: "alarm-clock",  # md-reminder: Reminder
    0xF0176: "coffee",  # md-coffee: Stay Awake
    0xF009B: "bell-off",  # md-bell_off: Notifications
    0xEBA2: "server",  # cod-server_process: Process
    0xF16A1: "robot-face-sad",  # md-robot_dead: Crash Capture
    # Menu: apps and tools
    0xF489: "terminal",  # oct-terminal: Terminal, TUI, Tmux
    0xE795: "terminal",  # dev-terminal: Alacritty, Foot, Ghostty, Kitty
    0xF1183: "terminal",  # md-bash: Bash
    0xF15C: "file-text",  # fa-file_text: Editor
    0xE8DA: "code",  # dev-vscode
    0xE62B: "code",  # custom-vim
    0xE6AE: "code",  # custom-neovim
    0xF06E4: "infinity",  # md-infinity: Muse Code
    0xF0DB: "layout",  # fa-table_columns: Herdr
    0xF488: "globe",  # oct-browser: Browser
    0xF059F: "globe",  # md-web: Brave, Zen, Add Plugin
    0xF268: "google-chrome",  # fa-chrome: Chromium, Web App
    0xF02AF: "google-chrome",  # md-google_chrome: Chrome
    0xF269: "earth",  # fa-firefox: Firefox, Zen
    0xF01E9: "earth",  # md-microsoft_edge: Edge
    0xE7F0: "google",  # dev-google: Chromium Account
    0xF02AD: "google",  # md-google: Google
    0xF0372: "app-windows",  # md-microsoft: Windows
    0xF015F: "cloud",  # md-cloud: Cloudflare
    0xF11F1: "shield",  # md-cloud_lock: NordVPN
    0xF0881: "key",  # md-onepassword: 1Password
    0xF0B79: "message",  # md-chat: Signal
    0xF04C7: "music",  # md-spotify: Spotify
    0xF02D1: "heart",  # md-heart: Crush
    0xF21F: "docker",  # fa-docker: Docker DB
    0xE707: "box",  # dev-dropbox: Dropbox
    0xF06A9: "robot",  # md-robot: Agent
    0xF16A4: "robot-face",  # md-robot_excited_outline: AI
    0xF16A3: "robot-face-happy",  # md-robot_excited
    0xF4B8: "robot-face",  # oct-copilot: Copilot
    0xF06C4: "sparkle",  # md-asterisk: Claude
    0xF0AE2: "sparkles",  # md-star_four_points: Gemini
    # Menu: gaming
    0xF11B: "gamepad",  # fa-gamepad: Gaming
    0xF1B6: "gamepad",  # fa-steam: Steam
    0xEF94: "gamepad",  # fa-battle_net: Lutris
    0xF835: "gamepad",  # Battle.net
    0xED3E: "gamepad",  # fa-xbox: Xbox Cloud Gaming
    0xF05BA: "gamepad",  # md-microsoft_xbox_controller
    0xF14DF: "gamepad",  # md-rocket_launch_outline: Heroic
    0xF08B9: "tv",  # md-remote_desktop: GeForce NOW
    0xF0BC9: "alien",  # md-space_invaders: RetroArch
    0xF0373: "blocks",  # md-minecraft: Minecraft
    # Menu: languages
    0xE627: "braces",  # seti-go
    0xE62D: "braces",  # seti-elixir
    0xE737: "braces",  # dev-scala
    0xE738: "braces",  # dev-java
    0xE73C: "braces",  # dev-python
    0xE73D: "braces",  # dev-php
    0xE73F: "braces",  # dev-laravel
    0xE757: "braces",  # dev-symfony_badge
    0xE768: "braces",  # dev-clojure
    0xE76F: "braces",  # dev-bun
    0xE77F: "braces",  # dev-dotnet
    0xE781: "braces",  # dev-javascript_badge
    0xE7A8: "braces",  # dev-rust
    0xE7C0: "deno",  # dev-denojs
    0xE84E: "braces",  # dev-ocaml
    0xE860: "braces",  # dev-phoenix
    0xE8EF: "braces",  # dev-zig
    0xED0D: "npm",  # fa-node_js
    0xF0ACF: "braces",  # md-language_ruby_on_rails
    # Bar, panels and indicators
    0xF009A: "bell",  # md-bell
    0xF00ED: "calendar",  # md-calendar
    0xF0996: "clock",  # md-progress_clock
    0xF051F: "hourglass",  # md-timer_sand
    0xF00C: "check",  # fa-check
    0xF012C: "check",  # md-check
    0xF0156: "close",  # md-close
    0xF0159: "close",  # md-close_circle
    0xF053: "chevron-left",  # fa-chevron_left
    0xF0140: "chevron-down",  # md-chevron_down
    0xF0141: "chevron-left",  # md-chevron_left
    0xF0142: "chevron-right",  # md-chevron_right
    0xF06E: "eye",  # fa-eye
    0xF0209: "eye-off",  # md-eye_off
    0xF08D: "bookmark",  # fa-thumbtack
    0xF014C: "clipboard",  # md-clipboard_outline
    0xF018F: "copy",  # md-content_copy
    0xF0450: "refresh",  # md-refresh
    0xF041: "map-pin",  # fa-map_marker
    0xF033E: "lock",  # md-lock
    0xF030B: "key",  # md-key_variant
    0xF0483: "shield",  # md-security
    0xF0582: "shield",  # md-vpn
    0xF048A: "send",  # md-send
    0xF11E2: "modem",  # md-router
    0xF02CB: "headphone",  # md-headphones
    0xF036C: "mic",  # md-microphone
    0xF036D: "mic-off",  # md-microphone_off
    0xF026: "volume",  # fa-volume_off
    0xF027: "volume-1",  # fa-volume_low
    0xF028: "volume-3",  # fa-volume_up
    0xF057E: "volume-3",  # md-volume_high
    0xF075F: "volume-x",  # md-volume_mute
    0xEEE8: "volume-x",  # fa-volume_xmark
    0xF075A: "music",  # md-music
    0xF040A: "play",  # md-play
    0xF03E4: "pause",  # md-pause
    0xF04AD: "chevron-right-2",  # md-skip_next
    0xF04AE: "chevron-left-2",  # md-skip_previous
    0xF0EC2: "circle",  # md-record_circle: screen recording
    0xF00AF: "bluetooth",  # md-bluetooth (CUSTOM)
    0xF00B1: "bluetooth",  # md-bluetooth_connect
    0xF00B2: "bluetooth",  # md-bluetooth_off
    0xF04C3: "volume-2",  # md-speaker: audio outputs
    0xF0100: "camera",  # md-camera: audio inputs
    0xF0741: "pointer",  # md-gesture_tap: OSD
    # Network
    0xF091F: "wifi",  # md-wifi_strength_1
    0xF0922: "wifi",  # md-wifi_strength_2
    0xF0925: "wifi",  # md-wifi_strength_3
    0xF0928: "wifi",  # md-wifi_strength_4
    0xF092F: "wifi",  # md-wifi_strength_outline
    0xF092E: "close",  # md-wifi_strength_off_outline
    0xF0200: "plug",  # md-ethernet
    0xF0415: "plus",  # md-plus
    # Power
    0xF032A: "leaf",  # md-leaf: power saver
    0xF029A: "speed-medium",  # md-gauge: balanced
    0xF140B: "zap",  # md-lightning_bolt
    0xF0084: "zap",  # md-battery_charging
    0xF089C: "battery-low",  # md-battery_charging_10
    0xF0086: "battery-low",  # md-battery_charging_20
    0xF0087: "battery-low",  # md-battery_charging_30
    0xF0088: "battery-medium",  # md-battery_charging_40
    0xF089D: "battery-medium",  # md-battery_charging_50
    0xF0089: "battery-medium",  # md-battery_charging_60
    0xF089E: "battery-medium",  # md-battery_charging_70
    0xF008A: "battery-full",  # md-battery_charging_80
    0xF008B: "battery-full",  # md-battery_charging_90
    0xF0085: "battery-full",  # md-battery_charging_100
    0xF007A: "battery-low",  # md-battery_10
    0xF007B: "battery-low",  # md-battery_20
    0xF007C: "battery-low",  # md-battery_30
    0xF007D: "battery-medium",  # md-battery_40
    0xF007E: "battery-medium",  # md-battery_50
    0xF007F: "battery-medium",  # md-battery_60
    0xF0080: "battery-medium",  # md-battery_70
    0xF0081: "battery-full",  # md-battery_80
    0xF0082: "battery-full",  # md-battery_90
    # Weather
    0xE30D: "sun",  # weather-day_sunny
    0xE32B: "moon",  # weather-night_clear
    0xE302: "cloud-sun",  # weather-day_cloudy
    0xE32E: "cloud-moon",  # weather-night_cloudy
    0xE33D: "cloud",  # weather-cloud
    0xE313: "wind",  # weather-fog
    0xE346: "wind",  # weather-night_fog
    0xE308: "cloud",  # weather-day_rain
    0xE333: "cloud",  # weather-night_rain
    0xE318: "cloud",  # weather-rain
    0xE30A: "snowflake",  # weather-day_snow
    0xE327: "snowflake",  # weather-night_alt_snow
    0xE31A: "snowflake",  # weather-snow
    0xE3AD: "snowflake",  # weather-sleet
    0xE31D: "zap",  # weather-thunderstorm
    # Files and devices
    0xF0214: "file",  # md-file
    0xF0219: "file-text",  # md-file_document
    0xF022B: "video",  # md-file_video
    0xF02E9: "image",  # md-image
    0xF024B: "folder",  # md-folder
    0xF033D: "linux",  # md-linux
    0xF0035: "apple",  # md-apple
    0xF0032: "android",  # md-android
    0xF07C0: "computer",  # md-desktop_classic
    # Bar scripts and notifications
    0xF0A60: "modem",  # md-ip_network
    0xF04FE: "target",  # md-target
    0xF0132: "checkbox-on",  # md-checkbox_marked
    0xF014D: "clipboard",  # md-clipboard_text
    0xF035B: "memory-stick",  # md-memory
    0xF0361: "message",  # md-message
    0xF02FC: "info-box",  # md-information
    0xF01B4: "trash",  # md-delete
    0xF062C: "git-branch",  # md-source_branch
    0xF02FB: "inbox",  # md-inbox_arrow_down
    0xF0A53: "hand",  # md-hand_pointing_down
    0xF0904: "moon",  # md-power_sleep
    0xF0493: "settings-cog",  # md-cog
    0xF048D: "server",  # md-server_network
    0xF018D: "terminal",  # md-console
    0xF01D8: "more-horizontal",  # md-dots_horizontal
    0xF03CC: "external-link",  # md-open_in_new
    0xF0306: "key",  # md-key
    0xF062: "arrow-up",  # fa-arrow_up
    0xF063: "arrow-down",  # fa-arrow_down
    0xF07E: "arrows-horizontal",  # fa-arrows_left_right
    0xF01DA: "download",  # md-download
    0xF0239: "earth",  # md-firefox
    0xF43A: "clock",  # oct-clock
}

# Icons Pixelarticons lacks, drawn on its 12x12 grid ("#" is a pixel).
CUSTOM = {
    "bluetooth": [
        "............",
        ".....#......",
        ".....##.....",
        "..#..#.#....",
        "...#.#.#....",
        "....###.....",
        "....###.....",
        "...#.#.#....",
        "..#..#.#....",
        ".....##.....",
        ".....#......",
        "............",
    ],
}

SOURCE = Path(__file__).resolve().parent / "pixelarticons" / "pixelart-icons-font.ttf"
REPO = Path(__file__).resolve().parents[6]
OUTPUT = REPO / "apps/.local/share/fonts/wh01s17/wh01s17-pixel-icons.ttf"


def main():
    font = TTFont(SOURCE)
    glyf, hmtx = font["glyf"], font["hmtx"]
    glyphs = font.getGlyphSet()
    order = font.getGlyphOrder()
    for name, rows in CUSTOM.items():
        pen = TTGlyphPen(None)
        cell = font["head"].unitsPerEm // 12
        for y, row in enumerate(rows):
            for x, bit in enumerate(row):
                if bit == "#":
                    x0, y0 = x * cell, (11 - y) * cell
                    pen.moveTo((x0, y0))
                    pen.lineTo((x0, y0 + cell))
                    pen.lineTo((x0 + cell, y0 + cell))
                    pen.lineTo((x0 + cell, y0))
                    pen.closePath()
        glyf[name] = pen.glyph()  # also appends it to the shared glyph order
        hmtx[name] = (font["head"].unitsPerEm, 0)
    glyphs = font.getGlyphSet()
    names = set(order)
    missing = sorted({n for n in ICONS.values() if n not in names})
    if missing:
        raise SystemExit("unknown Pixelarticons icons: " + ", ".join(missing))

    # Lower every glyph used; contours are drawn through a pen so composite
    # glyphs come out flattened too.
    for name in sorted(set(ICONS.values())):
        rec = DecomposingRecordingPen(glyphs)
        glyphs[name].draw(rec)
        pen = TTGlyphPen(None)
        rec.replay(TransformPen(pen, (1, 0, 0, 1, 0, -DROP)))
        glyf[name] = pen.glyph()
        glyf[name].recalcBounds(glyf)
        advance, _ = hmtx[name]
        hmtx[name] = (advance, glyf[name].xMin)

    # Replace the character map: only the Nerd Font code points, in a
    # format 12 subtable because many of them lie beyond the BMP.
    mapping = {cp: name for cp, name in ICONS.items()}
    tables = []
    for platform, encoding, fmt in ((3, 10, 12), (0, 4, 12)):
        sub = CmapSubtable.newSubtable(fmt)
        sub.platformID, sub.platEncID, sub.language = platform, encoding, 0
        sub.cmap = dict(mapping)
        tables.append(sub)
    font["cmap"].tables = tables

    hhea, os2 = font["hhea"], font["OS/2"]
    hhea.descent = os2.sTypoDescender = -DROP
    os2.usWinDescent = DROP
    os2.usFirstCharIndex = min(cp for cp in mapping if cp <= 0xFFFF)
    os2.usLastCharIndex = 0xFFFF

    name = font["name"]
    for record in list(name.names):
        if record.nameID in (1, 3, 4, 6, 16, 17):
            name.removeNames(nameID=record.nameID)
    name.setName(FAMILY, 1, 3, 1, 0x409)
    name.setName("Regular", 2, 3, 1, 0x409)
    name.setName(FAMILY + " Regular", 3, 3, 1, 0x409)
    name.setName(FAMILY, 4, 3, 1, 0x409)
    name.setName(FAMILY.replace(" ", ""), 6, 3, 1, 0x409)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUTPUT)
    print(f"{OUTPUT}: {len(mapping)} code points, {len(set(ICONS.values()))} icons")


if __name__ == "__main__":
    main()
