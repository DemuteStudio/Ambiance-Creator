-- DM_Ambiance_Structures.lua (modifié)
local Structures = {}

local globals = {}

function Structures.initModule(g)
    globals = g
end

-- Group structure with randomization parameters
function Structures.createGroup(name)
    return {
        name = name or "New Group",
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
        overrideParent = false -- New flag to override parent group settings
    }
end

-- Function to get effective container parameters, considering parent inheritance
function Structures.getEffectiveContainerParams(group, container)
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
    
    -- Override with parent group randomization settings
    effectiveParams.randomizePitch = group.randomizePitch
    effectiveParams.randomizeVolume = group.randomizeVolume
    effectiveParams.randomizePan = group.randomizePan
    
    -- Copy parent range values (creating new tables to avoid reference issues)
    effectiveParams.pitchRange = {min = group.pitchRange.min, max = group.pitchRange.max}
    effectiveParams.volumeRange = {min = group.volumeRange.min, max = group.volumeRange.max}
    effectiveParams.panRange = {min = group.panRange.min, max = group.panRange.max}
    
    -- Inherit trigger settings
    effectiveParams.useRepetition = group.useRepetition
    effectiveParams.triggerRate = group.triggerRate
    effectiveParams.triggerDrift = group.triggerDrift
    effectiveParams.intervalMode = group.intervalMode
    
    return effectiveParams
end

return Structures
