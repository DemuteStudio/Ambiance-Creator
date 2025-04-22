--[[
Sound Randomizer for REAPER - UI Groups Module
This module handles group display and management UI components
]]

local UI_Groups = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_Groups.initModule(g)
    globals = g
end

-- Function to display group preset controls for a specific group
function UI_Groups.drawGroupPresetControls(i)
    local groupId = "group" .. i
    
    -- Initialize selected preset index if needed
    if not globals.selectedGroupPresetIndex[i] then
        globals.selectedGroupPresetIndex[i] = -1
    end
    
    -- Get group presets
    local groupPresetList = globals.Presets.listPresets("Groups")
    
    -- Prepare items for the preset dropdown
    local groupPresetItems = ""
    for _, name in ipairs(groupPresetList) do
        groupPresetItems = groupPresetItems .. name .. "\0"
    end
    groupPresetItems = groupPresetItems .. "\0"
    
    -- Group preset dropdown
    imgui.PushItemWidth(globals.ctx, 200)
    local rv, newSelectedGroupIndex = imgui.Combo(globals.ctx, "##GroupPresetSelector" .. groupId,
        globals.selectedGroupPresetIndex[i], groupPresetItems)
    if rv then
        globals.selectedGroupPresetIndex[i] = newSelectedGroupIndex
    end
    
    -- Load preset button
    imgui.SameLine(globals.ctx)
    if imgui.Button(globals.ctx, "Load Group##" .. groupId) and
        globals.selectedGroupPresetIndex[i] >= 0 and
        globals.selectedGroupPresetIndex[i] < #groupPresetList then
        local presetName = groupPresetList[globals.selectedGroupPresetIndex[i] + 1]
        globals.Presets.loadGroupPreset(presetName, i)
    end
    
    -- Save preset button
    imgui.SameLine(globals.ctx)
    if imgui.Button(globals.ctx, "Save Group##" .. groupId) then
        globals.newGroupPresetName = globals.groups[i].name
        globals.currentSaveGroupIndex = i
        globals.Utils.safeOpenPopup("Save Group Preset##" .. groupId)
    end
    
    -- Group save dialog popup
    if imgui.BeginPopupModal(globals.ctx, "Save Group Preset##" .. groupId, nil, imgui.WindowFlags_AlwaysAutoResize) then
        imgui.Text(globals.ctx, "Group preset name:")
        local rv, value = imgui.InputText(globals.ctx, "##GroupPresetName" .. groupId, globals.newGroupPresetName)
        if rv then globals.newGroupPresetName = value end
        if imgui.Button(globals.ctx, "Save", 120, 0) and globals.newGroupPresetName ~= "" then
            if globals.Presets.saveGroupPreset(globals.newGroupPresetName, globals.currentSaveGroupIndex) then
                globals.Utils.safeClosePopup("Save Group Preset##" .. groupId)
            end
        end
        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Cancel", 120, 0) then
            globals.Utils.safeClosePopup("Save Group Preset##" .. groupId)
        end
        imgui.EndPopup(globals.ctx)
    end
end

