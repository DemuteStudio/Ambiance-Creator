--[[
@version 1.3
@noindex
--]]

local Items = {}
local globals = {}

function Items.initModule(g)
  globals = g
end

-- Get selected items
function Items.getSelectedItems()
  local items = {}
  local count = reaper.CountSelectedMediaItems(0)
  
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    
    if take then
      local source = reaper.GetMediaItemTake_Source(take)
      local filename = reaper.GetMediaSourceFileName(source, "")
      
      local itemData = {
        name = reaper.GetTakeName(take),
        filePath = filename,
        startOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
        length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
        originalPitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH"),
        originalVolume = reaper.GetMediaItemTakeInfo_Value(take, "D_VOL"),
        originalPan = reaper.GetMediaItemTakeInfo_Value(take, "D_PAN")
      }
      table.insert(items, itemData)
    end
  end
  
  return items
end

-- Function to create a pan envelope and add a point
-- @param take MediaItemTake: The take to create envelope for
-- @param panValue number: Pan value (-1 to 1)
function Items.createTakePanEnvelope(take, panValue)
  -- Check if the take is valid
  if not take then 
    reaper.ShowConsoleMsg("DEBUG: createTakePanEnvelope - invalid take\n")
    return 
  end
  
  -- Get the parent item
  local item = reaper.GetMediaItemTake_Item(take)
  if not item then 
    reaper.ShowConsoleMsg("DEBUG: createTakePanEnvelope - invalid item\n")
    return 
  end
  
  reaper.ShowConsoleMsg("DEBUG: createTakePanEnvelope called with panValue=" .. panValue .. "\n")
  
  -- Get the pan envelope by its name
  local env = reaper.GetTakeEnvelopeByName(take, "Pan")
  
  -- If the envelope doesn't exist, create it manually but without problematic UI commands
  if not env then
      reaper.ShowConsoleMsg("DEBUG: Pan envelope doesn't exist, creating it manually\n")
      
      -- Save the complete current selection
      local numSelectedItems = reaper.CountSelectedMediaItems(0)
      local selectedItems = {}
      for i = 0, numSelectedItems - 1 do
          selectedItems[i + 1] = reaper.GetSelectedMediaItem(0, i)
      end
      
      -- Clear all selections and select only our target item
      reaper.SelectAllMediaItems(0, false)
      reaper.SetMediaItemSelected(item, true)
      
      -- Use ONLY the create envelope command, no visibility commands
      reaper.Main_OnCommand(40694, 0)  -- Create take pan envelope
      
      -- Force update and get the created envelope
      reaper.UpdateArrange()
      
      env = reaper.GetTakeEnvelopeByName(take, "Pan")
      
      -- Restore the original selection
      reaper.SelectAllMediaItems(0, false)
      for i, selectedItem in ipairs(selectedItems) do
          reaper.SetMediaItemSelected(selectedItem, true)
      end
      
      if env then
          reaper.ShowConsoleMsg("DEBUG: Pan envelope created successfully\n")
      else
          reaper.ShowConsoleMsg("DEBUG: Failed to create pan envelope\n")
          return
      end
  else
      reaper.ShowConsoleMsg("DEBUG: Pan envelope already exists\n")
  end
  
  if env then
      -- Calculate time for envelope points
      local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local playRate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
      
      -- Delete all existing points
      reaper.DeleteEnvelopePointRange(env, 0, itemLength * playRate)
      
      -- Add points at the beginning and end with the same value
      reaper.InsertEnvelopePoint(env, 0, panValue, 0, 0, false, true)
      reaper.InsertEnvelopePoint(env, itemLength * playRate, panValue, 0, 0, false, true)
      
      -- Sorting is necessary after adding points with noSort = true
      reaper.Envelope_SortPoints(env)
      
      -- Force display update to make envelope visible
      reaper.UpdateArrange()
      reaper.ShowConsoleMsg("DEBUG: Pan envelope points added successfully\n")
  else
      reaper.ShowConsoleMsg("DEBUG: No pan envelope available to add points to\n")
  end
end

-- Function to update all points in an existing pan envelope
function Items.updateTakePanEnvelope(take, newPanValue)
  -- Check if the take is valid
  if not take then 
    reaper.ShowConsoleMsg("DEBUG: updateTakePanEnvelope - invalid take\n")
    return false
  end
  
  reaper.ShowConsoleMsg("DEBUG: updateTakePanEnvelope called with newPanValue=" .. newPanValue .. "\n")
  
  -- Get the existing pan envelope
  local env = reaper.GetTakeEnvelopeByName(take, "Pan")
  if not env then
    reaper.ShowConsoleMsg("DEBUG: No existing pan envelope to update\n")
    return false
  end
  
  -- Get the number of existing points
  local numPoints = reaper.CountEnvelopePoints(env)
  reaper.ShowConsoleMsg("DEBUG: Found " .. numPoints .. " envelope points to update\n")
  
  if numPoints == 0 then
    -- No points exist, create initial points
    local item = reaper.GetMediaItemTake_Item(take)
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local playRate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    
    reaper.InsertEnvelopePoint(env, 0, newPanValue, 0, 0, false, true)
    reaper.InsertEnvelopePoint(env, itemLength * playRate, newPanValue, 0, 0, false, true)
    reaper.Envelope_SortPoints(env)
    reaper.ShowConsoleMsg("DEBUG: Created initial points with value " .. newPanValue .. "\n")
  else
    -- Update all existing points with the new pan value
    for i = 0, numPoints - 1 do
      local retval, time, oldValue, shape, tension, selected = reaper.GetEnvelopePoint(env, i)
      if retval then
        reaper.SetEnvelopePoint(env, i, time, newPanValue, shape, tension, selected, true)
        reaper.ShowConsoleMsg("DEBUG: Updated point " .. i .. " from " .. oldValue .. " to " .. newPanValue .. "\n")
      end
    end
  end
  
  -- Force display update
  reaper.UpdateArrange()
  reaper.ShowConsoleMsg("DEBUG: Pan envelope updated successfully\n")
  return true
end


return Items
