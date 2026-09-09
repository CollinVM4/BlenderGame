# Blender visual tuning

This pass changes ingredient target placement only. Liquid behavior, visual scale, ingestion, sanitization, arrival easing, particle lifecycle and its 0.35-second idle grace are unchanged.

## Ingredient placement

Create three Attachments named exactly `IngredientSlot1`, `IngredientSlot2`, and
`IngredientSlot3` directly under `Blender`, alongside `BlendVisualOrigin` [Part].
Position and orient them manually inside the glass. Direct children of
`BlendVisualOrigin` are also supported; a same-named direct Blender child takes
precedence. Discovery is non-recursive and requires Attachment instances.

At each placement, a complete set maps accepted indices 1, 2, and 3 directly to
those slots' current `WorldCFrame`, including orientation. Snapshot restoration
uses the same mapping without an arrival tween. Moving a slot later does not
move an already placed visual. Normal placement does not cycle.

If any slot is missing or has the wrong class, the whole set uses the existing
deterministic offsets relative to BlendVisualOrigin. This avoids mixing layouts:

| Index | Fallback local offset (studs) |
|---|---|
| 1 | (1.8, -0.16, 0.09) |
| 2 | (-1.17, 0.06, 1.35) |
| 3 | (-0.9, -0.08, -1.44) |
| 4 | (0.99, -0.24, 1.26) |
| 5 | (-1.71, 0.16, -0.18) |
| 6 | (0.72, 0, -1.35) |

Unexpected indices above three use this legacy fallback (repeating after six)
and emit a Studio-only warning. They never cycle through the three authored
slots or mutate gameplay. The authoritative batch requirements remain unchanged.
BlendVisualOrigin remains required for compatibility with the fallback.

The existing 0.35-second Quad/In arrival tween, per-part transforms, template
scale, CreateVisual source, sanitization, and reset cleanup are unchanged. Live
geometry diagnostics confirmed that visuals reached their commanded targets;
the temporary hierarchy/pivot/bounds dumps and post-arrival observers have been
removed. Slots now provide direct artistic control over the target placement.

Validation covers all three slots and world orientation, snapshot restoration,
missing/wrong-class slots, origin-child discovery, direct-child precedence, and
an injected fourth presentation event with a Studio-only warning. The latter
uses a presentation fixture without changing BlendService's acceptance rules.

## Manual Studio emitter settings

Puff1/Puff2/Puff3/Puff4 are not defined by the Rojo map, a place/model asset in the repo, or a source-controlled setup script. Apply these starting values manually to the existing emitters beneath BlendVisualOrigin Puff attachments. No runtime tuning script was added.

Ranges are min-max. Size and Transparency are NumberSequence keypoints written as `normalized age:value`; set all keypoint envelopes to 0. Size is in studs; lifetime in seconds; speed in studs/second; rotation in degrees; RotSpeed in degrees/second. These are proposed art settings using [Roblox ParticleEmitter properties](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter), not a claim of rendered Studio verification.

| Property | Puff1 | Puff2 | Puff3 | Puff4 |
|---|---|---|---|---|
| Rate | 14 | 12 | 10 | 8 |
| Lifetime | 0.45-0.65 | 0.4-0.6 | 0.5-0.7 | 0.45-0.65 |
| Speed | 0.35-0.8 | 0.45-0.9 | 0.3-0.75 | 0.4-0.85 |
| SpreadAngle | (180,180) | (180,180) | (180,180) | (180,180) |
| Size | 0:1.6; 0.2:2.9; 0.75:3.2; 1:2.6 | 0:1.3; 0.2:2.5; 0.75:2.9; 1:2.3 | 0:1.7; 0.25:3; 0.75:3.3; 1:2.7 | 0:1.4; 0.2:2.6; 0.75:3; 1:2.4 |
| Transparency | 0:1; 0.12:0.08; 0.7:0.12; 1:1 | 0:1; 0.1:0.1; 0.68:0.16; 1:1 | 0:1; 0.14:0.07; 0.72:0.14; 1:1 | 0:1; 0.11:0.09; 0.69:0.15; 1:1 |
| Rotation | 0-360 | 0-360 | 0-360 | 0-360 |
| RotSpeed | -35-35 | -55-55 | -45-45 | -60-60 |
| EmissionDirection | Front | Front | Front | Front |
| Drag | 3 | 3.2 | 3.4 | 3.1 |
| Acceleration | (0,0,0) | (0,0,0) | (0,0,0) | (0,0,0) |
| LightInfluence | 0.2 | 0.2 | 0.2 | 0.2 |
| LightEmission | 0 | 0 | 0 | 0 |

For all four: Orientation = FacingCamera, VelocityInheritance = 0, WindAffectsDrag = false, LockedToPart = true, TimeScale = 1, Brightness = 1, ZOffset = 0. Use cloud/puff textures only; do not use star/sparkle accent textures. Leave Enabled under the working lifecycle's control.

Puffs should be large, solid white, spherical/cartoon-like clouds with enough overlap to fill most of the blender glass volume. Verify there are no sharp starbursts, sparkle rays, glitter accents, or impact-star textures in the final look.

The working lifecycle controls only emitter Enabled state, Clear(), and the existing 0.35-second active/idle timing. Appearance values (Texture, Color, Size, Transparency, Rate, Lifetime, Speed, SpreadAngle, Rotation, RotSpeed, Shape) stay Studio-authored.
