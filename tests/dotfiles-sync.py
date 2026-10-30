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
                 patch.dict(main.__globals__, {'run': lambda *args: calls.append(tuple(map(str, args)))}), \
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
                 patch.dict(main.__globals__, {'run': lambda *args: calls.append(args)}):
                main(); self.assertEqual(calls, [])


if __name__ == '__main__':
    unittest.main()
