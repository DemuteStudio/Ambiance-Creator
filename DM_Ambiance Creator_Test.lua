-- Sound Randomizer - Reaper Script
-- Allows creating tracks and containers to organize audio samples with advanced preset management
-- Features selective regeneration of individual tracks and containers

-- Checking if ReaImGui exists
if not reaper.ImGui_CreateContext then
  reaper.MB("This script requires ReaImGui. Please install the extension via ReaPack.", "Error", 0)
  return
end

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

-- Initialization
local ctx = reaper.ImGui_CreateContext('Ambiance Creator')

-- Global variables
local tracks = {}
local timeSelectionValid = false
local startTime, endTime = 0, 0
local timeSelectionLength = 0

-- Variables for preset management
local currentPresetName = ""
local presetsPath = ""

-- Variables for container and track preset management
local selectedTrackPresetIndex = {}
local selectedContainerPresetIndex = {}
local currentSaveTrackIndex = nil
local currentSaveContainerTrack = nil
local currentSaveContainerIndex = nil
local newTrackPresetName = ""
local newContainerPresetName = ""

-- Variables for the interface
local newPresetName = ""
local selectedPresetIndex = -1

-- Variables to track active popups, avoid window flashing issues
local activePopups = {}

-- Random number generator initialization
math.randomseed(os.time())

-- Partage des variables globales avec les modules
local globals = {
  ctx = ctx,
  tracks = tracks,
  timeSelectionValid = timeSelectionValid,
  startTime = startTime,
  endTime = endTime,
  timeSelectionLength = timeSelectionLength,
  currentPresetName = currentPresetName,
  presetsPath = presetsPath,
  selectedTrackPresetIndex = selectedTrackPresetIndex,
  selectedContainerPresetIndex = selectedContainerPresetIndex,
  currentSaveTrackIndex = currentSaveTrackIndex,
  currentSaveContainerTrack = currentSaveContainerTrack,
  currentSaveContainerIndex = currentSaveContainerIndex,
  newTrackPresetName = newTrackPresetName,
  newContainerPresetName = newContainerPresetName,
  newPresetName = newPresetName,
  selectedPresetIndex = selectedPresetIndex,
  activePopups = activePopups,
  
  -- Ajout des modules dans l'objet globals
  Utils = Utils,
  Structures = Structures,
  Items = Items,
  Presets = Presets,
  Generation = Generation,
  UI = UI
}

-- Partage des globals avec tous les modules
Utils.initModule(globals)
Structures.initModule(globals)
Items.initModule(globals)
Presets.initModule(globals)
Generation.initModule(globals)
UI.initModule(globals)

-- Initialize the presets path at startup
presetsPath = ""  -- Reset to force proper folder creation
Presets.getPresetsPath("Global")
Presets.getPresetsPath("Tracks")

-- Start the main loop
reaper.defer(UI.mainLoop)
