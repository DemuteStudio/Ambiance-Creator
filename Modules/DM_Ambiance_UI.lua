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
    
    -- Make UI accessible to other modules
    globals.UI = UI
end

-- PushStyle function recommended by the developer
function UI.PushStyle()
    --globals.imgui.PushStyleVar(globals.ctx, globals.imgui.StyleVar_WindowPadding(), 10, 10)
end

-- PopStyle function recommended by the developer
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

-- Common function to draw trigger settings section
-- dataObj must expose the fields intervalMode, triggerRate, triggerDrift, fadeIn, fadeOut
-- callbacks must contain setIntervalMode, setTriggerRate, setTriggerDrift, setFadeIn, setFadeOut functions
-- Dessine la section « Trigger Settings » avec fade in/out
-- Dessine la section « Trigger Settings » avec fade in/out linéaires
function UI.drawTriggerSettingsSection(dataObj, callbacks, width, titlePrefix, objId)
    -- Séparateur et titre
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, titlePrefix .. "Trigger Settings")

    -- Mode d'intervalle
    local intervalModes = "Absolute\0Relative\0Coverage\0\0"
    if dataObj.intervalMode == 0 then
        if dataObj.triggerRate < 0 then
            imgui.TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
        else
            imgui.TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
        end
    elseif dataObj.intervalMode == 1 then
        imgui.TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
    else
        imgui.TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
    end

    local comboId = "Interval Mode"
    if objId then comboId = comboId .. "##" .. objId end
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local changed, newMode = imgui.Combo(globals.ctx, comboId, dataObj.intervalMode, intervalModes)
    if changed then callbacks.setIntervalMode(newMode) end
    imgui.SameLine(globals.ctx)
    globals.Utils.HelpMarker(
        "Absolute: Fixed interval in seconds\n" ..
        "Relative: Interval as percentage of time selection\n" ..
        "Coverage: Percentage of time selection to be filled"
    )

    -- Intervalle / couverture
    local rateLabel, minRate, maxRate = "Interval (sec)", -10.0, 60.0
    if dataObj.intervalMode == 1 then
        rateLabel, minRate, maxRate = "Interval (%)", 0.1, 100.0
    elseif dataObj.intervalMode == 2 then
        rateLabel, minRate, maxRate = "Coverage (%)", 0.1, 100.0
    end
    local rateId = rateLabel
    if objId then rateId = rateId .. "##" .. objId end
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local ch2, newRate = imgui.SliderDouble(globals.ctx, rateId, dataObj.triggerRate, minRate, maxRate, "%.1f")
    if ch2 then callbacks.setTriggerRate(newRate) end

    -- Variation aléatoire
    local driftId = "Random variation (%)"
    if objId then driftId = driftId .. "##" .. objId end
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local ch3, newDrift = imgui.SliderInt(globals.ctx, driftId, dataObj.triggerDrift, 0, 100, "%d")
    if ch3 then callbacks.setTriggerDrift(newDrift) end

    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, titlePrefix .. "Fades")

    -- Fade in
    local fadeInId = "Fade in (sec)"
    if objId then fadeInId = fadeInId .. "##" .. objId end
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local ch4, newFadeIn = imgui.InputDouble(globals.ctx, fadeInId, dataObj.fadeIn or 0.0, 0.01, 0.1, "%.3f")
    if ch4 then callbacks.setFadeIn(math.max(0, newFadeIn)) end
    imgui.SameLine(globals.ctx)
    do
        local drawList = imgui.GetWindowDrawList(globals.ctx)
        local x, y = imgui.GetCursorScreenPos(globals.ctx)
        local curveSize, curveHeight = 40, 15
        
        -- Dessin du fade in avec une ligne linéaire au lieu d'une courbe
        imgui.DrawList_AddLine(
            drawList,
            x, y + curveHeight,              -- Point de départ (bas gauche)
            x + curveSize, y,                -- Point d'arrivée (haut droite)
            0xFFFFFFFF,                      -- Couleur (blanc)
            1.5                              -- Épaisseur
        )
        imgui.Dummy(globals.ctx, curveSize, curveHeight)
    end

    -- Fade out
    local fadeOutId = "Fade out (sec)"
    if objId then fadeOutId = fadeOutId .. "##" .. objId end
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local ch5, newFadeOut = imgui.InputDouble(globals.ctx, fadeOutId, dataObj.fadeOut or 0.0, 0.01, 0.1, "%.3f")
    if ch5 then callbacks.setFadeOut(math.max(0, newFadeOut)) end
    imgui.SameLine(globals.ctx)
    do
        local drawList = imgui.GetWindowDrawList(globals.ctx)
        local x, y = imgui.GetCursorScreenPos(globals.ctx)
        local curveSize, curveHeight = 40, 15
        
        -- Dessin du fade out avec une ligne linéaire au lieu d'une courbe
        imgui.DrawList_AddLine(
            drawList,
            x, y,                            -- Point de départ (haut gauche)
            x + curveSize, y + curveHeight,  -- Point d'arrivée (bas droite)
            0xFFFFFFFF,                      -- Couleur (blanc)
            1.5                              -- Épaisseur
        )
        imgui.Dummy(globals.ctx, curveSize, curveHeight)
    end
