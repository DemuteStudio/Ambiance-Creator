--[[
Sound Randomizer for REAPER - UI MultiSelection Module
This module handles the multi-selection and batch editing of containers
]]

local UI_MultiSelection = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_MultiSelection.initModule(g)
    globals = g
end

-- Helper function to display a "mixed values" indicator
local function showMixedValues()
    reaper.ImGui_SameLine(globals.ctx)
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "(Mixed values)")
end

-- Function to get all selected containers as a table of {groupIndex, containerIndex} pairs
function UI_MultiSelection.getSelectedContainersList()
    local containers = {}
    for key in pairs(globals.selectedContainers) do
        local t, c = key:match("(%d+)_(%d+)")
        table.insert(containers, {groupIndex = tonumber(t), containerIndex = tonumber(c)})
    end
    return containers
end

-- Function to draw the right panel for multi-selection edit mode
function UI_MultiSelection.drawMultiSelectionPanel(width)
    -- Count selected containers
    local selectedCount = 0
    for _ in pairs(globals.selectedContainers) do
        selectedCount = selectedCount + 1
    end
    
    -- Title with count
    reaper.ImGui_TextColored(globals.ctx, 0xFF4CAF50, "Editing " .. selectedCount .. " containers")
    
    if selectedCount == 0 then
        reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "No containers selected. Select containers to edit them.")
        return
    end
    
    -- Get list of all selected containers
    local containers = UI_MultiSelection.getSelectedContainersList()
    
    -- Button to regenerate all selected containers
    if reaper.ImGui_Button(globals.ctx, "Regenerate All Selected", width * 0.5, 30) then
        for _, c in ipairs(containers) do
            globals.Generation.generateSingleContainer(c.groupIndex, c.containerIndex)
        end
    end
    
    reaper.ImGui_Separator(globals.ctx)
    
    -- Collect info about selected containers for initial values
    local anyUseRepetition = false
    local allUseRepetition = true
    local anyRandomizePitch = false
    local allRandomizePitch = true
    local anyRandomizeVolume = false
    local allRandomizeVolume = true
    local anyRandomizePan = false
    local allRandomizePan = true
    
    -- Default values for common parameters
    local commonIntervalMode = nil
    local commonTriggerRate = nil
    local commonTriggerDrift = nil
    local commonPitchMin, commonPitchMax = nil, nil
    local commonVolumeMin, commonVolumeMax = nil, nil
    local commonPanMin, commonPanMax = nil, nil
    
    -- Check all containers to determine common settings
    for _, c in ipairs(containers) do
        local groupIndex = c.groupIndex
        local containerIndex = c.containerIndex
        local container = globals.groups[groupIndex].containers[containerIndex]
        
        -- Repetition settings
        if container.useRepetition then anyUseRepetition = true else allUseRepetition = false end
        
        -- Randomization settings
        if container.randomizePitch then anyRandomizePitch = true else allRandomizePitch = false end
        if container.randomizeVolume then anyRandomizeVolume = true else allRandomizeVolume = false end
        if container.randomizePan then anyRandomizePan = true else allRandomizePan = false end
        
        -- Calculate common values
        if commonIntervalMode == nil then
            commonIntervalMode = container.intervalMode
        elseif commonIntervalMode ~= container.intervalMode then
            commonIntervalMode = -1 -- Mixed values
        end
        
        if commonTriggerRate == nil then
            commonTriggerRate = container.triggerRate
        elseif math.abs(commonTriggerRate - container.triggerRate) > 0.001 then
            commonTriggerRate = -999 -- Mixed values
        end
        
        if commonTriggerDrift == nil then
            commonTriggerDrift = container.triggerDrift
        elseif commonTriggerDrift ~= container.triggerDrift then
            commonTriggerDrift = -1 -- Mixed values
        end
        
        -- Pitch range
        if commonPitchMin == nil then
            commonPitchMin = container.pitchRange.min
            commonPitchMax = container.pitchRange.max
        else
            if math.abs(commonPitchMin - container.pitchRange.min) > 0.001 then commonPitchMin = -999 end
            if math.abs(commonPitchMax - container.pitchRange.max) > 0.001 then commonPitchMax = -999 end
        end
        
        -- Volume range
        if commonVolumeMin == nil then
            commonVolumeMin = container.volumeRange.min
            commonVolumeMax = container.volumeRange.max
        else
            if math.abs(commonVolumeMin - container.volumeRange.min) > 0.001 then commonVolumeMin = -999 end
            if math.abs(commonVolumeMax - container.volumeRange.max) > 0.001 then commonVolumeMax = -999 end
        end
        
        -- Pan range
        if commonPanMin == nil then
            commonPanMin = container.panRange.min
            commonPanMax = container.panRange.max
        else
            if math.abs(commonPanMin - container.panRange.min) > 0.001 then commonPanMin = -999 end
            if math.abs(commonPanMax - container.panRange.max) > 0.001 then commonPanMax = -999 end
        end
    end
    
    -- TRIGGER SETTINGS SECTION
    reaper.ImGui_Text(globals.ctx, "Trigger Settings")
    
    -- Repetition activation checkbox (three-state checkbox for mixed values)
    local repetitionState = allUseRepetition and 1 or (anyUseRepetition and 2 or 0)
    local repetitionText = "Use trigger rate"
    
    if repetitionState == 2 then -- Mixed values
        repetitionText = repetitionText .. " (Mixed)"
    end
    
    -- Custom drawing of the three-state checkbox
    local useRep = false
    if repetitionState == 1 then
        useRep = true
    end
    
    local rv, newUseRep = reaper.ImGui_Checkbox(globals.ctx, repetitionText, useRep)
    if rv then
        -- Apply to all selected containers
        for _, c in ipairs(containers) do
            globals.groups[c.groupIndex].containers[c.containerIndex].useRepetition = newUseRep
        end
        
        -- Update state for UI refresh
        if newUseRep then
            anyUseRepetition = true
            allUseRepetition = true
        else
            anyUseRepetition = false
            allUseRepetition = false
        end
    end
    
    -- Only show trigger settings if any container uses repetition
    if anyUseRepetition then
        -- Interval Mode dropdown - different modes for triggering sounds
        local intervalModes = "Absolute\0Relative\0Coverage\0\0"
        local intervalMode = commonIntervalMode
        
        if intervalMode == -1 then
            -- Mixed values - use a placeholder
            reaper.ImGui_Text(globals.ctx, "Interval Mode:")
            reaper.ImGui_SameLine(globals.ctx)
            reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "(Mixed values)")
            
            -- Add a dropdown to set all values to the same value
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newIntervalMode = reaper.ImGui_Combo(globals.ctx, "Set all to##IntervalMode", 0, intervalModes)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].intervalMode = newIntervalMode
                end
                
                -- Update state for UI refresh
                commonIntervalMode = newIntervalMode
            end
        else
            -- All containers have the same value - normal edit
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newIntervalMode = reaper.ImGui_Combo(globals.ctx, "Interval Mode", intervalMode, intervalModes)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].intervalMode = newIntervalMode
                end
                
                -- Update state for UI refresh
                commonIntervalMode = newIntervalMode
            end
        end
        
        -- Trigger rate label and slider range changes based on selected mode
        local triggerRateLabel = "Interval (sec)"
        local triggerRateMin = -10.0
        local triggerRateMax = 60.0
        
        if commonIntervalMode == 1 then
            triggerRateLabel = "Interval (%)"
            triggerRateMin = 0.1
            triggerRateMax = 100.0
        elseif commonIntervalMode == 2 then
            triggerRateLabel = "Coverage (%)"
            triggerRateMin = 0.1
            triggerRateMax = 100.0
        end
        
        -- Trigger rate slider
        if commonTriggerRate == -999 then
            -- Mixed values - show a text indicator and editable field
            reaper.ImGui_Text(globals.ctx, triggerRateLabel .. ":")
            showMixedValues()
            
            -- Add a slider to set all values to the same value
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newTriggerRate = reaper.ImGui_SliderDouble(globals.ctx, "Set all to##TriggerRate",
                0, triggerRateMin, triggerRateMax, "%.1f")
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].triggerRate = newTriggerRate
                end
                
                -- Update state for UI refresh
                commonTriggerRate = newTriggerRate
            end
        else
            -- All containers have the same value - normal edit
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newTriggerRate = reaper.ImGui_SliderDouble(globals.ctx, triggerRateLabel,
                commonTriggerRate, triggerRateMin, triggerRateMax, "%.1f")
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].triggerRate = newTriggerRate
                end
                
                -- Update state for UI refresh
                commonTriggerRate = newTriggerRate
            end
        end
        
        -- Help text explaining the selected mode
        if commonIntervalMode == 0 then
            if commonTriggerRate < 0 then
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
            else
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
            end
        elseif commonIntervalMode == 1 then
            reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
        elseif commonIntervalMode == 2 then
            reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
        end
        
        -- Trigger drift slider (randomness in timing)
        if commonTriggerDrift == -1 then
            -- Mixed values - show a text indicator and editable field
            reaper.ImGui_Text(globals.ctx, "Random variation (%):")
            showMixedValues()
            
            -- Add a slider to set all values to the same value
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newTriggerDrift = reaper.ImGui_SliderInt(globals.ctx, "Set all to##TriggerDrift", 0, 0, 100, "%d")
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].triggerDrift = newTriggerDrift
                end
                
                -- Update state for UI refresh
                commonTriggerDrift = newTriggerDrift
            end
        else
            -- All containers have the same value - normal edit
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newTriggerDrift = reaper.ImGui_SliderInt(globals.ctx, "Random variation (%)",
                commonTriggerDrift, 0, 100, "%d")
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].triggerDrift = newTriggerDrift
                end
                
                -- Update state for UI refresh
                commonTriggerDrift = newTriggerDrift
            end
        end
    end
    
    -- RANDOMIZATION PARAMETERS SECTION
    reaper.ImGui_Separator(globals.ctx)
    reaper.ImGui_Text(globals.ctx, "Randomization parameters")
    
    -- Pitch randomization checkbox
    local pitchState = allRandomizePitch and 1 or (anyRandomizePitch and 2 or 0)
    local pitchText = "Randomize Pitch"
    
    if pitchState == 2 then -- Mixed values
        pitchText = pitchText .. " (Mixed)"
    end
    
    -- Custom drawing of the three-state checkbox
    local randomizePitch = false
    if pitchState == 1 then
        randomizePitch = true
    end
    
    local rv, newRandomizePitch = reaper.ImGui_Checkbox(globals.ctx, pitchText, randomizePitch)
    if rv then
        -- Apply to all selected containers
        for _, c in ipairs(containers) do
            globals.groups[c.groupIndex].containers[c.containerIndex].randomizePitch = newRandomizePitch
        end
        
        -- Update state for UI refresh
        if newRandomizePitch then
            anyRandomizePitch = true
            allRandomizePitch = true
        else
            anyRandomizePitch = false
            allRandomizePitch = false
        end
    end
    
    -- Only show pitch range if any container uses pitch randomization
    if anyRandomizePitch then
        if commonPitchMin == -999 or commonPitchMax == -999 then
            -- Mixed values - show a text indicator and editable field
            reaper.ImGui_Text(globals.ctx, "Pitch Range (semitones):")
            showMixedValues()
            
            -- Add a range slider to set all values to the same value
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newPitchMin, newPitchMax = reaper.ImGui_DragFloatRange2(globals.ctx,
                "Set all to##PitchRange",
                -12, 12, 0.1, -48, 48)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].pitchRange.min = newPitchMin
                    globals.groups[c.groupIndex].containers[c.containerIndex].pitchRange.max = newPitchMax
                end
                
                -- Update state for UI refresh
                commonPitchMin = newPitchMin
                commonPitchMax = newPitchMax
            end
        else
            -- All containers have the same value - normal edit
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newPitchMin, newPitchMax = reaper.ImGui_DragFloatRange2(globals.ctx,
                "Pitch Range (semitones)",
                commonPitchMin, commonPitchMax, 0.1, -48, 48)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].pitchRange.min = newPitchMin
                    globals.groups[c.groupIndex].containers[c.containerIndex].pitchRange.max = newPitchMax
                end
                
                -- Update state for UI refresh
                commonPitchMin = newPitchMin
                commonPitchMax = newPitchMax
            end
        end
    end
    
    -- Volume randomization checkbox
    local volumeState = allRandomizeVolume and 1 or (anyRandomizeVolume and 2 or 0)
    local volumeText = "Randomize Volume"
    
    if volumeState == 2 then -- Mixed values
        volumeText = volumeText .. " (Mixed)"
    end
    
    -- Custom drawing of the three-state checkbox
    local randomizeVolume = false
    if volumeState == 1 then
        randomizeVolume = true
    end
    
    local rv, newRandomizeVolume = reaper.ImGui_Checkbox(globals.ctx, volumeText, randomizeVolume)
    if rv then
        -- Apply to all selected containers
        for _, c in ipairs(containers) do
            globals.groups[c.groupIndex].containers[c.containerIndex].randomizeVolume = newRandomizeVolume
        end
        
        -- Update state for UI refresh
        if newRandomizeVolume then
            anyRandomizeVolume = true
            allRandomizeVolume = true
        else
            anyRandomizeVolume = false
            allRandomizeVolume = false
        end
    end
    
    -- Only show volume range if any container uses volume randomization
    if anyRandomizeVolume then
        if commonVolumeMin == -999 or commonVolumeMax == -999 then
            -- Mixed values - show a text indicator and editable field
            reaper.ImGui_Text(globals.ctx, "Volume Range (dB):")
            showMixedValues()
            
            -- Add a range slider to set all values to the same value
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newVolumeMin, newVolumeMax = reaper.ImGui_DragFloatRange2(globals.ctx,
                "Set all to##VolumeRange",
                -6, 6, 0.1, -24, 24)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].volumeRange.min = newVolumeMin
                    globals.groups[c.groupIndex].containers[c.containerIndex].volumeRange.max = newVolumeMax
                end
                
                -- Update state for UI refresh
                commonVolumeMin = newVolumeMin
                commonVolumeMax = newVolumeMax
            end
        else
            -- All containers have the same value - normal edit
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newVolumeMin, newVolumeMax = reaper.ImGui_DragFloatRange2(globals.ctx,
                "Volume Range (dB)",
                commonVolumeMin, commonVolumeMax, 0.1, -24, 24)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].volumeRange.min = newVolumeMin
                    globals.groups[c.groupIndex].containers[c.containerIndex].volumeRange.max = newVolumeMax
                end
                
                -- Update state for UI refresh
                commonVolumeMin = newVolumeMin
                commonVolumeMax = newVolumeMax
            end
        end
    end
    
    -- Pan randomization checkbox
    local panState = allRandomizePan and 1 or (anyRandomizePan and 2 or 0)
    local panText = "Randomize Pan"
    
    if panState == 2 then -- Mixed values
        panText = panText .. " (Mixed)"
    end
    
    -- Custom drawing of the three-state checkbox
    local randomizePan = false
    if panState == 1 then
        randomizePan = true
    end
    
    local rv, newRandomizePan = reaper.ImGui_Checkbox(globals.ctx, panText, randomizePan)
    if rv then
        -- Apply to all selected containers
        for _, c in ipairs(containers) do
            globals.groups[c.groupIndex].containers[c.containerIndex].randomizePan = newRandomizePan
        end
        
        -- Update state for UI refresh
        if newRandomizePan then
            anyRandomizePan = true
            allRandomizePan = true
        else
            anyRandomizePan = false
            allRandomizePan = false
        end
    end
    
    -- Only show pan range if any container uses pan randomization
    if anyRandomizePan then
        if commonPanMin == -999 or commonPanMax == -999 then
            -- Mixed values - show a text indicator and editable field
            reaper.ImGui_Text(globals.ctx, "Pan Range (-100/+100):")
            showMixedValues()
            
            -- Add a range slider to set all values to the same value
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newPanMin, newPanMax = reaper.ImGui_DragFloatRange2(globals.ctx,
                "Set all to##PanRange",
                -50, 50, 1, -100, 100)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].panRange.min = newPanMin
                    globals.groups[c.groupIndex].containers[c.containerIndex].panRange.max = newPanMax
                end
                
                -- Update state for UI refresh
                commonPanMin = newPanMin
                commonPanMax = newPanMax
            end
        else
            -- All containers have the same value - normal edit
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newPanMin, newPanMax = reaper.ImGui_DragFloatRange2(globals.ctx,
                "Pan Range (-100/+100)",
                commonPanMin, commonPanMax, 1, -100, 100)
            if rv then
                -- Apply to all selected containers
                for _, c in ipairs(containers) do
                    globals.groups[c.groupIndex].containers[c.containerIndex].panRange.min = newPanMin
                    globals.groups[c.groupIndex].containers[c.containerIndex].panRange.max = newPanMax
                end
                
                -- Update state for UI refresh
                commonPanMin = newPanMin
                commonPanMax = newPanMax
            end
        end
    end
end

return UI_MultiSelection
