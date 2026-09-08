#!/usr/bin/env python3
"""Audio engine for the wh01s17.metronome shell plugin.

Timing lives here, not in QML: a Quickshell Timer drifts by whole
milliseconds under load, which a musician hears immediately. This process
synthesises the click track sample by sample and hands raw PCM to a player
(`pw-cat`, or `aplay` as a fallback), so every pulse lands on an exact
frame boundary regardless of what the shell's event loop is doing.

Protocol
  stdin   one JSON object per line, any subset of the state keys:
          {"running": true, "bpm": 120, "beats": 4, "subdivision": "1/8",
           "volume": 0.7, "accent": true}
          Unknown keys are ignored; "quit" exits.
  stdout  one JSON event per line, emitted when the pulse becomes
          *audible* rather than when it is synthesised:
          {"e": "beat", "beat": 0, "pulse": 0, "accent": true, "bpm": 120}
  stderr  human-readable diagnostics only.

The stream stays open while stopped — silence is cheaper than tearing the
player down and paying its startup latency on the next start, and it keeps
the measured output latency stable across starts.
"""

import array
import json
import math
import os
import shutil
import signal
import subprocess
import sys
import threading
import time

RATE = 48000
CHUNK = 512            # frames per render pass (~10.7 ms)
LOOKAHEAD = 0.08       # seconds of audio kept ahead of the wall clock
SINK_LATENCY = 0.030   # the player's own buffer, matched to --latency below

# Pulse offsets inside one beat, as fractions of the beat.
SUBDIVISIONS = {
    "1/4":   [0.0],
    "1/8":   [0.0, 0.5],
    "1/8t":  [0.0, 1.0 / 3.0, 2.0 / 3.0],
    "1/16":  [0.0, 0.25, 0.5, 0.75],
    "1/16t": [0.0, 1.0 / 6.0, 2.0 / 6.0, 3.0 / 6.0, 4.0 / 6.0, 5.0 / 6.0],
    "swing": [0.0, 2.0 / 3.0],
}

# freq (Hz), amplitude, decay time constant (s), length (s)
VOICE_ACCENT = (1560.0, 1.00, 0.016, 0.055)
VOICE_BEAT = (1040.0, 0.72, 0.018, 0.055)
VOICE_SUB = (2080.0, 0.30, 0.008, 0.030)

SILENCE = array.array("h", [0] * CHUNK).tobytes()


def player_command():
    if shutil.which("pw-cat"):
        return ["pw-cat", "-p", "--format", "s16", "--rate", str(RATE),
                "--channels", "1", "--raw", "--latency", "30ms",
                "--media-role", "Production",
                "-P", "media.name=Metronome", "-"]
    if shutil.which("aplay"):
        return ["aplay", "-q", "-t", "raw", "-f", "S16_LE",
                "-r", str(RATE), "-c", "1", "-"]
    return None


class Emitter(threading.Thread):
    """Prints beat events at the moment their audio reaches the speakers.

    Synthesis runs LOOKAHEAD seconds early, so publishing a beat as it is
    rendered would light the UI up before the click is heard. Events are
    queued with the wall-clock time they become audible and released then.
    """

    daemon = True

    def __init__(self):
        super().__init__()
        self.cond = threading.Condition()
        self.queue = []
        self.alive = True

    def push(self, when, payload):
        with self.cond:
            self.queue.append((when, payload))
            self.queue.sort(key=lambda item: item[0])
            self.cond.notify()

    def drop_pending(self):
        with self.cond:
            self.queue = []
            self.cond.notify()

    def stop(self):
        with self.cond:
            self.alive = False
            self.cond.notify()

    def run(self):
        while True:
            with self.cond:
                if not self.alive:
                    return
                if not self.queue:
                    self.cond.wait()
                    continue
                when, payload = self.queue[0]
                delay = when - time.monotonic()
                if delay > 0:
                    self.cond.wait(delay)
                    continue
                self.queue.pop(0)
            try:
                sys.stdout.write(json.dumps(payload) + "\n")
                sys.stdout.flush()
            except (BrokenPipeError, ValueError):
                return


