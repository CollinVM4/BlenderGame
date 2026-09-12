# Custom world interaction text

`src/client/UI/InteractionPromptPresentation.luau` creates the reusable pixel-sized
BillboardGui. `src/client/Controllers/InteractionPromptController.luau` owns its
PromptShown/PromptHidden lifecycle and is initialized by the client bootstrap.
Neither module contains object-specific names or gameplay logic.

## Dispenser setup

The existing server `Components/DispenseButton.luau` creates `DispensePrompt` on
the actual button resolved from the `DispenseButton` tag. It now sets Custom style
and the presentation attributes automatically. Its Triggered handler, owner check,
BlendService.Dispense call, and audio are unchanged. `Components/Dispenser.luau`
is a separate inventory release API and is not the smoothie button handler.

Keep the existing button/tag and this authored hierarchy:

```text
Dispenser
├── DispenserTextOrigin [Attachment]
├── Union
├── DispenseButton [existing tagged interaction fixture]
└── base
```

**DispenserTextOrigin needs no attributes or tags.** Its exact name and existing
world transform are used. Nothing moves the attachment or physical button.
No new remotes, server services, or Studio-authored GUIs are needed. Sync and
restart Play so runtime prompts are recreated with their presentation metadata.
If the marker is absent, custom text stays hidden; the controller binds it when
it arrives through replication/streaming. No fallback marker is invented.

## Start Day setup

`src/server/Components/DayButton.luau` automatically applies Custom style,
`InteractionOrigin = "StartDayTextOrigin"`, and
`InteractionActionText = "START DAY"`. It clears any InteractionKeyText override
so the shared view uses the actual prompt key. No manual attributes are required
on the prompt or Attachment. Retain the existing StartDayButton fixture tag.

```text
Start Day
├── StartDayTextOrigin [Attachment]
├── ProximityPrompt
├── StartButton
└── base
```

The component reuses the authored sibling ProximityPrompt, or an existing prompt
on the resolved button part. It only uses its original StartDayPrompt creation
path when neither exists. This avoids creating a second prompt alongside the
authored one. Authored prompt parenting, key codes, activation distance, hold
duration, line of sight, Enabled state, and click settings are preserved. The
fallback keeps the original 10-stud range and RequiresLineOfSight = false.

The existing Triggered owner check, GameService.StartDay call, and LastActionError
result reporting are unchanged. Cleanup disconnects the handler and restores
borrowed prompt presentation settings; only component-created prompts are destroyed.

The legacy visual found in repository code was Roblox's default prompt UI; Custom
style disables it. No separate Start Day BillboardGui/SurfaceGui/key renderer was
found in source. The shared controller/view supplies fixed 300 x 56 pixel text,
dynamic key labeling, and duplicate-free lifecycle at the untouched authored origin.
Sync and restart Play. Live Studio-only scripts/assets were not inspected.

## Opt another prompt in

Set these on an existing prompt (preferably before parenting it into Workspace):

```luau
prompt:SetAttribute("InteractionOrigin", "StartDayTextOrigin")
prompt:SetAttribute("InteractionActionText", "START DAY")
prompt.Style = Enum.ProximityPromptStyle.Custom
```

The named Attachment may be a sibling of the prompt, a direct child on the path
to its nearest containing Model, or nested beneath that Model. Direct matches
take precedence; otherwise the nested Attachment must be unique. Resolution stops
at that Model so a missing marker cannot bind another interactable in the plot.
A direct marker of the wrong class or ambiguous nested Attachments is rejected
with an explicit diagnostic. Optional prompt attributes:

| Attribute | Type | Default |
| --- | --- | --- |
| InteractionActionText | string | prompt.ActionText |
| InteractionKeyText | string | actual keyboard/gamepad key, or TAP for touch |
| InteractionMaxDistance | positive number | no additional camera culling |

The prompt itself continues to control interaction range, line of sight,
exclusivity, Enabled state, key input, and hold duration. Presentation distance
only adds camera culling; it never grants interaction. The view shows hold text
from prompt events; it does not interpret a trigger as a successful transaction.
Touch and permitted clicks forward InputHoldBegin/InputHoldEnd to the prompt.

For an explicit client adapter, the lower-level API is:

