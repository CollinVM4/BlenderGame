local customer = loadModule("CustomerService")
local requestConfig = loadModule("CustomerRequests")
local requests = requestConfig.Definitions
local requestsById = {}
for _, request in requests do
    -- Schema/uniqueness is owned by customer_requests.spec.luau.
    requestsById[request.Id] = request
end
-- Unit-level tag validation accepts arbitrary arrays; these are not serving fixtures.
local function requestResult(ids)
    return { Ingredients = ids, Tags = { "Red", "Sweet", "Cold" } }
end
check(
    customer.ValidateRequest(requestResult({ "Strawberry", "Tire" }), requests[1]),
    "one Red ingredient suffices despite extras"
)
check(customer.ValidateRequest(requestResult({ "Banana" }), requests[2]), "Sweet uses metadata for Banana")
check(customer.ValidateRequest(requestResult({ "Ice" }), requestsById.Cold), "Cold uses metadata for Ice")
check(not customer.ValidateRequest(requestResult({ "Tire" }), requests[1]), "forged result tags cannot satisfy Red")
check(not customer.ValidateRequest(requestResult({}), requests[1]), "empty smoothie fails")
check(not customer.ValidateRequest(requestResult({ "Unknown" }), requests[1]), "unknown ingredient fails closed")
local combined =
    { Id = "RedCold", DisplayText = "Red and cold", RequiredTags = { "Red", "Cold" }, BasePayout = 40, MinJumpTier = 3 }
check(
    customer.ValidateRequest(requestResult({ "Strawberry", "Ice" }), combined),
    "combined request accepts tags across ingredients"
)
check(not customer.ValidateRequest(requestResult({ "Strawberry" }), combined), "combined request requires every tag")

-- One authoritative home for required/forbidden tag semantics.
local function validate(required, forbidden, ingredients, expected, reason)
    local request = {
        Id = "Validation",
        DisplayText = "Test",
        RequiredTags = required,
        ForbiddenTags = forbidden,
        BasePayout = 50,
        MinJumpTier = 0,
    }
    local success, actualReason = customer.ValidateRequest(requestResult(ingredients), request)
    check(success == expected, "request matches expected outcome: " .. actualReason)
    if reason then
        check(actualReason == reason, "diagnostic distinguishes the failure")
    end
end
validate({ "Sweet" }, nil, { "Strawberry" }, true)
validate({ "Sweet" }, {}, { "Strawberry" }, true)
validate({ "Sweet", "Cold" }, nil, { "Strawberry" }, false, "Missing required tag: Cold")
validate({ "Sweet", "Cold" }, nil, { "Strawberry", "Ice" }, true)
validate({ "Sweet", "Fruit" }, nil, { "Strawberry" }, true)
validate({ "Sweet" }, { "Spicy" }, { "Strawberry", "Banana" }, true)
validate({ "Sweet" }, { "Spicy" }, { "Strawberry", "Chili_Pepper" }, false, "Contains forbidden tag: Spicy")
validate({ "Sweet", "Cold" }, { "Spicy" }, { "Strawberry", "Ice" }, true)
validate(
    { "Sweet", "Cold" },
    { "Spicy" },
    { "Strawberry", "Ice", "Chili_Pepper" },
    false,
    "Contains forbidden tag: Spicy"
)
validate(
    { "sWeEt", "COLD" },
    { "sPiCy", "mILk" },
    { "Strawberry", "Ice", "Milk" },
    false,
    "Contains forbidden tag: mILk"
)
validate({ "sWeEt", "COLD" }, { "sPiCy" }, { "Strawberry", "Ice" }, true)
validate({ "Cold" }, { "fast food" }, { "Ice", "Hamburger" }, false, "Contains forbidden tag: fast food")
validate({ "Sweet" }, { "SWEET" }, { "Strawberry" }, false, "Contains forbidden tag: SWEET")
validate({}, nil, { "Strawberry" }, false, "Empty request")

local function ingredientRequest(requiredIngredients, forbiddenIngredients, exactIngredients, requiredTags, forbiddenTags)
    return {
        Id = "IngredientValidation",
        DisplayText = "Test",
        RequiredTags = requiredTags or {},
        ForbiddenTags = forbiddenTags,
        RequiredIngredients = requiredIngredients,
        ForbiddenIngredients = forbiddenIngredients,
        ExactIngredients = exactIngredients,
        BasePayout = 50,
        MinJumpTier = 0,
    }
