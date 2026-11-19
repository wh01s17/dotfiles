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
# Quickshell does not pick up new QML on its own, and a lock service is never
# swapped live: changes here need the shell restarted.
SHELL_SOURCES = ('platform/.local/share/wh01s17/shell/', 'desktop/.config/wh01s17/plugins/',
                 'desktop/.config/wh01s17/bar/', 'desktop/.config/wh01s17/shell.json')
LOCK_EXPLORER = 'io.github.sirjul1337.lock-explorer'


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


def retire_lock_explorer(home):
    """Remove the third-party lock-explorer that wh01s17.lock replaced.

    Only its own paths: lock-videos only while it holds nothing but links into
    the plugin, lock-components only when empty. Returns what was removed."""
    config = home / '.config/wh01s17'
    plugin = config / 'plugins' / LOCK_EXPLORER
    removed = []
    if plugin.is_symlink():
        plugin.unlink()
        removed.append(plugin)
    elif plugin.is_dir():
        videos = config / 'lock-videos'
        if videos.is_dir() and not videos.is_symlink():
            entries = list(videos.iterdir())
            if all(e.is_symlink() and str(plugin) in os.readlink(e) for e in entries):
                shutil.rmtree(videos)
                removed.append(videos)
        shutil.rmtree(plugin)
        removed.append(plugin)
    for leftover in config.glob(f'plugins/.{LOCK_EXPLORER}.bak.*'):
        if leftover.is_dir() and not leftover.is_symlink():
            shutil.rmtree(leftover)
            removed.append(leftover)
    settings = config / 'lock-explorer.json'
    if settings.is_file() and not settings.is_symlink():
        settings.unlink()
        removed.append(settings)
    components = config / 'lock-components'
    if components.is_dir() and not components.is_symlink() and not any(components.iterdir()):
        components.rmdir()
        removed.append(components)
    previews = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state')) / 'wh01s17/lock-explorer-boot-previews'
    if previews.is_dir() and not previews.is_symlink():
        shutil.rmtree(previews)
        removed.append(previews)
    return removed


def changed_paths(root, before):
    if not before:
        return []
    result = subprocess.run(['git', '-C', str(root), 'diff', '--name-only', before, 'HEAD'],
                            check=False, capture_output=True, text=True)
    return result.stdout.split() if result.returncode == 0 else []


def shell_changed(paths):
    return any(path.startswith(SHELL_SOURCES) or path in SHELL_SOURCES for path in paths)


def restart_shell(root):
    """Best effort: an update never fails because the shell could not restart."""
    if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        return False
    runtime = root / 'platform/.local/share/wh01s17'
    environment = dict(os.environ, WH01S17_PATH=str(runtime),
                       PATH=str(runtime / 'bin') + os.pathsep + os.environ.get('PATH', ''))
    return subprocess.run(['bash', str(runtime / 'bin/wh01s17-restart-shell')], env=environment,
                          check=False, capture_output=True).returncode == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local', action='store_true', help='apply the current checkout without pulling')
    # Set by the updater when a pull changed this very script: the new copy
    # runs with --local and still knows where the update started.
    parser.add_argument('--since', help=argparse.SUPPRESS)
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
            before = args.since
            if not args.local:
                print('Actualizando el repositorio…', flush=True)
                head = subprocess.run(['git', '-C', str(root), 'rev-parse', 'HEAD'],
                                      check=False, capture_output=True, text=True)
                before = head.stdout.strip() if head.returncode == 0 else None
                script = Path(__file__).resolve()
                old_script = script.read_bytes()
                run('git', '-C', root, 'pull', '--ff-only')
                if script.read_bytes() != old_script:
                    # Python already loaded the old updater; hand over to the new one.
                    print('El actualizador cambió; continuando con la versión nueva…', flush=True)
                    lock.close()
                    os.execv(sys.executable, [sys.executable, '-B', str(script), '--local']
                             + (['--since', before] if before else []))
            print('Aplicando la configuración…', flush=True)
            apply_configuration(root, Path.home())
            for path in retire_lock_explorer(Path.home()):
                print(f'Retirado (lock-explorer): {path}', flush=True)
        except (subprocess.CalledProcessError, OSError, ValueError, RuntimeError) as error:
            if active:
                subprocess.run(['systemctl', '--user', 'start', 'dotfiles-sync.timer'], check=False)
            parser.exit(1, f'La actualización se detuvo: {error}\n')
    if shell_changed(changed_paths(root, before)) and restart_shell(root):
        print('Shell reiniciado con los cambios nuevos.')
    print('Configuración actualizada. Cierra sesión y vuelve a entrar para cargar todos los cambios.')


if __name__ == '__main__':
    main()
