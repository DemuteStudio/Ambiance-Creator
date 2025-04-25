--[[
Sound Randomizer for REAPER - UI Container Module
This module handles the UI for displaying and editing container settings.
]]

local UI_Container = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_Container.initModule(g)
    globals = g
end

-- Display the preset controls for a specific container (load/save container presets)
function UI_Container.drawContainerPresetControls(groupIndex, containerIndex)
    local groupId = "group" .. groupIndex
    local containerId = groupId .. "_container" .. containerIndex
    local presetKey = groupIndex .. "_" .. containerIndex

    -- Initialize the selected preset index for this container if not already set
    if not globals.selectedContainerPresetIndex[presetKey] then
        globals.selectedContainerPresetIndex[presetKey] = -1
    end

    -- Get a sanitized group name for folder structure (replace non-alphanumeric characters with underscores)
    local groupName = globals.groups[groupIndex].name:gsub("[^%w]", "_")

    -- Get the list of available container presets (shared across all groups)
    local containerPresetList = globals.Presets.listPresets("Containers")

    -- Prepare the items for the preset dropdown (ImGui Combo expects a null-separated string)
    local containerPresetItems = ""
    for _, name in ipairs(containerPresetList) do
        containerPresetItems = containerPresetItems .. name .. "\0"
    end
    containerPresetItems = containerPresetItems .. "\0"

    -- Preset dropdown control
    imgui.PushItemWidth(globals.ctx, 200)
    local rv, newSelectedContainerIndex = imgui.Combo(
        globals.ctx,
        "##ContainerPresetSelector" .. containerId,
        globals.selectedContainerPresetIndex[presetKey],
        containerPresetItems
    )
    if rv then
        globals.selectedContainerPresetIndex[presetKey] = newSelectedContainerIndex
    end

    -- Load preset button: loads the selected preset into this container
    imgui.SameLine(globals.ctx)
    if imgui.Button(globals.ctx, "Load Container##" .. containerId)
        and globals.selectedContainerPresetIndex[presetKey] >= 0
        and globals.selectedContainerPresetIndex[presetKey] < #containerPresetList then

        local presetName = containerPresetList[globals.selectedContainerPresetIndex[presetKey] + 1]
        globals.Presets.loadContainerPreset(presetName, groupIndex, containerIndex)
    end

    -- Save preset button: opens a popup to save the current container as a preset
    imgui.SameLine(globals.ctx)
    if imgui.Button(globals.ctx, "Save Container##" .. containerId) then
        -- Check if a media directory is configured before allowing save
        if not globals.Utils.isMediaDirectoryConfigured() then
            -- Set flag to show the warning popup
            globals.showMediaDirWarning = true
        else
            -- Continue with the normal save popup
            globals.newContainerPresetName = globals.groups[groupIndex].containers[containerIndex].name
            globals.currentSaveContainerGroup = groupIndex
            globals.currentSaveContainerIndex = containerIndex
            globals.Utils.safeOpenPopup("Save Container Preset##" .. containerId)
        end
    end

    -- Popup dialog for saving the container as a preset
    if imgui.BeginPopupModal(globals.ctx, "Save Container Preset##" .. containerId, nil, imgui.WindowFlags_AlwaysAutoResize) then
        imgui.Text(globals.ctx, "Container preset name:")
        local rv, value = imgui.InputText(globals.ctx, "##ContainerPresetName" .. containerId, globals.newContainerPresetName)
        if rv then globals.newContainerPresetName = value end

        if imgui.Button(globals.ctx, "Save", 120, 0) and globals.newContainerPresetName ~= "" then
            if globals.Presets.saveContainerPreset(
                globals.newContainerPresetName,
                globals.currentSaveContainerGroup,
                globals.currentSaveContainerIndex
            ) then
                globals.Utils.safeClosePopup("Save Container Preset##" .. containerId)
            end
        end

        imgui.SameLine(globals.ctx)
        if imgui.Button(globals.ctx, "Cancel", 120, 0) then
            globals.Utils.safeClosePopup("Save Container Preset##" .. containerId)
        end

        imgui.EndPopup(globals.ctx)
    end
end

-- Display the settings for a specific container in the right panel
function UI_Container.displayContainerSettings(groupIndex, containerIndex, width)
    local group = globals.groups[groupIndex]
    local container = group.containers[containerIndex]
    local groupId = "group" .. groupIndex
    local containerId = groupId .. "_container" .. containerIndex

    -- Panel title showing which container is being edited
    imgui.Text(globals.ctx, "Container Settings: " .. container.name)
    imgui.Separator(globals.ctx)

    -- Editable container name input field
    local containerName = container.name
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local rv, newContainerName = imgui.InputText(globals.ctx, "Name##detail_" .. containerId, containerName)
    if rv then container.name = newContainerName end

    -- "Override Parent Settings" checkbox
    local overrideParent = container.overrideParent
    local rv, newOverrideParent = imgui.Checkbox(globals.ctx, "Override Parent Settings##" .. containerId, overrideParent)
    imgui.SameLine(globals.ctx)
    globals.Utils.HelpMarker("Enable 'Override Parent Settings' to customize parameters for this container instead of inheriting from the group.")
    if rv then container.overrideParent = newOverrideParent end

    -- Container preset controls (load/save)
    UI_Container.drawContainerPresetControls(groupIndex, containerIndex)

    -- Button to import selected items from REAPER into this container
    if imgui.Button(globals.ctx, "Import Selected Items##" .. containerId) then
        local items = globals.Items.getSelectedItems()
        if #items > 0 then
            for _, item in ipairs(items) do
                table.insert(container.items, item)
            end
        else
            reaper.MB("No item selected!", "Error", 0)
        end
    end

    -- Display imported items in a collapsible header
    if #container.items > 0 then
        if imgui.CollapsingHeader(globals.ctx, "Imported items (" .. #container.items .. ")##" .. containerId) then
            local itemToDelete = nil
            -- List all imported items with a button to remove each one
            for l, item in ipairs(container.items) do
                imgui.Text(globals.ctx, l .. ". " .. item.name)
                imgui.SameLine(globals.ctx)
                if imgui.Button(globals.ctx, "X##item" .. containerId .. "_" .. l) then
                    itemToDelete = l
                end
            end
            -- Remove the item if the delete button was pressed
            if itemToDelete then
                table.remove(container.items, itemToDelete)
            end
        end
    end

    -- Display trigger/randomization settings or inheritance info
    if container.overrideParent then
        -- Show a message that the container uses its own settings
        imgui.TextColored(globals.ctx, 0x00AA00FF, "Using container's own settings")
        -- Display the trigger and randomization settings for this container
        globals.UI.displayTriggerSettings(container, containerId, width, false)
    else
        -- Show a message that the container inherits settings from its parent group
        imgui.TextColored(globals.ctx, 0x0088FFFF, "Inheriting settings from parent group")
        --imgui.TextColored(globals.ctx, 0xAAAAAAFF, "Enable 'Override Parent Settings' to customize parameters")
    end
end

return UI_Container
