"""Exercise real upgrade display/controller modules at a fake Roblox boundary."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = {
    "Upgrades": "src/shared/Constants/Upgrades.luau",
    "MoneyFormat": "src/shared/MoneyFormat.luau",
    "UpgradesGui": "src/client/UI/UpgradesGui.luau",
    "UpgradeDisplay": "src/client/UI/UpgradeDisplay.luau",
    "Controller": "src/client/Controllers/UpgradesController.luau",
}
# Build the UI boundary from the actual export, so path/class drift fails tests.
items = []
def add_item(item, parent):
    index = len(items) + 1
    name = item.find("./Properties/string[@name='Name']").text
    items.append((index, parent, item.attrib["class"], name))
    for child in item.findall("Item"):
        add_item(child, index)
for item in ET.parse(root / "Framewisp_CCWMF.rbxmx").getroot().findall("Item"):
    add_item(item, 0)
tree = "local exportNodes = {\n" + "\n".join(
    "{" + f"{i}, {parent}, {json.dumps(cls)}, {json.dumps(name)}" + "},"
    for i, parent, cls, name in items
) + "\n}\n"
bundle = tree + "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text(encoding='utf-8'), ensure_ascii=False)},"
    for name, path in paths.items()
) + "\n}\n" + (root / "tests/upgrade_ui.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-upgrade-ui-") as directory:
    path = Path(directory) / "tests.luau"
    for initial_ui in (False, True):
        print(f"UI present before Init: {initial_ui}", flush=True)
        path.write_text(f"local initialUi = {str(initial_ui).lower()}\n" + bundle, encoding="utf-8")
        result = subprocess.run([args.luau, str(path)], cwd=root, check=False)
        if result.returncode:
            raise SystemExit(result.returncode)
