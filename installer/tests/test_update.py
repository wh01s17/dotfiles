"""Check the updater using a disposable HOME, real Stow and simulated services."""
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
UPDATER = runpy.run_path(str(ROOT / 'installer/tools/update-dotfiles.py'))


class UpdateTests(unittest.TestCase):
    def fixture(self, directory):
        root, home = Path(directory) / 'repo', Path(directory) / 'home'
        home.mkdir()
        for package in UPDATER['PACKAGES']:
            (root / package).mkdir(parents=True)
        for package, app in (('desktop', 'hypr'), ('terminal', 'kitty')):
            for base in (root / package, root / '.arch-build' / package):
                config = base / '.config' / app
                config.mkdir(parents=True)
                (config / 'config').write_text(package)
        (home / '.config/hypr').mkdir(parents=True)
        (home / '.config/hypr/machine-profile.lua').write_text('return "omen"')
        (home / '.config/hypr/custom').symlink_to('/tmp/unrelated-user-file')
        subprocess.run(['stow', '--dir', str(root / '.arch-build'), '--target', str(home),
                        'desktop', 'terminal'], check=True)
        return root, home

    def test_migration_and_repeat_update_without_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root, home = self.fixture(directory)
            calls = []

            def run(*args, **kwargs):
                calls.append(tuple(map(str, args)))
                if len(args) > 2 and 'dotfiles-sync' in str(args[2]):
                    subprocess.run(['stow', '--restow', '--dir', str(root), '--target', str(home),
                                    'desktop', 'terminal'], check=True)

            with patch.dict(UPDATER['apply_configuration'].__globals__, {'run': run}):
                UPDATER['apply_configuration'](root, home)
                self.assertFalse((root / '.arch-build').exists())
                self.assertEqual((home / '.config/hypr/config').resolve(), root / 'desktop/.config/hypr/config')
                self.assertEqual((home / '.config/hypr/machine-profile.lua').read_text(), 'return "omen"')
                self.assertEqual(os.readlink(home / '.config/hypr/custom'), '/tmp/unrelated-user-file')
                UPDATER['apply_configuration'](root, home)
                self.assertEqual(len(calls), 6)

    def test_failed_application_restores_legacy_links_and_retains_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root, home = self.fixture(directory)
            old = (home / '.config/hypr/config').resolve()
            def fail(*args, **kwargs):
                raise subprocess.CalledProcessError(1, 'sync')
            with patch.dict(UPDATER['apply_configuration'].__globals__, {'run': fail}):
                with self.assertRaises(subprocess.CalledProcessError):
                    UPDATER['apply_configuration'](root, home)
            self.assertEqual((home / '.config/hypr/config').resolve(), old)
            self.assertTrue((root / '.arch-build').exists())

    def test_missing_new_source_prevents_any_rewiring(self):
        with tempfile.TemporaryDirectory() as directory:
            root, home = self.fixture(directory)
            (root / 'desktop/.config/hypr/config').unlink()
            with self.assertRaises(ValueError):
                UPDATER['legacy_links'](root, home)
            self.assertIn('.arch-build', str((home / '.config/hypr/config').resolve()))

    def test_lock_explorer_is_retired_without_touching_user_files(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / '.config/wh01s17'
            plugin = config / 'plugins' / UPDATER['LOCK_EXPLORER']
            (plugin / 'videos').mkdir(parents=True)
            (plugin / 'videos/eye.mp4').write_text('clip')
            (config / 'lock-videos').mkdir()
            (config / 'lock-videos/eye.mp4').symlink_to(plugin / 'videos/eye.mp4')
            (config / f'plugins/.{UPDATER["LOCK_EXPLORER"]}.bak.20261119').mkdir()
            (config / 'lock-explorer.json').write_text('{"design": "neon"}')
            (config / 'lock-components').mkdir()
            (config / 'plugins/wh01s17.lock').mkdir()
            (config / 'branding').mkdir()
            previews = home / '.local/state/wh01s17/lock-explorer-boot-previews'
            previews.mkdir(parents=True)
            with patch.dict(os.environ, {'XDG_STATE_HOME': str(home / '.local/state')}):
                removed = UPDATER['retire_lock_explorer'](home)
            self.assertEqual(len(removed), 6)
            for gone in (plugin, config / 'lock-videos', config / 'lock-explorer.json',
                         config / 'lock-components', previews):
                self.assertFalse(os.path.lexists(gone), gone)
            self.assertTrue((config / 'plugins/wh01s17.lock').is_dir())
            self.assertTrue((config / 'branding').is_dir())
            with patch.dict(os.environ, {'XDG_STATE_HOME': str(home / '.local/state')}):
                self.assertEqual(UPDATER['retire_lock_explorer'](home), [])

    def test_lock_explorer_keeps_videos_and_components_that_are_not_its_own(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / '.config/wh01s17'
            (config / 'plugins' / UPDATER['LOCK_EXPLORER']).mkdir(parents=True)
            (config / 'lock-videos').mkdir()
            (config / 'lock-videos/mine.mp4').write_text('own clip')
            (config / 'lock-components').mkdir()
            (config / 'lock-components/Custom.qml').write_text('Item {}')
            with patch.dict(os.environ, {'XDG_STATE_HOME': str(home / '.local/state')}):
                UPDATER['retire_lock_explorer'](home)
            self.assertTrue((config / 'lock-videos/mine.mp4').is_file())
            self.assertTrue((config / 'lock-components/Custom.qml').is_file())
            self.assertFalse((config / 'plugins' / UPDATER['LOCK_EXPLORER']).exists())

    def test_shell_restarts_only_for_shell_sources(self):
        changed = UPDATER['shell_changed']
        self.assertTrue(changed(['platform/.local/share/wh01s17/shell/Ui/KeyboardPanel.qml']))
        self.assertTrue(changed(['desktop/.config/wh01s17/plugins/wh01s17.lock/LockView.qml']))
        self.assertTrue(changed(['desktop/.config/wh01s17/shell.json']))
        self.assertFalse(changed(['README.md', 'desktop/.config/hypr/hyprland.lua']))
        self.assertFalse(changed([]))
        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(UPDATER['restart_shell'](ROOT))
        self.assertEqual(UPDATER['changed_paths'](ROOT, None), [])


if __name__ == '__main__':
    unittest.main()
