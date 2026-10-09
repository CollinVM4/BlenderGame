--!strict
local RunService = game:GetService("RunService")
local Debug = {}
-- Set on the server in Studio; Workspace replicates the flag to playtest clients.
-- Nil/false by default. Never emit diagnostics in a published server.
function Debug.Log(prompt: ProximityPrompt, stage: string, detail: string?)
    if not RunService:IsStudio() or workspace:GetAttribute("DebugMobilePrompts") ~= true then
        return
    end
    print("[MobilePrompt] " .. stage .. " | " .. prompt:GetFullName() .. (if detail then " | " .. detail else ""))
end
return Debug
