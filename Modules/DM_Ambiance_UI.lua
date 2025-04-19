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

local UI_Preset = require("DM_Ambiance_UI_Preset")
local UI_Container = require("DM_Ambiance_UI_Container")

-- Initialize the module with global variables from the main script
function UI.initModule(g)
  globals = g
  
  -- Initialize selection tracking variables for two-panel layout
  globals.selectedTrackIndex = nil
  globals.selectedContainerIndex = nil
  
  -- Initialize structure for multi-selection
  globals.selectedContainers = {} -- Format: {[trackIndex_containerIndex] = true}
  globals.inMultiSelectMode = false
  
  -- Initialize variables for Shift multi-selection
  globals.shiftAnchorTrackIndex = nil
  globals.shiftAnchorContainerIndex = nil
  
  -- Initialize UI sub-modules
  UI_Preset.initModule(globals)
  UI_Container.initModule(globals)
end

-- Function to display track preset controls for a specific track
local function drawTrackPresetControls(i)
  -- Code existant, inchangé
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

-- Get count of selected containers
local function getSelectedContainersCount()
  local count = 0
  for _ in pairs(globals.selectedContainers) do
    count = count + 1
  end
  return count
end

-- Function to check if a container is selected
local function isContainerSelected(trackIndex, containerIndex)
  return globals.selectedContainers[trackIndex .. "_" .. containerIndex] == true
end

-- Function to toggle container selection
local function toggleContainerSelection(trackIndex, containerIndex)
  local key = trackIndex .. "_" .. containerIndex
  
  if globals.selectedContainers[key] then
    globals.selectedContainers[key] = nil
  else
    globals.selectedContainers[key] = true
  end
  
  -- Update primary selection for compatibility
  globals.selectedTrackIndex = trackIndex
  globals.selectedContainerIndex = containerIndex
end

-- Function to clear all container selections
local function clearContainerSelections()
  globals.selectedContainers = {}
  globals.inMultiSelectMode = false
  -- Also clear the shift anchor when clearing selections
  globals.shiftAnchorTrackIndex = nil
  globals.shiftAnchorContainerIndex = nil
end

-- Function to select a range of containers between two points
local function selectContainerRange(startTrackIndex, startContainerIndex, endTrackIndex, endContainerIndex)
  -- Clear existing selection first if not in multi-select mode
  if not (reaper.ImGui_GetKeyMods(globals.ctx) & reaper.ImGui_Mod_Ctrl() ~= 0) then
    clearContainerSelections()
  end
  
  -- Handle range selection within the same track
  if startTrackIndex == endTrackIndex then
    local track = globals.tracks[startTrackIndex]
    local startIdx = math.min(startContainerIndex, endContainerIndex)
    local endIdx = math.max(startContainerIndex, endContainerIndex)
    
    for i = startIdx, endIdx do
      if i <= #track.containers then
        globals.selectedContainers[startTrackIndex .. "_" .. i] = true
      end
    end
    return
  end
  
  -- Handle range selection across different tracks
  local startTrack = math.min(startTrackIndex, endTrackIndex)
  local endTrack = math.max(startTrackIndex, endTrackIndex)
  
  -- If selecting from higher track to lower track, reverse the container indices
  local firstContainerIdx, lastContainerIdx
  if startTrackIndex < endTrackIndex then
    firstContainerIdx, lastContainerIdx = startContainerIndex, endContainerIndex
  else
    firstContainerIdx, lastContainerIdx = endContainerIndex, startContainerIndex
  end
  
  -- Select all containers in the range
  for t = startTrack, endTrack do
    if globals.tracks[t] then
      if t == startTrack then
        -- First track: select from firstContainerIdx to end
        for c = firstContainerIdx, #globals.tracks[t].containers do
          globals.selectedContainers[t .. "_" .. c] = true
        end
      elseif t == endTrack then
        -- Last track: select from start to lastContainerIdx
        for c = 1, lastContainerIdx do
          globals.selectedContainers[t .. "_" .. c] = true
        end
      else
        -- Middle tracks: select all containers
        for c = 1, #globals.tracks[t].containers do
          globals.selectedContainers[t .. "_" .. c] = true
        end
      end
    end
  end
  
  -- Update the multi-select mode flag
  globals.inMultiSelectMode = getSelectedContainersCount() > 1
end



