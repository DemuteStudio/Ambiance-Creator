--[[
@version 1.3
@noindex
--]]

local UI = {}
local globals = {}
local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")

-- Import UI submodules
local UI_Preset = require("DM_Ambiance_UI_Preset")
local UI_Container = require("DM_Ambiance_UI_Container")
local UI_Groups = require("DM_Ambiance_UI_Groups")
local UI_MultiSelection = require("DM_Ambiance_UI_MultiSelection")
local UI_Generation = require("DM_Ambiance_UI_Generation")
local UI_Group = require("DM_Ambiance_UI_Group")

-- Initialize the module with global variables from the main script
function UI.initModule(g)
    globals = g

    -- Initialize selection variables for two-panel layout
    globals.selectedGroupIndex = nil
    globals.selectedContainerIndex = nil

    -- Initialize structure for multi-selection
    globals.selectedContainers = {} -- Format: {[groupIndex_containerIndex] = true}
    globals.inMultiSelectMode = false

    -- Initialize variables for Shift multi-selection
    globals.shiftAnchorGroupIndex = nil
    globals.shiftAnchorContainerIndex = nil

    -- Initialize UI submodules with globals
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

-- Push custom style variables for UI
function UI.PushStyle()
    local ctx = globals.ctx
    local imgui = globals.imgui
    local settings = globals.Settings
    local utils = globals.Utils
    
    -- Item Spacing
    local itemSpacing = settings.getSetting("itemSpacing")
    imgui.PushStyleVar(ctx, imgui.StyleVar_ItemSpacing, itemSpacing, itemSpacing)
    


    -- Round Style for buttons and frames
    local rounding = settings.getSetting("uiRounding")
    
    -- Apply the user-defined rounding value
    imgui.PushStyleVar(ctx, imgui.StyleVar_DisabledAlpha, 0.68)
    imgui.PushStyleVar(ctx, imgui.StyleVar_FrameRounding, rounding)
    imgui.PushStyleVar(ctx, imgui.StyleVar_GrabRounding, rounding)
    
    -- Colors
    local buttonColor = settings.getSetting("buttonColor")
    local backgroundColor = settings.getSetting("backgroundColor")
    local textColor = settings.getSetting("textColor")
    
    -- Apply button colors
    imgui.PushStyleColor(ctx, imgui.Col_Button, buttonColor)
    imgui.PushStyleColor(ctx, imgui.Col_ButtonHovered, utils.brightenColor(buttonColor, 0.1))
    imgui.PushStyleColor(ctx, imgui.Col_ButtonActive, utils.brightenColor(buttonColor, -0.1))
    -- Apply scroll bars
    imgui.PushStyleColor(ctx, imgui.Col_ScrollbarGrab, buttonColor)
    imgui.PushStyleColor(ctx, imgui.Col_ScrollbarGrabHovered, utils.brightenColor(buttonColor, 0.1))
    imgui.PushStyleColor(ctx, imgui.Col_ScrollbarGrabActive, utils.brightenColor(buttonColor, -0.1))
    -- Apply sliders
    imgui.PushStyleColor(ctx, imgui.Col_SliderGrab, buttonColor)
    imgui.PushStyleColor(ctx, imgui.Col_SliderGrabActive, buttonColor)
    -- Apply check marks
    imgui.PushStyleColor(ctx, imgui.Col_CheckMark, buttonColor)
    
    -- Apply background colors
    imgui.PushStyleColor(ctx, imgui.Col_Header, utils.brightenColor(backgroundColor, 0.1))
    imgui.PushStyleColor(ctx, imgui.Col_HeaderActive, utils.brightenColor(backgroundColor, 0.2))
    imgui.PushStyleColor(ctx, imgui.Col_HeaderHovered, utils.brightenColor(backgroundColor, 0.15))
    imgui.PushStyleColor(ctx, imgui.Col_TitleBgActive, utils.brightenColor(backgroundColor, -0.01))
    imgui.PushStyleColor(ctx, imgui.Col_WindowBg, backgroundColor)
    imgui.PushStyleColor(ctx, imgui.Col_PopupBg, utils.brightenColor(backgroundColor, 0.05))
    imgui.PushStyleColor(ctx, imgui.Col_FrameBg, utils.brightenColor(backgroundColor, 0.1))
    imgui.PushStyleColor(ctx, imgui.Col_FrameBgHovered, utils.brightenColor(backgroundColor, 0.15))
    imgui.PushStyleColor(ctx, imgui.Col_FrameBgActive, utils.brightenColor(backgroundColor, 0.2))
    
    -- Apply text colors
    imgui.PushStyleColor(ctx, imgui.Col_Text, textColor)
    imgui.PushStyleColor(ctx, imgui.Col_CheckMark, textColor)
