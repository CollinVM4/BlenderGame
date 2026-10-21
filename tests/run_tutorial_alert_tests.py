"""Pure tutorial alert model contracts; no UI or gameplay fixture required."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = {
    "Upgrades": "src/shared/Constants/Upgrades.luau",
    "TutorialAlertState": "src/client/Controllers/TutorialAlertState.luau",
}
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text(encoding='utf-8'))},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (root / "tests/tutorial_alert_state.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="tutorial-alert-tests-") as directory:
    path = Path(directory) / "tests.luau"
    path.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
