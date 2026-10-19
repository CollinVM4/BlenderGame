"""Independent FilmCam presentation/math contracts, using real unmodified sources."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
paths = {
    "FilmCamPath": "src/shared/FilmCamPath.luau",
    "FilmCam": "src/shared/Constants/FilmCam.luau",
    "FilmCamTakes": "src/client/UI/FilmCamTakes.luau",
    "FilmCamController": "src/client/Controllers/FilmCamController.luau",
    "FilmCamPanel": "src/client/UI/FilmCamPanel.luau",
}
bundle = "local sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps((ROOT / path).read_text(encoding='utf-8'))},"
    for name, path in paths.items()
) + "\n}\n"
bundle += (ROOT / "tests/fixtures/roblox.luau").read_text(encoding="utf-8")
bundle += (ROOT / "tests/filmcam.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="filmcam-tests-") as directory:
    output = Path(directory) / "tests.luau"
    output.write_text(bundle, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(output)], cwd=ROOT, check=False).returncode)
