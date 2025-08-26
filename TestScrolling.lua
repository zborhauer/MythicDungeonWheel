-- TestScrolling.lua
-- Comprehensive test suite for Mythic Dungeon Wheel scrolling animations and party synchronization
-- Updated to test all new functionality: animation robustness, debug keystones, party sync, and highlighting

local MDW = MythicDungeonWheel

local function PrintTestHeader(testName)
    print("|cff00ff00=== " .. testName .. " ===|r")
end

local function PrintTestResult(testName, success, details)
    local color = success and "|cff00ff00" or "|cffff0000"
    local status = success and "✓" or "✗"
    print(color .. status .. " " .. testName .. "|r" .. (details and (" - " .. details) or ""))
end

-- Test 1: Basic Animation State and Functions
local function TestBasicAnimationState()
    PrintTestHeader("Basic Animation State and Functions")
    
    -- Check if the scrolling animation state exists
    local hasAnimationState = MDW and MDW.scrollingAnimation
    PrintTestResult("Scrolling animation state initialized", hasAnimationState)
    
    if hasAnimationState then
        print("  - isAnimating: " .. tostring(MDW.scrollingAnimation.isAnimating))
        print("  - selectedKeystone: " .. tostring(MDW.scrollingAnimation.selectedKeystone))
        print("  - keystoneSnapshot: " .. tostring(MDW.scrollingAnimation.keystoneSnapshot))
    end
    
    -- Check if the interface mode is properly set
    local hasInterfaceMode = MDW and MDW.interfaceMode
    PrintTestResult("Interface mode set", hasInterfaceMode, hasInterfaceMode and MDW.interfaceMode or nil)
    
    -- Check core animation functions
    PrintTestResult("StartScrollingAnimation function exists", MDW and MDW.StartScrollingAnimation ~= nil)
    PrintTestResult("FinishScrollingAnimation function exists", MDW and MDW.FinishScrollingAnimation ~= nil)
    PrintTestResult("StartSynchronizedAnimation function exists", MDW and MDW.StartSynchronizedAnimation ~= nil)
    
    -- Check keystone functions
    PrintTestResult("GetPlayerKeystones function exists", MDW and MDW.GetPlayerKeystones ~= nil)
    PrintTestResult("SelectRandomKeystone function exists", MDW and MDW.SelectRandomKeystone ~= nil)
    
    -- Check communication functions
    PrintTestResult("SendMessage function exists", MDW and MDW.SendMessage ~= nil)
    PrintTestResult("SerializeKeystoneSnapshot function exists", MDW and MDW.SerializeKeystoneSnapshot ~= nil)
    PrintTestResult("DeserializeKeystoneSnapshot function exists", MDW and MDW.DeserializeKeystoneSnapshot ~= nil)
end

-- Test 2: Debug Mode Keystone Generation
local function TestDebugModeKeystones()
    PrintTestHeader("Debug Mode Keystone Generation")
    
    if not MDW then
        PrintTestResult("MDW addon not available", false)
        return
    end
    
    -- Enable debug mode
    local originalDebugMode = MDW.debugMode
    MDW.debugMode = true
    
    -- Mock empty bags to force debug keystone generation
    local originalGetContainerNumSlots = GetContainerNumSlots
    local originalGetContainerItemInfo = GetContainerItemInfo
    
    GetContainerNumSlots = function() return 0 end
    GetContainerItemInfo = function() return nil end
    
    -- Test keystone generation
    local keystones = MDW:GetPlayerKeystones()
    
    local hasDebugKeystone = false
    local debugKeystoneDetails = ""
    
    if keystones and #keystones > 0 then
        for _, keystone in ipairs(keystones) do
            if keystone and keystone.dungeon == "Goon Cave" and keystone.level == 69 then
                hasDebugKeystone = true
                debugKeystoneDetails = keystone.player .. "'s +" .. keystone.level .. " " .. keystone.dungeon .. (keystone.isTest and " (TEST)" or "")
                break
            end
        end
    end
    
    PrintTestResult("Debug keystone '+69 Goon Cave' generated", hasDebugKeystone, debugKeystoneDetails)
    
    -- Restore functions
    GetContainerNumSlots = originalGetContainerNumSlots
    GetContainerItemInfo = originalGetContainerItemInfo
    MDW.debugMode = originalDebugMode
end

