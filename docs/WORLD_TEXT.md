# Visual-only world text

## Automatic Studio labels

1. Add an Attachment anywhere in Workspace, for example `plat.JumpZoneTextOrigin`.
2. Position the Attachment.
3. Add a **string** attribute `WorldText` with value `JUMP I ZONE`.
4. Play with the latest client scripts synced.

No tags, per-label LocalScripts, or prompts are required. The shared client startup
initializes `WorldTextController` once. It scans Workspace once, then uses descendant
events and one attribute listener per tracked Attachment, including bare Attachments
that may receive their WorldText attribute later. There is no per-frame polling.

Only Attachments with nonempty string WorldText values render. Changing the text
updates the same handle; removing it, setting it empty, or assigning a nonstring
destroys the label. Removing an Attachment disconnects its listener and destroys
its GUI; reentry/streaming creates one fresh view. Repeated startup/discovery is
idempotent. These optional attributes are also observed:

| Attribute | Default | Behavior |
| --- | --- | --- |
| WorldTextVisible | true | Boolean false hides; true/removal shows |
| WorldTextMaxDistance | math.huge | Positive finite number; engine culling only |
| WorldTextTextSize | 24 | Positive finite number; fixed font size |

Invalid optional values fall back to defaults. Text and visibility updates reuse
the GUI. Effective distance/font changes replace the old GUI once because those
settings are creation-only in WorldTextPresentation. The canvas remains 300 x 56
pixels with no camera-distance scaling.

Use either attributes or a manually owned handle for a particular label, not both.
The controller owns only handles it creates and does not alter existing displays.

## Manual client API

`src/client/UI/WorldTextPresentation.luau` displays authored text at any supplied
Workspace Attachment. It uses a TextLabel with no key hint, input handling, tags,
attributes, or ProximityPrompt. Call it from a LocalScript or client controller.

Create an Attachment named `StatusTextOrigin` anywhere appropriate in Workspace,
then resolve it in client code. For example, this LocalScript can live under
`src/client` with an authored `Workspace.Machine.StatusTextOrigin`:

```luau
local WorldTextPresentation = require(script.Parent.UI.WorldTextPresentation)
local attachment = workspace:WaitForChild("Machine"):WaitForChild("StatusTextOrigin")

local label, reason = WorldTextPresentation.Create({
    Origin = attachment,
    Text = "READY",
})
if not label then
    warn(reason)
    return
end

-- Call these from your existing presentation/state events as appropriate:
label:SetText("BLENDING 50%")
label:SetVisible(false)
label:SetVisible(true)
label:SetText("BLEND COMPLETE")

-- When the owning client controller no longer needs the label:
label:Destroy()
```

The calls illustrate the API; do not execute the entire sequence immediately if
you want the proof label to remain visible. For a simple proof, run through the
Create/error-check block and leave it showing READY.

For manually managed labels, no Studio setup beyond the Attachment and your client
call is required. Rojo already maps the UI modules. Retain one handle per label and
update it rather than calling Create again. Multiple intentional labels have
independent handles. Omit WorldText on manually managed origins.

`Create(settings)` returns `(handle, nil)` or `(nil, reason)` for missing,
non-Attachment, or non-Workspace origins, before allocating any GUI. Optional fields:

| Field | Default | Meaning |
| --- | --- | --- |
| Text | empty string | Literal label text |
| Width / Height | 300 / 56 | Canvas pixels, never stud/scale units |
| TextSize | 24 | Fixed font size |
| StudsOffset | Vector3.zero | Billboard camera-relative offset in studs |
| MaxDistance | math.huge | Engine visibility culling, not resizing |

The GUI is a client-created child of the Attachment, which is also its exact
Adornee. Destroying the Attachment (or its containing model) destroys the GUI.
Destroy is idempotent; methods after destruction do nothing. Streaming owners
should destroy their handle when unbinding and create a new handle for a newly
streamed Attachment. The module does not search or wait for replacement origins.

`WorldBillboardStyle` shares the existing prompt's pixel canvas, white GothamBold
text, black stroke, transparency, wrapping, centering, and AlwaysOnTop treatment.
InteractionPromptPresentation still owns its TextButton, input events, key hint,
and cleanup; WorldTextPresentation owns its independent visual-only lifecycle.
Neither shared styling nor world text subscribes to camera or frame events.

IngredientCountOrigin is intentionally unchanged. BlenderStatusPresentation
already owns its server-created count display, owner subscriptions, state-driven
text, and completion color. Migrating it would expand this pass beyond a reusable
client visual helper. The manual READY example above is the initial proof of use.

Validation commands: `python tests/run_world_text_tests.py --luau <luau.exe>` and
`python tests/run_interaction_prompt_tests.py --luau <luau.exe>`, plus StyLua,
Roblox-aware Luau LSP analysis with a fresh Rojo sourcemap, and Rojo build.
CLI tests use a mocked Roblox boundary; they do not verify live Studio rendering.

Attribute-controller checks: 49 world-text assertions and 23 controller assertions,
including initial/late discovery, attribute updates, invalid attributes, duplicate
prevention, removal/reentry, and cleanup. Focused Roblox-aware typecheck, StyLua,
and Rojo 7.7.0 build are also run for the controller changes.
