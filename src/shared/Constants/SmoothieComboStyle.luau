--!strict
local colors: { [string]: Color3 } = {
    Red = Color3.fromRGB(255, 109, 122),
    Yellow = Color3.fromRGB(255, 226, 100),
    Green = Color3.fromRGB(146, 255, 136),
    Blue = Color3.fromRGB(103, 213, 255),
    Purple = Color3.fromRGB(213, 155, 255),
}

return {
    Colors = table.freeze(colors),
    Identical = Color3.fromRGB(255, 157, 230),
}
