# Mythic Dungeon Wheel

A World of Warcraft addon that provides an engaging and democratic way for groups to randomly select keystones for Mythic+ dungeons using a smooth scrolling animation and group voting system.

## What This Addon Does

**Mythic Dungeon Wheel** transforms the keystone selection process from "who speaks first" to a fair, animated, and democratic experience. Instead of debating which key to run, simply add all available keystones to a session and let the wheel decide! The addon features:

- **Animated Keystone Selection**: A smooth scrolling animation that builds suspense before revealing the chosen keystone
- **Democratic Voting System**: After a keystone is selected, the group votes whether to accept the wheel's decision
- **Session Management**: Create collaborative sessions where participants can join, leave, and contribute keystones
- **Smart Leave System**: Participants can cleanly leave sessions without disrupting the experience
- **Cross-Client Synchronization**: All party members see the same animation and results simultaneously

## Key Features

### 🎯 **Core Functionality**
- **Democratic Session Management**: Any party member can start sessions; participants can join and leave freely
- **Automated Keystone Detection**: Scans your bags and displays available keystones automatically  
- **Animated Selection Process**: Engaging scrolling animation that gradually slows down before selection
- **Group Voting System**: After selection, the group votes to accept or reject the wheel's choice
- **Session Participant Management**: Clean join/leave system with proper state management

### 🛡️ **Safety & Control**
- **Animation Lock**: Prevents keystone changes during the selection animation
- **Voting Lock**: Blocks leaving sessions during active votes
- **Owner Controls**: Session owners can remove any keystone from the session
- **One Entry Per Player**: Each player can only add one keystone per session
- **State Validation**: Comprehensive error checking and state management

### 🎨 **User Experience**
- **Minimap Integration**: Convenient minimap button with LibDBIcon support and fallback
- **Clean UI**: Intuitive interface showing session status, available keystones, and voting results
- **Visual Feedback**: Color-coded keystone highlighting (green for selected, gray for others)
- **Statistics Tracking**: Tracks how often groups obey or disobey the wheel

## Installation

