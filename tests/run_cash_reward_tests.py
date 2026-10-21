"""Presentation-only cash event, Framewisp destination and animation contracts."""
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
    "MoneyFormat": "src/shared/MoneyFormat.luau",
    "CashTicker": "src/client/UI/CashTicker.luau",
    "CashTickerModel": "src/client/UI/CashTickerModel.luau",
    "CashFeedback": "src/shared/Constants/CashFeedback.luau",
    "CashRewardState": "src/client/UI/CashRewardState.luau",
    "CashRewardDebug": "src/client/UI/CashRewardDebug.luau",
    "CashHud": "src/client/UI/CashHud.luau",
    "UIRegistry": "src/client/UI/UIRegistry.luau",
    "CashRewardAnimation": "src/client/UI/CashRewardAnimation.luau",
    "CashRewardController": "src/client/Controllers/CashRewardController.luau",
}
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((root / path).read_text())},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (root / "tests/fixtures/roblox.luau").read_text()
bundle += (root / "tests/cash_reward.spec.luau").read_text()
bundle += (root / "tests/cash_ticker.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="cash-reward-tests-") as directory:
    path = Path(directory) / "tests.luau"
    path.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
