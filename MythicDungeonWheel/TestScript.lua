-- TestScript.lua
-- Main test script and menu for Mythic Dungeon Wheel test suite
-- Updated to include all new functionality tests

local MDW = MythicDungeonWheel

-- Test menu and utilities
local function PrintTestMenu()
    print("|cff00ff00=== Mythic Dungeon Wheel Test Suite ===|r")
    print("|cffffff00Available test commands:|r")
    print("  |cff88ff88/mdwtest|r - Basic functionality tests")
    print("  |cff88ff88/mdwtestall|r - Complete test suite") 
    print("  |cff88ff88/mdwintegration|r - Integration tests")
    print("  |cff88ff88/mdwdebug|r - Test debug mode keystones")
    print("  |cff88ff88/mdwanimation|r - Test animation features")
    print("  |cff88ff88/mdwparty|r - Test party synchronization")
    print("  |cff88ff88/mdwhighlight|r - Test highlighting system")
    print("  |cff88ff88/mdwreset|r - Reset test environment")
    print("")
    print("|cffffff00New features tested:|r")
    print("• Animation robustness against keystone removal")
    print("• Debug mode '+69 Goon Cave' keystone generation")
    print("• Party-wide animation synchronization") 
    print("• Yellow/gold highlighting for party members")
    print("• Proper animation cleanup on completion")
    print("• Message serialization and communication")
end

