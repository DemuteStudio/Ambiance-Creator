-- DM_AmbianceCreator_Settings.lua
local Settings = {}

local globals = {}
local defaultSettings = {
    mediaItemDirectory = "",  -- Chemin vers le répertoire des médias
    autoImportMedia = true,   -- Copier automatiquement les médias
}

function Settings.initModule(g)
    globals = g
    
    -- Charger les paramètres
    Settings.loadSettings()
    
    -- Vérifier le répertoire média à l'initialisation
    if Settings.getSetting("mediaItemDirectory") == "" then
        -- Si aucun répertoire configuré et qu'on est en exécution normale
        if select(2, reaper.get_action_context()) == debug.getinfo(1, 'S').source:sub(2) then
            reaper.defer(function() 
                globals.showSettingsWindow = true
            end)
        end
    end
end

-- Obtient le chemin de base pour les paramètres (même niveau que le dossier Presets)
function Settings.getSettingsBasePath()
    local basePath = globals.Presets.getPresetsPath("Global"):match("(.+)Global[/\\]")
    return basePath or ""
end

-- Fonction pour vérifier si un répertoire existe de manière fiable
function Settings.directoryExists(path)
    if not path or path == "" then return false end
    
    -- Méthode simple et fiable - essaie de créer/ouvrir un fichier temporaire
    local testFile = path .. "/.test_access"
    local file = io.open(testFile, "w")
    if file then
        file:close()
        os.remove(testFile)
        return true
    end
    return false
end

-- Fonction pour charger les paramètres depuis le fichier
function Settings.loadSettings()
    local settingsFile = Settings.getSettingsBasePath() .. "settings.cfg"
    local file = io.open(settingsFile, "r")
    
    if file then
        local settings = {}
        for line in file:lines() do
            local key, value = line:match("([^=]+)=(.+)")
            if key and value then
                -- Conversion des valeurs booléennes
                if value == "true" then value = true
                elseif value == "false" then value = false
                end
                settings[key] = value
            end
        end
        file:close()
        
        -- Fusionner avec les paramètres par défaut
        globals.settings = {}
        for k, v in pairs(defaultSettings) do
            globals.settings[k] = settings[k] ~= nil and settings[k] or v
        end
    else
        globals.settings = defaultSettings
    end
end

-- Fonction pour sauvegarder les paramètres
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

-- Accesseurs pour les paramètres
function Settings.getSetting(key)
    return globals.settings[key]
end

function Settings.setSetting(key, value)
    globals.settings[key] = value
    Settings.saveSettings()
end

-- Fonction pour configurer le répertoire média
function Settings.setupMediaDirectory()
    local retval, dirPath
    
    -- Essayer avec JS_ReaScriptAPI (méthode la plus fiable)
    if reaper.JS_Dialog_BrowseForFolder then
        retval, dirPath = reaper.JS_Dialog_BrowseForFolder("Sélectionner le répertoire pour les médias", "")
        
        if retval and dirPath and dirPath ~= "" then
            -- Test d'accès au répertoire sans essayer de le créer
            if Settings.directoryExists(dirPath) then
                Settings.setSetting("mediaItemDirectory", dirPath)
                return true
            else
                reaper.ShowMessageBox("Impossible d'accéder à ce répertoire. Vérifiez les permissions.", "Erreur d'accès", 0)
            end
        end
        return false
    end
    
    -- Alternative avec l'extension SWS
    if reaper.BR_Win32_BrowseForDirectory then
        retval, dirPath = reaper.BR_Win32_BrowseForDirectory(reaper.GetResourcePath(), "Sélectionner le répertoire pour les médias")
        
        if retval and dirPath and dirPath ~= "" then
            if Settings.directoryExists(dirPath) then
                Settings.setSetting("mediaItemDirectory", dirPath)
                return true
            else
                reaper.ShowMessageBox("Impossible d'accéder à ce répertoire. Vérifiez les permissions.", "Erreur d'accès", 0)
            end
        end
        return false
    end
    
    -- Fallback: méthode manuelle avec GetUserInputs
    reaper.ShowMessageBox("Veuillez installer l'extension JS_ReaScriptAPI via ReaPack pour une meilleure expérience.", "Extensions recommandées", 0)
    
    retval, dirPath = reaper.GetUserInputs("Sélectionner le répertoire pour les médias", 1, 
                                     "Chemin complet:,extrawidth=300", reaper.GetResourcePath() .. "/Scripts")
    
    if retval and dirPath and dirPath ~= "" then
        if Settings.directoryExists(dirPath) then
            Settings.setSetting("mediaItemDirectory", dirPath)
            return true
        else
            reaper.ShowMessageBox("Le répertoire spécifié n'existe pas ou n'est pas accessible.", "Erreur", 0)
        end
    end
    
    return false
end

