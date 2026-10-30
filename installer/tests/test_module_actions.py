"""Run real desktop actions without hardware, using empty homes and fake daemons."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / 'platform/.local/share/wh01s17'


class ModuleActionsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.home = self.root / 'home'; self.home.mkdir()
        self.bin = self.root / 'bin'; self.bin.mkdir()
        self.log = self.root / 'calls'
        self.env = dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home / '.local/state'),
                        XDG_RUNTIME_DIR=str(self.root), WH01S17_PATH=str(RUNTIME),
                        PATH=f'{self.bin}:{RUNTIME}/bin:/usr/bin', ACTION_LOG=str(self.log))
        mock = self.bin / 'mock'
        mock.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['ACTION_LOG'], 'a') as log:
    log.write(json.dumps([name, *args]) + '\\n')
if name == os.environ.get('FAIL_TOOL') and (not os.environ.get('FAIL_ACTION') or args and (args[0].startswith(os.environ['FAIL_ACTION']) or os.environ['FAIL_ACTION'] == '@apply' and args[0] in ('eval', 'keyword'))):
    sys.exit(7)
if name == 'hyprctl':
    if args[0] == 'activeworkspace': print(' {"id":1,"tiledLayout":"dwindle"}')
    elif args[0] == 'hyprsunset': print(os.environ.get('TEMPERATURE', '6500'))
    elif args[0] == 'monitors': print('[{"name":"eDP-1","disabled":false,"scale":1,"focused":true,"width":1920,"height":1080,"refreshRate":60},{"name":"DP-1","disabled":false}]')
    else: print('ok')
elif name in ('wh01s17-hw-touchpad', 'wh01s17-hw-touchscreen'): print('test-device')
elif name == 'wh01s17-powerprofiles-list': print('balanced\\nperformance\\npower-saver')
elif name == 'wh01s17-audio-output-sink': print('alsa_output.test')
elif name == 'pactl':
    if args[:1] == ['get-sink-volume']: print('Volume: front-left: 32768 / 50% / -18.0 dB')
    elif args[:1] == ['get-sink-mute']: print('Mute: no')
elif name == 'bluetoothctl': print('Powered: yes')
''')
        mock.chmod(0o755)
        for name in ('hyprctl', 'wh01s17-hw-touchpad', 'wh01s17-hw-touchscreen',
                     'wh01s17-powerprofiles-list', 'powerprofilesctl', 'pactl', 'wpctl',
                     'wh01s17-audio-output-sink', 'wh01s17-notification-send', 'wh01s17-osd',
                     'wh01s17-shell', 'systemctl', 'bluetoothctl', 'rfkill',
                     'wh01s17-hw-clamshell', 'wh01s17-hw-laptop', 'pgrep', 'sleep',
                     'pkill', 'gsettings', 'wh01s17-cmd-present'):
            (self.bin / name).symlink_to(mock)

    def run_action(self, name, *args):
        return subprocess.run(['bash', str(RUNTIME / 'bin' / name), *args],
                              env=self.env, capture_output=True, text=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def assert_no_success_feedback(self):
        self.assertFalse(any(call[0] in ('wh01s17-notification-send', 'wh01s17-osd') for call in self.calls()), self.calls())

    def test_state_actions_create_their_directories_without_prior_setup(self):
        cases = (
            ('wh01s17-toggle', ('bar-off', 'on'), '.local/state/wh01s17/toggles/bar-off'),
            ('wh01s17-toggle-idle', ('stay-awake',), '.local/state/wh01s17/indicators/stay-awake'),
            ('wh01s17-toggle-touchpad', ('off',), '.local/state/wh01s17/toggles/hypr/touchpad-disabled-name'),
            ('wh01s17-toggle-touchscreen', ('off',), '.local/state/wh01s17/toggles/hypr/touchscreen-disabled-name'),
            ('wh01s17-hyprland-workspace-layout-toggle', (), '.local/state/wh01s17/workspace-layouts/1.lua'),
            ('wh01s17-default-editor', ('nvim',), '.local/state/wh01s17/defaults/editor'),
            ('wh01s17-default-terminal', ('kitty',), '.config/xdg-terminals.list'),
            ('wh01s17-display-text-size', ('16',), '.config/wh01s17/shell.toml'),
            ('wh01s17-weather-location', ('--set', 'Santiago', '-33.4,-70.6'), '.local/state/wh01s17/settings/weather.json'),
            ('wh01s17-powerprofiles-set', ('ac', 'balanced'), '.local/state/wh01s17/powerprofiles/ac'),
            ('wh01s17-hyprland-monitor-clamshell', (), '.local/state/wh01s17/toggles/hypr/internal-monitor-clamshell.lua'),
        )
        for index, (name, args, relative) in enumerate(cases):
            with self.subTest(action=name):
                home = self.root / f'fresh-{index}'; home.mkdir()
                self.env.update(HOME=str(home), XDG_STATE_HOME=str(home / '.local/state'))
                result = self.run_action(name, *args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((home / relative).exists(), result.stderr)

    def test_blocked_state_storage_returns_failure_without_success_feedback(self):
        (self.home / '.local').write_text('user file')
        for name, args in (
            ('wh01s17-toggle-bar', ('on',)),
            ('wh01s17-toggle-screensaver', ()),
            ('wh01s17-toggle-suspend', ()),
            ('wh01s17-toggle-crash-capture', ()),
            ('wh01s17-toggle-idle', ('stay-awake',)),
            ('wh01s17-toggle-touchpad', ('off',)),
            ('wh01s17-toggle-touchscreen', ('off',)),
            ('wh01s17-hyprland-workspace-layout-toggle', ()),
            ('wh01s17-default-editor', ('nvim',)),
            ('wh01s17-hyprland-monitor-scaling', ('1.25',)),
            ('wh01s17-weather-location', ('--set', 'Santiago')),
            ('wh01s17-powerprofiles-set', ('battery', 'balanced')),
            ('wh01s17-hyprland-monitor-clamshell', ()),
        ):
            with self.subTest(action=name):
                self.log.write_text('')
                result = self.run_action(name, *args)
                self.assertNotEqual(result.returncode, 0, (name, result.stdout, result.stderr))
                self.assert_no_success_feedback()
                self.assertEqual((self.home / '.local').read_text(), 'user file')

    def test_failed_hyprland_toggle_does_not_reload_or_print_success(self):
        # Both the normal "on" and the convenience "toggle" branch must propagate cp failure.
        source = self.root / 'runtime/default/hypr/toggles'
        source.mkdir(parents=True)
        (source / 'test.lua').write_text('hl.config({})')
        self.env['WH01S17_PATH'] = str(self.root / 'runtime')
        (self.home / '.local').write_text('blocked')
        for action in ('on', 'toggle'):
            with self.subTest(action=action):
                result = self.run_action('wh01s17-hyprland-toggle', 'test', action)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertFalse(any(call[:2] == ['hyprctl', 'reload'] for call in self.calls()))

    def test_backend_errors_do_not_report_success(self):
        for name, args, tool, action in (
            ('wh01s17-audio-input-mute', (), 'wpctl', 'set-mute'),
            ('wh01s17-audio-output-volume', ('+5',), 'pactl', 'set-'),
            ('wh01s17-audio-output-volume', ('mute-toggle',), 'pactl', 'set-'),
            ('wh01s17-audio-output-set-default', ('42', 'test'), 'pactl', 'set-'),
            ('wh01s17-audio-input-set-default', ('42', 'test'), 'pactl', 'set-'),
            ('wh01s17-toggle-touchpad', ('off',), 'hyprctl', 'eval'),
            ('wh01s17-hyprland-workspace-layout-toggle', (), 'hyprctl', '@apply'),
            ('wh01s17-toggle-crash-capture', (), 'systemctl', ''),
            ('wh01s17-powerprofiles-set', ('ac', 'balanced'), 'powerprofilesctl', ''),
            ('wh01s17-bluetooth-device', ('connect', '00:11:22:33:44:55'), 'bluetoothctl', 'connect'),
            ('wh01s17-bluetooth-device', ('pair', '00:11:22:33:44:55'), 'bluetoothctl', 'connect'),
            ('wh01s17-bluetooth-device', ('disconnect', '00:11:22:33:44:55'), 'bluetoothctl', 'disconnect'),
            ('wh01s17-bluetooth-device', ('forget', '00:11:22:33:44:55'), 'bluetoothctl', 'remove'),
            ('wh01s17-bluetooth-power', ('on',), 'rfkill', 'unblock'),
            ('wh01s17-toggle-notification-silencing', (), 'wh01s17-shell', ''),
        ):
            with self.subTest(action=name, args=args):
                self.log.write_text('')
                self.env.update(FAIL_TOOL=tool, FAIL_ACTION=action)
                result = self.run_action(name, *args)
                self.assertNotEqual(result.returncode, 0, (result.stdout, result.stderr))
                self.assert_no_success_feedback()

    def test_nightlight_must_reach_the_requested_temperature(self):
        self.env['TEMPERATURE'] = '6500'
        result = self.run_action('wh01s17-toggle-nightlight')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[0] == 'wh01s17-shell' for call in self.calls()))

    def test_blocked_terminal_configuration_is_not_reported_as_saved(self):
        (self.home / '.config').write_text('user config')
        result = self.run_action('wh01s17-default-terminal', 'kitty')
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_success_feedback()
        self.assertEqual((self.home / '.config').read_text(), 'user config')

    def test_clipboard_image_is_reported_only_after_it_is_saved(self):
        script = RUNTIME / 'shell/plugins/clipboard/capture.sh'
        command = ['bash', str(script), 'image/png']
        success = subprocess.run(command, input=b'image-content', env=self.env, capture_output=True)
        self.assertEqual(success.returncode, 0, success.stderr)
        entry = json.loads(success.stdout)
        self.assertEqual(Path(entry['path']).read_bytes(), b'image-content')
        # A different payload avoids the existing-image fast path.
        mover = self.bin / 'mv'
        mover.write_text('#!/bin/sh\nexit 7\n'); mover.chmod(0o755)
        failure = subprocess.run(command, input=b'different-image', env=self.env, capture_output=True)
        self.assertNotEqual(failure.returncode, 0)
        self.assertEqual(failure.stdout, b'')

    def test_default_agent_does_not_launch_after_a_failed_preference_write(self):
        for name in ('mise', 'wh01s17-agent'):
            (self.bin / name).symlink_to(self.bin / 'mock')
        (self.home / '.config').write_text('blocked')
        result = self.run_action('wh01s17-default-agent', 'codex')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[0] == 'wh01s17-agent' for call in self.calls()))

    def test_directory_at_flag_path_is_not_reported_as_enabled(self):
        for name, args, relative in (
            ('wh01s17-toggle', ('bar-off', 'on'), '.local/state/wh01s17/toggles/bar-off'),
            ('wh01s17-toggle-idle', ('stay-awake',), '.local/state/wh01s17/indicators/stay-awake'),
        ):
            with self.subTest(action=name):
                target = self.home / relative
                target.mkdir(parents=True)
                result = self.run_action(name, *args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertTrue(target.is_dir())

    def test_text_size_stops_when_shell_settings_cannot_be_written(self):
        (self.home / '.config').write_text('user config')
        result = self.run_action('wh01s17-display-text-size', '16')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[0] in ('gsettings', 'pkill') for call in self.calls()))
        self.assertEqual((self.home / '.config').read_text(), 'user config')


if __name__ == '__main__':
    unittest.main()
