"""Exercise real ingredient prompt modules using the shared mocked Roblox boundary."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
parser.add_argument("--player-head-only", action="store_true", help="Run focused head name presentation")
args = parser.parse_args()
paths = list((root / "src/client/UI").glob("*Prompt*.luau"))
paths += [root / path for path in (
    "src/client/UI/WorldBillboardStyle.luau",
    "src/client/Controllers/IngredientPickupPromptController.luau",
    "src/shared/Constants/Ingredients.luau",
    "src/shared/MoneyFormat.luau",
    "src/shared/IngredientName.luau",
    "src/shared/Constants/DialogueTextStyle.luau",
    "src/server/Components/IngredientPickup.luau",
)]
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(path.stem)}] = {json.dumps(path.read_text(), ensure_ascii=False)}," for path in paths
) + "\n}\n"
bundle += (root / "tests/fixtures/roblox.luau").read_text()
bundle += (root / "tests/interaction_prompt.spec.luau").read_text().split("local function module", 1)[0]
bundle += (root / "tests/ingredient_prompt.spec.luau").read_text() if not args.player_head_only else (root / "tests/player_head_presentation.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="ingredient-prompt-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)
