--[[
  Sound Randomizer for REAPER
  This script provides a GUI interface for creating randomized ambient sounds
  It allows creating tracks with containers of audio items that can be randomized by pitch, volume, and pan
  Uses ReaImGui for UI rendering
]]

local UI = {}
local globals = {}
local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")

-- Initialize the module with global variables from the main script
function UI.initModule(g)
  globals = g
  
  -- Initialize selection tracking variables for two-panel layout
  globals.selectedTrackIndex = nil
  globals.selectedContainerIndex = nil
end

-- Function to display global preset controls in the top section
local function drawPresetControls()
  -- Section title with colored text
  reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Global Presets")
  
  -- Refresh button to update preset list
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Refresh") then
    Presets.listPresets("Global", nil, true)
  end
  
  -- Dropdown list of presets
  reaper.ImGui_SameLine(globals.ctx)
  
  -- Get the preset list from presets module
  local presetList = Presets.listPresets("Global")
  
  -- Prepare items for the dropdown (ImGui Combo)
  -- The \0 character is used as a separator in ImGui
  local presetItems = ""
  for _, name in ipairs(presetList) do
    presetItems = presetItems .. name .. "\0"
  end
  presetItems = presetItems .. "\0"
  
  -- Display the dropdown list with existing presets
  reaper.ImGui_PushItemWidth(globals.ctx, 300)
  local rv, newSelectedIndex = reaper.ImGui_Combo(globals.ctx, "##PresetSelector", globals.selectedPresetIndex, presetItems)
  
  -- Handle selection change
  if rv then
    globals.selectedPresetIndex = newSelectedIndex
    globals.currentPresetName = presetList[globals.selectedPresetIndex + 1] or ""
  end
  
  -- Action buttons: Load, Save, Delete, Open Directory
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
  
  -- Save preset popup modal
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
  
  -- Deletion confirmation popup modal
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
end

-- Function to display track preset controls for a specific track
local function drawTrackPresetControls(i)
  local trackId = "track" .. i
  
  -- Initialize selected preset index if needed
  if not globals.selectedTrackPresetIndex[i] then
    globals.selectedTrackPresetIndex[i] = -1
  end
  
  -- Get track presets
  local trackPresetList = Presets.listPresets("Tracks")
  
  -- Prepare items for the preset dropdown
  local trackPresetItems = ""
  for _, name in ipairs(trackPresetList) do
    trackPresetItems = trackPresetItems .. name .. "\0"
  end
  trackPresetItems = trackPresetItems .. "\0"
  
  -- Track preset dropdown
  reaper.ImGui_PushItemWidth(globals.ctx, 200)
  local rv, newSelectedTrackIndex = reaper.ImGui_Combo(globals.ctx, "##TrackPresetSelector" .. trackId, 
                                                      globals.selectedTrackPresetIndex[i], trackPresetItems)
  
  if rv then
    globals.selectedTrackPresetIndex[i] = newSelectedTrackIndex
  end
  
  -- Load preset button
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Load Track##" .. trackId) and 
     globals.selectedTrackPresetIndex[i] >= 0 and 
     globals.selectedTrackPresetIndex[i] < #trackPresetList then
    local presetName = trackPresetList[globals.selectedTrackPresetIndex[i] + 1]
    Presets.loadTrackPreset(presetName, i)
  end
  
  -- Save preset button
  reaper.ImGui_SameLine(globals.ctx)
  if reaper.ImGui_Button(globals.ctx, "Save Track##" .. trackId) then
    globals.newTrackPresetName = globals.tracks[i].name
    globals.currentSaveTrackIndex = i
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

-- Function to display container preset controls for a specific container
local function drawContainerPresetControls(trackIndex, containerIndex)
  local trackId = "track" .. trackIndex
  local containerId = trackId .. "_container" .. containerIndex
  local presetKey = trackIndex .. "_" .. containerIndex
  
  -- Initialize selected preset index if needed
  if not globals.selectedContainerPresetIndex[presetKey] then
    globals.selectedContainerPresetIndex[presetKey] = -1
  end
  
  -- Get sanitized track name for folder structure (replacing non-alphanumeric chars with underscore)
  local trackName = globals.tracks[trackIndex].name:gsub("[^%w]", "_")
  
  -- Get container presets for this track
  local containerPresetList = Presets.listPresets("Containers", trackName)
  
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
    Presets.loadContainerPreset(presetName, trackIndex, containerIndex)
  end
  
  -- Save preset button
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

