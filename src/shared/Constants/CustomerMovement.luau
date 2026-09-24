--!strict
return {
    Speed = 8,
    TurnSeconds = 0.2,
    MaxPathAttempts = 3,
    FinalApproachDistance = 3,
    Agent = {
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = false,
        AgentCanClimb = false,
        WaypointSpacing = 3,
        Costs = { CustomerAvoid = math.huge },
    },
}
