"""Focused Scrapbook presentation/controller contracts; no Studio layout simulation."""
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
    "IngredientPickupPromptStyle": "src/client/UI/IngredientPickupPromptStyle.luau",
    "IngredientViewport": "src/client/UI/IngredientViewport.luau",
    "IngredientPreviewGeometry": "src/shared/IngredientPreviewGeometry.luau",
    "ScrapbookPreviews": "src/shared/Constants/ScrapbookPreviews.luau",
    "ScrapbookPreviewAssets": "src/server/Services/ScrapbookPreviewAssets.luau",
    "UIRegistry": "src/client/UI/UIRegistry.luau",
    "FramewispMenus": "src/client/UI/FramewispMenus.luau",
    "PanelManager": "src/client/UI/PanelManager.luau",
    "BadCustomers": "src/shared/Constants/BadCustomers.luau",
    "Ingredients": "src/shared/Constants/Ingredients.luau",
    "CustomerRequests": "src/shared/Constants/CustomerRequests.luau",
    "DiscoveryCatalog": "src/shared/Constants/DiscoveryCatalog.luau",
    "ScrapbookArtwork": "src/shared/Constants/ScrapbookArtwork.luau",
    "MoneyFormat": "src/shared/MoneyFormat.luau",
    "ScrapbookPresentation": "src/client/UI/ScrapbookPresentation.luau",
    "ScrapbookController": "src/client/Controllers/ScrapbookController.luau",
}
items = []
def add(item, parent):
    index = len(items) + 1
    items.append((index, parent, item.attrib["class"], item.findtext("./Properties/string[@name='Name']")))
    for child in item.findall("Item"):
        add(child, index)
for item in ET.parse(root / "Framewisp_CCWMF.rbxmx").getroot().findall("Item"):
    add(item, 0)
tree = "local exportNodes = " + json.dumps(items).replace("[", "{").replace("]", "}") + "\n"
bundle = tree + "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text(encoding='utf-8'))},"
    for name, path in paths.items()
) + "\n}\n" + (root / "tests/scrapbook_ui.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-scrapbook-ui-") as directory:
    path = Path(directory) / "tests.luau"
    path.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
