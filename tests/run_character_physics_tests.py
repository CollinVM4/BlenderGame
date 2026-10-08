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
sources = {
    name: (root / f'src/server/Services/{name}.luau').read_text(encoding='utf-8')
    for name in ('CharacterPhysicsService', 'PlayerOnlyCollisionService')
}
boundary = (root / 'tests/fixtures/roblox.luau').read_text(encoding='utf-8')
spec = (root / 'tests/character_physics.spec.luau').read_text(encoding='utf-8')
collision_spec = (root / 'tests/player_only_collision.spec.luau').read_text(encoding='utf-8')
source_table = ','.join(name + ' = ' + json.dumps(source) for name, source in sources.items())
bundle = 'local sources = {' + source_table + '}\n' + boundary + collision_spec + spec
with tempfile.TemporaryDirectory(prefix='blender-character-tests-') as directory:
    path = Path(directory) / 'test.luau'
    path.write_text(bundle, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
