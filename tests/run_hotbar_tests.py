"""Run the real hotbar resolver/controller against an event-driven Roblox double."""
import argparse
import base64
import json
from pathlib import Path
import subprocess
import struct
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(__doc__)
parser.add_argument("--luau", default="luau")
parser.add_argument("--case", choices=("all", "aspect", "template", "dock-portrait", "dock-landscape", "docking"), default="all")
args = parser.parse_args()
paths = {
    "UIRegistry": "src/client/UI/UIRegistry.luau",
    "HotbarGui": "src/client/UI/HotbarGui.luau",
    "UpgradesGui": "src/client/UI/UpgradesGui.luau",
    "Controller": "src/client/Controllers/HotbarController.luau",
}
nodes = []


def attributes(item):
    """Read the simple design/text attributes needed by the fake engine."""
    encoded = item.findtext("./Properties/BinaryString[@name='AttributesSerialize']", "")
    if not encoded.strip():
        return {}
    data = base64.b64decode(encoded)
    result = {}
    # These exact serialized keys carry numbers in this export. Leave unrelated
    # generated attributes out of the fake boundary rather than interpreting them.
    for key in ("BB_DesignW", "BB_DesignH", "FigmaFontSize", "HotbarTextMin", "HotbarTextMax"):
        marker = struct.pack("<I", len(key)) + key.encode() + b"\x06"
        offset = data.find(marker)
        if offset >= 0:
            result[key] = struct.unpack_from("<d", data, offset + len(marker))[0]
    return result


def add(item, parent):
    index = len(nodes) + 1
    properties = {}
    for prop in item.find("Properties"):
        key = prop.get("name")
        if prop.tag == "UDim2":
            properties[key] = [float(prop.findtext(k)) for k in ("XS", "XO", "YS", "YO")]
        elif key in ("Image", "Text", "TextSize", "TextScaled", "ScaleType", "AspectRatio"):
            properties[key] = "".join(prop.itertext()).strip()
    nodes.append([index, parent, item.attrib["class"],
                  item.findtext("./Properties/string[@name='Name']", ""), properties, attributes(item)])
    for child in item.findall("Item"):
        add(child, index)


project = json.loads((ROOT / "default.project.json").read_text())
export = ROOT / project["tree"]["StarterGui"]["Framewisp_CCVVMF"]["$path"]
for item in ET.parse(export).getroot().findall("Item"):
    add(item, 0)
def luau(value):
    if isinstance(value, dict):
        return "{" + ",".join(f"[{json.dumps(k)}]={luau(v)}" for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(luau(v) for v in value) + "}"
    return json.dumps(value)


bundle = "local testCase = " + json.dumps(args.case) + "\nlocal exportNodes = {\n" + "\n".join(
    luau(node) + "," for node in nodes
) + "\n}\nlocal sources = {\n" + "\n".join(
    f"[{json.dumps(key)}] = {json.dumps((ROOT / path).read_text())},"
    for key, path in paths.items()
) + "\n}\n" + (ROOT / "tests/hotbar.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="blender-hotbar-test-") as directory:
    output = Path(directory) / "hotbar.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT).returncode)
