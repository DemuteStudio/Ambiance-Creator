-- DM_Ambiance_Structures.lua (modifié)
local Structures = {}

local globals = {}

function Structures.initModule(g)
    globals = g
end

-- Track structure with randomization parameters
function Structures.createTrack(name)
    return {
        name = name or "New Track",
        containers = {},
        expanded = true,
        -- Added randomization parameters similar to containers
        pitchRange = {min = -3, max = 3},
        volumeRange = {min = -3, max = 3},
        panRange = {min = -100, max = 100},
        randomizePitch = true,
        randomizeVolume = true,
        randomizePan = true,
        useRepetition = true,
        triggerRate = 10.0,
        triggerDrift = 30,
        intervalMode = 0 -- 0 = Absolute, 1 = Relative, 2 = Coverage
    }
end

-- Container structure with override parent flag
function Structures.createContainer(name)
    return {
        name = name or "New Container",
        items = {},
        expanded = true,
        pitchRange = {min = -3, max = 3},
        volumeRange = {min = -3, max = 3},
        panRange = {min = -100, max = 100},
        randomizePitch = true,
        randomizeVolume = true,
        randomizePan = true,
        useRepetition = true,
        triggerRate = 10.0, -- Can be negative for overlaps
        triggerDrift = 30,
        intervalMode = 0, -- 0 = Absolute, 1 = Relative, 2 = Coverage
        overrideParent = false -- New flag to override parent track settings
    }
end

-- Function to get effective container parameters, considering parent inheritance
function Structures.getEffectiveContainerParams(track, container)
    -- If container is set to override parent settings, return its own parameters
    if container.overrideParent then
        return container
    end
    
    -- Create a new table with inherited parameters
    local effectiveParams = {}
    
    -- Copy all container properties first (without modifying references)
    for k, v in pairs(container) do
        if type(v) ~= "table" then
            effectiveParams[k] = v
        else
            -- Deep copy for tables (like ranges)
            effectiveParams[k] = {}
            for tk, tv in pairs(v) do
                effectiveParams[k][tk] = tv
            end
        end
    end
    
    -- Override with parent track randomization settings
    effectiveParams.randomizePitch = track.randomizePitch
    effectiveParams.randomizeVolume = track.randomizeVolume
    effectiveParams.randomizePan = track.randomizePan
    
    -- Copy parent range values (creating new tables to avoid reference issues)
    effectiveParams.pitchRange = {min = track.pitchRange.min, max = track.pitchRange.max}
    effectiveParams.volumeRange = {min = track.volumeRange.min, max = track.volumeRange.max}
    effectiveParams.panRange = {min = track.panRange.min, max = track.panRange.max}
    
    -- Inherit trigger settings
    effectiveParams.useRepetition = track.useRepetition
    effectiveParams.triggerRate = track.triggerRate
    effectiveParams.triggerDrift = track.triggerDrift
    effectiveParams.intervalMode = track.intervalMode
    
    return effectiveParams
end

return Structures
