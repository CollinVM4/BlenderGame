"""Run real service modules in Luau CLI with a small fake Roblox boundary.

Usage: python tests/run_state_tests.py --luau /path/to/luau
These are domain tests, not a replacement for Studio physics/network playtests.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
sources = {}
for directory in ("src/shared/Constants", "src/server/Services"):
    for path in (ROOT / directory).glob("*.luau"):
        sources[path.stem] = path.read_text(encoding="utf-8")
sources["Types"] = (ROOT / "src/shared/Types.luau").read_text(encoding="utf-8")
sources["BlenderInputComponent"] = (ROOT / "src/server/Components/BlenderInput.luau").read_text(encoding="utf-8")
sources["GameplayPresentationController"] = (ROOT / "src/client/Controllers/GameplayPresentationController.luau").read_text(encoding="utf-8")
sources["ClientBootstrap"] = (ROOT / "src/client/init.client.luau").read_text(encoding="utf-8")
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps(source)}," for name, source in sources.items()
) + "\n}\n"
bundle += (ROOT / "tests/server_state.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-state-tests-") as directory:
    output = Path(directory) / "state-tests.luau"
    output.write_text(bundle, encoding="utf-8")
    result = subprocess.run([args.luau, str(output)], cwd=ROOT, check=False)
    raise SystemExit(result.returncode)
