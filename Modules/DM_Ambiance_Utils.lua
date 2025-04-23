local Utils = {}
local globals = {}

function Utils.initModule(g)
  globals = g
end

function Utils.HelpMarker(desc)
  imgui.TextDisabled(globals.ctx, '(?)')
  if imgui.BeginItemTooltip(globals.ctx) then
    imgui.PushTextWrapPos(globals.ctx, imgui.GetFontSize(globals.ctx) * 35.0)
    imgui.Text(globals.ctx, desc)
    imgui.PopTextWrapPos(globals.ctx)
    imgui.EndTooltip(globals.ctx)
  end
end

-- Function to find a group by its name
function Utils.findGroupByName(name)
  for i = 0, reaper.CountTracks(0) - 1 do
    local group = reaper.GetTrack(0, i)
    local _, groupName = reaper.GetSetMediaTrackInfo_String(group, "P_NAME", "", false)
    if groupName == name then
      return group, i
    end
  end
  return nil, -1
end

-- Function to find a container group within a parent group
function Utils.findContainerGroup(parentGroupIdx, containerName)
  local groupCount = reaper.CountTracks(0)
  local folderDepth = 1 -- Commencer avec profondeur 1 (à l'intérieur d'un dossier)
  
  -- Log for debugging purposes
  -- reaper.ShowConsoleMsg("Searching for container: '" .. containerName .. "' starting from parent index " .. parentGroupIdx .. "\n")
  
  for i = parentGroupIdx + 1, groupCount - 1 do
      local childGroup = reaper.GetTrack(0, i)
      local _, name = reaper.GetSetMediaTrackInfo_String(childGroup, "P_NAME", "", false)
      
      -- Debug info
      -- reaper.ShowConsoleMsg("  Checking group at index " .. i .. ": '" .. name .. "' (depth: " .. folderDepth .. ")\n")
      
      -- Compare names with trim to avoid whitespace issues
      local containerNameTrimmed = string.gsub(containerName, "^%s*(.-)%s*$", "%1")
      local groupNameTrimmed = string.gsub(name, "^%s*(.-)%s*$", "%1")
      
      -- Case insensitive comparison
      if string.lower(groupNameTrimmed) == string.lower(containerNameTrimmed) then
          -- reaper.ShowConsoleMsg("  Found container group at index " .. i .. "\n")
          return childGroup, i
      end
      
      -- Update folder depth based on this group's folder status
      local depth = reaper.GetMediaTrackInfo_Value(childGroup, "I_FOLDERDEPTH")
      folderDepth = folderDepth + depth
      
      -- If we reach the end of the folder, stop searching
      if folderDepth <= 0 then 
          -- reaper.ShowConsoleMsg("  Reached end of folder at index " .. i .. "\n")
          break 
      end
  end
  
  -- Not found
  reaper.ShowConsoleMsg("  Container '" .. containerName .. "' not found in folder structure\n")
  return nil, nil
end

-- Function to delete all media items from a group
function Utils.clearGroupItems(group)
  if not group then return false end
  
  local itemCount = reaper.GetTrackNumMediaItems(group)
  for i = itemCount-1, 0, -1 do
    local item = reaper.GetTrackMediaItem(group, i)
    reaper.DeleteTrackMediaItem(group, item)
  end
  
  return true
end

-- Function to open the preset folder
function Utils.openPresetsFolder(type, groupName)
  local path = globals.Presets.getPresetsPath(type, groupName)
  
  if reaper.GetOS():match("Win") then
    os.execute('start "" "' .. path .. '"')
  elseif reaper.GetOS():match("OSX") then
    os.execute('open "' .. path .. '"')
  else -- Linux
    os.execute('xdg-open "' .. path .. '"')
  end
end

-- Safe popup management to avoid flashing issues
function Utils.safeOpenPopup(popupName)
  if not globals.activePopups[popupName] then
    imgui.OpenPopup(globals.ctx, popupName)
    globals.activePopups[popupName] = { active = true, timeOpened = reaper.time_precise() }
  end
end

function Utils.safeClosePopup(popupName)
  imgui.CloseCurrentPopup(globals.ctx)
  globals.activePopups[popupName] = nil
end

-- Function to check if a time selection exists
function Utils.checkTimeSelection()
  local start, ending = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if start ~= ending then
    globals.timeSelectionValid = true
    globals.startTime = start
    globals.endTime = ending
    globals.timeSelectionLength = ending - start
    return true
  else
    globals.timeSelectionValid = false
    return false
  end
end

-- Generate a random value in a given range
function Utils.randomInRange(min, max)
  return min + math.random() * (max - min)
end

function Utils.formatTime(seconds)
  -- Ensure seconds is a number
  seconds = tonumber(seconds) or 0
  
  -- Calculate hours, minutes, seconds
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = math.floor(seconds % 60)
  
  -- Format with leading zeros if needed
  return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Function to create crossfades for overlapping items
function Utils.createCrossfade(item1, item2, fadeShape)
  local item1End = reaper.GetMediaItemInfo_Value(item1, "D_POSITION") + reaper.GetMediaItemInfo_Value(item1, "D_LENGTH")
  local item2Start = reaper.GetMediaItemInfo_Value(item2, "D_POSITION")
  
  if item2Start < item1End then
    local overlapLength = item1End - item2Start
    
    -- Create fade out on first item
    reaper.SetMediaItemInfo_Value(item1, "D_FADEOUTLEN", overlapLength)
    reaper.SetMediaItemInfo_Value(item1, "C_FADEOUTSHAPE", fadeShape)
    
    -- Create fade in on second item
    reaper.SetMediaItemInfo_Value(item2, "D_FADEINLEN", overlapLength)
    reaper.SetMediaItemInfo_Value(item2, "C_FADEINSHAPE", fadeShape)
    
    return true
  end
  
  return false