end


-- Pop custom style variables
function UI.PopStyle()
    local ctx = globals.ctx
    
    -- Increase the number for PushStyleColor
    imgui.PopStyleColor(ctx, 20)
    
    -- Increase the number for PushStyleVar
    imgui.PopStyleVar(ctx, 4)
end


-- Clear all container selections and reset selection state
local function clearContainerSelections()
    globals.selectedContainers = {}
    globals.inMultiSelectMode = false
    -- Also clear the shift anchor when clearing selections
    globals.shiftAnchorGroupIndex = nil
    globals.shiftAnchorContainerIndex = nil
end

-- Draw the trigger settings section (shared by groups and containers)
-- dataObj must expose: intervalMode, triggerRate, triggerDrift, fadeIn, fadeOut
-- callbacks must provide setters for each parameter
function UI.drawTriggerSettingsSection(dataObj, callbacks, width, titlePrefix)
    -- Section separator and title
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, titlePrefix .. "Trigger Settings")

    -- Layout parameters
    local controlHeight = 20
    local controlWidth = width * 0.55
    local labelWidth = width * 0.35
    local padding = 5
    local fadeVisualSize = 15

    -- Info message for interval mode
    if dataObj.intervalMode == 0 then
        if dataObj.triggerRate < 0 then
            imgui.TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
        else
            imgui.TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
        end
    elseif dataObj.intervalMode == 1 then
        imgui.TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
    elseif dataObj.intervalMode == 2 then
        imgui.TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
    else
        imgui.TextColored(globals.ctx, 0xFFAA00FF, "Chunk: Structured sound/silence periods")
    end

    -- Interval mode selection (Combo box)
    do
        imgui.BeginGroup(globals.ctx)
        imgui.PushItemWidth(globals.ctx, controlWidth)
        local intervalModes = "Absolute\0Relative\0Coverage\0Chunk\0\0"
        local rv, newIntervalMode = imgui.Combo(globals.ctx, "##IntervalMode", dataObj.intervalMode, intervalModes)
        if rv then callbacks.setIntervalMode(newIntervalMode) end
        imgui.EndGroup(globals.ctx)

        imgui.SameLine(globals.ctx, controlWidth + padding)
        imgui.Text(globals.ctx, "Interval Mode")
        imgui.SameLine(globals.ctx)
        globals.Utils.HelpMarker(
            "Absolute: Fixed interval in seconds\n" ..
            "Relative: Interval as percentage of time selection\n" ..
            "Coverage: Percentage of time selection to be filled\n" ..
            "Chunk: Create structured sound/silence periods"
        )
    end

    -- Interval value (slider)
    do
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
        elseif dataObj.intervalMode == 3 then
            rateLabel = "Item Interval (sec)"
            rateMin = -10.0
            rateMax = 60.0
        end

        imgui.BeginGroup(globals.ctx)
        imgui.PushItemWidth(globals.ctx, controlWidth)
        local rv, newRate = imgui.SliderDouble(globals.ctx, "##TriggerRate", dataObj.triggerRate, rateMin, rateMax, "%.1f")
        if rv then callbacks.setTriggerRate(newRate) end
        imgui.EndGroup(globals.ctx)

        imgui.SameLine(globals.ctx, controlWidth + padding)
        imgui.Text(globals.ctx, rateLabel)
        
        -- Compact random variation control on same line
        imgui.SameLine(globals.ctx)
        imgui.PushItemWidth(globals.ctx, 60)
        local rvDrift, newDrift = imgui.DragInt(globals.ctx, "##TriggerDrift", dataObj.triggerDrift, 0.5, 0, 100, "%d%%")
        if rvDrift then callbacks.setTriggerDrift(newDrift) end
        imgui.PopItemWidth(globals.ctx)
        imgui.SameLine(globals.ctx)
        imgui.Text(globals.ctx, "Var")
    end

    -- Chunk mode specific controls
    if dataObj.intervalMode == 3 then
        -- Chunk Duration slider with variation knob
        do
            imgui.BeginGroup(globals.ctx)
            imgui.PushItemWidth(globals.ctx, controlWidth)
            local rv, newDuration = imgui.SliderDouble(globals.ctx, "##ChunkDuration", dataObj.chunkDuration, 0.5, 60.0, "%.1f sec")
            if rv then callbacks.setChunkDuration(newDuration) end
            imgui.EndGroup(globals.ctx)

            imgui.SameLine(globals.ctx, controlWidth + padding)
            imgui.Text(globals.ctx, "Chunk Duration")
            imgui.SameLine(globals.ctx)
            globals.Utils.HelpMarker("Duration of active sound periods in seconds")
            
            -- Compact variation control on same line
            imgui.SameLine(globals.ctx)
            imgui.PushItemWidth(globals.ctx, 60)
            local rv2, newDurationVar = imgui.DragInt(globals.ctx, "##ChunkDurationVar", dataObj.chunkDurationVariation, 0.5, 0, 100, "%d%%")
            if rv2 then callbacks.setChunkDurationVariation(newDurationVar) end
            imgui.PopItemWidth(globals.ctx)
            imgui.SameLine(globals.ctx)
            imgui.Text(globals.ctx, "Var")
        end

        -- Chunk Silence slider with variation knob
        do
            imgui.BeginGroup(globals.ctx)
            imgui.PushItemWidth(globals.ctx, controlWidth)
            local rv, newSilence = imgui.SliderDouble(globals.ctx, "##ChunkSilence", dataObj.chunkSilence, 0.0, 120.0, "%.1f sec")
            if rv then callbacks.setChunkSilence(newSilence) end
            imgui.EndGroup(globals.ctx)

            imgui.SameLine(globals.ctx, controlWidth + padding)
            imgui.Text(globals.ctx, "Silence Duration")
            imgui.SameLine(globals.ctx)
            globals.Utils.HelpMarker("Duration of silence periods between chunks in seconds")
            
            -- Compact variation control on same line
            imgui.SameLine(globals.ctx)
            imgui.PushItemWidth(globals.ctx, 60)
            local rv2, newSilenceVar = imgui.DragInt(globals.ctx, "##ChunkSilenceVar", dataObj.chunkSilenceVariation, 0.5, 0, 100, "%d%%")
            if rv2 then callbacks.setChunkSilenceVariation(newSilenceVar) end
            imgui.PopItemWidth(globals.ctx)
            imgui.SameLine(globals.ctx)
            imgui.Text(globals.ctx, "Var")
        end
    end

    -- Fade in/out controls are commented out but can be enabled if needed