end



-- Function to display trigger and randomization settings
function UI.displayTriggerSettings(obj, objId, width, isGroup)
    -- Determine display text based on whether it's a group or container
    local titlePrefix = isGroup and "Default " or ""
    local inheritText = isGroup and "These settings will be inherited by containers unless overridden" or ""
    
    -- TRIGGER SETTINGS SECTION
    if inheritText ~= "" then
        imgui.TextColored(globals.ctx, 0xFFAA00FF, inheritText)
    end
    
    -- Initialize fade properties if they don't exist
    obj.fadeIn = obj.fadeIn or 0.0
    obj.fadeOut = obj.fadeOut or 0.0
    
    -- Use the common trigger settings function
    UI.drawTriggerSettingsSection(
        obj, -- data object
        { -- callbacks
            setIntervalMode = function(v) obj.intervalMode = v end,
            setTriggerRate = function(v) obj.triggerRate = v end,
            setTriggerDrift = function(v) obj.triggerDrift = v end,
            setFadeIn = function(v) obj.fadeIn = math.max(0, v) end,
            setFadeOut = function(v) obj.fadeOut = math.max(0, v) end,
        },
        width,
        titlePrefix,
        objId
    )
    
    -- RANDOMIZATION PARAMETERS SECTION
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, titlePrefix .. "Randomization parameters")
    
    -- Pitch randomization checkbox
    local randomizePitch = obj.randomizePitch
    local rv, newRandomizePitch = imgui.Checkbox(globals.ctx, "Randomize Pitch##" .. objId, randomizePitch)
    if rv then obj.randomizePitch = newRandomizePitch end
    
    -- Only show pitch range if pitch randomization is enabled
    if obj.randomizePitch then
        local pitchMin = obj.pitchRange.min
        local pitchMax = obj.pitchRange.max
        imgui.PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPitchMin, newPitchMax = imgui.DragFloatRange2(globals.ctx, "Pitch Range (semitones)##" .. objId, pitchMin, pitchMax, 0.1, -48, 48)
        if rv then
            obj.pitchRange.min = newPitchMin
            obj.pitchRange.max = newPitchMax
        end
    end
    
    -- Volume randomization checkbox
    local randomizeVolume = obj.randomizeVolume
    local rv, newRandomizeVolume = imgui.Checkbox(globals.ctx, "Randomize Volume##" .. objId, randomizeVolume)
    if rv then obj.randomizeVolume = newRandomizeVolume end
    
    -- Only show volume range if volume randomization is enabled
    if obj.randomizeVolume then
        local volumeMin = obj.volumeRange.min
        local volumeMax = obj.volumeRange.max
        imgui.PushItemWidth(globals.ctx, width * 0.7)
        local rv, newVolumeMin, newVolumeMax = imgui.DragFloatRange2(globals.ctx, "Volume Range (dB)##" .. objId, volumeMin, volumeMax, 0.1, -24, 24)
        if rv then
            obj.volumeRange.min = newVolumeMin
            obj.volumeRange.max = newVolumeMax
        end
    end
    
    -- Pan randomization checkbox
    local randomizePan = obj.randomizePan
    local rv, newRandomizePan = imgui.Checkbox(globals.ctx, "Randomize Pan##" .. objId, randomizePan)
    if rv then obj.randomizePan = newRandomizePan end
    
    -- Only show pan range if pan randomization is enabled
    if obj.randomizePan then
        local panMin = obj.panRange.min
        local panMax = obj.panRange.max
        imgui.PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPanMin, newPanMax = imgui.DragFloatRange2(globals.ctx, "Pan Range (-100/+100)##" .. objId, panMin, panMax, 1, -100, 100)
        if rv then
            obj.panRange.min = newPanMin
            obj.panRange.max = newPanMax
        end
    end
