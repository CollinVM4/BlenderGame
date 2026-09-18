"""Run the real visual-only modules against the repository's Roblox boundary."""
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
    "WorldTextController": "src/client/Controllers/WorldTextController.luau",
    "WorldBillboardStyle": "src/client/UI/WorldBillboardStyle.luau",
    "WorldTextPresentation": "src/client/UI/WorldTextPresentation.luau",
}
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text())},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (root / "tests/server_state.spec.luau").read_text().split("env.require = loadModule", 1)[0]
bundle += (root / "tests/world_text.spec.luau").read_text()
bundle += (root / "tests/world_text_controller.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="world-text-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)
