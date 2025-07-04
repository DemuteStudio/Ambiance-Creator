# Reaper Ambiance Creator

![image](https://github.com/user-attachments/assets/87fe6cd5-9d4c-4109-a7ef-719ebeac0beb)


The **Ambiance Creator** is a tool that makes it easy to create soundscapes by randomly placing audio elements on the REAPER timeline according to user parameters.

We wanted to make ambiance creation and preview for games and linear content as easy and efficient as possible. Here are the main pillars for this tool:

- **Fast creation**: Creating ambiances can be tedious, time-consuming, and repetitive. The idea here is to build a complete ambiance in just a few seconds.
- **Iteration**: Iterating on an ambiance should be as easy as drinking a glass of water.
- **Reusability**: We wanted to be able to save creations as presets.
- **Modularity**: Each part of the ambiance should exist as a separate module that can be reused later.
- **Not context-dependent**: The tool should be useful for both linear and video game workflows.

## Video Tutorial

[I'm a video link](https://www.youtube.com/watch?v=aU6pfuM3aPQ)

## Installing the Ambiance Creator

### Requirements

- **Reaper**: The package was made for Reaper 7.39+ but should work with older versions as well.
- **ReaPack**: Used to import the package into Reaper.
- **ReaImGui**: Used for the whole interface. It's included in the ReaTeam Extensions package, which you can install with ReaPack. To check if it's installed, you should see a ReaImGui tab under the ReaScript tab in Preferences: **Options > Preferences > Plug-ins > ReaImGui**.

### Reapack:
To install Reapack follow these steps:
1. Download Reapack for your platform here(also the user Guide): [Reapack Download](https://reapack.com/user-guide#installation)
2. From REAPER: **Options > Show REAPER resource path in explorer/finder**
3. Put the downloaded file in the **UserPlugins** subdirectory
4. Restart REAPER. Done!

If you have Reapack installed go to **Extensions->Reapack->Import Repositories** paste the following link there and press **Ok**.

--> https://github.com/DemuteStudio/Ambiance-Creator/raw/main/index.xml

Then in **Extensions->Reapack->Manage repositories** you should see **Ambiance Creator** double click it and then press **Install/update Ambiance Creator** and choose **Install all packages in this repository**. It should Install without any errors.

To install **ReaImGui**, find **ReaTeam Extensions** in Manage repositories. Then if you only want ReaImGui Choose **Install individual packages in this repository** and find ReaImGui.



## General Overview

![image](https://github.com/user-attachments/assets/32ece09b-efac-4b81-b17b-c1f6fc023bf2)



The interface is divided into three main sections:

1. **Global section**: This is where you manage global presets, settings, and generate the whole ambiance.
2. **Groups and containers section**: This is where you organize your Groups and Containers.
3. **Parameters section**: This is where you tweak the parameters of Groups and Containers.

The tool works by defining "Groups" that contain "Containers," which group audio elements that will be randomly placed according to your parameters.
This may change in the future to be even more abstract (because who doesn’t love abstraction?).


## Creating/Editing Ambiances in the Ambiance Creator

The very first step is to create your own containers database. The idea is to build a collection of modules (containers) that can be reused over and over. There’s no “right way” to organize groups and containers, but here’s a suggestion.

Let’s say you want to create a Winter Forest. There are lots of different forest types, but all forests are made of two things: fauna and flora. Let’s break these down further:
- Fauna: Birds, Insects, Canidae, ...
- Flora: Leaves, Branches, Grass, Bushes, ...

You might also want to add a third generic category:
- Winds: Strong, Soft, Howling, Gust, ...

Now that we’ve divided our forest into smaller categories, let’s create our first group:
- Press the "Add group" button.
- Name the newly created group "Birds".
  
![image](https://github.com/user-attachments/assets/5c82fde4-8710-4b20-9fde-c09a7aacee5f)


We'll discuss the parameters later, let’s focus on containers for now.
- In the Birds group, press the "Add containers" button to create your first container.
- Name it "Birds - Generic Bed Chirps".

![image](https://github.com/user-attachments/assets/96e7e64d-e109-4f4c-a71c-4e6b42552328)


*IMPORTANT NOTE: The following steps are needed only once per new container.*

Now that we have the beginning of a hierarchy, we need to create the assets that will be used to build the ambiance. So let’s find our best generic bird chirps sound and add them into the session.

![image](https://github.com/user-attachments/assets/98658cbd-79b2-407d-b01e-0107dea77d56)

Here I took a nice generic bed of birds. The file is 1'40 long. I could keep it as one single file, but I chose to split it into 10 parts—you’ll see why later.
Select your items and make sure that the "Birds - Generic Bed Chirps" container is also selected, then press "Import Selected Items" in the right panel.

You should now see all the imported items in the list:

![image](https://github.com/user-attachments/assets/c3c0c082-ccb2-44d0-9171-6cdac8276027)

**Save Presets**
---
Depending on your workflow, this might be a good moment to save this container. You haven’t set any parameters yet, but it contains files that can be recalled and tweaked later.

Let’s see how the preset system works.

When you save a preset, the path of the imported files is saved. By default, Reaper imports your media items into a 'Media Files' directory, located at the project’s root. This means that by default, the item’s path is this directory.
It’s not a problem. BUT! If you delete this folder or the entire project folder, the reference to the item will be lost.
In the Settings, you can choose a Media Item Directory. By default, this field is empty. Once you set a location, all media files will be copied to this directory when you save a preset (if they don’t already exist). This means you’ll have all your file references in the same place. Convenient!

![image](https://github.com/user-attachments/assets/9597f3dd-1580-442e-ad20-1874e545bd2d)

Now that you’ve set up your *Media File Directory*, it’s time to press the "Save Container" button.
By default, it will be named as the container. Feel free to change the name as you wish.

![image](https://github.com/user-attachments/assets/5066689b-0cc8-4d11-aff3-e6f82cd94ebf)

*Note: You can find all your preset files into a dedicated folder accessible by pressing the "Open Preset Directory" button.*

If you work in a team and everyone uses the same directory, it means the preset can be shared and used by anyone with access to this shared directory.

*Note again: It’s not planned to create a customizable "Preset Directory" because it means anyone could delete/override a shared preset. It’s better to keep presets user-side. Share them carefully.*

**Parameters**
---

Now it’s time to customize our container. If you’re familiar with audio middleware, it’s the same logic.
The concept is to define some parameters to give a specific behavior to a container.
Both Groups and Containers have parameters. Containers inherit from their parent group by default.
Depending on the nature of your group, it can be good practice to first set a global rule for trigger and random settings.
But for now, let’s create some specific behavior for our bed of birds.

Select the "Birds - Generic Bed Chirps" container and check the "Override Parent Settings" box. The parameters will appear.

![image](https://github.com/user-attachments/assets/5d9d3708-7eae-408a-97fa-3699896042d0)

Here is a quick explanation of each parameters:

**Trigger Settings**
- Interval Mode: Choice between Absolute, Relative, or Coverage
- Absolute: Fixed interval in seconds (can be negative to create overlaps)
- Relative: Interval expressed as a percentage of the time selection
- Coverage: Percentage of the time selection to fill
- Interval: Time interval between sounds (in seconds or percentage depending on the mode)
- Random variation (%): Percentage of random variation applied to the interval

**Randomize Parameters**
- Randomize Pitch: Enables pitch randomization
- Pitch Range: Variation range in semitones (e.g., -3 to +3)
- Randomize Volume: Enables volume randomization
- Volume Range: Variation range in dB (e.g., -3 to +3)
- Randomize Pan: Enables pan randomization
- Pan Range: Variation range from -100 to +100


The tool is meant to create ambiances of any length. If the total length is 20 minutes but your file is only 1 minute long, it will be copied 20 times.
If you remember, I split the 1'40 long file into 10 pieces. Let’s roll 2d20 and take advantage of that.

Choose the "Absolute" mode and set the interval to a negative value. This value will be the length of the overlap between each item. Let’s say we want a 1-second overlap, so set the interval to -1 second.
We don’t need any variation for this value, so set it to 0%.

Pitch and Volume are up to you. I’ll leave these at their default values.
However, since our bed is supposed to be the foundation of the ambiance, let’s disable random pan.

Your container should look like this:

![image](https://github.com/user-attachments/assets/e9ff62a5-c8c3-4372-bab7-15b2ff21739e)

You can save the container as a preset now if you wish. Keep in mind that with the same preset name, the previous one will be overwritten. Feel free to rename it if you want to have both a raw and a tweaked version.

Now it’s time to test these parameters.
Create a time selection on the Reaper timeline of the desired size.
You’ll see that the previous "No time selection, please create one" message has turned into a "Create Ambiance" button with an option next to it.
We’ll discuss this option in a second. Press the "Create Ambiance" button.

![image](https://github.com/user-attachments/assets/e74a3e6b-1df7-4dd4-a863-391de374c7c4)

Congratulation ! You’ve created your first bed with the tool o//

You’ll notice that the track structure matches the Group/Container.
Each item are placed randomly, overlaps the next with a 1-second crossfade, and the last item has been trimmed precisely at the end of the time selection.

Each item has its own pitch and volume.

![image](https://github.com/user-attachments/assets/468f0715-ffec-47d4-af36-6b3d2bb06184)

If you're not satisfied with the result, you can change the parameters and press the "Regenerate" button next to the container. You can also regenerate a whole group or the whole ambiance. It's up to you. Your call. Your decision. Trust yourself.


- With the "Override existing tracks" checkbox enabled, the track structure will be preserved on each regeneration, no matter the source (Global, Groups, or Container). This is handy if you’ve already tweaked your track volume, pan, FX, etc., and want to keep that but just change the content.
If you change the time selection, only that time selection will be generated. If there’s content in the time selection, it will be deleted and regenerated. The new content will be crossfaded with what’s outside the time selection. The length of this crossfade can be set in the Settings.

![image](https://github.com/user-attachments/assets/41342f0f-c195-46ed-bbae-af818dac1ad9)


- If "Override existing tracks" is disabled, the tracks will be deleted and recreated each time you Generate (It's still local. So if you regenerate only 1 container, only the track related to this container will be deleted/created.)

**Tadaaaa**
---

All right, that’s the whole loop! Now let’s populate our database, play around with the parameters to create reusable containers and modular ambiances!
Once you're done, you can save the whole structure as one single preset "Winter Forest" that can be recalled at any time. You can also save the groups to reuse them in other contexts, or just use the containers to manually build another type of ambiance. The possibilities are endless.


![image](https://github.com/user-attachments/assets/b602d03f-6ef0-4397-b9ef-13664d746d73)


**Settings**
---

You can also customize the interface in the Settings.

![image](https://github.com/user-attachments/assets/b0199a14-b829-4b91-8b05-8b657c220c9e)



## Planned future additions:

- **Volume Slider for Groups and Containers**: A dedicated volume control slider will be added to both groups and containers, allowing for more precise level adjustments without affecting the randomization parameters.
- **Preview Listening for Containers/Groups**: A new function will enable you to preview the sound of a container or an entire group directly within the interface before generating it in REAPER, saving time in the creative process.
- **Advanced File Splitting**: The ability to split longer audio files into multiple segments and randomize their in/out points. This will allow for more variation from a single source file and enable creating evolving soundscapes from fewer original assets.
- **Flexible Group Generation Options**: The ability to generate content into a new group, a specific existing group chosen from a list, or directly into the currently selected group, providing more workflow flexibility and integration with existing projects.
- **Master Group**: A group to rule them all. Allows you to create a master group for better group organization.
- **Settings Menu**: Introduce a user settings menu to offer a certain level of customization, allowing users to tailor the tool to their preferences and workflow needs.
- **Chunk Mode**: Implement a fourth mode that enables the creation of “chunks” of sounds. Instead of randomly spacing sounds across the entire time selection, this mode will allow you to define active sound periods (e.g., 10 seconds of sound followed by 20 seconds of silence), repeating this pattern throughout the selection. This will make it possible to structure sound density more precisely over time.
- **UI Improvements**: Once the core features are complete, the overall user interface will be polished to ensure a cleaner, more intuitive, and visually appealing experience.
- **Action List**: Adds some Reaper actions to manipulate containers outside of the tool interface.
- **Drag and Drop**: Be able to drag and drop items directly into a container instead of using the "Import" button.
- **Reorganize Groups and Containers**: Allow users to manually drag and drop groups and containers to reorganize them.
- **Export**: For video games, allow the extraction of one instance of each item variation, so they can be exported and used to replicate the generated behavior in an audio middleware.
- **Middleware API**: Directly create Random or Sequence containers from the tool in your preferred audio middleware.
- **Multi Channel Management**: Be able to create quad/ambisonic containers
- **Fade System**: Create a whole fade system to configure item's fade wihtin a container



## Known Issues

- Startup and loading can be long on some setup.


##Change log

    1.0
        Initial Release
    1.1
        Fix freeze issue with sliders in the setting windows
    1.2
        Minor updates and improvements  
    1.3
        Partial fixes and improvements
    1.4
        Fix critical ImGui assertion error "Calling End() too many times!"
            - Fixed improper Begin/End pattern that caused crashes when collapsing window or switching between docked/embedded modes
            - Improved stability when switching window states and popup handling
            - No more crashes when clicking collapse arrow or changing dock states
        Fix confusing UI terminology
            - Renamed "Override Existing Track" option to "Keep Existing Track" to properly reflect its actual behavior
            - Inverted internal logic to match the new naming convention
            - Clarified help text to better explain the two generation modes
        Fix track folder structure corruption when adding containers to existing groups
            - Fixed issue where adding a new container to an existing group would change the entire track folder structure
            - New containers now properly inherit folder structure without affecting other tracks
        Fix auto-collapse behavior when removing items from container lists
            - Fixed issue where the "Imported items" section would automatically collapse every time an item was removed
            - Users can now remove multiple items consecutively without having to re-expand the list each time
        Added Drag and Drop functionality
            - Groups can now be reordered by dragging and dropping them
            - Containers can be moved between groups via drag and drop
            - REAPER track structure automatically reorganizes to match the new arrangement
            - Visual feedback during drag operations shows what's being moved

