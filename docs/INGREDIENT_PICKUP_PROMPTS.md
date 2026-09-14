# Ingredient pickup presentation

Loose, claimable ingredients now show a transparent, outlined world billboard:

```text
COMMON
Strawberry
[E]
```

`IngredientPickup` still binds `IngredientWorldItem`, reads the private server
record, and routes `Triggered` to `InventoryService.CarryWorldItem(player, object)`.
Its existing `CarryPrompt` now uses `Enum.ProximityPromptStyle.Custom` and the
`IngredientPickupPrompt = true` presentation marker. Range remains 10 studs;
hold duration, eligibility, server validation, market purchases, carry capacity,
throwing, stashing, blending, and rewards are unchanged.

## Data and tuning

- `src/shared/Constants/Ingredients.luau`: existing definitions remain authoritative.
  `Rarity` supports Common, Uncommon, Rare, and Mystery; omitted rarity displays
  Common. `DisplayName` is optional and falls back to `Id`. The existing Mystery
  definition now has Mystery rarity. No instance Rarity attributes are needed.
- `src/client/UI/IngredientPickupPromptStyle.luau`: `RarityStyles`, font, text and
  stroke colors, stroke thickness/transparency, text sizes, row heights/spacing,
  `BillboardSize`, `PromptStudsOffset`, `MaxDistance`, and `HideMysteryNames`.
  `HideMysteryNames = true` displays `MYSTERY` / `???`; false shows the definition's
  display name. This changes no ingredient IDs, names, tags, or gameplay data.
  `MaxDistance` is an optional camera-distance cull, default unlimited; it does
  not extend Roblox's prompt visibility or interaction range.

## Lifecycle and input

`IngredientPickupPromptController` listens to `ProximityPromptService.PromptShown`
and `PromptHidden`. It walks from the prompt host through ancestors to the tagged
registered root, then looks up its replicated `IngredientId` in the shared
definitions. It never derives ingredient identity from instance names or calls
a pickup remote. BasePart, Attachment, and Model prompt hosts are supported.

Only engine-visible prompts are tracked. Repeated show events replace the prior
view; hide, destruction, disabling, and removal clean connections and billboards.
Visible entries tolerate delayed identity/tag replication. Per-frame updates
follow rotated visual bounds, ignoring invisible pivot parts; there is no second
range or pickup detection system. No constant animation is used.

The reusable ingredient view uses `InteractionPromptPresentation` for input:
keyboard hints read the actual `KeyboardKeyCode` through UserInputService;
gamepad hints read `GamepadKeyCode` (for example `[ButtonY]`); mobile shows `[TAP]`.
Touch and permitted mouse clicks forward `InputHoldBegin`/`InputHoldEnd` to the
real prompt. Hold events display `HOLD`; release, focus loss, or cleanup ends a
held touch/click. Native keyboard/gamepad targeting and activation remain Roblox's
responsibility, following the [Roblox custom prompt API](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt).

## Files changed for this feature

| File | Purpose |
| --- | --- |
| `src/shared/Constants/Ingredients.luau` | Optional typed rarity/display-name fields; Mystery rarity |
| `src/server/Components/IngredientPickup.luau` | Custom style and presentation marker |
| `src/client/init.client.luau` | Start ingredient controller |
| `src/client/Controllers/IngredientPickupPromptController.luau` | Identity and visibility lifecycle |
| `src/client/UI/IngredientPickupPromptPresentation.luau` | Bounds-aware rarity/name/input billboard |
| `src/client/UI/IngredientPickupPromptStyle.luau` | Central appearance and name hiding |
| `src/client/UI/InteractionPromptPresentation.luau` | Reuse input handling with optional input-only layout and BasePart adornee |
| `tests/run_ingredient_prompt_tests.py` | Focused Luau test runner |
| `tests/ingredient_prompt.spec.luau` | Real-module presentation/controller/component regression checks |
| `tests/server_state.spec.luau` | Add Custom/Default prompt enums to engine mock |
| `docs/INGREDIENT_PICKUP_PROMPTS.md` | Setup, tuning, and validation |

Existing unrelated working changes were retained. Ingredients keeps its existing
tab indentation; its StyLua check uses `--indent-type Tabs`.

## Validation and Studio

Passed: 39 ingredient prompt assertions, 79 existing interaction prompt assertions,
75 ingredient world assertions, 221 carry assertions, and 72 world-text assertions.
These run real modules against a mocked Roblox boundary, not a live engine.
Changed runtime modules pass Roblox-aware Luau LSP type checking. All source Luau
files compile. StyLua, `git diff --check`, and Rojo build pass.

The complete state suite stops in the existing blender VFX assertion
`start clears copies and cancels arrival`. The same failure reproduces in a
temporary baseline test bundle with this feature's pickup/bootstrap sources and
Mystery rarity change removed. No VFX code was modified for this task.

No manual Studio objects, attachments, attributes, or Rojo mapping changes are
required. Sync with Rojo and start a fresh Play session. Live visual QA and device
input testing remain required in Studio: inspect Strawberry, Crab, Dragon Fruit,
and Mystery; walk out of range; pick up and drop a multipart ingredient repeatedly;
test keyboard, controller emulator, and touch emulator, including hold and release.
Confirm readable spacing above differently sized ingredients and no leftover UI.
