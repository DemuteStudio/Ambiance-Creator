-- DM_Ambiance_Generation.lua (modifié)
local Generation = {}

local globals = {}

local Utils = require("DM_Ambiance_Utils")
local Items = require("DM_Ambiance_Items")

function Generation.initModule(g)
    globals = g
end

-- Function to delete existing groups with same names before generating
function Generation.deleteExistingGroups()
  -- Create a map of group names we're about to create
  local groupNames = {}
  for _, group in ipairs(globals.groups) do
      groupNames[group.name] = true
  end
  
  -- Find all tracks with matching names and their children
  local groupsToDelete = {}
  local groupCount = reaper.CountTracks(0)
  local i = 0
  while i < groupCount do
      local group = reaper.GetTrack(0, i)
      local _, name = reaper.GetSetMediaTrackInfo_String(group, "P_NAME", "", false)
      if groupNames[name] then
          -- Check if this is a folder track
          local depth = reaper.GetMediaTrackInfo_Value(group, "I_FOLDERDEPTH")
          -- Add this track to the delete list
          table.insert(groupsToDelete, group)
          -- If this is a folder track, also find all its children
          if depth == 1 then
              local j = i + 1
              local folderDepth = 1 -- Start with depth 1 (we're inside one folder)
              while j < groupCount and folderDepth > 0 do
                  local childGroup = reaper.GetTrack(0, j)
                  table.insert(groupsToDelete, childGroup)
                  -- Update folder depth based on this group's folder status
                  local childDepth = reaper.GetMediaTrackInfo_Value(childGroup, "I_FOLDERDEPTH")
                  folderDepth = folderDepth + childDepth
                  j = j + 1
              end
              -- Skip the children we've already processed
              i = j - 1
          end
      end
      i = i + 1
  end
  
  -- Delete tracks in reverse order to avoid index issues
  for i = #groupsToDelete, 1, -1 do
      reaper.DeleteTrack(groupsToDelete[i])
  end
end


-- Function to place items for a container with inheritance support
function Generation.placeItemsForContainer(group, container, containerGroup, xfadeshape)
    -- Get effective parameters considering inheritance from parent group
    local effectiveParams = globals.Structures.getEffectiveContainerParams(group, container)
    
    if effectiveParams.items and #effectiveParams.items > 0 then
        if effectiveParams.useRepetition then
            -- Placement based on trigger rate with drift
            local lastItemEnd = globals.startTime -- Start at beginning of time selection
            local lastItemRef = nil -- Reference to the last item created
            
            while lastItemEnd < globals.endTime do
                -- Select a random item from the container
                local randomItemIndex = math.random(1, #effectiveParams.items)
                local itemData = effectiveParams.items[randomItemIndex]
                
                -- Calculate interval based on the selected mode
                local interval = effectiveParams.triggerRate -- Default (Absolute mode)
                if effectiveParams.intervalMode == 1 then
                    -- Relative mode: Interval is a percentage of time selection length
                    interval = (globals.timeSelectionLength * effectiveParams.triggerRate) / 100
                elseif effectiveParams.intervalMode == 2 then
                    -- Coverage mode: Calculate interval based on average item length and desired coverage
                    local totalItemLength = 0
                    local itemCount = #effectiveParams.items
                    if itemCount > 0 then
                        for _, item in ipairs(effectiveParams.items) do
                            totalItemLength = totalItemLength + item.length
                        end
                        local averageItemLength = totalItemLength / itemCount
                        local desiredCoverage = effectiveParams.triggerRate / 100 -- Convert percentage to ratio
                        local totalNumberOfItems = (globals.timeSelectionLength * desiredCoverage) / averageItemLength
                        if totalNumberOfItems > 0 then
                            interval = globals.timeSelectionLength / totalNumberOfItems
                        else
                            interval = globals.timeSelectionLength -- Fallback
                        end
                    end
                end
                
                -- Calculate position for the new item
                local position
                if effectiveParams.intervalMode == 0 and interval < 0 then
                    -- Negative spacing creates overlap with the last item (only applicable in Absolute mode)
                    local maxDrift = math.abs(interval) * (effectiveParams.triggerDrift / 100)
                    local drift = Utils.randomInRange(-maxDrift/2, maxDrift/2)
                    position = lastItemEnd + interval + drift
                else
                    -- Regular spacing from the end of the last item
                    local maxDrift = interval * (effectiveParams.triggerDrift / 100)
                    local drift = Utils.randomInRange(-maxDrift/2, maxDrift/2)
                    position = lastItemEnd + interval + drift
                end
                
                -- Stop if we'd place an item completely past the end time
                if position >= globals.endTime then
                    break
                end
                
                -- Create and configure the new item
                local newItem = reaper.AddMediaItemToTrack(containerGroup)
                local newTake = reaper.AddTakeToMediaItem(newItem)
                
                -- Configure the item
                local PCM_source = reaper.PCM_Source_CreateFromFile(itemData.filePath)
                reaper.SetMediaItemTake_Source(newTake, PCM_source)
                reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", itemData.startOffset)
                reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", position)
                reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemData.length)
                reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", itemData.name, true)
                
                -- Apply randomizations using effective parameters
                if effectiveParams.randomizePitch then
                    local randomPitch = itemData.originalPitch + Utils.randomInRange(effectiveParams.pitchRange.min, effectiveParams.pitchRange.max)
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_PITCH", randomPitch)
                else
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_PITCH", itemData.originalPitch)
                end
                
                if effectiveParams.randomizeVolume then
                    local randomVolume = itemData.originalVolume * 10^(Utils.randomInRange(effectiveParams.volumeRange.min, effectiveParams.volumeRange.max) / 20)
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_VOL", randomVolume)
                else
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_VOL", itemData.originalVolume)
                end
                
                if effectiveParams.randomizePan then
                    local randomPan = itemData.originalPan + Utils.randomInRange(effectiveParams.panRange.min, effectiveParams.panRange.max) / 100
                    randomPan = math.max(-1, math.min(1, randomPan))
                    -- Use envelope instead of directly modifying the property
                    Items.createTakePanEnvelope(newTake, randomPan)
                else
                    -- Even without randomization, create an envelope with the original value
                    Items.createTakePanEnvelope(newTake, itemData.originalPan)
                end
                
                -- Create crossfade if items overlap (negative triggerRate)
                if lastItemRef and position < lastItemEnd then
                    Utils.createCrossfade(lastItemRef, newItem, xfadeshape)
                end
                
                -- Update the last item end position and reference
                lastItemEnd = position + itemData.length
                lastItemRef = newItem
            end
        else
            -- Original random placement (one item per file)
            for _, itemData in ipairs(effectiveParams.items) do
                -- Random position in the time selection
                local position = globals.startTime + math.random() * globals.timeSelectionLength
                
                -- Create a new item from the source file
                local newItem = reaper.AddMediaItemToTrack(containerGroup)
                local newTake = reaper.AddTakeToMediaItem(newItem)
                
                -- Configure the item with saved data
                local PCM_source = reaper.PCM_Source_CreateFromFile(itemData.filePath)
                reaper.SetMediaItemTake_Source(newTake, PCM_source)
                reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", itemData.startOffset)
                reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", position)
                reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemData.length)
                reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", itemData.name, true)
                
                -- Apply randomizations using effective parameters
                if effectiveParams.randomizePitch then
                    local randomPitch = itemData.originalPitch + Utils.randomInRange(effectiveParams.pitchRange.min, effectiveParams.pitchRange.max)
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_PITCH", randomPitch)
                else
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_PITCH", itemData.originalPitch)
                end
                
                if effectiveParams.randomizeVolume then
                    local randomVolume = itemData.originalVolume * 10^(Utils.randomInRange(effectiveParams.volumeRange.min, effectiveParams.volumeRange.max) / 20)
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_VOL", randomVolume)
                else
                    reaper.SetMediaItemTakeInfo_Value(newTake, "D_VOL", itemData.originalVolume)
                end
                
                if effectiveParams.randomizePan then
                    local randomPan = itemData.originalPan + Utils.randomInRange(effectiveParams.panRange.min, effectiveParams.panRange.max) / 100
                    randomPan = math.max(-1, math.min(1, randomPan))
                    -- Use envelope instead of directly modifying the property
                    Items.createTakePanEnvelope(newTake, randomPan)
                else
                    -- Even without randomization, create an envelope with the original value
                    Items.createTakePanEnvelope(newTake, itemData.originalPan)
                end
            end
        end
    end
