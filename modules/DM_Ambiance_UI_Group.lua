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
    reaper.ImGui_Text(globals.ctx, "Group Settings: " .. group.name)
    reaper.ImGui_Separator(globals.ctx)
    
    -- Group name input field
    local groupName = group.name
    reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
    local rv, newGroupName = reaper.ImGui_InputText(globals.ctx, "Name##detail_" .. groupId, groupName)
    if rv then group.name = newGroupName end
    
    -- Group preset controls
    globals.UI_Groups.drawGroupPresetControls(groupIndex)
    
    -- TRIGGER SETTINGS SECTION
    reaper.ImGui_Separator(globals.ctx)
    reaper.ImGui_Text(globals.ctx, "Default Trigger Settings")
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "These settings will be inherited by containers unless overridden")
    
    -- Repetition activation checkbox
    local useRepetition = group.useRepetition
    local rv, newUseRepetition = reaper.ImGui_Checkbox(globals.ctx, "Use trigger rate##" .. groupId, useRepetition)
    if rv then group.useRepetition = newUseRepetition end
    
    -- Only show trigger settings if repetition is enabled
    if group.useRepetition then
        -- Interval Mode dropdown - different modes for triggering sounds
        local intervalModes = "Absolute\0Relative\0Coverage\0\0"
        local intervalMode = group.intervalMode
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
        local rv, newIntervalMode = reaper.ImGui_Combo(globals.ctx, "Interval Mode##" .. groupId, intervalMode, intervalModes)
        if rv then group.intervalMode = newIntervalMode end
        
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
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
        local rv, newTriggerRate = reaper.ImGui_SliderDouble(globals.ctx, triggerRateLabel .. "##" .. groupId,
            triggerRate, triggerRateMin, triggerRateMax, "%.1f")
        if rv then group.triggerRate = newTriggerRate end
        
        -- Help text explaining the selected mode
        if group.intervalMode == 0 then
            if group.triggerRate < 0 then
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
            else
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
            end
        elseif group.intervalMode == 1 then
            reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
        else
            reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
        end
        
        -- Trigger drift slider (randomness in timing)
        local triggerDrift = group.triggerDrift
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
        local rv, newTriggerDrift = reaper.ImGui_SliderInt(globals.ctx, "Random variation (%)##" .. groupId, triggerDrift, 0, 100, "%d")
        if rv then group.triggerDrift = newTriggerDrift end
    end
    
    -- RANDOMIZATION PARAMETERS SECTION
    reaper.ImGui_Separator(globals.ctx)
    reaper.ImGui_Text(globals.ctx, "Default Randomization parameters")
    
    -- Pitch randomization checkbox
    local randomizePitch = group.randomizePitch
    local rv, newRandomizePitch = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pitch##" .. groupId, randomizePitch)
    if rv then group.randomizePitch = newRandomizePitch end
    
    -- Only show pitch range if pitch randomization is enabled
    if group.randomizePitch then
        local pitchMin = group.pitchRange.min
        local pitchMax = group.pitchRange.max
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPitchMin, newPitchMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pitch Range (semitones)##" .. groupId, pitchMin, pitchMax, 0.1, -48, 48)
        if rv then
            group.pitchRange.min = newPitchMin
            group.pitchRange.max = newPitchMax
        end
    end
    
    -- Volume randomization checkbox
    local randomizeVolume = group.randomizeVolume
    local rv, newRandomizeVolume = reaper.ImGui_Checkbox(globals.ctx, "Randomize Volume##" .. groupId, randomizeVolume)
    if rv then group.randomizeVolume = newRandomizeVolume end
    
    -- Only show volume range if volume randomization is enabled
    if group.randomizeVolume then
        local volumeMin = group.volumeRange.min
        local volumeMax = group.volumeRange.max
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
        local rv, newVolumeMin, newVolumeMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Volume Range (dB)##" .. groupId, volumeMin, volumeMax, 0.1, -24, 24)
        if rv then
            group.volumeRange.min = newVolumeMin
            group.volumeRange.max = newVolumeMax
        end
    end
    
    -- Pan randomization checkbox
    local randomizePan = group.randomizePan
    local rv, newRandomizePan = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pan##" .. groupId, randomizePan)
    if rv then group.randomizePan = newRandomizePan end
    
    -- Only show pan range if pan randomization is enabled
    if group.randomizePan then
        local panMin = group.panRange.min
        local panMax = group.panRange.max
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPanMin, newPanMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pan Range (-100/+100)##" .. groupId, panMin, panMax, 1, -100, 100)
        if rv then
            group.panRange.min = newPanMin
            group.panRange.max = newPanMax
        end
    end
end

return UI_Group
