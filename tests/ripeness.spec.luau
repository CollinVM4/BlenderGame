local item = loadModule("IngredientItem")
local config = loadModule("Ripeness")
local a, b, c = item.New("Strawberry", "a"), item.New("Strawberry", "b"), item.New("Strawberry", "c")
item.EnterStash(a, 0)
item.EnterStash(b, 40)
item.EnterStash(c, 95)
check(
    item.GetStoredRipenessSeconds(a, 110) == 110
        and item.GetStoredRipenessSeconds(b, 110) == 70
        and item.GetStoredRipenessSeconds(c, 110) == 15,
    "identical ingredients age independently"
)
item.ExitStash(b, 80)
check(b.RipenessStoredSeconds == 40 and b.RipenessStoredAt == nil, "exit commits elapsed stash time")
check(item.GetStoredRipenessSeconds(b, 380) == 40, "outside stash time does not age")
item.EnterStash(b, 380)
check(not item.IsRipe(b, 459), "fresh below threshold")
item.Resolve(b, 460)
check(b.IsRipe and item.GetRipenessProgress(b, 460) == 1, "exact threshold promotes permanently")
item.ExitStash(b, 500)
item.EnterStash(b, 900)
check(b.IsRipe and b.RipenessStoredAt == nil, "ripe does not restart aging")
check(config.RipenessSeconds == 120 and config.RipenessValueMultiplier == 1.25, "shared tuning")
check(item.GetIngredientValue(c, 95) == 3000 and item.GetIngredientValue(b, 900) == 3750, "per-item effective value")
check(loadModule("Ingredients").Strawberry.Value == 3000, "base definition stays unchanged")
