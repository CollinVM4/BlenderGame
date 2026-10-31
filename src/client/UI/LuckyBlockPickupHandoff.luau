--!strict
-- One rendered owner per PickupId. Replication may deliver identity, art and the
-- terminal state on different frames; none of these authorize server claims.
local Handoff = {}
type Pending = { Release: () -> (), Until: number }
type Public = { Model: Model, Connection: RBXScriptConnection, Ready: boolean, Enabled: { [Instance]: boolean } }
local pending: { [number]: Pending } = {}
local public: { [number]: Public } = {}

local function release(id: number)
    local entry = pending[id]
    pending[id] = nil
    if entry then
        entry.Release()
    end
end
local function visibility(entry: Public, object: Instance, visible: boolean)
    if object:IsA("BasePart") then
        object.LocalTransparencyModifier = if visible then 0 else 1
    elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("Light") then
        local effect = object :: any
        if entry.Enabled[object] == nil then
            entry.Enabled[object] = effect.Enabled
        end
        effect.Enabled = visible and entry.Enabled[object]
        if not visible and object:IsA("ParticleEmitter") then
            object:Clear()
        end
    end
end
function Handoff.Track(model: Model)
    local id = model:GetAttribute("PickupId")
    if typeof(id) ~= "number" or public[id] then
        return
    end
    local entry: Public
    entry = {
        Model = model,
        Ready = false,
        Enabled = {},
        Connection = model.DescendantAdded:Connect(function(object)
            visibility(entry, object, false)
        end),
    }
    public[id] = entry
    for _, object in model:GetDescendants() do
        visibility(entry, object, false)
    end
end
function Handoff.Untrack(model: Model)
    local id = model:GetAttribute("PickupId")
    if typeof(id) ~= "number" then
        return
    end
    local entry = public[id]
    if entry and entry.Model == model then
        entry.Connection:Disconnect()
        public[id] = nil
        release(id)
    end
end
function Handoff.Ready(id: number): boolean
    local entry = public[id]
    return entry ~= nil and entry.Ready
end
function Handoff.Keep(id: number, callback: () -> (), expiresAt: number)
    release(id)
    pending[id] = { Release = callback, Until = expiresAt }
    local entry = public[id]
    local state = entry and entry.Model:GetAttribute("PickupState")
    if (entry and entry.Ready) or state == "Claimed" or state == "Expired" then
        release(id)
    end
end
function Handoff.Step(now: number)
    for id, entry in public do
        local state = entry.Model:GetAttribute("PickupState")
        if state == "Claimed" or state == "Expired" then
            release(id)
            entry.Ready = false
        elseif state == "Available" then
            local expected = entry.Model:GetAttribute("VisualPartCount")
            local visual = entry.Model:FindFirstChild("RewardVisual")
            local count = 0
            if visual then
                for _, object in visual:GetDescendants() do
                    if object:IsA("BasePart") then
                        count += 1
                    end
                end
            end
            if typeof(expected) == "number" and count >= expected and (expected == 0 or visual ~= nil) then
                -- Remove the local prize before exposing any public geometry/effects.
                release(id)
                entry.Ready = true
                for _, object in entry.Model:GetDescendants() do
                    visibility(entry, object, true)
                end
            end
        end
    end
    for id, entry in pending do
        local model = public[id] and public[id].Model
        local expiry = model and model:GetAttribute("ExpiresAt")
        if typeof(expiry) == "number" and expiry > 0 then
            entry.Until = expiry
        end
        if now >= entry.Until then
            release(id)
        end
    end
end
return Handoff
