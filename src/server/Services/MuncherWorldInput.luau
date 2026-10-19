--!strict
-- One server-owned lifecycle/attribution predicate for detection and commit.
local CollectionService = game:GetService("CollectionService")
local WorldUtil = require(script.Parent.WorldUtil)
local Input = {}

function Input.Eligible(services: any, zone: BasePart, object: Instance): (Player?, string?, BasePart?)
    local ancestor: Instance? = object
    while ancestor and ancestor ~= workspace do
        if ancestor:IsA("Tool") or ancestor:IsA("Accessory") or ancestor:FindFirstChildOfClass("Humanoid") then
            return nil, "CarriedIngredient"
        end
        if CollectionService:HasTag(ancestor, "PlayerStash") then
            return nil, "StashedIngredient"
        end
        ancestor = ancestor.Parent
    end
    local record = services.IngredientService.GetRecord(object)
    if not record then
        return nil, "InvalidWorldItem"
    end
    if record.FarmManaged then
        return nil, "FarmCrop"
    end
    if record.MuncherImmune then
        return nil, "OutputImmune"
    end
    if record.Reserved then
        return nil, "AlreadyReserved"
    end
    if not record.Claimable or object:GetAttribute("FrozenUntilPickup") == true then
        return nil, "InvalidWorldItem"
    end
    local actor = record.FeedingActor or record.Owner
    if not actor then
        return nil, "MissingAttribution"
    end
    if record.FeedingActor and record.Owner and record.FeedingActor ~= record.Owner then
        return nil, "UnauthorizedOwner"
    end
    local authority = services.TycoonService
    if
        not authority.IsMember(actor, zone)
        or (record.FeedingSessionId and record.FeedingSessionId ~= authority.GetSessionId(actor))
    then
        return nil, "UnauthorizedOwner"
    end
    local root = WorldUtil.Part(object)
    if not root or root.Anchored then
        return nil, "InvalidWorldItem"
    end
    -- Reject registered items welded outside their own multipart assembly, including
    -- overhead carry rigs. FarmManaged above protects even unanchored crops.
    for _, part in root:GetConnectedParts(true) do
        if part.Anchored or (part ~= object and not part:IsDescendantOf(object)) then
            return nil, "CarriedIngredient"
        end
    end
    return actor, nil, root
end
return Input
