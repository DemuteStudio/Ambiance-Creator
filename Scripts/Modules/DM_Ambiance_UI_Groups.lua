--[[
@version 1.3
@noindex
--]]

local UI_Groups = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_Groups.initModule(g)
    globals = g
end

-- Display group preset controls (load/save) for a specific group
function UI_Groups.drawGroupPresetControls(i)
    local groupId = "group" .. i

    -- Initialize selected preset index for this group if not already set
    if not globals.selectedGroupPresetIndex[i] then
        globals.selectedGroupPresetIndex[i] = -1
    end

    -- Get the list of available group presets
    local groupPresetList = globals.Presets.listPresets("Groups")

    -- Prepare items for the preset dropdown (ImGui Combo expects a null-separated string)
    local groupPresetItems = ""
    for _, name in ipairs(groupPresetList) do
        groupPresetItems = groupPresetItems .. name .. "\0"
    end
    groupPresetItems = groupPresetItems .. "\0"

    -- Group preset dropdown selector
    imgui.PushItemWidth(globals.ctx, 200)
    local rv, newSelectedGroupIndex = imgui.Combo(
        globals.ctx,
        "##GroupPresetSelector" .. groupId,
        globals.selectedGroupPresetIndex[i],
        groupPresetItems
    )
    if rv then
        globals.selectedGroupPresetIndex[i] = newSelectedGroupIndex
    end

    -- Load preset button
    imgui.SameLine(globals.ctx)
    if imgui.Button(globals.ctx, "Load Group##" .. groupId)
        and globals.selectedGroupPresetIndex[i] >= 0
        and globals.selectedGroupPresetIndex[i] < #groupPresetList then
        local presetName = groupPresetList[globals.selectedGroupPresetIndex[i] + 1]
        globals.Presets.loadGroupPreset(presetName, i)
    end

    -- Save preset button
    imgui.SameLine(globals.ctx)
    if imgui.Button(globals.ctx, "Save Group##" .. groupId) then
        -- Check if a media directory is configured before allowing save
        if not globals.Utils.isMediaDirectoryConfigured() then
            -- Set flag to show the warning popup
            globals.showMediaDirWarning = true
        else
            -- Continue with the normal save popup
            globals.newGroupPresetName = globals.groups[i].name
            globals.currentSaveGroupIndex = i
            globals.Utils.safeOpenPopup("Save Group Preset##" .. groupId)
        end
    end

    -- Popup dialog for saving the group as a preset
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


-- Create a drop zone with insertion line for groups (only during drag)
local function createGroupInsertionLine(insertIndex)
    -- Only show drop zones during an active drag
    if not globals.draggedItem or globals.draggedItem.type ~= "GROUP" then
        return
    end
    
    local dropZoneHeight = 8
    local dropZoneWidth = -1 -- Full width
    
    -- Get button color from settings and create variations
    local buttonColor = globals.Settings.getSetting("buttonColor")
    local backgroundColorTransparent = buttonColor
    local borderColor = globals.Utils.brightenColor(buttonColor, 0.2) -- Brighter border
    local insertionLineColor = globals.Utils.brightenColor(buttonColor, 0.4) -- Even brighter insertion line
    
    -- Create an interactive invisible button for the drop zone
    imgui.InvisibleButton(globals.ctx, "##group_dropzone_" .. insertIndex, dropZoneWidth, dropZoneHeight)
    
    -- Always draw the drop zone outline when visible
    local min_x, min_y = imgui.GetItemRectMin(globals.ctx)
    local max_x, max_y = imgui.GetItemRectMax(globals.ctx)
    local drawList = imgui.GetWindowDrawList(globals.ctx)
    
    -- Draw background and border for the drop zone using button color
    imgui.DrawList_AddRectFilled(drawList, min_x, min_y, max_x, max_y, backgroundColorTransparent)
    imgui.DrawList_AddRect(drawList, min_x, min_y, max_x, max_y, borderColor, 0, 0, 1)
    
    if imgui.BeginDragDropTarget(globals.ctx) then
        -- Draw insertion line when hovering with valid payload
        local lineY = min_y + dropZoneHeight / 2
        -- Draw insertion line using brightened button color
        imgui.DrawList_AddLine(drawList, min_x, lineY, max_x, lineY, insertionLineColor, 4)
        
        -- Accept group drops
        if imgui.AcceptDragDropPayload(globals.ctx, "DND_GROUP") then
            if globals.draggedItem and globals.draggedItem.type == "GROUP" then
                local sourceGroupIndex = globals.draggedItem.index
                if sourceGroupIndex and sourceGroupIndex ~= insertIndex then
                    globals.pendingGroupMove = {
                        sourceIndex = sourceGroupIndex,
                        targetIndex = insertIndex
                    }
                end
            end
        end
        imgui.EndDragDropTarget(globals.ctx)
    end
