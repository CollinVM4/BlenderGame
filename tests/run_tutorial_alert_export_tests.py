"""Resolve tutorial arrows from the real Framewisp 103026 export."""
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
    "UpgradesGui": "src/client/UI/UpgradesGui.luau",
    "Upgrades": "src/shared/Constants/Upgrades.luau",
    "TutorialAlertState": "src/client/Controllers/TutorialAlertState.luau",
}
nodes = []


def visit(item, parent):
    index = len(nodes) + 1
    nodes.append((index, parent, item.attrib["class"],
                  item.findtext("./Properties/string[@name='Name']"),
                  item.findtext("./Properties/bool[@name='Visible']", "true") == "true"))
    for child in item.findall("Item"):
        visit(child, index)


for item in ET.parse(root / "uiExport_103026.rbxmx").getroot().findall("Item"):
    visit(item, 0)
bundle = "local exportNodes = {\n" + "\n".join(
    "{" + ",".join(json.dumps(value) for value in node) + "},"
    for node in nodes
) + "\n}\nlocal sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text(encoding='utf-8'))},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (root / "tests/fixtures/settings_ui.luau").read_text(encoding="utf-8")
bundle += (root / "tests/tutorial_alert_export.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="tutorial-alert-export-") as directory:
    path = Path(directory) / "export.luau"
    path.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