```luau
local cleanup = Presentation.Create(prompt, attachment, playerGui, inputType, {
    ActionText = "START DAY",
    -- Optional: KeyText, MaxDistance, Width, Height, TextSize
})
-- Call cleanup on PromptHidden, removal, or replacement.
```

Use either the attribute controller or your own adapter for a given prompt.
The default view is 300×56 pixels with centered, transparent, white outlined
24px text and AlwaysOnTop. There is no distance scaling or render-frame loop.
Repeated PromptShown events replace the previous view and disconnect listeners.

## Turbine

The server's existing 380×80-pixel canvas, 24px font, zero offset, messages, and
TurbinePromptOrigin are retained. The client distance controller no longer
registers the turbine for camera updates or creates its CameraDistanceScale.
Removed its 12/25-stud bands, 1/0.70/0.55 scales, hysteresis participation, and
30–40-stud fade. BillboardGui.MaxDistance still culls at 40 studs. Ingredient
count display also now uses fixed pixels without scaling/fade, retaining its
240 x 72 canvas, 24px font, centered layout, and 60-stud engine culling range. The turbine remains a state message display;
no new turbine prompt or input was introduced.

## Validation

### Client runtime trace

Sync the client scripts and restart Play. In the **CLIENT** Command Bar, enable:

```luau
game.Players.LocalPlayer.PlayerGui:SetAttribute("DebugFilmLoop", true)
```

This follows the existing Studio-only `DebugFilmLoop` logging convention, using
local PlayerGui because the server's ServerStorage attribute cannot replicate.
No hierarchy or server changes are required. Disable with `false`; toggle off/on
to request another snapshot after approaching the two interactables.

`[InteractionPrompt]` lines include the full prompt path, observed PromptShown
count since controller startup, both presentation attributes, resolved origin,
range, line of sight, hold duration, style, Enabled, parent class/placement,
Workspace ancestry, exclusivity, and service visibility settings. Snapshots enumerate
opted-in prompts even if PromptShown has never fired. Event lines show the exact
prompt received by the controller; subsequent lines identify Presentation.Create,
the returned BillboardGui and its Adornee, or the exact controller rejection.
Presentation.Create has no rejection branch: an exception appears in Studio Output;
a successful return now also exposes the created GUI as a second return value.

A prompt directly under a Model requires that Model's PrimaryPart to be set.
The snapshot explicitly reports a missing PrimaryPart, but does not alter it or
bypass ProximityPromptService. Compare the live Start Day and dispenser lines;
the resolver already supported the supplied direct-sibling Start Day hierarchy
before the nested-origin change. A manually fired mocked PromptShown cannot
establish engine eligibility or prove that the live UI rendered.

Current trace validation: 79 focused interaction assertions and focused Roblox-aware
typecheck pass; Rojo 7.7.0 build passes. Direct Studio inspection was attempted but
the computer-use native pipe was unavailable. The live Start Day root cause remains
unconfirmed pending the client trace; a missing Model.PrimaryPart is a hypothesis,
not an observed runtime fact.

Run `tests/run_interaction_prompt_tests.py` and `tests/run_blender_status_tests.py`
with `--luau <executable>`. These exercise real modules with mocked engine signals;
they do not render Roblox graphics. Also run StyLua, Roblox-aware Luau LSP with
the Rojo sourcemap/Roblox definitions, and Rojo build.

In Studio, check near/far turbine size, dispense with keyboard/touch/gamepad,
hold/release if using a hold prompt, repeated range entry/exit, two dispensers,
and streaming. Confirm only custom text appears at the authored marker.

Implementation validation: 64 interaction assertions, 32 server status assertions,
and 126 client distance assertions pass. Changed Luau files pass StyLua; focused
Roblox-aware analysis and Rojo 7.7.0 build pass. Full source analysis reports
existing errors in StashPromptController (36/39) and CustomerService (337).
The full state suite stops at BlendVFX's `start clears copies and cancels arrival`
assertion; the same failure was reproduced from an isolated unchanged HEAD export.
Live Studio rendering/input verification has not been performed.

The lifecycle/input approach follows the
[Roblox proximity prompt documentation](https://create.roblox.com/docs/ui/proximity-prompts).