end

function Utils.displayTriggerSetting(container)
  imgui.Separator(globals.ctx)
  imgui.Text(globals.ctx, "Trigger Settings")
  
  -- Interval Mode dropdown - different modes for triggering sounds
  local intervalModes = "Absolute\0Relative\0Coverage\0\0"
  local intervalMode = container.intervalMode
  imgui.PushItemWidth(globals.ctx, width * 0.5)
  
  -- Help text explaining the selected mode
  if container.intervalMode == 0 then
      if container.triggerRate < 0 then
          imgui.TextColored(globals.ctx, 0xFFAA00FF, "Negative interval: Items will overlap and crossfade")
      else
          imgui.TextColored(globals.ctx, 0xFFAA00FF, "Absolute: Fixed interval in seconds")
      end
  elseif container.intervalMode == 1 then
      imgui.TextColored(globals.ctx, 0xFFAA00FF, "Relative: Interval as percentage of time selection")
  else
      imgui.TextColored(globals.ctx, 0xFFAA00FF, "Coverage: Percentage of time selection to be filled")
  end
  
  local rv, newIntervalMode = imgui.Combo(globals.ctx, "Interval Mode##" .. containerId, intervalMode, intervalModes)
  if rv then container.intervalMode = newIntervalMode end
  imgui.SameLine(globals.ctx)
  globals.Utils.HelpMarker("Absolute: Fixed interval in seconds\n" ..
  "Relative: Interval as percentage of time selection\n" ..
  "Coverage: Percentage of time selection to be filled")
  
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
  imgui.PushItemWidth(globals.ctx, width * 0.5)
  local rv, newTriggerRate = imgui.SliderDouble(globals.ctx, triggerRateLabel .. "##" .. containerId,
      triggerRate, triggerRateMin, triggerRateMax, "%.1f")
  if rv then container.triggerRate = newTriggerRate end
  
  
  -- Trigger drift slider (randomness in timing)
  local triggerDrift = container.triggerDrift
  imgui.PushItemWidth(globals.ctx, width * 0.5)
  local rv, newTriggerDrift = imgui.SliderInt(globals.ctx, "Random variation (%)##" .. containerId, triggerDrift, 0, 100, "%d")
  if rv then container.triggerDrift = newTriggerDrift end
  
  -- RANDOMIZATION PARAMETERS SECTION
  imgui.Separator(globals.ctx)
  imgui.Text(globals.ctx, "Randomization parameters")
  
  -- Pitch randomization checkbox
  local randomizePitch = container.randomizePitch
  local rv, newRandomizePitch = imgui.Checkbox(globals.ctx, "Randomize Pitch##" .. containerId, randomizePitch)
  if rv then container.randomizePitch = newRandomizePitch end
  
  -- Only show pitch range if pitch randomization is enabled
  if container.randomizePitch then
      local pitchMin = container.pitchRange.min
      local pitchMax = container.pitchRange.max
      imgui.PushItemWidth(globals.ctx, width * 0.7)
      local rv, newPitchMin, newPitchMax = imgui.DragFloatRange2(globals.ctx, "Pitch Range (semitones)##" .. containerId, pitchMin, pitchMax, 0.1, -48, 48)
      if rv then
          container.pitchRange.min = newPitchMin
          container.pitchRange.max = newPitchMax
      end
  end
  
  -- Volume randomization checkbox
  local randomizeVolume = container.randomizeVolume
  local rv, newRandomizeVolume = imgui.Checkbox(globals.ctx, "Randomize Volume##" .. containerId, randomizeVolume)
  if rv then container.randomizeVolume = newRandomizeVolume end
  
  -- Only show volume range if volume randomization is enabled
  if container.randomizeVolume then
      local volumeMin = container.volumeRange.min
      local volumeMax = container.volumeRange.max
      imgui.PushItemWidth(globals.ctx, width * 0.7)
      local rv, newVolumeMin, newVolumeMax = imgui.DragFloatRange2(globals.ctx, "Volume Range (dB)##" .. containerId, volumeMin, volumeMax, 0.1, -24, 24)
      if rv then
          container.volumeRange.min = newVolumeMin
          container.volumeRange.max = newVolumeMax
      end
  end
  
  -- Pan randomization checkbox
  local randomizePan = container.randomizePan
  local rv, newRandomizePan = imgui.Checkbox(globals.ctx, "Randomize Pan##" .. containerId, randomizePan)
  if rv then container.randomizePan = newRandomizePan end
  
  -- Only show pan range if pan randomization is enabled
  if container.randomizePan then
      local panMin = container.panRange.min
      local panMax = container.panRange.max
      imgui.PushItemWidth(globals.ctx, width * 0.7)
      local rv, newPanMin, newPanMax = imgui.DragFloatRange2(globals.ctx, "Pan Range (-100/+100)##" .. containerId, panMin, panMax, 1, -100, 100)
      if rv then
          container.panRange.min = newPanMin
          container.panRange.max = newPanMax
      end
  end
end


return Utils
