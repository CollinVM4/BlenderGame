"""Run the actual Edit-mode utility and shared geometry with mocked Studio signals."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = list((root / "src/server/Services").glob("*.luau"))
paths += list((root / "src/shared/Constants").glob("*.luau"))
paths += [root / "src/server/Components/IngredientSpawn.luau",
          root / "docs/studio/IngredientSpawnPreview.luau"]
sources = {path.stem: path.read_text(encoding="utf-8") for path in paths}
bundle = "local sources = " + "{\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps(source)}," for name, source in sources.items()
) + "\n}\n"
bundle += (root / "tests/server_state.spec.luau").read_text().split("env.require = loadModule", 1)[0]
# Reuse the rotation-aware CFrame math used by carry regression tests.
bundle += (root / "tests/ingredient_carry.spec.luau").read_text().split("local function part", 1)[0]
bundle += (root / "tests/spawn_preview.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="spawn-preview-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=root, check=False).returncode)
