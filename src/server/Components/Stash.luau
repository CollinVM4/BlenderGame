--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Presentation = require(script.Parent.StashPresentation)
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy).NormalStash
local Slots = require(script.Parent.Parent.Services.StashSlots)
local CollectionService = game:GetService("CollectionService")
local Stash = {}
function Stash.Init(services: any)
    WorldUtil.BindTag("PlayerStash", function(object)
        local plot = object.Parent
        while plot and not CollectionService:HasTag(plot, "PlayerPlot") do
            plot = plot.Parent
        end
        local expansion = plot and Slots.Expansion(plot)
        local slots = Slots.Resolve(object, expansion)
        local prompts = {}
        local connections = {}
        for index, slot in slots do
            slot:SetAttribute("StashLogicalSlotIndex", index)
            local origin = Instance.new("Attachment")
            origin.Name = "StashPromptOrigin"
            origin.Position = Vector3.new(0, slot.Size.Y / 2 + 0.5, 0)
            origin.Parent = slot
            local prompt = WorldUtil.Prompt(slot, "StashPrompt", "STORE")
            prompt.Style = Enum.ProximityPromptStyle.Custom
            prompt:SetAttribute("InteractionOrigin", origin.Name)
            prompt:SetAttribute("PlayerStashPrompt", true)
            prompts[index] = prompt
            table.insert(
                connections,
                prompt.Triggered:Connect(function(player)
                    local owner = services.TycoonService.GetOwner(object)
                    services.InventoryService.InteractStash(
                        player,
                        index,
                        owner,
                        if index > Config.Slots then expansion else object
                    )
                end)
            )
        end
        local function refresh()
            local owner = services.TycoonService.GetOwner(object)
            local snapshot = owner and services.InventoryService.GetSnapshot(owner)
            local raid = owner and services.InventoryService.GetStashRaidState(owner)
            for index, slot in slots do
                slot:SetAttribute("StashSessionId", raid and raid.SessionId)
                slot:SetAttribute("StashRaidEndsAt", raid and raid.RaidEndsAt or 0)
                slot:SetAttribute("StashProtectionEndsAt", raid and raid.ProtectionEndsAt or 0)
                local enabled = index <= Config.Slots
                    or (expansion ~= nil and expansion:GetAttribute("StashExpansionReady") == true)
                prompts[index].Enabled = enabled
                local state = enabled and snapshot and snapshot.Stash[index]
                slot:SetAttribute("StashOwnerUserId", owner and owner.UserId or 0)
                Presentation.Refresh(slot, state, services.IngredientService)
                prompts[index].ObjectText = (if index <= Config.Protected then "Protected slot " else "Slot ") .. index
                prompts[index].ActionText = if state and state.Count > 0 then "TAKE" else "STORE"
            end
        end
        table.insert(
            connections,
            services.InventoryService.StashChanged:Connect(function()
                refresh()
            end)
        )
        -- Plot assignment and release also refresh empty fixtures for their new owner.
        local ancestor = object.Parent
        while ancestor and ancestor ~= workspace do
            table.insert(connections, ancestor:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh))
            ancestor = ancestor.Parent
        end
        if expansion then
            table.insert(connections, expansion:GetAttributeChangedSignal("StashExpansionReady"):Connect(refresh))
        end
        refresh()
        return function()
            for _, connection in connections do
                connection:Disconnect()
            end
            for _, prompt in prompts do
                prompt:Destroy()
            end
            for _, slot in slots do
                local origin = slot:FindFirstChild("StashPromptOrigin")
                if origin then
                    origin:Destroy()
                end
                Presentation.Clear(slot)
                for _, name in
                    {
                        "StashLogicalSlotIndex",
                        "StashOwnerUserId",
                        "StashSessionId",
                        "StashRaidEndsAt",
                        "StashProtectionEndsAt",
                        "StashIngredientId",
                        "StashItemType",
                        "StashCapacity",
                        "StashCount",
                        "StashProtected",
                    }
                do
                    slot:SetAttribute(name, nil)
                end
            end
        end
    end)
end
return Stash