end

-- Display trigger and randomization settings for a group or container
function UI.displayTriggerSettings(obj, objId, width, isGroup)
    local titlePrefix = isGroup and "Default " or ""
    local inheritText = isGroup and "These settings will be inherited by containers unless overridden" or ""

    -- Inheritance info
    if inheritText ~= "" then
        imgui.TextColored(globals.ctx, 0xFFAA00FF, inheritText)
    end

    -- Ensure fade properties are initialized
    obj.fadeIn = obj.fadeIn or 0.0
    obj.fadeOut = obj.fadeOut or 0.0
    
    -- Ensure chunk mode properties are initialized
    obj.chunkDuration = obj.chunkDuration or require("DM_Ambiance_Constants").DEFAULTS.CHUNK_DURATION
    obj.chunkSilence = obj.chunkSilence or require("DM_Ambiance_Constants").DEFAULTS.CHUNK_SILENCE
    obj.chunkDurationVariation = obj.chunkDurationVariation or require("DM_Ambiance_Constants").DEFAULTS.CHUNK_DURATION_VARIATION
    obj.chunkSilenceVariation = obj.chunkSilenceVariation or require("DM_Ambiance_Constants").DEFAULTS.CHUNK_SILENCE_VARIATION

    -- Draw trigger settings section
    UI.drawTriggerSettingsSection(
        obj,
        {
            setIntervalMode = function(v) obj.intervalMode = v end,
            setTriggerRate = function(v) obj.triggerRate = v end,
            setTriggerDrift = function(v) obj.triggerDrift = v end,
            setFadeIn = function(v) obj.fadeIn = math.max(0, v) end,
            setFadeOut = function(v) obj.fadeOut = math.max(0, v) end,
            -- Chunk mode callbacks
            setChunkDuration = function(v) obj.chunkDuration = v end,
            setChunkSilence = function(v) obj.chunkSilence = v end,
            setChunkDurationVariation = function(v) obj.chunkDurationVariation = v end,
            setChunkSilenceVariation = function(v) obj.chunkSilenceVariation = v end,
        },
        width,
        titlePrefix
    )

    -- Randomization parameters section
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, titlePrefix .. "Randomization parameters")

    local controlWidth = width * 0.55
    local padding = 5

    -- Pitch randomization
    do
        imgui.BeginGroup(globals.ctx)
        local rv, newRandomizePitch = imgui.Checkbox(globals.ctx, "##RandomizePitch", obj.randomizePitch)
        if rv then obj.randomizePitch = newRandomizePitch end
        imgui.SameLine(globals.ctx)
        imgui.Text(globals.ctx, "Randomize Pitch")
        imgui.EndGroup(globals.ctx)
    end

    -- Pitch range if randomization enabled
    if obj.randomizePitch then
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

    -- Volume randomization
    do
        imgui.BeginGroup(globals.ctx)
        local rv, newRandomizeVolume = imgui.Checkbox(globals.ctx, "##RandomizeVolume", obj.randomizeVolume)
        if rv then obj.randomizeVolume = newRandomizeVolume end
        imgui.SameLine(globals.ctx)
        imgui.Text(globals.ctx, "Randomize Volume")
        imgui.EndGroup(globals.ctx)
    end

    -- Volume range if randomization enabled
    if obj.randomizeVolume then
        imgui.BeginGroup(globals.ctx)
        imgui.PushItemWidth(globals.ctx, controlWidth)
        local rv, newVolumeMin, newVolumeMax = imgui.DragFloatRange2(globals.ctx, "##VolumeRange", 
            obj.volumeRange.min, obj.volumeRange.max, 0.1, -24, 24)
        if rv then
            obj.volumeRange.min = newVolumeMin
            obj.volumeRange.max = newVolumeMax
        end
        imgui.EndGroup(globals.ctx)
        imgui.SameLine(globals.ctx, controlWidth + padding)
        imgui.Text(globals.ctx, "Volume Range (dB)")
    end

    -- Pan randomization
    do
        imgui.BeginGroup(globals.ctx)
        local rv, newRandomizePan = imgui.Checkbox(globals.ctx, "##RandomizePan", obj.randomizePan)
        if rv then obj.randomizePan = newRandomizePan end
        imgui.SameLine(globals.ctx)
        imgui.Text(globals.ctx, "Randomize Pan")
        imgui.EndGroup(globals.ctx)
    end

    -- Pan range if randomization enabled
    if obj.randomizePan then
        imgui.BeginGroup(globals.ctx)
        imgui.PushItemWidth(globals.ctx, controlWidth)
        local rv, newPanMin, newPanMax = imgui.DragFloatRange2(globals.ctx, "##PanRange", 
            obj.panRange.min, obj.panRange.max, 1, -100, 100)
        if rv then
            obj.panRange.min = newPanMin
            obj.panRange.max = newPanMax
        end
        imgui.EndGroup(globals.ctx)
        imgui.SameLine(globals.ctx, controlWidth + padding)
        imgui.Text(globals.ctx, "Pan Range (-100/+100)")
    end
