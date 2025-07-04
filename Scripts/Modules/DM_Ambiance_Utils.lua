--[[
@version 1.3
@noindex
--]]

local Utils = {}
local globals = {}

-- Initialize the module with global references from the main script
function Utils.initModule(g)
    globals = g
end

-- Display a help marker "(?)" with a tooltip containing the provided description
function Utils.HelpMarker(desc)
    imgui.SameLine(globals.ctx)
    imgui.TextDisabled(globals.ctx, '(?)')
    if imgui.BeginItemTooltip(globals.ctx) then
        imgui.PushTextWrapPos(globals.ctx, imgui.GetFontSize(globals.ctx) * 35.0)
        imgui.Text(globals.ctx, desc)
        imgui.PopTextWrapPos(globals.ctx)
        imgui.EndTooltip(globals.ctx)
    end
end

-- Search for a track group by its name and return the track and its index if found
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

-- Search for a container group by name within a parent group, considering folder depth
function Utils.findContainerGroup(parentGroupIdx, containerName)
    if not parentGroupIdx or not containerName then
        return nil, nil
    end
    
    local groupCount = reaper.CountTracks(0)
    local folderDepth = 1 -- Start at depth 1 (inside a folder)
    
    -- Trim and normalize the container name for comparison
    local containerNameTrimmed = string.gsub(containerName, "^%s*(.-)%s*$", "%1")
    
    for i = parentGroupIdx + 1, groupCount - 1 do
        local childGroup = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(childGroup, "P_NAME", "", false)
        
        -- Trim whitespace from track name
        local trackNameTrimmed = string.gsub(name, "^%s*(.-)%s*$", "%1")
        
        -- Case-sensitive exact match (more reliable than case-insensitive)
        if trackNameTrimmed == containerNameTrimmed then
            return childGroup, i
        end
        
        -- Update folder depth according to the folder status of this track
        local depth = reaper.GetMediaTrackInfo_Value(childGroup, "I_FOLDERDEPTH")
        folderDepth = folderDepth + depth
        
        -- Stop searching if we exit the parent folder
        if folderDepth <= 0 then
            break
        end
    end
    
    -- Container not found in this group
    return nil, nil
end

-- Remove all media items from a given track group
function Utils.clearGroupItems(group)
    if not group then return false end
    local itemCount = reaper.GetTrackNumMediaItems(group)
    for i = itemCount-1, 0, -1 do
        local item = reaper.GetTrackMediaItem(group, i)
        reaper.DeleteTrackMediaItem(group, item)
    end
    return true
end

-- Helper function to get all containers in a group with their information
function Utils.getAllContainersInGroup(parentGroupIdx)
    if not parentGroupIdx then
        return {}
    end
    
    local containers = {}
    local groupCount = reaper.CountTracks(0)
    local folderDepth = 1  -- We start inside the parent folder
    
    -- Start scanning from the track right after the parent
    for i = parentGroupIdx + 1, groupCount - 1 do
        local track = reaper.GetTrack(0, i)
        if not track then break end
        
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        
        -- Add this track as a container
        table.insert(containers, {
            track = track,
            index = i,
            name = name,
            originalDepth = depth
        })
        
        -- Update folder depth
        folderDepth = folderDepth + depth
        
        -- Stop if we exit the parent folder
        if folderDepth <= 0 then
            break
        end
    end
    
    return containers
end

-- Helper function to fix folder structure for a specific group
function Utils.fixGroupFolderStructure(parentGroupIdx)
    if not parentGroupIdx then
        return false
    end
    
    -- Get fresh container list after any track insertions/deletions
    local containers = Utils.getAllContainersInGroup(parentGroupIdx)
    
    if #containers == 0 then
        return false
    end
    
    -- IMPORTANT: Set proper folder depths with the correct logic
    for i = 1, #containers do
        local container = containers[i]
        if i == #containers then
            -- Last container should end the folder (-1 depth)
            reaper.SetMediaTrackInfo_Value(container.track, "I_FOLDERDEPTH", -1)
        else
            -- All other containers should be normal tracks in folder (0 depth)
            reaper.SetMediaTrackInfo_Value(container.track, "I_FOLDERDEPTH", 0)
        end
    end
    
    -- Ensure the parent group has the correct folder start depth
    local parentTrack = reaper.GetTrack(0, parentGroupIdx)
    if parentTrack then
        reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
    end
    
    return true
