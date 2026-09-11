"""Exercise the presentation component using the existing fake Roblox boundary."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
sources = {
    "Economy": (ROOT / "src/shared/Constants/Economy.luau").read_text(),
    "BlenderStatusPresentation": (ROOT / "src/server/Components/BlenderStatusPresentation.luau").read_text(),
    "BlenderStatusDistanceController": (ROOT / "src/client/Controllers/BlenderStatusDistanceController.luau").read_text(),
}
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps(source)}," for name, source in sources.items()
) + "\n}\n"
bundle += (ROOT / "tests/server_state.spec.luau").read_text().split("env.require = loadModule", 1)[0]
bundle += "env.require = loadModule\n"
bundle += (ROOT / "tests/blender_status.spec.luau").read_text()
bundle += "\n" + (ROOT / "tests/blender_status_distance.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="blender-status-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT, check=False).returncode)
