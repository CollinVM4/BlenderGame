"""Runner contract checks; no Luau executable required."""
import contextlib
import io
from pathlib import Path
import runpy
import subprocess
import sys
import unittest
from unittest.mock import patch

RUNNER = Path(__file__).with_name("run_state_tests.py")


class StateRunnerTests(unittest.TestCase):
    def run_runner(self, *arguments, fail_first=False):
        calls = []
        output = io.StringIO()

        def execute(command, **_kwargs):
            bundle = Path(command[1])
            calls.append((bundle.stem, bundle.read_text(encoding="utf-8")))
            return subprocess.CompletedProcess(command, int(fail_first and len(calls) == 1))

        with patch.object(sys, "argv", [str(RUNNER), *arguments]), patch(
            "subprocess.run", side_effect=execute
        ), contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as stopped:
            runpy.run_path(str(RUNNER), run_name="__main__")
        return stopped.exception.code, calls, output.getvalue()

    def test_default_covers_focused_suites_and_presentation_separately(self):
        code, calls, output = self.run_runner()
        self.assertEqual(code, 0)
        names = [name for name, _ in calls]
        for name in ("carry", "stash", "smoothie", "requests", "customer-queue", "customer-orders", "customer-payout", "customer-payout-serve", "customer-result", "world", "vfx", "smoothie-roundtrip"):
            self.assertIn(name, names)
        self.assertEqual(len(names), len(set(names)))
        for group in ("state", "integration", "presentation"):
            self.assertIn(f"[{group}]", output)
        for name, bundle in calls:
            # VFX source is bundled for loading, but only its own entry point executes it.
            self.assertEqual("\nvfxTests({" in bundle, name == "vfx")

    def test_failed_suite_does_not_stop_group_and_returns_failure(self):
        code, calls, output = self.run_runner("--group", "presentation", fail_first=True)
        self.assertEqual(code, 1)
        self.assertGreater(len(calls), 1)
        self.assertEqual(calls[0][0], "customer-result")
        self.assertIn("FAIL customer-result", output)
        self.assertIn("PASS stash-presentation", output)

    def test_state_group_does_not_execute_integration_or_presentation(self):
        code, calls, _ = self.run_runner("--group", "state")
        self.assertEqual(code, 0)
        self.assertEqual({name for name, _ in calls}, {"throw", "carry", "stash", "smoothie-world", "smoothie", "customer-validation", "customer-compatibility", "customer-payout", "sprint"})

    def test_named_session_suites_are_independently_selectable(self):
        code, calls, _ = self.run_runner("--suite", "plot-session", "--suite", "plot-session-races", "--suite", "plot-session-progression", "--suite", "plot-session-requests")
        self.assertEqual(code, 0)
        self.assertEqual([name for name, _ in calls], ["plot-session", "plot-session-races", "plot-session-progression", "plot-session-requests"])

    def test_focused_smoothie_keeps_flow_and_geometry_coverage(self):
        code, calls, _ = self.run_runner("--smoothie-only")
        self.assertEqual(code, 0)
        self.assertEqual(
            {name for name, _ in calls},
            {"smoothie-world", "smoothie", "smoothie-roundtrip", "smoothie-survivors", "smoothie-geometry"},
        )


if __name__ == "__main__":
    unittest.main()