end

-- Update all functions that call placeItemsForContainer to pass group parameter

-- Function to generate groups and place items
function Generation.generateGroups()
    if not globals.timeSelectionValid then
        reaper.MB("Please create a time selection before generating groups!", "Error", 0)
        return
    end
    
    -- Delete existing groups with the same names
    Generation.deleteExistingGroups()
    
    reaper.Main_OnCommand(40289, 0) -- "Item: Unselect all items"

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    -- Get default crossfade shape from REAPER preferences
    local xfadeshape = reaper.SNM_GetIntConfigVar("defxfadeshape", 0)
    
    for i, group in ipairs(globals.groups) do
        -- Create a parent group
        local parentGroupIdx = reaper.GetNumTracks()
        reaper.InsertTrackAtIndex(parentGroupIdx, true)
        local parentGroup = reaper.GetTrack(0, parentGroupIdx)
        reaper.GetSetMediaTrackInfo_String(parentGroup, "P_NAME", group.name, true)
        
        -- Set the group as parent (folder start)
        reaper.SetMediaTrackInfo_Value(parentGroup, "I_FOLDERDEPTH", 1)
        
        local containerCount = #group.containers
        
        for j, container in ipairs(group.containers) do
            -- Create a group for each container
            local containerGroupIdx = reaper.GetNumTracks()
            reaper.InsertTrackAtIndex(containerGroupIdx, true)
            local containerGroup = reaper.GetTrack(0, containerGroupIdx)
            reaper.GetSetMediaTrackInfo_String(containerGroup, "P_NAME", container.name, true)
            
            -- Set folder state based on position
            local folderState = 0 -- Default: normal group in a folder
            if j == containerCount then
                -- If it's the last container, mark as folder end
                folderState = -1
            end
            reaper.SetMediaTrackInfo_Value(containerGroup, "I_FOLDERDEPTH", folderState)
            
            -- Place items on the timeline according to the chosen mode
            -- Now passing group to enable inheritance
            Generation.placeItemsForContainer(group, container, containerGroup, xfadeshape)
        end
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Generate groups and place items", -1)
end

