# Mythic Dungeon Wheel - Installation Guide

## What is Mythic Dungeon Wheel?
A World of Warcraft addon that randomly selects keystones for your group and includes a voting system for democratic dungeon selection.

## Features
- Random keystone selection from group members' bags
- Group voting system with 30-second timer
- Statistics tracking (completed runs, voting behavior)
- Minimap button with draggable functionality
- Debug mode for testing and advanced features
- Automatic session management

## Installation Instructions

### Step 1: Download Files
Make sure you have all these files:
- `MythicDungeonWheel.lua`
- `MythicDungeonWheel.toc` 
- `MythicDungeonWheel.xml`
- `Libs/LibStub.lua`
- `Libs/CallbackHandler-1.0.lua`
- `Libs/LibDataBroker-1.1.lua`
- `Libs/LibDBIcon-1.0.lua`

### Step 2: Install Addon
1. Navigate to your World of Warcraft AddOns folder:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```

2. Create a new folder called:
   ```
   MythicDungeonWheel
   ```

3. Copy ALL the addon files (including the `Libs` folder) into this directory

4. Your folder structure should look like:
   ```
   AddOns\
   └── MythicDungeonWheel\
       ├── MythicDungeonWheel.lua
       ├── MythicDungeonWheel.toc
       ├── MythicDungeonWheel.xml
       └── Libs\
           ├── LibStub.lua
           ├── CallbackHandler-1.0.lua
           ├── LibDataBroker-1.1.lua
           └── LibDBIcon-1.0.lua
   ```

### Step 3: Enable Addon
1. Start World of Warcraft
2. At the character selection screen, click "AddOns"
3. Make sure "Mythic Dungeon Wheel" is checked/enabled
4. Log into your character

## How to Use

### Basic Commands
- `/mdw` - Open/close the addon interface
- `/mdw help` - Show all available commands
- `/mdw debug` - Enable debug mode for advanced features

### Group Features
1. **Form a group** - Get together with your friends
2. **Collect keystones** - Make sure group members have keystones in their bags
3. **Start voting** - Group leader uses `/mdw start` or clicks "Start Session"
4. **Vote together** - Everyone votes Yes/No on the selected keystone
5. **Run the dungeon** - If vote passes, go run that keystone!

### Debug Commands (after `/mdw debug`)
- `/mdw scan` - Check what keystones are in your bags
- `/mdw stats` - View your voting statistics
- `/mdw resetStats confirm` - Reset all statistics (careful!)
- `/mdw test` - Enable test mode for single-player testing

## Troubleshooting

**Addon not showing up?**
- Make sure all files are in the correct folder
- Restart World of Warcraft completely
- Check that the addon is enabled in the AddOns list

**Minimap button not working?**
- The basic button will always work
- For enhanced draggable functionality, make sure the Libs folder is included

**Group voting not working?**
- Make sure you're in a group/party
- Only the group leader can start voting sessions
- Make sure group members have the addon installed

## Support
If you encounter issues, enable debug mode (`/mdw debug`) and use `/mdw info` to check the addon status.

---
*Created by Sentex - Version 1.0.0*
