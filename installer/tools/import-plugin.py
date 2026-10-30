#!/usr/bin/env python3
"""Import an external plugin into the wh01s17 namespace (explicit operation)."""
import argparse
import os
from pathlib import Path
import shutil
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rename import NAME, is_qml, rename_name, rename_qml, rename_text, leftovers


def skipped(name):
    return name in {'.git', '__pycache__'} or name.endswith('.pyc')


def convert_file(source: Path, target: Path) -> list[str]:
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        target.symlink_to(rename_name(os.readlink(source)))
        return []
    try:
        text = source.read_text()
    except UnicodeDecodeError:
        shutil.copy2(source, target)
        return []
    new_text = rename_text(text)
    if is_qml(target.name, new_text):
        new_text = rename_qml(new_text)
    if target.suffix == ".lua":
        # Plain Arch has no /usr/share/wh01s17: fall back to the stowed copy.
        new_text = new_text.replace(f'"/usr/share/{NAME}"', f'(os.getenv("HOME") .. "/.local/share/{NAME}")')
    target.write_text(new_text)
    shutil.copymode(source, target)
    return leftovers(new_text)


def build(source_root: Path, target_root: Path) -> dict[str, list[str]]:
    remaining: dict[str, list[str]] = {}
    for directory, dirnames, filenames in os.walk(source_root):
        dirnames[:] = [d for d in dirnames if not skipped(d)]
        base = Path(directory)
        relative = base.relative_to(source_root)
        target_dir = target_root / Path(*[rename_name(part) for part in relative.parts])
        # Symlinked directories are links too: recreate them, do not descend.
        for name in list(dirnames):
            if (base / name).is_symlink():
                dirnames.remove(name)
                filenames.append(name)
        for name in filenames:
            if skipped(name):
                continue
            found = convert_file(base / name, target_dir / rename_name(name))
            if found:
                remaining[str(relative / name)] = found
    return remaining



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plugin', type=Path)
    args = parser.parse_args()
    root = args.plugin.expanduser().resolve()
    if not root.is_dir():
        parser.error(f'No existe el plugin: {root}')
    with tempfile.TemporaryDirectory(prefix='plugin-import-', dir=root.parent) as directory:
        staging = Path(directory) / 'plugin'
        build(root, staging)
        # Preserve the plugin's Git checkout; copy only imported source entries.
        for entry in staging.iterdir():
            target = root / entry.name
            if entry.is_dir() and not entry.is_symlink():
                shutil.copytree(entry, target, dirs_exist_ok=True)
            elif entry.is_symlink():
                target.unlink(missing_ok=True)
                target.symlink_to(os.readlink(entry))
            else:
                shutil.copy2(entry, target)


if __name__ == '__main__':
    main()
