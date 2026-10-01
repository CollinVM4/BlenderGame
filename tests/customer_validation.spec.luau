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
-- Wildcards accept every catalog ingredient, without bypassing other constraints.
for id in loadModule("Ingredients") do
    validate({ "*" }, nil, { id }, true)
end
validate({ "*" }, nil, {}, false, "Empty smoothie")
validate({ "*" }, nil, { "Unknown" }, false, "Unknown ingredient: Unknown")
validate({ "*", "Cold" }, nil, { "Strawberry" }, false, "Missing required tag: Cold")
validate({ "*", "Cold" }, nil, { "Ice" }, true)
validate({ "*" }, { "Spicy" }, { "Chili_Pepper" }, false, "Contains forbidden tag: Spicy")
check(customer.ValidateRequest(requestResult({ "Banana" }), requestsById.Nathan), "Nathan accepts a non-blue smoothie")

local function ingredientRequest(
    requiredIngredients,
    forbiddenIngredients,
    exactIngredients,
    requiredTags,
    forbiddenTags
)
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
local function validateIngredients(
    requiredIngredients,
    forbiddenIngredients,
    exactIngredients,
    ids,
    expected,
    reason,
    requiredTags,
    forbiddenTags
)
    local success, actualReason = customer.ValidateRequest(
        requestResult(ids),
        ingredientRequest(requiredIngredients, forbiddenIngredients, exactIngredients, requiredTags, forbiddenTags)
    )
    check(success == expected, "ingredient request matches expected outcome: " .. actualReason)
    if reason then
        check(actualReason == reason, "ingredient diagnostic distinguishes the failure")
    end
end

