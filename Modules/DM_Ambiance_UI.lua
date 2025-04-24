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
    imgui.PushStyleVar(globals.ctx, imgui.StyleVar_DisabledAlpha, 0.68)
    imgui.PushStyleVar(globals.ctx, imgui.StyleVar_FrameRounding, 2)
    imgui.PushStyleVar(globals.ctx, imgui.StyleVar_GrabRounding,  2)
end

-- PopStyle function recommended by the developer
function UI.PopStyle()
    imgui.PopStyleVar(globals.ctx, 3)
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
function UI.drawTriggerSettingsSection(dataObj, callbacks, width, titlePrefix)
    -- Séparateur et titre de section
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, titlePrefix .. "Trigger Settings")
    
    -- VBox principale pour Trigger Settings
    
    -- Hauteur pour tous les contrôles
    local controlHeight = 20
    -- Largeur pour les contrôles
    local controlWidth = width * 0.55
    -- Largeur pour les labels
    local labelWidth = width * 0.35
    -- Padding pour l'alignement
    local padding = 5
    -- Largeur pour le visuel de fade
    local fadeVisualSize = 15
    
    -- Boîte horizontale pour le mode d'intervalle
    -- Espace info mode
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
    
    -- Interval Mode - HBox
    do
        -- VBox pour le contrôle à gauche
        imgui.BeginGroup(globals.ctx)
        imgui.PushItemWidth(globals.ctx, controlWidth)
        local intervalModes = "Absolute\0Relative\0Coverage\0\0"
        local rv, newIntervalMode = imgui.Combo(globals.ctx, "##IntervalMode", dataObj.intervalMode, intervalModes)
        if rv then callbacks.setIntervalMode(newIntervalMode) end
        imgui.EndGroup(globals.ctx)
        
        -- VBox pour le texte à droite
        imgui.SameLine(globals.ctx, controlWidth + padding)
        imgui.Text(globals.ctx, "Interval Mode")
        imgui.SameLine(globals.ctx)
        globals.Utils.HelpMarker(
            "Absolute: Fixed interval in seconds\n" ..
            "Relative: Interval as percentage of time selection\n" ..
            "Coverage: Percentage of time selection to be filled"
        )
    end
    
    -- Interval Seconds - HBox
    do
        -- Définir les propriétés du slider
        local rateLabel = "Interval (sec)"
        local rateMin = -10.0
        local rateMax = 60.0
        
        if dataObj.intervalMode == 1 then
            rateLabel = "Interval (%)"
            rateMin = 0.1
            rateMax = 100.0
        elseif dataObj.intervalMode == 2 then
            rateLabel = "Coverage (%)"
            rateMin = 0.1
            rateMax = 100.0
        end
        
        -- VBox pour le contrôle à gauche
        imgui.BeginGroup(globals.ctx)
        imgui.PushItemWidth(globals.ctx, controlWidth)
        local rv, newRate = imgui.SliderDouble(globals.ctx, "##TriggerRate", dataObj.triggerRate, rateMin, rateMax, "%.1f")
        if rv then callbacks.setTriggerRate(newRate) end
        imgui.EndGroup(globals.ctx)
        
        -- VBox pour le texte à droite
        imgui.SameLine(globals.ctx, controlWidth + padding)
        imgui.Text(globals.ctx, rateLabel)
    end
    
    -- Random Variation - HBox
    do
        -- VBox pour le contrôle à gauche
        imgui.BeginGroup(globals.ctx)
        imgui.PushItemWidth(globals.ctx, controlWidth)
        local rv, newDrift = imgui.SliderInt(globals.ctx, "##TriggerDrift", dataObj.triggerDrift, 0, 100, "%d")
        if rv then callbacks.setTriggerDrift(newDrift) end
        imgui.EndGroup(globals.ctx)
        
        -- VBox pour le texte à droite
        imgui.SameLine(globals.ctx, controlWidth + padding)
        imgui.Text(globals.ctx, "Random variation (%)")
    end
    
    -- -- Fade In - HBox
    -- do
    --     -- VBox pour le contrôle et la visualisation
    --     imgui.BeginGroup(globals.ctx)
    --     -- Zone pour le contrôle (slider)
    --     imgui.BeginGroup(globals.ctx)
    --     local sliderWidth = controlWidth - fadeVisualSize - padding
    --     imgui.PushItemWidth(globals.ctx, sliderWidth)
    --     local rv, newFadeIn = imgui.DragDouble(globals.ctx, "##FadeIn", dataObj.fadeIn or 0.0, 0.01, 0, 0, "%.3f")
    --     if rv then callbacks.setFadeIn(math.max(0, newFadeIn)) end
    --     imgui.EndGroup(globals.ctx)
        
    --     -- Visualisation du fade
    --     imgui.SameLine(globals.ctx)
    --     imgui.BeginGroup(globals.ctx)
    --     local drawList = imgui.GetWindowDrawList(globals.ctx)
    --     local x, y = imgui.GetCursorScreenPos(globals.ctx)
    --     imgui.DrawList_AddLine(
    --         drawList,
    --         x, y + fadeVisualSize,
    --         x + fadeVisualSize, y,
    --         0xFFFFFFFF,
    --         1.5
    --     )
    --     imgui.Dummy(globals.ctx, fadeVisualSize, fadeVisualSize)
    --     imgui.EndGroup(globals.ctx)
    --     imgui.EndGroup(globals.ctx)
        
    --     -- VBox pour le texte à droite
    --     imgui.SameLine(globals.ctx, controlWidth + padding)
    --     imgui.Text(globals.ctx, "Fade in (sec)")
    -- end
    
    -- -- Fade Out - HBox
    -- do
    --     -- VBox pour le contrôle et la visualisation
    --     imgui.BeginGroup(globals.ctx)
    --     -- Zone pour le contrôle (slider)
    --     imgui.BeginGroup(globals.ctx)
    --     local sliderWidth = controlWidth - fadeVisualSize - padding
    --     imgui.PushItemWidth(globals.ctx, sliderWidth)
    --     local rv, newFadeOut = imgui.DragDouble(globals.ctx, "##FadeOut", dataObj.fadeOut or 0.0, 0.01, 0, 0, "%.3f")
    --     if rv then callbacks.setFadeOut(math.max(0, newFadeOut)) end
    --     imgui.EndGroup(globals.ctx)
        
    --     -- Visualisation du fade
    --     imgui.SameLine(globals.ctx)
    --     imgui.BeginGroup(globals.ctx)
    --     local drawList = imgui.GetWindowDrawList(globals.ctx)
    --     local x, y = imgui.GetCursorScreenPos(globals.ctx)
    --     imgui.DrawList_AddLine(
    --         drawList,
    --         x, y,
    --         x + fadeVisualSize, y + fadeVisualSize,
    --         0xFFFFFFFF,
    --         1.5
    --     )
    --     imgui.Dummy(globals.ctx, fadeVisualSize, fadeVisualSize)
    --     imgui.EndGroup(globals.ctx)
    --     imgui.EndGroup(globals.ctx)
        
    --     -- VBox pour le texte à droite
    --     imgui.SameLine(globals.ctx, controlWidth + padding)
    --     imgui.Text(globals.ctx, "Fade out (sec)")
    -- end