-- Function to draw the left panel containing tracks and containers list
local function drawLeftPanel(width)
  -- Title for the left panel
  reaper.ImGui_Text(globals.ctx, "Tracks & Containers")
  
  -- Button to add a new track
  if reaper.ImGui_Button(globals.ctx, "Add Track") then
    table.insert(globals.tracks, Structures.createTrack())
  end
  
  reaper.ImGui_Separator(globals.ctx)
  
  -- Variable to track which track to delete (if any)
  local trackToDelete = nil
  
  -- Loop through all tracks
  for i, track in ipairs(globals.tracks) do
    local trackId = "track" .. i
    -- TreeNode flags - include selection flags if needed
    local trackFlags = track.expanded and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
    
    -- Add specific flags to indicate selection
    if globals.selectedTrackIndex == i and globals.selectedContainerIndex == nil then
      trackFlags = trackFlags + reaper.ImGui_TreeNodeFlags_Selected()
    end
    
    -- Create tree node for the track
    local trackOpen = reaper.ImGui_TreeNodeEx(globals.ctx, trackId, track.name, trackFlags)
    
    -- Handle selection on click
    if reaper.ImGui_IsItemClicked(globals.ctx) then
      globals.selectedTrackIndex = i
      globals.selectedContainerIndex = nil
    end
    
    -- Delete track button
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Delete##" .. trackId) then
      trackToDelete = i
    end
    
    -- Regenerate track button
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Regenerate##" .. trackId) then
      Generation.generateSingleTrack(i)
    end
    
    -- If the track node is open, display its contents
    if trackOpen then
      -- Track name input field
      local trackName = track.name
      reaper.ImGui_PushItemWidth(globals.ctx, width * 0.8)
      local rv, newTrackName = reaper.ImGui_InputText(globals.ctx, "Name##" .. trackId, trackName)
      if rv then track.name = newTrackName end
      
      -- Track preset controls
      drawTrackPresetControls(i)
      
      -- Button to add a container to this track
      if reaper.ImGui_Button(globals.ctx, "Add Container##" .. trackId) then
        table.insert(track.containers, Structures.createContainer())
      end
      
      -- Variable to track which container to delete (if any)
      local containerToDelete = nil
      
      -- Loop through all containers in this track
      for j, container in ipairs(track.containers) do
        local containerId = trackId .. "_container" .. j
        -- TreeNode flags - leaf nodes for containers with selection support
        local containerFlags = reaper.ImGui_TreeNodeFlags_Leaf() + reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen()
        
        -- Add specific flags to indicate selection
        if globals.selectedTrackIndex == i and globals.selectedContainerIndex == j then
          containerFlags = containerFlags + reaper.ImGui_TreeNodeFlags_Selected()
        end
        
        -- Indent container items for better visual hierarchy
        reaper.ImGui_Indent(globals.ctx, 20)
        reaper.ImGui_TreeNodeEx(globals.ctx, containerId, container.name, containerFlags)
        
        -- Handle selection on click
        if reaper.ImGui_IsItemClicked(globals.ctx) then
          globals.selectedTrackIndex = i
          globals.selectedContainerIndex = j
        end
        
        -- Delete container button
        reaper.ImGui_SameLine(globals.ctx)
        if reaper.ImGui_Button(globals.ctx, "Delete##" .. containerId) then
          containerToDelete = j
        end
        
        -- Regenerate container button
        reaper.ImGui_SameLine(globals.ctx)
        if reaper.ImGui_Button(globals.ctx, "Regenerate##" .. containerId) then
          Generation.generateSingleContainer(i, j)
        end
        
        reaper.ImGui_Unindent(globals.ctx, 20)
      end
      
      -- Delete the marked container if any
      if containerToDelete then
        table.remove(track.containers, containerToDelete)
        -- Update selection if necessary
        if globals.selectedTrackIndex == i and globals.selectedContainerIndex == containerToDelete then
          globals.selectedContainerIndex = nil
        elseif globals.selectedTrackIndex == i and globals.selectedContainerIndex > containerToDelete then
          globals.selectedContainerIndex = globals.selectedContainerIndex - 1
        end
      end
      
      reaper.ImGui_TreePop(globals.ctx)
    end
  end
  
  -- Delete the marked track if any
  if trackToDelete then
    table.remove(globals.tracks, trackToDelete)
    -- Update selection if necessary
    if globals.selectedTrackIndex == trackToDelete then
      globals.selectedTrackIndex = nil
      globals.selectedContainerIndex = nil
    elseif globals.selectedTrackIndex > trackToDelete then
      globals.selectedTrackIndex = globals.selectedTrackIndex - 1
    end
  end
end

