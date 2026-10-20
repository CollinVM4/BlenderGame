# World outlines, covered throws and authored menu badges

WorldBillboardStyle.ApplyBillboard publishes WorldHeightStuds. ApplyWorldStroke
uses ThicknessStuds (default 0.05), projected AbsoluteSize.Y and that height to
compute max(1, round(studs * pixels / height)). ApplyText's built-in TextStroke
is unchanged. Ingredient/smoothie presentations explicitly chain stroke cleanup.
Other world views retain bindings until their stroke or billboard is destroyed;
the helper disconnects automatically. DialogueTextStyle accepts the billboard
before labels are parented. WorldStrokeController binds replicated server views
and clones on each client, where camera-dependent AbsoluteSize is available.
Screen and SurfaceGui strokes keep their existing pixel styling.

IngredientThrow placement is superseded by the [spawn preference ladder](THROW_SAFETY.md).
It uses one fixed height, straight then angled endpoint candidates, and a forced
straight minimum fallback. Occupancy no longer rejects throws; impulse is unchanged.

The updated Framewisp export is intentionally not included. After importing it,
each outer Upgrades/Index button needs a direct GuiObject child named Badge (or
BlenderUI=Badge). TextLabel containing ! and ImageLabel are both accepted. No
runtime badge is generated. Binding forces hidden before evaluating state;
missing/ambiguous elements are harmless and warn only in Studio. Upgrades follows
current replicated affordability using the same rows/prices as its panel. Index
counts DiscoveryAdded events received while closed; opening clears them, and
events received while open are already seen. Counts remain session-only.

Validation: billboard/helper/client replication, ingredient/smoothie/interaction
prompts, throw/throw-blender, carry presentation, customer result, notification,
upgrade and Scrapbook UI suites pass. The full interaction runner has the existing
"default Start Day UI hidden" failure, reproduced with the pre-task prompt
migration and original pixel outlines; customer-only coverage passes.
StyLua and Rojo build pass. Full Roblox
LSP analysis has existing CustomerRequests, CombatService, CustomerService and
JackedNoobService errors; comparison against baseline found no new type errors.

Studio checks still required:

- Walk toward/away from ingredient prompts, customers and carried stacks on
  desktop/mobile; assess outline weight at the one-pixel clamp and tune studs.
- Throw under Central Market Yellow Shop's awning, in fully enclosed cover, and
  on open ground. Inspect clear/forced placement traces and physical arrival.
- Import the updated UI; earn/spend across an upgrade price, unlock ingredients
  and customers with Index closed, open/close Index, then unlock again.
- Reimport with Badge removed: buttons/panels still work without generated badges.

Stroke audit: remaining direct pixel strokes belong to ScreenGui controls, the
Muncher SurfaceGui reels, and the stand SurfaceGui. The PlotIdentity border's
pixel branch is ScreenGui-only; its BillboardGui branch uses ApplyWorldStroke.
