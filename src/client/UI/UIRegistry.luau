--!strict
-- Shared semantic contract. Generated root names and XML referents are irrelevant.
local Registry = {}
local panelNames: { [string]: boolean } =
    { Index = true, Settings = true, Shop = true, Upgrades = true, Cosmetics = true }
Registry.Panels = panelNames

function Registry.Matches(instance: Instance, role: string, names: { string }): boolean
    local semantic = instance:GetAttribute("BlenderUI")
    if type(semantic) == "string" then
        return semantic == role
    end
    return table.find(names, instance.Name) ~= nil
end

-- Search only the specified parent's children; ambiguous contracts never pick a copy.
function Registry.Child(parent: Instance?, role: string, names: { string }, class: string): Instance?
    if not parent then
        return nil
    end
    local found: Instance? = nil
    for _, candidate in parent:GetChildren() do
        if Registry.Matches(candidate, role, names) then
            if found or not candidate:IsA(class) then
                return nil
            end
            found = candidate
        end
    end
    return found
end

function Registry.Desktops(container: Instance): { Instance }
    local result: { Instance } = {}
    for _, instance in container:GetDescendants() do
        if
            Registry.Matches(instance, "Desktop", { "Be a Blender! Desktop" })
            and (instance:IsA("GuiObject") or instance:IsA("ScreenGui"))
        then
            table.insert(result, instance)
        end
    end
    return result
end

function Registry.ActiveRoot(desktop: Instance, playerGui: Instance): ScreenGui?
    local ancestor: Instance? = desktop
    local root: ScreenGui? = nil
    while ancestor and ancestor ~= playerGui do
        if ancestor:IsA("ScreenGui") then
            if not ancestor.Enabled then
                return nil
            end
            root = ancestor
        elseif ancestor:IsA("GuiObject") and not ancestor.Visible then
            return nil
        end
        ancestor = ancestor.Parent
    end
    return if ancestor == playerGui then root else nil
end

function Registry.Content(desktop: Instance): Instance?
    local names = { "Be a Blender! DesktopContent", "DesktopContent" }
    local content = Registry.Child(desktop, "Content", names, "GuiObject")
    if content then
        return content
    end
    for _, candidate in desktop:GetChildren() do
        if Registry.Matches(candidate, "Content", names) then
            return nil
        end
    end
    return desktop
end

function Registry.ContentOf(instance: Instance): Instance?
    local ancestor: Instance? = instance
    while ancestor do
        if Registry.Matches(ancestor, "Desktop", { "Be a Blender! Desktop" }) then
            return Registry.Content(ancestor)
        end
        ancestor = ancestor.Parent
    end
    return nil
end

function Registry.PanelId(instance: Instance): string?
    if
        not (instance:IsA("Frame") or instance:IsA("CanvasGroup"))
        or instance.Parent ~= Registry.ContentOf(instance)
    then
        return nil
    end
    for id in panelNames do
        if Registry.Matches(instance, "Panel:" .. id, { id, id .. "_panel" }) then
            return id
        end
    end
    return nil
end

return Registry