end

-- Check if a container is selected
local function isContainerSelected(groupIndex, containerIndex)
    return globals.selectedContainers[groupIndex .. "_" .. containerIndex] == true
end

-- Toggle the selection state of a container
local function toggleContainerSelection(groupIndex, containerIndex)
    local key = groupIndex .. "_" .. containerIndex
    local isShiftPressed = (globals.imgui.GetKeyMods(globals.ctx) & globals.imgui.Mod_Shift ~= 0)

    -- If Shift is pressed and an anchor exists, select a range
    if isShiftPressed and globals.shiftAnchorGroupIndex and globals.shiftAnchorContainerIndex then
        selectContainerRange(globals.shiftAnchorGroupIndex, globals.shiftAnchorContainerIndex, groupIndex, containerIndex)
    else
        -- Without Shift, clear previous selections unless Ctrl is pressed
        if not (globals.imgui.GetKeyMods(globals.ctx) & globals.imgui.Mod_Ctrl ~= 0) then
            clearContainerSelections()
        end

        -- Toggle the current container selection
        if globals.selectedContainers[key] then
            globals.selectedContainers[key] = nil
        else
            globals.selectedContainers[key] = true
        end

        -- Update anchor for future Shift selections
        globals.shiftAnchorGroupIndex = groupIndex
        globals.shiftAnchorContainerIndex = containerIndex
    end

    -- Update main selection and multi-select mode
    globals.selectedGroupIndex = groupIndex
    globals.selectedContainerIndex = containerIndex
    globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
