"""Run the standalone hotbar/controller with event-driven Roblox UI doubles."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from framewisp_export import load_prepared_export

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(__doc__)
parser.add_argument("--luau", default="luau")
parser.add_argument("--case", choices=("all", "startup", "input", "lifecycle", "overflow", "fallback"), default="all")
args = parser.parse_args()
paths = {
    "HotbarGui": "src/client/UI/HotbarGui.luau",
    "MobileControlLayout": "src/client/UI/MobileControlLayout.luau",
    "Controller": "src/client/Controllers/HotbarController.luau",
}
export_names = [item.findtext("./Properties/string[@name='Name']", "")
                for item in load_prepared_export("Hotbar").iter("Item")]
bundle = "local testCase = " + json.dumps(args.case) + "\nlocal exportNames = {" + ",".join(
    json.dumps(name) for name in export_names
) + "}\nlocal sources = {\n" + "\n".join(
    f"[{json.dumps(key)}] = {json.dumps((ROOT / path).read_text())},"
    for key, path in paths.items()
) + "\n}\n" + (ROOT / "tests/hotbar.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="blender-hotbar-test-") as directory:
    output = Path(directory) / "hotbar.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT).returncode)
