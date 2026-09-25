"""Focused client camera presentation contracts; no gameplay suite dependency."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
source = (ROOT / "src/client/Controllers/TurbineCameraController.luau").read_text(encoding="utf-8")
bundle = "local sources = { TurbineCameraController = " + json.dumps(source) + " }\n"
bundle += (ROOT / "tests/fixtures/roblox.luau").read_text(encoding="utf-8")
bundle += (ROOT / "tests/turbine_camera.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="turbine-camera-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT, check=False).returncode)
