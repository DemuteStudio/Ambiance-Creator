# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The **Ambiance Creator** is a Reaper script for procedural soundscape generation. It allows audio professionals to create complex ambient audio by randomly placing audio elements on the timeline according to user-defined parameters. The tool operates on a hierarchical Group → Container → Audio Items structure.

## Development Environment

### Requirements
- **Reaper**: Version 7.39+ (DAW for which the script is developed)
- **ReaImGui**: Essential UI framework dependency (install via ReaPack)
- **Lua**: Scripting language (built into Reaper)

### File Structure
```
Scripts/
├── DM_Ambiance Creator.lua     # Main entry point
└── Modules/                    # Core functionality modules
    ├── DM_Ambiance_Structures.lua     # Data structures (Groups/Containers)
    ├── DM_Ambiance_Generation.lua     # Audio placement algorithms
    ├── DM_Ambiance_UI.lua             # Main UI orchestration
    ├── DM_Ambiance_Items.lua          # Audio item management
    ├── DM_Ambiance_Presets.lua        # Save/load system
    ├── DM_AmbianceCreator_Settings.lua # User preferences
    └── DM_Ambiance_UI_*.lua           # UI component modules
```

## Core Architecture

### Module System
- **Entry Point**: `DM_Ambiance Creator.lua` initializes all modules with shared `globals` table
- **Modular Design**: Each module exports functions and maintains internal state
- **Cross-Module Communication**: All modules access shared state through `globals` parameter
- **Initialization Pattern**: Every module has `initModule(globals)` function

### Data Hierarchy
1. **Groups**: Top-level containers with generation parameters (trigger rates, randomization)
2. **Containers**: Audio collections within groups, can override parent settings
3. **Audio Items**: Individual sound files with metadata and placement rules

### UI Architecture
- **ReaImGui-based**: Modern immediate-mode GUI framework
- **Component-based**: UI split into logical modules (Groups, Containers, Presets, etc.)
- **State Management**: UI state tracked in `globals` table
- **Popup System**: Modal dialogs managed through `activePopups` tracking

## Development Commands

### Testing the Script
Run the main script in Reaper:
```lua
-- Load in Reaper's Action list or run directly
-- Script will auto-initialize ReaImGui context and module system
```

### Development Workflow
1. Edit modules in `Scripts/Modules/` directory
2. Reload script in Reaper to test changes
3. Use global variable exposure (`_G.globals`, `_G.Utils`, etc.) for runtime debugging
4. Check Reaper's console for Lua errors

### Packaging for Distribution
Use the PowerShell publishing script:
```powershell
.\Publish-ReaPack.ps1
```
This script:
- Updates version numbers in script headers
- Generates ReaPack index.xml
- Commits changes and pushes to GitHub
- Handles changelog management

## Key Implementation Details

### Audio Generation Algorithm
- **Time Selection Based**: Operates within user-defined timeline selections
- **Randomization Parameters**: Pitch, volume, pan with configurable ranges
- **Trigger Modes**: Absolute (fixed intervals), Relative (percentage-based), Coverage (density-based)
- **Overlap Handling**: Supports negative intervals for crossfading

### Preset System
- **Hierarchical Saving**: Save individual containers, groups, or entire projects
- **File Path Management**: Automatic media file copying to configured directory
- **Cross-Session Persistence**: Presets survive Reaper restarts

### Track Management
- **Folder Structure**: Mirrors Group/Container hierarchy in Reaper tracks
- **Generation Modes**: "Keep Existing Track" vs recreate entire structure
- **Drag & Drop**: Groups and containers can be reordered, affecting track structure

## Common Development Patterns

### Adding New UI Components
1. Create module in `Modules/DM_Ambiance_UI_[Component].lua`
2. Implement `initModule(globals)` function
3. Add to UI module imports and initialization
4. Follow ImGui immediate-mode patterns

### Extending Data Structures
1. Modify relevant structure in `DM_Ambiance_Structures.lua`
2. Update serialization in `DM_Ambiance_Presets.lua`
3. Add UI components for new parameters
4. Ensure backward compatibility with existing presets

### Audio Processing Extensions
- Extend `DM_Ambiance_Generation.lua` for new placement algorithms
- Use Reaper API functions for timeline manipulation
- Maintain undo/redo compatibility with `reaper.Undo_BeginBlock()`/`reaper.Undo_EndBlock()`

## Dependencies & External APIs

### Reaper API
- `reaper.*` functions for DAW integration
- Media item manipulation, track management, timeline control
- No external audio processing libraries required

### ReaImGui Specifics
- Version requirement: 0.9.3+
- Context management: Single context per script instance
- Begin/End pairing: Critical for stability (recent bug fixes)

## Version Management

### Version Tracking
- Version stored in script header: `@version 1.4`
- Changelog maintained in same header block
- ReaPack index.xml auto-generated from metadata

### Release Process
1. Update version in main script file
2. Add changelog entry
3. Run `Publish-ReaPack.ps1` for automated publishing
4. Script handles git commits and index generation