--!strict
return table.freeze({
    RecentSeconds = 25,
    SampleSeconds = 0.4,
    ObserveSeconds = 2,
    RecoveryGraceSeconds = 2,
    AbnormalSeconds = 5,
    MaxDisplacement = 0.3,
    MaxSpeed = 1.5,
    IntentExpirySeconds = 0.9,
    RequestIntervalSeconds = 1,
    CooldownSeconds = 12,
    VerticalLift = 10,
    BodyClearanceInset = 0.05,
    FeedbackSeconds = 3,
})