end

-- Create a drop zone with insertion line for containers (only during drag)
local function createContainerInsertionLine(groupIndex, insertIndex)
    -- Only show drop zones during an active container drag
    if not globals.draggedItem or globals.draggedItem.type ~= "CONTAINER" then
        return
    end
    
    local dropZoneHeight = 6
    local dropZoneWidth = -1 -- Full width
    
    -- Get button color from settings and create variations
    local buttonColor = globals.Settings.getSetting("buttonColor")
    local backgroundColorTransparent = buttonColor
    local borderColor = globals.Utils.brightenColor(buttonColor, 0.1) -- Slightly brighter border
    local insertionLineColor = globals.Utils.brightenColor(buttonColor, 0.3) -- Brighter insertion line
    
    -- Indent to match containers
    imgui.Indent(globals.ctx, 20)
    
    -- Create an interactive invisible button for the drop zone
    imgui.InvisibleButton(globals.ctx, "##container_dropzone_" .. groupIndex .. "_" .. insertIndex, dropZoneWidth, dropZoneHeight)
    
    -- Always draw the drop zone outline when visible
    local min_x, min_y = imgui.GetItemRectMin(globals.ctx)
    local max_x, max_y = imgui.GetItemRectMax(globals.ctx)
    local drawList = imgui.GetWindowDrawList(globals.ctx)
    
    -- Draw background and border for the drop zone using button color
    imgui.DrawList_AddRectFilled(drawList, min_x, min_y, max_x, max_y, backgroundColorTransparent)
    imgui.DrawList_AddRect(drawList, min_x, min_y, max_x, max_y, borderColor, 0, 0, 1)
    
    if imgui.BeginDragDropTarget(globals.ctx) then
        -- Draw insertion line when hovering with valid payload
        local lineY = min_y + dropZoneHeight / 2
        imgui.DrawList_AddLine(drawList, min_x, lineY, max_x, lineY, insertionLineColor, 3)
        
        -- Accept container drops
        if imgui.AcceptDragDropPayload(globals.ctx, "DND_CONTAINER") then
            if globals.draggedItem and globals.draggedItem.type == "CONTAINER" then
                local sourceGroupIndex = globals.draggedItem.groupIndex
                local sourceContainerIndex = globals.draggedItem.containerIndex
                
                if sourceGroupIndex and sourceContainerIndex then
                    if sourceGroupIndex == groupIndex then
                        -- Moving within same group
                        if sourceContainerIndex ~= insertIndex and sourceContainerIndex ~= insertIndex - 1 then
                            globals.pendingContainerReorder = {
                                groupIndex = groupIndex,
                                sourceIndex = sourceContainerIndex,
                                targetIndex = insertIndex
                            }
                        end
                    else
                        -- Moving between groups
                        globals.pendingContainerMove = {
                            sourceGroupIndex = sourceGroupIndex,
                            sourceContainerIndex = sourceContainerIndex,
                            targetGroupIndex = groupIndex,
                            targetContainerIndex = insertIndex
                        }
                    end
                end
            end
        end
        imgui.EndDragDropTarget(globals.ctx)
    end
    
    imgui.Unindent(globals.ctx, 20)
end

