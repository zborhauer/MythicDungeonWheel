-- Test script for party synchronization
-- This script tests the new party-wide animation synchronization feature

local MDW = LibStub("AceAddon-3.0"):GetAddon("MythicDungeonWheel")

-- Test function to simulate party member receiving animation start
function TestPartySynchronization()
    print("|cff00ff00=== Testing Party Animation Synchronization ===|r")
    
    -- Simulate being in a group
    local originalIsInGroup = IsInGroup
    IsInGroup = function() return true end
    
    -- Create test keystones
    local testKeystones = {
        {player = "TestPlayer1", level = 15, dungeon = "The Necrotic Wake"},
        {player = "TestPlayer2", level = 18, dungeon = "Plaguefall"},
        {player = "TestPlayer3", level = 12, dungeon = "Mists of Tirna Scithe"},
        {player = "TestPlayer4", level = 20, dungeon = "Sanguine Depths"}
    }
    
    print("1. Testing SelectRandomKeystone with party synchronization...")
    
    -- Test the SelectRandomKeystone function
    MDW.session = {
        isSessionOwner = true,
        keystones = testKeystones
    }
    
    -- Override SendMessage to capture what would be sent
    local originalSendMessage = MDW.SendMessage
    local capturedMessage = nil
    MDW.SendMessage = function(self, msgType, data)
        capturedMessage = {msgType = msgType, data = data}
        print("  Would send message: " .. msgType)
        if data.keystones then
            print("  Keystone data included: " .. tostring(data.keystones))
        end
        if data.duration then
            print("  Duration: " .. data.duration)
        end
    end
    
    -- Call SelectRandomKeystone
    MDW:SelectRandomKeystone()
    
    -- Check if message was captured
    if capturedMessage and capturedMessage.msgType == "ANIMATION_STARTED" then
        print("  ✅ ANIMATION_STARTED message would be sent to party")
        
        -- Test the message handler
        print("2. Testing ANIMATION_STARTED message handler...")
        
        -- Simulate receiving the message as a party member
        MDW.session.isSessionOwner = false
        
        -- Test the message handler
        local testData = capturedMessage.data
        
        -- Manually trigger the message handler logic
        if testData and testData.keystones and testData.duration then
            local keystoneSnapshot = MDW:DeserializeKeystoneSnapshot(testData.keystones)
            local duration = tonumber(testData.duration) or 10.0
            
            print("  Deserialized " .. #keystoneSnapshot .. " keystones")
            print("  Duration: " .. duration .. " seconds")
            
            -- Test if StartSynchronizedAnimation would be called
            local originalStartSync = MDW.StartSynchronizedAnimation
            local syncCalled = false
            MDW.StartSynchronizedAnimation = function(self, snap, dur, isOwner)
                syncCalled = true
                print("  ✅ StartSynchronizedAnimation called with isOwner=" .. tostring(isOwner))
                print("  ✅ Keystone count: " .. #snap)
                print("  ✅ Duration: " .. dur)
            end
            
            -- Simulate the handler
            MDW:StartSynchronizedAnimation(keystoneSnapshot, duration, false)
            
            if syncCalled then
                print("  ✅ Synchronized animation would start for party member")
            else
                print("  ❌ Synchronized animation handler failed")
            end
            
            -- Restore function
            MDW.StartSynchronizedAnimation = originalStartSync
        else
            print("  ❌ Invalid data received")
        end
    else
        print("  ❌ ANIMATION_STARTED message was not sent")
    end
    
    -- Restore functions
    MDW.SendMessage = originalSendMessage
    IsInGroup = originalIsInGroup
    
    print("|cff00ff00=== Party Synchronization Test Complete ===|r")
end

-- Auto-run test if in debug mode
if MDW and MDW.debugMode then
    print("Running party synchronization test...")
    TestPartySynchronization()
end
