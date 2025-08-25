-- Simple test script for slot machine functionality
-- Run this with: /script LoadAddOn("MythicDungeonWheel"); MDW:TestSlotMachine()

function MDW:TestSlotMachine()
    print("Testing Slot Machine Functionality...")
    
    -- Initialize if needed
    if not self.slotMachine then
        self.slotMachine = {
            items = nil,
            selectedKeystone = nil,
            isAnimating = false
        }
    end
    
    -- Test interface mode switching
    self.interfaceMode = "wheel"
    print("Interface mode set to: " .. self.interfaceMode)
    
    -- Test with mock keystones
    self.session = {
        active = true,
        isLeader = true,
        keystones = {
            ["Player1"] = {player = "Player1", level = 15, dungeon = "Ara-Kara, City of Echoes"},
            ["Player2"] = {player = "Player2", level = 12, dungeon = "City of Threads"},
            ["Player3"] = {player = "Player3", level = 18, dungeon = "The Stonevault"},
            ["Player4"] = {player = "Player4", level = 20, dungeon = "The Dawnbreaker"}
        }
    }
    
    print("Mock session created with " .. self:GetKeystoneCount() .. " keystones")
    
    -- Test keystone selection
    print("Testing slot machine selection...")
    if self.interfaceMode == "wheel" then
        print("Would start slot machine animation")
        -- Don't actually run animation in test, just show the logic works
        local keystoneList = {}
        for key, keystone in pairs(self.session.keystones) do
            table.insert(keystoneList, {key = key, keystone = keystone})
        end
        
        local selectedIndex = math.random(1, #keystoneList)
        local selected = keystoneList[selectedIndex]
        print("Selected: " .. selected.keystone.player .. "'s +" .. selected.keystone.level .. " " .. selected.keystone.dungeon)
    end
    
    print("Slot machine test completed!")
end

function MDW:GetKeystoneCount()
    local count = 0
    if self.session and self.session.keystones then
        for _ in pairs(self.session.keystones) do
            count = count + 1
        end
    end
    return count
end
