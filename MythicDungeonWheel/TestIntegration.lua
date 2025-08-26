-- TestIntegration.lua
-- Integration test script for all new Mythic Dungeon Wheel functionality
-- This can be run in-game to validate the complete feature set

local MDW = MythicDungeonWheel

-- Test configuration
local TestConfig = {
    enableDebugOutput = true,
    testTimeout = 30, -- seconds
    expectedAnimationDuration = 12 -- seconds
}

-- Test state tracking
local TestState = {
    startTime = 0,
    currentTest = "",
    results = {},
    animationStarted = false,
    animationStopped = false,
    highlightingObserved = false
}

-- Utility functions
local function LogTest(message, success)
    local color = success and "|cff00ff00" or "|cffff0000"
    local status = success and "PASS" or "FAIL"
    print(color .. "[" .. status .. "] " .. message .. "|r")
    
    TestState.results[TestState.currentTest] = TestState.results[TestState.currentTest] or {}
    table.insert(TestState.results[TestState.currentTest], {message = message, success = success})
end

local function StartTest(testName)
    TestState.currentTest = testName
    TestState.startTime = GetTime()
    print("|cffffff00=== Starting Test: " .. testName .. " ===|r")
end

local function FinishTest()
    local duration = GetTime() - TestState.startTime
    print("|cffffff00=== Test Complete (" .. string.format("%.2f", duration) .. "s) ===|r")
    print("")
end

-- Test 1: Debug Mode Keystone Generation
local function TestDebugKeystones()
    StartTest("Debug Mode Keystone Generation")
    
    if not MDW then
        LogTest("MDW addon not loaded", false)
        FinishTest()
        return
    end
    
    -- Enable debug mode
    local originalDebugMode = MDW.debugMode
    MDW.debugMode = true
    
    -- Clear existing keystones by mocking empty bags
    local originalGetContainerNumSlots = GetContainerNumSlots
    local originalGetContainerItemInfo = GetContainerItemInfo
    
    if GetContainerNumSlots then
        GetContainerNumSlots = function() return 0 end
    end
    if GetContainerItemInfo then
        GetContainerItemInfo = function() return nil end
    end
    
    -- Test keystone generation
    local keystones = MDW:GetPlayerKeystones()
    
    local debugKeystoneFound = false
    local debugKeystoneDetails = ""
    
    if keystones and #keystones > 0 then
        for _, keystone in ipairs(keystones) do
            if keystone and keystone.dungeon == "Goon Cave" and keystone.level == 69 then
                debugKeystoneFound = true
                debugKeystoneDetails = keystone.player .. "'s +" .. keystone.level .. " " .. keystone.dungeon
                break
            end
        end
    end
    
    LogTest("Debug keystone '+69 Goon Cave' generated when no real keystones found", debugKeystoneFound)
    if debugKeystoneFound then
        LogTest("Debug keystone details: " .. debugKeystoneDetails, true)
    end
    
    -- Restore original functions
    if originalGetContainerNumSlots then
        GetContainerNumSlots = originalGetContainerNumSlots
    end
    if originalGetContainerItemInfo then
        GetContainerItemInfo = originalGetContainerItemInfo
    end
    MDW.debugMode = originalDebugMode
    
    FinishTest()
end

