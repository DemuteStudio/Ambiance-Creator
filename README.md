# Reaper Ambiance Creator

TOOL IMAGE

The **Ambiance Creator** is a tool that makes it easy to create soundscapes by randomly placing audio elements on the REAPER timeline. 

We wanted to make ambiance creation and preview for games and linear content as easy and efficient as possible. These were the main pillars for this tool:

- **Fast creation**: Create ambiances can be tedious, take times and can be repetitive. The idea here is to create an complete ambiance in few seconds.
- **Iteration**: Iterate over the ambiance should be as easy as drinking a glass of water.
- **Reusability**: We wanted to be able to save the creation as preset.
- **Modular**: Each part of the ambiance should exist as a separated module that can be reuse later on.
- **Not context dependant**: The tool should be useful for both linear and video games workflow


## Video Tutorial:
Coming soon.


## Installing the Ambiance Creator:

### Requirements:
- **Reaper**: Package was made for reaper 7.22+ but should work for older versions as well.
- **Reapack** : Used to import the package in reaper.
- **ReaImGui**: Used for the whole interface, Is included in the ReaTeam Extensions Package that you can install with Reapack. To check if it is installed, you should have a ReaImGui Tab under the ReaScript tab in the preferences: **options >preferences >Plug-ins >ReaImGui** 

### Reapack:
To install Reapack follow these steps:
1. Download Reapack for your platform here(also the user Guide): [Reapack Download](https://reapack.com/user-guide#installation)
2. From REAPER: **Options > Show REAPER resource path in explorer/finder**
3. Put the downloaded file in the **UserPlugins** subdirectory
4. Restart REAPER. Done!

If you have Reapack installed go to **Extensions->Reapack->Import Repositories** paste the following link there and press **Ok**.

Then in **Extensions->Reapack->Manage repositories** you should see **DM_AmbianceCreator** double click it and then press **Install/update DM_AmbianceCreator** and choose **Install all packages in this repository**. It should Install without any errors.

To install **ReaImGui**, find **ReaTeam Extensions** in Manage repositories. Then if you only want ReaImGui Choose **Install individual packages in this repository** and find ReaImGui.



## General Overview

![image](https://github.com/user-attachments/assets/32ece09b-efac-4b81-b17b-c1f6fc023bf2)



The interface is divided into three main sections:

1) The global section: This where you manage the global presets, settings and generate the whole ambiance
2) The groups and containers section: This is where you organize your Groups and Containers
3) The parameters section: This is where you tweak the parameters of Groups and Containers
    
The tool works by defining "Groups" that contain "Containers," which group audio elements that will be randomly placed according to your parameters.
This is subject to change in the futur to be more abstract.


## Creating/Editing Ambiances in the Ambiance Creator

The very first step is to create your own containers data base. The idea is to build a collection of module (containers) that can be reused over and over. There is no "good way" to organize the groups and container but here is a suggestion.
Let's say you want to create a Winter Forest. There is a lot of different forest type, but all forests are made of 2 things: A fauna and a flora. Let's divide these 2 categories in smaller pieces:
- Fauna: Birds, Insects, Canidae, ...
- Flora: Leaves, Branches, Grass, Bushes, ...

You may also optionnaly want to add a third generic category:
- Winds: Strong, Soft, Howling, Gust, ...

Now that we've divided our forest into smaller catageories, let's create our first group:
- Press the "Add group" button.
- Name the newly created group "Birds".
  