local alternatives = { { "Apple", "Green_Apple" }, "Banana", "Ice" }
validateIngredients(alternatives, nil, true, { "Apple", "Banana", "Ice" }, true)
validateIngredients(alternatives, nil, true, { "Green_Apple", "Banana", "Ice" }, true)
validateIngredients(
    alternatives,
    nil,
    true,
    { "Apple", "Green_Apple", "Banana", "Ice" },
    false,
    "Exact ingredient mismatch"
)
validateIngredients(alternatives, nil, true, { "Strawberry", "Banana", "Ice" }, false)
validateIngredients(alternatives, nil, false, { "Apple", "Green_Apple", "Banana", "Ice" }, true)
validateIngredients({ { "Apple", "Green_Apple" }, "Apple" }, nil, true, { "Apple", "Green_Apple" }, true)
validateIngredients({ { "Apple", "Green_Apple" }, "Apple" }, nil, false, { "Apple" }, false)
validateIngredients({ { "Apple", "Green_Apple" }, { "Apple", "Green_Apple" } }, nil, true, { "Apple", "Apple" }, true)
validateIngredients({ {} }, nil, false, { "Apple" }, false)
check(
    customer.ValidateRequest(requestResult({ "Green_Apple", "Banana", "Ice" }), requestsById.AppleBananaIce),
    "authored recipe supports green apple"
)
local accessibleGroup = ingredientRequest({ { "Fish", "Apple", "Unknown" } })
local groupDiagnostics = customer.ValidateRequestDefinition(accessibleGroup)
check(
    #groupDiagnostics == 1 and groupDiagnostics[1] == "Unknown required ingredient: Unknown",
    "accessible alternative suppresses tier warning but retains unknown ID warning"
)
check(
    #customer.ValidateRequestDefinition(ingredientRequest({ { "Fish", "Squid" } })) == 1,
    "inaccessible alternatives produce one group warning"
)
check(#customer.ValidateRequestDefinition(ingredientRequest({ {} })) == 1, "empty alternative group is diagnosed")

validateIngredients({ "Apple", "Ice" }, nil, nil, { "Apple", "Ice", "Banana" }, true)
validateIngredients(
    { "Apple", "Lemon" },
    nil,
    nil,
    { "Apple", "Banana", "Ice" },
    false,
    "Missing required ingredient: Lemon"
)
validateIngredients({ "Apple" }, nil, nil, { "Apple", "Banana" }, true, nil, { "Sweet" })
validateIngredients({ "Apple" }, nil, nil, { "Apple", "Ice" }, false, "Missing required tag: Sweet", { "Sweet" })
validateIngredients(
    nil,
    { "Banana" },
    nil,
    { "Apple", "Banana" },
    false,
    "Contains forbidden ingredient: Banana",
    { "Fruit" }
)
validateIngredients(
    { "Apple" },
    { "Banana" },
    nil,
    { "Apple", "Banana" },
    false,
    "Contains forbidden ingredient: Banana",
    { "Fruit" },
    { "Milk" }
)
validateIngredients({ "Apple", "Banana", "Ice" }, nil, true, { "Ice", "Apple", "Banana" }, true)
validateIngredients(
    { "Apple", "Banana", "Ice" },
    nil,
    true,
    { "Apple", "Banana", "Ice", "Strawberry" },
    false,
    "Exact ingredient mismatch"
)
validateIngredients(
    { "Apple", "Banana", "Ice" },
    nil,
    true,
    { "Apple", "Banana" },
    false,
    "Missing required ingredient: Ice"
)
validateIngredients(
    { "Apple", "Apple", "Ice" },
    nil,
    nil,
    { "Apple", "Ice" },
    false,
    "Missing required ingredient: Apple"
)
validateIngredients({ "Apple", "Apple", "Ice" }, nil, true, { "Ice", "Apple", "Apple" }, true)
validateIngredients(nil, nil, true, { "Apple" }, false, "ExactIngredients requires at least one RequiredIngredient")

local invalidDefinition = ingredientRequest({ "Strawbery", "Fish" }, { "Bananna" }, nil, { "Fruit" })
invalidDefinition.MinJumpTier = 0
local definitionDiagnostics = customer.ValidateRequestDefinition(invalidDefinition)
check(
    table.find(definitionDiagnostics, "Unknown required ingredient: Strawbery") ~= nil,
    "invalid required ingredient is diagnosed"
)
check(
    table.find(definitionDiagnostics, "Unknown forbidden ingredient: Bananna") ~= nil,
    "invalid forbidden ingredient is diagnosed"
)
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

local function gradingRequest(requiredTags, requiredIngredients, exact, forbiddenTags, forbiddenIngredients)
    return {
        Id = "Grading",
        DisplayText = "Test order",
        RequiredTags = requiredTags or {},
        RequiredIngredients = requiredIngredients,
        ExactIngredients = exact,
        ForbiddenTags = forbiddenTags,
        ForbiddenIngredients = forbiddenIngredients,
        BasePayout = 25,
        MinJumpTier = 0,
    }
end
local function gradeFor(ids, request)
    return customer.EvaluateOrder(requestResult(ids), request).Grade
end

local red = gradingRequest({ "Red" })
check(gradeFor({ "Strawberry", "Cherries", "Apple" }, red) == "A", "three tag matches grade A")
check(gradeFor({ "Strawberry", "Cherries", "Tire" }, red) == "B", "two tag matches grade B")
check(gradeFor({ "Strawberry", "Tire", "Rock" }, red) == "C", "one tag match grades C")
check(gradeFor({ "Tire", "Rock", "Onion" }, red) == "D", "zero tag matches grade D")

local sweetRed = gradingRequest({ "Sweet", "Red" })
check(gradeFor({ "Strawberry", "Cherries", "Apple" }, sweetRed) == "A", "three matches cover both requested tags")
check(gradeFor({ "Strawberry", "Banana", "Tire" }, sweetRed) == "B", "two matches can cover both requested tags")
check(gradeFor({ "Banana", "Tire", "Rock" }, sweetRed) == "C", "one match with a missing tag grades C")
check(gradeFor({ "Banana", "Banana", "Banana" }, sweetRed) == "C", "three matches cannot hide an uncovered tag")
check(gradeFor({ "Tire", "Rock", "Onion" }, sweetRed) == "D", "no useful multi-tag matches grade D")

local mushroom = gradingRequest({}, { "Mushrooms" })
check(gradeFor({ "Mushrooms", "Mushrooms", "Mushrooms" }, mushroom) == "A", "three requested ingredients grade A")
check(gradeFor({ "Mushrooms", "Mushrooms", "Apple" }, mushroom) == "B", "two requested ingredients grade B")
check(gradeFor({ "Mushrooms", "Apple", "Tire" }, mushroom) == "C", "one requested ingredient grades C")
check(gradeFor({ "Apple", "Tire", "Rock" }, mushroom) == "D", "no requested ingredients grade D")

local exactRecipe = gradingRequest({}, { "Apple", "Banana", "Ice" }, true)
check(gradeFor({ "Apple", "Banana", "Ice" }, exactRecipe) == "A", "three exact slots grade A")
check(gradeFor({ "Apple", "Banana", "Tire" }, exactRecipe) == "B", "two exact slots grade B")
check(gradeFor({ "Apple", "Tire", "Rock" }, exactRecipe) == "C", "one exact slot grades C")
check(gradeFor({ "Tire", "Rock", "Onion" }, exactRecipe) == "D", "no exact slots grade D")
check(
    gradeFor(
        { "Green_Apple", "Banana", "Ice" },
        gradingRequest({}, { { "Apple", "Green_Apple" }, "Banana", "Ice" }, true)
    ) == "A",
    "an exact alternative group counts as one slot"
)

local forbiddenApple = gradingRequest({ "Red" }, nil, nil, nil, { "Apple" })
local restricted = customer.EvaluateOrder(requestResult({ "Strawberry", "Cherries", "Apple" }), forbiddenApple)
check(
    restricted.Grade == "D" and restricted.RestrictionViolated,
    "a forbidden ingredient overrides three strong matches"
)
local forbiddenSweet = customer.EvaluateOrder(
    requestResult({ "Strawberry", "Cherries", "Apple" }),
    gradingRequest({ "Red" }, nil, nil, { "Sweet" })
)
check(forbiddenSweet.Grade == "D" and forbiddenSweet.RestrictionViolated, "a forbidden tag forces D")

local wildcard = customer.EvaluateOrder(requestResult({ "Banana", "Banana", "Banana" }), {
    Id = "Wildcard",
    DisplayText = "Surprise me",
    RequiredTags = {},
    BasePayout = 25,
    MinJumpTier = 0,
    Wildcard = true,
})
check(
    wildcard.IsValid and wildcard.IsFulfilled and wildcard.IsWildcard,
    "wildcard accepts any valid three-ingredient smoothie"
)
check(wildcard.Grade == nil, "wildcard has no letter grade")
local economy = loadModule("Economy")
check(
    economy.GradeMultiplier.A == 1.25
        and economy.GradeMultiplier.B == 1.1
        and economy.GradeMultiplier.C == 0.9
        and economy.GradeMultiplier.D == 0.15,
    "grade fulfillment multipliers match the provisional values"
)