class Engine:
    def __init__(self):
        self.lock = threading.Lock()
        self.running = False
        self.bpm = 100.0
        self.beats = 4
        self.subdivision = "1/4"
        self.volume = 0.7
        self.accent = True
        self.generation = 0      # bumped on every stop/start, tags queued events

        self.pos = 0             # absolute frame cursor
        self.voices = []
        self.beat_start = 0.0    # frame position of the current beat
        self.beat_index = 0
        self.pulse_index = 0
        self.beat_len = self._beat_frames()

        self.emitter = Emitter()
        self.player = None
        self.quit = False

    # ------------------------------------------------------------- state

    def _beat_frames(self):
        return RATE * 60.0 / max(20.0, min(400.0, self.bpm))

    def offsets(self):
        return SUBDIVISIONS.get(self.subdivision, SUBDIVISIONS["1/4"])

    def apply(self, msg):
        with self.lock:
            if msg.get("quit"):
                self.quit = True
                return
            if "bpm" in msg:
                try:
                    self.bpm = max(20.0, min(400.0, float(msg["bpm"])))
                except (TypeError, ValueError):
                    pass
            if "beats" in msg:
                try:
                    self.beats = max(1, min(32, int(msg["beats"])))
                except (TypeError, ValueError):
                    pass
            if "subdivision" in msg and msg["subdivision"] in SUBDIVISIONS:
                self.subdivision = msg["subdivision"]
            if "volume" in msg:
                try:
                    self.volume = max(0.0, min(1.0, float(msg["volume"])))
                except (TypeError, ValueError):
                    pass
            if "accent" in msg:
                self.accent = bool(msg["accent"])
            if "running" in msg:
                want = bool(msg["running"])
                if want != self.running:
                    self.running = want
                    self.generation += 1
                    self.voices = []
                    if want:
                        # Start on the next render pass rather than mid-chunk,
                        # so the downbeat is exactly one lookahead away and the
                        # first click is not clipped by the pacing sleep.
                        self.beat_start = float(self.pos) + CHUNK
                        self.beat_index = 0
                        self.pulse_index = 0
                        self.beat_len = self._beat_frames()
                    else:
                        self.emitter.drop_pending()

    # --------------------------------------------------------- synthesis

    def schedule(self, until):
        """Queue every pulse that starts before frame `until`."""
        while self.running:
            offsets = self.offsets()
            if self.pulse_index >= len(offsets):
                # Tempo changes take effect on the bar's next beat, never
                # mid-beat: shortening the beat under a pulse already
                # scheduled would swallow it.
                self.beat_start += self.beat_len
                self.beat_len = self._beat_frames()
                self.beat_index = (self.beat_index + 1) % max(1, self.beats)
                self.pulse_index = 0
                continue

            frame = self.beat_start + offsets[self.pulse_index] * self.beat_len
            if frame >= until:
                return

            downbeat = self.pulse_index == 0
            accented = downbeat and self.beat_index == 0 and self.accent
            if accented:
                voice = VOICE_ACCENT
            elif downbeat:
                voice = VOICE_BEAT
            else:
                voice = VOICE_SUB

            freq, amp, decay, length = voice
            self.voices.append({
                "start": frame,
                "freq": freq,
                "amp": amp * self.volume,
                "decay": decay,
                "end": frame + length * RATE,
            })
            self.emitter.push(
                self.start_wall + frame / RATE + SINK_LATENCY,
                {"e": "beat", "beat": self.beat_index, "pulse": self.pulse_index,
                 "accent": accented, "downbeat": downbeat,
                 "bpm": round(self.bpm, 2), "gen": self.generation})
            self.pulse_index += 1

    def render(self):
        """Return CHUNK frames of PCM for the current cursor position."""
        if not self.voices:
            return SILENCE

        buf = [0.0] * CHUNK
        alive = []
        for voice in self.voices:
            start = voice["start"]
            if voice["end"] <= self.pos:
                continue
            alive.append(voice)
            first = max(0, int(math.ceil(start - self.pos)))
            last = min(CHUNK, int(math.ceil(voice["end"] - self.pos)))
            omega = 2.0 * math.pi * voice["freq"] / RATE
            for i in range(first, last):
                t = (self.pos + i - start)
                env = math.exp(-(t / RATE) / voice["decay"])
                buf[i] += voice["amp"] * env * math.sin(omega * t)
        self.voices = alive

        out = array.array("h", [0] * CHUNK)
        for i in range(CHUNK):
            s = buf[i]
            if s > 1.0:
                s = 1.0
            elif s < -1.0:
                s = -1.0
            out[i] = int(s * 32000.0)
        return out.tobytes()

    # -------------------------------------------------------------- loop

    def read_stdin(self):
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if isinstance(msg, dict):
                self.apply(msg)
                if self.quit:
                    break
        self.quit = True

    def run(self):
        command = player_command()
        if command is None:
            sys.stderr.write("no audio player found (need pw-cat or aplay)\n")
            return 1

        self.player = subprocess.Popen(command, stdin=subprocess.PIPE,
                                       stdout=subprocess.DEVNULL)
        self.emitter.start()
        threading.Thread(target=self.read_stdin, daemon=True).start()

        self.start_wall = time.monotonic()
        try:
            while not self.quit:
                target = self.start_wall + self.pos / RATE - LOOKAHEAD
                delay = target - time.monotonic()
                if delay > 0:
                    time.sleep(min(delay, 0.05))
                    continue
                with self.lock:
                    self.schedule(self.pos + CHUNK)
                    data = self.render()
                    self.pos += CHUNK
                self.player.stdin.write(data)
                self.player.stdin.flush()
        except (BrokenPipeError, KeyboardInterrupt):
            pass
        finally:
            self.shutdown()
        return 0

    def shutdown(self):
        self.emitter.stop()
        if self.player and self.player.poll() is None:
            try:
                self.player.stdin.close()
            except (BrokenPipeError, ValueError):
                pass
            try:
                self.player.terminate()
                self.player.wait(timeout=1)
            except Exception:
                self.player.kill()


def main():
    engine = Engine()

    def bye(_signum, _frame):
        engine.quit = True
        engine.shutdown()
        os._exit(0)

    signal.signal(signal.SIGTERM, bye)
    signal.signal(signal.SIGINT, bye)
    return engine.run()


if __name__ == "__main__":
    sys.exit(main())