### Option 1: Download from GitHub Releases (Recommended)
1. Visit the [GitHub Releases page](https://github.com/zborhauer/MythicDungeonWheel/releases)
2. Download the latest `MythicDungeonWheel-v.X.X.X.zip` file
3. Extract the contents to your `World of Warcraft/_retail_/Interface/AddOns/` directory
4. Restart World of Warcraft or type `/reload` in-game

### Option 2: Manual Installation
1. Download or clone this repository
2. Copy the `MythicDungeonWheel` folder to `World of Warcraft/_retail_/Interface/AddOns/`
3. Ensure the structure is: `AddOns/MythicDungeonWheel/MythicDungeonWheel.lua` (and other files)
4. Restart World of Warcraft or use `/reload`

### Verification
- Look for the minimap button (dice icon or question mark)
- Check chat for the addon load message: "MythicDungeonWheel loaded! Use /mdw to open interface"
- Type `/mdw` to open the interface

## Commands Reference

### Basic Commands
| Command | Description |
|---------|-------------|
| `/mdw` | Opens/closes the main interface |
| `/mdw help` | Shows available commands |
| `/mdw debug` | Enables debug mode (unlocks additional commands) |

### Debug Mode Commands
*Enable debug mode first with `/mdw debug`, then use:*

| Command | Description |
|---------|-------------|
| `/mdw start` | Start a new session (any party member) |
| `/mdw leave` | Leave current session (participants only, not during voting) |
| `/mdw reset` | Reset current session (any party member) |
| `/mdw test` | Toggle test mode (adds fake keystones for testing) |
| `/mdw scan` | Force scan bags for keystones |
| `/mdw info` | Show detailed debug information |
| `/mdw stats` | Display wheel decision statistics |
| `/mdw resetStats confirm` | Reset all statistics data |

### Multi-Client Testing Commands
*For developers and advanced users:*

| Command | Description |
|---------|-------------|
| `/mdw testclient join <name>` | Simulate a client joining the session |
| `/mdw testclient leave <name>` | Simulate a client leaving the session |
| `/mdw testclient addkey <name> <level> <dungeon>` | Add keystone for test client |
| `/mdw testsession start <name>` | Simulate another client starting a session |
| `/mdw testsession reset` | Reset and clear all test clients |
| `/mdw testvote yes/no <name>` | Simulate a specific client voting |
| `/mdw testvote auto` | Enable/disable automatic random voting |

## How to Use

### Starting a Session
1. Any party member can start by typing `/mdw start` or using the "Start Session" button
2. Other party members can join by clicking "Join Session" when they open `/mdw`

### Adding Keystones
1. Open the interface with `/mdw`
2. If you're in a session, your available keystones will appear as "Add Your Key" buttons
3. Click to add your keystone to the session
4. You can remove your keystone with "Remove Your Key" if needed

### Rolling for a Keystone
1. Once keystones are added, any participant can click "Get Rolling!"
2. All party members see a synchronized scrolling animation
3. The animation gradually slows down and selects a keystone
4. The selected keystone is highlighted in green

### Voting on Results
1. After a keystone is selected, a 30-second voting window appears
2. All participants vote "Yes" (accept) or "No" (reject) the wheel's choice
3. Majority wins; ties default to "Yes"
4. Non-voters are counted as "No" votes

### Leaving Sessions
1. Participants (not owners) can leave by clicking "Leave Session"
2. Cannot leave during active voting or rolling animations
3. Leaving removes your keystone and clears your view of the session
4. You can rejoin by clicking "Join Session" again

## Files & Dependencies

### Core Files
- **`MythicDungeonWheel.lua`** - Main addon logic (3600+ lines)
- **`MythicDungeonWheel.toc`** - Addon manifest and metadata
- **`MythicDungeonWheel.xml`** - User interface definitions
- **`README.md`** - This documentation
- **`CHANGELOG.md`** - Version history and updates
- **`INSTALL.md`** - Detailed installation instructions

### Development Files
- **`TestScript.lua`** - Development testing utilities (optional)

### Dependencies & Libraries
The addon includes these optional libraries for enhanced functionality:

- **`Libs/LibStub.lua`** - Library loading system
- **`Libs/LibDataBroker-1.1.lua`** - Data broker interface
- **`Libs/LibDBIcon-1.0.lua`** - Minimap button management
- **`Libs/CallbackHandler-1.0.lua`** - Event callback system

**Note**: The addon works without these libraries but provides fallback functionality (e.g., simple minimap button instead of draggable one).

## Troubleshooting

### Common Issues

#### "No keystones found"
- **Solution**: Make sure you have Mythic Keystone items in your bags
- **Debug**: Use `/mdw debug` then `/mdw scan` to force a bag scan
- **Test**: Enable test mode with `/mdw test` to add fake keystones

#### "Cannot start session"
- **Solution**: You need to be in a party or raid group (or enable test mode)
- **Check**: Verify you're in a group with `/who`
- **Test**: Use `/mdw test` to enable solo testing

#### Interface not showing
- **Solution**: Type `/mdw` to toggle the interface
- **Reset**: Try `/reload` to refresh the UI
- **Check**: Look for the minimap button (dice or question mark icon)

#### Voting not working
- **Solution**: Ensure all participants are in the same group and have the addon
- **Check**: Verify voting window appears after keystone selection
- **Debug**: Enable debug mode to see voting status messages

#### Animation desynchronized
- **Solution**: This typically self-corrects; ensure all players have the addon
- **Reset**: Use `/mdw reset` to clear the session and start fresh
- **Update**: Ensure all players have the same addon version

### Debug Information

Enable debug mode with `/mdw debug` to see:
- Keystone detection details
- Session participant status
- Voting progress and results
- Communication message flow
- Animation state information

### Advanced Troubleshooting

#### Complete Reset
```
/mdw debug
/mdw reset
/reload
```

#### Check Addon Status
```
/mdw debug
/mdw info
```

#### Test Basic Functionality
```
/mdw debug
/mdw test
/mdw start
```

## Statistics & Tracking

The addon tracks your group's behavior:
- **Obeyed the Wheel**: Times your group accepted the selected keystone
- **Disobeyed the Wheel**: Times your group rejected the selected keystone
- View with `/mdw debug` then `/mdw stats`

## Technical Notes

### Communication
- Uses secure addon-to-addon communication within your party/raid
- No external servers or data collection
- All messages are encrypted within WoW's addon channel

### Performance
- Lightweight design with minimal memory footprint
- Caches keystone detection to avoid excessive bag scanning
- Optimized UI updates to prevent frame rate drops

### Compatibility
- Works with all WoW retail versions
- No conflicts with other addons
- Graceful fallbacks when libraries are missing

## Support & Feedback

- **Issues**: Report bugs on the [GitHub Issues page](https://github.com/zborhauer/MythicDungeonWheel/issues)
- **Features**: Suggest enhancements via GitHub Issues
- **Debug**: Include output from `/mdw info` when reporting problems

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and feature updates.