end

-- Select a range of containers between two points (supports cross-group selection)
local function selectContainerRange(startGroupIndex, startContainerIndex, endGroupIndex, endContainerIndex)
    -- Clear selection if not in multi-select mode
    if not (globals.imgui.GetKeyMods(globals.ctx) & globals.imgui.Mod_Ctrl ~= 0) then
        clearContainerSelections()
    end

    -- Range selection within the same group
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

    -- Range selection across groups
    local startGroup = math.min(startGroupIndex, endGroupIndex)
    local endGroup = math.max(startGroupIndex, endGroupIndex)
    local firstContainerIdx, lastContainerIdx
    if startGroupIndex < endGroupIndex then
        firstContainerIdx, lastContainerIdx = startContainerIndex, endContainerIndex
    else
        firstContainerIdx, lastContainerIdx = endContainerIndex, startContainerIndex
    end

    for t = startGroup, endGroup do
        if globals.groups[t] then
            if t == startGroup then
                for c = firstContainerIdx, #globals.groups[t].containers do
                    globals.selectedContainers[t .. "_" .. c] = true
                end
            elseif t == endGroup then
                for c = 1, lastContainerIdx do
                    globals.selectedContainers[t .. "_" .. c] = true
                end
            else
                for c = 1, #globals.groups[t].containers do
                    globals.selectedContainers[t .. "_" .. c] = true
                end
            end
        end
    end

    globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
end

-- Draw the left panel with the list of groups and containers
local function drawLeftPanel(width)
    local availHeight = globals.imgui.GetWindowHeight(globals.ctx)
    if availHeight < 100 then -- Minimum height check
        globals.imgui.TextColored(globals.ctx, 0xFF0000FF, "Window too small")
        return
    end
    UI_Groups.drawGroupsPanel(width, isContainerSelected, toggleContainerSelection, clearContainerSelections, selectContainerRange)
end