end

-- Helper function to validate and repair folder structures if needed
function Utils.validateAndRepairGroupStructure(parentGroupIdx)
    if not parentGroupIdx then
        return false
    end
    
    local containers = Utils.getAllContainersInGroup(parentGroupIdx)
    local needsRepair = false
    
    -- Check if the structure is correct
    for i = 1, #containers do
        local container = containers[i]
        local expectedDepth = (i == #containers) and -1 or 0
        
        if container.originalDepth ~= expectedDepth then
            needsRepair = true
            break
        end
    end
    
    -- Repair if needed
    if needsRepair then
        return Utils.fixGroupFolderStructure(parentGroupIdx)
    end
    
    return true
end

-- Clear items from a group within the time selection, preserving items outside the selection
function Utils.clearGroupItemsInTimeSelection(containerGroup, crossfadeMargin)
    if not globals.timeSelectionValid then
        return
    end
    
    -- Default crossfade margin parameter (in seconds)
    crossfadeMargin = globals.Settings.getSetting("crossfadeMargin") or crossfadeMargin
    
    local itemCount = reaper.CountTrackMediaItems(containerGroup)
    local itemsToProcess = {}
    
    -- Store references to items that will be preserved for crossfades
    globals.crossfadeItems = globals.crossfadeItems or {}
    globals.crossfadeItems[containerGroup] = { startItems = {}, endItems = {} }
    
    -- Collect all items that need processing
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(containerGroup, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEnd = itemStart + itemLength
        
        -- Check intersection with time selection
        if itemEnd > globals.startTime and itemStart < globals.endTime then
            table.insert(itemsToProcess, {
                item = item,
                start = itemStart,
                length = itemLength,
                ending = itemEnd
            })
        end
    end
    
    -- Process items in reverse order to avoid index issues
    for i = #itemsToProcess, 1, -1 do
        local itemData = itemsToProcess[i]
        local item = itemData.item
        local itemStart = itemData.start
        local itemLength = itemData.length
        local itemEnd = itemData.ending
        
        if itemStart >= globals.startTime and itemEnd <= globals.endTime then
            -- Item is completely within time selection - delete it
            reaper.DeleteTrackMediaItem(containerGroup, item)
            
        elseif itemStart < globals.startTime and itemEnd > globals.endTime then
            -- Item spans the entire time selection - split into two parts with overlap
            local splitStart = globals.startTime + crossfadeMargin  -- Cut later
            local splitEnd = globals.endTime - crossfadeMargin      -- Cut earlier
            
            -- Ensure we don't go beyond the original item boundaries
            splitStart = math.max(splitStart, itemStart)
            splitEnd = math.min(splitEnd, itemEnd)
            
            if splitStart < splitEnd then
                local splitItem1 = reaper.SplitMediaItem(item, splitStart)
                if splitItem1 then
                    local splitItem2 = reaper.SplitMediaItem(splitItem1, splitEnd)
                    -- Delete the middle part
                    reaper.DeleteTrackMediaItem(containerGroup, splitItem1)
                    -- Store references for crossfading
                    table.insert(globals.crossfadeItems[containerGroup].startItems, item)
                    if splitItem2 then
                        table.insert(globals.crossfadeItems[containerGroup].endItems, splitItem2)
                    end
                end
            end
            
        elseif itemStart < globals.startTime and itemEnd <= globals.endTime then
            -- Item starts before and ends within selection
            local splitPoint = globals.startTime + crossfadeMargin  -- Cut later
            splitPoint = math.max(splitPoint, itemStart)
            splitPoint = math.min(splitPoint, itemEnd)
            
            if splitPoint > itemStart and splitPoint < itemEnd then
                local splitItem = reaper.SplitMediaItem(item, splitPoint)
                if splitItem then
                    reaper.DeleteTrackMediaItem(containerGroup, splitItem)
                    -- Store reference for crossfading
                    table.insert(globals.crossfadeItems[containerGroup].startItems, item)
                end
            elseif splitPoint >= itemEnd then
                -- If the split point is after the end of the item, delete the entire item
                reaper.DeleteTrackMediaItem(containerGroup, item)
            end
            
        elseif itemStart >= globals.startTime and itemEnd > globals.endTime then
            -- Item starts within and ends after selection
            local splitPoint = globals.endTime - crossfadeMargin  -- Cut earlier
            splitPoint = math.min(splitPoint, itemEnd)
            splitPoint = math.max(splitPoint, itemStart)
            
            if splitPoint < itemEnd and splitPoint > itemStart then
                local splitItem = reaper.SplitMediaItem(item, splitPoint)
                reaper.DeleteTrackMediaItem(containerGroup, item)
                if splitItem then
                    -- Store reference for crossfading
                    table.insert(globals.crossfadeItems[containerGroup].endItems, splitItem)
                end
            elseif splitPoint <= itemStart then
                -- If the split point is before the start of the item, delete the entire item
                reaper.DeleteTrackMediaItem(containerGroup, item)
            end
        end
    end
end

-- Reorganize REAPER tracks after group reordering via drag and drop
function Utils.reorganizeTracksAfterGroupReorder()
    --reaper.ShowConsoleMsg("DEBUG: Starting track reorganization after group reorder\n")
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    -- Get all current tracks with their group associations
    local tracksToStore = {}
    
    -- Map tracks to their groups and store all their data
    for groupIndex, group in ipairs(globals.groups) do
        --reaper.ShowConsoleMsg("DEBUG: Processing group " .. groupIndex .. ": " .. group.name .. "\n")
        
        local groupTrack, groupTrackIdx = Utils.findGroupByName(group.name)
        if groupTrack and groupTrackIdx >= 0 then
            -- Store the parent group track data
            tracksToStore[groupIndex] = {
                groupName = group.name,
                containers = {}
            }
            
            -- Get all container tracks in this group
            local containers = Utils.getAllContainersInGroup(groupTrackIdx)
            for _, container in ipairs(containers) do
                local containerData = {
                    name = container.name,
                    mediaItems = {}
                }
                
                -- Store all media items from this container
                local itemCount = reaper.CountTrackMediaItems(container.track)
                for i = 0, itemCount - 1 do
                    local item = reaper.GetTrackMediaItem(container.track, i)
                    local itemData = {
                        position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
                        length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
                        take = reaper.GetActiveTake(item)
                    }
                    if itemData.take then
                        local source = reaper.GetMediaItemTake_Source(itemData.take)
                        itemData.sourceFile = reaper.GetMediaSourceFileName(source, "")
                        itemData.takeName = reaper.GetTakeName(itemData.take)
                        itemData.startOffset = reaper.GetMediaItemTakeInfo_Value(itemData.take, "D_STARTOFFS")
                        itemData.pitch = reaper.GetMediaItemTakeInfo_Value(itemData.take, "D_PITCH")
                        itemData.volume = reaper.GetMediaItemTakeInfo_Value(itemData.take, "D_VOL")
                        itemData.pan = reaper.GetMediaItemTakeInfo_Value(itemData.take, "D_PAN")
                    end
                    table.insert(containerData.mediaItems, itemData)
                end
                
                table.insert(tracksToStore[groupIndex].containers, containerData)
            end
        end
    end
    
    -- Delete all tracks that belong to our groups
    local tracksToDelete = {}
    for groupIndex, group in ipairs(globals.groups) do
        local groupTrack, groupTrackIdx = Utils.findGroupByName(group.name)
        if groupTrack then
            -- Add all tracks in this group to deletion list
            table.insert(tracksToDelete, groupTrack)
            local containers = Utils.getAllContainersInGroup(groupTrackIdx)
            for _, container in ipairs(containers) do
                table.insert(tracksToDelete, container.track)
            end
        end
    end
    
    -- Delete tracks in reverse order to maintain indices
    table.sort(tracksToDelete, function(a, b)
        local indexA = reaper.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER") - 1
        local indexB = reaper.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER") - 1
        return indexA > indexB
    end)
    
    for _, track in ipairs(tracksToDelete) do
        reaper.DeleteTrack(track)
    end
    
    -- Recreate tracks in the new order
    for groupIndex, group in ipairs(globals.groups) do
        local storedData = tracksToStore[groupIndex]
        if storedData then
            -- Create parent group track
            local parentGroupIdx = reaper.GetNumTracks()
            reaper.InsertTrackAtIndex(parentGroupIdx, true)
            local parentGroup = reaper.GetTrack(0, parentGroupIdx)
            reaper.GetSetMediaTrackInfo_String(parentGroup, "P_NAME", group.name, true)
            reaper.SetMediaTrackInfo_Value(parentGroup, "I_FOLDERDEPTH", 1)
            
            -- Create container tracks
            local containerCount = #group.containers
            for j, container in ipairs(group.containers) do
                local containerGroupIdx = reaper.GetNumTracks()
                reaper.InsertTrackAtIndex(containerGroupIdx, true)
                local containerGroup = reaper.GetTrack(0, containerGroupIdx)
                reaper.GetSetMediaTrackInfo_String(containerGroup, "P_NAME", container.name, true)
                
                -- Set folder state based on position
                local folderState = 0 -- Default: normal track in a folder
                if j == containerCount then
                    -- If it's the last container, mark as folder end
                    folderState = -1
                end
                reaper.SetMediaTrackInfo_Value(containerGroup, "I_FOLDERDEPTH", folderState)
                
                -- Restore media items if we have stored data for this container
                if storedData.containers[j] then
                    local containerData = storedData.containers[j]
                    for _, itemData in ipairs(containerData.mediaItems) do
                        if itemData.sourceFile and itemData.sourceFile ~= "" then
                            local newItem = reaper.AddMediaItemToTrack(containerGroup)
                            local newTake = reaper.AddTakeToMediaItem(newItem)
                            
                            local pcmSource = reaper.PCM_Source_CreateFromFile(itemData.sourceFile)
                            reaper.SetMediaItemTake_Source(newTake, pcmSource)
                            
                            reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", itemData.position)
                            reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemData.length)
                            reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", itemData.takeName, true)
                            reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", itemData.startOffset)
                            reaper.SetMediaItemTakeInfo_Value(newTake, "D_PITCH", itemData.pitch)
                            reaper.SetMediaItemTakeInfo_Value(newTake, "D_VOL", itemData.volume)
                            reaper.SetMediaItemTakeInfo_Value(newTake, "D_PAN", itemData.pan)
                        end
                    end
                end
            end
        end
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Reorganize groups after drag and drop", -1)
    
    --reaper.ShowConsoleMsg("DEBUG: Track reorganization completed\n")
end

-- Reorganize REAPER tracks after moving a container between groups
function Utils.reorganizeTracksAfterContainerMove(sourceGroupIndex, targetGroupIndex, containerName)
    --reaper.ShowConsoleMsg("DEBUG: Starting track reorganization after container move\n")
    
    -- If moving within the same group, no track reorganization needed
    if sourceGroupIndex == targetGroupIndex then
        --reaper.ShowConsoleMsg("DEBUG: Same group move, no track reorganization needed\n")
        return
    end
    
    -- For moves between different groups, we need to rebuild the entire track structure
    -- to maintain proper folder hierarchy. Use the same approach as group reordering.
    Utils.reorganizeTracksAfterGroupReorder()
    
    --reaper.ShowConsoleMsg("DEBUG: Track reorganization after container move completed\n")
end

-- Open the preset folder in the system file explorer
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

-- Open any folder in the system file explorer
function Utils.openFolder(path)
    if not path or path == "" then
        return
    end
    local OS = reaper.GetOS()
    local command
    if OS:match("^Win") then
        command = 'explorer "'
    elseif OS:match("^macOS") or OS:match("^OSX") then
        command = 'open "'
    else -- Linux
        command = 'xdg-open "'
    end
    os.execute(command .. path .. '"')
end

-- Open a popup safely (prevents multiple flashes or duplicate popups)
function Utils.safeOpenPopup(popupName)
    -- Initialize activePopups if it doesn't exist
    if not globals.activePopups then
        globals.activePopups = {}
    end
    
    -- Only open if not already active and if we're in a valid ImGui context
    if not globals.activePopups[popupName] then
        local success = pcall(function()
            imgui.OpenPopup(globals.ctx, popupName)
        end)
        
        if success then
            globals.activePopups[popupName] = { 
                active = true, 
                timeOpened = reaper.time_precise() 
            }
        end
    end
end

-- Close a popup safely and remove it from the active popups list
function Utils.safeClosePopup(popupName)
    -- Use pcall to prevent crashes
    pcall(function()
        imgui.CloseCurrentPopup(globals.ctx)
    end)
    
    -- Clean up the popup tracking
    if globals.activePopups then
        globals.activePopups[popupName] = nil
    end
end

-- Check if the media directory is configured and accessible in the settings
function Utils.isMediaDirectoryConfigured()
    -- Ensure the Settings module is properly initialized
    if not globals.Settings then
        return false
    end
    
    local mediaDir = globals.Settings.getSetting("mediaItemDirectory")
    return mediaDir ~= nil and mediaDir ~= "" and globals.Settings.directoryExists(mediaDir)
end

-- Display a warning popup if the media directory is not configured
function Utils.showDirectoryWarningPopup(popupTitle)
    local ctx = globals.ctx
    local imgui = globals.imgui
    local title = popupTitle or "Warning: Media Directory Not Configured"
    
    -- Use safe popup management to avoid flashing issues
    Utils.safeOpenPopup(title)
    
    -- Use pcall to protect against errors in popup rendering
    local success = pcall(function()
        if imgui.BeginPopupModal(ctx, title, nil, imgui.WindowFlags_AlwaysAutoResize) then
            imgui.TextColored(ctx, 0xFF8000FF, "No media directory has been configured in the settings.")
            imgui.TextWrapped(ctx, "You need to configure a media directory before saving presets to ensure proper media file management.")
            
            imgui.Separator(ctx)
            
            if imgui.Button(ctx, "Configure Now", 150, 0) then
                -- Open the settings window
                globals.showSettingsWindow = true
                Utils.safeClosePopup(title)
                globals.showMediaDirWarning = false  -- Reset the state
            end
            
            imgui.SameLine(ctx)
            
            if imgui.Button(ctx, "Cancel", 120, 0) then
                Utils.safeClosePopup(title)
                globals.showMediaDirWarning = false  -- Reset the state
            end
            
            imgui.EndPopup(ctx)
        end
    end)
    
    -- If popup rendering fails, reset the warning flag
    if not success then
        globals.showMediaDirWarning = false
        if globals.activePopups then
            globals.activePopups[title] = nil
        end
    end
end

-- Check if a time selection exists in the project and update globals accordingly
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

-- Generate a random value between min and max
function Utils.randomInRange(min, max)
    return min + math.random() * (max - min)
end

-- Format a time value in seconds as HH:MM:SS
function Utils.formatTime(seconds)
    seconds = tonumber(seconds) or 0
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Create crossfades between two overlapping media items with the given fade shape
function Utils.createCrossfade(item1, item2, fadeShape)
    local item1End = reaper.GetMediaItemInfo_Value(item1, "D_POSITION") + reaper.GetMediaItemInfo_Value(item1, "D_LENGTH")
    local item2Start = reaper.GetMediaItemInfo_Value(item2, "D_POSITION")
    if item2Start < item1End then
        local overlapLength = item1End - item2Start
        -- Set fade out for the first item
        reaper.SetMediaItemInfo_Value(item1, "D_FADEOUTLEN", overlapLength)
        reaper.SetMediaItemInfo_Value(item1, "C_FADEOUTSHAPE", fadeShape)
        -- Set fade in for the second item
        reaper.SetMediaItemInfo_Value(item2, "D_FADEINLEN", overlapLength)
        reaper.SetMediaItemInfo_Value(item2, "C_FADEINSHAPE", fadeShape)
        return true
    end
    return false
end

-- Unpacks a 32-bit color into individual RGBA components (0-1)
function Utils.unpackColor(color)
    -- Convert string to number if necessary
    if type(color) == "string" then
        color = tonumber(color)
    end
    
    -- Check that the color is a number
    if type(color) ~= "number" then
        -- Default value in case of error (opaque white)
        return 1, 1, 1, 1
    end
    
    local r = ((color >> 24) & 0xFF) / 255
    local g = ((color >> 16) & 0xFF) / 255
    local b = ((color >> 8) & 0xFF) / 255
    local a = (color & 0xFF) / 255
    
    return r, g, b, a
end

-- Packs RGBA components (0-1) into a 32-bit color
function Utils.packColor(r, g, b, a)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    a = math.floor((a or 1) * 255)
    
    return (r << 24) | (g << 16) | (b << 8) | a
end

-- Utility function to brighten or darken a color
function Utils.brightenColor(color, amount)
    local r, g, b, a = Utils.unpackColor(color)
    
    r = math.max(0, math.min(1, r + amount))
    g = math.max(0, math.min(1, g + amount))
    b = math.max(0, math.min(1, b + amount))
    
    return Utils.packColor(r, g, b, a)
end

return Utils