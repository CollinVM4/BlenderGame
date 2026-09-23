"""Run state, integration and presentation suites in independent Luau processes.

Usage: python tests/run_state_tests.py --luau /path/to/luau
Use --group to select a boundary, or --list to inspect the manifest.
These tests do not replace Studio physics/network playtests.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default="luau")
selection = parser.add_mutually_exclusive_group()
selection.add_argument("--group", choices=("state", "integration", "presentation"))
selection.add_argument("--vfx-only", action="store_true", help="Run blender VFX presentation checks")
selection.add_argument("--world-only", action="store_true", help="Run ingredient world integration checks")
selection.add_argument("--throw-only", action="store_true", help="Run ingredient throw contracts")
selection.add_argument("--carry-only", action="store_true", help="Run carry state and presentation separately")
selection.add_argument("--sprint-only", action="store_true")
selection.add_argument("--customer-queue-only", action="store_true")
selection.add_argument("--customer-only", action="store_true", help="Compatibility: run legacy customer/state prefix")
selection.add_argument("--customer-walk-only", action="store_true", help="Run customer walk and rig validation")
selection.add_argument("--customer-order-text-only", action="store_true", help="Run order text through spawning and yielding typewriter")
selection.add_argument("--customer-presentation-only", action="store_true", help="Run customer placement, names and walk presentation")
selection.add_argument("--request-validation-only", action="store_true", help="Run request state and serving integration")
selection.add_argument("--requests-only", action="store_true", help="Run request integration and placement separately")
selection.add_argument("--stash-only", action="store_true")
selection.add_argument("--smoothie-only", action="store_true", help="Run smoothie state, round-trip and geometry separately")
parser.add_argument("--list", action="store_true", help="List selected suites without executing")
args = parser.parse_args()
# Each entry gets a fresh Luau process. The legacy monolith is explicitly integration,
# because it still contains presentation and Studio-adapter checks (see README.md).
SUITES = {
    "throw": ("state", ("fixtures/carry.luau", "ingredient_throw.spec.luau")),
    "throw-blender": ("integration", ("fixtures/carry.luau", "ingredient_throw_blender.spec.luau")),
    "carry-input": ("integration", ("fixtures/carry.luau", "carry_input.spec.luau")),
    "ingredient-slots": ("integration", ("fixtures/smoothie.luau", "ingredient_slots.spec.luau")),
    "carry": ("state", ("fixtures/carry.luau", "ingredient_carry.spec.luau")),
    "stash": ("state", ("stash_interaction.spec.luau",)),
    "smoothie-world": ("state", ("fixtures/smoothie.luau", "smoothie_world.spec.luau")),
    "smoothie": ("state", ("fixtures/smoothie.luau", "smoothie_items.spec.luau")),
    "customer-queue": ("integration", ("customer_queue.spec.luau",)),
    "customer-validation": ("state", ("customer_validation.spec.luau",)),
    "customer-compatibility": ("state", ("customer_compatibility.spec.luau",)),
    "sprint": ("state", ("sprint.spec.luau",)),
    "legacy-state": ("integration", ("server_state.spec.luau",)),
    "legacy-movement": ("integration", ("legacy_movement.spec.luau",)),
    "requests": ("integration", ("customer_requests.spec.luau",)),
    "world": ("integration", ("ingredient_world.spec.luau",)),
    "smoothie-roundtrip": ("integration", ("fixtures/smoothie.luau", "smoothie_roundtrip.spec.luau")),
    "smoothie-survivors": ("integration", ("fixtures/smoothie.luau", "smoothie_survivors.spec.luau")),
    "vfx": ("presentation", ("vfx_runner.spec.luau",)),
    "carry-presentation": ("presentation", ("fixtures/carry.luau", "carry_presentation.spec.luau")),
    "smoothie-geometry": ("presentation", ("fixtures/smoothie.luau", "smoothie_geometry.spec.luau")),
    "customer-order-text": ("presentation", ("customer_order_text.spec.luau",)),
    "customer-orders": ("presentation", ("customer_order_queue.spec.luau",)),
    "customer-placement": ("presentation", ("customer_placement.spec.luau",)),
    "customer-walk": ("presentation", ("customer_walk.spec.luau",)),
    "client-presentation": ("presentation", ("client_presentation.spec.luau",)),
    "blend-presentation": ("presentation", ("fixtures/smoothie.luau", "blend_presentation.spec.luau")),
    "stash-presentation": ("presentation", ("stash_presentation.spec.luau",)),
}
focused = {
    "vfx_only": ("vfx",),
    "world_only": ("world",),
    "throw_only": ("throw", "throw-blender"),
    "carry_only": ("carry", "throw", "ingredient-slots", "carry-input", "carry-presentation"),
    "sprint_only": ("sprint",),
    "customer_queue_only": ("customer-queue",),
    "customer_only": ("legacy-state",),
    "request_validation_only": ("customer-validation", "customer-compatibility", "requests"),
    "requests_only": ("requests", "customer-placement", "customer-walk"),
    "customer_order_text_only": ("customer-order-text",),
    "customer_presentation_only": ("customer-order-text", "customer-orders", "customer-placement", "customer-walk"),
    "customer_walk_only": ("customer-walk",),
    "stash_only": ("stash", "stash-presentation"),
    "smoothie_only": ("smoothie-world", "smoothie", "smoothie-roundtrip", "smoothie-survivors", "smoothie-geometry"),
}
selected = next((names for flag, names in focused.items() if getattr(args, flag)), None)
if selected is None:
    selected = tuple(name for name, (group, _) in SUITES.items() if not args.group or group == args.group)
if args.list:
    for name in selected:
        print(f"{SUITES[name][0]}: {name}")
    raise SystemExit(0)
sources = {}
for directory in ("src/shared/Constants", "src/server/Services"):
    for path in (ROOT / directory).glob("*.luau"):
        sources[path.stem] = path.read_text(encoding="utf-8")
sources["StashPresentation"] = (ROOT / "src/server/Components/StashPresentation.luau").read_text(encoding="utf-8")
sources["StashComponent"] = (ROOT / "src/server/Components/Stash.luau").read_text(encoding="utf-8")
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
sources["CustomerOrderController"] = (ROOT / "src/client/Controllers/CustomerOrderController.luau").read_text(encoding="utf-8")
sources["CarryInputController"] = (ROOT / "src/client/Controllers/CarryInputController.luau").read_text(encoding="utf-8")
sources["SprintController"] = (ROOT / "src/client/Controllers/SprintController.luau").read_text(encoding="utf-8")
source_bundle = (
    "local customerOnly = " + str(args.customer_only).lower() + "\nlocal sources = {\n"
    + "\n".join(f"[{json.dumps(name)}] = {json.dumps(source)}," for name, source in sources.items())
    + "\n}\n"
)
fixture = (ROOT / "tests/fixtures/roblox.luau").read_text(encoding="utf-8")
results = []
with tempfile.TemporaryDirectory(prefix="blender-state-tests-") as directory:
    for name in selected:
        group, files = SUITES[name]
        print(f"\n[{group}] {name}", flush=True)
        # Specs keep their locals together, while a legacy early return cannot skip reporting.
        output = Path(directory) / f"{name}.luau"
        spec = "\n".join(
            (ROOT / "tests" / file).read_text(encoding="utf-8") for file in files
        )
        report = '\nprint(string.format("COUNTS: %d behavioral assertions; %d setup validations", count, setupCount))\n'
        output.write_text(
            source_bundle + fixture + "\nlocal function runSuite()\n" + spec + "\nend\nrunSuite()" + report,
            encoding="utf-8",
        )
        try:
            result = subprocess.run([args.luau, str(output)], cwd=ROOT, check=False)
            passed = result.returncode == 0
        except OSError as error:
            print(f"Cannot execute {args.luau}: {error}", flush=True)
            passed = False
        results.append((group, name, passed))
print("\nRESULTS", flush=True)
for group in ("state", "integration", "presentation"):
    entries = [(name, passed) for category, name, passed in results if category == group]
    if entries:
        print(f"[{group}] {sum(passed for _, passed in entries)}/{len(entries)} suites passed")
        for name, passed in entries:
            print(f"  {'PASS' if passed else 'FAIL'} {name}")
raise SystemExit(0 if all(passed for _, _, passed in results) else 1)
