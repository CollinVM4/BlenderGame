# Customer order presentation

Customers receive assigned requests at spawn, but dialogue stays hidden and silent
until the owner takes the order. Any of the three queued customers supports Take
Order. Only the front customer can be served. This presentation pass preserves
request state, dialogue audio cadence, server authorization/distance, one-time
serving, cash calculation, and the 15% missed-order payout.

## Stable world layout

The previous UI followed the animated Head and used camera-relative StudsOffset
(0, 3, 0). The regular dialogue also used TextScaled while the typewriter replaced
its text with a growing prefix. That combination allowed head bobbing, projected
offset drift, and text reflow. Billboard dimensions were already pixel-based;
there was no distance-driven size tween to remove.

CustomerPresentation.CreateAnchor measures the resting head height once and
creates ServePromptOrigin on the stable root. Dialogue, custom actions, and serve
results share that attachment with zero StudsOffset. There are no per-frame
camera/distance position or scale updates. MaxDistance controls visibility only.
The actual ProximityPrompts remain on the root, preserving activation distance.

The fixed pixel regions relative to the projected anchor are:

| Element | Canvas | Vertical region (screen Y, relative to anchor) |
|---|---|---|
| Regular order dialogue | 300 x 112 | -112 to 0 |
| Regular served reaction | 300 x 112 | -80 to +32 |
| Success result | 300 x 54 | -140 to -86 |
| Missed result | 300 x 76 | -162 to -86 |
| Take Order / Serve | 220 x 44 | +12 to +56 |

The result has a fixed 6px gap above the reaction canvas; prompts remain 12px
below the anchor. These gaps remain constant when the anchor moves on screen. Special-customer
dialogue retains its original dimensions and separate name row, with the same
Fredoka One, white primary text, and thick charcoal outline as regular dialogue.
The result position uses that dialogue height. The separate ingredient pickup **RARE Steak** card,
its layout, lettering, and outline are untouched.

Regular and special dialogue use fixed 21px Fredoka One, white text, individually colored request
keywords from the shared ingredient/tag formatter, and an opaque 2.5px charcoal outline. The generic name stays hidden.
The typewriter assigns the complete escaped/rich string once, then changes only
MaxVisibleGraphemes. Word wrapping and font size stay fixed throughout the reveal.
Audio still chirps every third visible character and on the last character, with
the existing whitespace handling and cancellation behavior.

The result's first row uses 24px rounded lettering: grade-specific color and gold actual
awarded cash (comma formatted). `Rarity Bonus xN` has its own white 18px row. Misses add a 16px
red TRY AGAIN / 15% PAYOUT row. All rows use the same charcoal outline. The result
remains owner-only and holds fully readable for four seconds without a fade.
If the exit route completes sooner, only a presentation copy remains at the final
root transform for the rest of that hold. Customer removal, queue progression,
payment, and audio timing are unchanged.

Take Order is compact gold; Serve is compact blue. Both reuse the shared custom
prompt system and actual keyboard/gamepad bindings, plus touch hold input. No E
key is hardcoded in the visual. Their existing mutual exclusion remains intact.

References: [Roblox in-experience UI containers](https://create.roblox.com/docs/ui/in-experience-containers)
and [TextLabel.MaxVisibleGraphemes](https://create.roblox.com/docs/reference/engine/classes/TextLabel#MaxVisibleGraphemes).

## Changed files and validation

Runtime: CustomerService.luau, CustomerPresentation.luau,
InteractionPromptController.luau, InteractionPromptPresentation.luau.
Tests: customer_order_text.spec.luau, customer_order_visibility.spec.luau,
customer_result.spec.luau, customer_queue.spec.luau, fixtures/roblox.luau.

Focused dialogue, custom customer prompt, result layout/ownership, queue, payout,
serve replay, request integration/compatibility, and ingredient/Steak prompt tests
pass. Typecheck, StyLua, Rojo build, and whitespace checks pass; typecheck reports
the existing LoadCharacterAppearance deprecation warning.

The broader customer-validation ingredient expectation fails unchanged in the
pre-edit copy customer-stable-baseline-gnko1vyp under the system temporary folder.
No unrelated production fixes were made. The mock grapheme iterator covers the
uncombined characters in the test dialogue; production uses Roblox's iterator.

## Studio visual checks still required

No live Roblox camera/render session was available. Automated checks establish
fixed sizes/spacing, root anchoring, layout-stable reveal, ownership, and cleanup;
they do not prove rendered readability or clipping. Sync with Rojo; no manual
attachment or asset setup is required.

With all three customers queued, compare close (3 studs), medium (7 studs), and
far (10 studs) interaction distances, then 20-30 studs for dialogue visibility.
Orbit at eye level and elevated/low angles; check grass, market clutter, and sky.
Confirm constant screen font size and gaps during idle/walk animations, reveal,
and serving. Inspect long multiline requests and all three result rows on a
320px-wide phone viewport as well as desktop. Verify the original RARE Steak
card remains unchanged. Check cross-customer overlap at oblique angles, since
world anchors can project near one another. Test two-client ownership, all input
modes, and reset during reveal/feedback.

## Color and result follow-up

Regular Take Order and RefreshOrder now call the same formatter as specials
without a uniform keyword override. Full RichText spans remain assigned before
MaxVisibleGraphemes starts revealing characters. Grade and cash each have closed,
independent color spans; all unaccented result text has a white base color.

No Studio setup is required. Studio visual checks still needed: regular AppleSour,
purple/cold special dialogue, successful and missed serves, short exit routes,
and near/far camera views. Confirm the reward/reaction gap, hidden serve/take-order
prompts after serving, special name row, and unchanged RARE Steak card. Automated
layout checks verify canvas separation, not rendered font bounds or replication.

## Shared special styling and lower served stack

`StyleDialogue` now applies the same lettering to both customer types. Special
names remain visible in their reserved row, using smaller 18px lettering. The
formatter, typewriter, anchor, audio, request selection, and Steak pickup card
are unchanged.

On serving, the reaction and reward both move down 32 fixed pixels. Internal
reward rows and the 6px reward/reaction gap are unchanged. This applies only once
serving has disabled both action prompts, so the lower reaction cannot overlap
an active Take Order or Serve prompt on that customer. Order placement before
serving is unchanged. The four-second result hold is unchanged.
