"""Mobile layout/input presentation contracts at a fake Roblox UI boundary."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
paths = {
    'MobileControlLayout': 'src/client/UI/MobileControlLayout.luau',
    'CarryInputController': 'src/client/Controllers/CarryInputController.luau',
    'SprintController': 'src/client/Controllers/SprintController.luau',
}
bundle = 'local sources = {\n' + '\n'.join(
    f'[{json.dumps(name)}] = {json.dumps((ROOT / path).read_text())},'
    for name, path in paths.items()
) + '\n}\n'
bundle += (ROOT / 'tests/mobile_control_layout.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='mobile-control-tests-') as directory:
    output = Path(directory) / 'tests.luau'
    output.write_text(bundle, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT, check=False).returncode)
