"""Mobile-only prompt contracts; separate from authoritative inventory tests."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = list((root / "src/client/UI").glob("*Prompt*.luau"))
paths += [root / path for path in (
    "src/client/UI/WorldBillboardStyle.luau",
    "src/shared/MobilePromptDebug.luau",
    "src/client/Controllers/IngredientPickupPromptController.luau",
    "src/client/Controllers/InteractionPromptController.luau",
    "src/client/Controllers/CarryInputController.luau",
    "src/shared/Constants/Ingredients.luau",
    "src/shared/MoneyFormat.luau",
    "src/shared/IngredientName.luau",
    "src/shared/Constants/DialogueTextStyle.luau",
    "src/server/Components/IngredientPickup.luau",
    "src/server/Components/DispenseButton.luau",
)]
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(path.stem)}] = {json.dumps(path.read_text(), ensure_ascii=False)}," for path in paths
) + "\n}\n"
bundle += (root / "tests/fixtures/roblox.luau").read_text()
bundle += (root / "tests/interaction_prompt.spec.luau").read_text().split("local function module", 1)[0]
setup = (root / "tests/ingredient_prompt.spec.luau").read_text().split("local controller = load", 1)[0]
setup = setup.split("for id, definition in definitions do", 1)[0] + "local style = load" + setup.split("local style = load", 1)[1]
bundle += setup
bundle += (root / "tests/mobile_prompt.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="mobile-prompt-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)