-- Function to regenerate a single group (updated to pass group parameter)
function Generation.generateSingleGroup(groupIndex)
    if not globals.timeSelectionValid then
        reaper.MB("Please create a time selection before regenerating!", "Error", 0)
        return
    end
    
    local group = globals.groups[groupIndex]
    if not group then return end
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    reaper.Main_OnCommand(40289, 0) -- "Item: Unselect all items"

    -- Get default crossfade shape from REAPER preferences
    local xfadeshape = reaper.SNM_GetIntConfigVar("defxfadeshape", 0)
    
    -- Find the existing group by its name
    local existingGroup, existingGroupIdx = Utils.findGroupByName(group.name)
    
    if existingGroup then
        -- Find all container groups within this folder
        local containerGroups = {}
        local groupCount = reaper.CountTracks(0)
        local folderDepth = 1 -- Start with depth 1 (inside a folder)
        
        for i = existingGroupIdx + 1, groupCount - 1 do
            local childGroup = reaper.GetTrack(0, i)
            local depth = reaper.GetMediaTrackInfo_Value(childGroup, "I_FOLDERDEPTH")
            
            -- Add this group to our container list
            table.insert(containerGroups, childGroup)
            
            -- Update folder depth
            folderDepth = folderDepth + depth
            
            -- If we reach the end of the folder, stop searching
            if folderDepth <= 0 then break end
        end
        
        -- Clear items from all container groups
        for i, containerGroup in ipairs(containerGroups) do
            Utils.clearGroupItems(containerGroup)
        end
        
        -- Regenerate items for each container
        for j, container in ipairs(group.containers) do
            if j <= #containerGroups then
                -- Pass group to enable inheritance
                Generation.placeItemsForContainer(group, container, containerGroups[j], xfadeshape)
            end
        end
    else
        -- Group doesn't exist, create it
        local parentGroupIdx = reaper.GetNumTracks()
        reaper.InsertTrackAtIndex(parentGroupIdx, true)
        local parentGroup = reaper.GetTrack(0, parentGroupIdx)
        reaper.GetSetMediaTrackInfo_String(parentGroup, "P_NAME", group.name, true)
        
        -- Set the group as parent (folder start)
        reaper.SetMediaTrackInfo_Value(parentGroup, "I_FOLDERDEPTH", 1)
        
        local containerCount = #group.containers
        
        for j, container in ipairs(group.containers) do
            -- Create a group for each container
            local containerGroupIdx = reaper.GetNumTracks()
            reaper.InsertTrackAtIndex(containerGroupIdx, true)
            local containerGroup = reaper.GetTrack(0, containerGroupIdx)
            reaper.GetSetMediaTrackInfo_String(containerGroup, "P_NAME", container.name, true)
            
            -- Set folder state based on position
            local folderState = 0 -- Default: normal group in a folder
            if j == containerCount then
                -- If it's the last container, mark as folder end
                folderState = -1
            end
            reaper.SetMediaTrackInfo_Value(containerGroup, "I_FOLDERDEPTH", folderState)
            
            -- Place items on the timeline according to the chosen mode
            -- Pass group to enable inheritance
            Generation.placeItemsForContainer(group, container, containerGroup, xfadeshape)
        end
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Regenerate group '" .. group.name .. "'", -1)
end

