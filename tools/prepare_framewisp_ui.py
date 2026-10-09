"""Apply the menu policy to a Framewisp export without rewriting its artwork XML.

Run after replacing Framewisp_CCWMF.rbxmx, before Rojo sync/build. Fail on an
unknown generated wiring contract rather than installing competing handlers.
"""
import argparse
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BEGIN = "-- BEGIN BLENDER MAIN MENUS"
END = "-- END BLENDER MAIN MENUS"


def prepare(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    tree = ET.fromstring(text)
    scripts = [item for item in tree.iter("Item")
               if item.attrib["class"] == "LocalScript"
               and item.findtext("./Properties/string[@name='Name']") == "FramewispActions"]
    if len(scripts) != 1:
        raise ValueError("Expected exactly one FramewispActions LocalScript")
    source = scripts[0].findtext("./Properties/ProtectedString[@name='Source']")
    source = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "", source, flags=re.S)
    hook = "\tif blenderMenus.Wire(btn) then return end\n"
    source = source.replace(hook, "")
    if source.count("local gui = script.Parent\n") != 1 or source.count("local function wire(btn)\n") != 1:
        raise ValueError("Framewisp action wiring changed; review before applying menu policy")
    block = (BEGIN + '\nlocal player = game:GetService("Players").LocalPlayer\n'
             + 'local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")\n'
             + 'local menus = require(client:WaitForChild("UI"):WaitForChild("FramewispMenus"))\n'
             + 'local blenderMenus = menus.Attach(gui, player)\n' + END + '\n')
    source = source.replace("local gui = script.Parent\n", "local gui = script.Parent\n" + block)
    source = source.replace("local function wire(btn)\n", "local function wire(btn)\n" + hook)
    # CDATA keeps generated Luau intact; only this LocalScript source changes.
    scripts_found = 0

    def replace_script(match):
        nonlocal scripts_found
        item = match.group(0)
        if '<string name="Name">FramewispActions</string>' not in item:
            return item
        scripts_found += 1
        return re.sub(r'<ProtectedString name="Source">.*?</ProtectedString>',
                      lambda _: '<ProtectedString name="Source"><![CDATA[' + source + ']]></ProtectedString>',
                      item, flags=re.S)

    text = re.sub(r'<Item class="LocalScript".*?</Item>', replace_script, text, flags=re.S)
    if scripts_found != 1:
        raise ValueError("Could not locate exact generated script XML")
    # Only direct main panel properties, never HUD descendants or artwork.
    parents = {child: parent for parent in tree.iter("Item") for child in parent.findall("Item")}
    panel_refs = set()
    for item in tree.iter("Item"):
        name = item.findtext("./Properties/string[@name='Name']", "")
        parent = parents.get(item)
        parent_name = parent.findtext("./Properties/string[@name='Name']", "") if parent is not None else ""
        if (item.attrib["class"] in ("Frame", "CanvasGroup") and name.removesuffix("_panel") in
                ("Settings", "Upgrades", "Shop", "Index", "Cosmetics") and parent_name in
                ("Be a Blender! Desktop", "Be a Blender! DesktopContent", "DesktopContent")):
            panel_refs.add(item.attrib["referent"])
    for ref in panel_refs:
        pattern = r'(<Item class="(?:Frame|CanvasGroup)" referent="' + re.escape(ref) + r'">\s*<Properties>)(.*?)(</Properties>)'
        text, count = re.subn(pattern, lambda m: m[1] + m[2].replace(
            '<bool name="Visible">true</bool>', '<bool name="Visible">false</bool>') + m[3], text, flags=re.S)
        if count != 1:
            raise ValueError("Could not locate exact panel properties")
    path.write_text(text, encoding="utf-8", newline="\n")
    print(f"Prepared {path.name}: {len(panel_refs)} existing main panel(s) default hidden")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", type=Path, default=ROOT / "Framewisp_CCWMF.rbxmx")
    prepare(parser.parse_args().path)

