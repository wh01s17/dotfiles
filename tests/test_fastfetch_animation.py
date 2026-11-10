"""Fastfetch's dot renderer and terminal overlay contract (no desktop needed)."""

import importlib.util
import io
import math
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "desktop/.config/fastfetch/w-spin.py"
SPEC = importlib.util.spec_from_file_location("w_spin", SCRIPT)
spin = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(spin)
ANSI = re.compile(r"\x1b\[[0-9;]*m")
GREEN, WHITE = (132, 201, 89), (243, 251, 238)


class FastfetchAnimationTests(unittest.TestCase):
    def test_frames_stay_inside_logo_panel(self):
        for logo in ("w", "arch"):
            for step in range(13):
                lines = spin.render(-math.pi / 2 + step * math.pi / 12, GREEN, logo)
                self.assertEqual(len(lines), spin.HEIGHT)
                for line in lines:
                    plain = ANSI.sub("", line)
                    self.assertEqual(len(plain), spin.WIDTH)
                    self.assertTrue(all(c == " " or 0x2800 <= ord(c) <= 0x28FF
                                        for c in plain))

    def test_transition_starts_with_w_pauses_on_arch_and_ends_with_w(self):
        self.assertEqual(spin.animation_frame(0, GREEN, WHITE), spin.render(0, GREEN))
        self.assertEqual(spin.animation_frame(0.50, GREEN, WHITE), spin.render(0, WHITE, "arch"))
        self.assertEqual(spin.animation_frame(1, GREEN, WHITE), spin.render(0, GREEN))
        # The silhouettes stay recognizable: W has a centre bar, A an open arch.
        self.assertTrue(spin.silhouette(0, -0.4, "w"))
        self.assertFalse(spin.silhouette(0, -0.4, "arch"))
        self.assertTrue(spin.silhouette(0, 0.7, "arch"))

    def test_active_theme_colors(self):
        with tempfile.TemporaryDirectory() as state:
            colors = Path(state) / "wh01s17/current/theme/colors.toml"
            colors.parent.mkdir(parents=True)
            colors.write_text('accent = "#aabbcc"\nbright_foreground = "#ddeeff"\n')
            with patch.dict(os.environ, {"XDG_STATE_HOME": state}):
                self.assertEqual(spin.theme_colors(),
                                 {"accent": "#aabbcc", "bright_foreground": "#ddeeff"})

    def test_two_turns_in_each_direction(self):
        with patch.object(spin, "render") as render:
            spin.animation_frame(0.26, GREEN, WHITE)
            angle, color, logo = render.call_args.args
            self.assertAlmostEqual(angle, 2 * math.pi)
            self.assertEqual((color, logo), (GREEN, "w"))
            spin.animation_frame(0.76, GREEN, WHITE)
            angle, color, logo = render.call_args.args
            self.assertAlmostEqual(angle, 2 * math.pi)
            self.assertEqual((color, logo), (WHITE, "arch"))

    def test_interrupt_leaves_w_and_restores_cursor(self):
        output = io.StringIO()
        with patch.object(spin.sys, "stdout", output), \
                patch.object(spin.os, "get_terminal_size", return_value=os.terminal_size((120, 40))), \
                patch.object(spin.time, "sleep", side_effect=KeyboardInterrupt):
            spin.play(25, 3, GREEN, WHITE)
        result = output.getvalue()
        self.assertTrue(result.startswith("\x1b[?25l\x1b7"))
        self.assertTrue(result.endswith("\x1b[?25h"))
        self.assertIn(spin.render(0, GREEN)[10], result)
        self.assertNotIn("\x1b[2J", result)
        self.assertNotIn("\x1b[0K", result)

    def test_demo_repeats_cycles_until_interrupt(self):
        output = io.StringIO()
        # Two completed cycles must wrap rather than ending playback.
        with patch.object(spin.sys, "stdout", output), \
                patch.object(spin.os, "get_terminal_size", return_value=os.terminal_size((120, 40))), \
                patch.dict(os.environ, {"WH01S17_SPIN_SECONDS": "1"}), \
                patch.object(spin.time, "monotonic", side_effect=[0, 0.5, 0.5, 1.25, 1.25, 2.75, 2.75]), \
                patch.object(spin.time, "sleep", side_effect=[None, None, KeyboardInterrupt]), \
                patch.object(spin, "animation_frame", return_value=["frame"] * spin.HEIGHT) as frame:
            spin.play(25, 3, GREEN, WHITE, loop=True)
        self.assertEqual([call.args[0] for call in frame.call_args_list], [0.5, 0.25, 0.75])
        self.assertTrue(output.getvalue().endswith("\x1b[?25h"))
        self.assertIn(spin.render(0, GREEN)[10], output.getvalue())

    def test_normal_play_stops_after_one_cycle(self):
        with patch.object(spin.sys, "stdout", io.StringIO()), \
                patch.object(spin.os, "get_terminal_size", return_value=os.terminal_size((120, 40))), \
                patch.dict(os.environ, {"WH01S17_SPIN_SECONDS": "1"}), \
                patch.object(spin.time, "monotonic", side_effect=[0, 1.1]), \
                patch.object(spin, "animation_frame", return_value=["frame"] * spin.HEIGHT) as frame, \
                patch.object(spin.time, "sleep") as sleep:
            spin.play(25, 3, GREEN, WHITE)
        frame.assert_called_once_with(1.0, GREEN, WHITE)
        sleep.assert_not_called()


if __name__ == "__main__":
    unittest.main()
