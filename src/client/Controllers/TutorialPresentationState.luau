--!strict
-- Local presentation only: no delayed tasks, remotes or gameplay milestones.
local State = {}
local session: any = nil
local character: Model? = nil
local removedCharacter: Model? = nil
local textFinished = false
local initialStashFinished = false
local stashDeadline: number? = nil
local previousStage: any = nil
local counterDeadline: number? = nil
local counterReady = false
function State.CharacterRemoving(model: Model)
    removedCharacter = model
    stashDeadline, counterDeadline = nil, nil
end
function State.CharacterAdded()
    removedCharacter = nil
end
function State.Read(player: Player): (boolean, boolean, string?)
    local nextSession = player:GetAttribute("PlotSessionId")
    if session ~= nextSession then
        session = nextSession
        textFinished, initialStashFinished = false, false
        stashDeadline, previousStage = nil, nil
        counterDeadline, counterReady = nil, false
    end
    if character ~= player.Character then
        character = player.Character
        stashDeadline, counterDeadline = nil, nil
    end
    local stage = player:GetAttribute("TutorialStage")
    local order = player:GetAttribute("TutorialOrderIndex")
    if type(order) == "number" and order > 1 then
        textFinished = true -- Only a new plot session may re-enable instructions.
    end
    if previousStage == "Stash" and stage ~= "Stash" then
        initialStashFinished = true
        stashDeadline = nil
    end
    if stage ~= "Counter" then
        counterDeadline, counterReady = nil, false
    end
    previousStage = stage
    if
        type(stage) == "string"
        and stage ~= "ClaimPlot"
        and stage ~= "Counter"
        and stage ~= "Order"
        and stage ~= "Stash"
    then
        initialStashFinished = true -- Early gameplay never gets an obsolete order-dialogue delay.
    end
    local ready = true
    if stage == "Stash" and order == 1 and not initialStashFinished then
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        if
            not character
            or character == removedCharacter
            or not humanoid
            or humanoid.Health <= 0
            or not character:IsDescendantOf(workspace)
            or player:GetAttribute("TutorialActive") ~= true
        then
            stashDeadline = nil
            ready = false
        else
            if not stashDeadline then
                stashDeadline = os.clock() + 2.5
            end
            ready = os.clock() >= (stashDeadline :: number)
            if ready then
                initialStashFinished = true
                stashDeadline = nil
            end
        end
    end
    if stage == "Counter" and order == 1 and not textFinished then
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        local alive = character ~= nil
            and character ~= removedCharacter
            and character:IsDescendantOf(workspace)
            and humanoid ~= nil
            and humanoid.Health > 0
            and player:GetAttribute("TutorialActive") == true
        if not alive then
            counterDeadline = nil
            ready = false
        elseif not counterReady then
            counterDeadline = counterDeadline or (os.clock() + 3)
            counterReady = os.clock() >= (counterDeadline :: number)
            ready = counterReady
        end
    end
    return not textFinished or stage == "ClaimPlot", ready, if type(stage) == "string" then stage else nil
end
return State
