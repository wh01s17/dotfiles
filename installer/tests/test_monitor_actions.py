"""Exercise real monitor actions with a disposable HOME and fake compositor."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / 'platform/.local/share/wh01s17'


class MonitorActionsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / 'home'; self.home.mkdir()
        self.bin = self.root / 'bin'; self.bin.mkdir()
        self.log = self.root / 'commands'
        self.environment = dict(os.environ, HOME=str(self.home), WH01S17_PATH=str(RUNTIME),
                                PATH=f'{self.bin}:{RUNTIME}/bin:/usr/bin', MONITOR_LOG=str(self.log),
                                MONITOR_JSON=json.dumps([
                                    {'name': 'eDP-1', 'disabled': False},
                                    {'name': 'DP-1', 'disabled': False}]))
        self.mock('hyprctl', '''printf '%s\\n' "$*" >>"$MONITOR_LOG"
if [ "$1" = monitors ]; then printf '%s\\n' "$MONITOR_JSON"; fi''')
        self.mock('wh01s17-notification-send', 'printf "notify %s\\n" "$*" >>"$MONITOR_LOG"')

    def mock(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)

    def action(self, name, argument):
        return subprocess.run(['bash', str(RUNTIME / 'bin' / name), argument],
                              env=self.environment, capture_output=True, text=True)

    def test_external_creates_toggle_in_fresh_home_and_can_be_reenabled(self):
        flag = self.home / '.local/state/wh01s17/toggles/hypr/internal-monitor-disable.lua'
        result = self.action('wh01s17-hyprland-monitor-internal', 'off')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertEqual(flag.read_text(), 'hl.monitor({ output = "eDP-1", disabled = true })\n')
        self.assertIn('reload', self.log.read_text())
        result = self.action('wh01s17-hyprland-monitor-internal', 'on')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(flag.exists())

    def test_external_refuses_to_disable_the_only_active_display(self):
        self.environment['MONITOR_JSON'] = json.dumps([{'name': 'eDP-1', 'disabled': False}])
        result = self.action('wh01s17-hyprland-monitor-internal', 'off')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('reload', self.log.read_text())

    def test_write_failure_returns_error_without_success_notification_or_reload(self):
        blocker = self.home / '.local/state/wh01s17/toggles'
        blocker.parent.mkdir(parents=True)
        blocker.write_text('local file')
        result = self.action('wh01s17-hyprland-monitor-internal', 'off')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('reload', self.log.read_text())
        self.assertNotIn('Laptop display disabled', self.log.read_text())
        self.assertEqual(blocker.read_text(), 'local file')

    def test_mirror_creates_its_toggle_in_a_fresh_home(self):
        result = self.action('wh01s17-hyprland-monitor-internal-mirror', 'on')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        flag = self.home / '.local/state/wh01s17/toggles/hypr/internal-monitor-mirror.lua'
        self.assertIn('mirror = "eDP-1"', flag.read_text())
        self.assertIn('output = "DP-1"', flag.read_text())


if __name__ == '__main__':
    unittest.main()
