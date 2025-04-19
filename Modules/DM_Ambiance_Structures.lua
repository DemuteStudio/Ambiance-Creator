local Structures = {}
local globals = {}

function Structures.initModule(g)
  globals = g
end

-- Track structure
function Structures.createTrack(name)
  return {
    name = name or "New Track",
    containers = {},
    expanded = true
  }
end

-- Container structure
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
    triggerRate = 10.0,  -- Can be negative for overlaps
    triggerDrift = 30,
    intervalMode = 0     -- 0 = Absolute, 1 = Relative, 2 = Coverage
  }
end

return Structures