-- Fenêtre des paramètres principale
function Settings.showSettingsWindow(open)
    local ctx = globals.ctx
    local imgui = globals.imgui
    
    imgui.SetNextWindowSize(ctx, 500, 300, imgui.Cond_FirstUseEver)
    local visible, open = imgui.Begin(ctx, 'Ambiance Creator Settings', open)
    
    if visible then
        imgui.TextColored(ctx, 0xFFAA00FF, "Media Management Settings")
        imgui.Separator(ctx)
        
        -- Répertoire des médias
        imgui.Text(ctx, "Media Item Directory")
        
        local mediaDir = Settings.getSetting("mediaItemDirectory")
        if mediaDir == "" then
            mediaDir = "No directory selected"
            imgui.TextColored(ctx, 0xFF0000FF, "Warning: No media directory configured")
        end
        
        -- Afficher le chemin actuel (non éditable)
        imgui.PushItemWidth(ctx, 350)
        imgui.InputText(ctx, "##MediaDir", mediaDir, imgui.InputTextFlags_ReadOnly)
        
        -- Bouton pour changer de répertoire
        imgui.SameLine(ctx)
        if imgui.Button(ctx, "Browse") then
            Settings.setupMediaDirectory()
        end
        
        -- Paramètres d'importation automatique
        local rv, autoImport = imgui.Checkbox(ctx, "Automatically import media files when saving presets", 
                                             Settings.getSetting("autoImportMedia"))
        if rv then
            Settings.setSetting("autoImportMedia", autoImport)
        end

        --Tooltip
        imgui.SameLine(globals.ctx)
        globals.Utils.HelpMarker("- Enabled: Automatically copies all media files referenced in your presets to the central media directory when saving. This ensures your presets remain functional even if original files are moved or deleted.\n\n"..
                                 "- Disabled: Presets will maintain references to the original file locations without creating copies, which saves disk space but makes presets dependent on the original file locations.")
        
        -- Bouton pour ouvrir le répertoire
        if mediaDir ~= "No directory selected" then
            if imgui.Button(ctx, "Open Media Directory") then
                -- Utiliser os.execute directement pour éviter les dépendances
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
        
        -- Boutons de contrôle
        if imgui.Button(ctx, "Save & Close", 120, 0) then
            Settings.saveSettings()
            open = false
        end
    end
    
    imgui.End(ctx)
    
    -- Gérer le popup de configuration du répertoire
    Settings.handleSetupMediaDirectoryPopup()
    
    return open
end

-- Popup pour configurer le répertoire des médias
function Settings.handleSetupMediaDirectoryPopup()
    local ctx = globals.ctx
    local imgui = globals.imgui
    
    if imgui.BeginPopupModal(ctx, "Setup Media Directory", nil, imgui.WindowFlags_AlwaysAutoResize) then
        imgui.Text(ctx, "Vous devez configurer un répertoire pour vos fichiers média")
        imgui.TextWrapped(ctx, "Ce répertoire sera utilisé pour stocker les copies de tous les médias utilisés dans vos presets.")
        
        -- Afficher le chemin actuel
        local mediaDir = Settings.getSetting("mediaItemDirectory") or ""
        if mediaDir ~= "" then
            imgui.Text(ctx, "Répertoire actuel:")
            imgui.PushStyleColor(ctx, imgui.Col_Text, 0x00AA00FF)
            imgui.Text(ctx, mediaDir)
            imgui.PopStyleColor(ctx)
        end
        
        -- Bouton pour ouvrir le sélecteur
        if imgui.Button(ctx, "Sélectionner un répertoire...", 200, 0) then
            local success = Settings.setupMediaDirectory()
            if success then
                imgui.CloseCurrentPopup(ctx)
            end
        end
        
        imgui.SameLine(ctx)
        if imgui.Button(ctx, "Annuler", 120, 0) then
            imgui.CloseCurrentPopup(ctx)
        end
        
        imgui.EndPopup(ctx)
    end
end

-- Vérifier si un fichier existe
function Settings.fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Copier un fichier
function Settings.copyFile(source, dest)
    -- Ouvrir le fichier source
    local sourceFile = io.open(source, "rb")
    if not sourceFile then
        return false
    end
    
    -- Lire le contenu
    local content = sourceFile:read("*all")
    sourceFile:close()
    
    -- Écrire dans le fichier de destination
    local destFile = io.open(dest, "wb")
    if not destFile then
        return false
    end
    
    destFile:write(content)
    destFile:close()
    
    return true
end

-- Fonction pour copier un fichier média vers le répertoire configuré
function Settings.copyMediaFile(sourcePath)
    local mediaDir = Settings.getSetting("mediaItemDirectory")
    if mediaDir == "" or not sourcePath or sourcePath == "" then
        return sourcePath, false
    end
    
    -- Extraire le nom du fichier
    local fileName = sourcePath:match("([^/\\]+)$")
    if not fileName then
        return sourcePath, false
    end
    
    -- Construire le chemin de destination
    local destPath = mediaDir
    if not destPath:match("[/\\]$") then
        destPath = destPath .. "/"
    end
    destPath = destPath .. fileName
    
    -- Éviter de recopier si le fichier existe déjà
    if Settings.fileExists(destPath) then
        return destPath, true
    end
    
    -- Copier le fichier
    local success = Settings.copyFile(sourcePath, destPath)
    
    return destPath, success
end

-- Traiter les médias d'un conteneur
function Settings.processContainerMedia(container)
    if not container or not container.items then
        return container
    end
    
    -- Copier les médias de tous les items
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

return Settings