-- Function to draw the left panel containing tracks and containers list
local function drawLeftPanel(width)
  -- Title for the left panel
  reaper.ImGui_Text(globals.ctx, "Tracks & Containers")
  
  -- Multi-selection mode toggle and info
  if getSelectedContainersCount() > 1 then
    reaper.ImGui_SameLine(globals.ctx)
    reaper.ImGui_TextColored(globals.ctx, 0xFF4CAF50, "(" .. getSelectedContainersCount() .. " selected)")
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Clear Selection") then
      clearContainerSelections()
    end
  end
  
  -- Button to add a new track
  if reaper.ImGui_Button(globals.ctx, "Add Track") then
    table.insert(globals.tracks, Structures.createTrack())
  end
  
  reaper.ImGui_Separator(globals.ctx)
  
  -- Check if Ctrl key is pressed for multi-selection mode
  local ctrlPressed = reaper.ImGui_GetKeyMods(globals.ctx) & reaper.ImGui_Mod_Ctrl() ~= 0
  
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
      
      -- Clear multi-selection if not holding Ctrl
      if not ctrlPressed then
        clearContainerSelections()
      end
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
        if isContainerSelected(i, j) then
          containerFlags = containerFlags + reaper.ImGui_TreeNodeFlags_Selected()
        end
        
        -- Indent container items for better visual hierarchy
        reaper.ImGui_Indent(globals.ctx, 20)
        reaper.ImGui_TreeNodeEx(globals.ctx, containerId, container.name, containerFlags)
        
        -- Handle selection on click with multi-selection support
        if reaper.ImGui_IsItemClicked(globals.ctx) then
          -- Check if Shift is pressed for range selection
          local shiftPressed = reaper.ImGui_GetKeyMods(globals.ctx) & reaper.ImGui_Mod_Shift() ~= 0
          
          -- If Ctrl is pressed, toggle this container in multi-selection
          if ctrlPressed then
            toggleContainerSelection(i, j)
            globals.inMultiSelectMode = getSelectedContainersCount() > 1
            
            -- Update anchor point for Shift+Click
            globals.shiftAnchorTrackIndex = i
            globals.shiftAnchorContainerIndex = j
          -- If Shift is pressed, select range from last anchor to this container
          elseif shiftPressed and globals.shiftAnchorTrackIndex then
            selectContainerRange(globals.shiftAnchorTrackIndex, globals.shiftAnchorContainerIndex, i, j)
          else
            -- Otherwise, select only this container and update anchor
            clearContainerSelections()
            toggleContainerSelection(i, j)
            globals.inMultiSelectMode = false
            
            -- Set new anchor point for Shift+Click
            globals.shiftAnchorTrackIndex = i
            globals.shiftAnchorContainerIndex = j
          end
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
        -- Remove from selected containers if it was selected
        globals.selectedContainers[i .. "_" .. containerToDelete] = nil
        
        table.remove(track.containers, containerToDelete)
        
        -- Update primary selection if necessary
        if globals.selectedTrackIndex == i and globals.selectedContainerIndex == containerToDelete then
          globals.selectedContainerIndex = nil
        elseif globals.selectedTrackIndex == i and globals.selectedContainerIndex > containerToDelete then
          globals.selectedContainerIndex = globals.selectedContainerIndex - 1
        end
        
        -- Update multi-selection references for containers after the deleted one
        for k = containerToDelete + 1, #track.containers + 1 do  -- +1 because we just deleted one
          if globals.selectedContainers[i .. "_" .. k] then
            globals.selectedContainers[i .. "_" .. (k-1)] = true
            globals.selectedContainers[i .. "_" .. k] = nil
          end
        end
      end
      
      reaper.ImGui_TreePop(globals.ctx)
    end
  end
  
  -- Delete the marked track if any
  if trackToDelete then
    -- Remove any selected containers from this track
    for key in pairs(globals.selectedContainers) do
      local t, c = key:match("(%d+)_(%d+)")
      if tonumber(t) == trackToDelete then
        globals.selectedContainers[key] = nil
      end
    end
    
    table.remove(globals.tracks, trackToDelete)
    
    -- Update primary selection if necessary
    if globals.selectedTrackIndex == trackToDelete then
      globals.selectedTrackIndex = nil
      globals.selectedContainerIndex = nil
    elseif globals.selectedTrackIndex > trackToDelete then
      globals.selectedTrackIndex = globals.selectedTrackIndex - 1
    end
    
    -- Update multi-selection references for tracks after the deleted one
    for key in pairs(globals.selectedContainers) do
      local t, c = key:match("(%d+)_(%d+)")
      if tonumber(t) > trackToDelete then
        globals.selectedContainers[(tonumber(t)-1) .. "_" .. c] = true
        globals.selectedContainers[key] = nil
      end
    end
  end
  
  -- Update the multi-select mode flag
  globals.inMultiSelectMode = getSelectedContainersCount() > 1
end

-- Function to get all selected containers as a table of {trackIndex, containerIndex} pairs
local function getSelectedContainersList()
  local containers = {}
  for key in pairs(globals.selectedContainers) do
    local t, c = key:match("(%d+)_(%d+)")
    table.insert(containers, {trackIndex = tonumber(t), containerIndex = tonumber(c)})
  end
  return containers
end

