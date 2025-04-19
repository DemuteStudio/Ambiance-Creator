--[[
Sound Randomizer for REAPER - UI Tracks Module
This module handles track display and management UI components
]]

local UI_Tracks = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_Tracks.initModule(g)
    globals = g
end

-- Function to display track preset controls for a specific track
function UI_Tracks.drawTrackPresetControls(i)
    local trackId = "track" .. i
    
    -- Initialize selected preset index if needed
    if not globals.selectedTrackPresetIndex[i] then
        globals.selectedTrackPresetIndex[i] = -1
    end
    
    -- Get track presets
    local trackPresetList = globals.Presets.listPresets("Tracks")
    
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
        globals.Presets.loadTrackPreset(presetName, i)
    end
    
    -- Save preset button
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Save Track##" .. trackId) then
        globals.newTrackPresetName = globals.tracks[i].name
        globals.currentSaveTrackIndex = i
        globals.Utils.safeOpenPopup("Save Track Preset##" .. trackId)
    end
    
    -- Track save dialog popup
    if reaper.ImGui_BeginPopupModal(globals.ctx, "Save Track Preset##" .. trackId, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(globals.ctx, "Track preset name:")
        local rv, value = reaper.ImGui_InputText(globals.ctx, "##TrackPresetName" .. trackId, globals.newTrackPresetName)
        if rv then globals.newTrackPresetName = value end
        if reaper.ImGui_Button(globals.ctx, "Save", 120, 0) and globals.newTrackPresetName ~= "" then
            if globals.Presets.saveTrackPreset(globals.newTrackPresetName, globals.currentSaveTrackIndex) then
                globals.Utils.safeClosePopup("Save Track Preset##" .. trackId)
            end
        end
        reaper.ImGui_SameLine(globals.ctx)
        if reaper.ImGui_Button(globals.ctx, "Cancel", 120, 0) then
            globals.Utils.safeClosePopup("Save Track Preset##" .. trackId)
        end
        reaper.ImGui_EndPopup(globals.ctx)
    end
end

-- Function to draw the left panel containing tracks list
function UI_Tracks.drawTracksPanel(width, isContainerSelected, toggleContainerSelection, clearContainerSelections, selectContainerRange)
    -- Title for the left panel
    reaper.ImGui_Text(globals.ctx, "Tracks & Containers")
    
    -- Multi-selection mode toggle and info
    local selectedCount = UI_Tracks.getSelectedContainersCount()
    if selectedCount > 1 then
        reaper.ImGui_SameLine(globals.ctx)
        reaper.ImGui_TextColored(globals.ctx, 0xFF4CAF50, "(" .. selectedCount .. " selected)")
        reaper.ImGui_SameLine(globals.ctx)
        if reaper.ImGui_Button(globals.ctx, "Clear Selection") then
            clearContainerSelections()
        end
    end
    
    -- Button to add a new track
    if reaper.ImGui_Button(globals.ctx, "Add Track") then
        table.insert(globals.tracks, globals.Structures.createTrack())
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
            globals.Generation.generateSingleTrack(i)
        end
        
        -- If the track node is open, display its contents
        if trackOpen then
            -- Track name input field
            local trackName = track.name
            reaper.ImGui_PushItemWidth(globals.ctx, width * 0.8)
            local rv, newTrackName = reaper.ImGui_InputText(globals.ctx, "Name##" .. trackId, trackName)
            if rv then track.name = newTrackName end
            
            -- Track preset controls
            UI_Tracks.drawTrackPresetControls(i)
            
            -- Button to add a container to this track
            if reaper.ImGui_Button(globals.ctx, "Add Container##" .. trackId) then
                table.insert(track.containers, globals.Structures.createContainer())
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
                        globals.inMultiSelectMode = UI_Tracks.getSelectedContainersCount() > 1
                        
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
                    globals.Generation.generateSingleContainer(i, j)
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
                for k = containerToDelete + 1, #track.containers + 1 do -- +1 because we just deleted one
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
    globals.inMultiSelectMode = UI_Tracks.getSelectedContainersCount() > 1
end

-- Get count of selected containers
function UI_Tracks.getSelectedContainersCount()
    local count = 0
    for _ in pairs(globals.selectedContainers) do
        count = count + 1
    end
    return count
end

return UI_Tracks
