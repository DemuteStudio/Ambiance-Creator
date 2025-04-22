--[[
Sound Randomizer for REAPER - UI Generation Module
This module handles UI components related to the sound generation process
]]

local UI_Generation = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_Generation.initModule(g)
    globals = g
end

-- Function to draw the main generation button with styling
function UI_Generation.drawMainGenerationButton()
    -- Apply styling for the main generation button
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_Button(), 0xFF4CAF50) -- Green button
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF66BB6A) -- Lighter green when hovered
    reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonActive(), 0xFF43A047) -- Darker green when clicked
    
    local buttonPressed = reaper.ImGui_Button(globals.ctx, "Create Ambiance", 150, 30)
    
    -- Pop styling colors to return to default
    reaper.ImGui_PopStyleColor(globals.ctx, 3)
    
    -- Execute generation if button was pressed
    if buttonPressed then
        globals.Generation.generateTracks()
    end
    
    return buttonPressed
end

-- Function to display time selection information
function UI_Generation.drawTimeSelectionInfo()
    if globals.Utils.checkTimeSelection() then
        reaper.ImGui_Text(globals.ctx, "Time Selection: " .. globals.Utils.formatTime(globals.startTime) .. 
                                       " - " .. globals.Utils.formatTime(globals.endTime) .. 
                                       " | Length: " .. globals.Utils.formatTime(globals.endTime - globals.startTime))
    else
        reaper.ImGui_TextColored(globals.ctx, 0xFF0000FF, "No time selection! Please create one.")
    end
end

-- Function to draw regenerate button for a track
function UI_Generation.drawTrackRegenerateButton(trackIndex)
    local trackId = "track" .. trackIndex
    if reaper.ImGui_Button(globals.ctx, "Regenerate##" .. trackId) then
        globals.Generation.generateSingleTrack(trackIndex)
        return true
    end
    return false
end

-- Function to draw regenerate button for a container
function UI_Generation.drawContainerRegenerateButton(trackIndex, containerIndex)
    local trackId = "track" .. trackIndex
    local containerId = trackId .. "_container" .. containerIndex
    if reaper.ImGui_Button(globals.ctx, "Regenerate##" .. containerId) then
        globals.Generation.generateSingleContainer(trackIndex, containerIndex)
        return true
    end
    return false
end

-- Function to draw regenerate button for multiple selected containers
function UI_Generation.drawMultiRegenerateButton(width)
    -- Get list of all selected containers
    local selectedContainers = {}
    for key in pairs(globals.selectedContainers) do
        local t, c = key:match("(%d+)_(%d+)")
        table.insert(selectedContainers, {trackIndex = tonumber(t), containerIndex = tonumber(c)})
    end
    
    if reaper.ImGui_Button(globals.ctx, "Regenerate All Selected", width * 0.5, 30) then
        for _, c in ipairs(selectedContainers) do
            globals.Generation.generateSingleContainer(c.trackIndex, c.containerIndex)
        end
        return true
    end
    return false
end

-- Function to display UI controls for global generation settings
function UI_Generation.drawGlobalGenerationSettings()
    if not reaper.ImGui_CollapsingHeader(globals.ctx, "Generation Settings") then
        return
    end
    
    reaper.ImGui_Indent(globals.ctx, 10)
    
    -- Global cross-fade settings
    local rv, newCrossfadeEnabled = reaper.ImGui_Checkbox(globals.ctx, "Enable automatic crossfades", globals.enableCrossfades)
    if rv then globals.enableCrossfades = newCrossfadeEnabled end
    
    if globals.enableCrossfades then
        reaper.ImGui_PushItemWidth(globals.ctx, 200)
        local crossfadeShapes = "Linear\0Slow start/end\0Fast start\0Fast end\0Sharp\0\0"
        local rv, newShape = reaper.ImGui_Combo(globals.ctx, "Crossfade shape", globals.crossfadeShape, crossfadeShapes)
        if rv then globals.crossfadeShape = newShape end
    end
    
    -- Random seed control
    reaper.ImGui_Separator(globals.ctx)
    local rv, newUseSeed = reaper.ImGui_Checkbox(globals.ctx, "Use fixed seed", globals.useRandomSeed)
    if rv then globals.useRandomSeed = newUseSeed end
    
    if globals.useRandomSeed then
        reaper.ImGui_PushItemWidth(globals.ctx, 200)
        local rv, newSeed = reaper.ImGui_InputInt(globals.ctx, "Random seed", globals.randomSeed)
        if rv then globals.randomSeed = newSeed end
    end
    
    reaper.ImGui_Unindent(globals.ctx, 10)
end

return UI_Generation
