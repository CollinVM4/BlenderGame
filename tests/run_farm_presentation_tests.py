"""Farm client presentation, separate from authoritative farm integration."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = [root / path for path in (
    "src/client/Controllers/FarmPresentationController.luau",
    "src/client/UI/WorldBillboardStyle.luau",
    "src/shared/MobilePromptDebug.luau",
    "src/client/UI/MobilePromptTouchTargets.luau",
    "src/client/UI/InteractionPromptPresentation.luau",
    "src/shared/Constants/DialogueTextStyle.luau",
    "src/shared/Constants/FarmConfig.luau",
    "src/shared/Constants/Ingredients.luau",
)]
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(path.stem)}] = {json.dumps(path.read_text())}," for path in paths
) + "\n}\n"
bundle += (root / "tests/fixtures/roblox.luau").read_text()
bundle += (root / "tests/interaction_prompt.spec.luau").read_text().split("local function module", 1)[0]
bundle += (root / "tests/farm_presentation.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="farm-presentation-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)
