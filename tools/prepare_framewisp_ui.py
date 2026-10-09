"""Apply the menu policy to a Framewisp export without rewriting its artwork XML.

Run before Rojo sync/build. The default command prepares Framewisp_CCWMF.rbxmx
in place; --input preserves the source and writes that Rojo-mapped asset. Fail on an
unknown generated wiring contract rather than installing competing handlers.
"""
import argparse
import base64
import sys
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BEGIN = "-- BEGIN BLENDER MAIN MENUS"
END = "-- END BLENDER MAIN MENUS"

DEFAULT_INPUT = ROOT / "Framewisp_CCWMF.rbxmx"
PANELS = ("Index", "Settings", "Shop", "Upgrades", "Cosmetics")
PERSISTENT = ("TOP", "LeftMenu", "RightMenu", "CashDisplay", "Cash", "{Coins}")
GUI_OBJECTS = {"Frame", "CanvasGroup", "ScrollingFrame", "ImageLabel", "ImageButton",
               "TextLabel", "TextButton", "TextBox", "ViewportFrame", "VideoFrame"}


def semantic(item):
    """Read BlenderUI without changing Roblox's serialized attributes.

    Attribute encoding follows rojo-rbx/rbx-dom rbx_types/src/attributes.
    Unknown/malformed encodings fail closed instead of falling back to names.
    """
    encoded = item.findtext("./Properties/BinaryString[@name='AttributesSerialize']", "")
    if not encoded.strip():
        return None
    data = base64.b64decode("".join(encoded.split()), validate=True)
    offset = 0

    def take(size):
        nonlocal offset
        if offset + size > len(data):
            raise ValueError("truncated AttributesSerialize")
        value = data[offset:offset + size]
        offset += size
        return value

    def integer():
        return int.from_bytes(take(4), "little")

    def string():
        return take(integer())

    result = None
    fixed = {3: 1, 4: 4, 5: 4, 6: 8, 9: 8, 10: 16, 14: 4,
             15: 12, 16: 8, 17: 12, 27: 8, 28: 16}
    for _ in range(integer()):
        key = string().decode("utf-8")
        kind = take(1)[0]
        if kind == 2:
            value = string()
            if key == "BlenderUI":
                result = value.decode("utf-8")
        elif kind in fixed:
            take(fixed[kind])
        elif kind == 20:  # CFrame position, compact rotation or full matrix
            take(12)
            if take(1)[0] == 0:
                take(36)
        elif kind == 21:  # EnumItem
            string()
            take(4)
        elif kind in (23, 25):  # NumberSequence / ColorSequence
            take(integer() * (12 if kind == 23 else 20))
        elif kind == 33:  # Font weight, style, family, cached face
            take(3)
            string()
            string()
        else:
            raise ValueError(f"unsupported attribute type {kind}")
    return result


def panel_referents(tree):
    """Mirror UIRegistry's semantic overrides and direct-child contracts."""
    items = list(tree.iter("Item"))
    roles = {}
    invalid = set()
    for item in items:
        try:
            roles[item] = semantic(item)
        except (ValueError, UnicodeError) as error:
            invalid.add(item)
            print(f"Warning: {item_name(item)!r}: cannot read BlenderUI: {error}; skipped", file=sys.stderr)

    def matches(item, role, names):
        return item not in invalid and (roles[item] == role if roles[item] is not None
                                       else item_name(item) in names)

    desktops = [item for item in items if matches(item, "Desktop", ("Be a Blender! Desktop",))]
    if len(desktops) != 1:
        print(f"Warning: expected one Desktop identifier, found {len(desktops)}; panel visibility unchanged", file=sys.stderr)
        return set()
    desktop = desktops[0]
    if desktop.attrib.get("class") not in GUI_OBJECTS | {"ScreenGui"}:
        print("Warning: unsupported Desktop class; panel visibility unchanged", file=sys.stderr)
        return set()
    wrappers = [item for item in desktop.findall("Item")
                if matches(item, "Content", ("Be a Blender! DesktopContent", "DesktopContent"))]
    if len(wrappers) > 1 or any(item in invalid for item in desktop.findall("Item")):
        print("Warning: ambiguous Content identifier; panel visibility unchanged", file=sys.stderr)
        return set()
    content = wrappers[0] if wrappers else desktop
    if wrappers and content.attrib.get("class") not in GUI_OBJECTS:
        print("Warning: unsupported Content class; panel visibility unchanged", file=sys.stderr)
        return set()
    if any(item in invalid for item in content.findall("Item")):
        print("Warning: unreadable panel identifiers; panel visibility unchanged", file=sys.stderr)
        return set()
    refs = set()
    for panel in PANELS:
        candidates = [item for item in content.findall("Item")
                      if matches(item, "Panel:" + panel, (panel, panel + "_panel"))]
        if not candidates and panel == "Cosmetics":
            continue  # Optional existing menu.
        if len(candidates) != 1:
            print(f"Warning: {panel}: {'missing' if not candidates else 'ambiguous'} panel identifier; skipped", file=sys.stderr)
            continue
        item = candidates[0]
        if (item.attrib.get("class") not in ("Frame", "CanvasGroup")
                or item_name(item).removesuffix("_panel") in PERSISTENT
                or roles[item] in PERSISTENT):
            print(f"Warning: {panel}: unsupported or persistent target; skipped", file=sys.stderr)
            continue
        refs.add(item.attrib["referent"])
    return refs


