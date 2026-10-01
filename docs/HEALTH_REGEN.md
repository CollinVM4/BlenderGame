# Passive health regeneration

The repository uses standard Roblox player characters: `init.server.luau`
attaches services through `CharacterAdded`, while CharacterPhysicsService
normalizes the spawned avatar. There is no custom character loader or other
health-regeneration script in the source tree. Previously, the Rojo project
provided no `StarterCharacterScripts.Health` replacement.

Roblox's [Humanoid documentation](https://create.roblox.com/docs/reference/engine/classes/Humanoid#Health)
specifies an empty Script named `Health` in `StarterCharacterScripts` to disable
default regeneration. `default.project.json` now maps the comment-only
`src/character/Health.server.luau` to that exact location and name. This replaces
the default script on spawn; an every-frame shadow-health clamp is unnecessary.

HealthRegenService observes `HealthChanged` decreases and waits **10 seconds**
after the latest decrease, then adds **1.25 HP/sec**, capped at current MaxHealth.
The previous event value is only an observation baseline, never a health value
written back to the Humanoid. Intentional server healing persists and does not
restart the delay. Damage followed by healing between frames still resets it.
There is no healing gameplay or special healing API in this change: server
systems can update Humanoid.Health directly.

One guarded Heartbeat connection updates all players. Death, character removal,
player removal, replacement and detached Humanoids retire their state and
connections. FallDamageService's TakeDamage calls are observed through the same
health signal; CombatService and RagdollService require no changes.

## Validation and Studio setup

Run `python tests/run_state_tests.py --luau <luau.exe> --suite health-regen
--suite fall-damage --suite combat`. Health-regen owns the passive timing,
intentional healing, MaxHealth and lifecycle contracts. Engine doubles cannot
verify Roblox's injected scripts or physical ragdoll behavior.

Sync the updated Rojo project **before starting a fresh Play session**. The
built hierarchy must contain a server Script named `Health` directly under
StarterPlayer/StarterCharacterScripts. Existing running characters must respawn
or the session must restart to receive the replacement.

Studio smoke checks (not performed by the CLI tests):

- Inspect a spawned character and its replacement `Health` script; verify no
  additional authored regeneration script exists in the Studio place.
- Apply server damage: health remains unchanged for ten seconds, then rises
  1.25 HP each second. Repeat after a fall and a bat-induced ragdoll landing.
- Heal from the server during the delay and during regen; healing persists.
  Damage again and verify a fresh ten-second delay.
- Die/reset and respawn; confirm the override is present again and regen works
  on the new character only.
