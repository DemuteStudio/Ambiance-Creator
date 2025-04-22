--[[
Sound Randomizer for REAPER - UI Container Module
This module handles container settings UI display and editing
]]
local UI_Container = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_Container.initModule(g)
    globals = g
end

-- Function to display container preset controls for a specific container
function UI_Container.drawContainerPresetControls(groupIndex, containerIndex)
    local groupId = "group" .. groupIndex
    local containerId = groupId .. "_container" .. containerIndex
    local presetKey = groupIndex .. "_" .. containerIndex
    
    -- Initialize selected preset index if needed
    if not globals.selectedContainerPresetIndex[presetKey] then
        globals.selectedContainerPresetIndex[presetKey] = -1
    end
    
    -- Get sanitized group name for folder structure (replacing non-alphanumeric chars with underscore)
    local groupName = globals.groups[groupIndex].name:gsub("[^%w]", "_")
    
    -- Get container presets for this group
    local containerPresetList = globals.Presets.listPresets("Containers")
    
    -- Prepare items for the preset dropdown
    local containerPresetItems = ""
    for _, name in ipairs(containerPresetList) do
        containerPresetItems = containerPresetItems .. name .. "\0"
    end
    containerPresetItems = containerPresetItems .. "\0"
    
    -- Preset dropdown control
    reaper.ImGui_PushItemWidth(globals.ctx, 200)
    local rv, newSelectedContainerIndex = reaper.ImGui_Combo(globals.ctx, "##ContainerPresetSelector" .. containerId,
        globals.selectedContainerPresetIndex[presetKey], containerPresetItems)
    if rv then
        globals.selectedContainerPresetIndex[presetKey] = newSelectedContainerIndex
    end
    
    -- Load preset button
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Load Container##" .. containerId) and
        globals.selectedContainerPresetIndex[presetKey] >= 0 and
        globals.selectedContainerPresetIndex[presetKey] < #containerPresetList then
        local presetName = containerPresetList[globals.selectedContainerPresetIndex[presetKey] + 1]
        globals.Presets.loadContainerPreset(presetName, groupIndex, containerIndex)
    end
    
    -- Save preset button
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Save Container##" .. containerId) then
        globals.newContainerPresetName = globals.groups[groupIndex].containers[containerIndex].name
        globals.currentSaveContainerGroup = groupIndex
        globals.currentSaveContainerIndex = containerIndex
        globals.Utils.safeOpenPopup("Save Container Preset##" .. containerId)
    end
    
    -- Container save dialog popup
    if reaper.ImGui_BeginPopupModal(globals.ctx, "Save Container Preset##" .. containerId, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(globals.ctx, "Container preset name:")
        local rv, value = reaper.ImGui_InputText(globals.ctx, "##ContainerPresetName" .. containerId, globals.newContainerPresetName)
        if rv then globals.newContainerPresetName = value end
        if reaper.ImGui_Button(globals.ctx, "Save", 120, 0) and globals.newContainerPresetName ~= "" then
            if globals.Presets.saveContainerPreset(globals.newContainerPresetName, globals.currentSaveContainerGroup, globals.currentSaveContainerIndex) then
                globals.Utils.safeClosePopup("Save Container Preset##" .. containerId)
            end
        end
        reaper.ImGui_SameLine(globals.ctx)
        if reaper.ImGui_Button(globals.ctx, "Cancel", 120, 0) then
            globals.Utils.safeClosePopup("Save Container Preset##" .. containerId)
        end
        reaper.ImGui_EndPopup(globals.ctx)
    end
end

-- Function to display container settings in the right panel
-- Function to display container settings in the right panel
function UI_Container.displayContainerSettings(groupIndex, containerIndex, width)
    local group = globals.groups[groupIndex]
    local container = group.containers[containerIndex]
    local groupId = "group" .. groupIndex
    local containerId = groupId .. "_container" .. containerIndex
    
    -- Panel title showing which container is being edited
    reaper.ImGui_Text(globals.ctx, "Container Settings: " .. container.name)
    reaper.ImGui_Separator(globals.ctx)
    
    -- Container name input field
    local containerName = container.name
    reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
    local rv, newContainerName = reaper.ImGui_InputText(globals.ctx, "Name##detail_" .. containerId, containerName)
    if rv then container.name = newContainerName end
    
    -- Override parent checkbox
    local overrideParent = container.overrideParent
    local rv, newOverrideParent = reaper.ImGui_Checkbox(globals.ctx, "Override Parent Settings##" .. containerId, overrideParent)
    reaper.ImGui_SameLine(globals.ctx)
    globals.Utils.HelpMarker("Enable 'Override Parent Settings' to customize parameters")
    if rv then container.overrideParent = newOverrideParent end
    
    -- Container preset controls
    UI_Container.drawContainerPresetControls(groupIndex, containerIndex)
    
    -- Button to import selected items from REAPER
    if reaper.ImGui_Button(globals.ctx, "Import Selected Items##" .. containerId) then
        local items = globals.Items.getSelectedItems()
        if #items > 0 then
            for _, item in ipairs(items) do
                table.insert(container.items, item)
            end
        else
            reaper.MB("No item selected!", "Error", 0)
        end
    end
    
    -- Display imported items in a collapsible header
    if #container.items > 0 then
        if reaper.ImGui_CollapsingHeader(globals.ctx, "Imported items (" .. #container.items .. ")##" .. containerId) then
            local itemToDelete = nil
            -- Loop through all items
            for l, item in ipairs(container.items) do
                reaper.ImGui_Text(globals.ctx, l .. ". " .. item.name)
                reaper.ImGui_SameLine(globals.ctx)
                if reaper.ImGui_Button(globals.ctx, "X##item" .. containerId .. "_" .. l) then
                    itemToDelete = l
                end
            end
            -- Delete the marked item if any
            if itemToDelete then
                table.remove(container.items, itemToDelete)
            end
        end
    end
    
    if container.overrideParent then
        -- Afficher le message qui explique que les paramètres propres sont utilisés
        reaper.ImGui_TextColored(globals.ctx, 0x00AA00FF, "Using container's own settings")
        
        -- TRIGGER SETTINGS SECTION
        reaper.ImGui_Separator(globals.ctx)
        reaper.ImGui_Text(globals.ctx, "Trigger Settings")
        
        -- Repetition activation checkbox
        local useRepetition = container.useRepetition
        local rv, newUseRepetition = reaper.ImGui_Checkbox(globals.ctx, "Use trigger rate##" .. containerId, useRepetition)
        if rv then container.useRepetition = newUseRepetition end
        
        -- Only show trigger settings if repetition is enabled
        if container.useRepetition then
            -- Interval Mode dropdown - different modes for triggering sounds
            local intervalModes = "Absolute\0Relative\0Coverage\0\0"
            local intervalMode = container.intervalMode
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            
            -- Help text explaining the selected mode
            if container.intervalMode == 0 then
                if container.triggerRate < 0 then
                    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
                else
                    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
                end
            elseif container.intervalMode == 1 then
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
            else
                reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
            end
            
            local rv, newIntervalMode = reaper.ImGui_Combo(globals.ctx, "Interval Mode##" .. containerId, intervalMode, intervalModes)
            if rv then container.intervalMode = newIntervalMode end
            
            -- Trigger rate label and slider range changes based on selected mode
            local triggerRateLabel = "Interval (sec)"
            local triggerRateMin = -10.0
            local triggerRateMax = 60.0
            
            if container.intervalMode == 1 then
                triggerRateLabel = "Interval (%)"
                triggerRateMin = 0.1
                triggerRateMax = 100.0
            elseif container.intervalMode == 2 then
                triggerRateLabel = "Coverage (%)"
                triggerRateMin = 0.1
                triggerRateMax = 100.0
            end
            
            -- Trigger rate slider
            local triggerRate = container.triggerRate
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newTriggerRate = reaper.ImGui_SliderDouble(globals.ctx, triggerRateLabel .. "##" .. containerId,
                triggerRate, triggerRateMin, triggerRateMax, "%.1f")
            if rv then container.triggerRate = newTriggerRate end
            
            
            -- Trigger drift slider (randomness in timing)
            local triggerDrift = container.triggerDrift
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
            local rv, newTriggerDrift = reaper.ImGui_SliderInt(globals.ctx, "Random variation (%)##" .. containerId, triggerDrift, 0, 100, "%d")
            if rv then container.triggerDrift = newTriggerDrift end
        end
        
        -- RANDOMIZATION PARAMETERS SECTION
        reaper.ImGui_Separator(globals.ctx)
        reaper.ImGui_Text(globals.ctx, "Randomization parameters")
        
        -- Pitch randomization checkbox
        local randomizePitch = container.randomizePitch
        local rv, newRandomizePitch = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pitch##" .. containerId, randomizePitch)
        if rv then container.randomizePitch = newRandomizePitch end
        
        -- Only show pitch range if pitch randomization is enabled
        if container.randomizePitch then
            local pitchMin = container.pitchRange.min
            local pitchMax = container.pitchRange.max
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newPitchMin, newPitchMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pitch Range (semitones)##" .. containerId, pitchMin, pitchMax, 0.1, -48, 48)
            if rv then
                container.pitchRange.min = newPitchMin
                container.pitchRange.max = newPitchMax
            end
        end
        
        -- Volume randomization checkbox
        local randomizeVolume = container.randomizeVolume
        local rv, newRandomizeVolume = reaper.ImGui_Checkbox(globals.ctx, "Randomize Volume##" .. containerId, randomizeVolume)
        if rv then container.randomizeVolume = newRandomizeVolume end
        
        -- Only show volume range if volume randomization is enabled
        if container.randomizeVolume then
            local volumeMin = container.volumeRange.min
            local volumeMax = container.volumeRange.max
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newVolumeMin, newVolumeMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Volume Range (dB)##" .. containerId, volumeMin, volumeMax, 0.1, -24, 24)
            if rv then
                container.volumeRange.min = newVolumeMin
                container.volumeRange.max = newVolumeMax
            end
        end
        
        -- Pan randomization checkbox
        local randomizePan = container.randomizePan
        local rv, newRandomizePan = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pan##" .. containerId, randomizePan)
        if rv then container.randomizePan = newRandomizePan end
        
        -- Only show pan range if pan randomization is enabled
        if container.randomizePan then
            local panMin = container.panRange.min
            local panMax = container.panRange.max
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.7)
            local rv, newPanMin, newPanMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pan Range (-100/+100)##" .. containerId, panMin, panMax, 1, -100, 100)
            if rv then
                container.panRange.min = newPanMin
                container.panRange.max = newPanMax
            end
        end
    else
        -- Si Override Parent n'est pas coché, afficher un message explicatif
        reaper.ImGui_TextColored(globals.ctx, 0x0088FFFF, "Inheriting settings from parent group")
        reaper.ImGui_TextColored(globals.ctx, 0xAAAAAAFF, "Enable 'Override Parent Settings' to customize parameters")
    end
end


return UI_Container