-- Function to draw the right panel containing detailed settings for the selected container
local function drawRightPanel(width)
  -- Show container details if a container is selected
  if globals.selectedTrackIndex and globals.selectedContainerIndex then
    local track = globals.tracks[globals.selectedTrackIndex]
    local container = track.containers[globals.selectedContainerIndex]
    local trackId = "track" .. globals.selectedTrackIndex
    local containerId = trackId .. "_container" .. globals.selectedContainerIndex
    
    -- Panel title showing which container is being edited
    reaper.ImGui_Text(globals.ctx, "Container Settings: " .. container.name)
    reaper.ImGui_Separator(globals.ctx)
    
    -- Container name input field
    local containerName = container.name
    reaper.ImGui_PushItemWidth(globals.ctx, width * 0.5)
    local rv, newContainerName = reaper.ImGui_InputText(globals.ctx, "Name##detail_" .. containerId, containerName)
    if rv then container.name = newContainerName end
    
    -- Container preset controls
    drawContainerPresetControls(globals.selectedTrackIndex, globals.selectedContainerIndex)
    
    -- Button to import selected items from REAPER
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
  elseif globals.selectedTrackIndex then
    -- Show track details if only a track is selected
    local track = globals.tracks[globals.selectedTrackIndex]
    reaper.ImGui_Text(globals.ctx, "Track Settings: " .. track.name)
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Select a container to view and edit its settings.")
  else
    -- No selection
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Select a track or container to view and edit its settings.")
  end
end

-- Function to handle popup management and timeout
local function handlePopups()
  -- Check for any popup that might be stuck (safety measure)
  for name, popup in pairs(globals.activePopups) do
    if popup.active and reaper.time_precise() - popup.timeOpened > 5 then
      -- Force close popups that have been open too long (5 seconds)
      reaper.ImGui_CloseCurrentPopup(globals.ctx)
      globals.activePopups[name] = nil
    end
  end
end

-- Main interface loop - this is called repeatedly to render the UI
function UI.mainLoop()
  -- Begin the main window
  local visible, open = reaper.ImGui_Begin(globals.ctx, 'Sound Randomizer', true)
  
  if visible then
    -- Section with presets controls at the top
    drawPresetControls()
    
    -- Button to generate all tracks and place items - moved to top, with custom styling
    reaper.ImGui_SameLine(globals.ctx)
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_Button(), 0xFF4CAF50)     -- Green button
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF66BB6A)  -- Lighter green when hovered
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonActive(), 0xFF43A047)   -- Darker green when clicked
    
    if reaper.ImGui_Button(globals.ctx, "Create Ambiance", 150, 30) then
      Generation.generateTracks()
    end
    
    -- Pop styling colors to return to default
    reaper.ImGui_PopStyleColor(globals.ctx, 3)
    
    -- Display time selection information
    if Utils.checkTimeSelection() then
      reaper.ImGui_Text(globals.ctx, "Time Selection: " .. Utils.formatTime(globals.startTime) .. " - " .. Utils.formatTime(globals.endTime) .. " | Length: " .. Utils.formatTime(globals.endTime - globals.startTime))
    else
      reaper.ImGui_TextColored(globals.ctx, 0xFF0000FF, "No time selection! Please create one.")
    end
    
    reaper.ImGui_Separator(globals.ctx)
    
    -- Initialize selection tracking variables if needed
    if not globals.selectedTrackIndex then globals.selectedTrackIndex = nil end
    if not globals.selectedContainerIndex then globals.selectedContainerIndex = nil end
    
    -- Calculate dimensions for the split view layout
    local windowWidth = reaper.ImGui_GetWindowWidth(globals.ctx)
    local leftPanelWidth = windowWidth * 0.35
    local rightPanelWidth = windowWidth * 0.63
    
    -- We'll use a manual split view since ImGui_Columns might not be available
    -- Left panel (Tracks & Containers list)
    reaper.ImGui_BeginChild(globals.ctx, "LeftPanel", leftPanelWidth, 0)
    drawLeftPanel(leftPanelWidth)
    reaper.ImGui_EndChild(globals.ctx)
    
    -- Right panel (Container Settings)
    reaper.ImGui_SameLine(globals.ctx)
    reaper.ImGui_BeginChild(globals.ctx, "RightPanel", rightPanelWidth, 0)
    drawRightPanel(rightPanelWidth)
    reaper.ImGui_EndChild(globals.ctx)
    
    -- End the main window
    reaper.ImGui_End(globals.ctx)
  end
  
  -- Handle popup management
  handlePopups()
  
  -- Defer next UI refresh or destroy context if window is closed
  if open then
    reaper.defer(UI.mainLoop)
  else
    reaper.ImGui_DestroyContext(globals.ctx)
  end
end

return UI
