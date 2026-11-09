"""Runner contract checks; no Luau executable required."""
import ast
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
    def run_runner(self, *arguments, fail_first=False, registry_source=None, missing_file=None):
        calls = []
        output = io.StringIO()

        def execute(command, **_kwargs):
            bundle = Path(command[1])
            calls.append((bundle.stem, bundle.read_text(encoding="utf-8")))
            return subprocess.CompletedProcess(command, int(fail_first and len(calls) == 1))

        read_text = Path.read_text

        def read(path, *args, **kwargs):
            if path.name == missing_file:
                raise FileNotFoundError(path)
            if path == RUNNER and registry_source is not None:
                return registry_source
            return read_text(path, *args, **kwargs)

        with patch.object(Path, "read_text", read), patch.object(sys, "argv", [str(RUNNER), *arguments]), patch(
            "subprocess.run", side_effect=execute
        ), contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as stopped:
            runpy.run_path(str(RUNNER), run_name="__main__")
        return stopped.exception.code, calls, output.getvalue()

    def test_default_covers_focused_suites_and_presentation_separately(self):
        code, calls, output = self.run_runner()
        self.assertEqual(code, 0)
        names = [name for name, _ in calls]
        for name in ("carry", "stash", "smoothie", "request-selection", "requests", "customer-queue", "customer-orders", "customer-payout", "customer-payout-serve", "customer-result", "world", "vfx", "smoothie-roundtrip"):
            self.assertIn(name, names)
        self.assertEqual(len(names), len(set(names)))
        for group in ("state", "integration", "presentation"):
            self.assertIn(f"[{group}]", output)
        for name, bundle in calls:
            # Only the VFX and player-head visual entry points execute the VFX harness.
            self.assertEqual("\nvfxTests({" in bundle, name in {"vfx", "player-head-blender-visual"})

    def test_failed_suite_does_not_stop_group_and_returns_failure(self):
        code, calls, output = self.run_runner("--group", "presentation", fail_first=True)
        self.assertEqual(code, 1)
        self.assertGreater(len(calls), 1)
        self.assertIn(f"FAIL {calls[0][0]}", output)
        self.assertIn("PASS stash-presentation", output)

    def test_state_group_does_not_execute_integration_or_presentation(self):
        code, calls, _ = self.run_runner("--group", "state")
        self.assertEqual(code, 0)
        tree = ast.parse(RUNNER.read_text(encoding="utf-8"))
        manifest = next(ast.literal_eval(node.value) for node in tree.body
                        if isinstance(node, ast.Assign) and any(
                            isinstance(target, ast.Name) and target.id == "SUITES" for target in node.targets))
        self.assertEqual({name for name, _ in calls},
                         {name for name, (group, _) in manifest.items() if group == "state"})
        self.assertIn("tutorial", {name for name, _ in calls})
        self.assertNotIn("tutorial-gameplay", {name for name, _ in calls})

    def test_named_session_suites_are_independently_selectable(self):
        code, calls, _ = self.run_runner("--suite", "plot-session", "--suite", "plot-session-races", "--suite", "plot-session-progression", "--suite", "plot-session-requests")
        self.assertEqual(code, 0)
        self.assertEqual([name for name, _ in calls], ["plot-session", "plot-session-races", "plot-session-progression", "plot-session-requests"])

    def test_focused_smoothie_keeps_flow_and_geometry_coverage(self):
        code, calls, _ = self.run_runner("--smoothie-only")
        self.assertEqual(code, 0)
        self.assertEqual(
            {name for name, _ in calls},
            {"smoothie-world", "smoothie", "smoothie-dispense", "smoothie-roundtrip", "smoothie-survivors", "smoothie-geometry"},
        )

    def test_duplicate_registration_is_rejected_before_listing_or_execution(self):
        source = RUNNER.read_text(encoding="utf-8")
        for name in ("tutorial-claim", "tutorial-gameplay"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, f"Duplicate suite registration: {name}"):
                self.run_runner("--list", registry_source=source.replace(
                    "SUITES = {", f'SUITES = {{\n    "{name}": ("integration", ()),', 1))

    def test_tutorial_bundles_include_both_merged_fixture_contracts(self):
        code, calls, _ = self.run_runner("--suite", "tutorial-claim", "--suite", "tutorial-gameplay")
        self.assertEqual(code, 0)
        for name, bundle in calls:
            self.assertIn("local storedStashes = {}", bundle)
            if name == "tutorial-gameplay":
                self.assertIn('caseohTemplate:SetAttribute("CustomerId", "caseoh")', bundle)

    def test_missing_manifest_file_is_rejected_even_when_unselected(self):
        with self.assertRaises(FileNotFoundError):
            self.run_runner("--list", "--suite", "tutorial", missing_file="cash_boost.spec.luau")


if __name__ == "__main__":
    unittest.main()
