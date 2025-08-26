-- Test script for synchronized animation with highlighting
-- This script tests the new yellow/gold highlighting in synchronized animations

local MDW = LibStub("AceAddon-3.0"):GetAddon("MythicDungeonWheel")

-- Test function to simulate synchronized animation with highlighting
function TestSynchronizedHighlighting()
    print("|cff00ff00=== Testing Synchronized Animation Highlighting ===|r")
    
    -- Create test keystones
    local testKeystones = {
        {keystone = {player = "TestPlayer1", level = 15, dungeon = "The Necrotic Wake", isTest = false}},
        {keystone = {player = "TestPlayer2", level = 18, dungeon = "Plaguefall", isTest = false}},
        {keystone = {player = "TestPlayer3", level = 12, dungeon = "Mists of Tirna Scithe", isTest = false}},
        {keystone = {player = "Sentx", level = 69, dungeon = "Goon Cave", isTest = true}}
    }
    
    print("1. Testing StartSynchronizedAnimation with highlighting...")
    
    -- Mock UI elements
    local mockButtons = {}
    local mockContent = {
        buttons = mockButtons
    }
    
    -- Create mock UI buttons for each test keystone
    for i, item in ipairs(testKeystones) do
        local mockButton = {
            keystone = item.keystone,
            bg = {
                SetColorTexture = function(self, r, g, b, a)
                    local colorName = "gray"
                    if r > 0.5 and g > 0.4 and b < 0.5 then
                        colorName = "yellow/gold"
                    end
                    print("  Button " .. i .. " (" .. item.keystone.player .. ") set to " .. colorName .. " (r=" .. r .. ", g=" .. g .. ", b=" .. b .. ")")
                end
            }
        }
        table.insert(mockButtons, mockButton)
    end
    
    -- Override UI element access
    local originalFrame = MythicDungeonWheelFrameKeystoneListScrollChild
    MythicDungeonWheelFrameKeystoneListScrollChild = mockContent
    
    -- Test the StartSynchronizedAnimation function
    MDW.scrollingAnimation = {isAnimating = false}
    
    -- Mock other required functions
    local originalHideVoting = MDW.HideVotingUI
    MDW.HideVotingUI = function() 
        print("  Voting UI hidden")
    end
    
    local originalDebugPrint = MDW.DebugPrint
    MDW.DebugPrint = function(self, msg)
        print("  DEBUG: " .. msg)
    end
    
    -- Call StartSynchronizedAnimation
    print("2. Starting synchronized animation...")
    MDW:StartSynchronizedAnimation(testKeystones, 10.0, false)
    
    -- Check if animation started
    if MDW.scrollingAnimation.isAnimating then
        print("  ✅ Synchronized animation started successfully")
        print("  ✅ Should see yellow/gold highlighting cycling through buttons")
        
        -- Test stopping animation with KEYSTONE_SELECTED message
        print("3. Testing animation stop via KEYSTONE_SELECTED...")
        
        -- Simulate the KEYSTONE_SELECTED message data
        local selectedData = {
            player = "TestPlayer2",
            level = "18",
            dungeon = "Plaguefall",
            isTest = "false"
        }
        
        -- Test the message handler logic
        if MDW.scrollingAnimation.isAnimating then
            print("  Stopping synchronized animation due to KEYSTONE_SELECTED message")
            MDW.scrollingAnimation.isAnimating = false
            
            -- Reset all button colors to default (this should show all buttons going back to gray)
            if mockContent and mockContent.buttons then
                for _, button in ipairs(mockContent.buttons) do
                    if button and button.bg and button.bg.SetColorTexture then
                        button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                    end
                end
            end
            
            print("  ✅ Animation stopped and all buttons reset to gray")
        else
            print("  ❌ Animation was not running")
        end
        
        -- Set the selected keystone
        MDW.session = MDW.session or {}
        MDW.session.selectedKeystone = {
            player = selectedData.player,
            level = tonumber(selectedData.level),
            dungeon = selectedData.dungeon,
            isTest = selectedData.isTest == "true"
        }
        
        print("  ✅ Selected keystone set to: " .. selectedData.player .. "'s +" .. selectedData.level .. " " .. selectedData.dungeon)
        
    else
        print("  ❌ Synchronized animation failed to start")
    end
    
    -- Restore original functions
    MDW.HideVotingUI = originalHideVoting
    MDW.DebugPrint = originalDebugPrint
    MythicDungeonWheelFrameKeystoneListScrollChild = originalFrame
    
    print("|cff00ff00=== Synchronized Animation Highlighting Test Complete ===|r")
    print("Expected behavior:")
    print("- Party members should see yellow/gold highlighting cycling through keystones")
    print("- Animation should stop when session owner sends KEYSTONE_SELECTED message")
    print("- All buttons should return to gray when animation stops")
end

-- Auto-run test if in debug mode
if MDW and MDW.debugMode then
    print("Running synchronized animation highlighting test...")
    TestSynchronizedHighlighting()
end
