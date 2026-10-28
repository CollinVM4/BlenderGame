--!strict
-- Local presentation only: no delayed tasks, remotes or gameplay milestones.
local ORDER_READ_SECONDS = 2.5
local State = {}
local session: any = nil
local character: Model? = nil
local removedCharacter: Model? = nil
local beamFinished = false -- Permanent for this onboarding, including respawns and membership changes.
local textFinished = false
local initialStashFinished = false
local stashDeadline: number? = nil
local marketDeadline: number? = nil
local marketReadFinished = false
local marketReadPending = false
local previousStage: any = nil
local counterDeadline: number? = nil
local counterReady = false
function State.CharacterRemoving(model: Model)
    removedCharacter = model
    stashDeadline, counterDeadline, marketDeadline = nil, nil, nil
end
function State.CharacterAdded()
    removedCharacter = nil
end
function State.IsActive(player: Player, stage: string?): boolean
    if stage == "BuyRow" or stage == "Plant" or stage == "Harvest" then
        return player:GetAttribute("TutorialActive") ~= true and player:GetAttribute("FarmTutorialStage") == stage
    end
    return player:GetAttribute("TutorialActive") == true
        and (player:GetAttribute("TutorialHintReady") == true or stage == "ClaimPlot")
end
function State.Read(player: Player): (boolean, boolean, string?, boolean)
    local nextSession = player:GetAttribute("PlotSessionId")
    if session ~= nextSession then
        session = nextSession
        textFinished, initialStashFinished = false, false
        stashDeadline, previousStage = nil, nil
        marketDeadline, marketReadFinished, marketReadPending = nil, false, false
        counterDeadline, counterReady = nil, false
    end
    if character ~= player.Character then
        character = player.Character
        stashDeadline, counterDeadline, marketDeadline = nil, nil, nil
    end
    local stage = player:GetAttribute("TutorialStage")
    local order = player:GetAttribute("TutorialOrderIndex")
    if type(order) == "number" and order > 1 then
        beamFinished = true
        textFinished = true -- Only a new plot session may re-enable instructions.
    end
    if stage == "Complete" then
        beamFinished = true
    end
    if previousStage == "Stash" and stage ~= "Stash" then
        initialStashFinished = true
        stashDeadline = nil
    end
    if stage ~= "Counter" then
        counterDeadline, counterReady = nil, false
    end
    if previousStage == "NextCustomer" and stage == "Market" and not marketReadFinished then
        marketReadPending = true
    end
    if stage ~= "Market" and marketReadPending then
        marketReadFinished, marketReadPending, marketDeadline = true, false, nil
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
                stashDeadline = os.clock() + ORDER_READ_SECONDS
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
    if stage == "Market" and marketReadPending and not marketReadFinished then
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        if
            not character
            or character == removedCharacter
            or not humanoid
            or humanoid.Health <= 0
            or not character:IsDescendantOf(workspace)
            or player:GetAttribute("TutorialActive") ~= true
        then
            marketDeadline = nil
            ready = false
        else
            marketDeadline = marketDeadline or (os.clock() + ORDER_READ_SECONDS)
            ready = os.clock() >= (marketDeadline :: number)
            if ready then
                marketReadFinished, marketReadPending, marketDeadline = true, false, nil
            end
        end
    end
    -- Follow-up guidance bypasses first-order instruction retirement.
    if (stage == "BuyJump" or stage == "BuyBat") and player:GetAttribute("TutorialActive") == true then
        return true, ready, stage, false -- Alert pulses point to upgrades; there is no world target.
    end
    if
        (stage == "NextCustomer" or stage == "Market" or stage == "MarketJump")
        and player:GetAttribute("TutorialActive") == true
    then
        return true, ready, stage, ready
    end
    -- Farm guidance deliberately bypasses opening-only completion latches.
    if player:GetAttribute("TutorialActive") ~= true then
        local farmStage = player:GetAttribute("FarmTutorialStage")
        if farmStage == "BuyRow" or farmStage == "Plant" or farmStage == "Harvest" then
            return true, true, farmStage, true
        end
    end
    return not textFinished or stage == "ClaimPlot",
        ready,
        if type(stage) == "string" then stage else nil,
        not beamFinished and (stage == "ClaimPlot" or order == 1)
end
return State
