--[[
Sound Randomizer for REAPER
This script provides a GUI interface for creating randomized ambient sounds
It allows creating tracks with containers of audio items that can be randomized by pitch, volume, and pan
Uses ReaImGui for UI rendering
]]

local UI = {}
local globals = {}

local Utils = require("DM_Ambiance_Utils")
local Structures = require("DM_Ambiance_Structures")
local Items = require("DM_Ambiance_Items")
local Presets = require("DM_Ambiance_Presets")
local Generation = require("DM_Ambiance_Generation")

-- Import UI modules
local UI_Preset = require("DM_Ambiance_UI_Preset")
local UI_Container = require("DM_Ambiance_UI_Container")
local UI_Tracks = require("DM_Ambiance_UI_Tracks")
local UI_MultiSelection = require("DM_Ambiance_UI_MultiSelection")

-- Initialize the module with global variables from the main script
function UI.initModule(g)
    globals = g
    
    -- Initialize selection tracking variables for two-panel layout
    globals.selectedTrackIndex = nil
    globals.selectedContainerIndex = nil
    
    -- Initialize structure for multi-selection
    globals.selectedContainers = {} -- Format: {[trackIndex_containerIndex] = true}
    globals.inMultiSelectMode = false
    
    -- Initialize variables for Shift multi-selection
    globals.shiftAnchorTrackIndex = nil
    globals.shiftAnchorContainerIndex = nil
    
    -- Initialize UI sub-modules
    UI_Preset.initModule(globals)
    UI_Container.initModule(globals)
    UI_Tracks.initModule(globals)
    UI_MultiSelection.initModule(globals)
end

-- Function to clear all container selections
local function clearContainerSelections()
  globals.selectedContainers = {}
  globals.inMultiSelectMode = false
  
  -- Also clear the shift anchor when clearing selections
  globals.shiftAnchorTrackIndex = nil
  globals.shiftAnchorContainerIndex = nil
end


-- Function to check if a container is selected
local function isContainerSelected(trackIndex, containerIndex)
  return globals.selectedContainers[trackIndex .. "_" .. containerIndex] == true
end

-- Function to toggle container selection
local function toggleContainerSelection(trackIndex, containerIndex)
  local key = trackIndex .. "_" .. containerIndex
  if globals.selectedContainers[key] then
      globals.selectedContainers[key] = nil
  else
      globals.selectedContainers[key] = true
  end
  
  -- Update primary selection for compatibility
  globals.selectedTrackIndex = trackIndex
  globals.selectedContainerIndex = containerIndex
end

-- Function to select a range of containers between two points
local function selectContainerRange(startTrackIndex, startContainerIndex, endTrackIndex, endContainerIndex)
  -- Clear existing selection first if not in multi-select mode
  if not (reaper.ImGui_GetKeyMods(globals.ctx) & reaper.ImGui_Mod_Ctrl() ~= 0) then
      clearContainerSelections()
  end
  
  -- Handle range selection within the same track
  if startTrackIndex == endTrackIndex then
      local track = globals.tracks[startTrackIndex]
      local startIdx = math.min(startContainerIndex, endContainerIndex)
      local endIdx = math.max(startContainerIndex, endContainerIndex)
      
      for i = startIdx, endIdx do
          if i <= #track.containers then
              globals.selectedContainers[startTrackIndex .. "_" .. i] = true
          end
      end
      return
  end
  
  -- Handle range selection across different tracks
  local startTrack = math.min(startTrackIndex, endTrackIndex)
  local endTrack = math.max(startTrackIndex, endTrackIndex)
  
  -- If selecting from higher track to lower track, reverse the container indices
  local firstContainerIdx, lastContainerIdx
  if startTrackIndex < endTrackIndex then
      firstContainerIdx, lastContainerIdx = startContainerIndex, endContainerIndex
  else
      firstContainerIdx, lastContainerIdx = endContainerIndex, startContainerIndex
  end
  
  -- Select all containers in the range
  for t = startTrack, endTrack do
      if globals.tracks[t] then
          if t == startTrack then
              -- First track: select from firstContainerIdx to end
              for c = firstContainerIdx, #globals.tracks[t].containers do
                  globals.selectedContainers[t .. "_" .. c] = true
              end
          elseif t == endTrack then
              -- Last track: select from start to lastContainerIdx
              for c = 1, lastContainerIdx do
                  globals.selectedContainers[t .. "_" .. c] = true
              end
          else
              -- Middle tracks: select all containers
              for c = 1, #globals.tracks[t].containers do
                  globals.selectedContainers[t .. "_" .. c] = true
              end
          end
      end
  end
  
  -- Update the multi-select mode flag
  globals.inMultiSelectMode = UI_Tracks.getSelectedContainersCount() > 1
