"""Execute the prepared FramewispActions source at a fake Roblox boundary."""
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
tree = ET.parse(root / "Framewisp_CCWMF.rbxmx").getroot()
actions = next(i for i in tree.iter("Item") if i.attrib["class"] == "LocalScript"
               and i.findtext("./Properties/string[@name='Name']") == "FramewispActions")
source = actions.findtext("./Properties/ProtectedString[@name='Source']")
module = (root / "src/client/UI/FramewispMenus.luau").read_text(encoding="utf-8")
assert module in source, "Run tools/prepare_framewisp_ui.py after editing the policy or reimporting"
parents = {child: parent for parent in tree.iter("Item") for child in parent.findall("Item")}
for i, parent in parents.items():
    name = i.findtext("./Properties/string[@name='Name']", "").removesuffix("_panel")
    if i.attrib["class"] == "Frame" and name in ("Settings", "Upgrades", "Shop", "Index"):
        if parent.findtext("./Properties/string[@name='Name']") in (
                "Be a Blender! Desktop", "Be a Blender! DesktopContent"):
            assert i.findtext("./Properties/bool[@name='Visible']") == "false", name
fixture = (root / "tests/framewisp_menus.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-menu-tests-") as directory:
    test = Path(directory) / "menus.luau"
    test.write_text("local actionSource = " + json.dumps(source) + "\n" + fixture, encoding="utf-8")
    subprocess.run([args.luau, str(test)], cwd=root, check=True)
