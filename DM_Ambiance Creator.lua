-- Sound Randomizer - Reaper Script
-- Allows creating groups and containers to organize audio samples with advanced preset management
-- Features selective regeneration of individual groups and containers

-- Checking if ReaImGui exists
if not reaper.ImGui_CreateContext then
    reaper.MB("This script requires ReaImGui. Please install the extension via ReaPack.", "Error", 0)
    return
end

-- Initialisation correcte de ReaImGui selon les recommandations du développeur
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.9.3'

-- Définir le chemin pour les modules
local script_path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "modules/?.lua;" .. package.path

-- Importation des modules
local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")
local UI = require("DM_Ambiance_UI")

-- Variables globales
local globals = {
    groups = {},
    timeSelectionValid = false,
    startTime = 0,
    endTime = 0,
    timeSelectionLength = 0,
    currentPresetName = "",
    presetsPath = "",
    selectedGroupPresetIndex = {},
    selectedContainerPresetIndex = {},
    currentSaveGroupIndex = nil,
    currentSaveContainerGroup = nil,
    currentSaveContainerIndex = nil,
    newGroupPresetName = "",
    newContainerPresetName = "",
    newPresetName = "",
    selectedPresetIndex = -1,
    activePopups = {}
}

-- Fonction loop suivant les recommandations du développeur
local function loop()
    UI.PushStyle()
    local open = UI.ShowMainWindow(true)
    UI.PopStyle()

    if open then
        reaper.defer(loop)
    end
    -- Note: DestroyContext n'est plus nécessaire dans les versions récentes de ReaImGui
end

-- N'exécute le code que si le script est lancé directement
if select(2, reaper.get_action_context()) == debug.getinfo(1, 'S').source:sub(2) then
    -- Expose les variables pour le débogage
    _G.globals = globals
    _G.Utils = Utils
    _G.Structures = Structures
    _G.Items = Items
    _G.Presets = Presets
    _G.Generation = Generation
    _G.UI = UI
    _G.imgui = imgui
    
    -- Initialisation du générateur de nombres aléatoires
    math.randomseed(os.time())
    
    -- Création du contexte ImGui selon les recommandations
    local ctx = imgui.CreateContext('Ambiance Creator')
    globals.ctx = ctx
    globals.imgui = imgui
    
    -- Partage des modules avec globals
    globals.Utils = Utils
    globals.Structures = Structures
    globals.Items = Items
    globals.Presets = Presets
    globals.Generation = Generation
    globals.UI = UI
    
    -- Initialisation des modules
    Utils.initModule(globals)
    Structures.initModule(globals)
    Items.initModule(globals)
    Presets.initModule(globals)
    Generation.initModule(globals)
    UI.initModule(globals)
    
    -- Initialisation des chemins de presets
    globals.presetsPath = "" -- Reset pour forcer la création du dossier
    Presets.getPresetsPath("Global")
    Presets.getPresetsPath("Groups")
    
    -- Démarrage de la boucle principale
    reaper.defer(loop)
end
