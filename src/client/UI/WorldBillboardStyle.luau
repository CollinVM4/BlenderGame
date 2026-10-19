--!strict
-- Compatibility entry point. Server and client share the same convention.
local Style = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
export type Settings = Style.Settings
export type TextSettings = Style.TextSettings
return Style
