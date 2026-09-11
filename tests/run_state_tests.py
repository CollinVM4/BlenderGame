"""Run real service modules in Luau CLI with a small fake Roblox boundary.

Usage: python tests/run_state_tests.py --luau /path/to/luau
These are domain tests, not a replacement for Studio physics/network playtests.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
parser.add_argument("--vfx-only", action="store_true", help="Run only blender presentation integration checks")
parser.add_argument("--world-only", action="store_true", help="Run ingredient world/spawn regression checks")
parser.add_argument("--carry-only", action="store_true", help="Run overhead geometry and carry lifecycle checks")
parser.add_argument("--sprint-only", action="store_true", help="Run sprint network and stamina regression checks")
parser.add_argument("--customer-only", action="store_true", help="Run through customer request/serve integration checks")
args = parser.parse_args()
sources = {}
for directory in ("src/shared/Constants", "src/server/Services"):
    for path in (ROOT / directory).glob("*.luau"):
        sources[path.stem] = path.read_text(encoding="utf-8")
sources["StashPresentation"] = (ROOT / "src/server/Components/StashPresentation.luau").read_text(encoding="utf-8")
sources["BlendVFX"] = (ROOT / "src/server/Components/BlendVFX.luau").read_text(encoding="utf-8")
sources["BlendVFXTests"] = (ROOT / "tests/blend_vfx.spec.luau").read_text(encoding="utf-8")
sources["Types"] = (ROOT / "src/shared/Types.luau").read_text(encoding="utf-8")
sources["BlenderInputComponent"] = (ROOT / "src/server/Components/BlenderInput.luau").read_text(encoding="utf-8")
sources["IngredientSpawnComponent"] = (ROOT / "src/server/Components/IngredientSpawn.luau").read_text(encoding="utf-8")
sources["AnnouncedIngredientSpawn"] = (ROOT / "src/server/Components/AnnouncedIngredientSpawn.luau").read_text(encoding="utf-8")
sources["IngredientPickupComponent"] = (ROOT / "src/server/Components/IngredientPickup.luau").read_text(encoding="utf-8")
sources["DispenserComponent"] = (ROOT / "src/server/Components/Dispenser.luau").read_text(encoding="utf-8")
sources["GameplayPresentationController"] = (ROOT / "src/client/Controllers/GameplayPresentationController.luau").read_text(encoding="utf-8")
sources["ClientBootstrap"] = (ROOT / "src/client/init.client.luau").read_text(encoding="utf-8")
sources["SprintController"] = (ROOT / "src/client/Controllers/SprintController.luau").read_text(encoding="utf-8")
bundle = "local customerOnly = " + str(args.customer_only).lower() + "\nlocal vfxOnly = " + str(args.vfx_only).lower() + "\nlocal sources = {\n" + "\n".join(
    f"[{json.dumps(name)}] = {json.dumps(source)}," for name, source in sources.items()
) + "\n}\n"
state_tests = (ROOT / "tests/server_state.spec.luau").read_text(encoding="utf-8")
if args.world_only or args.sprint_only or args.carry_only:
    # Reuse the fake engine boundary; skip unrelated gameplay assertions.
    bundle += state_tests.split("env.require = loadModule", 1)[0] + "env.require = loadModule\n"
    spec = "ingredient_carry.spec.luau" if args.carry_only else "sprint.spec.luau" if args.sprint_only else "ingredient_world.spec.luau"
    bundle += (ROOT / "tests" / spec).read_text(encoding="utf-8")
else:
    bundle += state_tests
with tempfile.TemporaryDirectory(prefix="blender-state-tests-") as directory:
    output = Path(directory) / "state-tests.luau"
    output.write_text(bundle, encoding="utf-8")
    result = subprocess.run([args.luau, str(output)], cwd=ROOT, check=False)
    raise SystemExit(result.returncode)
