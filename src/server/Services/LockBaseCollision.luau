--!strict
local Helpers = require(script.Parent.PlayerOnlyCollisionService)
local Collision = {}

-- Retain the shared Players/PlayerOnly matrix. Only member character/wall pairs
-- receive exceptions, so members still collide with every OTHER plot's walls.
function Collision.Bind(plot: Instance, walls: { BasePart })
    local members: { [Player]: any } = {}
    local enabled = false
    local api = {}
    for _, wall in walls do
        wall.Transparency = 1
        wall.Anchored = true
        Helpers.SetControlled(wall, false)
    end
    local function remove(player: Player)
        local state = members[player]
        if state then
            for _, connection in state.Connections do
                connection:Disconnect()
            end
            state.Folder:Destroy()
            members[player] = nil
        end
    end
    function api.Refresh(players: { Player })
        for player, state in members do
            if not enabled or not table.find(players, player) or player.Character ~= state.Character then
                remove(player)
            end
        end
        if not enabled then
            return
        end
        for _, player in players do
            local character = player.Character
            if not character or members[player] then
                continue
            end
            local folder = Instance.new("Folder")
            folder.Name = "LockBaseMemberExemptions"
            folder.Parent = plot
            local state: any = { Character = character, Folder = folder, Connections = {}, Parts = {} }
            members[player] = state
            local function add(part: Instance)
                if members[player] ~= state or not part:IsA("BasePart") or state.Parts[part] then
                    return
                end
                local constraints = {}
                for _, wall in walls do
                    local constraint = Instance.new("NoCollisionConstraint")
                    constraint.Part0, constraint.Part1 = wall, part
                    constraint.Parent = folder
                    table.insert(constraints, constraint)
                end
                state.Parts[part] = constraints
            end
            table.insert(state.Connections, character.DescendantAdded:Connect(add))
            table.insert(
                state.Connections,
                character.DescendantRemoving:Connect(function(part)
                    for _, constraint in state.Parts[part] or {} do
                        constraint:Destroy()
                    end
                    state.Parts[part] = nil
                end)
            )
            for _, part in character:GetDescendants() do
                add(part)
            end
        end
    end
    function api.SetLocked(locked: boolean, players: { Player })
        enabled = locked
        -- Exceptions exist before enabling walls. Revocation is synchronous.
        api.Refresh(players)
        for _, wall in walls do
            Helpers.SetControlled(wall, locked)
        end
    end
    function api.Destroy()
        enabled = false
        for _, wall in walls do
            Helpers.ReleaseControlled(wall)
        end
        for player in members do
            remove(player)
        end
    end
    return api
end

return Collision