-- Create a drop zone on group header for moving containers to the end of the group (only during container drag)
local function createGroupDropZone(groupIndex)
    -- Only show group drop zones during container drag
    if not globals.draggedItem or globals.draggedItem.type ~= "CONTAINER" then
        return
    end
    
    if imgui.BeginDragDropTarget(globals.ctx) then
        -- Get button color from settings and create variations
        local buttonColor = globals.Settings.getSetting("buttonColor")
        local highlightColor = buttonColor
        local borderColor = globals.Utils.brightenColor(buttonColor, 0.3) -- Bright border
        
        -- Highlight the entire group with enhanced visuals using button color
        local min_x, min_y = imgui.GetItemRectMin(globals.ctx)
        local max_x, max_y = imgui.GetItemRectMax(globals.ctx)
        local drawList = imgui.GetWindowDrawList(globals.ctx)
        imgui.DrawList_AddRectFilled(drawList, min_x, min_y, max_x, max_y, highlightColor)
        imgui.DrawList_AddRect(drawList, min_x, min_y, max_x, max_y, borderColor, 0, 0, 2)
        
        -- Accept container drops (add to end of group)
        if imgui.AcceptDragDropPayload(globals.ctx, "DND_CONTAINER") then
            if globals.draggedItem and globals.draggedItem.type == "CONTAINER" then
                local sourceGroupIndex = globals.draggedItem.groupIndex
                local sourceContainerIndex = globals.draggedItem.containerIndex
                
                if sourceGroupIndex and sourceContainerIndex and sourceGroupIndex ~= groupIndex then
                    globals.pendingContainerMove = {
                        sourceGroupIndex = sourceGroupIndex,
                        sourceContainerIndex = sourceContainerIndex,
                        targetGroupIndex = groupIndex,
                        targetContainerIndex = #globals.groups[groupIndex].containers + 1
                    }
                end
            end
        end
        imgui.EndDragDropTarget(globals.ctx)
    end
end

