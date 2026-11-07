# Muncher ingredient thumbnails ? implementation and asset handoff

Implemented against checkout `f11feaf6095a5d2741b306b495b25d0b8709ecbc`
(the requested scope reference was `3af92fd55d225f24485f3bfd30dcdbc4bb56051f`).
Existing farm changes were present before this pass and were left alone.

## Release status: blocked on art, production switch pending

**0/39 usable production image URIs.** No faithful ingredient PNGs, ingredient
model exports, or ingredient image content IDs are supplied in this checkout.
The authored `ServerStorage.Ingredients` models are Studio content; the runtime
`ScrapbookPreviewAssets` publisher is code, not an exported prefab bundle.
No Studio rendering, creator-group upload, or experience load permission
verification was possible from the supplied files. No replacement artwork or
placeholder asset IDs have been invented.

All of these canonical IDs need source export/render and image-ID handoff here:

```text
Apple, Banana, Cactus, Chili_Sauce, Cinnamon, Coconut, Cotton_Candy, Crab
Dragon_Fruit, Fish, French_Fries, Golden_Potato, Golden_Tomato, Hamburger, Honey, Ice
Mango, Melon, Milk, Mushrooms, Noob, Orange, Peach, Pear
Pineapple, Pizza, Protein, Rainbow_Trout, Rock, Shell, Shit, Squid
Starfruit, Steak, Strawberry, Sushi, Tire, Watermelon, Worm
```

Render the corresponding authored prefabs (or matching sanitized published
copies) as 256 ? 256 transparent PNGs with consistent three-quarter framing,
silhouette padding, original material colors, and exact filenames such as
`Dragon_Fruit.png`. Import under the experience creator group. Record image
content IDs as `rbxassetid://<positive ID>` in
`src/shared/Constants/MuncherArtwork.luau` (`Images`). Verify each image can load
in the target experience, including a published client, before setting `Enabled`
to true. Restart the client after changing the map/switch.

The runtime gate requires both `Enabled` and complete syntactic URI coverage.
URI syntax cannot establish creator ownership, moderation, visual fidelity, or
experience permissions; those remain Studio/published-client checks.

## Implementation

- `MuncherArtwork`: separate Muncher getter, canonical reward-pool union, sorted
  missing-ID report, and activation gate. Index/ScrapbookArtwork is unchanged.
- `MuncherImagePreloader`: one client-wide deferred preload, four distinct image
  URIs per batch, batches started 0.1 seconds apart. Each yielding request is
  isolated so failed/slow batches cannot block later ones or reel callbacks.
- `MuncherEffects`: five reusable fitted images and catalog-name labels per
  reel. Image changes happen only on content changes. Readiness uses the current
  ImageLabel's `IsLoaded` during animation; no async completion closes over a
  slot. Sequence ownership and cancellation prevent stale image reveals.
  Missing/failed/loading images retain the exact ingredient's catalog name.
  Every string OutputId locks exactly, even outside the expected pool/catalog.
  Front clipping, spin, stop deadlines, rarity, audio and cleanup are preserved.
- `MuncherPresentationController`: skips its legacy Heartbeat warming hook when
  images are active; keeps lookup, cancellation and respawn cleanup.

The existing cache module, leases and controller warming code remain **only for
production while the asset handoff is incomplete**. The image path does not
require the cache, lease previews, warm models, or build/attach viewports. Delete
these legacy branches and `MuncherPreviewCache.luau` when verified images are
ready and the production switch is approved for release.

## Automated validation

```powershell
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite muncher-presentation
python tests/run_state_tests.py --luau .validation-tools/luau.exe --suite muncher-artwork-coverage
```

The presentation suite uses explicit fixture URIs, separate from the production
map. It covers every reward image and result, out-of-pool exact results, failed
and slow images, slot reuse across sequences, cancellation, interruption,
respawn, one-time batched preload, zero viewport creation/attachment, screen
binding recovery, audio, and opt-in timing. Fixture URIs are not real art or
proof of experience access.

Presentation suite, StyLua, Roblox Luau typecheck and Rojo build pass. The
production artwork coverage check **fails as expected**, naming all 39 IDs;
it must pass before release. Shared scrapbook artwork API is unchanged, so its
standalone UI suite was not required. No unrelated regression suites were run.

## Runtime acceptance remains pending

Enable Workspace `MuncherPresentationTiming` in Studio. One summary per roll
reports `path=images`, `worstFrame`, `worstUpdate`, and `iconFallbacks` (visible
slot content assignments that used a name at least once, counted once per
assignment). Preview build/destroy counters are zero on the image path.

Measure comparable first and repeat rolls on the same device after real art is
available. Include cold loading, repeat rolls, tier changes, interruptions,
respawn and multiple machines. Verify recognizable art and exact results.
The reported cached-viewport peak was 830.95 ms / 3.98 ms callback; the confirmed
text-only reference peaks were 61.74, 18.61 and 18.69 ms / 2.90?2.99 ms callbacks.
These are supplied reference measurements, **not thumbnail measurements**.
No runtime hitch improvement is claimed from fixture tests or preload scheduling.
