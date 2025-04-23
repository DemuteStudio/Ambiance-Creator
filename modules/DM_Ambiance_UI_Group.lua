--[[
Sound Randomizer for REAPER - UI Group Module
This module handles group settings UI display and editing
]]

local UI_Group = {}

local globals = {}

-- Initialize the module with global variables from the main script
function UI_Group.initModule(g)
    globals = g
end

-- Function to display group randomization settings in the right panel
function UI_Group.displayGroupSettings(groupIndex, width)
    local group = globals.groups[groupIndex]
    local groupId = "group" .. groupIndex
    
    -- Panel title showing which group is being edited
    imgui.Text(globals.ctx, "Group Settings: " .. group.name)
    imgui.Separator(globals.ctx)
    
    -- Group name input field
    local groupName = group.name
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local rv, newGroupName = imgui.InputText(globals.ctx, "Name##detail_" .. groupId, groupName)
    if rv then group.name = newGroupName end
    
    -- Group preset controls
    globals.UI_Groups.drawGroupPresetControls(groupIndex)
    
    -- TRIGGER SETTINGS SECTION
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, "Default Trigger Settings")
    imgui.TextColored(globals.ctx, 0xFFAA00FF, "These settings will be inherited by containers unless overridden")
    
    -- Interval Mode dropdown - different modes for triggering sounds
    local intervalModes = "Absolute\0Relative\0Coverage\0\0"
    local intervalMode = group.intervalMode
    imgui.PushItemWidth(globals.ctx, width * 0.5)

    -- Help text explaining the selected mode
    if group.intervalMode == 0 then
        if group.triggerRate < 0 then
            imgui.TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
        else
            imgui.TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
        end
    elseif group.intervalMode == 1 then
        imgui.TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
    else
        imgui.TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
    end
    
    local rv, newIntervalMode = imgui.Combo(globals.ctx, "Interval Mode##" .. groupId, intervalMode, intervalModes)
    if rv then group.intervalMode = newIntervalMode end
    imgui.SameLine(globals.ctx)
    globals.Utils.HelpMarker("Absolute: Fixed interval in seconds\n" ..
    "Relative: Interval as percentage of time selection\n" ..
    "Coverage: Percentage of time selection to be filled")

    -- Trigger rate label and slider range changes based on selected mode
    local triggerRateLabel = "Interval (sec)"
    local triggerRateMin = -10.0
    local triggerRateMax = 60.0
    
    if group.intervalMode == 1 then
        triggerRateLabel = "Interval (%)"
        triggerRateMin = 0.1
        triggerRateMax = 100.0
    elseif group.intervalMode == 2 then
        triggerRateLabel = "Coverage (%)"
        triggerRateMin = 0.1
        triggerRateMax = 100.0
    end
    
    -- Trigger rate slider
    local triggerRate = group.triggerRate
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local rv, newTriggerRate = imgui.SliderDouble(globals.ctx, triggerRateLabel .. "##" .. groupId,
        triggerRate, triggerRateMin, triggerRateMax, "%.1f")
    if rv then group.triggerRate = newTriggerRate end
    
    
    -- Trigger drift slider (randomness in timing)
    local triggerDrift = group.triggerDrift
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local rv, newTriggerDrift = imgui.SliderInt(globals.ctx, "Random variation (%)##" .. groupId, triggerDrift, 0, 100, "%d")
    if rv then group.triggerDrift = newTriggerDrift end

    
    -- RANDOMIZATION PARAMETERS SECTION
    imgui.Separator(globals.ctx)
    imgui.Text(globals.ctx, "Default Randomization parameters")
    
    -- Pitch randomization checkbox
    local randomizePitch = group.randomizePitch
    local rv, newRandomizePitch = imgui.Checkbox(globals.ctx, "Randomize Pitch##" .. groupId, randomizePitch)
    if rv then group.randomizePitch = newRandomizePitch end
    
    -- Only show pitch range if pitch randomization is enabled
    if group.randomizePitch then
        local pitchMin = group.pitchRange.min
        local pitchMax = group.pitchRange.max
        imgui.PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPitchMin, newPitchMax = imgui.DragFloatRange2(globals.ctx, "Pitch Range (semitones)##" .. groupId, pitchMin, pitchMax, 0.1, -48, 48)
        if rv then
            group.pitchRange.min = newPitchMin
            group.pitchRange.max = newPitchMax
        end
    end
    
    -- Volume randomization checkbox
    local randomizeVolume = group.randomizeVolume
    local rv, newRandomizeVolume = imgui.Checkbox(globals.ctx, "Randomize Volume##" .. groupId, randomizeVolume)
    if rv then group.randomizeVolume = newRandomizeVolume end
    
    -- Only show volume range if volume randomization is enabled
    if group.randomizeVolume then
        local volumeMin = group.volumeRange.min
        local volumeMax = group.volumeRange.max
        imgui.PushItemWidth(globals.ctx, width * 0.7)
        local rv, newVolumeMin, newVolumeMax = imgui.DragFloatRange2(globals.ctx, "Volume Range (dB)##" .. groupId, volumeMin, volumeMax, 0.1, -24, 24)
        if rv then
            group.volumeRange.min = newVolumeMin
            group.volumeRange.max = newVolumeMax
        end
    end
    
    -- Pan randomization checkbox
    local randomizePan = group.randomizePan
    local rv, newRandomizePan = imgui.Checkbox(globals.ctx, "Randomize Pan##" .. groupId, randomizePan)
    if rv then group.randomizePan = newRandomizePan end
    
    -- Only show pan range if pan randomization is enabled
    if group.randomizePan then
        local panMin = group.panRange.min
        local panMax = group.panRange.max
        imgui.PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPanMin, newPanMax = imgui.DragFloatRange2(globals.ctx, "Pan Range (-100/+100)##" .. groupId, panMin, panMax, 1, -100, 100)
        if rv then
            group.panRange.min = newPanMin
            group.panRange.max = newPanMax
        end
    end
end

return UI_Group
