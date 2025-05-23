-- DM_AmbianceCreator_Settings.lua

local Settings = {}

local globals = {}
-- Default settings for the module
local defaultSettings = {
    mediaItemDirectory = "",  -- Path to the media directory
    autoImportMedia = true,   -- Automatically copy media files
    buttonColor = 0x5D5D5DFF, -- Default blue color for buttons
    backgroundColor = 0x2E2E2EFF, -- Dark gray background
    textColor = 0xD5D5D5FF,   -- White text
    uiRounding = 2.0,         -- Default rounding for UI elements
    itemSpacing = 8,          -- Default item spacing
    crossfadeMargin = 0.2,    -- Default crossfade margin in seconds
}

-- Initialize the module with global references and load settings
function Settings.initModule(g)
    globals = g
    
    -- Load settings from file or defaults
    Settings.loadSettings()
    
    -- Check if the media directory is configured at startup
    if Settings.getSetting("mediaItemDirectory") == "" then
        -- If no directory is set and the script is running normally (not as a module)
        if select(2, reaper.get_action_context()) == debug.getinfo(1, 'S').source:sub(2) then
            reaper.defer(function() 
                globals.showSettingsWindow = true
            end)
        end
    end
end

-- Returns the base path for settings (same level as the Presets folder)
function Settings.getSettingsBasePath()
    local basePath = globals.Presets.getPresetsPath("Global"):match("(.+)Global[/\\]")
    return basePath or ""
end

-- Checks reliably if a directory exists
function Settings.directoryExists(path)
    if not path or path == "" then return false end
    
    -- Reliable method: try to create/open a temporary file in the directory
    local testFile = path .. "/.test_access"
    local file = io.open(testFile, "w")
    if file then
        file:close()
        os.remove(testFile)
        return true
    end
    return false
end

-- Load settings from the configuration file
function Settings.loadSettings()
    local settingsFile = Settings.getSettingsBasePath() .. "settings.cfg"
    local file = io.open(settingsFile, "r")
    
    if file then
        local settings = {}
        for line in file:lines() do
            local key, value = line:match("([^=]+)=(.+)")
            if key and value then
                -- Convert boolean values from string to boolean
                if value == "true" then value = true
                elseif value == "false" then value = false
                end
                settings[key] = value
            end
        end
        file:close()
        
        -- Merge loaded settings with defaults
        globals.settings = {}
        for k, v in pairs(defaultSettings) do
            globals.settings[k] = settings[k] ~= nil and settings[k] or v
        end
    else
        globals.settings = defaultSettings
    end
end

-- Save the current settings to the configuration file
function Settings.saveSettings()
    local settingsFile = Settings.getSettingsBasePath() .. "settings.cfg"
    local file = io.open(settingsFile, "w")
    
    if file then
        for k, v in pairs(globals.settings) do
            file:write(k .. "=" .. tostring(v) .. "\n")
        end
        file:close()
        return true
    end
    return false
end

-- Accessor to get a specific setting value
function Settings.getSetting(key)
    return globals.settings[key]
end

-- Mutator to set a specific setting value and save immediately
function Settings.setSetting(key, value)
    globals.settings[key] = value
    Settings.saveSettings()
end

