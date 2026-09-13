"""Exercise the real character service against the existing fake Roblox boundary."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
source = (root / 'src/server/Services/CharacterPhysicsService.luau').read_text(encoding='utf-8')
boundary = (root / 'tests/server_state.spec.luau').read_text(encoding='utf-8').split('env.require = loadModule', 1)[0]
spec = (root / 'tests/character_physics.spec.luau').read_text(encoding='utf-8')
bundle = 'local sources = {CharacterPhysicsService = ' + json.dumps(source) + '}\n' + boundary + spec
with tempfile.TemporaryDirectory(prefix='blender-character-tests-') as directory:
    path = Path(directory) / 'test.luau'
    path.write_text(bundle, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
