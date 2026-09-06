--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Stash = {}
function Stash.Init(services: any)
    WorldUtil.BindTag("PlayerStash", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            warn("[Stash] Requires a BasePart")
            return nil
        end
        -- Each optional SlotN part has a fixed server-authored SlotIndex attribute.
        local prompts = {}
        local connections = {}
        for _, slot in object:GetDescendants() do
            local index = slot:GetAttribute("SlotIndex")
            if slot:IsA("BasePart") and type(index) == "number" then
                local prompt = WorldUtil.Prompt(slot, "StashPrompt", "Take one unit")
                table.insert(prompts, prompt)
                table.insert(
                    connections,
                    prompt.Triggered:Connect(function(player)
                        local owner = services.TycoonService.GetOwner(object)
                        if owner == player then
                            services.InventoryService.Withdraw(player, index)
                        elseif owner then
                            services.InventoryService.Steal(player, owner, index)
                        end
                    end)
                )
            end
        end
        return function()
            for _, connection in connections do
                connection:Disconnect()
            end
            for _, prompt in prompts do
                prompt:Destroy()
            end
        end
    end)
end
return Stash
