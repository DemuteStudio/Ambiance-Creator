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
function Items.createTakePanEnvelope(take, panValue)
  -- Check if the take is valid
  if not take then return end
  
  -- Get the parent item
  local item = reaper.GetMediaItemTake_Item(take)
  if not item then return end
  
  -- Get the pan envelope by its name
  local env = reaper.GetTakeEnvelopeByName(take, "Pan")
  
  -- If the envelope doesn't exist, create it manually
  if not env then
      -- Remember the original selection state
      local wasSelected = reaper.IsMediaItemSelected(item)
      
      -- Select the item to be able to use the command
      reaper.SetMediaItemSelected(item, true)
      
      -- Use the native REAPER command to create the pan envelope
      reaper.Main_OnCommand(40694, 0)
      
      -- Get the created envelope
      env = reaper.GetTakeEnvelopeByName(take, "Pan")
      
      -- Restore the original selection state
      reaper.SetMediaItemSelected(item, wasSelected)
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
  end
end


return Items
