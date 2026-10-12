--!strict
return {
    NPCId = "JackedNoob",
    ProteinIngredientId = "Protein",
    ProteinCooldownSeconds = 90,
    RoamIdleMinSeconds = 2,
    RoamIdleMaxSeconds = 6,
    RoamEdgeMargin = 2.5,
    RespawnSeconds = 5,
    InteractionDistance = 10,
    DialogueSeconds = 2.8,
    HitDialogueSeconds = 2,
    HitReactionCooldownSeconds = 0.6,
    -- Reuse the game's customer hurt asset; replace with an approved ID here if needed.
    HurtSoundId = require(script.Parent.GameplayAudio).CustomerHurtSoundId,
    HurtSoundVolume = 0.7,
}
