"""LockBase contracts, with gameplay/integration independent of presentation."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
parser.add_argument("--group", choices=("integration", "presentation", "visibility"))
args = parser.parse_args()
sources = {}
for directory in ("src/server/Services", "src/shared", "src/shared/Constants", "src/client/Controllers"):
    for path in (ROOT / directory).glob("*.luau"):
        sources[path.stem] = path.read_text(encoding="utf-8")
prefix = "local sources = " + "{" + ",".join(
    f"[{json.dumps(name)}]={json.dumps(source, ensure_ascii=False)}" for name, source in sources.items()
) + "}\n"
groups = {
    "integration": ("fixtures/roblox.luau", "fixtures/smoothie.luau", "fixtures/lock_base.luau", "lock_base.spec.luau"),
    "runtime-integration": ("fixtures/roblox.luau", "fixtures/smoothie.luau", "fixtures/lock_base.luau", "lock_base_runtime.spec.luau"),
    "visibility": ("fixtures/roblox.luau", "fixtures/lock_base.luau", "lock_base_visibility.spec.luau"),
    "presentation": ("fixtures/roblox.luau", "fixtures/lock_base.luau", "lock_base_presentation.spec.luau"),
}
results = []
with tempfile.TemporaryDirectory(prefix="blender-lock-base-") as directory:
    for group, files in groups.items():
        if args.group and args.group != group and not (args.group == "integration" and group == "runtime-integration"):
            continue
        path = Path(directory) / f"{group}.luau"
        path.write_text(prefix + "\n".join((ROOT / "tests" / file).read_text(encoding="utf-8") for file in files), encoding="utf-8")
        result = subprocess.run([args.luau, str(path)], cwd=ROOT, check=False)
        results.append(result.returncode == 0)
        print(f"[{group}] {'PASS' if result.returncode == 0 else 'FAIL'}", flush=True)
raise SystemExit(0 if all(results) else 1)
