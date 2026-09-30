--!strict
-- Enter transparent PNG asset IDs here (for example "rbxassetid://123").
-- Keys must be canonical DiscoveryCatalog IDs, never display names.
local ScrapbookArtwork = {
    Ingredients = {} :: { [string]: string },
    SpecialCustomers = {} :: { [string]: string },
}

function ScrapbookArtwork.GetIngredient(id: string): string
    return ScrapbookArtwork.Ingredients[id] or ""
end

function ScrapbookArtwork.GetSpecialCustomer(id: string): string
    return ScrapbookArtwork.SpecialCustomers[id] or ""
end

return ScrapbookArtwork
