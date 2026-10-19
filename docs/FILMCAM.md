# FilmCam

FilmCam is a client-only filming tool. It records camera transforms and FOV, not
world state, player inputs, NPCs, physics, rewards, or gameplay. Server FilmingUtil
is unchanged. No remotes, server changes, plugins, or authored Studio UI are needed.

After Rojo sync, access is permitted in Studio, or in a live server as Roblox
UserId **66554216** (Collin). `Constants/FilmCam.luau` owns the numeric allowlist and
key configuration. Other live clients return from Init before UI creation,
input/event binding, camera access, or loading other camera controllers. Public
Play/Stop calls are inert before authorized initialization. Studio intentionally
admits every Studio test player, including negative test IDs.

## Two-pass filming

1. Close the stand-name editor, then press **F6** to enter film mode. The panel is
   hidden until entry. Fly using **WASD/QE**, hold **right mouse** and drag to aim,
   and scroll while dragging to change FOV. Movement affects only the camera.
   While framing, those movement keys are consumed so normal character movement
   and carry actions do not also fire. F6/F7 do not overlap CarryInput's CAS keys.
2. Optionally enter a take name. Press **Record**, rehearse the shot, and **Stop**.
   The default names are Take_1, Take_2, etc. Recording samples at most once per
   0.1 seconds, retaining position changes over 0.05 studs, rotation changes over
   0.5 degrees, or FOV changes over 0.01 degrees relative to the last retained key.
   Start/end keys and stationary-hold boundaries are retained to preserve timing.
   Holds remain still without spline overshoot. The five-minute limit
   stops and saves the take with a panel warning. Takes exist only in this session
   until exported.
3. Click the take selector to cycle saved/session takes. Enter a speed from
   **0.25 to 2**, optionally turn easing off, then **Play**. The same movement keys
   now pass through normally: perform the action live while the camera repeats
   the move. Playback does not reposition, freeze, or otherwise write to the
   character. Timing NPCs and other actors remains a live performance task.
4. Click the progress bar to seek during playback. It shows elapsed playback
   progress; with easing enabled, camera distance is not proportional to time.
   Stop or natural completion returns to the pre-playback framing and FOV.
   Push-in, Pull-out, and Orbit generate, save, select, and play synthetic takes
   from the current camera using this same playback path. Push/pull travel ten
   studs in five seconds. Orbit runs eight seconds around the center-ray hit
   (excluding your character), falling back to twenty studs ahead.
5. Enable **Letterbox** and **Hide UI**, then press **F7** to hide the film panel
   for capture. F7 shows it again. Each letterbox bar covers 12% of the viewport.
   Hide UI temporarily disables PlayerGui LayerCollectors, including new ones
   added while hidden. A LayerCollector with attribute `FilmCamDevUI = true` is
   exempt. Original Enabled values are restored, including initially disabled
   HUDs. Roblox CoreGui is outside this PlayerGui toggle.
6. Press **F6** to exit. CameraType, CameraSubject, CFrame, Focus, FOV, borrowed
   controller suspension flags, hidden HUDs, and any drag mouse settings are
   restored. Letterbox is removed. Losing window focus releases the drag pointer.
   Replacing CurrentCamera exits film mode and leaves the new camera untouched.

The screen panel is intentionally minimal desktop dev UI. Recording/playing does
not change either capture toggle. UI text focus suppresses freecam keyboard input.
While FilmCam is active, automatic stand-name editor opens are suppressed; open
the editor from Settings after exiting if a claim happened during filming.

## Persist a take

Click **Copy Take**. FilmCam fills and selects a textbox containing JSON; use
Ctrl+A/Ctrl+C there. A Roblox client has neither clipboard-write nor file-write
access, so this button does not write files or use executor clipboard APIs.

Paste the complete JSON as a long string inside the returned array in
`src/shared/Constants/FilmTakes.luau`:

```luau
return {
    [=[PASTE COMPLETE JSON HERE]=],
    -- Add further JSON strings here.
}
```

Each JSON object has Version=1, Name, Duration, and Keys. Each key contains Time,
Position=[x,y,z], Rotation=[qx,qy,qz,qw], and Fov. Position is in world coordinates,
so reused takes assume the same plot/map placement. Rotation uses unit quaternions.
On the next run the checked-in module is decoded and validated; bad entries warn
and are skipped. Session takes follow those entries in the selector. No module is
ever overwritten at runtime.

