local Utils = {}
local globals = {}

function Utils.initModule(g)
  globals = g
end

-- Function to find a track by its name
function Utils.findTrackByName(name)
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if trackName == name then
      return track, i
    end
  end
  return nil, -1
end

-- Function to find a container track within a parent track
function Utils.findContainerTrack(parentTrackIdx, containerName)
  if parentTrackIdx < 0 then return nil, -1 end
  
  local trackCount = reaper.CountTracks(0)
  local folderDepth = 1 -- Start with depth 1 (inside a folder)
  
  for i = parentTrackIdx + 1, trackCount - 1 do
    local track = reaper.GetTrack(0, i)
    local depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    
    -- Update folder depth
    folderDepth = folderDepth + depth
    
    -- If we reach the end of the folder, stop searching
    if folderDepth <= 0 then break end
    
    -- Check if this track is our container
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if trackName == containerName then
      return track, i
    end
  end
  
  return nil, -1
end

-- Function to delete all media items from a track
function Utils.clearTrackItems(track)
  if not track then return false end
  
  local itemCount = reaper.GetTrackNumMediaItems(track)
  for i = itemCount-1, 0, -1 do
    local item = reaper.GetTrackMediaItem(track, i)
    reaper.DeleteTrackMediaItem(track, item)
  end
  
  return true
end

-- Function to open the preset folder
function Utils.openPresetsFolder(type, trackName)
  local path = globals.Presets.getPresetsPath(type, trackName)
  
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
    reaper.ImGui_OpenPopup(globals.ctx, popupName)
    globals.activePopups[popupName] = { active = true, timeOpened = reaper.time_precise() }
  end
end

function Utils.safeClosePopup(popupName)
  reaper.ImGui_CloseCurrentPopup(globals.ctx)
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

return Utils
