"""Focused floor indicator/light presentation contracts; no gameplay suite dependency."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = [
    "src/shared/Constants/Economy.luau",
    "src/server/Services/WorldUtil.luau",
    "src/server/Components/BlenderReadyIndicator.luau",
    "src/server/Components/BlendProgressLights.luau",
]
sources = {Path(path).stem: (ROOT / path).read_text(encoding="utf-8") for path in paths}
bundle = "local sources = " + "{\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps(source)}," for name, source in sources.items()
) + "\n}\n"
bundle += (ROOT / "tests/fixtures/roblox.luau").read_text(encoding="utf-8")
bundle += (ROOT / "tests/blender_ready_indicator.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-ready-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT, check=False).returncode)
