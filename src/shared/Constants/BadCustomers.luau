--!strict
return {
    -- Relative weights inside the existing special pool; cadence/chance are unchanged.
    ThiefWeight = 0.5,
    FreeloaderWeight = 0.5,
    FreeloaderPayout = -50,
    TheftWindup = 1.2,
    BehaviorTimeout = 35,
    ExitTimeout = 15,
    DismissalResponseHold = 2,
    Reject = {
        LaunchVertical = 320,
        LaunchHorizontal = 12,
        TumbleSpeed = 8,
        MinimumFlight = 0.6,
        RecoveryDelay = 0.75,
        LandingTimeout = 10,
        LandingPoll = 0.1,
        LandingClearance = 1.5,
    },
    Audio = {
        -- Initial reusable cues; replace these IDs after listening in Studio.
        Reject = { SoundId = "rbxassetid://126967734395019", Volume = 1, PlaybackSpeed = 0.8 },
        Thief = { SoundId = "rbxassetid://9113305311", Volume = 0.8, PlaybackSpeed = 0.65 },
    },
    DismissalResponses = {
        "HEY! What did I do?!",
        "Seriously?!",
        "I was going to PAY you!",
        "Wow. Okay.",
        "Worst smoothie stand ever.",
        "Fine! I'm leaving!",
    },
}
