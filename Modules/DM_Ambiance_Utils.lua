local Utils = {}
local globals = {}

function Utils.initModule(g)
  globals = g
end

function Utils.HelpMarker(desc)
  reaper.ImGui_TextDisabled(globals.ctx, '(?)')
  if reaper.ImGui_BeginItemTooltip(globals.ctx) then
    reaper.ImGui_PushTextWrapPos(globals.ctx, reaper.ImGui_GetFontSize(globals.ctx) * 35.0)
    reaper.ImGui_Text(globals.ctx, desc)
    reaper.ImGui_PopTextWrapPos(globals.ctx)
    reaper.ImGui_EndTooltip(globals.ctx)
  end
end

-- Function to find a group by its name
function Utils.findGroupByName(name)
  for i = 0, reaper.CountGroups(0) - 1 do
    local group = reaper.GetGroup(0, i)
    local _, groupName = reaper.GetSetMediaGroupInfo_String(group, "P_NAME", "", false)
    if groupName == name then
      return group, i
    end
  end
  return nil, -1
end

-- Function to find a container group within a parent group
function Utils.findContainerGroup(parentGroupIdx, containerName)
  local groupCount = reaper.CountGroups(0)
  local folderDepth = 1 -- Commencer avec profondeur 1 (à l'intérieur d'un dossier)
  
  -- Log for debugging purposes
  -- reaper.ShowConsoleMsg("Searching for container: '" .. containerName .. "' starting from parent index " .. parentGroupIdx .. "\n")
  
  for i = parentGroupIdx + 1, groupCount - 1 do
      local childGroup = reaper.GetGroup(0, i)
      local _, name = reaper.GetSetMediaGroupInfo_String(childGroup, "P_NAME", "", false)
      
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
      local depth = reaper.GetMediaGroupInfo_Value(childGroup, "I_FOLDERDEPTH")
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
  
  local itemCount = reaper.GetGroupNumMediaItems(group)
  for i = itemCount-1, 0, -1 do
    local item = reaper.GetGroupMediaItem(group, i)
    reaper.DeleteGroupMediaItem(group, item)
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
