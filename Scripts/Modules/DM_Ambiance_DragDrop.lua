--[[
@noindex
--]]

local DragDrop = {}
local globals = {}

-- Initialize the module with global references from the main script
function DragDrop.initModule(g)
    globals = g
end

-- Constants for drag and drop payload types
DragDrop.PAYLOAD_GROUP = "DND_GROUP"
DragDrop.PAYLOAD_CONTAINER = "DND_CONTAINER"

-- Visual feedback colors for drag and drop operations
local DRAG_COLOR_GROUP = 0xFF4CAF50     -- Green for groups
local DRAG_COLOR_CONTAINER = 0xFF2196F3 -- Blue for containers
local DROP_TARGET_COLOR = 0xFFFF9800    -- Orange for drop targets
local DROP_HIGHLIGHT_COLOR = 0x40FFFF00 -- Semi-transparent yellow highlight

-- Helper function to create drag source for groups
function DragDrop.createGroupDragSource(groupIndex, groupName)
    if imgui.BeginDragDropSource(globals.ctx) then
        -- Set payload data
        local payloadData = string.format("GROUP:%d", groupIndex)
        imgui.SetDragDropPayload(globals.ctx, DragDrop.PAYLOAD_GROUP, payloadData)
        
        -- Simple visual feedback during drag (only show in the drag preview, not custom window)
        imgui.PushStyleColor(globals.ctx, imgui.Col_Text, DRAG_COLOR_GROUP)
        imgui.Text(globals.ctx, "📁 " .. groupName)
        imgui.PopStyleColor(globals.ctx)
        
        -- Update global drag state
        globals.dragDropActive = true
        globals.dragDropSource = {
            type = "GROUP",
            index = groupIndex,
            name = groupName
        }
        
        imgui.EndDragDropSource(globals.ctx)
        return true
    end
    return false
end

-- Helper function to create drag source for containers
function DragDrop.createContainerDragSource(groupIndex, containerIndex, containerName)
    if imgui.BeginDragDropSource(globals.ctx) then
        -- Set payload data
        local payloadData = string.format("CONTAINER:%d:%d", groupIndex, containerIndex)
        imgui.SetDragDropPayload(globals.ctx, DragDrop.PAYLOAD_CONTAINER, payloadData)
        
        -- Simple visual feedback during drag
        imgui.PushStyleColor(globals.ctx, imgui.Col_Text, DRAG_COLOR_CONTAINER)
        imgui.Text(globals.ctx, "📦 " .. containerName)
        local sourceGroupName = globals.groups[groupIndex] and globals.groups[groupIndex].name or "Unknown"
        imgui.Text(globals.ctx, "From: " .. sourceGroupName)
        imgui.PopStyleColor(globals.ctx)
        
        -- Update global drag state
        globals.dragDropActive = true
        globals.dragDropSource = {
            type = "CONTAINER",
            groupIndex = groupIndex,
            containerIndex = containerIndex,
            name = containerName
        }
        
        imgui.EndDragDropSource(globals.ctx)
        return true
    end
    return false
end

-- Helper function to create drop target for group reordering
function DragDrop.createGroupDropTarget(targetGroupIndex, targetGroupName, onDropCallback)
    if imgui.BeginDragDropTarget(globals.ctx) then
        -- Highlight the drop target
        DragDrop.highlightDropTarget()
        
        -- Accept group payload
        local payload = imgui.AcceptDragDropPayload(globals.ctx, DragDrop.PAYLOAD_GROUP)
        if payload then
            -- Parse payload
            local sourceGroupIndex = tonumber(payload:match("GROUP:(%d+)"))
            if sourceGroupIndex and sourceGroupIndex ~= targetGroupIndex then
                -- Debug output
                reaper.ShowConsoleMsg("DEBUG: Dropping group " .. sourceGroupIndex .. " onto " .. targetGroupIndex .. "\n")
                
                -- Execute drop callback
                if onDropCallback then
                    onDropCallback(sourceGroupIndex, targetGroupIndex)
                end
                DragDrop.resetDragState()
            end
        end
        
        imgui.EndDragDropTarget(globals.ctx)
        return true
    end
    return false
end

-- Helper function to create drop target for container movement
function DragDrop.createContainerDropTarget(targetGroupIndex, targetGroupName, onDropCallback)
    if imgui.BeginDragDropTarget(globals.ctx) then
        -- Highlight the drop target
        DragDrop.highlightDropTarget()
        
        -- Accept container payload
        local payload = imgui.AcceptDragDropPayload(globals.ctx, DragDrop.PAYLOAD_CONTAINER)
        if payload then
            -- Parse payload
            local sourceGroupIndex, sourceContainerIndex = payload:match("CONTAINER:(%d+):(%d+)")
            sourceGroupIndex = tonumber(sourceGroupIndex)
            sourceContainerIndex = tonumber(sourceContainerIndex)
            
            if sourceGroupIndex and sourceContainerIndex then
                -- Debug output
                reaper.ShowConsoleMsg("DEBUG: Dropping container " .. sourceGroupIndex .. "_" .. sourceContainerIndex .. " onto group " .. targetGroupIndex .. "\n")
                
                -- Execute drop callback
                if onDropCallback then
                    onDropCallback(sourceGroupIndex, sourceContainerIndex, targetGroupIndex)
                end
                DragDrop.resetDragState()
            end
        end
        
        imgui.EndDragDropTarget(globals.ctx)
        return true
    end
    return false
