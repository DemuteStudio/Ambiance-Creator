local Presets = {}
local globals = {}
local presetCache = {}
local presetCacheTime = {}

function Presets.initModule(g)
  globals = g
end

-- Function to determine the presets path with correct subfolder structure
function Presets.getPresetsPath(type, groupName)
  local basePath
  
  if globals.presetsPath ~= "" then 
    basePath = globals.presetsPath 
  else
    -- Define base path based on OS
    if reaper.GetOS():match("Win") then
      basePath = os.getenv("APPDATA") .. "\\REAPER\\Scripts\\Demute\\Ambiance Creator\\Presets\\"
    elseif reaper.GetOS():match("OSX") then
      basePath = os.getenv("HOME") .. "/Library/Application Support/REAPER/Scripts/Demute/Ambiance Creator/Presets/"
    else -- Linux
      basePath = os.getenv("HOME") .. "/.config/REAPER/Scripts/Demute/Ambiance Creator/Presets/"
    end
    
    -- Create base folder if it doesn't exist
    local command
    if reaper.GetOS():match("Win") then
      command = 'if not exist "' .. basePath .. '" mkdir "' .. basePath .. '"'
    else
      command = 'mkdir -p "' .. basePath .. '"'
    end
    os.execute(command)
    
    globals.presetsPath = basePath
  end
  
  -- Determine specific path based on type
  local specificPath = basePath
  
  if type == "Global" then
    specificPath = basePath .. "Global\\"
  elseif type == "Groups" then
    specificPath = basePath .. "Groups\\"
  elseif type == "Containers" then
    -- Élimination de la dépendance à groupName pour les conteneurs
    specificPath = basePath .. "Containers\\"
  end
  
  -- Create the specific directory if it doesn't exist
  local command
  if reaper.GetOS():match("Win") then
    command = 'if not exist "' .. specificPath .. '" mkdir "' .. specificPath .. '"'
  else
    command = 'mkdir -p "' .. specificPath .. '"'
  end
  os.execute(command)
  
  return specificPath
end