-- Function to reorder groups
function UI_Groups.reorderGroups(sourceIndex, targetIndex)
    if sourceIndex == targetIndex or sourceIndex < 1 or targetIndex < 1 or 
       sourceIndex > #globals.groups or targetIndex > #globals.groups then
        return
    end
    
    local movingGroup = globals.groups[sourceIndex]
    table.remove(globals.groups, sourceIndex)
    
    -- Adjust target index
    local insertIndex = targetIndex
    if sourceIndex < targetIndex then
        insertIndex = targetIndex - 1
    end
    insertIndex = math.max(1, math.min(insertIndex, #globals.groups + 1))
    
    table.insert(globals.groups, insertIndex, movingGroup)
    
    -- Update selections
    if globals.selectedGroupIndex == sourceIndex then
        globals.selectedGroupIndex = insertIndex
    end
    globals.selectedContainers = {}
    globals.inMultiSelectMode = false
    
    globals.Utils.reorganizeTracksAfterGroupReorder()
end

-- Function to move a container between groups
function UI_Groups.moveContainerToGroup(sourceGroupIndex, sourceContainerIndex, targetGroupIndex, targetContainerIndex)
    if sourceGroupIndex < 1 or targetGroupIndex < 1 or
       sourceGroupIndex > #globals.groups or targetGroupIndex > #globals.groups or
       sourceContainerIndex < 1 or sourceContainerIndex > #globals.groups[sourceGroupIndex].containers then
        return
    end
    
    local movingContainer = globals.groups[sourceGroupIndex].containers[sourceContainerIndex]
    table.remove(globals.groups[sourceGroupIndex].containers, sourceContainerIndex)
    
    -- Insert at target position
    local insertIndex = targetContainerIndex or (#globals.groups[targetGroupIndex].containers + 1)
    insertIndex = math.max(1, math.min(insertIndex, #globals.groups[targetGroupIndex].containers + 1))
    table.insert(globals.groups[targetGroupIndex].containers, insertIndex, movingContainer)
    
    -- Update selections
    local key = sourceGroupIndex .. "_" .. sourceContainerIndex
    if globals.selectedContainers[key] then
        globals.selectedContainers[key] = nil
        globals.selectedContainers[targetGroupIndex .. "_" .. insertIndex] = true
    end
    
    if globals.selectedGroupIndex == sourceGroupIndex and globals.selectedContainerIndex == sourceContainerIndex then
        globals.selectedGroupIndex = targetGroupIndex
        globals.selectedContainerIndex = insertIndex
    end
    
    globals.Utils.reorganizeTracksAfterContainerMove(sourceGroupIndex, targetGroupIndex, movingContainer.name)
end

-- Function to reorder containers within the same group
function UI_Groups.reorderContainers(groupIndex, sourceIndex, targetIndex)
    if sourceIndex == targetIndex or sourceIndex < 1 or targetIndex < 1 or
       groupIndex < 1 or groupIndex > #globals.groups or
       sourceIndex > #globals.groups[groupIndex].containers then
        return
    end
    
    local movingContainer = globals.groups[groupIndex].containers[sourceIndex]
    table.remove(globals.groups[groupIndex].containers, sourceIndex)
    
    -- Adjust target index
    local insertIndex = targetIndex
    if sourceIndex < targetIndex then
        insertIndex = targetIndex - 1
    end
    insertIndex = math.max(1, math.min(insertIndex, #globals.groups[groupIndex].containers + 1))
    
    table.insert(globals.groups[groupIndex].containers, insertIndex, movingContainer)
    
    -- Update selections
    local oldKey = groupIndex .. "_" .. sourceIndex
    if globals.selectedContainers[oldKey] then
        globals.selectedContainers[oldKey] = nil
        globals.selectedContainers[groupIndex .. "_" .. insertIndex] = true
    end
    
    if globals.selectedGroupIndex == groupIndex and globals.selectedContainerIndex == sourceIndex then
        globals.selectedContainerIndex = insertIndex
    end
    
    -- No need to reorganize tracks for reordering within same group
end

-- Draw the left panel containing the list of groups and their containers
function UI_Groups.drawGroupsPanel(width, isContainerSelected, toggleContainerSelection, clearContainerSelections, selectContainerRange)
    -- Basic check for minimal window size
    local availableHeight = imgui.GetWindowHeight(globals.ctx)
    local availableWidth = imgui.GetWindowWidth(globals.ctx)
    if availableHeight < 100 or availableWidth < 200 then
        imgui.TextColored(globals.ctx, 0xFF0000FF, "Window too small")
        return
    end

    -- Panel title
    imgui.Text(globals.ctx, "Groups & Containers")

    -- Multi-selection info and clear selection button
    local selectedCount = UI_Groups.getSelectedContainersCount()
    if selectedCount > 1 then
        imgui.SameLine(globals.ctx)
        imgui.TextColored(globals.ctx, 0xFF4CAF50, "(" .. selectedCount .. " selected)")
        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Clear Selection") then
            clearContainerSelections()
        end
    end

    -- Add group button
    if imgui.Button(globals.ctx, "Add Group") then
        table.insert(globals.groups, globals.Structures.createGroup())
        local newGroupIndex = #globals.groups
        globals.selectedGroupIndex = newGroupIndex
        globals.selectedContainerIndex = nil
        clearContainerSelections()
        globals.inMultiSelectMode = false
        globals.shiftAnchorGroupIndex = newGroupIndex
        globals.shiftAnchorContainerIndex = nil
    end
    imgui.Separator(globals.ctx)

    -- Detect if Ctrl is pressed for multi-selection
    local ctrlPressed = imgui.GetKeyMods(globals.ctx) & imgui.Mod_Ctrl ~= 0
    local groupToDelete = nil

    -- Drop zone before first group
    createGroupInsertionLine(1)

    -- Loop through groups
    for i, group in ipairs(globals.groups) do
        local groupId = "group" .. i

        -- TreeNode flags for group selection and expansion
        local groupFlags = group.expanded and imgui.TreeNodeFlags_DefaultOpen or 0
        groupFlags = groupFlags + imgui.TreeNodeFlags_OpenOnArrow + imgui.TreeNodeFlags_SpanTextWidth
        if globals.selectedGroupIndex == i and globals.selectedContainerIndex == nil then
            groupFlags = groupFlags + imgui.TreeNodeFlags_Selected
        end

        -- Create tree node for the group
        local groupOpen = imgui.TreeNodeEx(globals.ctx, groupId, group.name, groupFlags)
        group.expanded = groupOpen

        -- Make group draggable
        if imgui.BeginDragDropSource(globals.ctx) then
            local payloadData = string.format("GROUP:%d", i)
            imgui.SetDragDropPayload(globals.ctx, "DND_GROUP", payloadData)
            imgui.Text(globals.ctx, "📁 " .. group.name)
            
            -- Store drag info in global variable
            globals.draggedItem = {
                type = "GROUP",
                index = i,
                name = group.name
            }
            
            imgui.EndDragDropSource(globals.ctx)
        end

        -- Make group a drop target for containers
        createGroupDropZone(i)

        -- Handle selection on click
        if imgui.IsItemClicked(globals.ctx) then
            globals.selectedGroupIndex = i
            globals.selectedContainerIndex = nil
            if not ctrlPressed then
                clearContainerSelections()
            end
        end

        -- Delete and regenerate buttons
        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Delete##" .. groupId) then
            groupToDelete = i
        end
        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Regenerate##" .. groupId) then
            globals.Generation.generateSingleGroup(i)
        end

        -- If the group is open, display its content
        if groupOpen then
            -- Add container button
            if imgui.Button(globals.ctx, "Add Container##" .. groupId) then
                table.insert(group.containers, globals.Structures.createContainer())
                clearContainerSelections()
                local newContainerIndex = #group.containers
                toggleContainerSelection(i, newContainerIndex)
                globals.selectedGroupIndex = i
                globals.selectedContainerIndex = newContainerIndex
                globals.inMultiSelectMode = false
                globals.shiftAnchorGroupIndex = i
                globals.shiftAnchorContainerIndex = newContainerIndex
            end

            -- Help marker
            imgui.SameLine(globals.ctx)
            globals.Utils.HelpMarker("Drag and drop:\n" ..
                "- Drag groups to reorder them\n" ..
                "- Drag containers to move them within/between groups\n" ..
                "- Drop containers on group headers to add them to the end\n" ..
                "- Use Ctrl+Click and Shift+Click for multi-selection")

            local containerToDelete = nil

            -- Drop zone before first container
            if #group.containers > 0 then
                createContainerInsertionLine(i, 1)
            end

            -- Loop through containers in this group
            for j, container in ipairs(group.containers) do
                local containerId = groupId .. "_container" .. j
                local containerFlags = imgui.TreeNodeFlags_Leaf + imgui.TreeNodeFlags_NoTreePushOnOpen
                containerFlags = containerFlags + imgui.TreeNodeFlags_SpanTextWidth
                if isContainerSelected(i, j) then
                    containerFlags = containerFlags + imgui.TreeNodeFlags_Selected
                end

                -- Indent containers visually
                local startX = imgui.GetCursorPosX(globals.ctx)
                imgui.Indent(globals.ctx, 20)
                local nameWidth = width * 0.45
                imgui.PushItemWidth(globals.ctx, nameWidth)
                imgui.TreeNodeEx(globals.ctx, containerId, container.name, containerFlags)
                imgui.PopItemWidth(globals.ctx)

                -- Make container draggable
                if imgui.BeginDragDropSource(globals.ctx) then
                    local payloadData = string.format("CONTAINER:%d:%d", i, j)
                    imgui.SetDragDropPayload(globals.ctx, "DND_CONTAINER", payloadData)
                    imgui.Text(globals.ctx, "📦 " .. container.name)
                    
                    -- Store drag info in global variable
                    globals.draggedItem = {
                        type = "CONTAINER",
                        groupIndex = i,
                        containerIndex = j,
                        name = container.name
                    }
                    
                    imgui.EndDragDropSource(globals.ctx)
                end

                -- Handle selection with multi-selection support
                if imgui.IsItemClicked(globals.ctx) then
                    local shiftPressed = imgui.GetKeyMods(globals.ctx) & imgui.Mod_Shift ~= 0
                    if ctrlPressed then
                        toggleContainerSelection(i, j)
                        globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
                        globals.shiftAnchorGroupIndex = i
                        globals.shiftAnchorContainerIndex = j
                    elseif shiftPressed and globals.shiftAnchorGroupIndex then
                        selectContainerRange(globals.shiftAnchorGroupIndex, globals.shiftAnchorContainerIndex, i, j)
                    else
                        clearContainerSelections()
                        toggleContainerSelection(i, j)
                        globals.inMultiSelectMode = false
                        globals.shiftAnchorGroupIndex = i
                        globals.shiftAnchorContainerIndex = j
                    end
                end

                -- Position buttons for container actions
                local buttonsX = startX + 20 + nameWidth + 10
                imgui.SameLine(globals.ctx)
                imgui.SetCursorPosX(globals.ctx, buttonsX)

                -- Delete container button
                if imgui.Button(globals.ctx, "Delete##" .. containerId) then
                    containerToDelete = j
                end

                -- Regenerate container button
                imgui.SameLine(globals.ctx)
                if imgui.Button(globals.ctx, "Regenerate##" .. containerId) then
                    globals.Generation.generateSingleContainer(i, j)
                end

                imgui.Unindent(globals.ctx, 20)

                -- Drop zone after each container
                createContainerInsertionLine(i, j + 1)
            end

            -- Delete the marked container if any
            if containerToDelete then
                globals.selectedContainers[i .. "_" .. containerToDelete] = nil
                table.remove(group.containers, containerToDelete)
                if globals.selectedGroupIndex == i and globals.selectedContainerIndex == containerToDelete then
                    globals.selectedContainerIndex = nil
                elseif globals.selectedGroupIndex == i and globals.selectedContainerIndex > containerToDelete then
                    globals.selectedContainerIndex = globals.selectedContainerIndex - 1
                end
                -- Update selection indices for containers after the deleted one
                for k = containerToDelete + 1, #group.containers + 1 do
                    if globals.selectedContainers[i .. "_" .. k] then
                        globals.selectedContainers[i .. "_" .. (k-1)] = true
                        globals.selectedContainers[i .. "_" .. k] = nil
                    end
                end
            end

            imgui.TreePop(globals.ctx)
        end

        -- Drop zone after each group
        createGroupInsertionLine(i + 1)
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
    
    -- Process any pending moves after rendering is complete
    if globals.pendingGroupMove then
        UI_Groups.reorderGroups(globals.pendingGroupMove.sourceIndex, globals.pendingGroupMove.targetIndex)
        globals.pendingGroupMove = nil
        globals.draggedItem = nil -- Clear drag state after successful move
    end
    
    if globals.pendingContainerMove then
        UI_Groups.moveContainerToGroup(
            globals.pendingContainerMove.sourceGroupIndex,
            globals.pendingContainerMove.sourceContainerIndex,
            globals.pendingContainerMove.targetGroupIndex,
            globals.pendingContainerMove.targetContainerIndex
        )
        globals.pendingContainerMove = nil
        globals.draggedItem = nil -- Clear drag state after successful move
    end
    
    if globals.pendingContainerReorder then
        UI_Groups.reorderContainers(
            globals.pendingContainerReorder.groupIndex,
            globals.pendingContainerReorder.sourceIndex,
            globals.pendingContainerReorder.targetIndex
        )
        globals.pendingContainerReorder = nil
        globals.draggedItem = nil -- Clear drag state after successful move
    end
    
    -- Clean up drag state if no drag is active and no pending operations (fixes persistent drop zones)
    if globals.draggedItem and not imgui.IsMouseDown(globals.ctx, imgui.MouseButton_Left) and 
       not globals.pendingGroupMove and not globals.pendingContainerMove and not globals.pendingContainerReorder then
        globals.draggedItem = nil
    end
end

-- Return the number of selected containers across all groups
function UI_Groups.getSelectedContainersCount()
    local count = 0
    for _ in pairs(globals.selectedContainers) do
        count = count + 1
    end
    return count
end

return UI_Groups