-- Main settings window for the user interface
function Settings.showSettingsWindow(open)
    local ctx = globals.ctx
    local imgui = globals.imgui
    
    local windowFlags = imgui.WindowFlags_NoResize | imgui.WindowFlags_AlwaysAutoResize
    local visible, open = imgui.Begin(ctx, 'Ambiance Creator Settings', open, windowFlags)
    
    if visible then
        imgui.TextColored(ctx, 0xFFAA00FF, "Media Management Settings")
        imgui.Separator(ctx)
        
        -- Media directory section
        imgui.Text(ctx, "Media Item Directory")
        local mediaDir = Settings.getSetting("mediaItemDirectory")
        if mediaDir == "" then
            mediaDir = "No directory selected"
            imgui.TextColored(ctx, 0xFF0000FF, "Warning: No media directory configured")
        end
        
        -- Show current directory path (read-only)
        imgui.PushItemWidth(ctx, 350)
        imgui.InputText(ctx, "##MediaDir", mediaDir, imgui.InputTextFlags_ReadOnly)
        
        -- Button to change the directory
        imgui.SameLine(ctx)
        if imgui.Button(ctx, "Browse") then
            Settings.setupMediaDirectory()
        end
        
        -- Option to automatically import media files
        local rv, autoImport = imgui.Checkbox(ctx, "Automatically import media files when saving presets", 
                                             Settings.getSetting("autoImportMedia"))
        if rv then
            Settings.setSetting("autoImportMedia", autoImport)
        end

        -- Tooltip explaining the auto-import option
        imgui.SameLine(globals.ctx)
        globals.Utils.HelpMarker("- Enabled: Automatically copies all media files referenced in your presets to the central media directory when saving. This ensures your presets remain functional even if original files are moved or deleted.\n\n"..
                                 "- Disabled: Presets will maintain references to the original file locations without creating copies, which saves disk space but makes presets dependent on the original file locations.")
        
        -- Button to open the media directory in the system file explorer
        if mediaDir ~= "No directory selected" then
            if imgui.Button(ctx, "Open Media Directory") then
                -- Use os.execute directly to avoid dependencies
                local OS = reaper.GetOS()
                local command
                
                if OS:match("^Win") then
                    command = 'explorer "'
                elseif OS:match("^macOS") or OS:match("^OSX") then
                    command = 'open "'
                else -- Linux
                    command = 'xdg-open "'
                end
                
                os.execute(command .. mediaDir .. '"')
            end
        end
        
        imgui.Separator(ctx)
        
        -- Ajouter la section crossfade
        Settings.showCrossfadeSettings()

        -- Add the color settings section
        Settings.showAppearanceSettings()
        
        -- Control buttons at the bottom
        if imgui.Button(ctx, "Save & Close", 120, 0) then
            Settings.saveSettings()
            open = false
        end
    end
    
    imgui.End(ctx)
    
    -- Handle the popup for configuring the media directory if needed
    Settings.handleSetupMediaDirectoryPopup()
    
    return open
end

-------
--- Media Directory
-------

-- Opens a dialog to configure the media directory, using the most reliable method available
function Settings.setupMediaDirectory()
    local retval, dirPath
    
    -- Prefer JS_ReaScriptAPI if available (most reliable method)
    if reaper.JS_Dialog_BrowseForFolder then
        retval, dirPath = reaper.JS_Dialog_BrowseForFolder("Select the directory for media files", "")
        
        if retval and dirPath and dirPath ~= "" then
            -- Test directory access without attempting to create it
            if Settings.directoryExists(dirPath) then
                Settings.setSetting("mediaItemDirectory", dirPath)
                return true
            else
                reaper.ShowMessageBox("Cannot access this directory. Check permissions.", "Access Error", 0)
            end
        end
        return false
    end
    
    -- Alternative: Use SWS extension if available
    if reaper.BR_Win32_BrowseForDirectory then
        retval, dirPath = reaper.BR_Win32_BrowseForDirectory(reaper.GetResourcePath(), "Select the directory for media files")
        
        if retval and dirPath and dirPath ~= "" then
            if Settings.directoryExists(dirPath) then
                Settings.setSetting("mediaItemDirectory", dirPath)
                return true
            else
                reaper.ShowMessageBox("Cannot access this directory. Check permissions.", "Access Error", 0)
            end
        end
        return false
    end
    
    -- Fallback: Manual entry with GetUserInputs
    reaper.ShowMessageBox("Please install the JS_ReaScriptAPI extension via ReaPack for best experience.", "Recommended Extensions", 0)
    
    retval, dirPath = reaper.GetUserInputs("Select the directory for media files", 1, "Full path:,extrawidth=300", reaper.GetResourcePath() .. "/Scripts")
    
    if retval and dirPath and dirPath ~= "" then
        if Settings.directoryExists(dirPath) then
            Settings.setSetting("mediaItemDirectory", dirPath)
            return true
        else
            reaper.ShowMessageBox("The specified directory does not exist or is not accessible.", "Error", 0)
        end
    end
    
    return false
