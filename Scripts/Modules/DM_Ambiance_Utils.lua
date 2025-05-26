--[[
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
    local groupCount = reaper.CountTracks(0)
    local folderDepth = 1 -- Start at depth 1 (inside a folder)
    
    for i = parentGroupIdx + 1, groupCount - 1 do
        local childGroup = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(childGroup, "P_NAME", "", false)
        
        -- Trim whitespace from both names before comparing
        local containerNameTrimmed = string.gsub(containerName, "^%s*(.-)%s*$", "%1")
        local groupNameTrimmed = string.gsub(name, "^%s*(.-)%s*$", "%1")
        
        -- Case-insensitive comparison
        if string.lower(groupNameTrimmed) == string.lower(containerNameTrimmed) then
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
    
    -- Not found - no error message, just return nil
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

function Utils.clearGroupItemsInTimeSelection(containerGroup, crossfadeMargin)
    if not globals.timeSelectionValid then
        return
    end
    
    -- Paramètre par défaut pour la marge de crossfade (en secondes)
    crossfadeMargin = globals.Settings.getSetting("crossfadeMargin") or crossfadeMargin
    
    local itemCount = reaper.CountTrackMediaItems(containerGroup)
    local itemsToProcess = {}
    
    -- Stocker les références aux items qui vont être préservés pour les crossfades
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
            local splitStart = globals.startTime + crossfadeMargin  -- Couper plus tard
            local splitEnd = globals.endTime - crossfadeMargin      -- Couper plus tôt
            
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
            local splitPoint = globals.startTime + crossfadeMargin  -- Couper plus tard
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
                -- Si le split point est après la fin de l'item, supprimer tout l'item
                reaper.DeleteTrackMediaItem(containerGroup, item)
            end
            
        elseif itemStart >= globals.startTime and itemEnd > globals.endTime then
            -- Item starts within and ends after selection
            local splitPoint = globals.endTime - crossfadeMargin  -- Couper plus tôt
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
                -- Si le split point est avant le début de l'item, supprimer tout l'item
                reaper.DeleteTrackMediaItem(containerGroup, item)
            end
        end
    end
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
    if not globals.activePopups[popupName] then
        imgui.OpenPopup(globals.ctx, popupName)
        globals.activePopups[popupName] = { active = true, timeOpened = reaper.time_precise() }
    end
end

-- Close a popup safely and remove it from the active popups list
function Utils.safeClosePopup(popupName)
    imgui.CloseCurrentPopup(globals.ctx)
    globals.activePopups[popupName] = nil
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
    -- Conversion de la chaîne en nombre si nécessaire
    if type(color) == "string" then
        color = tonumber(color)
    end
    
    -- Vérification que la couleur est bien un nombre
    if type(color) ~= "number" then
        -- Valeur par défaut en cas d'erreur (blanc opaque)
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
