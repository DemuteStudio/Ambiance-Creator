# User Guide: Ambiance Generator for REAPER

This documentation details how to use the Ambiance Generator, a tool designed to create soundscapes and ambiances in REAPER by randomly placing audio elements according to various parameters.

## Table of Contents

1. Get the Tool
2. General Overview
3. Initial Setup
4. Working Structure: Groups and Containers
5. Randomization Parameters
6. Generating Ambiance  
7. Preset Management
8. Planned Features
9. Known Issue
  

---

## 1. Get the Tool

1. Connect to Github with dev@demute.studio: [https://github.com/DemuteStudio/Ambiance-Creator](https://github.com/DemuteStudio/Ambiance-Creator)
    
2. Clone the repository wherever you want
    
3. Add DM_Ambiance Creator.lua in your Reaper action
    
4. Read the “Known Issues” at the end of this document to avoid doing stuff that will make the tool crash.
    

## 2. General Overview

The Ambiance Generator is a tool that makes it easy to create soundscapes by randomly placing audio elements on the REAPER timeline. The interface is divided into two main panels:

  

- Left: hierarchical organization of Groups and Containers
    
- Right: trigger and randomization parameters
    

  

The tool works by defining "Groups" that contain "Containers," which group audio elements that will be randomly placed according to your parameters.

## 3. Initial Setup

### Asset Preparation

Before generating your ambiance, you need to prepare the audio assets you want to use:

  

1. Select and edit the audio assets you want to include in your ambiance
    
2. Add these assets to containers using the "Import Selected Item" button present on each container
    
3. Once your assets are imported, you can save containers, groups (groups of containers), or even all groups together
    

## 4. Working Structure: Groups and Containers

### Creating the Structure

1. Add a Group: Click the "Add Group" button to create a new group
    
2. Rename a Group: Select the group and modify its name in the "Name" field in the left panel
    
3. Add a Container: Select a group and click "Add Container"
    
4. Rename a Container: Select the container and modify its name in the "Name" field in the right panel
    
5. Navigate the Structure: Use the expansion arrows to show/hide a group's contents
    

### Organizing the Structure

- Groups can contain multiple containers
    
- Each container can contain multiple audio elements
    
- Clicking on a group or container selects it and displays its parameters in the right panel
    

### Managing Elements

- Delete: Use the "Delete" buttons to remove groups or containers
    
- Regenerate: Use the "Regenerate" buttons to recreate elements with new random parameters
    

## 5. Randomization Parameters

### Group Parameters

Groups have parameters that apply to all their containers unless they have the "Override Parent" option enabled:

#### Trigger Settings (Default Trigger Settings)

- Use trigger rate: Activates the trigger mode based on an interval
    
- Interval Mode: Choice between Absolute, Relative, or Coverage
    

- Absolute: Fixed interval in seconds (can be negative to create overlaps)
    
- Relative: Interval expressed as a percentage of the time selection
    
- Coverage: Percentage of the time selection to fill
    

- Interval: Time interval between sounds (in seconds or percentage depending on the mode)
    
- Random variation (%): Percentage of random variation applied to the interval
    

#### Randomization Parameters (Default Randomization parameters)

- Randomize Pitch: Enables pitch randomization
    

- Pitch Range: Variation range in semitones (e.g., -3 to +3)
    

- Randomize Volume: Enables volume randomization
    

- Volume Range: Variation range in dB (e.g., -3 to +3)
    

- Randomize Pan: Enables pan randomization
    

- Pan Range: Variation range from -100 to +100
    

### Container Parameters

Containers can:

  

- Inherit parameters from their parent group (default)
    
- Use their own parameters by enabling "Override Parent"
    

## 6. Generating Ambiance

Once your groups and containers are configured:

  

1. Ensure you have an active time selection in REAPER
    
2. Click the "Create Ambiance" button in the top right
    
3. The tool generates groups in REAPER corresponding to your structure
    
4. Audio elements are placed according to the defined randomization parameters
    

  

To regenerate a specific part:

  

- Use the "Regenerate" button next to a group to recreate all its containers
    
- Use the "Regenerate" button next to a container to recreate only that container
    

## 7. Preset Management

### Global Presets

At the top of the interface:

  

- Refresh: Updates the list of available presets
    
- Load: Loads a selected preset
    
- Save: Saves the current configuration as a preset
    
- Delete: Removes the selected preset
    
- Open Preset Directory: Opens the folder containing preset files
    

### Group and Container Presets

Each group and container can have its own presets:

  

- Load Group/Container: Loads a preset for the selected group/container
    
- Save Group/Container: Saves the current parameters as a preset
    

  

By default, the media files path is set to the location specified in the item properties of the imported assets. You can select a specific media file directory in the Settings menu. When a directory is set this way, all files will be copied into this folder whenever you save a preset (If they don’t already exist).

  

To make it easier to share presets among users within the company, I recommend setting this directory to:

→ Y:\Shared drives\VSTs-Tools-Plugs\Reaper\Tools\Ambiance Tool\Media Item Directory

  

This way, we can share any presets without losing references to the media items.

  

Please note that, depending on the number of new files, saving a preset may take a moment.

  

I’m also planning to implement a similar system for locating preset files, so we won’t even need to manually share them—they’ll all be available in one centralized location.

## 8. Planned Features

  

- Volume Slider for Groups and Containers: A dedicated volume control slider will be added to both groups and containers, allowing for more precise level adjustments without affecting the randomization parameters.
    

- Preview Listening for Containers/Groups: A new function will enable you to preview the sound of a container or an entire group directly within the interface before generating it in REAPER, saving time in the creative process.
    

- Advanced File Splitting: The ability to split longer audio files into multiple segments and randomize their in/out points. This will allow for more variation from a single source file and enable creating evolving soundscapes from fewer original assets.
    

- Flexible Group Generation Options: The ability to generate content into a new group, a specific existing group chosen from a list, or directly into the currently selected group, providing more workflow flexibility and integration with existing projects.
    
- Master Group: A group to rule them all. Allows you to create a master group to have better group organization.
    
- Settings Menu: Introduce a user settings menu to offer a certain level of customization, allowing users to tailor the tool to their preferences and workflow needs.
    

- Chunk Mode: Implement a fourth mode that enables the creation of “chunks” of sounds. Instead of randomly spacing sounds across the entire time selection, this mode allows you to define active sound periods (e.g., 10 seconds of sound followed by 20 seconds of silence), repeating this pattern throughout the selection. This will make it possible to structure sound density more precisely over time.
    
- UI Improvements: Once the core features are complete, the overall user interface will be polished to ensure a cleaner, more intuitive, and visually appealing experience.
    

  

## 9. Known Issues

- None atm
    

  
  
