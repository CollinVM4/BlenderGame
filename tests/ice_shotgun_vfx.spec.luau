local vfx = loadModule("IceShotgunPresentationController")
vfx.Init()
vfx.Init()
flush()
local function shot(hits, origin)
    return {
        Origin = origin or vec(0, 1, -2),
        Radius = config.BlastRadius,
        Stage = "Surge",
        ShooterUserId = localPlayer.UserId,
        ServerTime = workspaceFake:GetServerTimeNow(),
        Hits = hits or {},
    }
end
check(#childrenNamed(workspaceFake, "IceShotgunBlast") == 0, "initialization never predicts a blast")
local unknown = shot()
unknown.Stage = "Unknown"
check(not vfx.Play(unknown), "unknown stage is rejected")
check(playerGui:FindFirstChild("IceRayCasterSurge") == nil, "invalid events cannot show a caster surge cue")
local init = shot()
init.Stage, init.Radius = "Init", config.InitBlastRadius
setup(vfx.Play(init), "init visual")
check(playerGui:FindFirstChild("IceRayCasterSurge") == nil, "initial charge never shows the surge cue")
local heldBlast = childrenNamed(workspaceFake, "IceShotgunBlast")[1]
local replaced = heldBlast
setup(vfx.Play(init), "replacement init")
heldBlast = childrenNamed(workspaceFake, "IceShotgunBlast")[1]
check(
    replaced.Destroyed and #childrenNamed(workspaceFake, "IceShotgunBlast") == 1,
    "new init replaces previous held blast"
)
local heldPulse = heldBlast:FindFirstChild("IceRadialPulse")
check(heldPulse.Material == "Ice" and heldPulse.Transparency == 0.25, "icy pulse material and opacity")
advance(0.5)
check(
    heldPulse.Size.X == config.InitBlastRadius * 2 and heldPulse.Transparency == 0.25,
    "small sphere holds through charge"
)
-- Fill every remaining slot before surge: reuse must bypass allocation budget.
for i = 2, presentationConfig.MaxActiveBlasts do
    local other = shot()
    other.ShooterUserId = localPlayer.UserId + i
    setup(vfx.Play(other), "other shooter at active budget")
end
setup(vfx.Play(shot(nil, vec(3, 1, 0))), "surge reuses init")
check(
    #childrenNamed(workspaceFake, "IceShotgunBlast") == presentationConfig.MaxActiveBlasts
        and heldBlast:FindFirstChild("IceRadialPulse") == heldPulse,
    "surge reuses model and sphere without another active slot"
)
check(heldPulse.CFrame.Position.X == 3, "reused surge moves to current server origin")
check(heldPulse.Size.X == 2, "surge restarts at the caster instead of the held init sphere's radius")
local surgeFrost = emitted[#emitted].Emitter
check(
    surgeFrost.Parent.ClassName == "Attachment"
        and surgeFrost.Parent.Parent == heldPulse
        and emitted[#emitted].Count == presentationConfig.SurgeFrostCount,
    "stronger surge frost emits from a point at the caster rather than the sphere volume"
)
advance(0.11)
check(heldPulse.Size.X == config.BlastRadius * 2, "surge expands reused sphere to full diameter")
advance(0.24)
check(heldPulse.Transparency == 1, "surge fades after expansion")
advance(0.31)
check(heldBlast.Destroyed, "surge resets bounded expiry")
init.ServerTime = workspaceFake:GetServerTimeNow()
setup(vfx.Play(init), "cancelled init visual")
advance(1.16)
check(#childrenNamed(workspaceFake, "IceShotgunBlast") == 0, "cancelled init expires without surge")
-- Reset audio observations before the existing fallback and budget contracts.
table.clear(playedSounds)
table.clear(emitted)
resultRemote.OnClientEvent:Fire(shot({ { Position = vec(0, 1, -12), UserId = 7, Frozen = true } }))
local blast = childrenNamed(workspaceFake, "IceShotgunBlast")[1]
check(blast ~= nil, "server-confirmed result renders a blast")
check(
    blast:FindFirstChild("IceRadialPulse")
        and blast:FindFirstChild("IceShard")
        and blast:FindFirstChild("IceImpact")
        and blast:FindFirstChild("IceConePanel") == nil,
    "radial pulse, shards and confirmed impact render together, with no cone"
)
check(
    playerGui:FindFirstChild("IceShotgunHitFeedback"):FindFirstChild("ConfirmedHit").TextColor3
        == presentationConfig.Blue,
    "confirmed new freeze gives blue shooter hit feedback"
)
for _, object in blast:GetDescendants() do
    if object:IsA("Part") or object:IsA("WedgePart") then
        check(
            object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,
            "local effect cannot affect combat rays, contacts or movement"
        )
    end
end
check(
    playedSounds[1] == presentationConfig.FallbackSoundId
        and emitted[1].Emitter.Texture == presentationConfig.FallbackTexture,
    "unavailable imported assets use immediate icy sound/particle fallbacks"
)
local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
local emitter = root:FindFirstChild("IceRayCastEmitter")
local clip = emitter and emitter:FindFirstChild("IceRayCast")
check(
    clip
        and clip.Volume == 0.3
        and clip.RollOffMinDistance == 6
        and clip.RollOffMaxDistance == 60
        and clip.RollOffMode == "InverseTapered",
    "quiet cast follows caster with explicit distance attenuation"
)
advance(0.12)
local pulse = blast:FindFirstChild("IceRadialPulse")
check(pulse.Size.Magnitude > 5 and pulse.Transparency < 1, "pulse rapidly expands while still translucent")
check(pulse.Size.X == config.BlastRadius * 2, "pulse diameter is exactly twice the server blast radius")
advance(0.24)
check(
    pulse.Transparency == 1 and playerGui:FindFirstChild("IceShotgunHitFeedback") == nil,
    "pulse and hit feedback fade promptly"
)
advance(0.3)
check(blast.Destroyed, "blast objects expire within the configured short lifetime")

services.UserInputService.PreferredInput = "Touch"
local many = {}
for i = 1, 20 do
    table.insert(many, { Position = vec(i * 0.1, 1, -10), UserId = i, Frozen = false })
end
setup(vfx.Play(shot(many)), "mobile confirmed shot")
check(#playedSounds == 2, "AoE impacts add no duplicate audio on top of authoritative freeze sounds")
local mobileBlast = childrenNamed(workspaceFake, "IceShotgunBlast")[1]
check(
    #childrenNamed(mobileBlast, "IceImpact") == presentationConfig.MobileMaxImpactEffects,
    "large multiplayer hit lists obey the mobile impact budget"
)
check(
    mobileBlast
        :FindFirstChild("IceRadialPulse")
        :FindFirstChild("IceFrostOrigin")
        :FindFirstChild("ShotgunFrost").EmittedCount == presentationConfig.MobileSurgeFrostCount,
    "mobile surge center uses the reduced surge frost budget"
)
setup(vfx.Play(shot()), "second mobile shot")
check(
    not vfx.Play(shot())
        and #childrenNamed(workspaceFake, "IceShotgunBlast") == presentationConfig.MobileMaxActiveBlasts,
    "simultaneous remote shots cannot exceed the mobile blast budget"
)
advance(presentationConfig.Lifetime + 0.01)
check(#childrenNamed(workspaceFake, "IceShotgunBlast") == 0, "mobile budget releases after effect expiry")
-- Remote cast geometry is built from the event origin, even if the caster
-- character is not streamed in on this client.
for _, input in { "KeyboardAndMouse", "Touch" } do
    services.UserInputService.PreferredInput = input
    for _, stage in { "Init", "Surge" } do
        local crossMap = shot(nil, vec(1500, 1, 0))
        crossMap.ShooterUserId, crossMap.Stage = -999, stage
        crossMap.Radius = if stage == "Init" then config.InitBlastRadius else config.BlastRadius
        check(vfx.Play(crossMap), "both cross-map blast stages render on desktop and mobile without a caster model")
    end
    advance(presentationConfig.Lifetime + 0.01)
    check(not vfx.Play(shot(nil, vec(2049, 1, 0))), "blasts past the extended draw range are still culled")
end
local stale = shot()
stale.ServerTime -= 2
check(not vfx.Play(stale), "late confirmed events do not replay obsolete effects")
local malformed = shot()
malformed.Radius = vec(0 / 0, 0, -1)
check(
    not vfx.Play(malformed) and not vfx.Play({ Target = localPlayer }),
    "invalid cosmetic messages do not allocate effects"
)
local zeroRadius = shot()
zeroRadius.Radius = 0
check(not vfx.Play(zeroRadius), "zero-radius cosmetic messages do not allocate effects")

vfx.Destroy()
preloadMode = "success"
vfx.Init()
flush()
setup(
    vfx.Play(shot({ { Position = vec(0, 1, -12), UserId = localPlayer.UserId, Frozen = false } })),
    "successful sound preload shot"
)
check(
    playedSounds[#playedSounds] == presentationConfig.ShotSoundId,
    "cast uses original imported Launch after successful preload"
)
check(
    playerGui:FindFirstChild("IceShotgunHitFeedback"):FindFirstChild("FrostFlash") ~= nil,
    "confirmed victim hit gives a brief noninteractive frost flash"
)
localPlayer.CharacterRemoving:Fire(localPlayer.Character)
check(playerGui:FindFirstChild("IceShotgunHitFeedback") == nil, "respawn retires local impact feedback")
vfx.Destroy()
check(#childrenNamed(workspaceFake, "IceShotgunBlast") == 0, "controller teardown retires all short-lived effects")
preloadMode = "error"
vfx.Init()
flush()
check(vfx.Play(shot()), "preload exceptions cannot prevent confirmed visuals")
vfx.Destroy()

-- The caster can see the surge from inside its sphere, even on a miss and
-- when nearby players have exhausted the world-effect allocation budget.
vfx.Init()
flush()
for index = 1, presentationConfig.MobileMaxActiveBlasts do
    local other = shot()
    other.ShooterUserId += index
    setup(vfx.Play(other), "remote blast fills mobile budget")
end
check(playerGui:FindFirstChild("IceRayCasterSurge") == nil, "other players never trigger the caster cue")
check(not vfx.Play(shot()), "world blast budget remains enforced")
local cue = playerGui:FindFirstChild("IceRayCasterSurge")
check(cue ~= nil, "confirmed local surge remains visible inside its sphere on a miss at full world budget")
local ring = cue:FindFirstChild("SurgeRing")
check(
    ring.Position.X.Offset == workspaceFake.CurrentCamera.ViewportSize.X * 0.5
        and ring.Position.Y.Offset == workspaceFake.CurrentCamera.ViewportSize.Y * 0.65,
    "screen shockwave originates at the caster's projected position rather than the screen center"
)
check(
    ring.BackgroundTransparency == 1
        and ring.Active == false
        and playerGui:FindFirstChild("IceShotgunHitFeedback") == nil,
    "surge cue leaves the view clear and does not imply a confirmed hit"
)
local streaks = childrenNamed(cue, "SurgeStreak")
check(#streaks == presentationConfig.CasterSurgeStreakCount, "bounded outward streaks accompany the ring")
for _, streak in streaks do
    check(not streak.Active, "surge streaks never intercept mobile controls")
end
advance(presentationConfig.CasterSurgeSeconds + 0.01)
check(playerGui:FindFirstChild("IceRayCasterSurge") == nil, "caster cue expires after its brief surge")
advance(presentationConfig.Lifetime)
for _, viewport in { vec(390, 844, 0), vec(844, 390, 0) } do
    workspaceFake.CurrentCamera.ViewportSize = viewport
    setup(vfx.Play(shot()), "surge in mobile orientation")
    cue = playerGui:FindFirstChild("IceRayCasterSurge")
    ring = cue:FindFirstChild("SurgeRing")
    check(
        ring.Size.X.Offset == math.min(viewport.X, viewport.Y) * presentationConfig.CasterSurgeStartScale
            and ring.Size.X.Offset == ring.Size.Y.Offset,
        "caster ring stays circular and sized to the current portrait or landscape viewport"
    )
    localPlayer.CharacterRemoving:Fire(localPlayer.Character)
    check(playerGui:FindFirstChild("IceRayCasterSurge") == nil, "respawn clears the caster surge cue")
    advance(presentationConfig.Lifetime)
end
setup(vfx.Play(shot()), "surge before teardown")
vfx.Destroy()
check(playerGui:FindFirstChild("IceRayCasterSurge") == nil, "teardown clears the caster surge cue")

-- Late packets can deliver the initial growth and surge close together.
vfx.Init()
flush()
init.ServerTime = workspaceFake:GetServerTimeNow()
setup(vfx.Play(init), "late init visual")
advance(0.05)
setup(vfx.Play(shot(nil, vec(7, 1, 0))), "catch-up surge")
local catchUpPulse = childrenNamed(workspaceFake, "IceShotgunBlast")[1]:FindFirstChild("IceRadialPulse")
advance(0.061)
check(catchUpPulse.Size.X == 2, "late initial growth cannot overwrite the restarted surge")
advance(0.05)
check(
    catchUpPulse.Size.X == config.BlastRadius * 2 and catchUpPulse.CFrame.Position.X == 7,
    "restarted surge reaches the authoritative radius at the current caster position"
)
advance(presentationConfig.Lifetime)
workspaceFake.CurrentCamera.WorldToViewportPoint = function()
    return vec(0, 0, -1), false
end
setup(vfx.Play(shot()), "first-person surge")
ring = playerGui:FindFirstChild("IceRayCasterSurge"):FindFirstChild("SurgeRing")
check(
    ring.Position.X.Offset == workspaceFake.CurrentCamera.ViewportSize.X * 0.5
        and ring.Position.Y.Offset == workspaceFake.CurrentCamera.ViewportSize.Y * 0.5,
    "first-person surge stays visible when the caster root is behind the camera"
)
vfx.Destroy()
print("PASS: Ice Ray client presentation and mobile budgets")
