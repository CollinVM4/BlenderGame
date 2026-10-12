# Ice Shotgun firing interface

`IceGunController` preserves desktop click-to-fire, the dedicated mobile **Fire**
button, console **RT / R2**, and the existing pointer/center crosshair. Holding
an input does not repeat shots. Mobile placement still uses `MobileControlLayout`
to keep Fire clear of Jump, Sprint, and Throw.

## Cooldown feedback

The shared `IceGunConfig.ShotCooldown` is **4.5 seconds**, enforced by the server.
There is no radial countdown, READY indicator, or permanent cooldown widget.
Each attempt uses the existing server validation; the client only suppresses
pending requests until a response arrives (with the existing 1.5-second timeout).
It does not start its own gameplay cooldown.

`IceGunFire` returns acceptance, firing character, the authoritative server-time
deadline, and an optional rejection reason. Only a `shot cooldown` rejection
shows `Cooldown... 3.2s left`, calculated from the deadline minus current server
time and rounded to one decimal. Other validation failures stay silent. Geometry,
character, entitlement, and gameplay validation precede the cooldown rejection
so an invalid attempt does not receive misleading feedback.

The compact white Fredoka message has a bold black outline and sits below the
crosshair. It briefly pops in scale, drifts upward, and fades over 0.8 seconds.
Repeated rejections refresh one label and restart its animation. Expiry disconnects
the animation listener. Successful shots hide feedback; unequip, death, removal,
and respawn destroy it. No expiry notification appears. Feedback is neither active
nor selectable and cannot capture gameplay or menu input.

## Studio setup and smoke checks

No new authored instances are required; sync with Rojo and retain the existing
weapon, shop, and pass setup. Automated fixtures do not prove engine rendering
or real network replication. Verify in Studio and on devices:

1. Desktop clicks, mobile Fire, and console RT/R2 shoot once, then wait 4.5 seconds.
   Early attempts show accurate remaining time; repeated attempts refresh one message.
   The next shot works immediately after cooldown, without a READY notification.
2. Inspect the compact pop, upward drift, outline, and fade. Check pointer and
   centered aim, phone portrait/landscape and safe insets. Verify no radial UI remains.
3. Use Throw, Sprint, Jump, Shop/Settings, Framewisp menus, and text input while
   equipped. Verify input routing and cursor restoration remain correct.
4. Under network emulation, confirm only server cooldown rejections show feedback;
   blocked muzzle, freeze/stun, and stale-character attempts do not. Attempts must
   neither extend cooldown nor predict successful shot effects.
5. Unequip/re-equip during cooldown, remove/destroy the weapon, and die/respawn.
   Feedback and Fire controls clean up; re-equip preserves server cooldown and
   respawn allows the existing ownership/grant flow without duplicate listeners.

## Focused automated validation

Run `tests/run_state_tests.py` with `--suite icegun-combat --suite icegun-aim
--suite ice-shotgun-results --suite icegun-input --suite icegun-initial-owner
--suite icegun-entitlement`, plus `tests/run_mobile_control_layout_tests.py`.
Run Roblox-aware typecheck, StyLua, and Rojo build on changes.
