# Scrapbook GUI setup

The first Scrapbook GUI reads the existing DiscoveryCatalog and discovery remotes.
It adds no server authority, acquisition rules, persistence, or customer encounter rules.
Presentation lives in `src/client/UI`, alongside the existing presentation modules.

## Exact Studio hierarchy

Create this in **StarterGui**, with these case-sensitive names and classes. Rojo
maps the scripts, not StarterGui; this hierarchy must be saved in your Studio place.
Do not create per-entry cards or additional LocalScripts.

```text
StarterGui
└── ScrapbookGui [ScreenGui]
    ├── OpenButton [ImageButton]
    │   ├── Icon [ImageLabel]
    │   └── Label [TextLabel]
    └── Window [Frame]
        ├── Background [ImageLabel]
        ├── CloseButton [ImageButton]
        ├── Header [Frame]
        │   └── Title [TextLabel]
        ├── Tabs [Frame]
        │   ├── IngredientsButton [TextButton]
        │   └── CustomersButton [TextButton]
        └── Pages [Frame]
            ├── IngredientsPage [Frame]
            │   └── Scroll [ScrollingFrame]
            │       ├── UIListLayout
            │       └── RaritySectionTemplate [Frame]
            │           ├── Header [Frame]
            │           │   └── Title [TextLabel]
            │           └── Grid [Frame]
            │               ├── UIGridLayout
            │               └── IngredientCardTemplate [Frame]
            │                   ├── Artwork [ImageLabel]
            │                   ├── Name [TextLabel]
            │                   ├── Rarity [TextLabel]
            │                   └── Value [TextLabel]
            └── CustomersPage [Frame]
                └── Scroll [ScrollingFrame]
                    ├── UIListLayout
                    └── JumpSectionTemplate [Frame]
                        ├── Header [Frame]
                        │   └── Title [TextLabel]
                        └── Grid [Frame]
                            ├── UIGridLayout
                            └── CustomerCardTemplate [Frame]
                                ├── Portrait [ImageLabel]
                                └── Name [TextLabel]
```

OpenButton.Icon/Label, Window.Background, and Window.Header.Title are decorative:
the code leaves their text, images, and styling to Studio. Functional descendants
are resolved immediately with class checks and full-path errors. Only PlayerGui,
ScrapbookGui, and replicated remote startup have bounded waits (10 seconds each).
After fixing a missing hierarchy, restart Play to initialize again.

## Required settings and practical starting sizes

- ScrapbookGui: `Enabled = true`, `ResetOnSpawn = false` (also set by the code).
  Keep OpenButton visible and outside Window. Set its Label.Text to `Scrapbook`.
- Window: `Visible = false`, `AnchorPoint = (0.5, 0.5)`,
  `Position = {0.5, 0, 0.5, 0}`, `Size = {0.94, 0, 0.9, 0}`. An optional
  UISizeConstraint with MaxSize `(1000, 800)` keeps desktop cards manageable;
  avoid a large MinSize that would force the window off mobile screens.
- Window.Header: Position `{0.04, 0, 0.02, 0}`, Size `{0.8, 0, 0.08, 0}`.
  Title fills Header. Place CloseButton at the upper right, at least 40x40 pixels.
- Tabs: Position `{0.04, 0, 0.11, 0}`, Size `{0.92, 0, 0.1, 0}`.
  Each tab fills half its width; set texts to `Ingredients` and `Customers`.
  Keep BackgroundTransparency below 1 so selected-tab lightening is visible.
- Pages: Position `{0.04, 0, 0.23, 0}`, Size `{0.92, 0, 0.73, 0}`.
  Both page frames and their Scroll fill their parent: Position zero, Size
  `{1, 0, 1, 0}`. Scroll must have a fixed viewport, not AutomaticSize.
  Set Scroll.ClipsDescendants true. IngredientsPage starts visible, CustomersPage hidden.
