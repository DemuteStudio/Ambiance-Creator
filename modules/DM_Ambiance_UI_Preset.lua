--[[
Sound Randomizer for REAPER - UI Preset Module
This module handles the UI for global presets management
]]

local UI_Preset = {}
local globals = {}

-- Initialize the module with global variables from the main script
function UI_Preset.initModule(g)
    globals = g
end

-- Function to display global preset controls in the top section
function UI_Preset.drawPresetControls()
    -- Section title with colored text
    reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Global Presets")
    
    -- Refresh button to update preset list
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Refresh") then
        globals.Presets.listPresets("Global", nil, true)
    end
    
    -- Dropdown list of presets
    reaper.ImGui_SameLine(globals.ctx)
    
    -- Get the preset list from presets module
    local presetList = globals.Presets.listPresets("Global")
    
    -- Prepare items for the dropdown (ImGui Combo)
    local presetItems = ""
    for _, name in ipairs(presetList) do
        presetItems = presetItems .. name .. "\0"
    end
    presetItems = presetItems .. "\0"
    
    -- Display the dropdown list with existing presets
    reaper.ImGui_PushItemWidth(globals.ctx, 300)
    local rv, newSelectedIndex = reaper.ImGui_Combo(globals.ctx, "##PresetSelector", globals.selectedPresetIndex, presetItems)
    
    -- Handle selection change
    if rv then
        globals.selectedPresetIndex = newSelectedIndex
        globals.currentPresetName = presetList[globals.selectedPresetIndex + 1] or ""
    end
    
    -- Action buttons: Load, Save, Delete, Open Directory
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Load") and globals.currentPresetName ~= "" then
        globals.Presets.loadPreset(globals.currentPresetName)
    end
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Save") then
        globals.Utils.safeOpenPopup("Save Preset")
        globals.newPresetName = globals.currentPresetName
    end
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Delete") and globals.currentPresetName ~= "" then
        globals.Utils.safeOpenPopup("Confirm deletion")
    end
    
    reaper.ImGui_SameLine(globals.ctx)
    if reaper.ImGui_Button(globals.ctx, "Open Preset Directory") then
        globals.Utils.openPresetsFolder("Global")
    end
    
    -- Save preset popup modal
    UI_Preset.handleSavePresetPopup(presetList)
    
    -- Deletion confirmation popup modal
    UI_Preset.handleDeletePresetPopup()
end

-- Function to handle the save preset popup
function UI_Preset.handleSavePresetPopup(presetList)
    if reaper.ImGui_BeginPopupModal(globals.ctx, "Save Preset", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(globals.ctx, "Preset name:")
        local rv, value = reaper.ImGui_InputText(globals.ctx, "##PresetName", globals.newPresetName)
        if rv then globals.newPresetName = value end
        
        if reaper.ImGui_Button(globals.ctx, "Save", 120, 0) and globals.newPresetName ~= "" then
            if globals.Presets.savePreset(globals.newPresetName) then
                globals.currentPresetName = globals.newPresetName
                for i, name in ipairs(presetList) do
                    if name == globals.currentPresetName then
                        globals.selectedPresetIndex = i - 1
                        break
                    end
                end
                globals.Utils.safeClosePopup("Save Preset")
            end
        end
        
        reaper.ImGui_SameLine(globals.ctx)
        if reaper.ImGui_Button(globals.ctx, "Cancel", 120, 0) then
            globals.Utils.safeClosePopup("Save Preset")
        end
        
        reaper.ImGui_EndPopup(globals.ctx)
    end
end

-- Function to handle the delete preset confirmation popup
function UI_Preset.handleDeletePresetPopup()
    if reaper.ImGui_BeginPopupModal(globals.ctx, "Confirm deletion", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(globals.ctx, "Are you sure you want to delete the preset \"" .. globals.currentPresetName .. "\"?")
        reaper.ImGui_Separator(globals.ctx)
        
        if reaper.ImGui_Button(globals.ctx, "Yes", 120, 0) then
            globals.Presets.deletePreset(globals.currentPresetName, "Global")
            globals.Utils.safeClosePopup("Confirm deletion")
        end
        
        reaper.ImGui_SameLine(globals.ctx)
        if reaper.ImGui_Button(globals.ctx, "No", 120, 0) then
            globals.Utils.safeClosePopup("Confirm deletion")
        end
        
        reaper.ImGui_EndPopup(globals.ctx)
    end
end

return UI_Preset
