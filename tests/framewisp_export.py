"""Load the Rojo-mounted prepared export and enforce shipped binding contracts."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def load_prepared_export(section=None):
    project = json.loads((ROOT / "default.project.json").read_text())
    path = ROOT / project["tree"]["StarterGui"]["Framewisp_CCVVMF"]["$path"]
    if not path.is_file():
        raise SystemExit(f"Prepared export missing: {path}. Run python tools/prepare_framewisp_ui.py --input export116.rbxmx --output Framewisp_Hotbar.prepared.rbxmx first.")
    tree = ET.parse(path)
    if section is None:
        return tree

    def name(item):
        return item.findtext("./Properties/string[@name='Name']", "")

    def child(parent, wanted, classes=None):
        matches = [item for item in parent.findall("Item") if name(item) == wanted]
        assert len(matches) == 1, f"{section}: expected one {wanted} under {name(parent)}"
        result = matches[0]
        assert classes is None or result.attrib["class"] in classes, f"{section}: wrong class for {wanted}"
        return result

    desktops = [item for item in tree.iter("Item") if name(item) == "Be a Blender! Desktop"]
    assert len(desktops) == 1, "expected one shipped desktop"
    desktop = desktops[0]
    if section == "Hotbar":
        bar = child(desktop, "Hotbar")
        slots = [item for item in bar.findall("Item") if name(item) == "Slot1"]
        assert len(slots) == 9, "shipped Hotbar must contain nine direct Slot1 buttons"
        for slot in slots:
            assert slot.attrib["class"] in ("TextButton", "ImageButton")
            child(slot, "Label", {"TextLabel", "TextButton", "TextBox"})
            child(slot, "SlotIcon", {"ImageLabel"})
            child(slot, "Slot1Background", {"ImageLabel"})
    elif section == "Settings":
        panel = child(desktop, "Settings")
        plot = child(child(panel, "PLOT"), "PLOTContent")
        music = child(child(panel, "MUSIC"), "MUSICContent")
        for control in ("Open", "Friends", "Locked", "Rename", "Kick"):
            child(plot, control, {"TextButton", "ImageButton"})
        for control in ("MusicOn", "MusicOff"):
            child(music, control, {"TextButton", "ImageButton"})
        child(child(music, "Slider"), "SliderBackground", {"ImageLabel"})
    elif section == "Upgrades":
        cards = child(child(child(desktop, "Upgrades"), "UpgradeScroll"), "UpgradeList")
        for name_ in ("JumpCard", "BatCard", "MovementSpeedCard", "CarryCapacityCard", "SprintStaminaCard"):
            content = child(child(cards, name_), name_ + "Content", {"Frame", "CanvasGroup"})
            child(content, "Buy", {"TextButton", "ImageButton"})
    else:
        raise ValueError(section)
    return tree
