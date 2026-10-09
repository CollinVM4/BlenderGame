# Mobile action layout

`src/client/UI/MobileControlLayout.luau` is a single presentation helper shared by
CarryInputController and SprintController. Existing CAS bindings, titles, input
callbacks, server requests and gameplay systems are preserved. The helper only
sets the returned CAS buttons' Size and Position. It never writes to native Jump.

When a visible, nonzero JumpButton is found beneath PlayerGui.TouchGui, its live
AbsolutePosition/AbsoluteSize define the reference center and diameter D. The
preferred center offsets are Sprint (-1.25D, 0), Throw (-0.95D, -0.95D). Action
buttons are 0.83D square, with a 44 px minimum for unusually small native controls.
The whole rectangular hit target stays 8 px inside the core UI safe area; a 2 px
minimum gap separates it from Jump and the other action. Near screen edges the
closest safe, unoccupied position takes priority over the preferred offsets.

The helper uses the actual CAS button parent rather than searching for a fixed
ContextButtonFrame hierarchy. Parent-local scale ratios preserve screen geometry
across parent scaling and button AnchorPoints. Roblox documents AbsolutePosition
and GetInsetArea as sharing the CoreUISafeInsets coordinate system:
[GuiBase2d](https://create.roblox.com/docs/reference/engine/classes/GuiBase2d),
[GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService).
No extra GUI inset is added during conversion.

Native discovery uses only the TouchGui/JumpButton names; there is no CoreGui
access or hierarchy wait. Missing, hidden or zero-sized Jump uses a bottom-right
reference with D = clamp(18% of the shorter safe-area dimension, 70, 120).
GetGuiInset plus camera ViewportSize is the compatibility fallback if GetInsetArea
is unavailable. Missing CAS buttons are resolved when they appear.

Deferred updates coalesce changes to native geometry/visibility, CAS parent
geometry, button anchors, screen insets, camera viewport, touch availability and
interface additions/removals. Replaced interfaces release their observers;
module destruction releases all observers and invalidates queued updates. There
is no RenderStepped or timer polling, no respawn binding and no new buttons.

## Automated validation

Run the isolated presentation/input suite:

```powershell
python tests/run_mobile_control_layout_tests.py --luau <luau.exe>
python tests/run_state_tests.py --luau <luau.exe> --suite carry-input --suite sprint --suite bat-controller
```

The mobile suite uses the real helper and both controllers at a mocked UI/input
boundary. It covers phone/tablet portrait and landscape dimensions, changing
safe bounds, differing parent origins/sizes/anchors, native moves/resizes,
interface recreation, missing/hidden controls, delayed CAS buttons, fallback,
touch enablement, teardown and existing held-sprint/throw-press semantics.
It cannot validate native Roblox rendering or simultaneous physical touch input.

Changed runtime files pass Roblox-aware Luau LSP typecheck; all touched Luau
files pass StyLua and Rojo build succeeds. The bat-controller suite passes.
Carry-input and sprint stop in StandIdentity.DefaultName because their existing
session fixture omits the player name. Both failures reproduce on HEAD in an
isolated baseline checkout before reaching the input contracts. No unrelated
production code was changed.

## Studio Device Emulator checks remaining

No new assets, remotes or authored Studio setup are needed; sync with Rojo.
Studio native UI control is unavailable in this environment, so these checks
remain manual:

- Small/narrow and wide phones, plus tablets: check portrait/landscape where
  supported, notch/home-indicator clearance, target separation and Throw sitting
  slightly right of Sprint. Jump must keep its original size, position and art.
- Hold Sprint and press Jump simultaneously. Test release/cancellation, stamina
  exhaustion and fresh presses using the existing sprint behavior.
- Move, drag the camera and press Throw with empty and populated inventories;
  verify selection, one throw on press and the existing Bat input pass-through.
- Respawn repeatedly, rotate/resize, and recreate TouchGui/ContextActionGui while
  playing; verify the two CAS actions recover their layout with no extra buttons.
- Desktop mouse/Shift and console primary action: confirm existing controls.
