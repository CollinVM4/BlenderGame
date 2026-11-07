-- Release check against actual production content, without fixture image IDs.
local artwork = loadModule("MuncherArtwork")
local missing = artwork.Missing()
check(#missing == 0, "Muncher artwork release blocked; missing/invalid image URIs: " .. table.concat(missing, ", "))
