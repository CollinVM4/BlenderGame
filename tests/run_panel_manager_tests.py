"""Presentation-state contracts for major-menu exclusivity and yielded transitions."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
source = (root / "src/client/UI/PanelManager.luau").read_text(encoding="utf-8")
fixture = (root / "tests/panel_manager.spec.luau").read_text(encoding="utf-8")
with tempfile.TemporaryDirectory(prefix="blender-panel-manager-") as directory:
    path = Path(directory) / "tests.luau"
    path.write_text("local managerSource = " + json.dumps(source) + "\n" + fixture, encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(path)], cwd=root, check=False).returncode)
