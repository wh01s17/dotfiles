"""Guard the imported disk/encryption/boot logic against migration changes."""
import hashlib
import json
from pathlib import Path
import unittest
import subprocess

INSTALLER = Path(__file__).resolve().parents[1]


class InstallationIntegrityTests(unittest.TestCase):
    def test_sensitive_installation_sources_match_original(self):
        manifest = json.loads((INSTALLER / 'tests/installation-origin-sha256.json').read_text())
        for relative, expected in manifest.items():
            with self.subTest(path=relative):
                content = (INSTALLER / relative).read_bytes()
                if relative == 'tools/iso-install.sh':
                    # Only repository locations and the continuation command changed.
                    # Lint-only annotations do not alter disk/encryption commands.
                    text = ''.join(line for line in content.decode().splitlines(keepends=True)
                                   if line.strip() not in {'# shellcheck disable=SC2154',
                                                           '# shellcheck disable=SC2015'})
                    for current, original in (
                        ('https://github.com/wh01s17/dotfiles', 'https://github.com/wh01s17/arch-desktop'),
                        ('bash dotfiles/installer/tools/iso-install.sh', 'bash arch-desktop/tools/iso-install.sh'),
                        ('readonly REPO=wh01s17/dotfiles', 'readonly REPO=wh01s17/arch-desktop'),
                        ("log 'Repo dotfiles'", "log 'Repo arch-desktop'"),
                        ('/mnt/home/$user/dotfiles/.git', '/mnt/home/$user/workspace/arch-desktop/.git'),
                        ('"/home/$user/dotfiles"', '"/home/$user/workspace/arch-desktop"'),
                        ('cd ~/dotfiles && ./installer/install.sh', 'cd ~/workspace/arch-desktop && ./install.sh'),
                    ):
                        self.assertIn(current, text)
                        text = text.replace(current, original)
                    content = text.encode()
                self.assertEqual(hashlib.sha256(content).hexdigest(), expected,
                                 f'{relative}: cambió lógica fuera de la reubicación del repositorio')

    def test_machine_dry_run_succeeds_for_a_physical_gpu(self):
        result = subprocess.run(
            ['bash', '-c', 'source "$1"; DRY_RUN=true; WH_PROFILE=omen; WH_GPU=nvidia; stage_machine',
             'test', str(INSTALLER / 'install.sh')], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('[dry-run]', result.stdout)

    def test_external_plugin_import_uses_native_namespace_and_preserves_git(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'plugin'
            (root / '.git').mkdir(parents=True)
            (root / '.git/config').write_text('repository metadata')
            (root / 'Panel.qml').write_text('import QtQuick\nimport qs.Commons\nItem { property color tint: Color.accent }\n')
            (root / 'helper.lua').write_text('local root = "/usr/share/omarchy"\n')
            (root / 'manifest.json').write_text('{"id":"custom.plugin","description":"Omarchy plugin"}')
            command = ['python3', '-I', str(INSTALLER / 'tools/import-plugin.py'), str(root)]
            subprocess.run(command, check=True)
            self.assertIn('Colors.accent', (root / 'Panel.qml').read_text())
            self.assertIn('.local/share/wh01s17', (root / 'helper.lua').read_text())
            self.assertIn('wh01s17 plugin', (root / 'manifest.json').read_text())
            self.assertEqual((root / '.git/config').read_text(), 'repository metadata')
            before = (root / 'Panel.qml').read_text()
            subprocess.run(command, check=True)
            self.assertEqual((root / 'Panel.qml').read_text(), before)

    def test_diagnostic_success_counter_does_not_report_a_failure(self):
        source = (INSTALLER / 'tools/check-desktop.sh').read_text()
        helpers = source[source.index('passed=0 failed=0'):source.index('info()')]
        result = subprocess.run(
            ['bash', '-e', '-c', helpers + '\nok "first check"; test "$passed" = 1; test "$failed" = 0'],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
