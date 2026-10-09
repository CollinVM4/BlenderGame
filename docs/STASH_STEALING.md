# Stash stealing and protection

Slots 1–2 always reject enemy TAKE. Exposed slots allow enemy TAKE while carry has
room. The first successful theft starts one six-second window for the whole stash;
later thefts do not extend it. At the deadline, exposed slots reject enemies for
thirty seconds. Owners and current teammates can STORE and TAKE during both phases.
Second storage retains its existing unlock and exposed-slot behavior.

Both protected and exposed slots hold three mixed ingredients. TAKE selects the
ripest item first, preserving identity and cumulative stored ripeness. A smoothie
occupies one whole slot and keeps its blend identity and ingredient order. Failed
visual creation or equip restores exact contents and does not start a raid.

Every request explicitly names STORE or TAKE. Enemy STORE is rejected; it never
turns into theft. There is no direction inference, burst timer, or replicated
direction state. InventoryService validates actual plot membership, canonical
prompt/fixture/slot identity, character health/action state, proximity, permissions,
and capacity. Actor revisions and target-session identity prevent stale requests
from reaching recycled plots. Replicated deadlines only drive presentation.

Raid state is keyed by the authoritative plot session ID and removed through the
SessionEnded hook. Deadlines are evaluated on demand, without delayed mutation of
recycled plots. Client availability evaluates replicated deadlines so protection
begins and ends without rebuilding displays or scheduling per-slot timers.

See [Player stash](PLAYER_STASH.md) for controls, validation, and Studio setup.
Test with three clients: two teammates and an enemy. Check mixed exposed-slot theft,
protected rejection, team access during protection, shared deadlines, and plot
reassignment. Studio multiplayer checks have not been run for this pass.
