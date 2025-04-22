--[[
Sound Randomizer for REAPER
This script provides a GUI interface for creating randomized ambient sounds
It allows creating groups with containers of audio items that can be randomized by pitch, volume, and pan
Uses ReaImGui for UI rendering
]]

local UI = {}
local globals = {}

local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")

-- Import UI modules
local UI_Preset = require("DM_Ambiance_UI_Preset")
local UI_Container = require("DM_Ambiance_UI_Container")
local UI_Groups = require("DM_Ambiance_UI_Groups")
local UI_MultiSelection = require("DM_Ambiance_UI_MultiSelection")
local UI_Generation = require("DM_Ambiance_UI_Generation")
local UI_Group = require("DM_Ambiance_UI_Group")

-- Initialize the module with global variables from the main script
function UI.initModule(g)
    globals = g
    
    -- Initialize selection grouping variables for two-panel layout
    globals.selectedGroupIndex = nil
    globals.selectedContainerIndex = nil
    
    -- Initialize structure for multi-selection
    globals.selectedContainers = {} -- Format: {[groupIndex_containerIndex] = true}
    globals.inMultiSelectMode = false
    
    -- Initialize variables for Shift multi-selection
    globals.shiftAnchorGroupIndex = nil
    globals.shiftAnchorContainerIndex = nil
    
    -- Initialize UI sub-modules
    UI_Preset.initModule(globals)
    UI_Container.initModule(globals)
    UI_Groups.initModule(globals)
    UI_MultiSelection.initModule(globals)
    UI_Generation.initModule(globals)
    UI_Group.initModule(globals)
    
    -- Make UI_Groups accessible to the UI_Group module
    globals.UI_Groups = UI_Groups
end

-- Fonction PushStyle recommandée par le développeur
function UI.PushStyle()
    --globals.imgui.PushStyleVar(globals.ctx, globals.imgui.StyleVar_WindowPadding(), 10, 10)
end

-- Fonction PopStyle recommandée par le développeur
function UI.PopStyle()
    --globals.imgui.PopStyleVar(globals.ctx, 1)
end

-- Function to clear all container selections
local function clearContainerSelections()
    globals.selectedContainers = {}
    globals.inMultiSelectMode = false
    -- Also clear the shift anchor when clearing selections
    globals.shiftAnchorGroupIndex = nil
    globals.shiftAnchorContainerIndex = nil
end

-- Function to check if a container is selected
local function isContainerSelected(groupIndex, containerIndex)
    return globals.selectedContainers[groupIndex .. "_" .. containerIndex] == true
end

-- Function to toggle container selection
local function toggleContainerSelection(groupIndex, containerIndex)
    local key = groupIndex .. "_" .. containerIndex
    if globals.selectedContainers[key] then
        globals.selectedContainers[key] = nil
    else
        globals.selectedContainers[key] = true
    end
    -- Update primary selection for compatibility
    globals.selectedGroupIndex = groupIndex
    globals.selectedContainerIndex = containerIndex
end

-- Function to select a range of containers between two points
local function selectContainerRange(startGroupIndex, startContainerIndex, endGroupIndex, endContainerIndex)
    -- Clear existing selection first if not in multi-select mode
    if not (globals.imgui.GetKeyMods(globals.ctx) & globals.imgui.Mod_Ctrl() ~= 0) then
        clearContainerSelections()
    end
    
    -- Handle range selection within the same group
    if startGroupIndex == endGroupIndex then
        local group = globals.groups[startGroupIndex]
        local startIdx = math.min(startContainerIndex, endContainerIndex)
        local endIdx = math.max(startContainerIndex, endContainerIndex)
        for i = startIdx, endIdx do
            if i <= #group.containers then
                globals.selectedContainers[startGroupIndex .. "_" .. i] = true
            end
        end
        return
    end
    
    -- Handle range selection across different groups
    local startGroup = math.min(startGroupIndex, endGroupIndex)
    local endGroup = math.max(startGroupIndex, endGroupIndex)
    
    -- If selecting from higher group to lower group, reverse the container indices
    local firstContainerIdx, lastContainerIdx
    if startGroupIndex < endGroupIndex then
        firstContainerIdx, lastContainerIdx = startContainerIndex, endContainerIndex
    else
        firstContainerIdx, lastContainerIdx = endContainerIndex, startContainerIndex
    end
    
    -- Select all containers in the range
    for t = startGroup, endGroup do
        if globals.groups[t] then
            if t == startGroup then
                -- First group: select from firstContainerIdx to end
                for c = firstContainerIdx, #globals.groups[t].containers do
                    globals.selectedContainers[t .. "_" .. c] = true
                end
            elseif t == endGroup then
                -- Last group: select from start to lastContainerIdx
                for c = 1, lastContainerIdx do
                    globals.selectedContainers[t .. "_" .. c] = true
                end
            else
                -- Middle groups: select all containers
                for c = 1, #globals.groups[t].containers do
                    globals.selectedContainers[t .. "_" .. c] = true
                end
            end
        end
    end
    
    -- Update the multi-select mode flag
    globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
