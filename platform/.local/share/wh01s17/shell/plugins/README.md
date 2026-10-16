# First-party plugins

These plugins ship with wh01s17 and are discovered by the shell at startup.
They use the same `manifest.json` contract as third-party plugins; the
only difference is that the shell flags them with `__isFirstParty: true`.
First-party non-bar plugins are enabled unless listed in `disabledPlugins[]`;
`core.bar` is the default bar option and becomes inactive only while another
`kind: "bar"` plugin is selected. Services and keep-loaded panels are mounted
at startup; other panels, overlays, and menus are loaded on demand.

User-installed plugins live alongside these conceptually but on disk under
`~/.config/wh01s17/plugins/<plugin-id>/` rather than in this directory.

| Plugin        | id                        | kinds                   | entry point                           |
|---------------|---------------------------|-------------------------|---------------------------------------|
| Bar           | `core.bar`             | `bar`                   | `bar/Bar.qml`                         |
| Image picker  | `core.image-picker`    | `overlay`               | `image-picker/ImagePicker.qml`        |
| Emojis        | `core.emojis`          | `overlay`               | `emojis/Emojis.qml`                   |
| Clipboard mgr | `core.clipboard`       | `overlay`               | `clipboard/Clipboard.qml`             |
| Reminders     | `core.reminders`       | `overlay`               | `reminders/ReminderFlow.qml`          |
| wh01s17 menu  | `core.menu`            | `menu`, `bar-widget`    | `menu/Menu.qml`, `menu/BarWidget.qml` |
| Notifications | `core.notifications`   | `service`               | `notifications/Service.qml`           |
| Audio         | `core.audio`           | `bar-widget`            | `panels/audio/Panel.qml`              |
| Bluetooth     | `core.bluetooth`       | `bar-widget`            | `panels/bluetooth/Panel.qml`          |
| Clock         | `core.clock`           | `bar-widget`            | `panels/clock/BarWidget.qml`          |
| Monitor       | `core.monitor`         | `bar-widget`            | `panels/monitor/Panel.qml`            |
| Network       | `core.network`         | `bar-widget`            | `panels/network/Panel.qml`            |
| Power         | `core.power`           | `bar-widget`            | `panels/power/Panel.qml`              |
| Tailscale     | `core.tailscale`       | `bar-widget`            | `panels/tailscale/Panel.qml`          |
| Agents   | `core.agents`     | `bar-widget`            | `agents/Panel.qml`               |
| Weather       | `core.weather`         | `bar-widget`            | `panels/weather/BarWidget.qml`        |
| Media         | `core.media`           | `service`, `bar-widget` | `services/media/Service.qml`, `services/media/BarWidget.qml` |
| Battery       | `core.battery`         | `service`               | `services/battery/Service.qml`        |
| Idle          | `core.idle`            | `service`               | `services/idle/Service.qml`           |
| Night light   | `core.nightlight`      | `service`               | `services/nightlight/Service.qml`     |
| Lock screen   | `core.lock`            | `service`               | `lock/Service.qml`                    |
| OSD           | `core.osd`             | `panel`                 | `osd/Osd.qml`                         |
| Polkit agent  | `core.polkit`          | `service`               | `polkit/PolkitAgent.qml`              |

First-party bar-only widgets also carry manifests next to their QML files,
e.g. `bar/widgets/Workspaces.manifest.json`. Rich popup widgets live in their
own plugin directories, each with its own `manifest.json`.

## Bar

The built-in status bar and default full-bar option. Layout lives in the
top-level `bar:` subtree of `~/.config/wh01s17/shell.json` (with the shell
providing [`config/wh01s17/shell.json`](../../config/wh01s17/shell.json) when
the user has no file). See [`bar/README.md`](bar/README.md) for the widget catalogue
and customization schema.

## Image picker

Fullscreen image-grid selector overlay. Used by `wh01s17-menu-images`
(wallpaper picker) and `wh01s17-theme-switcher` (theme picker) and any
other caller that wants to present a directory of images with previews.

Two ways to drive it:

- Shell-level summon: `wh01s17-shell shell summon core.image-picker '<jsonPayload>'`.
  The payload can carry `imageDirs`, `imageRows`, `selectedImage`,
  `selectionFile`, `doneFile`, `showLabels`, `filterable`. Best for
  in-shell callers that already speak JSON.
- Direct IPC target: `wh01s17-shell image-selector open <imageDirs> <imageRowsB64> <selectedImage> <selectionFile> <doneFile> <showLabels> <filterable>`.
  Positional args; `imageRowsB64` is base64-encoded so embedded newlines /
  tabs survive the bash argv handoff. This is what `wh01s17-menu-images`
  uses. Colors come from the central shell theme singleton; there is no
  per-call override surface.

The selection round-trip remains file-based: callers create a
`selection_file` and `done_file` (both `mktemp`), pass the paths, and
poll `done_file` for existence. The plugin writes the chosen path into
`selection_file` and touches `done_file` when it's done. `cancel` IPC
clears it without writing a selection.

The plugin has `keepLoaded: true` so the layer-shell window survives
between summons within a single shell session.

## Lock screen

Session-lock surface using Quickshell's native `WlSessionLock` and two
separate PAM services: `wh01s17-lock-password` for password auth and,
only when fingerprints are enrolled, `wh01s17-lock-fingerprint` for
fingerprint auth. It mirrors the previous lock screen field dimensions,
colors, blurred wallpaper, placeholder, and Hyprland-driven corners.
The plugin sets `keepLoaded: true` so a plugin hot-reload (for example
an installed bar widget changing on disk) does not destroy the lock
client while Hyprland still holds the session lock.

## Polkit agent

Theme-aware authentication dialog for privileged actions. It uses
Quickshell's native `Quickshell.Services.Polkit.PolkitAgent` backend and
runs inside the long-lived `wh01s17-shell` process, replacing the old
`polkit-gnome-authentication-agent-1` autostart.

## wh01s17 menu

Quickshell-powered wh01s17 command menu.
The menu UI lives in `menu/Menu.qml` as a first-party `menu` plugin and is
summoned through the shell (`wh01s17-shell shell summon core.menu ...`),
so it shares the long-running `wh01s17-shell` process instead of starting a
second Quickshell instance.

The menu definition lives outside the shell host code:

- defaults: `default/wh01s17/wh01s17-menu.jsonc`
- user extensions: `~/.config/wh01s17/extensions/wh01s17-menu.jsonc`

The shell parses both JSONC files at startup (with `watchChanges: true`
so edits take effect without a restart), evaluates `when:` / `checked:`
bash expressions in a single batched subprocess, and executes the
selected `action:` string directly via `Quickshell.execDetached`. The
long-running shell process keeps the parsed menu in memory, so the
keybind → IPC → visible path costs ~30ms cold.

## Coming soon

- `wh01s17.theme-switcher` — folds theme switching into the shell.
