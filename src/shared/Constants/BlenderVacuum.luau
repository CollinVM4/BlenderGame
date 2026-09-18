--!strict
return table.freeze({
    PullStrength = 7, -- velocity response / second near the opening
    CenteringStrength = 6, -- horizontal speed per stud of error
    DownwardBias = 12, -- studs / second; never steer upward
    MaxSpeed = 36, -- desired speed; faster incoming throws brake progressively
    MaxAcceleration = 120, -- maximum assisted velocity change / second
    EdgeStrength = 0.3,
    TargetHeight = 0.5, -- above InputZone's local top surface
    MaxStep = 1 / 30, -- do not snap after a server hitch
})
