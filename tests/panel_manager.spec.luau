-- Presentation state only; callbacks model observable visibility and animation completion.
local function check(value, message)
    assert(value, message)
end
local manager = assert(loadstring(managerSource))()
local visible = {}
local function only(id)
    for name, shown in visible do
        check(shown == (name == id), "unexpected visibility: " .. name)
    end
end
local function setVisible(id, shown)
    if shown then
        for name, value in visible do
            check(not value or name == id, "major menus overlap")
        end
    end
    visible[id] = shown
end
local pauseClose, pauseOpen = false, false
local function panel(id)
    visible[id] = true -- The manager must override preview visibility.
    return manager.Register(id, {
        Open = function()
            if pauseOpen then
                coroutine.yield()
            end
            setVisible(id, true)
        end,
        Close = function()
            if pauseClose then
                coroutine.yield()
            end
            setVisible(id, false)
        end,
    })
end
local function start(fn)
    local thread = coroutine.create(fn)
    local ok, message = coroutine.resume(thread)
    check(ok, message)
    return thread
end
local function finish(thread)
    local ok, message = coroutine.resume(thread)
    check(ok, message)
    check(coroutine.status(thread) == "dead", "transition did not finish")
end
local upgrades, index, cosmetics = panel("Upgrades"), panel("Index"), panel("Cosmetics")
only(nil)
check(manager.GetActive() == nil, "startup has no active menu")
upgrades.Open()
only("Upgrades")
check(manager.GetActive() == "Upgrades", "active identity exposed")
index.Open()
only("Index")
cosmetics.Open()
only("Cosmetics")
cosmetics.Close()
only(nil)
cosmetics.Open()
cosmetics.Toggle()
only(nil)

-- Fifty rapid sequences must all preserve exclusivity, including same-panel toggles.
for _ = 1, 50 do
    upgrades.Toggle()
    only("Upgrades")
    index.Toggle()
    only("Index")
    cosmetics.Toggle()
    only("Cosmetics")
    cosmetics.Close()
    only(nil)
end

-- A delayed close remains the sole visible panel; latest request wins on completion.
upgrades.Open()
pauseClose = true
local transition = start(index.Open)
only("Upgrades")
cosmetics.Open()
index.Close() -- An old X callback cannot cancel a different pending panel.
only("Upgrades")
pauseClose = false
finish(transition)
only("Cosmetics")

-- Closing a queued panel cancels its opening, even while another is still closing.
pauseClose = true
transition = start(upgrades.Open)
upgrades.Close()
pauseClose = false
finish(transition)
only(nil)

-- Reopen the same panel while its X close animation is finishing.
index.Open()
pauseClose = true
transition = start(index.Close)
index.Open()
pauseClose = false
finish(transition)
only("Index")

-- Toggle a queued request twice without showing that intermediate panel.
pauseClose = true
transition = start(cosmetics.Open)
cosmetics.Toggle()
cosmetics.Toggle()
pauseClose = false
finish(transition)
only("Cosmetics")

-- Opening animations are serialized too: the next panel waits for them to finish.
cosmetics.Close()
pauseOpen = true
transition = start(upgrades.Open)
index.Open()
cosmetics.Open()
only(nil)
pauseOpen = false
finish(transition)
only("Cosmetics")

-- Stable logical names can acquire replacement callbacks. Detached handles are inert.
local old = cosmetics
cosmetics = panel("Cosmetics")
only(nil)
cosmetics.Open()
old.Open()
old.Close()
old.Destroy()
only("Cosmetics")
cosmetics.Destroy()
cosmetics.Open()
only(nil)

-- Destroying a pending request never opens the removed view or strands the worker.
index.Open()
pauseClose = true
transition = start(upgrades.Open)
upgrades.Destroy()
pauseClose = false
finish(transition)
only(nil)
index.Open()
only("Index")
index.Destroy()
only(nil)
index = panel("Index")
index.Open()
manager.CloseAll()
only(nil)
check(manager.GetActive() == nil, "CloseAll clears active identity")
print("Panel manager: exclusivity, rapid input, X/reopen, yielded transitions, replacement and removal passed")