- Window.Background fills the window, with lower ZIndex than controls/content and
  Active false. Keep all buttons unobstructed. Use transparent backgrounds on the
  intermediate layout frames if you want the page artwork to show through.
- Both section templates and both nested card templates: `Visible = false`,
  `Archivable = true`. Header.Title fills its Header. Section Header/Grid must use
  AnchorPoint `(0, 0)`. Don't add a competing layout or size constraint to Grid/cards.
- Ingredient card child sizes/positions should use scale: Artwork at `{0.05,0,0.03,0}`,
  size `{0.9,0,0.55,0}`; Name at y=0.59, height=0.15; Rarity at y=0.75,
  height=0.10; Value at y=0.87, height=0.10. Labels use x=0.04, width=0.92.
  Customer Portrait can use height=0.72, with Name at y=0.77 and height=0.18.
  Artwork/Portrait should have transparent backgrounds, ImageTransparency 0,
  and white ImageColor3 (or your intended default tint). The code sets ScaleType Fit.
- Use TextScaled and TextWrapped on card labels; a UITextSizeConstraint with
  MinTextSize 8 and MaxTextSize 20 is a reasonable starting point. Adjust in Studio
  device emulation. Scale-based image rectangles plus ScaleType Fit preserve PNG
  proportions without requiring an additional aspect constraint.

The code owns section sizing/order, a vertical list inside each generated section,
30-pixel section headers, four-column grids with 6-pixel gaps, and card cells with
height 1.35 times their width. Grid height follows UIGridLayout.AbsoluteContentSize;
scroll canvas height uses AutomaticCanvasSize.Y. No card positions or scroll canvas
heights are manually computed. Original templates remain hidden.

## Artwork and behavior

Enter asset strings in `src/shared/Constants/ScrapbookArtwork.luau`, for example:

```lua
Ingredients = {
    Strawberry = "rbxassetid://YOUR_ASSET_ID",
},
SpecialCustomers = {
    walter = "rbxassetid://YOUR_ASSET_ID",
    caseoh = "rbxassetid://YOUR_ASSET_ID",
},
```

Use transparent PNGs. Missing entries use an empty image; cards still render.
There is no duplicate catalog to maintain. Ingredient cards are generated from
GetIngredients(), grouped by Rarity in the supplied order. Customers come from
GetSpecialCustomers(), grouped by MinJumpTier in supplied order. Only populated
sections are created. Canonical IDs index live-update lookups; display names never
serve as discovery keys.

Locked ingredients show a black image tint, `???`, visible rarity, and `$???`.
Locked customers show a black portrait tint and `???`. Discoveries restore each
image's template tint and real text. The controller subscribes before requesting
its snapshot and unions both sets, including events received while the request
is pending or before GUI creation. Individual deltas update only their existing
card. First open selects Ingredients; closing/reopening preserves the current tab.
The GUI survives character respawns. Runtime replacement of the ScreenGui is not
supported in this first pass. A failed snapshot warns; live events continue, but
previous discoveries require successful initialization on the next session.

## Validation

Run `python tests/run_scrapbook_ui_tests.py --luau <luau.exe>` for the focused
presentation suite. It loads the real catalog, artwork, presentation, and controller
with fake Roblox instances/remotes. Covers monotonic merging, snapshot/delta races
with GUI ready both before and after snapshot completion, duplicate events,
canonical grouping/IDs, formatting, locked/unlocked card properties, missing artwork,
missing-instance diagnostics, open/close, and tab preservation.

This fixture does not simulate Roblox layout or verify appearance. No visual Studio
verification was performed. Manually check desktop/tablet/phone sizing, long names,
scrolling, buttons, respawn retention, and live unlocks in Studio after setup.

Implementation checks: focused Scrapbook tests, StyLua on changed Luau files,
Rojo build, and `git diff --check` pass. Full-src Roblox-aware Luau LSP analysis
reports the same 24 unique diagnostics as a fresh unchanged-HEAD baseline
(CustomerRequests missing DisplayText and CombatService optional BasePart);
no new diagnostics were introduced.
