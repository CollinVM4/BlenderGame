-- Real service, with engine HealthChanged/Died events and time controlled here.
services.RunService.Heartbeat = signal()
local regen = loadModule("HealthRegenService")
regen.Init()
regen.Init() -- repeated initialization must not multiply passive healing

local function subject(player)
    local p = player or instance("Player")
    local character = instance("Model")
    character.Parent, p.Character = workspaceFake, character
    local health = 100
    local h = setmetatable({
        Parent = character,
        MaxHealth = 100,
        HealthChanged = signal(),
        Died = signal(),
    }, {
        __index = function(_, key)
            return if key == "Health" then health else nil
        end,
        __newindex = function(self, key, value)
            if key == "Health" then
                health = value
                self.HealthChanged:Fire(value)
                if value <= 0 then
                    self.Died:Fire()
                end
            else
                rawset(self, key, value)
            end
        end,
    })
    function character:FindFirstChildOfClass(class)
        return if class == "Humanoid" then h else nil
    end
    regen.ApplyCharacter(p, character)
    return p, h, character
end
local function step(seconds)
    now += seconds
    services.RunService.Heartbeat:Fire(seconds)
end
local function near(actual, expected, message)
    check(math.abs(actual - expected) < 1e-6, message)
end

local p, h = subject()
h.Health = 50
step(9.5)
near(h.Health, 50, "damage prevents regen before ten seconds")
step(1)
near(h.Health, 50.625, "crossing delay only credits time after ten seconds")
step(2)
near(h.Health, 53.125, "passive rate is 1.25 HP per second")
h.Health = 80
step(1)
near(h.Health, 81.25, "intentional healing persists without restarting the damage delay")
h.Health = 70
h.Health = 90 -- damage and a larger heal in the same frame must still reset delay
step(9.9)
near(h.Health, 90, "damage followed by healing between frames resets delay")
step(0.1)
near(h.Health, 90, "the full ten second delay is respected")
step(1)
near(h.Health, 91.25, "regen resumes after subsequent damage delay")
h.MaxHealth = 92
step(1)
near(h.Health, 92, "regen caps at current MaxHealth")
step(1)
near(h.Health, 92, "full health stays full")
h.MaxHealth = 120
h.Health = 110
step(1)
near(h.Health, 111.25, "max-health changes and server healing remain authoritative")
regen.RemovePlayer(p)

for _, cancellation in { "death", "character-removal", "player-removal", "detached", "respawn" } do
    local owner, old, character = subject()
    old.Health = 50
    if cancellation == "death" then
        old.Health = 0
    elseif cancellation == "character-removal" then
        owner.CharacterRemoving:Fire(character)
    elseif cancellation == "player-removal" then
        regen.RemovePlayer(owner)
    elseif cancellation == "detached" then
        old.Parent = nil
    else
        local _, fresh = subject(owner)
        fresh.Health = 75
        old.Health = 0
        owner.CharacterRemoving:Fire(character)
        step(11)
        near(fresh.Health, 76.25, "stale character events cannot cancel replacement regen")
    end
    local stopped = old.Health
    step(11)
    near(old.Health, stopped, cancellation .. " stops regeneration on old humanoid")
    regen.RemovePlayer(owner)
end

local first, a = subject()
local second, b = subject()
a.Health, b.Health = 50, 50
step(5)
b.Health = 40
step(6)
near(a.Health, 51.25, "shared loop regenerates eligible players")
near(b.Health, 40, "shared loop preserves independent damage delays")
regen.RemovePlayer(first)
regen.RemovePlayer(second)
