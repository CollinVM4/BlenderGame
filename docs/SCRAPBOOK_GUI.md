# Framewisp Index / Scrapbook

The Index now uses the updated `new_export.rbxmx` design and the existing
session discovery backend. No DataStore, second ingredient registry, or separate
ScrapbookGui is required. `ScrapbookController.Init()` is already called by the
client bootstrap. FramewispMenus owns Index visibility, X, exclusive navigation,
and closing menus on respawn; ScrapbookController owns discovery replication.

## Inspected export and required instances

The source root is `Framewisp_7QWABL` (ScreenGui), with
`Be a Blender! Desktop` and `Be a Blender! DesktopContent` (Frames).
The actual Index hierarchy is:

```text
Index [Frame]
??? UpgradesPanelArtwork [ImageLabel]
??? CardsViewport [ScrollingFrame]
?   ??? IndexCardTemplate [Frame]
?   ?   ??? CardBackground [ImageLabel]
?   ?   ??? Top Line [ImageLabel]
?   ?   ??? IngredientValue [TextLabel]
?   ?   ??? IngredientLabel [TextLabel]
?   ?   ??? RarityLabel [TextLabel]
?   ?   ??? FruitImage [ImageLabel]
?   ??? IndexCard [Frame] ? 3, same fields as template
??? Header [Frame]
    ??? HeaderBackground [ImageLabel]
    ??? INDEX [TextLabel]
    ??? Close [ImageButton]
```

Text labels retain authored UIStroke and FW_Scale/k_text descendants. Figma
suffixes are stripped by the exporter. Resolution accepts the exported names
and tagged names such as Index_panel, CardsViewport_scroll_grid, and *_txt.
BlenderUI semantic identifiers override names through the shared UIRegistry.
Generated ScreenGui names and XML referents are not used for binding.

Compared with the previous asset in HEAD, the first example card is now explicitly
IndexCardTemplate, HeaderBackground is authored image artwork instead of a Frame,
and the viewport's scrolling direction is Y. The export still has no UIGridLayout,
UIPadding, automatic canvas expansion, category tabs, or standalone counter.

## Import and Studio setup

Keep the raw export untouched. Prepare the Rojo-mapped asset with:

```powershell
python tools/prepare_framewisp_ui.py --input new_export.rbxmx --external-menus
```

The existing `default.project.json` maps the prepared Framewisp_CCWMF.rbxmx into
StarterGui. This command preserves every generated LocalScript source and all
artwork/layout properties. It defaults the four main panels to hidden and renames
only the eight major navigation/X FigmaAction attribute keys to BlenderMenuAction.
Their FigmaActionParam values stay intact. This prevents generated handlers from
competing with the existing exclusive-menu adapter, which the controller attaches
from canonical client code. Other action attributes, hover/press effects, text
scaling, and spin remain authored. Raw unprepared imports still contain competing
menu actions: always prepare before Rojo sync/build or a manual Studio import.

Sync the prepared asset and client modules. Remove any old manually authored
ScrapbookGui from StarterGui; the collection opens through the existing Index
navigation button. Keep only one enabled desktop import in PlayerGui. No manual
grid, padding, new remotes, or replacement artwork is needed.

## Runtime behavior

DiscoveryCatalog.GetIngredients() provides the complete definitions from
Ingredients, ordered by Common/Uncommon/Rare/Mystery, then canonical ID.
The controller subscribes to DiscoveryAdded before invoking DiscoverySnapshot.
Both merge monotonically, so a late snapshot cannot erase an in-flight discovery.
Duplicate events do not affect totals. These remotes under Shared.Events carry
`{Kind = "Ingredient" | "SpecialCustomer", Id = canonicalId}` and
`{Ingredients = {[id] = true}, SpecialCustomers = {[id] = true}}` respectively.
No client unlock mutation endpoint is added.

The template and three examples are hidden. Runtime cards retain its artwork,
fonts, child positions, strokes, and scaling metadata. Instance names use numeric
positions rather than ingredient IDs. Locked cards show ??? / LOCKED and clear
images and value text. Discovered cards show DisplayName, Rarity, base Value via
MoneyFormat.Announcement, and a mapped image. The authored INDEX label displays
INDEX discovered/total without adding another UI element.

ScrapbookArtwork remains the centralized canonical-ID thumbnail mapping. No
image IDs have been invented; all unmapped thumbnails use an empty image with
hidden FruitImage. Enter actual authored asset strings in that module when ready.

The adapter reuses a UIGridLayout when available, otherwise creates one. Four
columns use 8-pixel gaps and padding, with cell height preserving the exported
234:208 card proportions. Width follows AbsoluteWindowSize, including resize.
CanvasSize starts at zero, AutomaticCanvasSize is Y, ScrollingDirection is Y,
and content is clipped. All entries, including additional rows, are cloned.

Replacement panels/templates, enabled-root changes, and full reimports rebuild
views from the retained session state. Duplicate active desktops pause binding.
View cleanup removes owned cards/layout/padding and resize subscriptions; session
cleanup disconnects replication and ignores in-flight snapshots. Respawn closes
the menu through FramewispMenus without clearing discoveries.

## Customer support and required Figma work

DiscoveryCatalog.GetSpecialCustomers() already supplies canonical special NPCs
ordered by MinJumpTier then ID, including zero-weight entries and excluding regular
NPCs. Customer deltas/snapshots continue merging in the same session state.
Presentation.RenderCard is shared rendering infrastructure: customer adapters can
provide DisplayName, optional rarity/value, and ScrapbookArtwork.GetSpecialCustomer.
No customer UI is added because this export has no category controls.

To expose customers later, author IngredientsButton and CustomersButton beneath
an Index Tabs container, plus a suitable authored category-content layout. Re-export
and prepare it before adding the category binding. Avoid overlaying runtime tabs.

## Validation

Passed: focused Scrapbook presentation/controller tests using the actual exported
hierarchy, Framewisp menu tests executing the unchanged generated action source,
existing cash/upgrade tests with both startup orders, all 16 preparation tests,
discovery state and discovery/inventory integration. Coverage includes duplicate
unlocks, snapshot races, hidden identities, missing thumbnails, deterministic
ordering, counter, four-column sizing, scrolling configuration, panel and partial
template replacement, respawn, ambiguous imports, reimport, and cleanup/cancellation.

Changed-module Roblox-aware typechecking passes with the existing CustomerRequests
DisplayText dependency diagnostics excluded; the unfiltered check reports those
existing errors. StyLua, Rojo build, and whitespace checks pass. The unrelated
discovery-customers integration fails at CustomerService spawnForPlayer's missing
Connect boundary and reproduces on a separate pre-pass copy; it was left isolated.

No Studio render/play session was run. Check actual canvas growth, fonts, padding,
scrollbar interaction, live unlocks, and X/exclusive navigation on desktop and mobile
in Studio. Unit tests verify engine property contracts and simulated UI lifecycles,
not rendered Roblox geometry or network delivery.
