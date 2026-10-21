"""Settings presentation/contracts at a fake Roblox boundary; export names are real."""
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
    "UIRegistry": "src/client/UI/UIRegistry.luau",
    "SettingsGui": "src/client/UI/SettingsGui.luau",
    "MusicController": "src/client/Controllers/MusicController.luau",
    "SettingsController": "src/client/Controllers/SettingsController.luau",
    "MusicPresentation": "src/shared/Constants/MusicPresentation.luau",
}
nodes = []


def visit(item, parent):
    index = len(nodes) + 1
    def geometry(kind, name, fields):
        prop = item.find(f"./Properties/{kind}[@name='{name}']")
        return [float(prop.findtext(field, "0")) for field in fields] if prop is not None else []
    nodes.append([index, parent, item.attrib["class"], item.findtext("./Properties/string[@name='Name']"),
                  geometry("UDim2", "Position", ("XS", "XO", "YS", "YO")),
                  geometry("UDim2", "Size", ("XS", "XO", "YS", "YO")),
                  geometry("Vector2", "AnchorPoint", ("X", "Y"))])
    for child in item.findall("Item"):
        visit(child, index)


for item in ET.parse(root / "Framewisp_CCWMF.rbxmx").getroot().findall("Item"):
    visit(item, 0)
def lua(value):
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    return json.dumps(value)


bundle = "local exportNodes = {\n" + "\n".join(
    lua(node) + "," for node in nodes
) + "\n}\nlocal sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text(encoding='utf-8'))},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (root / "tests/fixtures/settings_ui.luau").read_text()
bundle += (root / "tests/settings.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="blender-settings-") as directory:
    path = Path(directory) / "settings.luau"
    path.write_text(bundle, encoding="utf-8")
    subprocess.run([args.luau, str(path)], cwd=root, check=True)