end

-- Function to check if a container is selected
local function isContainerSelected(groupIndex, containerIndex)
    return globals.selectedContainers[groupIndex .. "_" .. containerIndex] == true
end

-- Function to toggle container selection
local function toggleContainerSelection(groupIndex, containerIndex)
    local key = groupIndex .. "_" .. containerIndex
    
    -- Check if Shift key is pressed
    local isShiftPressed = (globals.imgui.GetKeyMods(globals.ctx) & globals.imgui.Mod_Shift ~= 0)
    
    -- If Shift is pressed and we have an anchor point, select range
    if isShiftPressed and globals.shiftAnchorGroupIndex and globals.shiftAnchorContainerIndex then
        -- Shift key: select range from anchor to current
        selectContainerRange(globals.shiftAnchorGroupIndex, globals.shiftAnchorContainerIndex, groupIndex, containerIndex)
    else
        -- Regular selection (without Shift)
        if not (globals.imgui.GetKeyMods(globals.ctx) & globals.imgui.Mod_Ctrl ~= 0) then
            -- Clear previous selections if Ctrl is not pressed
            clearContainerSelections()
        end
        
        -- Toggle the current container selection
        if globals.selectedContainers[key] then
            globals.selectedContainers[key] = nil
        else
            globals.selectedContainers[key] = true
        end
        
        -- Update anchor point for future Shift selections
        globals.shiftAnchorGroupIndex = groupIndex
        globals.shiftAnchorContainerIndex = containerIndex
    end
    
    -- Update primary selection for compatibility
    globals.selectedGroupIndex = groupIndex
    globals.selectedContainerIndex = containerIndex
    
    -- Update multi-select mode flag
    globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
end

-- Function to select a range of containers between two points
local function selectContainerRange(startGroupIndex, startContainerIndex, endGroupIndex, endContainerIndex)
    -- Clear existing selection first if not in multi-select mode
    if not (globals.imgui.GetKeyMods(globals.ctx) & globals.imgui.Mod_Ctrl ~= 0) then
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
    -- Check if available space is sufficient
    local availHeight = globals.imgui.GetWindowHeight(globals.ctx)
    if availHeight < 100 then -- Reasonable minimum height
        globals.imgui.TextColored(globals.ctx, 0xFF0000FF, "Window too small")
        return
    end
    
    -- Call the normal function when space is sufficient
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

-- Show the main window
function UI.ShowMainWindow(open)
    globals.imgui.SetNextWindowSizeConstraints(globals.ctx, 600, 400, -1, -1)
    local visible, open = globals.imgui.Begin(globals.ctx, 'Ambiance Creator', open)
    
    if visible then
        -- Section with preset controls at the top
        UI_Preset.drawPresetControls()
        globals.imgui.SameLine(globals.ctx)
        UI_Generation.drawMainGenerationButton()
        UI_Generation.drawTimeSelectionInfo()
        globals.imgui.Separator(globals.ctx)
        
        -- Calculate dimensions for two-panel layout
        local windowWidth = globals.imgui.GetWindowWidth(globals.ctx)
        local leftPanelWidth = windowWidth * 0.35
        local rightPanelWidth = windowWidth * 0.63
        
        -- Left panel (Groups & Containers list)
        if globals.imgui.BeginChild(globals.ctx, "LeftPanel", leftPanelWidth, 0) then
            drawLeftPanel(leftPanelWidth)
            globals.imgui.EndChild(globals.ctx)
        end
        
        -- Right panel (Container settings)
        globals.imgui.SameLine(globals.ctx)
        if globals.imgui.BeginChild(globals.ctx, "RightPanel", rightPanelWidth, 0) then
            drawRightPanel(rightPanelWidth)
            globals.imgui.EndChild(globals.ctx)
        end
    end
    
    globals.imgui.End(globals.ctx)
    handlePopups()
    return open
end

return UI
