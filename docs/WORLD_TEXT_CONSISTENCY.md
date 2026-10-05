# World text consistency pass

This pass changes presentation only and preserves the existing working-tree changes.

| Display | Owning file(s) under `src` | Change |
| --- | --- | --- |
| Unassigned top message | `client/Controllers/PlotIdentityController.luau` | Exact text `Claim an available PLOT!`; 17 ? 20 px for this instruction only; existing full-width top-center position retained. |
| Available Plot | `client/Controllers/PlotIdentityController.luau` | 160 ? 80 studs while unassigned; claimed plot identity retains 160. Claim/join pad labels retain 22. |
| Jump Zones | `client/UI/WorldTextPresentation.luau`, fed by existing `WorldTextController` | Fredoka and shared charcoal outline; sand for Jump 1, beach blue for Jump 2, pastel rainbow lettering for Jump 3; white ZONE. Arabic and existing Roman numeral labels are recognized and preserved. |
| Second Storage | `client/Controllers/StashExpansionController.luau` | 40 ? 28 studs. Content and configured price unchanged. |
| All Farm Row purchase pads | `client/Controllers/FarmPresentationController.luau` | 40 ? 28 studs for every generated purchase label. Growing/ready displays retain 40. |
| Load Ingredients | `server/Components/BlenderStatusPresentation.luau`, `client/Controllers/BlenderStatusDistanceController.luau` | Idle guidance only: 380?80 ? 323?68 canvas, 24 ? 20.4 px text, effective client range 40 ? 28 studs. Server bootstrap range 5 ? 3.5. Other status/count sizing and ranges retained. |
| Normal active customer requests | `server/Services/CustomerService.luau` | 30 ? 37.5 studs when an order is taken. Restored to 30 before serving/dismissal/rejection feedback, so `CustomerPresentation.ShowResult` still inherits 30. Bad-customer dialogue retains 30. Existing client membership/reveal visibility unchanged. |
| Muncher progress track | `server/Components/MuncherPresentation.luau` | Shared white color and 0.30 transparency; pill, dark border, green fill, tween, count, FULL/YUM and speech unchanged. |

## Styling and authored content

`shared/Constants/DialogueTextStyle.luau` supplies FredokaOne, White, Dark,
Apply and the 2.5 px opaque text outline. Existing purchase, plot, Blender and
Muncher displays already use this helper; Jump labels now reuse it too.
The generic `WorldBillboardStyle` remains unchanged to preserve unrelated text.
Jump 3 uses per-letter pastel RichText rather than a continuous UIGradient.

All requested displays are generated dynamically by the listed scripts.
Jump origins/text are authored in Studio as Attachment `WorldText` attributes,
as documented in [WORLD_TEXT.md](WORLD_TEXT.md); the renderer creates their
BillboardGuis. The Rojo project does not include the authored Workspace map,
so actual Studio origins and rendered layout could not be inspected here.
Existing labels matching `JUMP 1/2/3 ZONE` or `JUMP I/II/III ZONE` receive the
scoped style automatically. Their authored viewing distances remain unchanged.

## Validation

Passing CLI suites: plot-identity, muncher-presentation, Blender status and
its client distance controller, world text and its controller. The world-text
runner now loads the existing extracted Roblox fixture instead of the retired
server-state prefix; its fixture permits the shared style dependency/UIStroke.

Farm presentation fails at the configured pad price assertion; customer-order-text
fails during recipe-unlock setup; customer-result/customer-orders lack a LocalPlayer
attribute-signal double; customer-queue fails at the existing payout assertion.
Each failure reproduces in the snapshot taken immediately before this pass.
No unrelated production behavior was changed to repair them.

Roblox-aware Luau LSP typecheck was run with fresh Rojo sourcemaps before/after:
201 existing diagnostics in both runs, with no added diagnostics after normalizing
paths/line numbers. StyLua on touched Luau files and Rojo build pass.

## Required Studio acceptance

No new tags, remotes, purchase objects or gameplay configuration are required.
After syncing scripts, playtest the existing authored map:

1. Spawn unassigned at desktop and narrow/mobile viewport sizes. Confirm the
   exact instruction, increased readability, and retained top-center position.
2. Approach an available plot: confirm the label culls near 80 studs and claimed
   identity still uses its old range. Walk-in claim/join behavior must remain intact.
3. Inspect all three authored Jump Zone labels: sand, beach blue, pastel rainbow;
   Fredoka, charcoal outline, white ZONE. Confirm their WorldText strings match
   the forms above and that zone mechanics still behave normally.
4. Approach Second Storage and every Farm Row purchase pad from beyond 28 studs;
   confirm visibility and unchanged prices. Growing/ready farm displays retain 40.
5. Approach the Blender: confirm idle guidance is smaller and culls at 28 studs;
   other status messages/counts keep their existing size/range and state transitions.
6. Take normal customer orders: confirm active request text remains visible to
   plot members near 37.5 studs, feedback/results cull at 30, and nonmembers cannot
   see them. Inspect bad-customer dialogue separately at its unchanged range.
7. Inspect Muncher empty and partially filled against grass/sky: translucent white
   track, dark outline, clear green fill, working count/tween and FULL/YUM response.

Studio playtesting and real font/viewport rendering were not available in this run.

## Files changed

Production files are the eight files named in the ownership table above.
Additional files changed:

- `tests/plot_identity.spec.luau`: expected spawn instruction.
- `tests/blender_status_distance.spec.luau`: clarify retained non-guidance range.
- `tests/world_text.spec.luau`: permit the existing shared typography dependency.
- `tests/world_text_controller.spec.luau`: compare visible Jump text through RichText.
- `tests/run_world_text_tests.py`: include shared typography and load extracted fixture.
- `docs/WORLD_TEXT_CONSISTENCY.md`: this source/range report and Studio checklist.
