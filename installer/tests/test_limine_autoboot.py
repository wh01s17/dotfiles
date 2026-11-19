"""patches/limine-autoboot.sh on copies of limine.conf, never the real ESP."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'patches/limine-autoboot.sh'

MERGED = """timeout: 3

/Arch Linux
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: root=/dev/mapper/root rw quiet
    module_path: boot():/initramfs-linux.img
  //linux
  comment: kernel-id=linux
  protocol: linux
  path: boot():/27ea/linux/vmlinuz#a
  cmdline: root=/dev/mapper/root rw quiet

/Windows
    protocol: efi
    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
"""


class LimineAutobootTests(unittest.TestCase):
    def run_on(self, text):
        with tempfile.TemporaryDirectory() as directory:
            conf = Path(directory) / 'limine.conf'
            conf.write_text(text)
            env = dict(os.environ, LIMINE_OS_NAME='Arch Linux')
            subprocess.run(['bash', str(SCRIPT), str(conf)], env=env, check=True, capture_output=True)
            first = conf.read_text()
            subprocess.run(['bash', str(SCRIPT), str(conf)], env=env, check=True, capture_output=True)
            self.assertEqual(conf.read_text(), first, 'a second run must change nothing')
            return first

    def test_merged_first_boot_entry_becomes_a_bootable_menu(self):
        result = self.run_on(MERGED)
        self.assertIn('default_entry: 2\n', result)
        self.assertIn('\n/+Arch Linux\n  //linux\n', result)
        self.assertNotIn('boot():/vmlinuz-linux', result)
        self.assertIn('  path: boot():/27ea/linux/vmlinuz#a', result)
        self.assertIn('/Windows\n    protocol: efi', result)

    def test_first_boot_entry_goes_once_kernels_exist(self):
        result = self.run_on('timeout: 3\n\n/Primer arranque\n    protocol: linux\n'
                             '    path: boot():/vmlinuz-linux\n\n/+Arch Linux\n  //linux\n  protocol: linux\n')
        self.assertNotIn('Primer arranque', result)
        self.assertIn('default_entry: 2', result)

    def test_fresh_install_is_left_alone(self):
        text = 'timeout: 3\n\n/Primer arranque\n    protocol: linux\n    path: boot():/vmlinuz-linux\n'
        self.assertEqual(self.run_on(text), text)


if __name__ == '__main__':
    unittest.main()
