--!strict
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Allowed = require(Shared.Constants.ScrapbookPreviews)
local Geometry = require(Shared.IngredientPreviewGeometry)
local Assets = {}

function Assets.Init()
    local previous = Shared:FindFirstChild("ScrapbookPreviewAssets")
    if previous then
        previous:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "ScrapbookPreviewAssets"
    local sources = ServerStorage:FindFirstChild("Ingredients")
    for id in Allowed :: { [string]: boolean } do
        local model = Geometry.Clone(if sources then sources:FindFirstChild(id) else nil)
        if model then
            model.Name = id
            model.Parent = folder
        else
            warn("[Scrapbook] Preview prefab unavailable: " .. id)
        end
    end
    -- Publish only sanitized allowlisted visuals. No remotes or inventory APIs.
    folder.Parent = Shared
end

return Assets