-- Draw the right panel with details for the selected container or group
local function drawRightPanel(width)
    if globals.selectedContainers == {} then
        return
    end
        
    if globals.inMultiSelectMode then
        UI_MultiSelection.drawMultiSelectionPanel(width)
        return
    end

    if globals.selectedGroupIndex and globals.selectedContainerIndex then
        UI_Container.displayContainerSettings(globals.selectedGroupIndex, globals.selectedContainerIndex, width)
    elseif globals.selectedGroupIndex then
        UI_Group.displayGroupSettings(globals.selectedGroupIndex, width)
    else
        globals.imgui.TextColored(globals.ctx, 0xFFAA00FF, "Select a group or container to view and edit its settings.")
    end
end

-- Handle popups and force close if a popup is stuck for too long
local function handlePopups()
    for name, popup in pairs(globals.activePopups or {}) do
        if popup.active and reaper.time_precise() - popup.timeOpened > 5 then
            globals.imgui.CloseCurrentPopup(globals.ctx)
            globals.activePopups[name] = nil
        end
    end
end

local function detectAndFixImGuiImbalance()
    -- Get ImGui context state (if accessible)
    -- This is a safety net to prevent crashes
    local success = pcall(function()
        -- Try to detect if we're in an inconsistent state
        -- by checking if any operation causes an error
        local testVar = globals.imgui.GetWindowWidth(globals.ctx)
    end)
    
    if not success then
        -- If there's an issue, reset some flags that might help
        globals.showMediaDirWarning = false
        globals.activePopups = {}
        
        -- Force close any open popups
        pcall(function()
            globals.imgui.CloseCurrentPopup(globals.ctx)
        end)
    end
end

-- Main window rendering function
function UI.ShowMainWindow(open)
    local windowFlags = imgui.WindowFlags_None
    local visible, open = globals.imgui.Begin(globals.ctx, 'Ambiance Creator', open, windowFlags)

    -- CRITICAL: Only call End() if Begin() returned true (visible)
    if visible then
        -- Top section: preset controls and generation button
        UI_Preset.drawPresetControls()
        globals.imgui.SameLine(globals.ctx)
        if globals.imgui.Button(globals.ctx, "Settings") then
            globals.showSettingsWindow = true
        end
        
        if globals.Utils.checkTimeSelection() then
            UI_Generation.drawMainGenerationButton()
            globals.imgui.SameLine(globals.ctx)
            UI_Generation.drawKeepExistingTracksButton()  -- Changed from drawOverrideExistingTracksButton
        else
            UI_Generation.drawTimeSelectionInfo()
        end

        globals.imgui.Separator(globals.ctx)

        -- Two-panel layout dimensions
        local windowWidth = globals.imgui.GetWindowWidth(globals.ctx)
        local leftPanelWidth = windowWidth * 0.35
        local rightPanelWidth = windowWidth * 0.63

        -- Left panel: groups and containers
        -- For BeginChild/EndChild: ALWAYS call EndChild regardless of return value
        globals.imgui.BeginChild(globals.ctx, "LeftPanel", leftPanelWidth, 0)
        drawLeftPanel(leftPanelWidth)
        globals.imgui.EndChild(globals.ctx)

        -- Right panel: container or group details
        globals.imgui.SameLine(globals.ctx)
        -- For BeginChild/EndChild: ALWAYS call EndChild regardless of return value
        globals.imgui.BeginChild(globals.ctx, "RightPanel", rightPanelWidth, 0)
        drawRightPanel(rightPanelWidth)
        globals.imgui.EndChild(globals.ctx)

        -- CRITICAL: Only call End() if Begin() returned true
        globals.imgui.End(globals.ctx)
    end

    -- Handle settings window with the same pattern
    if globals.showSettingsWindow then
        globals.showSettingsWindow = globals.Settings.showSettingsWindow(true)
    end

    -- Show the media directory warning popup if needed
    if globals.showMediaDirWarning then
        Utils.showDirectoryWarningPopup()
    end

    -- Handle other popups
    handlePopups()
    
    return open
end



return UI
