"""Run real prompt presentation/controller against the existing Roblox boundary."""
import json
from pathlib import Path
import argparse
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = {
    "WorldBillboardStyle": "src/client/UI/WorldBillboardStyle.luau",
    "Presentation": "src/client/UI/InteractionPromptPresentation.luau",
    "Controller": "src/client/Controllers/InteractionPromptController.luau",
    "CustomerOrderController": "src/client/Controllers/CustomerOrderController.luau",
    "DispenseButton": "src/server/Components/DispenseButton.luau",
    "DayButton": "src/server/Components/DayButton.luau",
}
bundle = "local sources = " + "{\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text())},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (root / "tests/fixtures/roblox.luau").read_text()
bundle += (root / "tests/interaction_prompt.spec.luau").read_text()
bundle += "\n" + (root / "tests/customer_order_visibility.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="interaction-prompt-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)
