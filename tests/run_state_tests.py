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
selection.add_argument("--suite", action="append", help="Run named suites (repeatable)")
selection.add_argument("--group", choices=("state", "integration", "presentation"))
selection.add_argument("--vfx-only", action="store_true", help="Run blender VFX presentation checks")
selection.add_argument("--world-only", action="store_true", help="Run ingredient world integration checks")
selection.add_argument("--throw-only", action="store_true", help="Run ingredient throw contracts")
selection.add_argument("--carry-only", action="store_true", help="Run carry state and presentation separately")
selection.add_argument("--sprint-only", action="store_true")
selection.add_argument("--customer-payout-only", action="store_true")
selection.add_argument("--customer-result-only", action="store_true")
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
    "tutorial": ("state", ("tutorial.spec.luau",)),
    "initial-spawn": ("integration", ("initial_spawn.spec.luau",)),
    "tutorial-targets": ("presentation", ("tutorial_targets.spec.luau",)),
    "tutorial-claim": ("integration", ("fixtures/smoothie.luau", "tutorial_claim.spec.luau")),
    "tutorial-gameplay": ("integration", ("fixtures/smoothie.luau", "tutorial_gameplay.spec.luau")),
    "admin": ("integration", ("admin.spec.luau",)),
    "admin-legacy": ("integration", ("admin_legacy.spec.luau", "admin.spec.luau")),
    "bad-customer-presentation": ("presentation", ("bad_customer_presentation.spec.luau",)),
    "bad-customers": ("integration", ("fixtures/customer_queue.luau", "bad_customers.spec.luau")),
    "bad-customer-stash": ("integration", ("fixtures/smoothie.luau", "bad_customer_stash.spec.luau")),
    "muncher": ("integration", ("fixtures/smoothie.luau", "muncher.spec.luau")),
    "muncher-presentation": ("presentation", ("muncher_presentation.spec.luau",)),
    "ingredient-cleanup": ("integration", ("fixtures/smoothie.luau", "ingredient_cleanup.spec.luau")),
    "jacked-noob": ("state", ("jacked_noob.spec.luau",)),
    "jacked-noob-inventory": ("integration", ("fixtures/smoothie.luau", "jacked_noob_inventory.spec.luau")),
    "ripeness": ("state", ("ripeness.spec.luau",)),
    "ripeness-presentation": ("presentation", ("ripeness_presentation.spec.luau",)),
    "ripeness-lifecycle": ("integration", ("fixtures/smoothie.luau", "ripeness_lifecycle.spec.luau")),
    "announcements": ("integration", ("fixtures/smoothie.luau", "announcements.spec.luau")),
    "announcement-presentation": ("presentation", ("announcement_presentation.spec.luau",)),
    "discovery": ("state", ("discovery.spec.luau",)),
    "discovery-inventory": ("integration", ("fixtures/smoothie.luau", "discovery_inventory.spec.luau")),
    "discovery-customers": ("integration", ("fixtures/customer_requests.luau", "discovery_customers.spec.luau")),
    "gameplay-sfx": ("integration", ("fixtures/smoothie.luau", "gameplay_sfx.spec.luau")),
    "stash-expansion": ("integration", ("fixtures/smoothie.luau", "stash_expansion.spec.luau")),
    "farm": ("integration", ("fixtures/smoothie.luau", "farm.spec.luau")),
    "upgrade-sync": ("integration", ("fixtures/smoothie.luau", "upgrade_sync.spec.luau")),
    "combat": ("integration", ("fixtures/smoothie.luau", "combat.spec.luau")),
    "plot-player-flow": ("integration", ("fixtures/smoothie.luau", "plot_player_flow.spec.luau")),
    "plot-session-races": ("integration", ("fixtures/smoothie.luau", "plot_session_races.spec.luau")),
    "plot-session-progression": ("integration", ("fixtures/smoothie.luau", "plot_session_progression.spec.luau")),
    "plot-session-requests": ("integration", ("fixtures/smoothie.luau", "plot_session_requests.spec.luau")),
    "plot-session": ("integration", ("fixtures/smoothie.luau", "plot_session.spec.luau")),
    "throw": ("state", ("fixtures/carry.luau", "ingredient_throw.spec.luau")),
    "throw-blender": ("integration", ("fixtures/carry.luau", "ingredient_throw_blender.spec.luau")),
    "carry-selection": ("integration", ("fixtures/smoothie.luau", "carry_selection.spec.luau")),
    "carry-input": ("integration", ("fixtures/carry.luau", "carry_input.spec.luau")),
    "ingredient-slots": ("integration", ("fixtures/smoothie.luau", "ingredient_slots.spec.luau")),
    "carry": ("state", ("fixtures/carry.luau", "ingredient_carry.spec.luau")),
    "stash": ("state", ("stash_interaction.spec.luau",)),
    "stash-integration": ("integration", ("fixtures/smoothie.luau", "stash_integration.spec.luau")),
    "smoothie-world": ("state", ("fixtures/smoothie.luau", "smoothie_world.spec.luau")),
    "smoothie": ("state", ("fixtures/smoothie.luau", "smoothie_items.spec.luau")),
    "smoothie-dispense": ("state", ("fixtures/smoothie.luau", "smoothie_dispense.spec.luau")),
    "customer-payout": ("state", ("customer_payout.spec.luau",)),
    "customer-payout-serve": ("integration", ("customer_payout_serve.spec.luau",)),
    "customer-result": ("presentation", ("customer_result.spec.luau",)),
    "customer-queue": ("integration", ("fixtures/customer_queue.luau", "customer_queue.spec.luau")),
    "customer-serve-anywhere": ("integration", ("fixtures/customer_queue.luau", "customer_serve_anywhere.spec.luau")),
    "customer-bat": ("integration", ("fixtures/customer_queue.luau", "customer_bat.spec.luau")),
    "customer-validation": ("state", ("customer_validation.spec.luau",)),
    "customer-compatibility": ("state", ("customer_compatibility.spec.luau",)),
    "sprint": ("state", ("sprint.spec.luau",)),
    "fall-damage": ("state", ("fall_damage.spec.luau",)),
    "health-regen": ("state", ("health_regen.spec.luau",)),
    "legacy-state": ("integration", ("server_state.spec.luau",)),
    "legacy-movement": ("integration", ("legacy_movement.spec.luau",)),
    "request-selection": ("integration", ("fixtures/customer_requests.luau", "customer_request_selection.spec.luau")),
    "customer-wildcard": ("integration", ("fixtures/customer_requests.luau", "customer_wildcard.spec.luau")),
    "requests": ("integration", ("fixtures/customer_requests.luau", "customer_requests.spec.luau")),
    "world": ("integration", ("ingredient_world.spec.luau",)),
    "smoothie-roundtrip": ("integration", ("fixtures/smoothie.luau", "smoothie_roundtrip.spec.luau")),
    "smoothie-survivors": ("integration", ("fixtures/smoothie.luau", "smoothie_survivors.spec.luau")),
    "bat-controller": ("presentation", ("bat_controller.spec.luau",)),
    "ragdoll": ("presentation", ("fixtures/smoothie.luau", "fixtures/ragdoll_physics.luau", "ragdoll.spec.luau")),
    "vfx": ("presentation", ("vfx_runner.spec.luau",)),
    "carry-presentation": ("presentation", ("fixtures/carry.luau", "carry_presentation.spec.luau")),
    "smoothie-geometry": ("presentation", ("fixtures/smoothie.luau", "smoothie_geometry.spec.luau")),
    "customer-order-text": ("presentation", ("customer_order_text.spec.luau",)),
    "customer-orders": ("presentation", ("customer_order_queue.spec.luau",)),
    "customer-placement": ("presentation", ("customer_placement.spec.luau",)),
    "customer-routing": ("presentation", ("customer_routing.spec.luau",)),
    "customer-walk": ("presentation", ("customer_walk.spec.luau",)),
    "client-presentation": ("presentation", ("client_presentation.spec.luau",)),
    "plot-identity": ("presentation", ("fixtures/smoothie.luau", "plot_identity.spec.luau")),
    "plot-session-feedback": ("presentation", ("fixtures/smoothie.luau", "plot_session_feedback.spec.luau")),
    "blend-presentation": ("presentation", ("fixtures/smoothie.luau", "blend_presentation.spec.luau")),
    "stash-presentation": ("presentation", ("stash_presentation.spec.luau",)),
    "stash-capacity-indicators": ("presentation", ("stash_capacity_indicators.spec.luau",)),
    "stash-prompts": ("presentation", ("stash_prompt.spec.luau",)),
    "gameplay-audio": ("presentation", ("gameplay_audio.spec.luau",)),
    "player-head-stash": ("presentation", ("player_head_stash.spec.luau",)),
    "player-head-blender-visual": ("presentation", ("player_head_blender_visual.spec.luau",)),
    "player-head-visual": ("integration", ("player_head_visual.spec.luau",)),
    "player-head": ("integration", ("fixtures/smoothie.luau", "player_head.spec.luau")),
    "stand-editor": ("presentation", ("fixtures/stand_graphemes.luau", "stand_editor.spec.luau")),
    "stand-identity": ("integration", ("fixtures/smoothie.luau", "fixtures/stand_graphemes.luau", "stand_identity.spec.luau")),
    "stand-sign": ("presentation", ("stand_sign.spec.luau",)),
    "icegun-display": ("integration", ("fixtures/icegun.luau", "icegun_display.spec.luau")),
    "icegun-initial-owner": ("integration", ("fixtures/icegun.luau", "fixtures/icegun_input.luau", "icegun_initial_owner.spec.luau")),
    "icegun-input": ("presentation", ("fixtures/icegun.luau", "fixtures/icegun_input.luau", "icegun_input.spec.luau")),
    "icegun-presentation": ("presentation", ("fixtures/icegun.luau", "icegun_presentation.spec.luau")),
    "icegun-entitlement": ("state", ("fixtures/icegun.luau", "icegun_entitlement.spec.luau")),
    "freeze-status": ("state", ("fixtures/icegun.luau", "freeze_status.spec.luau")),
    "icegun-simulated-combat": ("integration", ("fixtures/icegun.luau", "icegun_simulated_combat.spec.luau", "icegun_combat.spec.luau")),
    "icegun-aim": ("integration", ("fixtures/icegun.luau", "icegun_aim.spec.luau")),
    "icegun-combat": ("integration", ("fixtures/icegun.luau", "icegun_combat.spec.luau")),
}
focused = {
    "vfx_only": ("vfx",),
    "world_only": ("world",),
    "throw_only": ("throw", "throw-blender"),
    "carry_only": ("carry", "throw", "ingredient-slots", "carry-selection", "carry-input", "carry-presentation"),
    "sprint_only": ("sprint",),
    "customer_payout_only": ("customer-payout", "customer-payout-serve"),
    "customer_result_only": ("customer-result",),
    "customer_queue_only": ("customer-queue",),
    "customer_only": ("legacy-state",),
    "request_validation_only": ("customer-validation", "customer-compatibility", "request-selection", "requests", "customer-wildcard"),
    "requests_only": ("request-selection", "requests", "customer-placement", "customer-walk"),
    "customer_order_text_only": ("customer-order-text",),
    "customer_presentation_only": ("customer-order-text", "customer-orders", "customer-placement", "customer-walk"),
    "customer_walk_only": ("customer-walk", "customer-routing"),
    "stash_only": ("stash", "stash-integration", "stash-presentation", "stash-capacity-indicators", "stash-prompts"),
    "smoothie_only": ("smoothie-world", "smoothie", "smoothie-dispense", "smoothie-roundtrip", "smoothie-survivors", "smoothie-geometry"),
}
selected = args.suite or next((names for flag, names in focused.items() if getattr(args, flag)), None)
if selected is None:
    selected = tuple(name for name, (group, _) in SUITES.items() if not args.group or group == args.group)
