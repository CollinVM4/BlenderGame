# Settings panel wiring

Settings binds authored Framewisp instances only. FramewispMenus and PanelManager
own menu visibility; owner Rename closes Settings via PanelManager before calling
StandIdentityController.OpenNameEditor for a fresh camera/editor sequence.

## Verified export contract (2026-10-21)

Source: `new_export102126.rbxmx`. Prepared with
`python tools/prepare_framewisp_ui.py --input new_export102126.rbxmx` into the
existing Rojo-mapped `Framewisp_CCWMF.rbxmx`. Preparation preserves artwork and
applies the existing main-menu wiring/visibility policy. No runtime controls or
renamed authored instances are added.

The raw export root is Framewisp_D7E7KL. Beneath Be a Blender! Desktop /
Be a Blender! DesktopContent, the Figma Settings_panel layer exports as Settings
(Frame). Its direct PLOT and MUSIC children are Frames.

| Export path under Settings | Class | Binding |
| --- | --- | --- |
| PLOT/Friends | TextButton | FriendsOnly |
| PLOT/Open | TextButton | Open |
| PLOT/Closed | TextButton | Closed |
| PLOT/Rename | TextButton | Existing owner stand-name editor |
| PLOT/Kick | TextButton | KickTeammate with current teammate and captured context |
| PLOT/Title | TextLabel | Four-second neutral failure feedback |
| MUSIC/MusicOn, MUSIC/MusicOff | TextButton | Per-player music preferences |
| MUSIC/Slider | Frame | Input bounds and track |
| MUSIC/Slider/Knob | Frame | Thumb |
| MUSIC/Slider/ProgressBar | Frame | Volume fill |
| MUSIC/Slider/OuterSlider, InnerSlider | Frame | Authored decoration; OuterSlider provides fallback bounds |

The export removes `_button_smooth` from the five Figma plot button names.
Fallbacks accept both sanitized and original names; Open also retains the old
All/All_button_smooth aliases. All three join modes are reachable in this export.
StandName and TeammateName are intentionally absent per Collin's direction:
they are neither required bindings nor Issues nor authoring TODOs.

Semantic resolution accepts any GuiObject for slider parts, uses direct children
and fails closed on missing, ambiguous or wrong-class bindings. Slider, Knob and
ProgressBar are all required for slider input; missing names appear in Issues,
while the two music toggle controls remain independent. The former
Music:VolumeTrack/Music:VolumeThumb attribute path has been removed.

## Behavior and authority

Settings resolves a unique session plot by the player's PlotSessionId, falling
back to OwnerUserId/TeammateUserId membership. Owners can edit join mode, rename,
and kick; Kick is visible only with a teammate. Teammates see the current mode
selection with every plot control inert. No plot means unselected, inert controls.
Selection follows replicated JoinMode, never an optimistic request.

Management works at any distance. Movement eligibility, Workspace membership,
GetPlot, ValidateActor and handlers' owner checks remain server-authoritative.
Requests capture PlotSessionId, MembershipRevision from PlotMembershipRevision,
and ClaimRevision from PlotClaimRevision (default zero) on activation. Claim/join
remain exclusive to trusted physical server plot zones; remote claim/join remain
retired. PlotIdentityController retains portraits, pad labels, nearby LEAVE TEAM
and PlotStatus feedback, with no owner action or management panel. Both failure
paths use "Plot action unavailable. Try again."

MusicController is the only source for volume. Mouse/touch down on the track or
its authored surfaces seeks and starts dragging; movement clamps normalized X
to 0..1, applies music immediately, and updates knob/fill. Release or panel close
ends dragging. Refresh does not overwrite an active drag. Panel open, external
MusicController.SetVolume, and layout changes refresh the display. Cleanup
restores the track's authored Active value.

ProgressBar exports with AnchorPoint (0.5, 0.5). Its X position follows its new
width so its left edge stays at the track left and its right edge meets the knob.
AnchorPoint, Y position and height remain authored. Knob preserves AnchorPoint
and Y while X follows volume. OuterSlider and InnerSlider are never moved or
resized. Slider absolute bounds take priority; OuterSlider bounds are used if
the group has no width yet, then layout signals reconcile to group coordinates.

MusicPresentation.TrackIds defaults to an empty list. Configure authorized
rbxassetid:// strings for playback. Enabled/volume preferences are per-player
session attributes, with no new persistence. Empty playback creates no Sound and
logs once in Studio. Configured playback uses the existing single looped Sound,
pause/resume, live volume and sequential playlist transitions.

## Validation and Studio acceptance

The Settings runner imports actual exported names, classes and authored geometry;
synthetic missing-part fixtures are explicitly separate from shipped artwork.
Contracts cover complete binding resolution, fallback button names, all modes,
owner/teammate/no-plot permissions, repeated rename delegation, kick context,
mouse/touch seek/drag, clamping, fill/knob alignment, preserved decoration,
refresh during drag, close/reopen, fallback bounds and missing-part music toggles.
Framewisp menu tests cover the newly prepared export's menu policy.

The known plot-session-requests upgrade assertion reproduces on unchanged HEAD
and remains out of scope. No broad state-group regression is required here.

Studio checks remain pending: with two clients, change mode and kick across the
map; repeat rename/save/cancel and check camera restoration; confirm teammate
plot controls are inert while their music slider works independently; drag by
mouse and touch at both ends, close/reopen, and resize; confirm nearby LEAVE TEAM
and physical claim/join behavior. Configure music assets to verify audible volume.

All six focused suites (Settings, Framewisp menus, plot-player-flow, plot-identity,
stand-identity and stand-editor) pass. Changed-runtime Roblox-aware typecheck,
StyLua, Rojo build and whitespace checks pass. Studio/device tests were not run.
