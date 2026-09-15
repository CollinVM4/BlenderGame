"""Exercise smoothie pickup prompt modules using the shared mocked Roblox boundary."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = list((root / "src/client/UI").glob("*Prompt*.luau"))
paths += [root / path for path in (
    "src/client/UI/WorldBillboardStyle.luau",
    "src/client/Controllers/IngredientPickupPromptController.luau",
    "src/client/Controllers/SmoothiePickupPromptController.luau",
    "src/shared/Constants/Ingredients.luau",
    "src/server/Components/IngredientPickup.luau",
)]
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(path.stem)}] = {json.dumps(path.read_text())}," for path in paths
) + "\n}\n"
bundle += (root / "tests/fixtures/roblox.luau").read_text()
bundle += (root / "tests/interaction_prompt.spec.luau").read_text().split("local function module", 1)[0]
bundle += (root / "tests/ingredient_prompt.spec.luau").read_text().split("local controller = load", 1)[0]
bundle += (root / "tests/smoothie_prompt.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="smoothie-prompt-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)

