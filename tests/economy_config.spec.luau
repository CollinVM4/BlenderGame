-- Approved catalog and purchase anchors are one shared economy contract.
local catalog = loadModule("Ingredients")
local upgrades = loadModule("Upgrades")
local farm = loadModule("FarmConfig")
local discovery = loadModule("DiscoveryCatalog")
local items = loadModule("IngredientItem")
local eligibility = loadModule("FarmEligibility")
local groups = {
    { 0, 1500, { "Rock", "Worm" } },
    { 0, 2000, { "Apple", "Green_Apple", "Ice" } },
    {
        0,
        2500,
        {
            "Banana",
            "Blueberry",
            "Cabbage",
            "Carrot",
            "Cherries",
            "Grapes",
            "Kiwi",
            "Lemon",
            "Onion",
            "Shit",
            "Strawberry",
        },
    },
    { 0, 3500, { "Mushrooms", "Orange", "Watermelon" } },
    { 0, 4500, { "Protein" } },
    { 1, 3500, { "Cactus", "Tire" } },
    { 1, 4500, { "Chili_Pepper", "Hamburger", "Pear", "Pineapple", "Starfruit" } },
    { 1, 5000, { "Noob" } },
    { 1, 5500, { "French_Fries" } },
    { 1, 6000, { "Honey" } },
    { 1, 6500, { "Steak" } },
    { 2, 5000, { "Shell", "Squid" } },
    { 2, 5500, { "Milk" } },
    { 2, 6000, { "Coconut", "Mango", "Pomegranate" } },
    { 2, 6500, { "Fish" } },
    { 2, 7000, { "Chili_Sauce", "Crab", "Sushi" } },
    { 3, 7000, { "Melon", "Peach" } },
    { 3, 7500, { "Cinnamon" } },
    { 3, 8000, { "Golden_Potato", "Golden_Tomato" } },
    { 3, 8500, { "Cotton_Candy" } },
    { 3, 9000, { "Pizza" } },
    { 0, 10000, { "Player_Head" } },
    { 0, 13000, { "Gummy_Bear" } },
    { 0, 24000, { "Rainbow_Trout" } },
    { 3, 30000, { "Mystery" } },
    { 3, 45000, { "Dragon_Fruit" } },
}
local seen, count = {}, 0
for _, group in groups do
    for _, id in group[3] do
        check(
            not seen[id]
                and catalog[id].Id == id
                and catalog[id].Value == group[2]
                and catalog[id].JumpLocation == group[1],
            "approved canonical value and accessibility: " .. id
        )
        seen[id] = true
        count += 1
    end
end
for id in catalog do
    check(seen[id], "no unpriced catalog definition")
end
check(count == 53, "complete canonical catalog")
for _, id in { "Player_Head", "Gummy_Bear", "Rainbow_Trout", "Mystery", "Dragon_Fruit" } do
    check(not eligibility.CanPlant(catalog[id]), "premium farm opt-out: " .. id)
end
local costs = {
    Jump = { 0, 10000, 60000, 175000 },
    Bat = { 0, 20000, 45000, 125000 },
    CarryCapacity = { 0, 30000, 75000 },
    StackSize = { 0, 100000 },
    SecondStorage = { 0, 140000 },
    BlendSpeed = { 0, 40000, 110000 },
    Payout = { 0, 65000, 160000 },
    MovementSpeed = {
        0,
        2000,
        3000,
        4000,
        5000,
        7000,
        9000,
        12000,
        15000,
        20000,
        26000,
        34000,
        40000,
        47000,
        55000,
        65000,
    },
    SprintStamina = { 0, 1500, 2000, 3000, 4000, 5500, 7500, 10000, 13000, 17000, 22000, 29000, 34000, 40000, 48000 },
}
for id, prices in costs do
    for index, price in prices do
        check(upgrades[id][index].Cost == price, "approved next purchase cost: " .. id)
    end
end
for index, price in { 20000, 55000, 110000 } do
    check(farm.RowPrices[index] == price, "approved farm row price")
end

for _, entry in discovery.GetIngredients() do
    check(entry.Value == catalog[entry.Id].Value, "catalog display reads approved shared value")
    check(
        items.GetIngredientValue(items.New(entry.Id, "price-check"), now) == entry.Value,
        "fresh effective-value lookup agrees with catalog display"
    )
end
