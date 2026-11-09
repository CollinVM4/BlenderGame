# Codex pass: Customer Take Order / Serve prompt visibility at maximum zoom

Implement only on branch fix/customer-prompt-distance. Independent of tutorial and stash branches. Do not merge.

## Problem
Take Order and Serve interaction prompts disappear too early as camera zooms out, despite readable customer order displays.

## Requirements
1. Trace actual customer interaction prompts on all platforms (ProximityPrompt, custom BillboardGui, visibility controller, distance gates, etc.). Identify which camera-to-prompt draw/visibility gate causes premature hiding.
2. Keep Take Order and Serve prompts visible at maximum supported NORMAL player camera zoom while the character is in the existing legal interaction range. Align their practical visibility with customer order display visibility.
3. Do not equate draw distance with activation distance: preserve server-authoritative player-to-customer activation checks and do not enable remote serving or taking orders from across the plot.
4. Preserve E / touch / gamepad labels and interactions, LOS/occlusion behavior unless directly responsible for the bug, and existing prompt appearance. Avoid setting unbounded global distances or affecting unrelated prompts.
5. If Roblox built-in ProximityPrompt distance rules prevent the desired behavior, document that constraint and use the smallest existing UI/controller-level solution consistent with server validation; no speculative global changes.

## Acceptance
- Desktop at max zoom: standing within valid interaction range shows both prompts; actions work.
- Mobile and console: prompts visible and usable with correct platform-specific controls.
- Out of valid interaction range: no interaction accepted even if display is visible.
- No regression to customer order BillboardGui, prompt duplication, or unrelated plot prompts.
- Add focused tests for visibility/config where feasible; run available tests, StyLua, typecheck and Rojo build. Report actual results and baseline failures. Do not merge or publish.
