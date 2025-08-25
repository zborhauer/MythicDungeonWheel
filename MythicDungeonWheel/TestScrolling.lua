-- TestScrolling.lua
-- Simple test file to verify our scrolling animation works

local function TestScrollingAnimation()
    print("Testing scrolling animation implementation...")
    
    -- Check if the scrolling animation state exists
    if MythicDungeonWheel and MythicDungeonWheel.scrollingAnimation then
        print("✓ Scrolling animation state initialized")
        print("  - isAnimating: " .. tostring(MythicDungeonWheel.scrollingAnimation.isAnimating))
        print("  - selectedKeystone: " .. tostring(MythicDungeonWheel.scrollingAnimation.selectedKeystone))
    else
        print("✗ Scrolling animation state not found")
        return
    end
    
    -- Check if the interface mode is properly set
    if MythicDungeonWheel.interfaceMode then
        print("✓ Interface mode: " .. MythicDungeonWheel.interfaceMode)
    else
        print("✗ Interface mode not set")
    end
    
    -- Check if the StartScrollingAnimation function exists
    if MythicDungeonWheel.StartScrollingAnimation then
        print("✓ StartScrollingAnimation function exists")
    else
        print("✗ StartScrollingAnimation function missing")
    end
    
    -- Check if the FinishScrollingAnimation function exists
    if MythicDungeonWheel.FinishScrollingAnimation then
        print("✓ FinishScrollingAnimation function exists")
    else
        print("✗ FinishScrollingAnimation function missing")
    end
    
    print("Test completed!")
end

-- Create a slash command to run the test
SLASH_MDWTEST1 = "/mdwtest"
SlashCmdList["MDWTEST"] = TestScrollingAnimation
