--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Presentation = require(script.Parent.StashPresentation)
local Stash = {}
function Stash.Init(services: any)
    WorldUtil.BindTag("PlayerStash", function(object)
        local slots: { [number]: BasePart } = {}
        local counts: { [number]: number } = {}
        for _, part in object:GetDescendants() do
            local index = part:GetAttribute("SlotIndex")
            if part:IsA("BasePart") and type(index) == "number" and index % 1 == 0 and index >= 1 and index <= 5 then
                counts[index] = (counts[index] or 0) + 1
                slots[index] = part
            end
        end
        local prompts = {}
        local connections = {}
        for index, slot in slots do
            if counts[index] ~= 1 then
                warn("[Stash] Duplicate SlotIndex: " .. index)
                slots[index] = nil
                continue
            end
            local prompt = WorldUtil.Prompt(slot, "StashPrompt", "Store ingredient")
            prompt:SetAttribute("PlayerStashPrompt", true)
            prompts[index] = prompt
            table.insert(
                connections,
                prompt.Triggered:Connect(function(player)
                    local owner = services.TycoonService.GetOwner(object)
                    if not owner then
                        return
                    end
                    local id = services.InventoryService.GetHeldIngredientId(player)
                    if id then
                        if owner == player then
                            services.InventoryService.Deposit(player, id, index)
                        end
                    else
                        services.InventoryService.Withdraw(player, index, owner)
                    end
                end)
            )
        end
        local function refresh()
            local owner = services.TycoonService.GetOwner(object)
            local snapshot = owner and services.InventoryService.GetSnapshot(owner)
            for index, slot in slots do
                local state = snapshot and snapshot.Stash[index]
                slot:SetAttribute("StashOwnerUserId", owner and owner.UserId or 0)
                Presentation.Refresh(slot, state, services.IngredientService)
                prompts[index].ObjectText = (if index <= 2 then "Protected slot " else "Slot ") .. index
                prompts[index].ActionText = if state and state.Count > 0
                    then "Take " .. state.IngredientId .. " (" .. state.Count .. "/5)"
                    else "Store ingredient"
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
        refresh()
        return function()
            for _, connection in connections do
                connection:Disconnect()
            end
            for _, prompt in prompts do
                prompt:Destroy()
            end
            for _, slot in slots do
                Presentation.Clear(slot)
                for _, name in { "StashOwnerUserId", "StashIngredientId", "StashCount", "StashProtected" } do
                    slot:SetAttribute(name, nil)
                end
            end
        end
    end)
end
return Stash