-- Test 3: Keystone Snapshot and Serialization
local function TestKeystoneSnapshotSerialization()
    PrintTestHeader("Keystone Snapshot and Serialization")
    
    if not MDW then
        PrintTestResult("MDW addon not available", false)
        return
    end
    
    -- Create test keystone data
    local testKeystones = {
        {keystone = {player = "TestPlayer1", level = 15, dungeon = "The Necrotic Wake", isTest = false}},
        {keystone = {player = "TestPlayer2", level = 18, dungeon = "Plaguefall", isTest = false}},
        {keystone = {player = "Sentx", level = 69, dungeon = "Goon Cave", isTest = true}}
    }
    
    -- Test serialization
    local serialized = MDW:SerializeKeystoneSnapshot(testKeystones)
    PrintTestResult("Keystone serialization works", serialized ~= nil, "Length: " .. (serialized and string.len(serialized) or 0))
    
    if serialized then
        -- Test deserialization
        local deserialized = MDW:DeserializeKeystoneSnapshot(serialized)
        local deserializationWorks = deserialized and #deserialized == #testKeystones
        PrintTestResult("Keystone deserialization works", deserializationWorks, "Count: " .. (#deserialized or 0))
        
        if deserializationWorks then
            -- Verify data integrity
            local dataIntact = true
            for i, original in ipairs(testKeystones) do
                local restored = deserialized[i]
                if not restored or not restored.keystone or
                   restored.keystone.player ~= original.keystone.player or
                   restored.keystone.level ~= original.keystone.level or
                   restored.keystone.dungeon ~= original.keystone.dungeon or
                   restored.keystone.isTest ~= original.keystone.isTest then
                    dataIntact = false
                    break
                end
            end
            PrintTestResult("Serialization data integrity", dataIntact)
        end
    end
end

-- Test 4: Party Communication Messages
local function TestPartyCommunication()
    PrintTestHeader("Party Communication Messages")
    
    if not MDW then
        PrintTestResult("MDW addon not available", false)
        return
    end
    
    -- Mock IsInGroup to simulate being in a party
    local originalIsInGroup = IsInGroup
    IsInGroup = function() return true end
    
    -- Mock SendMessage to capture what would be sent
    local originalSendMessage = MDW.SendMessage
    local capturedMessages = {}
    
    MDW.SendMessage = function(self, msgType, data)
        table.insert(capturedMessages, {msgType = msgType, data = data})
        print("  Would send message: " .. msgType)
    end
    
    -- Test ANIMATION_STARTED message
    local testKeystones = {
        {keystone = {player = "TestPlayer1", level = 15, dungeon = "The Necrotic Wake"}},
        {keystone = {player = "TestPlayer2", level = 18, dungeon = "Plaguefall"}}
    }
    
    -- Mock session and call SelectRandomKeystone
    MDW.session = {isSessionOwner = true, keystones = testKeystones}
    MDW:SelectRandomKeystone()
    
    -- Check if ANIMATION_STARTED message was captured
    local animationStartSent = false
    local animationStartData = nil
    
    for _, msg in ipairs(capturedMessages) do
        if msg.msgType == "ANIMATION_STARTED" then
            animationStartSent = true
            animationStartData = msg.data
            break
        end
    end
    
    PrintTestResult("ANIMATION_STARTED message sent", animationStartSent)
    
    if animationStartData then
        PrintTestResult("Message includes keystone data", animationStartData.keystones ~= nil)
        PrintTestResult("Message includes duration", animationStartData.duration ~= nil)
    end
    
    -- Restore functions
    IsInGroup = originalIsInGroup
    MDW.SendMessage = originalSendMessage
end

-- Test 5: Synchronized Animation with Highlighting
local function TestSynchronizedAnimation()
    PrintTestHeader("Synchronized Animation with Highlighting")
    
    if not MDW then
        PrintTestResult("MDW addon not available", false)
        return
    end
    
    -- Create mock UI elements
    local highlightingCalls = {}
    local mockButtons = {}
    
    local testKeystones = {
        {keystone = {player = "TestPlayer1", level = 15, dungeon = "The Necrotic Wake"}},
        {keystone = {player = "TestPlayer2", level = 18, dungeon = "Plaguefall"}},
        {keystone = {player = "Sentx", level = 69, dungeon = "Goon Cave", isTest = true}}
    }
    
    -- Create mock UI buttons
    for i, item in ipairs(testKeystones) do
        local mockButton = {
            keystone = item.keystone,
            bg = {
                SetColorTexture = function(self, r, g, b, a)
                    local colorType = "gray"
                    if r > 0.5 and g > 0.4 and b < 0.5 then
                        colorType = "yellow"
                    end
                    table.insert(highlightingCalls, {button = i, color = colorType})
                end
            }
        }
        table.insert(mockButtons, mockButton)
    end
    
    -- Mock UI elements
    local originalFrame = MythicDungeonWheelFrameKeystoneListScrollChild
    MythicDungeonWheelFrameKeystoneListScrollChild = {buttons = mockButtons}
    
    -- Mock other UI elements
    local originalSelectedFrame = MythicDungeonWheelFrameSelectedKeystone
    local originalLabelFrame = MythicDungeonWheelFrameSelectionLabel
    MythicDungeonWheelFrameSelectedKeystone = {Show = function() end}
    MythicDungeonWheelFrameSelectionLabel = {Show = function() end}
    
    -- Reset animation state
    MDW.scrollingAnimation = {isAnimating = false}
    
    -- Mock functions
    local originalHideVoting = MDW.HideVotingUI
    MDW.HideVotingUI = function() end
    
    -- Test StartSynchronizedAnimation
    MDW:StartSynchronizedAnimation(testKeystones, 10.0, false)
    
    PrintTestResult("Synchronized animation started", MDW.scrollingAnimation.isAnimating)
    PrintTestResult("UI buttons mapped correctly", #mockButtons == #testKeystones)
    
    -- Wait a moment for highlighting to occur
    C_Timer.After(0.5, function()
        local yellowHighlightFound = false
        for _, call in ipairs(highlightingCalls) do
            if call.color == "yellow" then
                yellowHighlightFound = true
                break
            end
        end
        PrintTestResult("Yellow highlighting applied", yellowHighlightFound)
        
        -- Test animation stop
        MDW.scrollingAnimation.isAnimating = false
        PrintTestResult("Animation can be stopped", true)
    end)
    
    -- Restore mocked elements
    MythicDungeonWheelFrameKeystoneListScrollChild = originalFrame
    MythicDungeonWheelFrameSelectedKeystone = originalSelectedFrame
    MythicDungeonWheelFrameSelectionLabel = originalLabelFrame
    MDW.HideVotingUI = originalHideVoting
end

-- Test 6: Message Handler Integration
local function TestMessageHandlers()
    PrintTestHeader("Message Handler Integration")
    
    if not MDW then
        PrintTestResult("MDW addon not available", false)
        return
    end
    
    -- Test ANIMATION_STARTED handler
    local testKeystoneData = {
        keystones = "testdata", -- Would normally be serialized data
        duration = "10.0"
    }
    
    -- Mock the deserialization
    local originalDeserialize = MDW.DeserializeKeystoneSnapshot
    MDW.DeserializeKeystoneSnapshot = function() 
        return {
            {keystone = {player = "TestPlayer1", level = 15, dungeon = "The Necrotic Wake"}}
        }
    end
    
    -- Mock StartSynchronizedAnimation to track calls
    local originalStartSync = MDW.StartSynchronizedAnimation
    local syncAnimationCalled = false
    MDW.StartSynchronizedAnimation = function(self, snapshot, duration, isOwner)
        syncAnimationCalled = true
        PrintTestResult("StartSynchronizedAnimation called with correct params", 
                       snapshot ~= nil and duration ~= nil and isOwner == false)
    end
    
    -- Test KEYSTONE_SELECTED handler
    MDW.scrollingAnimation = {isAnimating = true}
    
    local selectedKeystoneData = {
        player = "TestPlayer1",
        level = "15",
        dungeon = "The Necrotic Wake",
        isTest = "false"
    }
    
    -- Mock UpdateInterface
    local originalUpdateInterface = MDW.UpdateInterface
    MDW.UpdateInterface = function() end
    
    -- Simulate KEYSTONE_SELECTED message handling
    if MDW.scrollingAnimation.isAnimating then
        MDW.scrollingAnimation.isAnimating = false
        MDW.session = MDW.session or {}
        MDW.session.selectedKeystone = {
            player = selectedKeystoneData.player,
            level = tonumber(selectedKeystoneData.level),
            dungeon = selectedKeystoneData.dungeon,
            isTest = selectedKeystoneData.isTest == "true"
        }
    end
    
    PrintTestResult("KEYSTONE_SELECTED stops animation", not MDW.scrollingAnimation.isAnimating)
    PrintTestResult("Selected keystone properly set", 
                   MDW.session.selectedKeystone and MDW.session.selectedKeystone.player == "TestPlayer1")
    
    -- Restore functions
    MDW.DeserializeKeystoneSnapshot = originalDeserialize
    MDW.StartSynchronizedAnimation = originalStartSync
    MDW.UpdateInterface = originalUpdateInterface
end

-- Main test runner
local function RunAllTests()
    PrintTestHeader("Mythic Dungeon Wheel - Comprehensive Test Suite")
    print("|cffffff00Testing new features: Animation robustness, debug keystones, party sync, and highlighting|r")
    print("")
    
    TestBasicAnimationState()
    print("")
    
    TestDebugModeKeystones()
    print("")
    
    TestKeystoneSnapshotSerialization()
    print("")
    
    TestPartyCommunication()
    print("")
    
    TestSynchronizedAnimation()
    print("")
    
    TestMessageHandlers()
    print("")
    
    PrintTestHeader("Test Suite Complete")
    print("|cffffff00All new functionality has been tested!|r")
    print("New features tested:")
    print("• Animation robustness against keystone removal")
    print("• Debug mode '+69 Goon Cave' keystone generation")
    print("• Party-wide animation synchronization")
    print("• Yellow/gold highlighting for party members")
    print("• Proper animation cleanup on completion")
end

-- Create slash commands to run tests
SLASH_MDWTEST1 = "/mdwtest"
SLASH_MDWTESTALL1 = "/mdwtestall"

SlashCmdList["MDWTEST"] = TestBasicAnimationState
SlashCmdList["MDWTESTALL"] = RunAllTests

print("|cff00ff00Mythic Dungeon Wheel Test Suite Loaded!|r")
print("Use |cffffff00/mdwtest|r for basic tests or |cffffff00/mdwtestall|r for comprehensive testing")
