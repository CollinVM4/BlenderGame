"""Focused Scrapbook presentation/controller contracts; no Studio layout simulation."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = {
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
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text(encoding='utf-8'))},"
    for name, path in paths.items()
) + "\n}\n" + (root / "tests/scrapbook_ui.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-scrapbook-ui-") as directory:
    path = Path(directory) / "tests.luau"
    path.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