end



-- Function to display trigger and randomization settings
function UI.displayTriggerSettings(obj, objId, width, isGroup)
    -- Infos sur l'héritage
    local titlePrefix = isGroup and "Default " or ""
    local inheritText = isGroup and "These settings will be inherited by containers unless overridden" or ""
    
    -- Section TRIGGER SETTINGS
    if inheritText ~= "" then
        imgui.TextColored(globals.ctx, 0xFFAA00FF, inheritText)
    end
    
    -- Initialisation des propriétés de fade
    obj.fadeIn = obj.fadeIn or 0.0
    obj.fadeOut = obj.fadeOut or 0.0
    
    -- Appel à la fonction commune
    UI.drawTriggerSettingsSection(
        obj,
        {
            setIntervalMode = function(v) obj.intervalMode = v end,
            setTriggerRate = function(v) obj.triggerRate = v end,
            setTriggerDrift = function(v) obj.triggerDrift = v end,
            setFadeIn = function(v) obj.fadeIn = math.max(0, v) end,
            setFadeOut = function(v) obj.fadeOut = math.max(0, v) end,
        },
        width,
        titlePrefix
    )
    
    -- Section RANDOMIZATION PARAMETERS
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, titlePrefix .. "Randomization parameters")
    
    -- Largeurs pour les contrôles
    local controlWidth = width * 0.55
    local padding = 5
    
    -- Pitch randomization - HBox
    do
        -- VBox pour le contrôle (checkbox)
        imgui.BeginGroup(globals.ctx)
        local rv, newRandomizePitch = imgui.Checkbox(globals.ctx, "##RandomizePitch", obj.randomizePitch)
        if rv then obj.randomizePitch = newRandomizePitch end
        imgui.SameLine(globals.ctx)
        imgui.Text(globals.ctx, "Randomize Pitch")
        imgui.EndGroup(globals.ctx)
    end
    
    -- Afficher la plage de pitch si la randomisation est activée
    if obj.randomizePitch then
        do
            -- VBox pour le contrôle (range slider)
            imgui.BeginGroup(globals.ctx)
            imgui.PushItemWidth(globals.ctx, controlWidth)
            local rv, newPitchMin, newPitchMax = imgui.DragFloatRange2(globals.ctx, "##PitchRange", 
                obj.pitchRange.min, obj.pitchRange.max, 0.1, -48, 48)
            if rv then
                obj.pitchRange.min = newPitchMin
                obj.pitchRange.max = newPitchMax
            end
            imgui.SameLine(globals.ctx)
            imgui.Text(globals.ctx, "Pitch Range (semitones)")
            imgui.EndGroup(globals.ctx)
        end
    end
    
    -- Volume randomization - HBox
    do
        -- VBox pour le contrôle (checkbox)
        imgui.BeginGroup(globals.ctx)
        local rv, newRandomizeVolume = imgui.Checkbox(globals.ctx, "##RandomizeVolume", obj.randomizeVolume)
        if rv then obj.randomizeVolume = newRandomizeVolume end
        imgui.SameLine(globals.ctx)
        imgui.Text(globals.ctx, "Randomize Volume")
        imgui.EndGroup(globals.ctx)
    end
    
    -- Afficher la plage de volume si la randomisation est activée
    if obj.randomizeVolume then
        do
            -- VBox pour le contrôle (range slider)
            imgui.BeginGroup(globals.ctx)
            imgui.PushItemWidth(globals.ctx, controlWidth)
            local rv, newVolumeMin, newVolumeMax = imgui.DragFloatRange2(globals.ctx, "##VolumeRange", 
                obj.volumeRange.min, obj.volumeRange.max, 0.1, -24, 24)
            if rv then
                obj.volumeRange.min = newVolumeMin
                obj.volumeRange.max = newVolumeMax
            end
            imgui.EndGroup(globals.ctx)
            
            -- VBox pour le texte
            imgui.SameLine(globals.ctx, controlWidth + padding)
            imgui.Text(globals.ctx, "Volume Range (dB)")
        end
    end
    
    -- Pan randomization - HBox
    do
        -- VBox pour le contrôle (checkbox)
        imgui.BeginGroup(globals.ctx)
        local rv, newRandomizePan = imgui.Checkbox(globals.ctx, "##RandomizePan", obj.randomizePan)
        if rv then obj.randomizePan = newRandomizePan end
        imgui.SameLine(globals.ctx)
        imgui.Text(globals.ctx, "Randomize Pan")
        imgui.EndGroup(globals.ctx)
    end
    
    -- Afficher la plage de pan si la randomisation est activée
    if obj.randomizePan then
        do
            -- VBox pour le contrôle (range slider)
            imgui.BeginGroup(globals.ctx)
            imgui.PushItemWidth(globals.ctx, controlWidth)
            local rv, newPanMin, newPanMax = imgui.DragFloatRange2(globals.ctx, "##PanRange", 
                obj.panRange.min, obj.panRange.max, 1, -100, 100)
            if rv then
                obj.panRange.min = newPanMin
                obj.panRange.max = newPanMax
            end
            imgui.EndGroup(globals.ctx)
            
            -- VBox pour le texte
            imgui.SameLine(globals.ctx, controlWidth + padding)
            imgui.Text(globals.ctx, "Pan Range (-100/+100)")
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
