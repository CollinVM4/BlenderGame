# Scrapbook viewport experiment

Discovered cards can render real, sanitized ingredient prefabs at a stationary
three-quarter angle. Undiscovered cards show uppercase rarity in the existing
pickup palette (Common off-white, Uncommon green, Rare gold, Mystery purple),
while keeping names and values hidden. Approved undiscovered ingredients show
flat nearly black silhouettes; discovered ingredients show their original colors. Authored fonts, strokes,
backgrounds, generated Framewisp scripts and four-column layout are unchanged.

## Assets and scope

The eight canonical IDs enabled by `ScrapbookPreviews` are Apple, Banana, Grapes,
Pineapple, Watermelon, Squid, Golden_Potato and Dragon_Fruit. They target simple
fruit, clustered/multipart geometry, tall/irregular geometry, large fruit,
golden material and Mystery rarity. Their actual model structures must be
confirmed in Studio; the repository does not contain ingredient prefabs.

Existing gameplay geometry resolves exact names from `ServerStorage.Ingredients`.
At server startup, `ScrapbookPreviewAssets.Init` clones only these eight names
into `ReplicatedStorage.Shared.ScrapbookPreviewAssets`. It publishes only Models,
Folders, BaseParts, meshes, decals, textures, SurfaceAppearances and bones.
Scripts, sounds, emitters, constraints, prompts, object references, attributes
and CollectionService tags are removed. Parts are anchored and noninteractive.
The source prefabs and inventory lifecycle are untouched; no new remote exists.
There is no substitute geometry for absent prefabs.

**Studio status:** the user confirmed that discovered 3D previews load correctly.
Silhouette appearance still needs Studio visual verification; native Studio
control is unavailable in this session. Real prefabs remain inaccessible from
the supplied filesystem. Startup warnings identify missing, nonarchivable, empty or unsupported
prefabs. The Studio audit below prints the exact available and missing lists.
Other catalog ingredients deliberately use the existing image mapping (currently
empty) or a blank placeholder. PlayerHead's captured player-specific appearance
is outside this experiment.

Each client preview has its own WorldModel and Camera. The visual copy is
uniformly scaled to four studs along its longest bounding-box axis and centered
at the origin. A conservative bounding sphere fits both camera axes with 12%
margin and adapts to aspect-ratio changes. Uniform scaling preserves proportions;
normalization avoids extreme prefab scale causing camera clipping. This may make
thin/elongated models look smaller than hand-tuned PNG crops.

## Cost and expansion

Only vertically visible cards in the open Scrapbook instantiate previews,
using the same eight-item allowlist for discovered color and undiscovered
silhouette modes. Closing the panel, scrolling away, removing cards, or replacing the
binding releases their cameras, worlds and geometry. Scrolling, layout, visibility
and asset-arrival events coalesce refreshes; no RenderStepped/Heartbeat loop or
animation runs. At most eight live previews exist across both modes. Discovery replaces a
silhouette with a fresh full-color clone and releases its old camera/geometry.

The server and every client retain up to eight published sanitized prefab copies;
an active client additionally holds one geometry clone per visible preview plus
a ViewportFrame, WorldModel, Camera and wrapper Model. Instance memory scales with
prefab part/mesh counts. Mesh/texture resources and renderer caching require engine
measurement; no byte estimate, FPS gain or mobile compatibility is claimed.
Scrolling recreates previews and can cause allocation spikes despite the cap.

Expanding the allowlist to all catalog entries increases replicated instance and
asset cost even with lazy client rendering. It also needs prefab auditing,
per-model orientation/crop review, and an explicit concurrent-preview cap.
The catalog is read dynamically; no code assumes exactly 47 ingredients.
**Recommendation:** keep this eight-item prototype for visual evaluation. Prefer
static transparent PNG thumbnails for the full production collection until
representative devices show acceptable open/scroll/reopen frame times and memory.
PNGs also permit consistent golden material lighting and art-directed crops.

## Studio playtest

1. Rojo sync into the existing place that owns the real ingredient prefabs.
   Ensure `ServerStorage.Ingredients` contains exact canonical names from the
   allowlist; roots must be archivable BaseParts or Models with BaseParts.
   No Figma or manual replicated-folder setup is required. Restart Play after
   changing server prefabs; the publisher snapshots assets once at startup.
2. Start Play, inspect server `[Scrapbook] Preview prefab unavailable` warnings,
   and run `docs/studio/ScrapbookPreviewAudit.luau` in the **client** Command Bar.
   It creates temporary offscreen previews, checks real prefab normalization,
   silhouette surface stripping, matching color/silhouette framing, centering,
   engine bounding-box corner coverage and cleanup. It also exercises scrolling
   and close/reopen on the real panel, checks the eight-preview cap, restores
   its original visibility/scroll position, prints results, and removes test UI.
3. With a fresh discovery state, open Index. Check actual rarity colors, `???`,
   hidden values and flat nearly black silhouettes for available approved prefabs
   only. Check that decals, mesh textures, gold sheen and original colors are
   absent; invisible helper parts should remain invisible. Unavailable/nonallowlisted
   ingredients keep blank placeholders. Discover the eight ingredients through
   normal gameplay or existing developer controls; verify live counter updates,
   names, base values, and previews. Check multipart integrity and gold/Mystery
   appearance, then portrait/landscape and narrow screen sizes. Confirm discovery
   restores the original textures/colors with identical geometry and camera framing.
   The audit checks properties; visually inspect the actual cards for readability.
4. Scroll each preview out of view and back, switch exclusive menus, respawn,
   replace the Index panel and reimport Framewisp. Check that discoveries persist,
   four columns and canvas sizing remain correct, and each visible supported card
   has one IngredientPreview with one Camera and WorldModel. Closed/offscreen cards
   should release previews. Remove a prefab and restart: verify PNG/blank fallback.
5. Compare the same discoveries with an empty allowlist and with all eight enabled.
   Measure client memory, open/scroll/reopen frame time and instance counts using
   Studio profiling, then repeat on representative mobile hardware. Studio device
   emulation alone does not establish device GPU performance.

## Automated validation

`tests/run_scrapbook_ui_tests.py` exercises rarity/identity masking, existing color
palette, behavior stripping and source preservation, missing/nonallowlisted
assets, single/multipart renderer paths, bounding-sphere framing for large and
irregular sizes, aspect resize, lazy creation, duplicate refresh, offscreen/closed
cleanup, panel replacement and full/partial reimport. Silhouette tests additionally
cover decal/texture/SurfaceAppearance removal, MeshPart and SpecialMesh texture
clearing, union color overrides, flat lighting, invisible helpers, source
preservation, identical framing, unavailable assets and live discovery switching. Its lightweight UI/math
mocks do not validate real meshes, materials, engine bounding boxes or GPU cost.
Requiring RunService fails the test harness, guarding the static renderer design.

Focused tests, StyLua check and Rojo build pass. Focused luau-lsp analysis has
22 CustomerRequests diagnostics, exactly matching a fresh Git HEAD baseline;
there are no new diagnostics from the preview changes. Unrelated production code
was not changed to resolve those existing errors.
