-- TestScript.lua
-- Simple test script to demonstrate addon functionality
-- This file is not loaded by the addon, it's for reference only

--[[
To test the addon:

1. Load into WoW and type: /mdw test
   This enables test mode and adds fake keystones

2. Type: /mdw
   This opens the interface

3. If you're the party leader, click "Start Session" or type: /mdw start

4. Click on "Add: +15 Test Dungeon A" to add a keystone to the session

5. Click "Select Random" to randomly pick a keystone

6. Click "Reset" to clear the session and start over

Test Commands:
- /mdw - Open interface
- /mdw test - Toggle test mode (adds fake keystones)
- /mdw start - Start session (leader only)
- /mdw reset - Reset session
- /mdw help - Show help

Test Scenarios:

1. Solo Testing:
   - Enable test mode
   - Start session (works when not in group for testing)
   - Add keystones
   - Select random keystone
   - Reset

2. Group Testing:
   - Form a party with friends
   - Leader starts session
   - Each player adds their keystone
   - Leader selects random keystone
   - Reset for next round

3. Error Testing:
   - Try to start session without being leader
   - Try to add multiple keystones
   - Try to select keystone without being leader
   - Test with no keystones available

Expected Behavior:
- Only leaders can start/reset sessions and select keystones
- Players can only add one keystone per session
- Random selection works with any number of keystones
- Communication works across party members
- Interface updates in real-time
- Test mode provides fake data for development

Debug Information:
- Test keystones are marked with "(TEST)" 
- Chat messages show session state changes
- Interface reflects current session status
- All actions are logged to chat
--]]

-- Mock data for testing (already implemented in main addon)
local TestKeystones = {
    {level = 15, dungeon = "Mists of Tirna Scithe", affixes = "Fortified, Raging, Quaking"},
    {level = 12, dungeon = "The Necrotic Wake", affixes = "Tyrannical, Inspiring, Storming"},
    {level = 18, dungeon = "Plaguefall", affixes = "Fortified, Spiteful, Grievous"},
    {level = 20, dungeon = "Sanguine Depths", affixes = "Tyrannical, Volcanic, Prideful"},
    {level = 16, dungeon = "Spires of Ascension", affixes = "Fortified, Necrotic, Storming"}
}

-- Test communication messages
local TestMessages = {
    SESSION_START = "SESSION_START:leader=TestLeader;",
    SESSION_RESET = "SESSION_RESET",
    KEYSTONE_ADDED = "KEYSTONE_ADDED:player=TestPlayer;level=15;dungeon=Test Dungeon;affixes=Test Affixes;isTest=true;",
    KEYSTONE_SELECTED = "KEYSTONE_SELECTED:player=TestPlayer;level=15;dungeon=Test Dungeon;affixes=Test Affixes;isTest=true;"
}

print("MythicDungeonWheel Test Script Loaded")
print("Use '/mdw test' to enable test mode and start testing!")
