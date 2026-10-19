# Menu notification badges

The outer Upgrades and Index controls now receive a programmatic red `!` badge.
The inspected export paths are `Be a Blender! Desktop/Be a Blender! DesktopContent/LeftMenu/Upgrades`
and `Be a Blender! Desktop/Be a Blender! DesktopContent/LeftMenu/Index` (both TextButtons).
Runtime binding uses UIRegistry and FramewispMenus' existing semantic/navigation contract,
including renamed/tagged imports, rather than the generated ScreenGui name.

`NotificationBadge.Attach` returns a visibility setter and an optional detach callback.
The transparent 22-by-22 host sits at the button's top-right corner; its red round
TextLabel has a white, scaled GothamBold exclamation mark. Both objects are inactive.
No button property, input handler, artwork or layout is changed.

`MenuNotifications` retains session visibility independently of imported instances.
FramewispMenus attaches badges when it resolves outer navigation and removes them
alongside its existing instance connections. Its descendant/replacement lifecycle
already observes reimports, so a second desktop observer is unnecessary. Repeated
menu attachment stays idempotent. Panel callbacks hide badges before opening and
re-evaluate them when closing; PanelManager's exclusivity logic is unchanged.

Badge state is folded into the existing controllers rather than creating duplicate
attribute/remote subscriptions:

- UpgradesController aggregates UpgradeDisplay.Row over every Display.Tracks entry,
  including when the panel view is unavailable. It observes existing cash, purchased
  level, effective-stat, membership, purchase-result and panel-refresh paths. Updates
  coalesce until the next scheduler frame. Maxed/server-maxed tracks cannot notify;
  pending requests and membership updates suppress the badge. Opening acknowledges
  currently affordable tiers. A new affordable tier, track or subsequent crossing
  of an affordability threshold can notify again. Membership changes reset that
  acknowledgement. UpgradeBadgeState holds only acknowledgement, never pricing.
- ScrapbookController increments a session-local unseen counter for every
  DiscoveryAdded event, including duplicate payloads. Opening Index resets it.
  Events arriving while open remain hidden and notify when Index closes. Snapshot
  contents do not notify. The existing event subscription still precedes the
  snapshot request; no additional snapshot, remote or server change is introduced.

Sync with Rojo; no Studio asset setup is required.

## Focused validation

Run with the installed Luau executable:

```text
python tests/run_notification_badge_tests.py --luau <luau.exe>
python tests/run_upgrade_ui_tests.py --luau <luau.exe>
python tests/run_framewisp_menu_tests.py --luau <luau.exe>
python tests/run_scrapbook_ui_tests.py --luau <luau.exe>
python tests/run_panel_manager_tests.py --luau <luau.exe>
python tests/run_state_tests.py --luau <luau.exe> --suite upgrade-sync
```

The badge suite owns visual attach/detach, discovery acknowledgement and actual-export
replacement contracts. `upgrade_badge.spec.luau`, included by the upgrade UI runner,
owns aggregate affordability, maxed/unaffordable tracks, threshold rearming, pending
purchase/result handling and membership changes. The scrapbook and badge runners
share an explicit fake-engine fixture; these tests do not simulate Roblox rendering
or physical touch input.

The badge, upgrade UI, menu, scrapbook and PanelManager suites pass. `upgrade-sync`
fails at its existing `jump value and next price` assertion, identically with the
three modified runtime modules restored to HEAD in an isolated baseline copy.
Roblox-aware analysis reports the same 22 CustomerRequests missing-DisplayText
diagnostics before and after this change, with no badge-module diagnostics.
StyLua checks on the feature files and Rojo build pass.

## Studio acceptance still required

Live Studio verification was unavailable in this session. Run each check in desktop
Play and Device Emulator mobile portrait/landscape; use a physical touch device for
input routing when available:

1. Earn across an upgrade's next price with its panel closed: `!` appears. Open the
   panel: it clears immediately. Close: it stays cleared until a newly affordable
   tier/track or another threshold crossing. Check purchase success, rejection and
   timeout without a badge flicker while open.
2. Test only unaffordable tracks, then all tracks maxed with abundant cash: no badge.
3. Discover an ingredient and a special customer with Index closed: `!` appears.
   Open: it clears. Discover while open: it stays hidden, then appears on close.
4. Reimport/replace the Framewisp desktop while unseen state exists: each outer
   button receives exactly one badge with current state; detached buttons are inert.
   Repeat replacing only a button or panel and while a panel is open.
5. Tap/click the center and badge corner of both buttons. Confirm normal open/close,
   exclusive panels, and existing hover/press FX. Check legible badges at the
   smallest supported mobile viewport, without clipping or shifted artwork.