![image](https://github.com/user-attachments/assets/5c82fde4-8710-4b20-9fde-c09a7aacee5f)


We'll discuss the parameters later, let's focus on the containers for now.
- In the Birds groups, press the "Add containers" button to create your first container.
- Name it "Birds - Generic Bed Chirps".

![image](https://github.com/user-attachments/assets/96e7e64d-e109-4f4c-a71c-4e6b42552328)


*IMPORTANT NOTE: The following steps are needed only once for each new containers.*

Now that we have the begining of a hierarchy, we need to create the assets that will be used to build the ambiance. So let's find our best generic bird chirps sound and add them into the session.

![image](https://github.com/user-attachments/assets/98658cbd-79b2-407d-b01e-0107dea77d56)

Here I took a nice generic bed of birds. The file is 1'40 long. I could keep it as 1 single file but I choose to split it into 10 seconds chunk, you'll see why later.
Select your items and make sure that "Birds - Generic Bed Chirps" container is also selected, then press "Import Selected Item" in the right panel.

You should now see all the imported items in the list:

![image](https://github.com/user-attachments/assets/c3c0c082-ccb2-44d0-9171-6cdac8276027)

**Save Presets**
---
Depending on you workflow, it can be a good moment to save this container. You didn't set any parameter on it, but it contains some files that can be recall and tweak for a later use.
Let's see how the Preset system works.
When you save a preset, the path of the imported file is saved. By default, Reaper import your media item into a 'Media Files' directory, located at the project's root. Which means that by default, the item's path is this directory.
It's not a problem. BUT ! If you delete this folder or the entire project folder, the reference to the item will be lost.
In the Settings, you can choose a Media Item Directory. By default this field is empty. Once you set a location, all the media file will be copied to this directory when you save a preset (If they don't already exist). Which means that you will have all your file references at the same place. Convinient !

![image](https://github.com/user-attachments/assets/9597f3dd-1580-442e-ad20-1874e545bd2d)

Now that you've setup your *Media File Directory*, it's time to press the "Save Container" button.
By default, it will be named as the container. Feel free to change the name as you whish.

![image](https://github.com/user-attachments/assets/5066689b-0cc8-4d11-aff3-e6f82cd94ebf)
*Note: You can find all your preset files into a dedicated folder accessible by pressing the "Open Preset Directory" button.*

If you work in a team and all the users in the team use the same directory, it means that the preset can be shared and used by anyone that have access to this shared directory.
*Note again: It's not planned to create a customizable "Preset Directory" because it means that anyone can delete/override a shared preset. It's better to keep the presets on the user side. Share them carefully.*

**Parameters**
---
It's now time to customize our container. If you're familiar with audio middleware, it's the same logic.
The concept is the defined some parameter to give a specific behavior to a container.
Both Groups and Containers have parameters. Containers inherit from their parent parent group by default.
Depending on the nature of your group, it could be a good pratice to first set a general trigger and random settings.
But for now let's create some specific behavior for our bed of birds.

Select the Birds - Generic Bed Chirps container and press the "Override Parent Settings" checkbox. The parameters appears.

![image](https://github.com/user-attachments/assets/5d9d3708-7eae-408a-97fa-3699896042d0)




## Planned future additions:

- **Volume Slider for Groups and Containers**: A dedicated volume control slider will be added to both groups and containers, allowing for more precise level adjustments without affecting the randomization parameters.
    
- **Preview Listening for Containers/Groups**: A new function will enable you to preview the sound of a container or an entire group directly within the interface before generating it in REAPER, saving time in the creative process.
    
- **Advanced File Splitting**: The ability to split longer audio files into multiple segments and randomize their in/out points. This will allow for more variation from a single source file and enable creating evolving soundscapes from fewer original assets.
    
- **Flexible Group Generation Options**: The ability to generate content into a new group, a specific existing group chosen from a list, or directly into the currently selected group, providing more workflow flexibility and integration with existing projects.
    
- **Master Group**: A group to rule them all. Allows you to create a master group to have better group organization.
    
- **Settings Menu**: Introduce a user settings menu to offer a certain level of customization, allowing users to tailor the tool to their preferences and workflow needs.
    
- **Chunk Mode**: Implement a fourth mode that enables the creation of “chunks” of sounds. Instead of randomly spacing sounds across the entire time selection, this mode will allow you to define active sound periods (e.g., 10 seconds of sound followed by 20 seconds of silence), repeating this pattern throughout the selection. This will make it possible to structure sound density more precisely over time.
    
- **UI Improvements**: Once the core features are complete, the overall user interface will be polished to ensure a cleaner, more intuitive, and visually appealing experience.**

- **Action list**: Adds some reaper action to manipulate containers outside of the tool interface.

- **Drag and Drop**: Being able to drag and drop items directly into a container instead of using the "Import" button.

- **Reorganize Groups and Containers**: Allow the use to manually drag and drop groups and containers to reorganize them.



## Known Issues

- None atm
    