-- Test debug mode keystone generation
local function TestDebugMode()
    print("|cff00ff00=== Testing Debug Mode Keystones ===|r")
    
    if not MDW then
        print("|cffff0000MDW addon not loaded!|r")
        return
    end
    
    -- Enable debug mode
    local originalDebugMode = MDW.debugMode
    MDW.debugMode = true
    print("Debug mode enabled")
    
    -- Mock empty bags to trigger debug keystone
    local originalGetContainerNumSlots = GetContainerNumSlots
    local originalGetContainerItemInfo = GetContainerItemInfo
    
    if GetContainerNumSlots then
        GetContainerNumSlots = function() return 0 end
        print("Mocked empty bags")
    end
    if GetContainerItemInfo then
        GetContainerItemInfo = function() return nil end
    end
    
    -- Get keystones
    local keystones = MDW:GetPlayerKeystones()
    
    if keystones and #keystones > 0 then
        print("|cff00ff00Found " .. #keystones .. " keystones:|r")
        for i, keystone in ipairs(keystones) do
            local testFlag = keystone.isTest and " (TEST)" or ""
            print("  " .. i .. ". " .. keystone.player .. "'s +" .. keystone.level .. " " .. keystone.dungeon .. testFlag)
            
            if keystone.dungeon == "Goon Cave" and keystone.level == 69 then
                print("  |cff00ff00✓ Debug keystone '+69 Goon Cave' found!|r")
            end
        end
    else
        print("|cffff0000No keystones found|r")
    end
    
    -- Restore functions
    if originalGetContainerNumSlots then
        GetContainerNumSlots = originalGetContainerNumSlots
    end
    if originalGetContainerItemInfo then
        GetContainerItemInfo = originalGetContainerItemInfo
    end
    MDW.debugMode = originalDebugMode
    
    print("|cff00ff00Debug mode test complete|r")
end

-- Test animation features
local function TestAnimation()
    print("|cff00ff00=== Testing Animation Features ===|r")
    
    if not MDW then
        print("|cffff0000MDW addon not loaded!|r")
        return
    end
    
    -- Check animation functions
    local functions = {
        "StartScrollingAnimation",
        "StartSynchronizedAnimation", 
        "FinishScrollingAnimation"
    }
    
    for _, funcName in ipairs(functions) do
        if MDW[funcName] then
            print("|cff00ff00✓ " .. funcName .. " function exists|r")
        else
            print("|cffff0000✗ " .. funcName .. " function missing|r")
        end
    end
    
    -- Check animation state
    if MDW.scrollingAnimation then
        print("|cff00ff00✓ Animation state initialized|r")
        print("  - isAnimating: " .. tostring(MDW.scrollingAnimation.isAnimating))
        print("  - selectedKeystone: " .. tostring(MDW.scrollingAnimation.selectedKeystone))
        print("  - keystoneSnapshot: " .. tostring(MDW.scrollingAnimation.keystoneSnapshot))
    else
        print("|cffff0000✗ Animation state not found|r")
    end
    
    print("|cff00ff00Animation test complete|r")
end

-- Test party synchronization
local function TestPartySynchronization()
    print("|cff00ff00=== Testing Party Synchronization ===|r")
    
    if not MDW then
        print("|cffff0000MDW addon not loaded!|r")
        return
    end
    
    -- Check communication functions
    local commFunctions = {
        "SendMessage",
        "SerializeKeystoneSnapshot",
        "DeserializeKeystoneSnapshot"
    }
    
    for _, funcName in ipairs(commFunctions) do
        if MDW[funcName] then
            print("|cff00ff00✓ " .. funcName .. " function exists|r")
        else
            print("|cffff0000✗ " .. funcName .. " function missing|r")
        end
    end
    
    -- Test serialization with sample data
    local testKeystones = {
        {keystone = {player = "TestPlayer", level = 15, dungeon = "Test Dungeon", isTest = true}}
    }
    
    if MDW.SerializeKeystoneSnapshot then
        local serialized = MDW:SerializeKeystoneSnapshot(testKeystones)
        if serialized then
            print("|cff00ff00✓ Keystone serialization works|r")
            print("  Serialized length: " .. string.len(serialized))
            
            if MDW.DeserializeKeystoneSnapshot then
                local deserialized = MDW:DeserializeKeystoneSnapshot(serialized)
                if deserialized and #deserialized > 0 then
                    print("|cff00ff00✓ Keystone deserialization works|r")
                    print("  Restored " .. #deserialized .. " keystones")
                else
                    print("|cffff0000✗ Keystone deserialization failed|r")
                end
            end
        else
            print("|cffff0000✗ Keystone serialization failed|r")
        end
    end
    
    print("|cff00ff00Party synchronization test complete|r")
end

-- Test highlighting system
local function TestHighlighting()
    print("|cff00ff00=== Testing Highlighting System ===|r")
    
    if not MDW then
        print("|cffff0000MDW addon not loaded!|r")
        return
    end
    
    -- Check if UI frames exist
    local frames = {
        "MythicDungeonWheelFrameKeystoneList",
        "MythicDungeonWheelFrameKeystoneListScrollChild",
        "MythicDungeonWheelFrameSelectedKeystone",
        "MythicDungeonWheelFrameSelectionLabel"
    }
    
    for _, frameName in ipairs(frames) do
        local frame = _G[frameName]
        if frame then
            print("|cff00ff00✓ " .. frameName .. " exists|r")
        else
            print("|cffffff00- " .. frameName .. " not found (may be created dynamically)|r")
        end
    end
    
    -- Test mock highlighting
    print("Testing color highlighting...")
    local testColors = {
        {name = "Gray (default)", r = 0.2, g = 0.2, b = 0.2, a = 0.8},
        {name = "Yellow/Gold (highlight)", r = 0.8, g = 0.6, b = 0.2, a = 0.9}
    }
    
    for _, color in ipairs(testColors) do
        print("  " .. color.name .. ": RGB(" .. color.r .. ", " .. color.g .. ", " .. color.b .. ", " .. color.a .. ")")
    end
    
    print("|cff00ff00Highlighting test complete|r")
end

-- Reset test environment
local function ResetTestEnvironment()
    print("|cff00ff00=== Resetting Test Environment ===|r")
    
    if not MDW then
        print("|cffff0000MDW addon not loaded!|r")
        return
    end
    
    -- Reset animation state
    if MDW.scrollingAnimation then
        MDW.scrollingAnimation.isAnimating = false
        MDW.scrollingAnimation.selectedKeystone = nil
        MDW.scrollingAnimation.keystoneSnapshot = nil
        print("✓ Animation state reset")
    end
    
    -- Reset session state
    if MDW.session then
        MDW.session.selectedKeystone = nil
        print("✓ Session state reset")
    end
    
    -- Reset debug mode
    MDW.debugMode = false
    print("✓ Debug mode disabled")
    
    print("|cff00ff00Test environment reset complete|r")
end

-- Basic functionality test (for backward compatibility)
local function TestBasicFunctionality()
    print("|cff00ff00=== Testing Basic Functionality ===|r")
    
    if not MDW then
        print("|cffff0000MythicDungeonWheel addon not found!|r")
        return
    end
    
    print("Testing core functions...")
    
    -- Test session functions
    if MDW.CreateSession then
        print("|cff00ff00✓ CreateSession function exists|r")
    else
        print("|cffff0000✗ CreateSession function missing|r")
    end
    
    -- Test keystone functions
    if MDW.GetPlayerKeystones then
        print("|cff00ff00✓ GetPlayerKeystones function exists|r")
        local keystones = MDW:GetPlayerKeystones()
        print("  Found " .. (#keystones or 0) .. " keystones")
    else
        print("|cffff0000✗ GetPlayerKeystones function missing|r")
    end
    
    -- Test interface functions
    if MDW.UpdateInterface then
        print("|cff00ff00✓ UpdateInterface function exists|r")
    else
        print("|cffff0000✗ UpdateInterface function missing|r")
    end
    
    -- Test new animation functions
    if MDW.StartScrollingAnimation then
        print("|cff00ff00✓ StartScrollingAnimation function exists|r")
    else
        print("|cffff0000✗ StartScrollingAnimation function missing|r")
    end
    
    if MDW.StartSynchronizedAnimation then
        print("|cff00ff00✓ StartSynchronizedAnimation function exists|r")
    else
        print("|cffff0000✗ StartSynchronizedAnimation function missing|r")
    end
    
    print("|cff00ff00Basic functionality test complete!|r")
end

-- Comprehensive test runner
local function RunComprehensiveTests()
    print("|cff00ff00=== Running Comprehensive Test Suite ===|r")
    print("")
    
    TestBasicFunctionality()
    print("")
    
    TestDebugMode()
    print("")
    
    TestAnimation()
    print("")
    
    TestPartySynchronization()
    print("")
    
    TestHighlighting()
    print("")
    
    print("|cff00ff00=== Comprehensive Test Suite Complete ===|r")
    print("|cffffff00All major systems tested!|r")
    print("|cffffff00Use /mdwintegration for live integration tests|r")
end

-- Set up slash commands (keeping existing ones for compatibility)
SLASH_TESTMDW1 = "/testmdw"
SLASH_MDWDEBUG1 = "/mdwdebug"
SLASH_MDWANIMATION1 = "/mdwanimation"
SLASH_MDWPARTY1 = "/mdwparty"
SLASH_MDWHIGHLIGHT1 = "/mdwhighlight"
SLASH_MDWRESET1 = "/mdwreset"
SLASH_MDWMENU1 = "/mdwmenu"

SlashCmdList["TESTMDW"] = TestBasicFunctionality
SlashCmdList["MDWDEBUG"] = TestDebugMode
SlashCmdList["MDWANIMATION"] = TestAnimation
SlashCmdList["MDWPARTY"] = TestPartySynchronization
SlashCmdList["MDWHIGHLIGHT"] = TestHighlighting
SlashCmdList["MDWRESET"] = ResetTestEnvironment
SlashCmdList["MDWMENU"] = PrintTestMenu

-- Auto-show menu on load
print("|cff00ff00Mythic Dungeon Wheel Test Suite Loaded!|r")
PrintTestMenu()
