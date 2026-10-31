"""Run the real hotbar resolver/controller against an event-driven Roblox double."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(__doc__)
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = {
    "UIRegistry": "src/client/UI/UIRegistry.luau",
    "HotbarGui": "src/client/UI/HotbarGui.luau",
    "UpgradesGui": "src/client/UI/UpgradesGui.luau",
    "Controller": "src/client/Controllers/HotbarController.luau",
}
nodes = []


def add(item, parent):
    index = len(nodes) + 1
    nodes.append([index, parent, item.attrib["class"],
                  item.findtext("./Properties/string[@name='Name']", "")])
    for child in item.findall("Item"):
        add(child, index)


for item in ET.parse(ROOT / "Framewisp_Hotbar.prepared.rbxmx").getroot().findall("Item"):
    add(item, 0)
bundle = "local exportNodes = {\n" + "\n".join(
    "{" + ",".join(json.dumps(v) for v in node) + "}," for node in nodes
) + "\n}\nlocal sources = {\n" + "\n".join(
    f"[{json.dumps(key)}] = {json.dumps((ROOT / path).read_text())},"
    for key, path in paths.items()
) + "\n}\n" + (ROOT / "tests/hotbar.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="blender-hotbar-test-") as directory:
    output = Path(directory) / "hotbar.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT).returncode)
