--[[
@noindex
@version 1.0
--]]

local UI_Group = {}

local globals = {}

-- Initialize the module with global variables from the main script
function UI_Group.initModule(g)
    globals = g
end

-- Function to display group randomization settings in the right panel
function UI_Group.displayGroupSettings(groupIndex, width)
    local group = globals.groups[groupIndex]
    local groupId = "group" .. groupIndex
    
    -- Panel title showing which group is being edited
    imgui.Text(globals.ctx, "Group Settings: " .. group.name)
    imgui.Separator(globals.ctx)
    
    -- Group name input field
    local groupName = group.name
    imgui.PushItemWidth(globals.ctx, width * 0.5)
    local rv, newGroupName = imgui.InputText(globals.ctx, "Name##detail_" .. groupId, groupName)
    if rv then group.name = newGroupName end
    
    -- Group preset controls
    globals.UI_Groups.drawGroupPresetControls(groupIndex)
    
    -- TRIGGER SETTINGS SECTION
    globals.UI.displayTriggerSettings(group, groupId, width, true)
end

return UI_Group