def item_name(item):
    return item.findtext("./Properties/string[@name='Name']", "")


def prepare(path: Path, output: Path | None = None) -> None:
    text = path.read_text(encoding="utf-8")
    tree = ET.fromstring(text)
    scripts = [item for item in tree.iter("Item")
               if item.attrib["class"] == "LocalScript"
               and item.findtext("./Properties/string[@name='Name']") == "FramewispActions"]
    if len(scripts) != 1:
        raise ValueError("Expected exactly one FramewispActions LocalScript")
    source = scripts[0].findtext("./Properties/ProtectedString[@name='Source']")
    if source is None:
        raise ValueError("FramewispActions is missing its Source property")
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
    # CDATA keeps generated Luau intact while replacing its delegation hook.
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
    # Only unambiguous registered panels, never HUD/navigation descendants.
    panel_refs = panel_referents(tree)
    for ref in panel_refs:
        pattern = (r'(<Item\b(?=[^>]*\bclass="(?:Frame|CanvasGroup)")'
                   r'(?=[^>]*\breferent="' + re.escape(ref) + r'")[^>]*>\s*<Properties>)(.*?)(</Properties>)')

        def hide(match):
            properties, count = re.subn(r'<bool\s+name="Visible">\s*(?:true|false)\s*</bool>',
                                         '<bool name="Visible">false</bool>', match[2])
            if count == 0:
                properties += '<bool name="Visible">false</bool>'
            elif count != 1:
                raise ValueError("Duplicate panel Visible property")
            return match[1] + properties + match[3]

        text, count = re.subn(pattern, hide, text, flags=re.S)
        if count != 1:
            raise ValueError("Could not locate exact panel properties")
    destination = output if output is not None else path
    destination.write_text(text, encoding="utf-8", newline="\n")
    print(f"Prepared {destination.resolve()}: {len(panel_refs)} existing main panel(s) default hidden")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", type=Path, help="Legacy in-place export path")
    parser.add_argument("--input", type=Path, help="Source export; defaults output to the Rojo-mapped asset")
    parser.add_argument("--output", type=Path, help="Prepared .rbxmx destination")
    args = parser.parse_args(argv)
    if args.path is not None and args.input is not None:
        parser.error("Use either the legacy positional path or --input")
    source = args.input if args.input is not None else (args.path or DEFAULT_INPUT)
    destination = args.output if args.output is not None else (DEFAULT_INPUT if args.input is not None else source)
    for label, path in (("Input", source), ("Output", destination)):
        if path.suffix.lower() != ".rbxmx":
            parser.error(f"{label} must use the .rbxmx XML format: {path}")
    if not source.is_file():
        parser.error(f"Input file does not exist: {source}")
    if args.input is not None and source.resolve() == destination.resolve():
        parser.error("--input must differ from output; use the legacy positional command for intentional in-place preparation")
    try:
        prepare(source, destination)
    except (OSError, ValueError, ET.ParseError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
