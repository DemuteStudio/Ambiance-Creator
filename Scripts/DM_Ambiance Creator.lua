--[[
@description DM_Ambiance Creator
@version 1.5
@about
    The Ambiance Creator is a tool that makes it easy to create soundscapes by randomly placing audio elements on the REAPER timeline according to user parameters.
@author Anthony Deneyer
@provides
    [nomain] Modules/*.lua
@changelog
    1.0
        Initial Release
    1.1
        Fix freeze issue with sliders in the setting windows
    1.2
        Minor updates and improvements  
    1.3
        Partial fixes and improvements
    1.4
        Fix critical ImGui assertion error "Calling End() too many times!"
            - Fixed improper Begin/End pattern that caused crashes when collapsing window or switching between docked/embedded modes
            - Improved stability when switching window states and popup handling
            - No more crashes when clicking collapse arrow or changing dock states
        Fix confusing UI terminology
            - Renamed "Override Existing Track" option to "Keep Existing Track" to properly reflect its actual behavior
            - Inverted internal logic to match the new naming convention
            - Clarified help text to better explain the two generation modes
        Fix track folder structure corruption when adding containers to existing groups
            - Fixed issue where adding a new container to an existing group would change the entire track folder structure
            - New containers now properly inherit folder structure without affecting other tracks
        Fix auto-collapse behavior when removing items from container lists
            - Fixed issue where the "Imported items" section would automatically collapse every time an item was removed
            - Users can now remove multiple items consecutively without having to re-expand the list each time
        Added Drag and Drop functionality
            - Groups can now be reordered by dragging and dropping them
            - Containers can be moved between groups via drag and drop
            - REAPER track structure automatically reorganizes to match the new arrangement
            - Visual feedback during drag operations shows what's being moved
    1.5
        Volume Control Feature
        UI Enhancement - PNG Icon Integration
        Added Link Mode System for Randomization Parameters
            - New link mode buttons for pitch, volume, and pan controls
            - Three modes: Unlink (independent), Link (relative movement), Mirror (opposite movement)
            - Default mode changed to Mirror for intuitive opposite behavior (e.g., pan -100/+100)
        Fade Control System
            - Added link mode for fade in/out parameters with Link and Unlink modes only
            - Fades enabled by default with 0.0 second duration for immediate availability
            - Default fade link mode set to Link for synchronized fade behavior
        Pan Envelope Handling Enhancement
            - Create, update, and remove envelopes based on item selection and randomization settings
        Real Time Time Parameters and Fade Parameters


--]]

-- Check if ReaImGui is available; display an error and exit if not
if not reaper.ImGui_CreateContext then
    reaper.MB("This script requires ReaImGui. Please install the extension via ReaPack.", "Error", 0)
    return
end

-- Proper initialization of ReaImGui as recommended by the developer
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.9.3'

-- Define the path for custom modules (relative to the script location)
local script_path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "modules/?.lua;" .. package.path

-- Import all project modules
local Constants = require("DM_Ambiance_Constants")
local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")
local UI = require("DM_Ambiance_UI")
local Settings = require("DM_AmbianceCreator_Settings")

-- Global state shared across modules and UI
local globals = {
    groups = {},                      -- Stores all defined groups
    timeSelectionValid = false,       -- Indicates if a valid time selection exists in the project
    startTime = 0,                    -- Start time of the current time selection
    endTime = 0,                      -- End time of the current time selection
    timeSelectionLength = 0,          -- Length of the time selection
    currentPresetName = "",           -- Name of the currently loaded global preset
    presetsPath = "",                 -- Path to the presets directory
    selectedGroupPresetIndex = {},    -- Stores selected group preset indices for each group
    selectedContainerPresetIndex = {},-- Stores selected container preset indices for each container
    currentSaveGroupIndex = nil,      -- Index of the group currently being saved as a preset
    currentSaveContainerGroup = nil,  -- Index of the group for the container being saved
    currentSaveContainerIndex = nil,  -- Index of the container being saved as a preset
    newGroupPresetName = "",          -- Input field for new group preset name
    newContainerPresetName = "",      -- Input field for new container preset name
    newPresetName = "",               -- Input field for new global preset name
    selectedPresetIndex = -1,         -- Index of the currently selected global preset
    activePopups = {},                -- Table tracking active popup windows
    showMediaDirWarning = false,      -- Flag to display a warning if the media directory is not configured
    mediaWarningShown = false,        -- Prevents showing the media warning multiple times
    keepExistingTracks = true,        -- Default behavior for generation (changed from overrideExistingTracks)
    containerExpandedStates = {},     -- Stores expanded/collapsed states for container item lists to prevent auto-collapse
    
    -- Pending operations to avoid ImGui conflicts
    pendingGroupMove = nil,           -- Pending group reorder operation
    pendingContainerMove = nil,       -- Pending container move operation
    pendingContainerReorder = nil,    -- Pending container reorder within same group
    
    -- Drag and drop state
    draggedItem = nil,                -- Currently dragged item info
}

-- Main loop function for the GUI; called repeatedly via reaper.defer
local function loop()
    UI.PushStyle()

    -- Show the media directory warning popup ONLY if required
    if globals.showMediaDirWarning then
        Utils.showDirectoryWarningPopup()
    end

    -- Render the main window; returns 'open' (true if window is open)
    local open = UI.ShowMainWindow(true)
    
    UI.PopStyle()

    -- Continue the loop if the window is still open
    if open then
        reaper.defer(loop)
    end
end

-- Script entry point when run directly (not as a module)
if select(2, reaper.get_action_context()) == debug.getinfo(1, 'S').source:sub(2) then
    -- Expose variables and modules globally for debugging and live tweaking
    _G.globals = globals
    _G.Constants = Constants
    _G.Utils = Utils
    _G.Structures = Structures
    _G.Items = Items
    _G.Presets = Presets
    _G.Generation = Generation
    _G.UI = UI
    _G.Settings = Settings
    _G.imgui = imgui

    -- Seed the random number generator for consistent randomization
    math.randomseed(os.time())

    -- Create the ImGui context for the application window
    local ctx = imgui.CreateContext('Ambiance Creator')
    globals.ctx = ctx
    globals.imgui = imgui

    -- Share module references through the globals table for cross-module access
    globals.Constants = Constants
    globals.Utils = Utils
    globals.Structures = Structures
    globals.Items = Items
    globals.Presets = Presets
    globals.Generation = Generation
    globals.UI = UI
    globals.Settings = Settings

    -- Initialize all modules with the shared globals table
    Utils.initModule(globals)
    Structures.initModule(globals)
    Items.initModule(globals)
    Presets.initModule(globals)
    Generation.initModule(globals)
    UI.initModule(globals)
    Settings.initModule(globals)
    
    -- Initialize backward compatibility for container volumes
    Utils.initializeContainerVolumes()

    -- Force preset path initialization (ensures folders are created)
    globals.presetsPath = "" -- Reset to force directory creation
    Presets.getPresetsPath("Global")
    Presets.getPresetsPath("Groups")

    -- Start the main UI loop
    reaper.defer(loop)
end