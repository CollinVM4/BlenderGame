"""Run real prompt presentation/controller against the existing Roblox boundary."""
import json
from pathlib import Path
import argparse
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
parser.add_argument("--customer-only", action="store_true", help="Shared prompt core and customer presentation without legacy Start Day")
parser.add_argument("--view-only", action="store_true", help="Shared prompt input and visual presentation without gameplay adapters")
args = parser.parse_args()
paths = {
    "DialogueTextStyle": "src/shared/Constants/DialogueTextStyle.luau",
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
prompt_spec = (root / "tests/interaction_prompt.spec.luau").read_text()
if args.view_only:
    bundle += prompt_spec.split("local attach, serverPrompt", 1)[0]
    bundle += '\nprint(string.format("PASS: %d prompt presentation assertions.", count))\n'
else:
    bundle += prompt_spec.split("-- Start Day uses", 1)[0] if args.customer_only else prompt_spec
    bundle += "\n" + (root / "tests/customer_order_visibility.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="interaction-prompt-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)