-- Function to regenerate a single container (updated to pass group parameter)
function Generation.generateSingleContainer(groupIndex, containerIndex)
  if not globals.timeSelectionValid then
      reaper.MB("Please create a time selection before regenerating!", "Error", 0)
      return
  end
  
  local group = globals.groups[groupIndex]
  local container = group.containers[containerIndex]
  if not group or not container then return end
  
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  
  -- Désélectionner tous les items du projet
  reaper.Main_OnCommand(40289, 0) -- "Item: Unselect all items"
  
  -- Get default crossfade shape from REAPER preferences
  local xfadeshape = reaper.SNM_GetIntConfigVar("defxfadeshape", 0)
  
  -- Find the existing parent group by its name
  local parentGroup, parentGroupIdx = Utils.findGroupByName(group.name)
  
  if parentGroup then
      -- Find the specific container group within the parent
      local containerGroup, containerGroupIdx = Utils.findContainerGroup(parentGroupIdx, container.name)
      
      if containerGroup then
          -- Clear items from this container group
          Utils.clearGroupItems(containerGroup)
          
          -- Regenerate items for this container only
          Generation.placeItemsForContainer(group, container, containerGroup, xfadeshape)
      else
          reaper.MB("Container '" .. container.name .. "' not found in group '" .. group.name .. "'", "Error", 0)
      end
  else
      reaper.MB("Group '" .. group.name .. "' not found", "Error", 0)
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Regenerate container '" .. container.name .. "' in group '" .. group.name .. "'", -1)
end

return Generation
