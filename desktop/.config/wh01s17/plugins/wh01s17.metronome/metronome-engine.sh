#!/usr/bin/env bash
# Runs the metronome's audio engine, building it first when needed.
#
# metronome-engine.c is compiled against libpipewire into the user's cache,
# keyed by a hash of the source, so a change to the engine (a pull, a stow
# into a fresh machine) rebuilds it on the next start and never runs a stale
# binary. The build takes a moment once; every later start is a plain exec.
#
#   metronome-engine.sh           build if needed, then run the engine
#   metronome-engine.sh --build   build if needed and exit (warms the cache)
set -euo pipefail

here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
src=$here/metronome-engine.c
cache=${XDG_CACHE_HOME:-$HOME/.cache}/wh01s17
hash=$(sha256sum "$src" | cut -c1-16)
bin=$cache/metronome-engine-$hash

if [[ ! -x $bin ]]; then
  mkdir -p "$cache"
  tmp=$(mktemp "$cache/.metronome-engine.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  # shellcheck disable=SC2046 # pkg-config prints one flag per word
  "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -o "$tmp" "$src" \
    $(pkg-config --cflags --libs libpipewire-0.3) -lm -lpthread
  chmod 755 "$tmp"
  mv -f "$tmp" "$bin"
  trap - EXIT
  # Earlier builds are dead weight once the source has moved on.
  find "$cache" -maxdepth 1 -name 'metronome-engine-*' ! -path "$bin" -delete
fi

[[ ${1-} == --build ]] && exit 0

# The engine's audio thread runs at realtime priority, which needs a realtime
# CPU budget (RLIMIT_RTTIME). A desktop portal that lost track of RTKit hands
# PipeWire clients a budget of 0 µs, and the shell — a PipeWire client itself
# — passes that hard limit on to every child, where nothing unprivileged can
# raise it again. A transient unit of the user manager starts with clean
# limits; --pipe keeps stdin/stdout wired to the shell, and the engine exits
# when the shell closes its stdin.
rttime=$(ulimit -H -R 2>/dev/null || echo unlimited)
if [[ $rttime != unlimited ]] && ((rttime < 200000)) && command -v systemd-run >/dev/null; then
  env_args=()
  [[ -v WH01S17_METRONOME_SINK ]] && env_args+=(-E "WH01S17_METRONOME_SINK=$WH01S17_METRONOME_SINK")
  # systemd-run does not pass a SIGTERM on to the unit, so the shell
  # stopping this launcher has to stop the unit by name.
  unit=wh01s17-metronome-$$
  trap 'systemctl --user stop "$unit" 2>/dev/null; exit 143' TERM INT HUP
  # Backgrounded so the trap runs at once; stdin is passed explicitly,
  # since a background job would otherwise read from /dev/null.
  systemd-run --user --pipe --quiet --collect --unit="$unit" --description=Metronome \
    "${env_args[@]}" -- "$bin" "$@" <&0 &
  wait $!
  exit $?
fi
exec "$bin" "$@"
