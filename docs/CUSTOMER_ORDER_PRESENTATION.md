# Customer order presentation

`CustomerService` creates a transparent, fixed 270 x 84 order billboard, with
21 px GothamBold dialogue in a 56 px row and an 18 px name in a 28 px row below it.
Both use white text and a dark stroke. The head-relative offset is 3 studs and
MaxDistance is 30, intentionally larger than the unchanged 10-stud serve range.
Written requests, typewriter behavior, and response selection are unchanged.

The server creates OrderBubble disabled. `CustomerOrderController` enables it
locally only when the containing customer's OwnerUserId matches LocalPlayer.UserId.
Ownership changes, dynamically added customers, and streamed removal/reentry are
handled through events. This controls normal UI visibility; request state still
replicates and serving remains server authoritative.

Serving reuses InteractionPromptController and InteractionPromptPresentation,
with Custom style, InteractionActionText = SERVE, and InteractionOrigin =
ServePromptOrigin. The attachment is generated on the NPC root at (0, -0.5, -1.5),
below the dialogue and toward the counter. The actual prompt stays on the root,
preserving interaction distance and the existing Triggered/Serve path.
No manual attachment or remote setup is required.

Studio smoke checks still required:

- With two players, only the owner's nearby customer order is visible. Walk past
  30 studs and confirm it disappears; test owner respawn and customer streaming.
  Confirm the order appears while approaching, before the 10-stud SERVE prompt.
- Inspect generic and imported rigs against bright terrain: dialogue above name,
  name above head, SERVE near the counter, with no visual overlap.
- Exercise keyboard, gamepad, and touch serving; confirm the top valid smoothie
  is consumed once, repeated input does not serve twice, and leaving/resetting
  the day removes the custom prompt.

Automated validation: customer requests, placement/walk, custom prompt lifecycle,
and local owner visibility suites; Roblox-aware typecheck; StyLua; Rojo build.
These mocked tests do not verify engine distance culling or rendered appearance.
