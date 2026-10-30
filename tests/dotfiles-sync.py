"""Exercise native Stow links and synchronization without touching HOME."""
import contextlib
import io
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SYNC = runpy.run_path(str(ROOT / 'maintenance/.local/bin/dotfiles-sync'))


class StowTests(unittest.TestCase):
    def test_direct_links_preserve_local_files_and_follow_source_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, home = Path(tmp) / 'repo', Path(tmp) / 'home'
            home.mkdir()
            for package, app in (('desktop', 'hypr'), ('terminal', 'kitty')):
                config = root / package / '.config' / app
                config.mkdir(parents=True)
                (config / 'config').write_text(package)
            (home / '.config/hypr').mkdir(parents=True)
            selector = home / '.config/hypr/machine-profile.lua'
            selector.write_text('return "omen"')
            external = home / '.config/hypr/custom'
            external.symlink_to('/tmp/unrelated-custom-config')
            command = ['stow', '--restow', '--dir', str(root), '--target', str(home),
                       'desktop', 'terminal']
            subprocess.run(command, check=True)
            source = root / 'desktop/.config/hypr/config'
            source.write_text('edited')
            self.assertEqual((home / '.config/hypr/config').read_text(), 'edited')
            added = root / 'desktop/.config/hypr/new-config'
            added.touch()
            subprocess.run(command, check=True)
            self.assertEqual((home / '.config/hypr/new-config').resolve(), added)
            added.unlink()
            subprocess.run(command, check=True)
            self.assertFalse((home / '.config/hypr/new-config').is_symlink())
            self.assertEqual(selector.read_text(), 'return "omen"')
            self.assertEqual(os.readlink(external), '/tmp/unrelated-custom-config')


class SyncTests(unittest.TestCase):
    def test_edits_deletes_failures_and_unchanged_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'repo'; root.mkdir()
            for package in SYNC['PACKAGES']:
                (root / package).mkdir()
            source = root / 'desktop/config'; source.write_text('one')
            calls = []
            main = SYNC['main']
            with patch.dict(os.environ, {'XDG_STATE_HOME': str(Path(tmp) / 'state')}), \
                 patch.object(sys, 'argv', ['dotfiles-sync', '--dotfiles', str(root)]), \
                 patch('time.sleep'), \
                 patch('subprocess.check_output', return_value=str(root / '.git')), \
                 patch.dict(main.__globals__, {'run': lambda *args, **kwargs: calls.append(tuple(map(str, args))),
                                               'session_inputs': lambda root: {'theme': None, 'instance': None, 'hypr': None}}), \
                 contextlib.redirect_stdout(io.StringIO()):
                main()
                self.assertEqual(len(calls), 5)
                self.assertFalse(any('.arch-build' in arg for call in calls for arg in call))
                self.assertFalse(any('arch-desktop' in arg for call in calls for arg in call))
                calls.clear(); main(); self.assertEqual(calls, [])
                source.write_text('two'); main(); self.assertEqual(len(calls), 5)
                calls.clear(); source.unlink(); main(); self.assertEqual(len(calls), 5)
                source.write_text('retry')
                with patch.dict(main.__globals__, {'run': lambda *args: (_ for _ in ()).throw(RuntimeError('conflict'))}):
                    with self.assertRaises(RuntimeError):
                        main()
                calls.clear(); main(); self.assertEqual(len(calls), 5)

    def test_active_git_operation_defers_sync(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'repo'; root.mkdir()
            for package in SYNC['PACKAGES']:
                (root / package).mkdir()
            (root / '.git').mkdir(); (root / '.git/index.lock').touch()
            calls = []
            main = SYNC['main']
            with patch.dict(os.environ, {'XDG_STATE_HOME': str(Path(tmp) / 'state')}), \
                 patch.object(sys, 'argv', ['dotfiles-sync', '--dotfiles', str(root)]), \
                 patch('time.sleep'), \
                 patch('subprocess.check_output', return_value=str(root / '.git')), \
                 patch.dict(main.__globals__, {'run': lambda *args, **kwargs: calls.append(args),
                                               'session_inputs': lambda root: {'theme': None, 'instance': None, 'hypr': None}}):
                main(); self.assertEqual(calls, [])


class SessionRefreshTests(unittest.TestCase):
    def test_active_theme_refreshes_staged_files_and_live_session(self):
        current = {'theme': {'name': 'wh01s17', 'files': 'changed'},
                   'instance': 'session', 'hypr': 'same'}
        previous = {'theme': {'name': 'wh01s17', 'files': 'old'},
                    'instance': 'session', 'hypr': 'same'}
        calls = []
        refresh = SYNC['refresh_session']
        with patch.dict(refresh.__globals__, {'run': lambda *args, **kwargs: calls.append((args, kwargs))}):
            refresh(ROOT, current, previous)
        self.assertEqual(len(calls), 4)
        staging_args, staging_options = calls[0]
        self.assertIn('wh01s17-theme-set', str(staging_args[1]))
        self.assertEqual(staging_options['env']['WH01S17_THEME_HEADLESS'], '1')
        self.assertEqual(staging_options['env']['WH01S17_THEME_SKIP_BACKGROUND'], '1')
        self.assertEqual(calls[1][0], ('hyprctl', 'reload'))
        self.assertIn('applyTheme', calls[2][0])
        self.assertNotIn('wh01s17-theme-set-browser', str(calls))

    def test_unrelated_edits_do_not_reload_session(self):
        current = {'theme': {'name': 'wh01s17', 'files': 'same'},
                   'instance': 'session', 'hypr': 'same'}
        refresh = SYNC['refresh_session']
        with patch.dict(refresh.__globals__, {'run': lambda *args, **kwargs: self.fail(str(args))}):
            refresh(ROOT, current, current)

    def test_hyprland_edit_reloads_without_regenerating_theme(self):
        current = {'theme': None, 'instance': 'session', 'hypr': 'new'}
        calls = []
        refresh = SYNC['refresh_session']
        with patch.dict(refresh.__globals__, {'run': lambda *args, **kwargs: calls.append(args)}):
            refresh(ROOT, current, dict(current, hypr='old'))
        self.assertEqual(calls, [('hyprctl', 'reload')])

    def test_only_active_theme_sources_and_templates_invalidate_theme(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            root = home / 'repo'
            name = home / '.local/state/wh01s17/current/theme.name'
            name.parent.mkdir(parents=True)
            name.write_text('wh01s17')
            theme = root / 'desktop/.config/wh01s17/themes/wh01s17'
            theme.mkdir(parents=True)
            source = theme / 'hyprland.lua'
            source.write_text('enabled = true')
            with patch.dict(os.environ, {'HOME': str(home)}):
                initial = SYNC['session_inputs'](root)
                unrelated = root / 'terminal'
                unrelated.mkdir()
                (unrelated / 'config').write_text('unrelated')
                self.assertEqual(SYNC['session_inputs'](root), initial)
                source.write_text('enabled = false')
                self.assertNotEqual(SYNC['session_inputs'](root)['theme'], initial['theme'])


if __name__ == '__main__':
    unittest.main()
