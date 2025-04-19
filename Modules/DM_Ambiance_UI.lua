local UI = {}
local globals = {}
local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")

function UI.initModule(g)
  globals = g
end

-- Display preset controls
local function drawPresetControls()
  -- Section title
  reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Global Presets")
  
  -- Refresh button
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Refresh") then
    Presets.listPresets("Global", nil, true)
  end
  
  -- Dropdown list of presets
  reaper.ImGui_SameLine(globals.ctx)
  
  -- Get the preset list
  local presetList = Presets.listPresets("Global")
  
  -- Prepare items for the Combo
  local presetItems = ""
  for _, name in ipairs(presetList) do
    presetItems = presetItems .. name .. "\0"
  end
  presetItems = presetItems .. "\0"
  
  -- Display the dropdown list
  reaper.ImGui_PushItemWidth(globals.ctx, 300)
  local rv, newSelectedIndex = reaper.ImGui_Combo(globals.ctx, "##PresetSelector", globals.selectedPresetIndex, presetItems)
  
  if rv then
    globals.selectedPresetIndex = newSelectedIndex
    globals.currentPresetName = presetList[globals.selectedPresetIndex + 1] or ""
  end
  
  -- Action buttons
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Load") and globals.currentPresetName ~= "" then
    Presets.loadPreset(globals.currentPresetName)
  end
  
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Save") then
    Utils.safeOpenPopup("Save Preset")
    globals.newPresetName = globals.currentPresetName
  end
  
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Delete") and globals.currentPresetName ~= "" then
    Utils.safeOpenPopup("Confirm deletion")
  end
  
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Open Preset Directory") then
    Utils.openPresetsFolder("Global")
  end
  
  -- Save popup
  if reaper.ImGui_BeginPopupModal(globals.ctx, "Save Preset", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(globals.ctx, "Preset name:")
    local rv, value = reaper.ImGui_InputText(globals.ctx, "##PresetName", globals.newPresetName)
    if rv then globals.newPresetName = value end
    
    if reaper.ImGui_Button(globals.ctx, "Save", 120, 0) and globals.newPresetName ~= "" then
      if Presets.savePreset(globals.newPresetName) then
        globals.currentPresetName = globals.newPresetName
        for i, name in ipairs(presetList) do
          if name == globals.currentPresetName then
            globals.selectedPresetIndex = i - 1
            break
          end
        end
        Utils.safeClosePopup("Save Preset")
      end
    end
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Cancel", 120, 0) then
      Utils.safeClosePopup("Save Preset")
    end
    
    reaper.ImGui_EndPopup(globals.ctx)
  end
  
  -- Deletion confirmation popup
  if reaper.ImGui_BeginPopupModal(globals.ctx, "Confirm deletion", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(globals.ctx, "Are you sure you want to delete the preset \"" .. globals.currentPresetName .. "\"?")
    reaper.ImGui_Separator(globals.ctx)
    
    if reaper.ImGui_Button(globals.ctx, "Yes", 120, 0) then
      Presets.deletePreset(globals.currentPresetName, "Global")
      Utils.safeClosePopup("Confirm deletion")
    end
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "No", 120, 0) then
      Utils.safeClosePopup("Confirm deletion")
    end
    
    reaper.ImGui_EndPopup(globals.ctx)
  end
  
  reaper.ImGui_Separator(globals.ctx)
end

-- Track preset controls
local function drawTrackPresetControls(trackIndex)
  local trackId = "track" .. trackIndex
  
  -- Initialize selected index if needed
  if not globals.selectedTrackPresetIndex[trackIndex] then
    globals.selectedTrackPresetIndex[trackIndex] = -1
  end
  
  -- Get track presets
  local trackPresetList = Presets.listPresets("Tracks")
  
  -- Prepare items for the Combo
  local trackPresetItems = ""
  for _, name in ipairs(trackPresetList) do
    trackPresetItems = trackPresetItems .. name .. "\0"
  end
  trackPresetItems = trackPresetItems .. "\0"
  
  -- Preset controls
  reaper.ImGui_PushItemWidth(globals.ctx, 200)
  local rv, newSelectedTrackIndex = reaper.ImGui_Combo(globals.ctx, "##TrackPresetSelector" .. trackId, 
                                                      globals.selectedTrackPresetIndex[trackIndex], trackPresetItems)
  
  if rv then
    globals.selectedTrackPresetIndex[trackIndex] = newSelectedTrackIndex
  end
  
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Load Track##" .. trackId) and 
     globals.selectedTrackPresetIndex[trackIndex] >= 0 and 
     globals.selectedTrackPresetIndex[trackIndex] < #trackPresetList then
    local presetName = trackPresetList[globals.selectedTrackPresetIndex[trackIndex] + 1]
    Presets.loadTrackPreset(presetName, trackIndex)
  end
  
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Save Track##" .. trackId) then
    globals.newTrackPresetName = globals.tracks[trackIndex].name
    globals.currentSaveTrackIndex = trackIndex
    Utils.safeOpenPopup("Save Track Preset##" .. trackId)
  end
  
  -- Track save dialog popup
  if reaper.ImGui_BeginPopupModal(globals.ctx, "Save Track Preset##" .. trackId, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(globals.ctx, "Track preset name:")
    local rv, value = reaper.ImGui_InputText(globals.ctx, "##TrackPresetName" .. trackId, globals.newTrackPresetName)
    if rv then globals.newTrackPresetName = value end
    
    if reaper.ImGui_Button(globals.ctx, "Save", 120, 0) and globals.newTrackPresetName ~= "" then
      if Presets.saveTrackPreset(globals.newTrackPresetName, globals.currentSaveTrackIndex) then
        Utils.safeClosePopup("Save Track Preset##" .. trackId)
      end
    end
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Cancel", 120, 0) then
      Utils.safeClosePopup("Save Track Preset##" .. trackId)
    end
    
    reaper.ImGui_EndPopup(globals.ctx)
  end
end

-- Container preset controls
local function drawContainerPresetControls(trackIndex, containerIndex)
  local trackId = "track" .. trackIndex
  local containerId = trackId .. "_container" .. containerIndex
  local presetKey = trackIndex .. "_" .. containerIndex
  
  -- Initialize selected index if needed
  if not globals.selectedContainerPresetIndex[presetKey] then
    globals.selectedContainerPresetIndex[presetKey] = -1
  end
  
  -- Get sanitized track name for folder structure
  local trackName = globals.tracks[trackIndex].name:gsub("[^%w]", "_")
  
  -- Get container presets
  local containerPresetList = Presets.listPresets("Containers", trackName)
  
  -- Prepare items for the Combo
  local containerPresetItems = ""
  for _, name in ipairs(containerPresetList) do
    containerPresetItems = containerPresetItems .. name .. "\0"
  end
  containerPresetItems = containerPresetItems .. "\0"
  
  -- Preset controls
  reaper.ImGui_PushItemWidth(globals.ctx, 200)
  local rv, newSelectedContainerIndex = reaper.ImGui_Combo(globals.ctx, "##ContainerPresetSelector" .. containerId,
                                                          globals.selectedContainerPresetIndex[presetKey], containerPresetItems)
  
  if rv then
    globals.selectedContainerPresetIndex[presetKey] = newSelectedContainerIndex
  end
  
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Load Container##" .. containerId) and 
     globals.selectedContainerPresetIndex[presetKey] >= 0 and 
     globals.selectedContainerPresetIndex[presetKey] < #containerPresetList then
    local presetName = containerPresetList[globals.selectedContainerPresetIndex[presetKey] + 1]
    Presets.loadContainerPreset(presetName, trackIndex, containerIndex)
  end
  
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Save Container##" .. containerId) then
    globals.newContainerPresetName = globals.tracks[trackIndex].containers[containerIndex].name
    globals.currentSaveContainerTrack = trackIndex
    globals.currentSaveContainerIndex = containerIndex
    Utils.safeOpenPopup("Save Container Preset##" .. containerId)
  end
  
  -- Container save dialog popup
  if reaper.ImGui_BeginPopupModal(globals.ctx, "Save Container Preset##" .. containerId, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(globals.ctx, "Container preset name:")
    local rv, value = reaper.ImGui_InputText(globals.ctx, "##ContainerPresetName" .. containerId, globals.newContainerPresetName)
    if rv then globals.newContainerPresetName = value end
    
    if reaper.ImGui_Button(globals.ctx, "Save", 120, 0) and globals.newContainerPresetName ~= "" then
      if Presets.saveContainerPreset(globals.newContainerPresetName, globals.currentSaveContainerTrack, globals.currentSaveContainerIndex) then
        Utils.safeClosePopup("Save Container Preset##" .. containerId)
      end
    end
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Cancel", 120, 0) then
      Utils.safeClosePopup("Save Container Preset##" .. containerId)
    end
    
    reaper.ImGui_EndPopup(globals.ctx)
  end
end

-- Main interface
function UI.mainLoop()
  local visible, open = reaper.ImGui_Begin(globals.ctx, 'Sound Randomizer', true)
  
  if visible then
    -- Presets section
    drawPresetControls()
    
    -- Time selection check
    if Utils.checkTimeSelection() then
      reaper.ImGui_Text(globals.ctx, "Time Selection: " .. Utils.formatTime(globals.startTime) .. " - " .. Utils.formatTime(globals.endTime) .. " | Length: " .. Utils.formatTime(globals.endTime - globals.startTime))
    else
      reaper.ImGui_TextColored(globals.ctx, 0xFF0000FF, "No time selection! Please create one.")
    end
    
    reaper.ImGui_Separator(globals.ctx)
    
    -- Button to add a track
    if reaper.ImGui_Button(globals.ctx, "Add Track") then
      table.insert(globals.tracks, Structures.createTrack())
    end
    
    reaper.ImGui_Separator(globals.ctx)
    
    -- Display tracks
    local trackToDelete = nil
    
    for i, track in ipairs(globals.tracks) do
      local trackId = "track" .. i
      local trackFlags = track.expanded and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
      
      local trackOpen = reaper.ImGui_TreeNodeEx(globals.ctx, trackId, track.name, trackFlags)
      
      reaper.ImGui_SameLine(globals.ctx)
      if reaper.ImGui_Button(globals.ctx, "Delete##" .. trackId) then
        trackToDelete = i
      end
      
      -- Add regenerate button for the track
      reaper.ImGui_SameLine(globals.ctx)
      if reaper.ImGui_Button(globals.ctx, "Regenerate##" .. trackId) then
        Generation.generateSingleTrack(i)
      end
      
      if trackOpen then
        -- Track name
        local trackName = track.name
        reaper.ImGui_PushItemWidth(globals.ctx, 200)
        local rv, newTrackName = reaper.ImGui_InputText(globals.ctx, "Name##" .. trackId, trackName)
        if rv then track.name = newTrackName end
        
        -- Track preset controls
        drawTrackPresetControls(i)
        
        -- Button to add a container
        if reaper.ImGui_Button(globals.ctx, "Add Container##" .. trackId) then
          table.insert(track.containers, Structures.createContainer())
        end
        
        -- Display containers
        local containerToDelete = nil
        
        for j, container in ipairs(track.containers) do
          local containerId = trackId .. "_container" .. j
          local containerFlags = container.expanded and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
          
          reaper.ImGui_Indent(globals.ctx, 20)
          local containerOpen = reaper.ImGui_TreeNodeEx(globals.ctx, containerId, container.name, containerFlags)
          
          reaper.ImGui_SameLine(globals.ctx)
          if reaper.ImGui_Button(globals.ctx, "Delete##" .. containerId) then
            containerToDelete = j
          end
          
          -- Add regenerate button for the container
          reaper.ImGui_SameLine(globals.ctx)
          if reaper.ImGui_Button(globals.ctx, "Regenerate##" .. containerId) then
            Generation.generateSingleContainer(i, j)
          end
          
          if containerOpen then
            -- Container name
            local containerName = container.name
            reaper.ImGui_PushItemWidth(globals.ctx, 200)
            local rv, newContainerName = reaper.ImGui_InputText(globals.ctx, "Name##" .. containerId, containerName)
            if rv then container.name = newContainerName end
            
            -- Container preset controls
            drawContainerPresetControls(i, j)
            
            -- Button to import selected items
            if reaper.ImGui_Button(globals.ctx, "Import Selected Items##" .. containerId) then
              local items = Items.getSelectedItems()
              if #items > 0 then
                for _, item in ipairs(items) do
                  table.insert(container.items, item)
                end
              else
                reaper.MB("No item selected!", "Error", 0)
              end
            end
            
            -- Display imported items
            if #container.items > 0 then
              if reaper.ImGui_CollapsingHeader(globals.ctx, "Imported items (" .. #container.items .. ")##" .. containerId) then
                local itemToDelete = nil
                
                for l, item in ipairs(container.items) do
                  reaper.ImGui_Text(globals.ctx, l .. ". " .. item.name)
                  reaper.ImGui_SameLine(globals.ctx)
                  if reaper.ImGui_Button(globals.ctx, "X##item" .. containerId .. "_" .. l) then
                    itemToDelete = l
                  end
                end
                
                if itemToDelete then
                  table.remove(container.items, itemToDelete)
                end
              end
            end
            
            reaper.ImGui_Separator(globals.ctx)
            reaper.ImGui_Text(globals.ctx, "Trigger Settings")
            
            -- Repetition activation option
            local useRepetition = container.useRepetition
            local rv, newUseRepetition = reaper.ImGui_Checkbox(globals.ctx, "Use trigger rate##" .. containerId, useRepetition)
            if rv then container.useRepetition = newUseRepetition end
            
            if container.useRepetition then
              -- Interval Mode dropdown
              local intervalModes = "Absolute\0Relative\0Coverage\0\0"
              local intervalMode = container.intervalMode
              reaper.ImGui_PushItemWidth(globals.ctx, 200)
              local rv, newIntervalMode = reaper.ImGui_Combo(globals.ctx, "Interval Mode##" .. containerId, intervalMode, intervalModes)
              if rv then container.intervalMode = newIntervalMode end
              
              -- Trigger rate label and range changes based on mode
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
              
              -- Trigger rate control
              local triggerRate = container.triggerRate
              reaper.ImGui_PushItemWidth(globals.ctx, 200)
              local rv, newTriggerRate = reaper.ImGui_SliderDouble(globals.ctx, triggerRateLabel .. "##" .. containerId, 
                                                           triggerRate, triggerRateMin, triggerRateMax, "%.1f")
              if rv then container.triggerRate = newTriggerRate end
              
              -- Help text based on the selected mode
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
              
              -- Drift control
              local triggerDrift = container.triggerDrift
              reaper.ImGui_PushItemWidth(globals.ctx, 200)
              local rv, newTriggerDrift = reaper.ImGui_SliderInt(globals.ctx, "Random variation (%)##" .. containerId, triggerDrift, 0, 100, "%d")
              if rv then container.triggerDrift = newTriggerDrift end
            end
            
            -- RANDOMIZATION PARAMETERS
            reaper.ImGui_Separator(globals.ctx)
            reaper.ImGui_Text(globals.ctx, "Randomization parameters")
            
            -- Pitch
            local randomizePitch = container.randomizePitch
            local rv, newRandomizePitch = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pitch##" .. containerId, randomizePitch)
            if rv then container.randomizePitch = newRandomizePitch end
            
            if container.randomizePitch then
              local pitchMin = container.pitchRange.min
              local pitchMax = container.pitchRange.max
              
              reaper.ImGui_PushItemWidth(globals.ctx, 300)
              local rv, newPitchMin, newPitchMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pitch Range (semitones)##" .. containerId, pitchMin, pitchMax, 0.1, -48, 48)
              if rv then 
                container.pitchRange.min = newPitchMin
                container.pitchRange.max = newPitchMax
              end
            end
            
            -- Volume
            local randomizeVolume = container.randomizeVolume
            local rv, newRandomizeVolume = reaper.ImGui_Checkbox(globals.ctx, "Randomize Volume##" .. containerId, randomizeVolume)
            if rv then container.randomizeVolume = newRandomizeVolume end
            
            if container.randomizeVolume then
              local volumeMin = container.volumeRange.min
              local volumeMax = container.volumeRange.max
              
              reaper.ImGui_PushItemWidth(globals.ctx, 300)
              local rv, newVolumeMin, newVolumeMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Volume Range (dB)##" .. containerId, volumeMin, volumeMax, 0.1, -24, 24)
              if rv then 
                container.volumeRange.min = newVolumeMin
                container.volumeRange.max = newVolumeMax
              end
            end
            
            -- Pan
            local randomizePan = container.randomizePan
            local rv, newRandomizePan = reaper.ImGui_Checkbox(globals.ctx, "Randomize Pan##" .. containerId, randomizePan)
            if rv then container.randomizePan = newRandomizePan end
            
            if container.randomizePan then
              local panMin = container.panRange.min
              local panMax = container.panRange.max
              
              reaper.ImGui_PushItemWidth(globals.ctx, 300)
              local rv, newPanMin, newPanMax = reaper.ImGui_DragFloatRange2(globals.ctx, "Pan Range (-100/+100)##" .. containerId, panMin, panMax, 1, -100, 100)
              if rv then 
                container.panRange.min = newPanMin
                container.panRange.max = newPanMax
              end
            end
            
            reaper.ImGui_TreePop(globals.ctx)
          end
          reaper.ImGui_Unindent(globals.ctx, 20)
          
          -- Delete a container if needed
          if containerToDelete then
            table.remove(track.containers, containerToDelete)
          end
        end
        
        reaper.ImGui_TreePop(globals.ctx)
      end
      
      -- Delete a track if needed
      if trackToDelete then
        table.remove(globals.tracks, trackToDelete)
      end
    end
    
    reaper.ImGui_Separator(globals.ctx)
    
    -- Button to generate tracks and place items
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_Button(), 0xFF4CAF50)
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF66BB6A)
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonActive(), 0xFF43A047)
    
    if reaper.ImGui_Button(globals.ctx, "Create Ambiance", 300, 40) then
      Generation.generateTracks()
    end
    
    reaper.ImGui_PopStyleColor(globals.ctx, 3)
    
    reaper.ImGui_End(globals.ctx)
  end
  
  -- Check for any popup that might be stuck
  for name, popup in pairs(globals.activePopups) do
    if popup.active and reaper.time_precise() - popup.timeOpened > 5 then
      -- Force close popups that have been open too long (5 seconds)
      reaper.ImGui_CloseCurrentPopup(globals.ctx)
      globals.activePopups[name] = nil
    end
  end
  
  if open then
    reaper.defer(UI.mainLoop)
  else
    reaper.ImGui_DestroyContext(globals.ctx)
  end
end

return UI