end

-- Helper function to highlight drop targets
function DragDrop.highlightDropTarget()
    -- Get the current item rectangle
    local min_x, min_y = imgui.GetItemRectMin(globals.ctx)
    local max_x, max_y = imgui.GetItemRectMax(globals.ctx)
    
    -- Draw a colored rectangle behind the item
    local drawList = imgui.GetWindowDrawList(globals.ctx)
    imgui.DrawList_AddRectFilled(drawList, min_x, min_y, max_x, max_y, DROP_HIGHLIGHT_COLOR)
    
    -- Draw a border around the drop target
    imgui.DrawList_AddRect(drawList, min_x - 1, min_y - 1, max_x + 1, max_y + 1, DROP_TARGET_COLOR, 0, 0, 2)
end

-- Helper function to show drop target hints
function DragDrop.showDropTargetHint(targetType, targetName)
    if not globals.dragDropActive or not globals.dragDropSource then
        return
    end
    
    local sourceType = globals.dragDropSource.type
    local sourceName = globals.dragDropSource.name
    
    -- Determine if this is a valid drop target
    local isValidTarget = false
    local hintText = ""
    
    if sourceType == "GROUP" and targetType == "GROUP" then
        isValidTarget = true
        hintText = "💱 Reorder group here"
    elseif sourceType == "CONTAINER" and targetType == "GROUP" then
        isValidTarget = true
        hintText = "📥 Move container to this group"
    end
    
    if isValidTarget then
        -- Show a subtle hint
        imgui.PushStyleColor(globals.ctx, imgui.Col_Text, DROP_TARGET_COLOR)
        imgui.SameLine(globals.ctx)
        imgui.TextDisabled(globals.ctx, hintText)
        imgui.PopStyleColor(globals.ctx)
    end
end

-- Function to reset drag and drop state
function DragDrop.resetDragState()
    globals.dragDropActive = false
    globals.dragDropSource = nil
end

-- Function to check if a drag operation is currently active
function DragDrop.isDragActive()
    return globals.dragDropActive and globals.dragDropSource ~= nil
end

-- Function to get current drag source information
function DragDrop.getDragSource()
    return globals.dragDropSource
end

-- Helper function to show drag feedback in the UI
function DragDrop.showDragFeedback()
    if not DragDrop.isDragActive() then
        return
    end
    
    local source = DragDrop.getDragSource()
    if not source then
        return
    end
    
    -- Show drag status in a small overlay
    local windowFlags = imgui.WindowFlags_NoTitleBar | 
                       imgui.WindowFlags_NoResize | 
                       imgui.WindowFlags_NoMove | 
                       imgui.WindowFlags_NoScrollbar |
                       imgui.WindowFlags_NoSavedSettings |
                       imgui.WindowFlags_AlwaysAutoResize
    
    -- Position the overlay near the mouse cursor
    local mouse_x, mouse_y = imgui.GetMousePos(globals.ctx)
    imgui.SetNextWindowPos(globals.ctx, mouse_x + 10, mouse_y + 10)
    
    if imgui.Begin(globals.ctx, "##DragFeedback", nil, windowFlags) then
        if source.type == "GROUP" then
            imgui.PushStyleColor(globals.ctx, imgui.Col_Text, DRAG_COLOR_GROUP)
            imgui.Text(globals.ctx, "📁 " .. source.name)
        elseif source.type == "CONTAINER" then
            imgui.PushStyleColor(globals.ctx, imgui.Col_Text, DRAG_COLOR_CONTAINER)
            imgui.Text(globals.ctx, "📦 " .. source.name)
            local sourceGroupName = globals.groups[source.groupIndex] and globals.groups[source.groupIndex].name or "Unknown"
            imgui.Text(globals.ctx, "   From: " .. sourceGroupName)
        end
        imgui.PopStyleColor(globals.ctx)
        imgui.Text(globals.ctx, "Drop to move")
        imgui.End(globals.ctx)
    end
end

-- Function to handle drag and drop cleanup when operations are cancelled
function DragDrop.handleDragCancel()
    -- Check if we need to reset drag state (e.g., when mouse is released without dropping)
    if globals.dragDropActive and not imgui.IsMouseDown(globals.ctx, imgui.MouseButton_Left) then
        DragDrop.resetDragState()
    end
end

return DragDrop