**Real-shot example is pending Studio capture.** FilmTakes is intentionally empty
until a real shot is recorded on a plot. Do not describe a synthetic preset or a
CLI-generated path as Studio-filmed footage.

## Camera suspension contract

`TurbineCameraController.SetSuspended(value)` and
`StandIdentityController.SetSuspended(value)` return the previous boolean. FilmCam
snapshots the camera, saves those booleans, and sets both true before taking
Scriptable ownership. On exit it restores the camera first and then restores
each prior boolean, including controllers that were already suspended.

The turbine controller retains its current view while suspended. Both render
callbacks and its restore/replacement paths refrain from camera writes. After
resume, normal validation handles a character, membership, or plot change that
occurred during filming. The stand editor refuses new camera sequences while
suspended. FilmCam refuses entry while an existing stand editor owns the camera,
so it never suspends an in-flight tween or loses editor progress. Suspension
does not require Destroy/Init, disconnect gameplay listeners, or reset UI systems.

Future camera writers must adopt this contract and be added to FilmCam's handoff.
Avoid circular dependencies: FilmCam depends on the camera owners; owners never
require FilmCam. Roblox's normal camera is suppressed through CameraType.Scriptable.

`FilmCamController.Play(take, speed?)` returns false unless film mode is already
active and the take is valid. `Stop()` ends recording/playback. Both remain behind
the same gate as the panel. Panel playback and presets use the public Play path.

Playback compiles timestamp-aware Catmull-Rom coefficients once at Play, binary
searches segments for arbitrary seeks, slerps normalized quaternions on the
shortest arc, and lerps FOV. Easing integrates a smooth speed ramp over the first
and last 0.5 seconds of playback (short shots use half their duration). The path
render loop creates no Lua tables or closures; camera CFrame and UI UDim2 values
are engine value types. Roblox frame hitches cannot recover missing camera samples.

## Validation and Studio acceptance

Independent presentation tests:

```text
python tests/run_filmcam_tests.py --luau <luau.exe>
python tests/run_turbine_camera_tests.py --luau <luau.exe>
python tests/run_state_tests.py --luau <luau.exe> --suite stand-editor
```

The FilmCam suite owns filtering, known-answer spline/slerp vectors, unequal-time
continuity, easing, take validation/serialization adapter, gate logic, presets,
and event-driven record/play/seek/restore/HUD lifecycle. Engine services, UI, and
CFrame are mocked; this cannot establish visual smoothness, native JSON behavior,
or physical player movement. The native-engine assertions in
`docs/studio/FilmCamSmoke.luau` cover full pitched/rolled transforms, real JSON,
and preset geometry when run from the **client Command Bar** during Studio Play.
They do not record a real shot or substitute for the following checks.

Focused suites, FilmCam Roblox-aware typecheck, StyLua, and Rojo build pass.
Typechecking the client bootstrap includes 22 pre-existing CustomerRequests
missing-DisplayText diagnostics; an isolated snapshot with the FilmCam integration
removed reproduces exactly the same 22 diagnostics. Unrelated code is unchanged.

Studio acceptance has **not been run in this environment**. Required before sign-off:

- Record a real shot on an authored plot; play it while serving a customer or
  feeding the muncher. Verify WASD operates the character only during playback.
- Try 0.25x, 1x, and 2x with easing on/off, a rotation crossing 180 degrees, a long
  stationary hold, FOV changes, and retake seeking. Collin signs off on smoothness.
- Check push/pull travel, orbit ray target/fallback, letterbox, Hide UI, F7 panel
  hiding, and HUDs that appear while hidden. Capture the shot externally.
- Enter/exit inside the turbine zone, including during its transition. Change
  plots, reset/respawn, and replace CurrentCamera while filming; verify camera
  ownership resumes appropriately. Finish the stand editor before entering; claim
  another plot while filming and verify it cannot steal the camera.
- Export that real shot into FilmTakes, restart Studio Play, and replay the
  checked-in entry. Commit the actual take as the requested filmed example.
- In a published private test, verify Collin has access and a non-allowlisted
  account gets no panel or camera/input interference from F6, F7, or Play calls.
  Studio cannot test the denied gate because IsStudio is intentionally sufficient.
