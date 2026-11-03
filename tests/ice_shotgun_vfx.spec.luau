local vfx = loadModule("IceShotgunPresentationController")
vfx.Init()
vfx.Init()
flush()
local function shot(hits, origin)
    return {
        Origin = origin or vec(0, 1, -2),
        Radius = 22,
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
local init = shot()
init.Stage, init.Radius = "Init", 8
setup(vfx.Play(init), "init visual")
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
check(heldPulse.Size.X == 16 and heldPulse.Transparency == 0.25, "small sphere holds through charge")
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
advance(0.11)
check(heldPulse.Size.X == 44, "surge expands reused sphere to full diameter")
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
check(pulse.Size.X == 44, "pulse diameter is exactly twice the server blast radius")
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
    mobileBlast:FindFirstChild("IceRadialPulse"):FindFirstChild("ShotgunFrost").EmittedCount
        == presentationConfig.MobileFrostCount,
    "mobile pulse center uses the reduced frost budget"
)
setup(vfx.Play(shot()), "second mobile shot")
check(
    not vfx.Play(shot())
        and #childrenNamed(workspaceFake, "IceShotgunBlast") == presentationConfig.MobileMaxActiveBlasts,
    "simultaneous remote shots cannot exceed the mobile blast budget"
)
advance(presentationConfig.Lifetime + 0.01)
check(#childrenNamed(workspaceFake, "IceShotgunBlast") == 0, "mobile budget releases after effect expiry")
check(not vfx.Play(shot(nil, vec(500, 1, 0))), "distant blasts are culled")
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
print("PASS: Ice Ray client presentation and mobile budgets")
