#!/usr/bin/env python3
"""Update the checkout, migrate old links, and apply the desktop configuration."""
import argparse
import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PACKAGES = ('desktop', 'terminal', 'maintenance', 'platform', 'apps')


def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def replace_link(destination, target):
    fd, temporary = tempfile.mkstemp(prefix=f'.{destination.name}.', dir=destination.parent)
    os.close(fd)
    try:
        os.unlink(temporary)
        os.symlink(target, temporary)
        os.replace(temporary, destination)
    finally:
        if os.path.lexists(temporary):
            os.unlink(temporary)


def legacy_links(root, home):
    """Plan only links owned by the old build, without traversing HOME links."""
    changes = []
    for package in ('desktop', 'terminal'):
        legacy = root / '.arch-build' / package
        if not legacy.is_dir():
            continue

        def visit(old, new, destination):
            if destination.is_symlink():
                previous = os.readlink(destination)
                target = Path(os.path.abspath(destination.parent / previous))
                if target == old:
                    if not new.exists():
                        raise ValueError(f'Falta el nuevo destino: {new}')
                    changes.append((destination, previous, os.path.relpath(new, destination.parent)))
                return
            if old.is_dir() and not old.is_symlink() and destination.is_dir():
                for child in sorted(old.iterdir()):
                    visit(child, new / child.name, destination / child.name)

        visit(legacy, root / package, home)
    return changes


def apply_configuration(root, home):
    for package in PACKAGES:
        if not (root / package).is_dir():
            raise ValueError(f'Falta el paquete Stow: {root / package}')
    build = root / '.arch-build'
    if build.is_symlink():
        raise ValueError(f'No se eliminará un build que sea un enlace: {build}')
    changes = legacy_links(root, home)
    applied = []
    try:
        for destination, previous, target in changes:
            replace_link(destination, target)
            applied.append((destination, previous, target))
        run(sys.executable, '-B', root / 'maintenance/.local/bin/dotfiles-sync',
            '--dotfiles', root, '--force')
    except Exception:
        # Restore only our links if application failed; keep the old build available.
        for destination, previous, target in reversed(applied):
            if destination.is_symlink() and os.readlink(destination) == target:
                replace_link(destination, previous)
        raise
    run('bash', root / 'test.sh', cwd=root)
    run('systemctl', '--user', 'enable', '--now', 'dotfiles-sync.timer')
    if build.exists():
        shutil.rmtree(build)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local', action='store_true', help='apply the current checkout without pulling')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'dotfiles-sync'
    state.mkdir(parents=True, exist_ok=True)
    with (state / 'update.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.exit(1, 'Ya hay una actualización de dotfiles en curso.\n')
        active = subprocess.run(['systemctl', '--user', 'is-active', '--quiet', 'dotfiles-sync.timer'],
                                check=False).returncode == 0
        try:
            # Old installations may not have the timer yet.
            stopped = subprocess.run(['systemctl', '--user', 'stop', 'dotfiles-sync.timer',
                                      'dotfiles-sync.service'], check=False, capture_output=True, text=True)
            if active and stopped.returncode:
                raise RuntimeError(stopped.stderr.strip())
            if not args.local:
                print('Actualizando el repositorio…', flush=True)
                run('git', '-C', root, 'pull', '--ff-only')
            print('Aplicando la configuración…', flush=True)
            apply_configuration(root, Path.home())
        except (subprocess.CalledProcessError, OSError, ValueError, RuntimeError) as error:
            if active:
                subprocess.run(['systemctl', '--user', 'start', 'dotfiles-sync.timer'], check=False)
            parser.exit(1, f'La actualización se detuvo: {error}\n')
    print('Configuración actualizada. Cierra sesión y vuelve a entrar para cargar todos los cambios.')


if __name__ == '__main__':
    main()
