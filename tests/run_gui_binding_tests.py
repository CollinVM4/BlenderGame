"""Focused claim GUI fan-out and binding lifecycle contracts (CLI engine doubles)."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = {
    **{name: f"src/client/Controllers/{name}.luau" for name in (
        "TasksController", "WingsShopAdapter", "CashBoostShopAdapter", "IceGunShopAdapter",
    )},
    **{name: f"src/client/UI/{name}.luau" for name in ("UIRegistry", "TasksGui")},
    **{name: f"src/shared/Constants/{name}.luau" for name in ("WingsConfig", "IceGunConfig", "ShopProducts")},
    "MoneyFormat": "src/shared/MoneyFormat.luau",
}
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((ROOT / path).read_text(encoding='utf-8'))},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (ROOT / "tests/fixtures/roblox.luau").read_text(encoding="utf-8")
spec = (ROOT / "tests/gui_binding.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="claim-gui-binding-") as directory:
    for mode in ("startup", "late"):
        target = Path(directory) / f"{mode}.luau"
        target.write_text(bundle + f"\nlocal bindingMode = {json.dumps(mode)}\n" + spec, encoding="utf-8")
        subprocess.run([args.luau, str(target)], cwd=ROOT, check=True)
