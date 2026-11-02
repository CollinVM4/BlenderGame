--!strict
return table.freeze({
    -- Creator Hub pass ID, not the asset ID (Collin, 2026-11-02).
    WingsGamePassId = 2021642550,
    OwnershipRetrySeconds = 15,
    RequestInterval = 0.5,
    FlightDurationSeconds = 1.75,
    PoweredAscentVelocity = 22,
    PoweredApproachAccel = 150,
    GlideDescentVelocity = 20,
    GroundedConfirmSeconds = 0.2,
    ClimbToleranceStuds = 15, -- Diagnostic only; external impulses are legitimate.
    PoweredTimeToleranceSeconds = 0.25,
    GlideOverspeedTolerance = 5,
    GlideOverspeedSeconds = 0.25,
    PoweredFlapHz = 6,
    PoweredFlapAmplitudeDegrees = 35,
    GlideBobAmplitudeDegrees = 4,
    DebugLogging = false,
})
