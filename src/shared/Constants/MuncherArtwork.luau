--!strict
local Config = require(script.Parent.Muncher)

local Artwork = {
    -- Release gate: enable only after Coverage passes AND group asset access is
    -- verified in the experience. Never fill this map with placeholder asset IDs.
    Enabled = true,
    Images = {
        Apple = "rbxassetid://106569294229540",
        Banana = "rbxassetid://78359736862128",
        Cactus = "rbxassetid://133849462291036",
        Chili_Sauce = "rbxassetid://108253795711463",
        Cinnamon = "rbxassetid://83598863631938",
        Coconut = "rbxassetid://113665140625458",
        Cotton_Candy = "rbxassetid://140047129842756",
        Crab = "rbxassetid://99705354232675",
        Dragon_Fruit = "rbxassetid://105148578625210",
        Fish = "rbxassetid://77060611438747",
        French_Fries = "rbxassetid://77607088686906",
        Golden_Potato = "rbxassetid://74607252660717",
        Golden_Tomato = "rbxassetid://136287344264610",
        Hamburger = "rbxassetid://112617912795291",
        Honey = "rbxassetid://104180995012202",
        Ice = "rbxassetid://98194030668909",
        Mango = "rbxassetid://103038941435909",
        Melon = "rbxassetid://132937154402647",
        Milk = "rbxassetid://126935424802456",
        Mushrooms = "rbxassetid://117970758179337",
        Noob = "rbxassetid://108414816898275",
        Orange = "rbxassetid://100002880320081",
        Peach = "rbxassetid://93642184426380",
        Pear = "rbxassetid://92007525501589",
        Pineapple = "rbxassetid://71262629880405",
        Pizza = "rbxassetid://125277141520341",
        Protein = "rbxassetid://79583795177042",
        Rainbow_Trout = "rbxassetid://136105705915382",
        Rock = "rbxassetid://87147436048787",
        Shell = "rbxassetid://91720805002122",
        Shit = "rbxassetid://99318883645766",
        Squid = "rbxassetid://99306037870535",
        Starfruit = "rbxassetid://94593969183317",
        Steak = "rbxassetid://81810202472100",
        Strawberry = "rbxassetid://93116514538308",
        Sushi = "rbxassetid://101518378306302",
        Tire = "rbxassetid://101855754688475",
        Watermelon = "rbxassetid://86734368031089",
        Worm = "rbxassetid://85735174475853",
    } :: { [string]: string },
}

function Artwork.GetMuncherIngredient(id: string): string
    local uri = Artwork.Images[id]
    return if uri and string.match(uri, "^rbxassetid://[1-9]%d*$") then uri else ""
end

function Artwork.RewardIds(): { string }
    local seen: { [string]: boolean } = {}
    local ids = {}
    for _, pool in Config.RewardPools do
        for _, entry in pool do
            if not seen[entry.Id] then
                seen[entry.Id] = true
                table.insert(ids, entry.Id)
            end
        end
    end
    table.sort(ids)
    return ids
end

function Artwork.Missing(): { string }
    local missing = {}
    for _, id in Artwork.RewardIds() do
        if Artwork.GetMuncherIngredient(id) == "" then
            table.insert(missing, id)
        end
    end
    return missing
end

function Artwork.IsReady(): boolean
    return Artwork.Enabled and #Artwork.Missing() == 0
end

return Artwork
