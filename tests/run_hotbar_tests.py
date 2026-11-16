"""Run the standalone hotbar/controller with event-driven Roblox UI doubles."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from framewisp_export import load_prepared_export

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(__doc__)
parser.add_argument("--luau", default="luau")
parser.add_argument(
    "--case",
    choices=("all", "startup", "input", "lifecycle", "overflow", "fallback", "discovery", "diagnostic"),
    default="all",
)
parser.add_argument(
    "--source-root", type=Path, default=ROOT,
    help="Production source snapshot; tests stay in this checkout",
)
args = parser.parse_args()
paths = {
    "HotbarGui": "src/client/UI/HotbarGui.luau",
    "MobileControlLayout": "src/client/UI/MobileControlLayout.luau",
    "Controller": "src/client/Controllers/HotbarController.luau",
    "IceGunService": "src/server/Services/IceGunService.luau",
    "IceGunConfig": "src/shared/Constants/IceGunConfig.luau",
    "StudioIceGunEntitlement": "src/server/Services/StudioIceGunEntitlement.luau",
}
# Recreate the mapped template's class/name hierarchy and boolean properties at
# the engine boundary. Geometry/serialization/replication still require Studio.
project = json.loads((args.source_root / "default.project.json").read_text())
template_path = project["tree"]["ServerStorage"]["Weapons"]["IcicleGun"]["$path"]
template = ET.parse(args.source_root / template_path).getroot().find("Item")
template_lines = ["local function iceGunTemplate(new, parent)"]


def emit_template(item, parent):
    variable = f"object{len(template_lines)}"
    name = item.findtext("./Properties/string[@name='Name']", item.attrib["class"])
    template_lines.append(
        f"local {variable} = new({json.dumps(item.attrib['class'])}, {json.dumps(name)}, {parent})"
    )
    for prop in item.findall("./Properties/bool"):
        template_lines.append(f"{variable}[{json.dumps(prop.attrib['name'])}] = {prop.text}")
    for child in item.findall("Item"):
        emit_template(child, variable)
    return variable


template_root = emit_template(template, "parent")
template_lines.extend([f"return {template_root}", "end"])
export_names = [item.findtext("./Properties/string[@name='Name']", "")
                for item in load_prepared_export("Hotbar").iter("Item")]
bundle = "local testCase = " + json.dumps(args.case) + "\nlocal exportNames = {" + ",".join(
    json.dumps(name) for name in export_names
) + "}\nlocal sources = {\n" + "\n".join(
    f"[{json.dumps(key)}] = {json.dumps((args.source_root / path).read_text())},"
    for key, path in paths.items()
) + "\n}\n" + "\n".join(template_lines) + "\n" + (ROOT / "tests/hotbar.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="blender-hotbar-test-") as directory:
    output = Path(directory) / "hotbar.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT).returncode)
