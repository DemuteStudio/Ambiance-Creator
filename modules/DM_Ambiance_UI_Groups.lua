--[[
Sound Randomizer for REAPER - UI Groups Module
This module handles group display and management UI components.
]]

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

-- Draw the left panel containing the list of groups and their containers
function UI_Groups.drawGroupsPanel(width, isContainerSelected, toggleContainerSelection, clearContainerSelections, selectContainerRange)
    -- Wrapper for ImGui calls to avoid crashes on errors
    local function safeImGui(func, ...)
        local success, result = pcall(func, ...)
        if not success then
            -- Optional: log the error
            -- reaper.ShowConsoleMsg("ImGui error: " .. tostring(result) .. "\n")
            return false
        end
        return result
    end

    -- Basic check for minimal window size
    local availableHeight = imgui.GetWindowHeight(globals.ctx)
    local availableWidth = imgui.GetWindowWidth(globals.ctx)
    if availableHeight < 100 or availableWidth < 200 then
        imgui.TextColored(globals.ctx, 0xFF0000FF, "Window too small")
        return
    end

    -- Panel title
    safeImGui(imgui.Text, globals.ctx, "Groups & Containers")

    -- Multi-selection info and clear selection button
    local selectedCount = UI_Groups.getSelectedContainersCount()
    if selectedCount > 1 then
        safeImGui(imgui.SameLine, globals.ctx)
        safeImGui(imgui.TextColored, globals.ctx, 0xFF4CAF50, "(" .. selectedCount .. " selected)")
        safeImGui(imgui.SameLine, globals.ctx)
        if safeImGui(imgui.Button, globals.ctx, "Clear Selection") then
            clearContainerSelections()
        end
    end

    -- Add group button
    if safeImGui(imgui.Button, globals.ctx, "Add Group") then
        table.insert(globals.groups, globals.Structures.createGroup())
        
        -- Sélectionner automatiquement le nouveau groupe
        local newGroupIndex = #globals.groups
        globals.selectedGroupIndex = newGroupIndex
        globals.selectedContainerIndex = nil
        clearContainerSelections()
        globals.inMultiSelectMode = false
        globals.shiftAnchorGroupIndex = newGroupIndex
        globals.shiftAnchorContainerIndex = nil
    end
    safeImGui(imgui.Separator, globals.ctx)

    -- Detect if Ctrl is pressed for multi-selection
    local ctrlPressed = safeImGui(imgui.GetKeyMods, globals.ctx) & imgui.Mod_Ctrl ~= 0

    -- Track which group to delete (if any)
    local groupToDelete = nil

    -- Loop through groups
    for i, group in ipairs(globals.groups) do
        local success = pcall(function()
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

            -- If the group is open, display its content
            if groupOpen then
                local contentSuccess = pcall(function()
                    -- Add container button
                    if imgui.Button(globals.ctx, "Add Container##" .. groupId) then
                        table.insert(group.containers, globals.Structures.createContainer())
                        
                        -- Automatically select the new container
                        clearContainerSelections()
                        local newContainerIndex = #group.containers
                        toggleContainerSelection(i, newContainerIndex)
                        globals.selectedGroupIndex = i
                        globals.selectedContainerIndex = newContainerIndex
                        globals.inMultiSelectMode = false
                        globals.shiftAnchorGroupIndex = i
                        globals.shiftAnchorContainerIndex = newContainerIndex
                    end

                    -- Help marker for multi-selection
                    imgui.SameLine(globals.ctx)
                    globals.Utils.HelpMarker("Select multiple containers using 'Shift' or 'Ctrl' keys:\n\n" ..
                        "- Hold 'Shift' to select a continuous range of items\n" ..
                        "- Hold 'Ctrl' to add or remove individual items from selection\n\n" ..
                        "Any changes made while multiple containers are selected will be applied to all of them simultaneously.")

                    -- Track which container to delete
                    local containerToDelete = nil

                    -- Loop through containers in this group
                    for j, container in ipairs(group.containers) do
                        pcall(function()
                            local containerId = groupId .. "_container" .. j
                            -- TreeNode flags for containers (leaf, no push, span width)
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
                        end)
                    end

                    -- Delete the marked container if any
                    if containerToDelete then
                        pcall(function()
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
                        end)
                    end

                    imgui.TreePop(globals.ctx)
                end)
                if not contentSuccess then
                    pcall(imgui.Text, globals.ctx, "Error rendering group content")
                end
            end
        end)
        if not success then
            pcall(imgui.Text, globals.ctx, "Error rendering group " .. i)
        end
    end

    -- Delete the marked group if any
    if groupToDelete then
        pcall(function()
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
        end)
    end

    -- Update the multi-select mode flag
    globals.inMultiSelectMode = UI_Groups.getSelectedContainersCount() > 1
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