if args.list:
    for name in selected:
        print(f"{SUITES[name][0]}: {name}")
    raise SystemExit(0)
sources = {}
for directory in ("src/shared/Constants", "src/server/Services", "src/server/Admin"):
    for path in (ROOT / directory).glob("*.luau"):
        sources[path.stem] = path.read_text(encoding="utf-8")
sources["TutorialTargets"] = (ROOT / "src/shared/TutorialTargets.luau").read_text(encoding="utf-8")
sources["TutorialGleamController"] = (ROOT / "src/client/Controllers/TutorialGleamController.luau").read_text(encoding="utf-8")
for name in ("IceGunShopAdapter", "IceGunController", "IceGunDisplayController"):
    sources[name] = (ROOT / f"src/client/Controllers/{name}.luau").read_text(encoding="utf-8")
sources["IceGunDisplayComponent"] = (ROOT / "src/server/Components/IceGunDisplay.luau").read_text(encoding="utf-8")
sources["BatController"] = (ROOT / "src/client/Controllers/BatController.luau").read_text(encoding="utf-8")
sources["UpgradeDisplay"] = (ROOT / "src/client/UI/UpgradeDisplay.luau").read_text(encoding="utf-8")
sources["StashPresentation"] = (ROOT / "src/server/Components/StashPresentation.luau").read_text(encoding="utf-8")
sources["MuncherPresentation"] = (ROOT / "src/server/Components/MuncherPresentation.luau").read_text(encoding="utf-8")
sources["MuncherReveal"] = (ROOT / "src/server/Components/MuncherReveal.luau").read_text(encoding="utf-8")
sources["TutorialTooltip"] = (ROOT / "src/client/UI/TutorialTooltip.luau").read_text(encoding="utf-8")
sources["MuncherPresentationController"] = (ROOT / "src/client/Controllers/MuncherPresentationController.luau").read_text(encoding="utf-8")
sources["MuncherComponent"] = (ROOT / "src/server/Components/Muncher.luau").read_text(encoding="utf-8")
sources["AnnouncementFormat"] = (ROOT / "src/shared/AnnouncementFormat.luau").read_text(encoding="utf-8")
sources["IngredientName"] = (ROOT / "src/shared/IngredientName.luau").read_text(encoding="utf-8")
sources["IngredientItem"] = (ROOT / "src/shared/IngredientItem.luau").read_text(encoding="utf-8")
sources["RipenessDisplayState"] = (ROOT / "src/client/UI/RipenessDisplayState.luau").read_text(encoding="utf-8")
sources["RadialProgress"] = (ROOT / "src/client/UI/RadialProgress.luau").read_text(encoding="utf-8")
sources["RipenessPresentationController"] = (ROOT / "src/client/Controllers/RipenessPresentationController.luau").read_text(encoding="utf-8")
sources["RipenessTutorialText"] = (ROOT / "src/client/UI/RipenessTutorialText.luau").read_text(encoding="utf-8")
sources["MoneyFormat"] = (ROOT / "src/shared/MoneyFormat.luau").read_text(encoding="utf-8")
sources["StashPromptController"] = (ROOT / "src/client/Controllers/StashPromptController.luau").read_text(encoding="utf-8")
sources["StashComponent"] = (ROOT / "src/server/Components/Stash.luau").read_text(encoding="utf-8")
sources["BlendVFX"] = (ROOT / "src/server/Components/BlendVFX.luau").read_text(encoding="utf-8")
sources["BlendVFXTests"] = (ROOT / "tests/blend_vfx.spec.luau").read_text(encoding="utf-8")
sources["InteractionPromptPresentation"] = (ROOT / "src/client/UI/InteractionPromptPresentation.luau").read_text(encoding="utf-8")
sources["MobilePromptDebug"] = (ROOT / "src/shared/MobilePromptDebug.luau").read_text(encoding="utf-8")
sources["MobilePromptTouchTargets"] = (ROOT / "src/client/UI/MobilePromptTouchTargets.luau").read_text(encoding="utf-8")
sources["WorldBillboardStyle"] = (ROOT / "src/client/UI/WorldBillboardStyle.luau").read_text(encoding="utf-8")
sources["Types"] = (ROOT / "src/shared/Types.luau").read_text(encoding="utf-8")
sources["BlenderInputComponent"] = (ROOT / "src/server/Components/BlenderInput.luau").read_text(encoding="utf-8")
sources["IngredientSpawnComponent"] = (ROOT / "src/server/Components/IngredientSpawn.luau").read_text(encoding="utf-8")
sources["AnnouncedIngredientSpawn"] = (ROOT / "src/server/Components/AnnouncedIngredientSpawn.luau").read_text(encoding="utf-8")
sources["IngredientPickupComponent"] = (ROOT / "src/server/Components/IngredientPickup.luau").read_text(encoding="utf-8")
sources["DispenserComponent"] = (ROOT / "src/server/Components/Dispenser.luau").read_text(encoding="utf-8")
sources["GameplayPresentationController"] = (ROOT / "src/client/Controllers/GameplayPresentationController.luau").read_text(encoding="utf-8")
sources["GameplayAudioController"] = (ROOT / "src/client/Controllers/GameplayAudioController.luau").read_text(encoding="utf-8")
sources["ServerBootstrap"] = (ROOT / "src/server/init.server.luau").read_text(encoding="utf-8")
sources["ClientBootstrap"] = (ROOT / "src/client/init.client.luau").read_text(encoding="utf-8")
sources["CustomerOrderController"] = (ROOT / "src/client/Controllers/CustomerOrderController.luau").read_text(encoding="utf-8")
sources["CarryInputController"] = (ROOT / "src/client/Controllers/CarryInputController.luau").read_text(encoding="utf-8")
sources["SessionInteractionController"] = (ROOT / "src/client/Controllers/SessionInteractionController.luau").read_text(encoding="utf-8")
sources["StandIdentityController"] = (ROOT / "src/client/Controllers/StandIdentityController.luau").read_text(encoding="utf-8")
sources["StandNameEditor"] = (ROOT / "src/client/UI/StandNameEditor.luau").read_text(encoding="utf-8")
sources["PanelManager"] = (ROOT / "src/client/UI/PanelManager.luau").read_text(encoding="utf-8")
sources["PlotIdentityController"] = (ROOT / "src/client/Controllers/PlotIdentityController.luau").read_text(encoding="utf-8")
sources["SprintController"] = (ROOT / "src/client/Controllers/SprintController.luau").read_text(encoding="utf-8")
source_bundle = (
    "local customerOnly = " + str(args.customer_only).lower() + "\nlocal sources = {\n"
    + "\n".join(f"[{json.dumps(name)}] = {json.dumps(source, ensure_ascii=False)}," for name, source in sources.items())
    + "\n}\n"
)
fixture = (ROOT / "tests/fixtures/roblox.luau").read_text(encoding="utf-8")
fixture += "\n" + (ROOT / "tests/fixtures/session.luau").read_text(encoding="utf-8")
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
