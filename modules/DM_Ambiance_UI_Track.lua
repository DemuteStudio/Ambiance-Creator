--[[
Sound Randomizer for REAPER - UI Track Module
This module handles track settings UI display and editing
]]

local UI_Track = {}

local globals = {}

-- Initialize the module with global variables from the main script
function UI_Track.initModule(g)
    globals = g
end

-- Function to display track randomization settings in the right panel
function UI_Track.displayTrackSettings(trackIndex, width)
    local track = globals.tracks[trackIndex]
    local trackId = "track" .. trackIndex
    
    -- Panel title showing which track is being edited
    reaper.ImGui_Text(globals.ctx, "Track Settings: " .. track.name)
    reaper.ImGui_Separator(globals.ctx)
    
    -- Track name input field
    local trackName = track.name
    reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
    local rv, newTrackName = reaper.ImGui_InputText(globals.ctx, "Name##detail_" .. trackId, trackName)
    if rv then track.name = newTrackName end
    
    -- Track preset controls
    globals.UI_Tracks.drawTrackPresetControls(trackIndex)
    
    -- TRIGGER SETTINGS SECTION
    reaper.ImGui_Separator(globals.ctx)
    reaper.ImGui_Text(globals.ctx, "Default Trigger Settings")
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "These settings will be inherited by containers unless overridden")
    
    -- Repetition activation checkbox
    local useRepetition = track.useRepetition
    local rv, newUseRepetition = reaper.ImGui_Checkbox(globals.ctx, "Use trigger rate##" .. trackId, useRepetition)
    if rv then track.useRepetition = newUseRepetition end
    
    -- Only show trigger settings if repetition is enabled
    if track.useRepetition then
        -- Interval Mode dropdown - different modes for triggering sounds
        local intervalModes = "Absolute\0Relative\0Coverage\0\0"
        local intervalMode = track.intervalMode
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
        local rv, newIntervalMode = reaper.ImGui_Combo(globals.ctx, "Interval Mode##" .. trackId, intervalMode, intervalModes)
        if rv then track.intervalMode = newIntervalMode end
        
        -- Trigger rate label and slider range changes based on selected mode
        local triggerRateLabel = "Interval (sec)"
        local triggerRateMin = -10.0
        local triggerRateMax = 60.0
        
        if track.intervalMode == 1 then
            triggerRateLabel = "Interval (%)"
            triggerRateMin = 0.1
            triggerRateMax = 100.0
        elseif track.intervalMode == 2 then
            triggerRateLabel = "Coverage (%)"
            triggerRateMin = 0.1
            triggerRateMax = 100.0
        end
        
        -- Trigger rate slider
        local triggerRate = track.triggerRate
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
        local rv, newTriggerRate = reaper.ImGui_SliderDouble(globals.ctx, triggerRateLabel .. "##" .. trackId,
            triggerRate, triggerRateMin, triggerRateMax, "%.1f")
        if rv then track.triggerRate = newTriggerRate end
        
        -- Help text explaining the selected mode
        if track.intervalMode == 0 then
            if track.triggerRate < 0 then
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
            else
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
            end
        elseif track.intervalMode == 1 then
            reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
        else
            reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
        end
        
        -- Trigger drift slider (randomness in timing)
        local triggerDrift = track.triggerDrift
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
        local rv, newTriggerDrift = reaper.ImGui_SliderInt(globals.ctx, "Random variation (%)##" .. trackId, triggerDrift, 0, 100, "%d")
        if rv then track.triggerDrift = newTriggerDrift end
    end
    
    -- RANDOMIZATION PARAMETERS SECTION
    reaper.ImGui_Separator(globals.ctx)
    reaper.ImGui_Text(globals.ctx, "Default Randomization parameters")
    
    -- Pitch randomization checkbox
    local randomizePitch = track.randomizePitch
    local rv, newRandomizePitch = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pitch##" .. trackId, randomizePitch)
    if rv then track.randomizePitch = newRandomizePitch end
    
    -- Only show pitch range if pitch randomization is enabled
    if track.randomizePitch then
        local pitchMin = track.pitchRange.min
        local pitchMax = track.pitchRange.max
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPitchMin, newPitchMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pitch Range (semitones)##" .. trackId, pitchMin, pitchMax, 0.1, -48, 48)
        if rv then
            track.pitchRange.min = newPitchMin
            track.pitchRange.max = newPitchMax
        end
    end
    
    -- Volume randomization checkbox
    local randomizeVolume = track.randomizeVolume
    local rv, newRandomizeVolume = reaper.ImGui_Checkbox(globals.ctx, "Randomize Volume##" .. trackId, randomizeVolume)
    if rv then track.randomizeVolume = newRandomizeVolume end
    
    -- Only show volume range if volume randomization is enabled
    if track.randomizeVolume then
        local volumeMin = track.volumeRange.min
        local volumeMax = track.volumeRange.max
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
        local rv, newVolumeMin, newVolumeMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Volume Range (dB)##" .. trackId, volumeMin, volumeMax, 0.1, -24, 24)
        if rv then
            track.volumeRange.min = newVolumeMin
            track.volumeRange.max = newVolumeMax
        end
    end
    
    -- Pan randomization checkbox
    local randomizePan = track.randomizePan
    local rv, newRandomizePan = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pan##" .. trackId, randomizePan)
    if rv then track.randomizePan = newRandomizePan end
    
    -- Only show pan range if pan randomization is enabled
    if track.randomizePan then
        local panMin = track.panRange.min
        local panMax = track.panRange.max
        reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
        local rv, newPanMin, newPanMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pan Range (-100/+100)##" .. trackId, panMin, panMax, 1, -100, 100)
        if rv then
            track.panRange.min = newPanMin
            track.panRange.max = newPanMax
        end
    end
end

return UI_Track