end

-- Popup modal for configuring the media directory
function Settings.handleSetupMediaDirectoryPopup()
    local ctx = globals.ctx
    local imgui = globals.imgui
    
    if imgui.BeginPopupModal(ctx, "Setup Media Directory", nil, imgui.WindowFlags_AlwaysAutoResize) then
        imgui.Text(ctx, "You need to configure a directory for your media files")
        imgui.TextWrapped(ctx, "This directory will be used to store copies of all media files used in your presets.")
        
        -- Show the current directory if set
        local mediaDir = Settings.getSetting("mediaItemDirectory") or ""
        if mediaDir ~= "" then
            imgui.Text(ctx, "Current directory:")
            imgui.PushStyleColor(ctx, imgui.Col_Text, 0x00AA00FF)
            imgui.Text(ctx, mediaDir)
            imgui.PopStyleColor(ctx)
        end
        
        -- Button to open the directory selector
        if imgui.Button(ctx, "Select a directory...", 200, 0) then
            local success = Settings.setupMediaDirectory()
            if success then
                imgui.CloseCurrentPopup(ctx)
            end
        end
        
        imgui.SameLine(ctx)
        if imgui.Button(ctx, "Cancel", 120, 0) then
            imgui.CloseCurrentPopup(ctx)
        end
        
        imgui.EndPopup(ctx)
    end
end

-- Check if a file exists at the given path
function Settings.fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Copy a file from source to destination
function Settings.copyFile(source, dest)
    -- Open the source file for reading
    local sourceFile = io.open(source, "rb")
    if not sourceFile then
        return false
    end
    
    -- Read the entire content
    local content = sourceFile:read("*all")
    sourceFile:close()
    
    -- Write to the destination file
    local destFile = io.open(dest, "wb")
    if not destFile then
        return false
    end
    
    destFile:write(content)
    destFile:close()
    
    return true
end

-- Copy a media file to the configured directory, returns the new path and success status
function Settings.copyMediaFile(sourcePath)
    local mediaDir = Settings.getSetting("mediaItemDirectory")
    if mediaDir == "" or not sourcePath or sourcePath == "" then
        return sourcePath, false
    end
    
    -- Extract the file name from the source path
    local fileName = sourcePath:match("([^/\\]+)$")
    if not fileName then
        return sourcePath, false
    end
    
    -- Build the destination path
    local destPath = mediaDir
    if not destPath:match("[/\\]$") then
        destPath = destPath .. "\\"
    end
    destPath = destPath .. fileName
    
    -- Avoid copying if the file already exists at the destination
    if Settings.fileExists(destPath) then
        return destPath, true
    end
    
    -- Copy the file and return the result
    local success = Settings.copyFile(sourcePath, destPath)
    
    return destPath, success
end

-- Process all media files in a container, copying them if needed
function Settings.processContainerMedia(container)
    if not container or not container.items then
        return container
    end
    
    -- Copy media files for each item in the container
    for i, item in ipairs(container.items) do
        if item.filePath and item.filePath ~= "" then
            local newPath, success = Settings.copyMediaFile(item.filePath)
            if success then
                item.filePath = newPath
            end
        end
    end
    
    return container
end

-------
--- Style
-------

