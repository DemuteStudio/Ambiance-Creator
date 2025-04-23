-- Sound Randomizer - Reaper Script
-- Allows creating groups and containers to organize audio samples with advanced preset management
-- Features selective regeneration of individual groups and containers

-- Check if ReaImGui exists
if not reaper.ImGui_CreateContext then
    reaper.MB("This script requires ReaImGui. Please install the extension via ReaPack.", "Error", 0)
    return
end

-- Proper initialization of ReaImGui as recommended by the developer
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.9.3'

-- Define path for modules
local script_path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "modules/?.lua;" .. package.path

-- Import modules
local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")
local UI = require("DM_Ambiance_UI")

-- Global variables
local globals = {
    groups = {},                      -- Stores all defined groups
    timeSelectionValid = false,       -- Indicates if a valid time selection exists
    startTime = 0,                    -- Start time of selection
    endTime = 0,                      -- End time of selection
    timeSelectionLength = 0,          -- Length of the time selection
    currentPresetName = "",           -- Currently loaded preset name
    presetsPath = "",                 -- Path to presets directory
    selectedGroupPresetIndex = {},    -- Indices of selected group presets
    selectedContainerPresetIndex = {},-- Indices of selected container presets
    currentSaveGroupIndex = nil,      -- Group index for saving
    currentSaveContainerGroup = nil,  -- Container group for saving
    currentSaveContainerIndex = nil,  -- Container index for saving
    newGroupPresetName = "",          -- New group preset name input
    newContainerPresetName = "",      -- New container preset name input
    newPresetName = "",               -- New global preset name input
    selectedPresetIndex = -1,         -- Index of selected preset
    activePopups = {}                 -- Tracking active popup windows
}

-- Main loop function for the GUI
local function loop()
    UI.PushStyle()
    local open = UI.ShowMainWindow(true)
    UI.PopStyle()

    if open then
        reaper.defer(loop)
    end
end

-- Script entry point when run directly
if select(2, reaper.get_action_context()) == debug.getinfo(1, 'S').source:sub(2) then
    -- Expose variables for debugging
    _G.globals = globals
    _G.Utils = Utils
    _G.Structures = Structures
    _G.Items = Items
    _G.Presets = Presets
    _G.Generation = Generation
    _G.UI = UI
    _G.imgui = imgui
    
    math.randomseed(os.time())
    
    -- Create ImGui context
    local ctx = imgui.CreateContext('Ambiance Creator')
    globals.ctx = ctx
    globals.imgui = imgui
    
    -- Share modules with globals for access across the application
    globals.Utils = Utils
    globals.Structures = Structures
    globals.Items = Items
    globals.Presets = Presets
    globals.Generation = Generation
    globals.UI = UI
    
    -- Initialize modules
    Utils.initModule(globals)
    Structures.initModule(globals)
    Items.initModule(globals)
    Presets.initModule(globals)
    Generation.initModule(globals)
    UI.initModule(globals)
    
    -- Initialize preset paths
    globals.presetsPath = "" -- Reset to force directory creation
    Presets.getPresetsPath("Global")
    Presets.getPresetsPath("Groups")
    
    -- Start the main loop
    reaper.defer(loop)
end
