local vfx = loadModule("IceShotgunPresentationController")
vfx.Init()
vfx.Init()
flush()
local function shot(hits, origin)
    return {
        Origin = origin or vec(0, 1, -2),
        Direction = vec(0, 0, -1),
        Range = 22,
        Angle = 50,
        ShooterUserId = localPlayer.UserId,
        ServerTime = workspaceFake:GetServerTimeNow(),
        Hits = hits or {},
    }
end
check(#childrenNamed(workspaceFake, "IceShotgunBlast") == 0, "initialization never predicts a blast")
resultRemote.OnClientEvent:Fire(shot({ { Position = vec(0, 1, -12), UserId = 7, Frozen = true } }))
local blast = childrenNamed(workspaceFake, "IceShotgunBlast")[1]
check(blast ~= nil, "server-confirmed result renders a blast")
check(
    blast:FindFirstChild("IceConePanel")
        and blast:FindFirstChild("IceMuzzleFlash")
        and blast:FindFirstChild("IceShard")
        and blast:FindFirstChild("IceImpact"),
    "cone, muzzle, shards and confirmed impact render together"
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
    "unavailable imported assets use immediate builtin sound/particle fallbacks"
)
advance(0.12)
local panel = blast:FindFirstChild("IceConePanel")
check(panel.Size.Magnitude > 5 and panel.Transparency < 1, "cone rapidly expands while still translucent")
advance(0.24)
check(
    panel.Transparency == 1 and playerGui:FindFirstChild("IceShotgunHitFeedback") == nil,
    "cone and hit feedback fade promptly"
)
advance(0.3)
check(blast.Destroyed, "blast objects expire within the configured short lifetime")

services.UserInputService.PreferredInput = "Touch"
local many = {}
for i = 1, 20 do
    table.insert(many, { Position = vec(i * 0.1, 1, -10), UserId = i, Frozen = false })
end
setup(vfx.Play(shot(many)), "mobile confirmed shot")
local mobileBlast = childrenNamed(workspaceFake, "IceShotgunBlast")[1]
check(
    #childrenNamed(mobileBlast, "IceImpact") == presentationConfig.MobileMaxImpactEffects,
    "large multiplayer hit lists obey the mobile impact budget"
)
check(
    mobileBlast:FindFirstChild("IceMuzzleFlash"):FindFirstChild("ShotgunFrost").EmittedCount
        == presentationConfig.MobileFrostCount,
    "mobile muzzle uses the reduced frost budget"
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
malformed.Direction = vec(0 / 0, 0, -1)
check(
    not vfx.Play(malformed) and not vfx.Play({ Target = localPlayer }),
    "invalid cosmetic messages do not allocate effects"
)

vfx.Destroy()
preloadMode = "success"
vfx.Init()
flush()
setup(
    vfx.Play(shot({ { Position = vec(0, 1, -12), UserId = localPlayer.UserId, Frozen = false } })),
    "successful sound preload shot"
)
check(
    playedSounds[#playedSounds - 1] == presentationConfig.ShotSoundId
        and playedSounds[#playedSounds] == presentationConfig.ImpactSoundId,
    "sound hooks use the original imported clips when available"
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
print("PASS: Ice Shotgun client presentation and mobile budgets")
