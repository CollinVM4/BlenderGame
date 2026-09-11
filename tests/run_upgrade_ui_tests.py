"""Exercise real upgrade display/controller modules at a fake Roblox boundary."""
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
    "SprintConfig": "src/shared/Constants/SprintConfig.luau",
    "UpgradeDisplay": "src/client/UI/UpgradeDisplay.luau",
    "Controller": "src/client/Controllers/UpgradesController.luau",
}
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text(encoding='utf-8'), ensure_ascii=False)},"
    for name, path in paths.items()
) + "\n}\n" + (root / "tests/upgrade_ui.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-upgrade-ui-") as directory:
    path = Path(directory) / "tests.luau"
    path.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
