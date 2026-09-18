"""Exercise vacuum, registration, plot references and ingestion with a fake engine boundary."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
sources = {}
for directory in ('src/shared/Constants', 'src/server/Services'):
    for path in (root / directory).glob('*.luau'):
        sources[path.stem] = path.read_text(encoding='utf-8')
for name in ('BlenderVacuum', 'BlenderInput'):
    sources[name + 'Component'] = (root / 'src/server/Components' / (name + '.luau')).read_text(encoding='utf-8')
sources['Types'] = (root / 'src/shared/Types.luau').read_text(encoding='utf-8')
boundary = (root / 'tests/server_state.spec.luau').read_text(encoding='utf-8').split('env.require = loadModule', 1)[0]
spec = (root / 'tests/blender_vacuum.spec.luau').read_text(encoding='utf-8')
bundle = 'local sources = ' + '{\n' + '\n'.join(
    f'[{json.dumps(name)}] = {json.dumps(source)},' for name, source in sources.items()
) + '\n}\n' + boundary + spec
with tempfile.TemporaryDirectory(prefix='blender-vacuum-tests-') as directory:
    path = Path(directory) / 'test.luau'
    path.write_text(bundle, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