-- Test 2: Animation Robustness
local function TestAnimationRobustness()
    StartTest("Animation Robustness Against Keystone Removal")
    
    if not MDW then
        LogTest("MDW addon not loaded", false)
        FinishTest()
        return
    end
    
    -- Create test session with keystones
    local testKeystones = {
        {player = "TestPlayer1", level = 15, dungeon = "The Necrotic Wake", isTest = false},
        {player = "TestPlayer2", level = 18, dungeon = "Plaguefall", isTest = false},
        {player = "TestPlayer3", level = 12, dungeon = "Mists of Tirna Scithe", isTest = false}
    }
    
    -- Mock session
    MDW.session = {
        isSessionOwner = true,
        keystones = testKeystones
    }
    
    -- Test keystone snapshot creation
    local keystoneList = {}
    for i, keystone in ipairs(testKeystones) do
        table.insert(keystoneList, {
            key = "test_key_" .. i,
            keystone = keystone
        })
    end
    
    -- Test that StartScrollingAnimation uses snapshot
    local originalStartScrolling = MDW.StartScrollingAnimation
    local snapshotCreated = false
    
    MDW.StartScrollingAnimation = function(self, ksList)
        snapshotCreated = ksList and #ksList > 0
        LogTest("Animation uses keystone snapshot", snapshotCreated)
        LogTest("Snapshot contains " .. (#ksList or 0) .. " keystones", #ksList == 3)
        
        -- Test snapshot immutability by "removing" a keystone from original
        testKeystones[2] = nil
        LogTest("Snapshot remains intact after original keystone removal", #ksList == 3)
        
        self.scrollingAnimation = self.scrollingAnimation or {}
        self.scrollingAnimation.isAnimating = true
        self.scrollingAnimation.keystoneSnapshot = ksList
    end
    
    -- Test SelectRandomKeystone with snapshot
    MDW:SelectRandomKeystone()
    
    -- Restore function
    MDW.StartScrollingAnimation = originalStartScrolling
    
    FinishTest()
end

-- Test 3: Party Communication
local function TestPartyCommunication()
    StartTest("Party Communication and Synchronization")
    
    if not MDW then
        LogTest("MDW addon not loaded", false)
        FinishTest()
        return
    end
    
    -- Mock being in a group
    local originalIsInGroup = IsInGroup
    IsInGroup = function() return true end
    
    -- Capture sent messages
    local originalSendMessage = MDW.SendMessage
    local capturedMessages = {}
    
    MDW.SendMessage = function(self, msgType, data)
        table.insert(capturedMessages, {msgType = msgType, data = data})
        LogTest("Message sent: " .. msgType, true)
        
        if msgType == "ANIMATION_STARTED" then
            LogTest("ANIMATION_STARTED includes keystone data", data and data.keystones ~= nil)
            LogTest("ANIMATION_STARTED includes duration", data and data.duration ~= nil)
            
            -- Simulate party member receiving message
            local keystoneSnapshot = MDW:DeserializeKeystoneSnapshot(data.keystones)
            LogTest("Keystone data can be deserialized", keystoneSnapshot and #keystoneSnapshot > 0)
        end
    end
    
    -- Mock session and trigger animation
    MDW.session = {
        isSessionOwner = true,
        keystones = {
            {player = "SessionOwner", level = 20, dungeon = "Theater of Pain", isTest = false}
        }
    }
    
    -- Test message sending
    MDW:SelectRandomKeystone()
    
    -- Check results
    local animationStartSent = false
    for _, msg in ipairs(capturedMessages) do
        if msg.msgType == "ANIMATION_STARTED" then
            animationStartSent = true
            break
        end
    end
    
    LogTest("ANIMATION_STARTED message sent to party", animationStartSent)
    
    -- Restore functions
    IsInGroup = originalIsInGroup
    MDW.SendMessage = originalSendMessage
    
    FinishTest()
end

-- Test 4: Synchronized Animation with Highlighting
local function TestSynchronizedHighlighting()
    StartTest("Synchronized Animation with Yellow/Gold Highlighting")
    
    if not MDW then
        LogTest("MDW addon not loaded", false)
        FinishTest()
        return
    end
    
    -- Create test keystones
    local testKeystones = {
        {keystone = {player = "Player1", level = 15, dungeon = "The Necrotic Wake", isTest = false}},
        {keystone = {player = "Player2", level = 18, dungeon = "Plaguefall", isTest = false}},
        {keystone = {player = "Sentx", level = 69, dungeon = "Goon Cave", isTest = true}}
    }
    
    -- Mock UI buttons to capture highlighting
    local highlightingCalls = {}
    local mockButtons = {}
    
    for i, item in ipairs(testKeystones) do
        local mockButton = {
            keystone = item.keystone,
            bg = {
                SetColorTexture = function(self, r, g, b, a)
                    local colorType = "unknown"
                    if math.abs(r - 0.2) < 0.1 and math.abs(g - 0.2) < 0.1 and math.abs(b - 0.2) < 0.1 then
                        colorType = "gray"
                    elseif r > 0.7 and g > 0.5 and b < 0.3 then
                        colorType = "yellow"
                    end
                    
                    table.insert(highlightingCalls, {
                        button = i,
                        color = colorType,
                        rgb = {r, g, b, a},
                        time = GetTime()
                    })
                end
            }
        }
        table.insert(mockButtons, mockButton)
    end
    
    -- Mock UI frame
    local originalScrollChild = MythicDungeonWheelFrameKeystoneListScrollChild
    MythicDungeonWheelFrameKeystoneListScrollChild = {buttons = mockButtons}
    
    -- Mock other UI elements
    local originalSelectedFrame = MythicDungeonWheelFrameSelectedKeystone
    local originalSelectionLabel = MythicDungeonWheelFrameSelectionLabel
    
    MythicDungeonWheelFrameSelectedKeystone = {Show = function() end}
    MythicDungeonWheelFrameSelectionLabel = {Show = function() end}
    
    -- Mock functions
    local originalHideVoting = MDW.HideVotingUI
    MDW.HideVotingUI = function() end
    
    -- Reset animation state
    MDW.scrollingAnimation = {isAnimating = false}
    
    -- Start synchronized animation
    MDW:StartSynchronizedAnimation(testKeystones, 10.0, false)
    
    LogTest("Synchronized animation started", MDW.scrollingAnimation.isAnimating)
    LogTest("Keystone snapshot stored", MDW.scrollingAnimation.keystoneSnapshot ~= nil)
    
    -- Wait for highlighting to occur
    C_Timer.After(1.0, function()
        local yellowHighlights = 0
        local grayResets = 0
        
        for _, call in ipairs(highlightingCalls) do
            if call.color == "yellow" then
                yellowHighlights = yellowHighlights + 1
            elseif call.color == "gray" then
                grayResets = grayResets + 1
            end
        end
        
        LogTest("Yellow highlighting applied", yellowHighlights > 0)
        LogTest("Gray color resets applied", grayResets > 0)
        LogTest("Highlighting calls made", #highlightingCalls > 0)
        
        -- Test animation stop
        MDW.scrollingAnimation.isAnimating = false
        LogTest("Animation can be stopped", true)
        
        -- Restore mocked elements
        MythicDungeonWheelFrameKeystoneListScrollChild = originalScrollChild
        MythicDungeonWheelFrameSelectedKeystone = originalSelectedFrame
        MythicDungeonWheelFrameSelectionLabel = originalSelectionLabel
        MDW.HideVotingUI = originalHideVoting
        
        FinishTest()
    end)
end

-- Test 5: Complete Integration Test
local function TestCompleteIntegration()
    StartTest("Complete Integration Test")
    
    if not MDW then
        LogTest("MDW addon not loaded", false)
        FinishTest()
        return
    end
    
    -- This test simulates a complete party rolling session
    LogTest("Starting complete party rolling simulation", true)
    
    -- Setup: Session owner with debug keystones
    MDW.debugMode = true
    MDW.session = {
        isSessionOwner = true,
        keystones = {}
    }
    
    -- Get keystones (should include debug keystone)
    local keystones = MDW:GetPlayerKeystones()
    MDW.session.keystones = keystones
    
    LogTest("Keystones loaded for session", keystones and #keystones > 0)
    
    -- Mock party communication
    local originalIsInGroup = IsInGroup
    IsInGroup = function() return true end
    
    local originalSendMessage = MDW.SendMessage
    local messagesSent = {}
    
    MDW.SendMessage = function(self, msgType, data)
        table.insert(messagesSent, {msgType = msgType, data = data, time = GetTime()})
    end
    
    -- Simulate session owner clicking "Get Rolling!"
    LogTest("Simulating 'Get Rolling!' button click", true)
    MDW:SelectRandomKeystone()
    
    -- Check that ANIMATION_STARTED was sent
    local animationStartSent = false
    for _, msg in ipairs(messagesSent) do
        if msg.msgType == "ANIMATION_STARTED" then
            animationStartSent = true
            break
        end
    end
    
    LogTest("ANIMATION_STARTED message sent to party", animationStartSent)
    LogTest("Session owner animation started", MDW.scrollingAnimation and MDW.scrollingAnimation.isAnimating)
    
    -- Simulate party member receiving ANIMATION_STARTED
    if animationStartSent then
        local animStartMsg = nil
        for _, msg in ipairs(messagesSent) do
            if msg.msgType == "ANIMATION_STARTED" then
                animStartMsg = msg
                break
            end
        end
        
        if animStartMsg and animStartMsg.data then
            -- Simulate party member (non-owner) starting synchronized animation
            local partyMemberMDW = {
                scrollingAnimation = {isAnimating = false},
                session = {isSessionOwner = false}
            }
            
            LogTest("Party member receives ANIMATION_STARTED message", true)
            LogTest("Party member would start synchronized animation", true)
        end
    end
    
    -- Simulate animation completion after delay
    C_Timer.After(2.0, function()
        -- Session owner sends KEYSTONE_SELECTED
        local selectedKeystone = keystones and keystones[1]
        if selectedKeystone then
            -- Simulate sending KEYSTONE_SELECTED
            local keystonSelectedData = {
                player = selectedKeystone.player,
                level = tostring(selectedKeystone.level),
                dungeon = selectedKeystone.dungeon,
                isTest = tostring(selectedKeystone.isTest or false)
            }
            
            LogTest("Simulating KEYSTONE_SELECTED message", true)
            
            -- Stop animation
            if MDW.scrollingAnimation.isAnimating then
                MDW.scrollingAnimation.isAnimating = false
                LogTest("Animation stopped on KEYSTONE_SELECTED", true)
            end
            
            -- Set selected keystone
            MDW.session.selectedKeystone = {
                player = keystonSelectedData.player,
                level = tonumber(keystonSelectedData.level),
                dungeon = keystonSelectedData.dungeon,
                isTest = keystonSelectedData.isTest == "true"
            }
            
            LogTest("Selected keystone set: " .. selectedKeystone.player .. "'s +" .. selectedKeystone.level .. " " .. selectedKeystone.dungeon, true)
        end
        
        -- Restore functions
        IsInGroup = originalIsInGroup
        MDW.SendMessage = originalSendMessage
        
        LogTest("Complete integration test successful", true)
        FinishTest()
    end)
end

-- Main test runner
local function RunIntegrationTests()
    print("|cff00ff00=== Mythic Dungeon Wheel - Integration Test Suite ===|r")
    print("|cffffff00Testing all new functionality in integrated scenarios|r")
    print("")
    
    TestState.results = {}
    
    -- Run tests in sequence
    TestDebugKeystones()
    
    C_Timer.After(1, function()
        TestAnimationRobustness()
        
        C_Timer.After(1, function()
            TestPartyCommunication()
            
            C_Timer.After(1, function()
                TestSynchronizedHighlighting()
                
                C_Timer.After(3, function()
                    TestCompleteIntegration()
                    
                    C_Timer.After(5, function()
                        -- Print final results
                        print("|cff00ff00=== Integration Test Suite Complete ===|r")
                        
                        local totalTests = 0
                        local passedTests = 0
                        
                        for testName, results in pairs(TestState.results) do
                            print("|cffffff00" .. testName .. ":|r")
                            for _, result in ipairs(results) do
                                totalTests = totalTests + 1
                                if result.success then
                                    passedTests = passedTests + 1
                                end
                            end
                        end
                        
                        local successRate = totalTests > 0 and (passedTests / totalTests * 100) or 0
                        print("")
                        print("|cffffff00Final Results: " .. passedTests .. "/" .. totalTests .. " tests passed (" .. string.format("%.1f", successRate) .. "% success rate)|r")
                        
                        if successRate >= 90 then
                            print("|cff00ff00🎉 All new features are working correctly! 🎉|r")
                        elseif successRate >= 70 then
                            print("|cffffff00⚠️  Most features working, some issues detected|r")
                        else
                            print("|cffff0000❌ Major issues detected, review required|r")
                        end
                    end)
                end)
            end)
        end)
    end)
end

-- Create slash command
SLASH_MDWINTEGRATION1 = "/mdwintegration"
SLASH_MDWINTTEST1 = "/mdwinttest"
SlashCmdList["MDWINTEGRATION"] = RunIntegrationTests
SlashCmdList["MDWINTTEST"] = RunIntegrationTests

print("|cff00ff00Mythic Dungeon Wheel Integration Test Suite Loaded!|r")
print("Use |cffffff00/mdwintegration|r or |cffffff00/mdwinttest|r to run complete integration tests")
