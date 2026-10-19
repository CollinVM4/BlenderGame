"""Shared world UI contracts and repo-wide billboard sizing lint."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from check_billboard_convention import ROOT, check, violations

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
assert violations('local gui = Instance.new("BillboardGui")\ngui.Size = UDim2.fromOffset(300, 56)')
assert violations('local gui = Instance.new("BillboardGui")\nlocal alias = gui\nalias.Size, alias.MaxDistance = SIZE, 25')
assert violations('function apply(gui: BillboardGui)\ngui.Size = SIZE\nend')
assert violations('local gui = Instance.new("BillboardGui")\ngui.Size\n = UDim2.fromOffset(80, 80)')
assert not violations('local gui = Instance.new("BillboardGui")\nlocal text = gui:FindFirstChild("Text")\ntext.Size = UDim2.fromOffset(80, 80)')
assert not violations('local gui = Instance.new("BillboardGui")\nlocal text = Instance.new("TextLabel")\ntext.Size = UDim2.fromOffset(80, 80)')
errors = check()
if errors:
    raise SystemExit("\n".join(errors))
print("PASS: billboard convention lint and lint regressions", flush=True)
source = (ROOT / "src/shared/WorldBillboardStyle.luau").read_text()
bundle = "local sources = { WorldBillboardStyle = " + json.dumps(source) + " }\n"
bundle += (ROOT / "tests/fixtures/roblox.luau").read_text()
bundle += (ROOT / "tests/world_billboard_style.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="billboard-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT, check=False).returncode)