-- Function to draw the left panel containing groups list
function UI_Groups.drawGroupsPanel(width, isContainerSelected, toggleContainerSelection, clearContainerSelections, selectContainerRange)
    -- Title for the left panel
    imgui.Text(globals.ctx, "Groups & Containers")
    
    -- Multi-selection mode toggle and info
    local selectedCount = UI_Groups.getSelectedContainersCount()
    if selectedCount > 1 then
        imgui.SameLine(globals.ctx)
        imgui.TextColored(globals.ctx, 0xFF4CAF50, "(" .. selectedCount .. " selected)")
        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Clear Selection") then
            clearContainerSelections()
        end
    end
    
    -- Button to add a new group
    if imgui.Button(globals.ctx, "Add Group") then
        table.insert(globals.groups, globals.Structures.createGroup())
    end
    
    imgui.Separator(globals.ctx)
    
    -- Check if Ctrl key is pressed for multi-selection mode
    local ctrlPressed = imgui.GetKeyMods(globals.ctx) & imgui.Mod_Ctrl ~= 0
    
    -- Variable to group which group to delete (if any)
    local groupToDelete = nil
    
    -- Loop through all groups
    for i, group in ipairs(globals.groups) do
        local groupId = "group" .. i
        
        -- TreeNode flags - include selection flags if needed
        local groupFlags = group.expanded and imgui.TreeNodeFlags_DefaultOpen or 0
        groupFlags = groupFlags + imgui.TreeNodeFlags_OpenOnArrow

        -- Add specific flags to indicate selection
        if globals.selectedGroupIndex == i and globals.selectedContainerIndex == nil then
            groupFlags = groupFlags + imgui.TreeNodeFlags_Selected
        end
        
        -- Create tree node for the group
        local groupOpen = imgui.TreeNodeEx(globals.ctx, groupId, group.name, groupFlags)

        -- Update the expanded state in our data structure
        group.expanded = groupOpen
        
        -- Handle selection on click
        if imgui.IsItemClicked(globals.ctx) then
            globals.selectedGroupIndex = i
            globals.selectedContainerIndex = nil
            
            -- Clear multi-selection if not holding Ctrl
            if not ctrlPressed then
                clearContainerSelections()
            end
        end
        
        -- Delete group button
        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Delete##" .. groupId) then
            groupToDelete = i
        end
        
        -- Regenerate group button
        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Regenerate##" .. groupId) then
            globals.Generation.generateSingleGroup(i)
        end
        
        -- If the group node is open, display its contents
        if groupOpen then
            -- Group name input field
            local groupName = group.name
            imgui.PushItemWidth(globals.ctx, width * 0.8)
            local rv, newGroupName = imgui.InputText(globals.ctx, "Name##" .. groupId, groupName)
            if rv then group.name = newGroupName end
            
            -- Group preset controls
            UI_Groups.drawGroupPresetControls(i)
            
            -- Button to add a container to this group
            if imgui.Button(globals.ctx, "Add Container##" .. groupId) then
                table.insert(group.containers, globals.Structures.createContainer())
            end
            
            -- Variable to group which container to delete (if any)
            local containerToDelete = nil
            
            -- Loop through all containers in this group
            for j, container in ipairs(group.containers) do
                local containerId = groupId .. "_container" .. j
                
                -- TreeNode flags - leaf nodes for containers with selection support
                local containerFlags = imgui.TreeNodeFlags_Leaf + imgui.TreeNodeFlags_NoTreePushOnOpen
                
                -- Add specific flags to indicate selection
                if isContainerSelected(i, j) then
                    containerFlags = containerFlags + imgui.TreeNodeFlags_Selected
                end
                
                -- Indent container items for better visual hierarchy
                imgui.Indent(globals.ctx, 20)
                imgui.TreeNodeEx(globals.ctx, containerId, container.name, containerFlags)
                
                -- Handle selection on click with multi-selection support
                if imgui.IsItemClicked(globals.ctx) then
                    -- Check if Shift is pressed for range selection
                    local shiftPressed = imgui.GetKeyMods(globals.ctx) & imgui.Mod_Shift ~= 0
                    
                    -- If Ctrl is pressed, toggle this container in multi-selection
                    if ctrlPressed then
                        toggleContainerSelection(i, j)
                        globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
                        
                        -- Update anchor point for Shift+Click
                        globals.shiftAnchorGroupIndex = i
                        globals.shiftAnchorContainerIndex = j
                        
                    -- If Shift is pressed, select range from last anchor to this container
                    elseif shiftPressed and globals.shiftAnchorGroupIndex then
                        selectContainerRange(globals.shiftAnchorGroupIndex, globals.shiftAnchorContainerIndex, i, j)
                    else
                        -- Otherwise, select only this container and update anchor
                        clearContainerSelections()
                        toggleContainerSelection(i, j)
                        globals.inMultiSelectMode = false
                        
                        -- Set new anchor point for Shift+Click
                        globals.shiftAnchorGroupIndex = i
                        globals.shiftAnchorContainerIndex = j
                    end
                end
                
                -- Delete container button
                imgui.SameLine(globals.ctx)
                if imgui.Button(globals.ctx, "Delete##" .. containerId) then
                    containerToDelete = j
                end
                
                -- Regenerate container button
                imgui.SameLine(globals.ctx)
                if imgui.Button(globals.ctx, "Regenerate##" .. containerId) then
                    globals.Generation.generateSingleContainer(i, j)
                end
                
                imgui.Unindent(globals.ctx, 20)
            end
            
            -- Delete the marked container if any
            if containerToDelete then
                -- Remove from selected containers if it was selected
                globals.selectedContainers[i .. "_" .. containerToDelete] = nil
                table.remove(group.containers, containerToDelete)
                
                -- Update primary selection if necessary
                if globals.selectedGroupIndex == i and globals.selectedContainerIndex == containerToDelete then
                    globals.selectedContainerIndex = nil
                elseif globals.selectedGroupIndex == i and globals.selectedContainerIndex > containerToDelete then
                    globals.selectedContainerIndex = globals.selectedContainerIndex - 1
                end
                
                -- Update multi-selection references for containers after the deleted one
                for k = containerToDelete + 1, #group.containers + 1 do -- +1 because we just deleted one
                    if globals.selectedContainers[i .. "_" .. k] then
                        globals.selectedContainers[i .. "_" .. (k-1)] = true
                        globals.selectedContainers[i .. "_" .. k] = nil
                    end
                end
            end
            
            imgui.TreePop(globals.ctx)
        end
    end
    
    -- Delete the marked group if any
    if groupToDelete then
        -- Remove any selected containers from this group
        for key in pairs(globals.selectedContainers) do
            local t, c = key:match("(%d+)_(%d+)")
            if tonumber(t) == groupToDelete then
                globals.selectedContainers[key] = nil
            end
        end
        
        table.remove(globals.groups, groupToDelete)
        
        -- Update primary selection if necessary
        if globals.selectedGroupIndex == groupToDelete then
            globals.selectedGroupIndex = nil
            globals.selectedContainerIndex = nil
        elseif globals.selectedGroupIndex and globals.selectedGroupIndex > groupToDelete then
            globals.selectedGroupIndex = globals.selectedGroupIndex - 1
        end
        
        -- Update multi-selection references for groups after the deleted one
        for key in pairs(globals.selectedContainers) do
            local t, c = key:match("(%d+)_(%d+)")
            if tonumber(t) > groupToDelete then
                globals.selectedContainers[(tonumber(t)-1) .. "_" .. c] = true
                globals.selectedContainers[key] = nil
            end
        end
    end
    
    -- Update the multi-select mode flag
    globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
end

-- Get count of selected containers
function UI_Groups.getSelectedContainersCount()
    local count = 0
    for _ in pairs(globals.selectedContainers) do
        count = count + 1
    end
    return count
end

return UI_Groups
