--[[
@version 1.3
@noindex
--]]

local Presets = {}
local globals = {}
local presetCache = {}
local presetCacheTime = {}

-- Initialize the module with global references from the main script
function Presets.initModule(g)
  globals = g
end

-- Function to determine the path for presets, creating the folder structure if needed
function Presets.getPresetsPath(type, groupName)
  local basePath

  if globals.presetsPath ~= "" then 
    basePath = globals.presetsPath 
  else
    -- Define the base path depending on the OS
    if reaper.GetOS():match("Win") then
      basePath = os.getenv("APPDATA") .. "\\REAPER\\Scripts\\Demute\\Ambiance Creator\\Presets\\"
    elseif reaper.GetOS():match("OSX") then
      basePath = os.getenv("HOME") .. "/Library/Application Support/REAPER/Scripts/Demute/Ambiance Creator/Presets/"
    else -- Linux
      basePath = os.getenv("HOME") .. "/.config/REAPER/Scripts/Demute/Ambiance Creator/Presets/"
    end

    -- Create the base directory if it doesn't exist
    local command
    if reaper.GetOS():match("Win") then
      command = 'if not exist "' .. basePath .. '" mkdir "' .. basePath .. '"'
    else
      command = 'mkdir -p "' .. basePath .. '"'
    end
    os.execute(command)

    globals.presetsPath = basePath
  end

  -- Determine the subfolder based on the preset type
  local specificPath = basePath

  if type == "Global" then
    specificPath = basePath .. "Global\\"
  elseif type == "Groups" then
    specificPath = basePath .. "Groups\\"
  elseif type == "Containers" then
    -- Remove dependency on groupName for containers
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

-- Function to list available presets by type, with optional cache and force refresh
function Presets.listPresets(type, groupName, forceRefresh)
  local currentTime = os.time()
  local cacheKey = type -- No need to include groupName for containers

  if not type then type = "Global" end

  -- Initialize cache if necessary
  if not presetCache then presetCache = {} end
  if not presetCacheTime then presetCacheTime = {} end

  if not forceRefresh and presetCache[cacheKey] then
    return presetCache[cacheKey] -- Return from cache if available
  end

  -- Get the directory path (groupName ignored for containers)
  local path = Presets.getPresetsPath(type, nil)

  -- Reset the preset list
  local typePresets = {}

  -- Use reaper.EnumerateFiles to list all .lua preset files
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

-- Helper function to serialize a table into a Lua string
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

-- Save a global preset (all groups) to disk
function Presets.savePreset(name)
  if name == "" then return false end

  -- If auto-import media is enabled, process all containers in all groups
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

-- Load a global preset from disk and set it as the current groups
function Presets.loadPreset(name)
  if name == "" then return false end

  globals.selectedContainers = {}
  
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

-- Delete a preset file by name and type
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

-- Save a group preset (single group) to disk
function Presets.saveGroupPreset(name, groupIndex)
  if name == "" then return false end

  -- If auto-import media is enabled, process all containers in the group
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

-- Load a group preset from disk and assign it to the specified group index
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

-- Save a container preset (single container) to disk
function Presets.saveContainerPreset(name, groupIndex, containerIndex)
  if name == "" then return false end

  -- If auto-import media is enabled, process the container
  if globals.Settings and globals.Settings.getSetting("autoImportMedia") then
    local container = globals.groups[groupIndex].containers[containerIndex]
    globals.Settings.processContainerMedia(container)
  end

  -- Remove any reference to track name (if any)
  local container = globals.groups[groupIndex].containers[containerIndex]
  local path = Presets.getPresetsPath("Containers") .. name .. ".lua"
  local file = io.open(path, "w")

  if file then
    file:write("-- Ambiance Creator Container Preset: " .. name .. "\n")
    file:write("-- Created on " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    file:write("return " .. serializeTable(container) .. "\n")
    file:close()

    -- Refresh the preset list (no groupName reference)
    Presets.listPresets("Containers", nil, true)
    return true
  end

  return false
end

-- Load a container preset from disk and apply it to the specified container, preserving existing items
function Presets.loadContainerPreset(name, groupIndex, containerIndex)
  if name == "" then return false end

  -- Remove any reference to track name (if any)
  local path = Presets.getPresetsPath("Containers") .. name .. ".lua"
  local success, presetData = pcall(dofile, path)

  if success and type(presetData) == "table" then
    -- Appliquer directement le preset chargé sans préserver les items existants
    globals.groups[groupIndex].containers[containerIndex] = presetData
    
    return true
  else
    reaper.ShowConsoleMsg("Error loading container preset: " .. tostring(presetData) .. "\n")
    return false
  end
end

return Presets