-- Converts a hex color (0xRRGGBBAA) to individual RGB components (0-1 for ImGui)
function Settings.colorToRGBA(color)
    -- Conversion de la chaîne en nombre si nécessaire
    if type(color) == "string" then
        color = tonumber(color)
    end
    
    -- Vérification que la couleur est bien un nombre
    if type(color) ~= "number" then
        -- Valeur par défaut en cas d'erreur (blanc opaque)
        return 1, 1, 1, 1
    end
    
    -- Extract components using bitwise operations
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = color & 0xFF
    
    return r/255, g/255, b/255, a/255
end


-- Converts RGB components (0-1) to a hex color (0xRRGGBBAA)
function Settings.rgbaToColor(r, g, b, a)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    a = math.floor((a or 1) * 255)
    
    return (r << 24) | (g << 16) | (b << 8) | a
end

-- Display a color picker UI element for a specific color setting
function Settings.colorPicker(label, colorKey)
    local ctx = globals.ctx
    local imgui = globals.imgui
    
    local currentColor = Settings.getSetting(colorKey)
    local r, g, b, a = Settings.colorToRGBA(currentColor)
    
    local rv, newColor = imgui.ColorEdit4(ctx, label, currentColor)
    
    if rv then
        Settings.setSetting(colorKey, newColor)
        return true
    end
    
    return false
end

-- Add the color settings section to the main settings window
function Settings.showAppearanceSettings()
    local ctx = globals.ctx
    local imgui = globals.imgui
    
    imgui.TextColored(ctx, 0xFFAA00FF, "UI Appearance Settings")
    imgui.Separator(ctx)
    
    -- UI Rounding slider
    local currentRounding = Settings.getSetting("uiRounding")
    imgui.PushItemWidth(ctx, 200)
    local rv, newRounding = imgui.SliderDouble(ctx, "UI Rounding", currentRounding, 0.0, 12.0, "%.1f")
    imgui.PopItemWidth(ctx)
    
    if rv then
        Settings.setSetting("uiRounding", newRounding)
    end
    
    imgui.SameLine(ctx)
    globals.Utils.HelpMarker("Controls the roundness of UI elements like buttons, frames, and sliders. Higher values create more rounded corners.")
    

    -- UI Item Spacing
    local currentSpacing = Settings.getSetting("itemSpacing")
    imgui.PushItemWidth(ctx, 200)
    local rv, newSpacing = imgui.SliderInt(ctx, "UI Spacing", currentSpacing, 0.0, 20.0, "%d")
    imgui.PopItemWidth(ctx)
    
    if rv then
        Settings.setSetting("itemSpacing", newSpacing)
    end

    imgui.SameLine(ctx)
    globals.Utils.HelpMarker("Controls the space between UI elements.")
    
    -- Add color pickers for the three color settings
    Settings.colorPicker("Button Color", "buttonColor")
    Settings.colorPicker("Background Color", "backgroundColor")
    Settings.colorPicker("Text Color", "textColor")
    
    imgui.Separator(ctx)
end

-- Add the crossfade settings section
function Settings.showCrossfadeSettings()
    local ctx = globals.ctx
    local imgui = globals.imgui
    
    imgui.TextColored(ctx, 0xFFAA00FF, "Crossfade Settings")
    imgui.Separator(ctx)
    
    -- Crossfade margin/length setting
    local currentMargin = Settings.getSetting("crossfadeMargin")
    imgui.PushItemWidth(ctx, 200)
    local rv, newMargin = imgui.SliderDouble(ctx, "Crossfade Length (seconds)", currentMargin, 0.05, 2.0, "%.3f")
    imgui.PopItemWidth(ctx)
    
    if rv then
        Settings.setSetting("crossfadeMargin", newMargin)
        -- Synchroniser avec la variable globale si elle existe
        if globals.crossfadeMargin then
            globals.crossfadeMargin = newMargin
        end
    end
    
    imgui.SameLine(ctx)
    globals.Utils.HelpMarker("Determines the length of automatic crossfades created when regenerating content in a time selection. A higher value creates longer and smoother transitions")
    
    imgui.Separator(ctx)
end

return Settings