-- Function to draw the right panel for multi-selection edit mode
local function drawMultiSelectionPanel(width)
  -- Count selected containers
  local selectedCount = getSelectedContainersCount()
  
  -- Title with count
  reaper.ImGui_TextColored(globals.ctx, 0xFF4CAF50, "Editing " .. selectedCount .. " containers")
  
  if selectedCount == 0 then
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "No containers selected. Select containers to edit them.")
    return
  end
  
  -- Get list of all selected containers
  local containers = getSelectedContainersList()
  
  -- Button to regenerate all selected containers
  if reaper.ImGui_Button(globals.ctx, "Regenerate All Selected", width * 0.5, 30) then
    for _, c in ipairs(containers) do
      Generation.generateSingleContainer(c.trackIndex, c.containerIndex)
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
    local trackIndex = c.trackIndex
    local containerIndex = c.containerIndex
    local container = globals.tracks[trackIndex].containers[containerIndex]
    
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
      commonIntervalMode = -1  -- Mixed values
    end
    
    if commonTriggerRate == nil then
      commonTriggerRate = container.triggerRate
    elseif math.abs(commonTriggerRate - container.triggerRate) > 0.001 then
      commonTriggerRate = -999  -- Mixed values
    end
    
    if commonTriggerDrift == nil then
      commonTriggerDrift = container.triggerDrift
    elseif commonTriggerDrift ~= container.triggerDrift then
      commonTriggerDrift = -1  -- Mixed values
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
  
  -- Helper function to display a "mixed values" indicator
  local function showMixedValues()
    reaper.ImGui_SameLine(globals.ctx)
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "(Mixed values)")
  end
  
  -- TRIGGER SETTINGS SECTION
  reaper.ImGui_Text(globals.ctx, "Trigger Settings")
  
  -- Repetition activation checkbox (three-state checkbox for mixed values)
  local repetitionState = allUseRepetition and 1 or (anyUseRepetition and 2 or 0)
  local repetitionText = "Use trigger rate"
  
  if repetitionState == 2 then  -- Mixed values
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
      globals.tracks[c.trackIndex].containers[c.containerIndex].useRepetition = newUseRep
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].intervalMode = newIntervalMode
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].intervalMode = newIntervalMode
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].triggerRate = newTriggerRate
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].triggerRate = newTriggerRate
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].triggerDrift = newTriggerDrift
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].triggerDrift = newTriggerDrift
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
  
  if pitchState == 2 then  -- Mixed values
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
      globals.tracks[c.trackIndex].containers[c.containerIndex].randomizePitch = newRandomizePitch
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].pitchRange.min = newPitchMin
          globals.tracks[c.trackIndex].containers[c.containerIndex].pitchRange.max = newPitchMax
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].pitchRange.min = newPitchMin
          globals.tracks[c.trackIndex].containers[c.containerIndex].pitchRange.max = newPitchMax
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
  
  if volumeState == 2 then  -- Mixed values
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
      globals.tracks[c.trackIndex].containers[c.containerIndex].randomizeVolume = newRandomizeVolume
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].volumeRange.min = newVolumeMin
          globals.tracks[c.trackIndex].containers[c.containerIndex].volumeRange.max = newVolumeMax
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].volumeRange.min = newVolumeMin
          globals.tracks[c.trackIndex].containers[c.containerIndex].volumeRange.max = newVolumeMax
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
  
  if panState == 2 then  -- Mixed values
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
      globals.tracks[c.trackIndex].containers[c.containerIndex].randomizePan = newRandomizePan
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].panRange.min = newPanMin
          globals.tracks[c.trackIndex].containers[c.containerIndex].panRange.max = newPanMax
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
          globals.tracks[c.trackIndex].containers[c.containerIndex].panRange.min = newPanMin
          globals.tracks[c.trackIndex].containers[c.containerIndex].panRange.max = newPanMax
        end
        -- Update state for UI refresh
        commonPanMin = newPanMin
        commonPanMax = newPanMax
      end
    end
  end
end

-- Function to draw the right panel containing detailed settings for the selected container
local function drawRightPanel(width)
  -- If we're in multi-select mode, draw the multi-selection panel
  if globals.inMultiSelectMode then
      drawMultiSelectionPanel(width)
      return
  end
  
  -- Show container details if a container is selected
  if globals.selectedTrackIndex and globals.selectedContainerIndex then
      -- Utiliser le module UI_Container pour afficher les paramètres du conteneur
      UI_Container.displayContainerSettings(globals.selectedTrackIndex, globals.selectedContainerIndex, width)
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
      UI_Preset.drawPresetControls()
      
      -- Button to generate all tracks and place items - moved to top, with custom styling
      reaper.ImGui_SameLine(globals.ctx)
      reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_Button(), 0xFF4CAF50) -- Green button
      reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF66BB6A) -- Lighter green when hovered
      reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonActive(), 0xFF43A047) -- Darker green when clicked
      
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
