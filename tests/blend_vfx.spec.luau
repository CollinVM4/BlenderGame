-- Real BlendService + BlendVFX, with engine signals/tweens simulated at the boundary.
return function(t)
    local check, frame = t.Check, t.Frame
    local now, timers = 0, {}
    local pendingEvents = {}
    local deferEvents = false
    local function new(class)
        local object = t.Instance(class)
        object.DescendantAdded = t.Signal()
        object.DescendantRemoving = t.Signal()
        if class == "BindableEvent" then
            local connect = object.Event.Connect
            function object.Event:Connect(callback)
                local connection = connect(self, callback)
                connection.Connected = true
                local disconnect = connection.Disconnect
                function connection:Disconnect()
                    self.Connected = false
                    disconnect(self)
                end
                return connection
            end
            function object:Fire(...)
                local args = table.pack(...)
                -- Roblox copies table payloads; our Instance/CFrame mocks retain identity.
                for index, value in args do
                    if type(value) == "table" and value.State then
                        args[index] = table.clone(value)
                    end
                end
                local function deliver()
                    self.Event:Fire(table.unpack(args, 1, args.n))
                end
                if deferEvents then
                    table.insert(pendingEvents, deliver)
                else
                    deliver()
                end
            end
        end
        local signals = {}
        function object:GetAttributes()
            return table.clone(self.Attributes)
        end
        function object:GetAttributeChangedSignal(name)
            signals[name] = signals[name] or t.Signal()
            return signals[name]
        end
        function object:SetAttribute(name, value)
            local old = self.Attributes[name]
            self.Attributes[name] = value
            if old ~= value and signals[name] then
                signals[name]:Fire()
            end
        end
        function object:Clear()
            self.Clears = (self.Clears or 0) + 1
        end
        return object
    end
    local owner = new("Player")
    local visitor = new("Player")
    local plot, blender = new("Model"), new("Model")
    plot.Name = "Plot1"
    blender.Name, blender.Parent = "Blender", plot
    plot:SetAttribute("OwnerUserId", 1)
    local function child(class, name, parent)
        local object = new(class)
        object.Name, object.Parent = name, parent
        return object
    end
    local folder = child("Folder", "IngredientVisuals", blender)
    local origin = child("Part", "BlendVisualOrigin", blender)
    origin.CFrame = frame(10, 2, 0)
    origin.CFrame.RightVector = t.Env.Vector3.new(0, 0, -1)
    origin.CFrame.LookVector = t.Env.Vector3.new(-1, 0, 0)
    local liquid = child("Part", "Liquid", child("Model", "Liquid", blender))
    local authoredColor = t.Env.Color3.new(0.1, 0.2, 0.3)
    liquid.Transparency, liquid.Color, liquid.Size = 0.2, authoredColor, t.Env.Vector3.new(3, 2, 3)
    local originalSize, originalFrame = liquid.Size, liquid.CFrame
    local puffAttachment1 = child("Attachment", "PuffAttachment1", origin)
    local puffAttachment2 = child("Attachment", "PuffAttachment2", origin)
    local puff1 = child("ParticleEmitter", "Puff1", puffAttachment1)
    local puff2 = child("ParticleEmitter", "Puff2", puffAttachment2)
    local input, wheel = new("Part"), new("Part")
    local records, animations = {}, {}
    local cleaning
    local inputCleaning
    local world = {
        BindTag = function(tag, attach)
            if tag == "BlenderInput" then
                inputCleaning = attach(input)
            else
                check(tag == "PlayerPlot", "VFX binds per plot")
                cleaning = attach(plot)
            end
        end,
        Part = function(object)
            return object
        end,
        Near = function()
            return true
        end,
    }
    local services = table.clone(t.Services)
    local logs = {}
    local warnings = {}
    local isStudio = true
    services.RunService = {
        IsStudio = function()
            return isStudio
        end,
        Heartbeat = t.Signal(),
    }
    services.Players = { PlayerRemoving = t.Signal() }
    services.TweenService = {
        Create = function(_, object, _, goal)
            local tween = { Object = object, Goal = goal }
            function tween:Play()
                self.Played = true
            end
            function tween:Cancel()
                self.Cancelled = true
            end
            table.insert(animations, tween)
            return tween
        end,
    }
    local modules = {
        WorldUtil = world,
        StudioServices = {
            Wrap = function(_, service)
                return service
            end,
        },
        FilmingUtil = { Emit = function() end, Log = function() end },
    }
    local environment = setmetatable({
        os = {
            clock = function()
                return now
            end,
        },
        task = {
            delay = function(seconds, callback)
                local timer = { At = now + seconds, Callback = callback }
                table.insert(timers, timer)
                return timer
            end,
            cancel = function(timer)
                timer.Cancelled = true
            end,
            defer = function(callback)
                callback()
            end,
        },
        print = function(message)
            table.insert(logs, message)
        end,
        warn = function(message)
            table.insert(warnings, message)
        end,
        game = {
            GetService = function(_, name)
                return services[name]
            end,
        },
        Instance = { new = new },
        TweenInfo = {
            new = function()
                return {}
            end,
        },
        Enum = { EasingStyle = { Quad = 1 }, EasingDirection = { In = 1 } },
        typeof = function(value)
            return if type(value) == "table" and value.R then "Color3" else typeof(value)
        end,
    }, { __index = t.Env })
    local function advance(seconds)
        now += seconds
        for _, timer in table.clone(timers) do
            if not timer.Cancelled and not timer.Ran and timer.At <= now then
                timer.Ran = true
                timer.Callback()
            end
        end
    end
    local function load(name, component)
        if modules[name] then
            return modules[name]
        end
        local chunk = assert(loadstring(t.Sources[name], name))
        setfenv(
            chunk,
            setmetatable({
                script = { Parent = if component then { Parent = { Services = t.Parent } } else t.Parent },
                require = function(key)
                    return load(key)
                end,
            }, { __index = environment })
        )
        modules[name] = chunk()
        return modules[name]
    end
    local definitions = load("Ingredients")
    local ingredients = {
        GetDefinition = function(id)
            return definitions[id]
        end,
        GetRecord = function(object)
            return records[object]
        end,
        Resolve = function(object)
            return if records[object] then object else nil
        end,
        Consume = function(object)
            local record = records[object]
            records[object] = nil
            object:Destroy()
            return record and record.Id
        end,
        CreateVisual = function()
            local proxy = new("Part")
            proxy:SetAttribute("IngredientId", "forged")
            services.CollectionService:AddTag(proxy, "IngredientWorldItem")
            child("Script", "Behavior", proxy)
            child("ProximityPrompt", "Pickup", proxy)
            child("TouchTransmitter", "TouchInterest", proxy)
            child("Decal", "Appearance", proxy)
            return proxy
        end,
    }
    local currentOwner = owner
    local deps = {
        IngredientService = ingredients,
        TycoonService = {
            GetOwner = function()
                return currentOwner
            end,
            GetReference = function()
                return input
            end,
        },
        PlayerDataService = { IncrementStat = function() end, RecordDiscovery = function() end },
    }
    local blend = load("BlendService")
    deps.BlendService = blend
    blend.Init(deps)
    blend.Reset(owner)
    load("BlendVFX", true).Init(deps)
    local notifications = 0
    local observation = blend.ObserveIngredientAccepted(function(player, _, _, index)
        notifications += 1
        check(blend.GetSnapshot(player).Ingredients[index] ~= nil, "acceptance fires after batch commit")
    end)
    local function accept(id, who)
        local object = new("Part")
        object.CFrame = frame(10, 8, 0)
        records[object] = { Id = id, Owner = who or owner, Claimable = true }
        input.Overlaps = { object }
        return blend.TryInput(who or owner, object, input), object
    end
    check(liquid.Transparency == 1 and not puff1.Enabled and not puff2.Enabled, "empty plot is hidden and quiet")
    check(not accept("Ice", visitor) and notifications == 0, "rejected ingestion has no notification or visual")
    local ok, consumed = accept("Strawberry")
    check(ok and consumed.Destroyed and records[consumed] == nil, "gameplay ingredient consumed before visual")
    accept("Banana")
    check(
        blender:FindFirstChild("IngredientVisuals") == folder and #folder:GetChildren() == 2,
        "existing folder retains both loaded copies"
    )
    local copy = folder:GetChildren()[1]
    check(
        copy.Anchored and not copy.CanCollide and not copy.CanTouch and not copy.CanQuery,
        "proxy has no physics interaction"
    )
    check(
        next(copy:GetAttributes()) == nil and #services.CollectionService:GetTags(copy) == 0,
        "proxy strips attributes and tags"
    )
    check(
        not copy:FindFirstChild("Pickup")
            and not copy:FindFirstChild("Behavior")
            and not copy:FindFirstChild("TouchInterest")
            and copy:FindFirstChild("Appearance"),
        "proxy preserves appearance only"
    )
    check(animations[1].Played and animations[1].Object.CFrame.Position.Y == 8, "arrival starts at consumed position")
    check(
        (animations[1].Goal.CFrame.Position - animations[2].Goal.CFrame.Position).Magnitude > 0.1,
        "loaded targets have separate transforms"
    )
    -- Finish the actual per-part arrival goals, not just the computed offset list.
    for index, expected in { t.Env.Vector3.new(1.8, -0.16, 0.09), t.Env.Vector3.new(-1.17, 0.06, 1.35) } do
        local animation = animations[index]
        animation.Object.CFrame = animation.Goal.CFrame
        animation.Object.Position = animation.Goal.CFrame.Position
        local destination = origin.CFrame * frame(expected.X, expected.Y, expected.Z)
        check(
            (animation.Object.CFrame.Position - destination.Position).Magnitude < 1e-9,
            "completed arrival retains local offset in final world position"
        )
    end
    blend.Ready(owner)
    check(
        (animations[1].Object.CFrame.Position - animations[1].Goal.CFrame.Position).Magnitude < 1e-9,
        "zero-progress refresh does not overwrite settled tween position"
    )
    local canonical = owner:GetAttribute("BlendColor")
    check(
        math.abs(canonical.R - (definitions.Strawberry.BlendColor.R + definitions.Banana.BlendColor.R) / 2) < 1e-9,
        "canonical loading color uses existing mean"
    )
    cleaning()
    load("BlendVFX", true).Init(deps)
    check(#folder:GetChildren() == 2, "reattachment restores accepted preblend batch from snapshot")
    blend.AddProgress(owner, wheel, 1)
    check(#folder:GetChildren() == 0 and animations[1].Cancelled, "start clears copies and cancels arrival")
    check(puff1.Enabled and puff2.Enabled, "puff emitters beneath BlendVisualOrigin activate")
    check(
        liquid.Color.R == canonical.R and liquid.Transparency < 1 and liquid.Transparency > 0.8,
        "start reveals faint canonical liquid"
    )
    check(math.abs(liquid.Transparency - 0.992) < 1e-9, "first positive progress uses hidden-to-authored interpolation")
    blend.AddProgress(owner, wheel, 24)
    check(math.abs(liquid.Transparency - 0.8) < 1e-9, "quarter blend transparency")
    blend.AddProgress(owner, wheel, 25)
    check(math.abs(liquid.Transparency - 0.6) < 1e-9, "midpoint transparency")
    blend.AddProgress(owner, wheel, 25)
    check(math.abs(liquid.Transparency - 0.4) < 1e-9, "three-quarter transparency")
    blend.AddProgress(owner, wheel, 25)
    check(
        not puff1.Enabled and not puff2.Enabled and puff1.Clears > 0 and puff2.Clears > 0,
        "completion immediately clears cloud"
    )
    check(
        liquid.Transparency == 0.2 and liquid.Color == blend.GetSnapshot(owner).Result.Color,
        "finished liquid matches result and authored visibility"
    )
    check(liquid.Size == originalSize and liquid.CFrame == originalFrame, "liquid geometry is never modified")
    owner.Backpack = new("Backpack")
    owner.Backpack.Parent = owner
    check(blend.Dispense(owner, input), "existing dispense succeeds")
    check(liquid.Transparency == 1 and liquid.Color == authoredColor, "DISPENSED hides liquid and restores color")
    blend.Reset(owner)
    accept("Ice")
    check(#folder:GetChildren() == 1, "new batch has fresh visual state")
    blend.AddProgress(owner, wheel, 20)
    local pausedTransparency = liquid.Transparency
    check(
        not blend.AddProgress(owner, wheel, 0) and liquid.Transparency == pausedTransparency and puff1.Enabled,
        "stopped progress holds presentation without independently advancing or resetting"
    )
    advance(0.2)
    check(puff1.Enabled, "particle grace prevents flicker between progress updates")
    advance(0.16)
    check(
        not puff1.Enabled and not puff2.Enabled and liquid.Transparency == pausedTransparency,
        "paused particles stop after grace while liquid holds progress"
    )
    blend.AddProgress(owner, wheel, 1)
    check(puff1.Enabled and puff2.Enabled, "particles resume on next authoritative progress increase")
    blend.Reset(owner)
    check(
        liquid.Transparency == 1 and not puff1.Enabled and not puff2.Enabled and #folder:GetChildren() == 0,
        "explicit reset during blending clears all presentation"
    )
    accept("Ice")
    services.Players.PlayerRemoving:Fire(owner)
    check(#folder:GetChildren() == 0 and not puff1.Enabled and not puff2.Enabled, "owner departure clears visuals")
    currentOwner = visitor
    blend.Reset(visitor)
    plot:SetAttribute("OwnerUserId", 2)
    accept("Ice", visitor)
    check(#folder:GetChildren() == 1, "new owner binds independently")
    cleaning()
    check(
        not folder.Destroyed and #folder:GetChildren() == 0,
        "detach preserves authored folder and clears runtime children"
    )
    accept("Banana", visitor)
    check(#folder:GetChildren() == 0, "detach disconnects ingestion listener")

    -- Missing optional liquid regression; four puff emitters under the live origin path.
    puffAttachment1:Destroy()
    puffAttachment2:Destroy()
    liquid.Parent:Destroy()
    local attachment = child("Attachment", "PuffAttachment", origin)
    local liveEmitters = {}
    for _, name in { "Puff1", "Puff2", "Puff3", "Puff4" } do
        table.insert(liveEmitters, child("ParticleEmitter", name, attachment))
    end
    blend.Reset(visitor)
    load("BlendVFX", true).Init(deps)
    load("BlenderInputComponent", true).Init(deps)
    local physical = new("Part")
    physical.CFrame = frame(10, 8, 0)
    records[physical] = { Id = "Ice", Owner = visitor, Claimable = true }
    input.Overlaps = { physical }
    local beforeNotifications = notifications
    services.RunService.Heartbeat:Fire(0.1)
    check(
        physical.Destroyed and notifications == beforeNotifications + 1,
        "physical BlenderInput consumption delivers ObserveIngredientAccepted"
    )
    check(
        #folder:GetChildren() == 1 and blend.GetSnapshot(visitor).State == "LOADING",
        "missing liquid does not block accepted visual"
    )
    blend.Ready(visitor)
    services.RunService.Heartbeat:Fire(0.1)
    check(#folder:GetChildren() == 1, "READY at zero progress does not immediately clear accepted visual")
    check(
        table.find(logs, "[BlendVFX] emitters found=4") and table.find(logs, "[BlendVFX] accepted ingredient=Ice"),
        "Studio logs prove emitter discovery and acceptance callback delivery"
    )
    blend.AddProgress(visitor, wheel, 1)
    for _, emitter in liveEmitters do
        check(emitter.Enabled, "origin emitter activates without liquid")
    end
    local logCount = #logs
    blend.AddProgress(visitor, wheel, 1)
    check(#logs == logCount, "progress updates do not spam lifecycle logs")
    blend.AddProgress(visitor, wheel, 98)
    for _, emitter in liveEmitters do
        check(not emitter.Enabled and emitter.Clears > 0, "origin emitter clears on completion")
    end
    inputCleaning()
    cleaning()

    -- Ingredient-only and alternative liquid layouts bind independently.
    attachment:Destroy()
    blend.Reset(visitor)
    load("BlendVFX", true).Init(deps)
    accept("Ice", visitor)
    check(#folder:GetChildren() == 1, "missing both particles and liquid still permits ingredient visuals")
    cleaning()
    local body = child("Model", "Body", blender)
    local alternate = child("Part", "Liquid", body)
    alternate.Color, alternate.Transparency = authoredColor, 0.1
    load("BlendVFX", true).Init(deps)
    blend.AddProgress(visitor, wheel, 100)
    check(alternate.Transparency == 0.1, "recursive Body.Liquid is discovered")
    cleaning()
    alternate.Parent = blender
    load("BlendVFX", true).Init(deps)
    check(alternate.Transparency == 0.1, "direct Blender.Liquid BasePart is discovered")
    cleaning()
    folder:Destroy()
    local invalidFolder = child("Part", "IngredientVisuals", blender)
    load("BlendVFX", true).Init(deps)
    check(alternate.Transparency == 0.1, "invalid ingredient container does not prevent liquid binding")
    cleaning()
    invalidFolder:Destroy()
    -- Late authored liquid arrival is discovered; no replacement geometry is made.
    alternate.Parent = nil
    blend.Reset(visitor)
    load("BlendVFX", true).Init(deps)
    alternate.Parent = body
    blender.DescendantAdded:Fire(alternate)
    check(alternate.Transparency == 1, "late liquid is bound and hidden for empty batch")
    accept("Ice", visitor)
    blend.AddProgress(visitor, wheel, 100)
    check(alternate.Transparency == 0.1, "late authored cylinder receives finished presentation")
    cleaning()
    blend.Reset(visitor)
    deferEvents = true
    local beforeStale = notifications
    accept("Ice", visitor)
    blend.Reset(visitor)
    for _, deliver in pendingEvents do
        deliver()
    end
    check(notifications == beforeStale, "scalar token still rejects deferred notifications from reset batches")
    deferEvents = false
    -- A populated authored folder is usable and must survive all VFX cleanup.
    local authoredFolder = child("Folder", "IngredientVisuals", blender)
    local decoration = child("Part", "AuthoredDecoration", authoredFolder)
    blend.Reset(visitor)
    load("BlendVFX", true).Init(deps)
    check(decoration.Parent == authoredFolder and not decoration.Destroyed, "bind preserves authored folder contents")
    local templateFolder = child("Folder", "Ingredients", services.ServerStorage)
    local template = child("Model", "Strawberry", templateFolder)
    local skin = child("Part", "Fruit", template)
    skin.Color, skin.Size = authoredColor, t.Env.Vector3.new(1, 2, 1)
    function template:Clone()
        local clone = new("Model")
        for _, name in { "Fruit", "Leaf" } do
            local part = child("Part", name, clone)
            part.Color, part.Size = skin.Color, skin.Size
            child("Decal", "Texture", part)
            child("ProximityPrompt", "Pickup", part)
        end
        return clone
    end
    ingredients.CreateVisual = load("IngredientService").CreateVisual
    accept("Strawberry", visitor)
    local proxy = authoredFolder:FindFirstChild("BlendIngredientVisual")
    check(proxy and proxy:IsA("Model"), "real CreateVisual selects ServerStorage.Ingredients.Strawberry model")
    for _, part in proxy:GetChildren() do
        check(
            part.Color == skin.Color and part.Size == skin.Size and part:FindFirstChild("Texture"),
            "template colors, geometry and texture survive sanitization"
        )
        check(
            part.Anchored
                and not part.CanCollide
                and not part.CanTouch
                and not part.CanQuery
                and not part:FindFirstChild("Pickup"),
            "all template parts are inert"
        )
    end
    check(#authoredFolder:GetChildren() == 2, "loaded visual coexists with unrelated authored content")
    blend.AddProgress(visitor, wheel, 1)
    check(proxy.Destroyed and not decoration.Destroyed, "blend start clears only owned visual")
    blend.Reset(visitor)
    check(
        #authoredFolder:GetChildren() == 1 and decoration.Parent == authoredFolder,
        "reset preserves authored content"
    )
    cleaning()
    check(not decoration.Destroyed and not authoredFolder.Destroyed, "detach preserves authored content")
    templateFolder:Destroy()
    observation:Disconnect()

    -- Inject presentation snapshots/events, without relaxing BlendService rules.
    local slots = {}
    for index = 1, 3 do
        local slot = child("Attachment", "IngredientSlot" .. index, blender)
        slot.WorldCFrame = frame(20 + index * 2, 5 + index, -10 - index)
        slot.WorldCFrame.RightVector = t.Env.Vector3.new(0, 0, -1)
        slot.WorldCFrame.LookVector = t.Env.Vector3.new(-1, 0, 0)
        slots[index] = slot
    end
    local snapshot = { State = "LOADING", Progress = 0, Ingredients = {} }
    local onAccepted
    local presentationDeps = {
        TycoonService = deps.TycoonService,
        IngredientService = {
            CreateVisual = function()
                return new("Part")
            end,
        },
        BlendService = {
            GetSnapshot = function()
                return snapshot
            end,
            ObserveIngredientAccepted = function(callback)
                onAccepted = callback
                return { Disconnect = function() end }
            end,
        },
    }
    load("BlendVFX", true).Init(presentationDeps)
    for index = 1, 3 do
        snapshot.Ingredients[index] = "Ice"
        onAccepted(visitor, "Ice", frame(10, 8, 0), index)
        local goal = animations[#animations].Goal.CFrame
        check(
            (goal.Position - slots[index].WorldCFrame.Position).Magnitude < 1e-9,
            "accepted index maps to exact authored slot"
        )
        check(goal.RightVector == slots[index].WorldCFrame.RightVector, "slot world orientation is retained")
    end
    local beforeFourth = #warnings
    snapshot.Ingredients[4] = "Ice"
    onAccepted(visitor, "Ice", frame(10, 8, 0), 4)
    local fourthGoal = animations[#animations].Goal.CFrame
    local fourthFallback = origin.CFrame * frame(0.99, -0.24, 1.26)
    check(
        (fourthGoal.Position - fourthFallback.Position).Magnitude < 1e-9,
        "fourth uses deterministic fallback rather than Slot1"
    )
    check(
        #warnings == beforeFourth + 1 and string.find(warnings[#warnings], "Unexpected ingredient index=4", 1, true),
        "fourth warns in Studio"
    )
    check(
        #snapshot.Ingredients == 4 and snapshot.Progress == 0 and snapshot.State == "LOADING",
        "presentation does not mutate unexpected batch"
    )
    cleaning()
    isStudio = false
    beforeFourth = #warnings
    load("BlendVFX", true).Init(presentationDeps)
    check(#warnings == beforeFourth, "unexpected fourth warning is Studio-only")
    cleaning()
    isStudio = true
    snapshot.Ingredients[4] = nil
    local fallbacks = { frame(1.8, -0.16, 0.09), frame(-1.17, 0.06, 1.35), frame(-0.9, -0.08, -1.44) }
    for missing = 1, 3 do
        slots[missing].Parent = nil
        load("BlendVFX", true).Init(presentationDeps)
        local copies = authoredFolder:GetChildren()
        for index = 1, 3 do
            check(
                (copies[index + 1].CFrame.Position - (origin.CFrame * fallbacks[index]).Position).Magnitude < 1e-9,
                "any missing slot restores entire legacy layout"
            )
        end
        cleaning()
        slots[missing].Parent = blender
    end
    slots[2].Parent = nil
    local invalidSlot = child("Part", "IngredientSlot2", blender)
    load("BlendVFX", true).Init(presentationDeps)
    check(
        (authoredFolder:GetChildren()[2].CFrame.Position - (origin.CFrame * fallbacks[1]).Position).Magnitude < 1e-9,
        "wrong slot class uses fallback"
    )
    cleaning()
    invalidSlot:Destroy()
    for _, slot in slots do
        slot.Parent = origin
    end
    slots[1].WorldCFrame = frame(40, 6, 20)
    load("BlendVFX", true).Init(presentationDeps)
    check(
        authoredFolder:GetChildren()[2].CFrame == slots[1].WorldCFrame,
        "origin child slots use current world frame on snapshot restoration"
    )
    cleaning()
    local directSlot = child("Attachment", "IngredientSlot1", blender)
    directSlot.WorldCFrame = frame(50, 7, 30)
    load("BlendVFX", true).Init(presentationDeps)
    check(authoredFolder:GetChildren()[2].CFrame == directSlot.WorldCFrame, "direct Blender slot takes precedence")
    cleaning()
    plot:Destroy()
    print("PASS: blender VFX lifecycle integration checks.")
end