end

-- Function to draw the left panel containing groups and containers list
local function drawLeftPanel(width)
    UI_Groups.drawGroupsPanel(width, isContainerSelected, toggleContainerSelection, clearContainerSelections, selectContainerRange)
end

-- Function to draw the right panel containing detailed settings for the selected container
local function drawRightPanel(width)
    -- If we're in multi-select mode, draw the multi-selection panel
    if globals.inMultiSelectMode then
        UI_MultiSelection.drawMultiSelectionPanel(width)
        return
    end
    
    -- Show container details if a container is selected
    if globals.selectedGroupIndex and globals.selectedContainerIndex then
        UI_Container.displayContainerSettings(globals.selectedGroupIndex, globals.selectedContainerIndex, width)
    elseif globals.selectedGroupIndex then
        -- Show group details if only a group is selected
        UI_Group.displayGroupSettings(globals.selectedGroupIndex, width)
    else
        -- No selection
        globals.imgui.TextColored(globals.ctx, 0xFFAA00FF, "Select a group or container to view and edit its settings.")
    end
end

-- Function to handle popup management and timeout
local function handlePopups()
    -- Check for any popup that might be stuck (safety measure)
    for name, popup in pairs(globals.activePopups or {}) do
        if popup.active and reaper.time_precise() - popup.timeOpened > 5 then
            -- Force close popups that have been open too long (5 seconds)
            globals.imgui.CloseCurrentPopup(globals.ctx)
            globals.activePopups[name] = nil
        end
    end
end

-- Nouvelle fonction ShowMainWindow conformément aux recommandations du développeur
function UI.ShowMainWindow(open)
    local visible, open = globals.imgui.Begin(globals.ctx, 'Ambiance Creator', open)
    
    if visible then
        -- Section with presets controls at the top
        UI_Preset.drawPresetControls()
        
        -- Button to generate all groups and place items
        globals.imgui.SameLine(globals.ctx)
        UI_Generation.drawMainGenerationButton()
        
        -- Display time selection information
        UI_Generation.drawTimeSelectionInfo()
        
        globals.imgui.Separator(globals.ctx)
        
        -- Calculate dimensions for the split view layout
        local windowWidth = globals.imgui.GetWindowWidth(globals.ctx)
        local leftPanelWidth = windowWidth * 0.35
        local rightPanelWidth = windowWidth * 0.63
        
        -- Left panel (Groups & Containers list)
        globals.imgui.BeginChild(globals.ctx, "LeftPanel", leftPanelWidth, 0)
        drawLeftPanel(leftPanelWidth)
        globals.imgui.EndChild(globals.ctx)
        
        -- Right panel (Container Settings)
        globals.imgui.SameLine(globals.ctx)
        globals.imgui.BeginChild(globals.ctx, "RightPanel", rightPanelWidth, 0)
        drawRightPanel(rightPanelWidth)
        globals.imgui.EndChild(globals.ctx)
    end
    
    globals.imgui.End(globals.ctx)
    
    -- Handle popup management
    handlePopups()
    
    return open
end

-- Fonction mainLoop pour compatibilité avec l'ancienne structure
function UI.mainLoop()
    UI.PushStyle()
    local open = UI.ShowMainWindow(true)
    UI.PopStyle()
    
    if open then
        reaper.defer(UI.mainLoop)
    end
    -- Note: DestroyContext a été supprimé et n'est plus nécessaire
end

return UI
