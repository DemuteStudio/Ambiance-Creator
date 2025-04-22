-- DM_Ambiance_Generation.lua (modifié)
local Generation = {}

local globals = {}

local Utils = require("DM_Ambiance_Utils")
local Items = require("DM_Ambiance_Items")

function Generation.initModule(g)
    globals = g
end

-- Function to delete existing tracks with same names before generating
function Generation.deleteExistingTracks()
  -- Create a map of track names we're about to create
  local trackNames = {}
  for _, track in ipairs(globals.tracks) do
      trackNames[track.name] = true
  end
  
  -- Find all tracks with matching names and their children
  local tracksToDelete = {}
  local trackCount = reaper.CountTracks(0)
  local i = 0
  while i < trackCount do
      local track = reaper.GetTrack(0, i)
      local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      if trackNames[name] then
          -- Check if this is a folder track
          local depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
          -- Add this track to the delete list
          table.insert(tracksToDelete, track)
          -- If this is a folder track, also find all its children
          if depth == 1 then
              local j = i + 1
              local folderDepth = 1 -- Start with depth 1 (we're inside one folder)
              while j < trackCount and folderDepth > 0 do
                  local childTrack = reaper.GetTrack(0, j)
                  table.insert(tracksToDelete, childTrack)
                  -- Update folder depth based on this track's folder status
                  local childDepth = reaper.GetMediaTrackInfo_Value(childTrack, "I_FOLDERDEPTH")
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
  for i = #tracksToDelete, 1, -1 do
      reaper.DeleteTrack(tracksToDelete[i])
  end
end


-- Function to place items for a container with inheritance support
function Generation.placeItemsForContainer(track, container, containerTrack, xfadeshape)
    -- Get effective parameters considering inheritance from parent track
    local effectiveParams = globals.Structures.getEffectiveContainerParams(track, container)
    
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
                local newItem = reaper.AddMediaItemToTrack(containerTrack)
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
                local newItem = reaper.AddMediaItemToTrack(containerTrack)
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

-- Update all functions that call placeItemsForContainer to pass track parameter

-- Function to generate tracks and place items
function Generation.generateTracks()
    if not globals.timeSelectionValid then
        reaper.MB("Please create a time selection before generating tracks!", "Error", 0)
        return
    end
    
    -- Delete existing tracks with the same names
    Generation.deleteExistingTracks()
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    -- Get default crossfade shape from REAPER preferences
    local xfadeshape = reaper.SNM_GetIntConfigVar("defxfadeshape", 0)
    
    for i, track in ipairs(globals.tracks) do
        -- Create a parent track
        local parentTrackIdx = reaper.GetNumTracks()
        reaper.InsertTrackAtIndex(parentTrackIdx, true)
        local parentTrack = reaper.GetTrack(0, parentTrackIdx)
        reaper.GetSetMediaTrackInfo_String(parentTrack, "P_NAME", track.name, true)
        
        -- Set the track as parent (folder start)
        reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
        
        local containerCount = #track.containers
        
        for j, container in ipairs(track.containers) do
            -- Create a track for each container
            local containerTrackIdx = reaper.GetNumTracks()
            reaper.InsertTrackAtIndex(containerTrackIdx, true)
            local containerTrack = reaper.GetTrack(0, containerTrackIdx)
            reaper.GetSetMediaTrackInfo_String(containerTrack, "P_NAME", container.name, true)
            
            -- Set folder state based on position
            local folderState = 0 -- Default: normal track in a folder
            if j == containerCount then
                -- If it's the last container, mark as folder end
                folderState = -1
            end
            reaper.SetMediaTrackInfo_Value(containerTrack, "I_FOLDERDEPTH", folderState)
            
            -- Place items on the timeline according to the chosen mode
            -- Now passing track to enable inheritance
            Generation.placeItemsForContainer(track, container, containerTrack, xfadeshape)
        end
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Generate tracks and place items", -1)
end

-- Function to regenerate a single track (updated to pass track parameter)
function Generation.generateSingleTrack(trackIndex)
    if not globals.timeSelectionValid then
        reaper.MB("Please create a time selection before regenerating!", "Error", 0)
        return
    end
    
    local track = globals.tracks[trackIndex]
    if not track then return end
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    -- Get default crossfade shape from REAPER preferences
    local xfadeshape = reaper.SNM_GetIntConfigVar("defxfadeshape", 0)
    
    -- Find the existing track by its name
    local existingTrack, existingTrackIdx = Utils.findTrackByName(track.name)
    
    if existingTrack then
        -- Find all container tracks within this folder
        local containerTracks = {}
        local trackCount = reaper.CountTracks(0)
        local folderDepth = 1 -- Start with depth 1 (inside a folder)
        
        for i = existingTrackIdx + 1, trackCount - 1 do
            local childTrack = reaper.GetTrack(0, i)
            local depth = reaper.GetMediaTrackInfo_Value(childTrack, "I_FOLDERDEPTH")
            
            -- Add this track to our container list
            table.insert(containerTracks, childTrack)
            
            -- Update folder depth
            folderDepth = folderDepth + depth
            
            -- If we reach the end of the folder, stop searching
            if folderDepth <= 0 then break end
        end
        
        -- Clear items from all container tracks
        for i, containerTrack in ipairs(containerTracks) do
            Utils.clearTrackItems(containerTrack)
        end
        
        -- Regenerate items for each container
        for j, container in ipairs(track.containers) do
            if j <= #containerTracks then
                -- Pass track to enable inheritance
                Generation.placeItemsForContainer(track, container, containerTracks[j], xfadeshape)
            end
        end
    else
        -- Track doesn't exist, create it
        local parentTrackIdx = reaper.GetNumTracks()
        reaper.InsertTrackAtIndex(parentTrackIdx, true)
        local parentTrack = reaper.GetTrack(0, parentTrackIdx)
        reaper.GetSetMediaTrackInfo_String(parentTrack, "P_NAME", track.name, true)
        
        -- Set the track as parent (folder start)
        reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
        
        local containerCount = #track.containers
        
        for j, container in ipairs(track.containers) do
            -- Create a track for each container
            local containerTrackIdx = reaper.GetNumTracks()
            reaper.InsertTrackAtIndex(containerTrackIdx, true)
            local containerTrack = reaper.GetTrack(0, containerTrackIdx)
            reaper.GetSetMediaTrackInfo_String(containerTrack, "P_NAME", container.name, true)
            
            -- Set folder state based on position
            local folderState = 0 -- Default: normal track in a folder
            if j == containerCount then
                -- If it's the last container, mark as folder end
                folderState = -1
            end
            reaper.SetMediaTrackInfo_Value(containerTrack, "I_FOLDERDEPTH", folderState)
            
            -- Place items on the timeline according to the chosen mode
            -- Pass track to enable inheritance
            Generation.placeItemsForContainer(track, container, containerTrack, xfadeshape)
        end
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Regenerate track '" .. track.name .. "'", -1)
end

-- Function to regenerate a single container (updated to pass track parameter)
function Generation.generateSingleContainer(trackIndex, containerIndex)
  if not globals.timeSelectionValid then
      reaper.MB("Please create a time selection before regenerating!", "Error", 0)
      return
  end
  
  local track = globals.tracks[trackIndex]
  local container = track.containers[containerIndex]
  if not track or not container then return end
  
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  
  -- Get default crossfade shape from REAPER preferences
  local xfadeshape = reaper.SNM_GetIntConfigVar("defxfadeshape", 0)
  
  -- Find the existing parent track by its name
  local parentTrack, parentTrackIdx = Utils.findTrackByName(track.name)
  
  if parentTrack then
      -- reaper.ShowConsoleMsg("Regenerating container for track '" .. track.name .. "' (index: " .. parentTrackIdx .. ")\n")
      
      -- Find the specific container track within the parent using the modified function
      local containerTrack, containerTrackIdx = Utils.findContainerTrack(parentTrackIdx, container.name)
      
      if containerTrack then
          -- Clear items from this container track
          Utils.clearTrackItems(containerTrack)
          
          -- Regenerate items for this container only
          Generation.placeItemsForContainer(track, container, containerTrack, xfadeshape)
      else
          -- Try a more exhaustive search if normal search fails
          reaper.ShowConsoleMsg("Container not found with standard method, trying fallback search...\n")
          
          -- Fallback method: search all tracks that might be container children
          local trackCount = reaper.CountTracks(0)
          local folderDepth = 1
          
          for i = parentTrackIdx + 1, trackCount - 1 do
              local childTrack = reaper.GetTrack(0, i)
              local _, name = reaper.GetSetMediaTrackInfo_String(childTrack, "P_NAME", "", false)
              
              -- Very permissive matching (substring)
              if string.find(string.lower(name), string.lower(container.name)) then
                  reaper.ShowConsoleMsg("Found potential match: '" .. name .. "'\n")
                  
                  -- Use this track
                  Utils.clearTrackItems(childTrack)
                  Generation.placeItemsForContainer(track, container, childTrack, xfadeshape)
                  
                  reaper.PreventUIRefresh(-1)
                  reaper.UpdateArrange()
                  reaper.Undo_EndBlock("Regenerate container '" .. container.name .. "' in track '" .. track.name .. "'", -1)
                  return
              end
              
              -- Update folder depth
              local depth = reaper.GetMediaTrackInfo_Value(childTrack, "I_FOLDERDEPTH")
              folderDepth = folderDepth + depth
              if folderDepth <= 0 then break end
          end
          
          -- If we reach here, no matching track was found even with fallback
          reaper.MB("Container '" .. container.name .. "' not found in track '" .. track.name .. "'", "Error", 0)
      end
  else
      reaper.MB("Track '" .. track.name .. "' not found", "Error", 0)
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Regenerate container '" .. container.name .. "' in track '" .. track.name .. "'", -1)
end


return Generation