end
local function validateIngredients(requiredIngredients, forbiddenIngredients, exactIngredients, ids, expected, reason, requiredTags, forbiddenTags)
    local success, actualReason = customer.ValidateRequest(
        requestResult(ids),
        ingredientRequest(requiredIngredients, forbiddenIngredients, exactIngredients, requiredTags, forbiddenTags)
    )
    check(success == expected, "ingredient request matches expected outcome: " .. actualReason)
    if reason then
        check(actualReason == reason, "ingredient diagnostic distinguishes the failure")
    end
end

validateIngredients({ "Apple", "Ice" }, nil, nil, { "Apple", "Ice", "Banana" }, true)
validateIngredients({ "Apple", "Lemon" }, nil, nil, { "Apple", "Banana", "Ice" }, false, "Missing required ingredient: Lemon")
validateIngredients({ "Apple" }, nil, nil, { "Apple", "Banana" }, true, nil, { "Sweet" })
validateIngredients({ "Apple" }, nil, nil, { "Apple", "Ice" }, false, "Missing required tag: Sweet", { "Sweet" })
validateIngredients(nil, { "Banana" }, nil, { "Apple", "Banana" }, false, "Contains forbidden ingredient: Banana", { "Fruit" })
validateIngredients({ "Apple" }, { "Banana" }, nil, { "Apple", "Banana" }, false, "Contains forbidden ingredient: Banana", { "Fruit" }, { "Milk" })
validateIngredients({ "Apple", "Banana", "Ice" }, nil, true, { "Ice", "Apple", "Banana" }, true)
validateIngredients({ "Apple", "Banana", "Ice" }, nil, true, { "Apple", "Banana", "Ice", "Strawberry" }, false, "Exact ingredient mismatch")
validateIngredients({ "Apple", "Banana", "Ice" }, nil, true, { "Apple", "Banana" }, false, "Missing required ingredient: Ice")
validateIngredients({ "Apple", "Apple", "Ice" }, nil, nil, { "Apple", "Ice" }, false, "Missing required ingredient: Apple")
validateIngredients({ "Apple", "Apple", "Ice" }, nil, true, { "Ice", "Apple", "Apple" }, true)
validateIngredients(nil, nil, true, { "Apple" }, false, "ExactIngredients requires at least one RequiredIngredient")

local invalidDefinition = ingredientRequest({ "Strawbery", "Fish" }, { "Bananna" }, nil, { "Fruit" })
invalidDefinition.MinJumpTier = 0
local definitionDiagnostics = customer.ValidateRequestDefinition(invalidDefinition)
check(table.find(definitionDiagnostics, "Unknown required ingredient: Strawbery") ~= nil, "invalid required ingredient is diagnosed")
check(table.find(definitionDiagnostics, "Unknown forbidden ingredient: Bananna") ~= nil, "invalid forbidden ingredient is diagnosed")
check(
    table.find(definitionDiagnostics, "Required ingredient Fish needs JumpLocation 2, above MinJumpTier 0") ~= nil,
    "required ingredient above request tier is diagnosed without rewriting the request"
)
check(invalidDefinition.MinJumpTier == 0, "definition validation leaves authored tier unchanged")
check(customer.ValidateRequest(requestResult({ "Steak" }), requestsById.Caseoh), "lowercase special Protein tag works")
check(customer.ValidateRequest(requestResult({ "Tire" }), requestsById.Prankster), "lowercase special Weird tag works")
check(requestConfig.GetForNPC("Caseoh") == nil, "CustomerId remains case-sensitive")
check(requestConfig.GetForNPC("caseoh") == requestsById.Caseoh, "exact CustomerId still maps")

-- Catalog witnesses are examples, never recipes enforced by gameplay.
-- Physical access at these tiers depends on the Studio-authored spawn locations.
local witnesses = {
    SweetCold = { 1, { "Strawberry", "Ice", "Banana" } },
    FruitProtein = { 1, { "Strawberry", "Hamburger", "Banana" } },
    GreenSpicy = { 1, { "Green_Apple", "Chili_Pepper", "Banana" } },
    SweetNoSpicy = { 2, { "Strawberry", "Ice", "Banana" } },
    FruitNoMilk = { 2, { "Strawberry", "Ice", "Banana" } },
    ColdNoFastFood = { 2, { "Strawberry", "Ice", "Banana" } },
    SweetColdNoSpicy = { 3, { "Strawberry", "Ice", "Banana" } },
    FruitGreenNoMilk = { 3, { "Green_Apple", "Strawberry", "Banana" } },
}
for id, witness in witnesses do
    local request = requestsById[id]
    check(
        request and request.MinJumpTier == witness[1] and not request.NPCOnly,
        "advanced normal request has intended tier: " .. id
    )
    check(
        customer.ValidateRequest(requestResult(witness[2]), request),
        "catalog permits a three-ingredient example: " .. id
    )
end