-- Function to list available presets by type
function Presets.listPresets(type, groupName, forceRefresh)
  local currentTime = os.time()
  local cacheKey = type .. (groupName or "")
  
  if not type then type = "Global" end
  
  -- Initialize preset cache if needed
  if not presetCache then presetCache = {} end
  if not presetCacheTime then presetCacheTime = {} end
  
  if not forceRefresh and presetCache[cacheKey] then
    return presetCache[cacheKey] -- Return cached list if recent
  end
  
  local path = Presets.getPresetsPath(type, groupName)
  
  -- Reset the presets list
  local typePresets = {}
  
  -- Use reaper.EnumerateFiles to list files
  local i = 0
  local file = reaper.EnumerateFiles(path, i)
  while file do
    if file:match("%.lua$") then
      -- Explicitly capture the result of gsub in a variable
      local presetName = file:gsub("%.lua$", "")
      -- Add the preset name to the list
      typePresets[#typePresets + 1] = presetName
    end
    i = i + 1
    file = reaper.EnumerateFiles(path, i)
  end
  
  table.sort(typePresets)
  presetCache[cacheKey] = typePresets
  presetCacheTime[cacheKey] = currentTime
  
  return typePresets
end

-- Function to serialize a table
function Presets.listPresets(type, groupName, forceRefresh)
  local currentTime = os.time()
  local cacheKey = type -- Plus besoin d'inclure groupName pour les conteneurs
  
  if not type then type = "Global" end
  
  -- Initialisation du cache et vérification
  if not presetCache then presetCache = {} end
  if not presetCacheTime then presetCacheTime = {} end
  
  if not forceRefresh and presetCache[cacheKey] then
    return presetCache[cacheKey] -- Retour du cache si récent
  end
  
  -- Obtention du chemin sans référence au groupName pour les conteneurs
  local path = Presets.getPresetsPath(type, nil)
  
  -- Reset de la liste des presets
  local typePresets = {}
  
  -- Utilisation de reaper.EnumerateFiles pour lister les fichiers
  local i = 0
  local file = reaper.EnumerateFiles(path, i)
  while file do
    if file:match("%.lua$") then
      local presetName = file:gsub("%.lua$", "")
      typePresets[#typePresets + 1] = presetName
    end
    i = i + 1
    file = reaper.EnumerateFiles(path, i)
  end
  
  table.sort(typePresets)
  presetCache[cacheKey] = typePresets
  presetCacheTime[cacheKey] = currentTime
  
  return typePresets
end

local function serializeTable(val, name, depth)
  depth = depth or 0
  local indent = string.rep("  ", depth)
  local result = ""
  
  if name then result = indent .. name .. " = " end
  
  if type(val) == "table" then
    result = result .. "{\n"
    
    for k, v in pairs(val) do
      local key = type(k) == "number" and "[" .. k .. "]" or k
      result = result .. serializeTable(v, key, depth + 1) .. ",\n"
    end
    
    result = result .. indent .. "}"
  elseif type(val) == "number" then
    result = result .. tostring(val)
  elseif type(val) == "string" then
    result = result .. string.format("%q", val)
  elseif type(val) == "boolean" then
    result = result .. (val and "true" or "false")
  else
    result = result .. "nil"
  end
  
  return result
end


-- Function to save a global preset
function Presets.savePreset(name)
  if name == "" then return false end

  if globals.Settings and globals.Settings.getSetting("autoImportMedia") then
    for _, group in ipairs(globals.groups) do
        for _, container in ipairs(group.containers) do
            globals.Settings.processContainerMedia(container)
        end
    end
  end

  local path = Presets.getPresetsPath("Global") .. name .. ".lua"
  local file = io.open(path, "w")
  
  if file then
    file:write("-- Ambiance Creator Global Preset: " .. name .. "\n")
    file:write("-- Created on " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    file:write("return " .. serializeTable(globals.groups) .. "\n")
    file:close()
    
    -- Refresh the preset list
    Presets.listPresets("Global", nil, true)
    return true
  end
  
  return false
end

-- Function to load a global preset
function Presets.loadPreset(name)
  if name == "" then return false end
  
  local path = Presets.getPresetsPath("Global") .. name .. ".lua"
  local success, presetData = pcall(dofile, path)
  
  if success and type(presetData) == "table" then
    globals.groups = presetData
    globals.currentPresetName = name
    return true
  else
    reaper.ShowConsoleMsg("Error loading preset: " .. tostring(presetData) .. "\n")
    return false
  end
end

-- Function to delete a preset
function Presets.deletePreset(name, type, groupName)
  if name == "" then return false end
  
  if not type then type = "Global" end
  
  local path = Presets.getPresetsPath(type, groupName) .. name .. ".lua"
  local success, result = os.remove(path)
  
  if success then
    -- Refresh the preset list
    Presets.listPresets(type, groupName, true)
    if type == "Global" then
      globals.currentPresetName = ""
      globals.selectedPresetIndex = 0
    end
    return true
  else
    reaper.ShowConsoleMsg("Error deleting preset: " .. tostring(result) .. "\n")
    return false
  end
end

-- Function to save a group preset
function Presets.saveGroupPreset(name, groupIndex)
  if name == "" then return false end
  
  if globals.Settings and globals.Settings.getSetting("autoImportMedia") then
    local group = globals.groups[groupIndex]
    for _, container in ipairs(group.containers) do
        globals.Settings.processContainerMedia(container)
    end
  end

  local group = globals.groups[groupIndex]
  local path = Presets.getPresetsPath("Groups") .. name .. ".lua"
  local file = io.open(path, "w")
  
  if file then
    file:write("-- Ambiance Creator Group Preset: " .. name .. "\n")
    file:write("-- Created on " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    file:write("return " .. serializeTable(group) .. "\n")
    file:close()
    
    -- Refresh the preset list
    Presets.listPresets("Groups", nil, true)
    return true
  end
  
  return false
end

-- Function to load a group preset
function Presets.loadGroupPreset(name, groupIndex)
  if name == "" then return false end
  
  local path = Presets.getPresetsPath("Groups") .. name .. ".lua"
  local success, presetData = pcall(dofile, path)
  
  if success and type(presetData) == "table" then
    globals.groups[groupIndex] = presetData
    return true
  else
    reaper.ShowConsoleMsg("Error loading group preset: " .. tostring(presetData) .. "\n")
    return false
  end
end

-- Function to save a container preset
function Presets.saveContainerPreset(name, groupIndex, containerIndex)
  if name == "" then return false end
  
  if globals.Settings and globals.Settings.getSetting("autoImportMedia") then
    local container = globals.groups[groupIndex].containers[containerIndex]
    globals.Settings.processContainerMedia(container)
  end

  -- Suppression de la référence au nom de la piste
  local container = globals.groups[groupIndex].containers[containerIndex]
  local path = Presets.getPresetsPath("Containers") .. name .. ".lua"
  local file = io.open(path, "w")
  
  if file then
    file:write("-- Ambiance Creator Container Preset: " .. name .. "\n")
    file:write("-- Created on " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    file:write("return " .. serializeTable(container) .. "\n")
    file:close()
    
    -- Rafraîchir la liste des presets sans référence au groupName
    Presets.listPresets("Containers", nil, true)
    return true
  end
  
  return false
end

-- Function to load a container preset
function Presets.loadContainerPreset(name, groupIndex, containerIndex)
  if name == "" then return false end
  
  -- Suppression de la référence au nom de la piste
  local path = Presets.getPresetsPath("Containers") .. name .. ".lua"
  local success, presetData = pcall(dofile, path)
  
  if success and type(presetData) == "table" then
    -- Préservation des items existants
    local existingItems = globals.groups[groupIndex].containers[containerIndex].items
    
    -- Application du preset
    globals.groups[groupIndex].containers[containerIndex] = presetData
    
    -- Restauration des items
    globals.groups[groupIndex].containers[containerIndex].items = existingItems
    
    return true
  else
    reaper.ShowConsoleMsg("Error loading container preset: " .. tostring(presetData) .. "\n")
    return false
  end
end


return Presets
