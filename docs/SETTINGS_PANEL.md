# Settings panel wiring

The Settings adapter creates no UI and never opens/closes a panel. UIRegistry
resolves the existing Desktop/Content/Panel:Settings contract (including
Settings_panel); FramewispMenus, PanelManager and FramewispActions retain their
existing responsibilities. Rename is intentionally unwired.

## Inspected export contract and outstanding artwork

Inspected XML: repository Framewisp_CCWMF.rbxmx and
C:/Users/Collin Van Meter/Downloads/Framewisp_JTRKKV.rbxmx. Both exports contain
these paths beneath Be a Blender! Desktop/Be a Blender! DesktopContent/Settings:

| Path | Class | Behavior |
| --- | --- | --- |
| PLOT/Friends | TextButton | SetJoinMode FriendsOnly |
| PLOT/All | TextButton | SetJoinMode Open |
| PLOT/Rename | TextButton | No behavior added |
| PLOT/Title | TextLabel | Existing title reused for four-second failure feedback |
| MUSIC/MusicOn | TextButton | Enable music |
| MUSIC/MusicOff | TextButton | Disable music |
| button/BuyBackground/UIStroke | Frame/UIStroke | Selected green background and gold outline |

Unexpected differences from the request: **neither available export has Closed,
a volume track/thumb, or button SelectionScale objects**. Music is two separate
buttons, rather than a single switch. JTRKKV also uses Frame backgrounds with
UIGradient where the mapped older export uses some ImageLabels; binding does not
rely on those decorative instances. The repository export remains unchanged.
No live Studio hierarchy inspection or desktop/mobile smoke test was possible
with the available tools; XML inspection is not claimed as Studio verification.

Closed is supported by both controller and adapter (PLOT/Closed, or
Closed_button_smooth), but that fallback name is specified by the request and
has **not** been verified against an actual Closed control. Closed remains a
valid server mode; the currently mapped export cannot offer its button. An
updated export is required before all three modes are reachable in Settings.
The old manage menu privacy rows have been removed as requested.

The event-based slider implementation is ready for an authored track and thumb,
but deliberately guesses no exported slider names. Until its actual hierarchy
is available, it accepts only explicit BlenderUI attributes: Music:VolumeTrack
on a direct MUSIC child and Music:VolumeThumb on that track's child. Both must be
GuiObjects. Its horizontal position maps to 0?1; the thumb retains its authored
vertical position. Mouse and touch drag end on release or panel close. Adapter
cleanup restores the track's original Active value. Update these bindings after
inspecting the completed export. Do not mistake the synthetic slider test
fixture for shipped artwork.

Selection uses existing BuyBackground color and UIStroke, plus a direct
SelectionScale UIScale if supplied by the import. The adapter does not create
that missing scale or overwrite Framewisp's FW_Scale. Supply SelectionScale in
the authored buttons to enable the 1.1 selected scale. Missing required controls
emit deduplicated diagnostics; ambiguous/wrong-class controls fail closed.

## State and authority

Settings discovers PlayerPlot-tagged Workspace descendants and direct children
of Workspace.Plots, matching TycoonService's candidate sources. It sends only
for a unique locally owned plot, captures PlotSessionId, MembershipRevision from
PlotMembershipRevision, and ClaimRevision from PlotClaimRevision (default zero)
on activation. SetJoinMode uses the unchanged server action and guards.
Selection follows replicated JoinMode, never an optimistic request. Ownership,
plot discovery and reimport changes use signals, with no new polling loops.
Kick, teammate management and close stay in PlotIdentityController.

MusicPresentation.TrackIds defaults to an empty list. Add authorized
rbxassetid://... strings to configure playback. DefaultEnabled=true and
DefaultVolume=0.7; local player MusicEnabled/MusicVolume attributes preserve
preferences for this session. There is no DataStore. Empty playback allocates
no Sound and logs once in Studio; preference controls remain safe. A configured
playlist uses one looped Sound in SoundService. Toggle pauses/resumes that
Sound; volume changes apply live. Ended advances sequentially; DidLoop also
advances multi-track playlists because Roblox looped Sounds do not emit Ended
at the loop boundary. Audio asset playback awaits supplied IDs and Studio QA.

## Validation

Run python tests/run_settings_tests.py --luau <luau.exe> for real module tests at
fake Roblox boundaries, including actual checked-in export resolution and
synthetic missing-artwork contracts. It passes 33 behavioral checks. The updated
plot-identity suite passes, including no privacy rows and retained kick/close.
Existing upgrade_ui (both startup orders) and framewisp_menus suites pass.

The requested state group passes 15/22 suites. All seven failures reproduce
with this Settings change removed: ripeness, smoothie-world, smoothie,
customer-payout, customer-validation, customer-compatibility and sprint. Existing
failures involve value/capacity expectations and missing fixture player names;
no unrelated production code was changed to address them.

Roblox-aware typechecking passes for new/changed feature modules. Full-source
analysis retains exactly the same 216 baseline TypeError diagnostics, with zero
new diagnostics. StyLua passes on changed/new Luau files. Rojo build passes.
Unrelated pre-existing workspace changes were retained.

Before acceptance: supply/inspect the completed export with Closed, slider and
SelectionScale; prepare it through the existing Framewisp toolchain, verify all
three join modes and rejected requests on desktop/mobile, measure minimum 44px
button targets in Device Emulator, drag by mouse/touch, verify panel exclusivity
with Upgrades/Shop/Index, and reimport while open to confirm rebinding. Then
configure music IDs and verify native pause/resume, live volume and playlist
transitions. No AnnouncementBanner or server gameplay code was changed.