end

-- Function to draw the left panel containing tracks and containers list
local function drawLeftPanel(width)
  UI_Tracks.drawTracksPanel(width, isContainerSelected, toggleContainerSelection, clearContainerSelections, selectContainerRange)
end


-- Function to draw the right panel containing detailed settings for the selected container
local function drawRightPanel(width)
  -- If we're in multi-select mode, draw the multi-selection panel
  if globals.inMultiSelectMode then
      UI_MultiSelection.drawMultiSelectionPanel(width)
      return
  end
  
  -- Show container details if a container is selected
  if globals.selectedTrackIndex and globals.selectedContainerIndex then
      -- Utiliser le module UI_Container pour afficher les paramètres du conteneur
      UI_Container.displayContainerSettings(globals.selectedTrackIndex, globals.selectedContainerIndex, width)
  elseif globals.selectedTrackIndex then
      -- Show track details if only a track is selected
      local track = globals.tracks[globals.selectedTrackIndex]
      reaper.ImGui_Text(globals.ctx, "Track Settings: " .. track.name)
      reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Select a container to view and edit its settings.")
  else
      -- No selection
      reaper.ImGui_TextColored(globals.ctx, 0xFFAA00FF, "Select a track or container to view and edit its settings.")
  end
end

-- Function to handle popup management and timeout
local function handlePopups()
  -- Check for any popup that might be stuck (safety measure)
  for name, popup in pairs(globals.activePopups) do
      if popup.active and reaper.time_precise() - popup.timeOpened > 5 then
          -- Force close popups that have been open too long (5 seconds)
          reaper.ImGui_CloseCurrentPopup(globals.ctx)
          globals.activePopups[name] = nil
      end
  end
end

-- Main interface loop - this is called repeatedly to render the UI
function UI.mainLoop()
  -- Begin the main window
  local visible, open = reaper.ImGui_Begin(globals.ctx, 'Sound Randomizer', true)
  
  if visible then
      -- Section with presets controls at the top
      UI_Preset.drawPresetControls()
      
      -- Button to generate all tracks and place items - moved to top, with custom styling
      reaper.ImGui_SameLine(globals.ctx)
      reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_Button(), 0xFF4CAF50) -- Green button
      reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF66BB6A) -- Lighter green when hovered
      reaper.ImGui_PushStyleColor(globals.ctx, reaper.ImGui_Col_ButtonActive(), 0xFF43A047) -- Darker green when clicked
      
      if reaper.ImGui_Button(globals.ctx, "Create Ambiance", 150, 30) then
          Generation.generateTracks()
      end
      
      -- Pop styling colors to return to default
      reaper.ImGui_PopStyleColor(globals.ctx, 3)
      
      -- Display time selection information
      if Utils.checkTimeSelection() then
          reaper.ImGui_Text(globals.ctx, "Time Selection: " .. Utils.formatTime(globals.startTime) .. " - " .. Utils.formatTime(globals.endTime) .. " | Length: " .. Utils.formatTime(globals.endTime - globals.startTime))
      else
          reaper.ImGui_TextColored(globals.ctx, 0xFF0000FF, "No time selection! Please create one.")
      end
      
      reaper.ImGui_Separator(globals.ctx)
      
      -- Calculate dimensions for the split view layout
      local windowWidth = reaper.ImGui_GetWindowWidth(globals.ctx)
      local leftPanelWidth = windowWidth * 0.35
      local rightPanelWidth = windowWidth * 0.63
      
      -- Left panel (Tracks & Containers list)
      reaper.ImGui_BeginChild(globals.ctx, "LeftPanel", leftPanelWidth, 0)
      drawLeftPanel(leftPanelWidth)
      reaper.ImGui_EndChild(globals.ctx)
      
      -- Right panel (Container Settings)
      reaper.ImGui_SameLine(globals.ctx)
      reaper.ImGui_BeginChild(globals.ctx, "RightPanel", rightPanelWidth, 0)
      drawRightPanel(rightPanelWidth)
      reaper.ImGui_EndChild(globals.ctx)
      
      -- End the main window
      reaper.ImGui_End(globals.ctx)
  end
  
  -- Handle popup management
  handlePopups()
  
  -- Defer next UI refresh or destroy context if window is closed
  if open then
      reaper.defer(UI.mainLoop)
  else
      reaper.ImGui_DestroyContext(globals.ctx)
  end
end

return UI
