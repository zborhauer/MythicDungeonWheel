 -- MythicDungeonWheel.lua
-- Main addon file for Mythic Dungeon Wheel

local addonName, addon = ...

-- Initialize addon without LibStub dependencies for simplicity
MythicDungeonWheel = CreateFrame("Frame")
local MDW = MythicDungeonWheel

-- Debug print helper function
function MDW:DebugPrint(message)
    if self.debugMode then
        print(message)
    end
end

-- Initialize scrolling animation state
MDW.scrollingAnimation = {
    isAnimating = false,
    selectedKeystone = nil
}

-- Constants
local COMM_PREFIX = "MDW"
local KEYSTONE_ITEM_ID = 180653 -- Mythic Keystone item ID (should work across expansions)
local KEYSTONE_ITEM_NAME = "Mythic Keystone" -- For fallback detection

-- Utility function for string trimming
local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

-- Make trim available as a string method
if not string.trim then
    string.trim = trim
end

-- Session data
MDW.session = {
    active = false,
    owner = nil,  -- Who started the session
    participants = {},
    keystones = {},
    selectedKeystone = nil,
    isOwner = false,  -- Whether this player owns the session
    selectedKeystoneRemoved = false,
    autoResetTimer = nil, -- Timer for auto-reset after voting
    voting = {
        active = false,
        votes = {}, -- {playerName = true/false}
        voteCount = 0, -- number of yes votes
        totalVotes = 0, -- total votes cast
        totalMembers = 0, -- total members in group
        timeLeft = 30,
        timer = nil
    }
}

-- Test mode for development
MDW.testMode = false

-- Developer mode (enables test button visibility)
MDW.debugMode = false

-- Event registration and initialization
function MDW:OnEvent(event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        self:Initialize()
    elseif self[event] then
        self[event](self, ...)
    end
end

MDW:SetScript("OnEvent", MDW.OnEvent)
MDW:RegisterEvent("ADDON_LOADED")

function MDW:CreateMinimapButton()
    -- Check if required libraries are available
    if not LibStub then
        -- Create a simple fallback minimap button without LibDBIcon
        self:CreateFallbackMinimapButton()
        return
    end
    
    local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    
    if not LDB or not LDBIcon then
        -- Create a simple fallback minimap button without LibDBIcon
        self:CreateFallbackMinimapButton()
        return
    end
    
    -- Create a minimap button data object
    local minimapButton = LDB:NewDataObject("MythicDungeonWheel", {
        type = "launcher",
        text = "MDW",
        icon = "Interface\\Icons\\INV_Misc_Dice_01",
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                self:ToggleInterface()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Mythic Dungeon Wheel")
            tooltip:AddLine("|cffeda55fClick|r to open interface")
        end,
    })
    
    -- Register the minimap button
    LDBIcon:Register("MythicDungeonWheel", minimapButton, MythicDungeonWheelDB)
    self:DebugPrint("|cff00ff00MythicDungeonWheel:|r Minimap button created successfully!")
end

function MDW:CreateFallbackMinimapButton()
    -- Create a simple minimap button without dependencies
    local button = CreateFrame("Button", "MythicDungeonWheelMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    
    -- Set the question mark texture
    local texture = button:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Create a circular mask
    button:SetNormalTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Position on minimap
    local angle = MythicDungeonWheelDB.minimapAngle or 45
    local x = math.cos(math.rad(angle)) * 80
    local y = math.sin(math.rad(angle)) * 80
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
    -- Make it clickable
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        self:ToggleInterface()
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Mythic Dungeon Wheel")
        GameTooltip:AddLine("|cffeda55fClick|r to open interface")
        GameTooltip:AddLine("|cffff9999Note:|r Install LibDBIcon for draggable button")
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Store reference
    self.minimapButton = button
    
    self:DebugPrint("|cffffff00MythicDungeonWheel:|r Simple minimap button created (question mark icon).")
end

function MDW:Initialize()
    -- Initialize saved variables
    if not MythicDungeonWheelDB then
        MythicDungeonWheelDB = {}
    end
    
    -- Set default minimap button position if not set
    if not MythicDungeonWheelDB.minimapAngle then
        MythicDungeonWheelDB.minimapAngle = 45
    end
    
    -- Initialize wheel statistics
    if not MythicDungeonWheelDB.statistics then
        MythicDungeonWheelDB.statistics = {
            completedKeys = {},
            totalCompleted = 0,
            yesVotes = 0,
            noVotes = 0
        }
    end
    
    -- Add voting statistics if they don't exist (for existing users)
    if MythicDungeonWheelDB.statistics.yesVotes == nil then
        MythicDungeonWheelDB.statistics.yesVotes = 0
    end
    if MythicDungeonWheelDB.statistics.noVotes == nil then
        MythicDungeonWheelDB.statistics.noVotes = 0
    end
    
    -- Create minimap button
    self:CreateMinimapButton()
    
    -- Register communication prefix
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
    end
    
    -- Register events
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PARTY_LEADER_CHANGED") 
    self:RegisterEvent("CHAT_MSG_ADDON")
    
    -- Create slash commands
    SLASH_MDW1 = "/mdw"
    SlashCmdList["MDW"] = function(msg) self:SlashHandler(msg) end
    
    -- Set initial window height (compact since voting is not active)
    C_Timer.After(0.1, function() self:AdjustWindowHeight() end)
    
    self:DebugPrint("|cff00ff00MythicDungeonWheel|r loaded! Use /mdw to open interface or /mdw help for commands.")
end

-- Slash command handler
function MDW:SlashHandler(msg)
    local trimmedMsg = string.trim(msg)
    local command, remainder = trimmedMsg:match("^(%S+)%s*(.*)")
    
    if command then
        command = string.lower(command)
    else
        command = ""
        remainder = ""
    end
    
    if command == "" then
        self:ToggleInterface()
    elseif command == "debug" then
        self:ToggleDebugMode()
    elseif command == "help" then
        self:ShowHelp()
    -- Debug mode commands
    elseif self.debugMode then
        if command == "test" then
            self:ToggleTestMode()
        elseif command == "reset" then
            self:ResetSession()
        elseif command == "start" then
            self:StartSession()
        elseif command == "scan" then
            print("|cff00ff00Scanning bags for keystones...|r")
            local keystones = self:GetPlayerKeystones()
            if #keystones == 0 then
                print("|cffff0000No keystones found in bags.|r")
                print("Make sure you have a Mythic Keystone item.")
            else
                print("|cff00ff00Found " .. #keystones .. " keystone(s):|r")
                for i, keystone in ipairs(keystones) do
                    print("  " .. i .. ": +" .. keystone.level .. " " .. keystone.dungeon)
                end
            end
        elseif command == "info" then
            print("|cff00ff00Debug Info:|r")
            print("Addon loaded: " .. tostring(MythicDungeonWheel ~= nil))
            print("Main frame exists: " .. tostring(MythicDungeonWheelFrame ~= nil))
            print("Session active: " .. tostring(self.session.active))
            print("Test mode: " .. tostring(self.testMode))
            print("Debug mode: " .. tostring(self.debugMode))
            
            -- Debug keystone detection
            local keystones = self:GetPlayerKeystones()
            print("Keystones found: " .. #keystones)
            for i, keystone in ipairs(keystones) do
                print("  " .. i .. ": +" .. (keystone.level or 0) .. " " .. (keystone.dungeon or "Unknown"))
            end
        elseif command == "stats" then
            self:ShowStatistics()
        elseif command == "resetstats" then
            self:ResetStatistics(remainder)
        else
            print("|cffff0000Unknown debug command:|r " .. command)
            self:ShowHelp()
        end
    else
        print("|cffff0000Unknown command:|r " .. command .. " (Use '/mdw debug' to enable more commands)")
        self:ShowHelp()
    end
end

function MDW:ShowHelp()
    print("|cff00ff00Mythic Dungeon Wheel Commands:|r")
    print("  /mdw - Opens the Mythic Dungeon Wheel window")
    print("  /mdw debug - Enables debug mode, unlocking more commands and logging")
    print("  /mdw help - Shows list of currently available commands")
    
    if self.debugMode then
        print("|cffffff00Debug Mode Commands (Additional):|r")
        print("  /mdw start - Start a new session (any party member)")
        print("  /mdw reset - Reset current session (any party member)")
        print("  /mdw test - Toggle test mode (adds fake keystones)")
        print("  /mdw scan - Scan bags for keystones")
        print("  /mdw stats - Show wheel decision statistics")
        print("  /mdw resetStats - Reset all statistics data")
        print("  /mdw info - Show debug information")
    end
end

function MDW:ShowStatistics()
    print("|cff00ff00Mythic Dungeon Wheel Statistics:|r")
    print("Total keys completed: " .. (MythicDungeonWheelDB.statistics.totalCompleted or 0))
    
    if MythicDungeonWheelDB.statistics.completedKeys and #MythicDungeonWheelDB.statistics.completedKeys > 0 then
        print("|cffffff00Recent completed keys:|r")
        local recent = {}
        for i = math.max(1, #MythicDungeonWheelDB.statistics.completedKeys - 9), #MythicDungeonWheelDB.statistics.completedKeys do
            table.insert(recent, MythicDungeonWheelDB.statistics.completedKeys[i])
        end
        
        for i, key in ipairs(recent) do
            print("  " .. key.date .. " - " .. key.dungeon)
        end
        
        if #MythicDungeonWheelDB.statistics.completedKeys > 10 then
            print("  ... (showing last 10 entries)")
        end
    else
        print("No completed keys yet. Start wheeling to build your statistics!")
    end
    
    -- Show voting behavior statistics
    print("|cffffff00Voting Behavior:|r")
    print("You have obeyed the wheel: " .. (MythicDungeonWheelDB.statistics.yesVotes or 0) .. " times")
    print("You have disobeyed the wheel: " .. (MythicDungeonWheelDB.statistics.noVotes or 0) .. " times")
end

function MDW:ResetStatistics(args)
    -- Only allow in debug mode for safety
    if not self.debugMode then
        print("|cffff0000Error:|r resetStats command is only available in debug mode")
        return
    end
    
    -- Check if user provided confirmation
    if not args or string.lower(args) ~= "confirm" then
        print("|cffff0000WARNING:|r This will permanently delete all your statistics data!")
        print("Type '/mdw resetStats confirm' to proceed with the reset.")
        return
    end
    
    -- Reset all statistics data
    MythicDungeonWheelDB.statistics = {
        completedKeys = {},
        totalCompleted = 0,
        yesVotes = 0,
        noVotes = 0
    }
    
    print("|cff00ff00All statistics have been reset!|r")
    print("Completed keys: 0")
    print("Voting behavior: 0 obeyed, 0 disobeyed")
    
    -- Update the UI display if it's showing
    self:UpdateVotingStatsDisplay()
end

function MDW:UpdateVotingStatsDisplay()
    local statsFrame = MythicDungeonWheelFrameVotingStats
    local statsText = MythicDungeonWheelFrameVotingStatsText
    if not statsFrame or not statsText then
        return
    end
    
    local hasActiveSession = self.session and self.session.active
    
    -- Hide stats on results screen (when vote result is being shown)
    local resultFrame = MythicDungeonWheelFrameVoteResult
    if resultFrame and resultFrame:IsShown() then
        statsFrame:Hide()
        return
    end
    
    -- Hide stats during ANY active session
    if hasActiveSession then
        statsFrame:Hide()
        return
    end
    
    -- Show stats only on idle screen (no active session)
    statsFrame:Show()
    local yesVotes = MythicDungeonWheelDB.statistics.yesVotes or 0
    local noVotes = MythicDungeonWheelDB.statistics.noVotes or 0
    statsText:SetText("You have obeyed the wheel: " .. yesVotes .. " times\nYou have disobeyed the wheel: " .. noVotes .. " times")
end

function MDW:ToggleTestMode()
    self.testMode = not self.testMode
    if self.testMode then
        if self.debugMode then
            print("|cff00ff00Test mode enabled|r - Fake keystones will be available")
        end
        self:AddTestKeystones()
    else
        if self.debugMode then
            print("|cffff0000Test mode disabled|r")
        end
        -- Reset session if it was a test session
        if self.session.active then
            if self.debugMode then
                print("|cffffff00Resetting test session...|r")
            end
            self:ResetSession()
        end
    end
    self:UpdateInterface()
end

function MDW:ToggleDebugMode()
    self.debugMode = not self.debugMode
    if self.debugMode then
        print("|cff00ff00Debug mode enabled|r - Additional commands are now available")
        print("Type '/mdw help' to see the full command list")
    else
        print("|cffff0000Debug mode disabled|r - Only basic commands are available")
        -- If test mode was active, disable it too
        if self.testMode then
            self:ToggleTestMode()
        end
    end
    self:UpdateInterface()
end

function MDW:AddTestKeystones()
    -- Add some test keystones for development with random player names
    local testPlayers = {"Shadowmage", "Healbot", "Tankzilla", "Roguelike", "Huntress"}
    local testKeystones = {
        {level = 15, dungeon = "Eco-Dome Al'dani"},
        {level = 12, dungeon = "Ara-Kara, City of Echoes"},
        {level = 18, dungeon = "The Dawnbreaker"},
        {level = 14, dungeon = "Operation: Floodgate"},
        {level = 16, dungeon = "Priory of the Sacred Flame"},
        {level = 20, dungeon = "Halls of Atonement"},
        {level = 13, dungeon = "Tazavesh: Streets of Wonder"}
    }
    
    -- Add keystones from 4 fake players (excluding yours, so 5 total when you add yours)
    for i = 1, 4 do
        local player = testPlayers[i]
        local keystone = testKeystones[i]
        local keystoneKey = player .. "_" .. keystone.level .. "_" .. keystone.dungeon
        
        self.session.keystones[keystoneKey] = {
            player = player,
            level = keystone.level,
            dungeon = keystone.dungeon,
            isTest = true
        }
    end
    
    if self.debugMode then
        print("|cff00ff00Test mode:|r Added 4 fake players with keystones. Add your own keystone to make 5 total.")
    end
end

-- Session management
function MDW:StartSession()
    -- Check if there's already an active session
    if self.session.active then
        if self.debugMode then
            print("|cffff0000A session is already active (owned by " .. (self.session.owner or "Unknown") .. "). Reset it first.|r")
        end
        return
    end
    
    -- Allow any party member to start a session (or solo in test mode)
    if not self.testMode and not IsInGroup() then
        if self.debugMode then
            print("|cffff0000You must be in a party or raid to start a session.|r")
        end
        return
    end
    
    self.session.active = true
    self.session.owner = UnitName("player")
    self.session.isOwner = true
    self.session.participants = {}
    self.session.keystones = {}
    self.session.selectedKeystone = nil
    
    -- Add test keystones if in test mode
    if self.testMode then
        self:AddTestKeystones()
    end
    
    -- Notify group (only if in a group)
    if IsInGroup() then
        self:SendMessage("SESSION_START", {
            owner = self.session.owner
        })
    end
    
    if self.debugMode then
        print("|cff00ff00Session started!|r Players can now add their keystones.")
    end
    self:UpdateInterface()
end

function MDW:ResetSession()
    -- Check if there's any active session OR ongoing animation to reset
    local hasActiveSession = self.session.active
    local hasActiveAnimation = self.scrollingAnimation.isAnimating
    
    if not hasActiveSession and not hasActiveAnimation then
        if self.debugMode then
            print("|cffff0000No active session or animation to reset.|r")
        end
        return
    end
    
    local wasOwner = self.session.isOwner
    local previousOwner = self.session.owner
    
    -- Stop any ongoing scrolling animation immediately
    if hasActiveAnimation then
        if self.debugMode then
            print("|cffffff00Stopping ongoing animation...|r")
        end
        self.scrollingAnimation.isAnimating = false
        self.scrollingAnimation.selectedKeystone = nil
        self.scrollingAnimation.keystoneSnapshot = nil
    end
    
    -- Hide voting UI when resetting
    self:HideVotingUI()
    
    -- Always reset all button highlighting back to default when resetting session
    local content = (self.ui and self.ui.keystoneListChild) or MythicDungeonWheelFrameKeystoneListScrollChild
    if content and content.buttons then
        for _, button in ipairs(content.buttons) do
            if button and button.bg and button.bg.SetColorTexture then
                button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8) -- Default gray
            end
        end
    end
    
    -- Reset session data (even if session wasn't active, ensure it's fully cleared)
    self.session.active = false
    self.session.owner = nil
    self.session.participants = {}
    self.session.keystones = {}
    self.session.selectedKeystone = nil
    self.session.selectedKeystoneRemoved = false
    self.session.isOwner = false
    
    -- Reset voting state
    if self.session.voting.timer then
        self.session.voting.timer:Cancel()
        self.session.voting.timer = nil
    end
    
    -- Cancel auto-reset timer if it exists
    if self.session.autoResetTimer then
        self.session.autoResetTimer:Cancel()
        self.session.autoResetTimer = nil
    end
    
    self.session.voting.active = false
    self.session.voting.votes = {}
    self.session.voting.voteCount = 0
    self.session.voting.totalVotes = 0
    self.session.voting.totalMembers = 0
    self.session.voting.timeLeft = 30
    self:HideVotingUI()
    
    -- Hide vote result
    local resultFrame = MythicDungeonWheelFrameVoteResult
    if resultFrame then
        resultFrame:Hide()
    end
    
    -- Reset scrolling animation state to initial values
    self.scrollingAnimation = {
        isAnimating = false,
        selectedKeystone = nil
    }
    
    -- Notify group if in a group and there was an active session
    if IsInGroup() and hasActiveSession then
        self:SendMessage("SESSION_RESET", {
            resetBy = UnitName("player"),
            previousOwner = previousOwner
        })
    end
    
    if hasActiveSession and hasActiveAnimation then
        if self.debugMode then
            print("|cff00ff00Session and animation reset. Addon returned to initial state.|r")
        end
    elseif hasActiveSession then
        if self.debugMode then
            print("|cff00ff00Session reset. Addon returned to initial state.|r")
        end
    elseif hasActiveAnimation then
        if self.debugMode then
            print("|cff00ff00Animation stopped. Addon returned to initial state.|r")
        end
    end
    
    self:UpdateInterface()
end

-- Keystone management
function MDW:GetPlayerKeystones()
    local keystones = {}
    
    -- First, scan bags for actual keystones using multiple detection methods
    self:DebugPrint("MDW Debug: Starting keystone scan...")
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo then
                    local itemLink = C_Container.GetContainerItemLink(bag, slot)
                    if itemLink then
                        -- Debug: Print every item we examine
                        self:DebugPrint("MDW Debug: Examining bag " .. bag .. " slot " .. slot .. " - ItemID: " .. (itemInfo.itemID or "nil") .. " - Link: " .. (itemLink or "nil"))
                        
                        -- Method 1: Check if this is a keystone by examining the link format
                        if itemLink:find("|Hkeystone:") then
                            self:DebugPrint("MDW Debug: Found keystone by link format in bag " .. bag .. " slot " .. slot)
                            local keystone = self:ParseKeystoneLink(itemLink)
                            if keystone then
                                table.insert(keystones, keystone)
                            end
                        -- Method 2: Check by item ID (fallback)
                        elseif itemInfo.itemID == KEYSTONE_ITEM_ID then
                            self:DebugPrint("MDW Debug: Found keystone by item ID in bag " .. bag .. " slot " .. slot)
                            local keystone = self:ParseKeystoneLink(itemLink)
                            if keystone then
                                table.insert(keystones, keystone)
                            end
                        -- Method 3: Check by item name (fallback)
                        elseif itemLink:find(KEYSTONE_ITEM_NAME) then
                            self:DebugPrint("MDW Debug: Found keystone by name in bag " .. bag .. " slot " .. slot)
                            local keystone = self:ParseKeystoneLink(itemLink)
                            if keystone then
                                table.insert(keystones, keystone)
                            end
                        -- Method 4: Tooltip scanning (most comprehensive fallback)
                        elseif itemLink:find("Keystone") or itemLink:find("Mythic") then
                            self:DebugPrint("MDW Debug: Potential keystone found, scanning tooltip...")
                            local keystone = self:ScanKeystoneTooltip(bag, slot, itemLink)
                            if keystone then
                                self:DebugPrint("MDW Debug: Found keystone by tooltip scan in bag " .. bag .. " slot " .. slot)
                                table.insert(keystones, keystone)
                            end
                        end
                    end
                end
            end
        end
    end
    self:DebugPrint("MDW Debug: Keystone scan complete. Found " .. #keystones .. " keystones.")
    
    -- ONLY in test mode: if no real keystones found, provide a fallback keystone
    if self.testMode and #keystones == 0 then
        self:DebugPrint("|cffffff00No keystones found in bags, using fallback test keystone.|r")
        return {
            {level = 17, dungeon = "Priory of the Sacred Flame", isTest = true}
        }
    end
    
    -- In normal mode: if no keystones found, just return empty table (no buttons will show)
    -- Only show helpful message if in an active session
    if #keystones == 0 and self.session.active and not self.testMode then
        self:DebugPrint("|cffffff00No keystones found in bags.|r Make sure you have a Mythic Keystone.")
    end
    
    return keystones
end

function MDW:ScanKeystoneTooltip(bag, slot, itemLink)
    -- Create a unique tooltip for scanning
    local tooltipName = "MDWKeystoneTooltip" .. bag .. slot
    local tooltip = CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetBagItem(bag, slot)
    
    local foundKeystone = nil
    
    -- Check tooltip lines for keystone information
    for i = 1, tooltip:NumLines() do
        local leftLine = _G[tooltipName .. "TextLeft" .. i]
        if leftLine then
            local text = leftLine:GetText()
            if text then
                -- Look for "Keystone: DungeonName" in tooltip
                if text:find("Keystone:") then
                    local dungeonName = text:match("Keystone: (.+)")
                    if dungeonName then
                        -- Look for level in the next few lines
                        for j = i, math.min(i + 3, tooltip:NumLines()) do
                            local levelLine = _G[tooltipName .. "TextLeft" .. j]
                            if levelLine then
                                local levelText = levelLine:GetText()
                                if levelText then
                                    local level = levelText:match("Level (%d+)") or levelText:match("%+(%d+)")
                                    if level then
                                        foundKeystone = {
                                            level = tonumber(level),
                                            dungeon = dungeonName,
                                            link = itemLink
                                        }
                                        self:DebugPrint("MDW Debug: Tooltip scan found - Level: " .. level .. ", Dungeon: " .. dungeonName)
                                        break
                                    end
                                end
                            end
                        end
                        break
                    end
                end
                
                -- Alternative: Look for "Mythic" and level patterns
                if not foundKeystone and (text:find("Mythic") or text:find("Keystone")) then
                    local level = text:match("Level (%d+)") or text:match("%+(%d+)")
                    if level then
                        -- Try to get dungeon name from item link or use generic name
                        local dungeonName = "Mythic Keystone"
                        local visibleText = itemLink and itemLink:match("|h%[([^%]]+)%]|h")
                        if visibleText then
                            local extractedDungeon = visibleText:match("Keystone: ([^%(]+)")
                            if extractedDungeon then
                                dungeonName = extractedDungeon:trim()
                            end
                        end
                        
                        foundKeystone = {
                            level = tonumber(level),
                            dungeon = dungeonName,
                            link = itemLink
                        }
                        self:DebugPrint("MDW Debug: Tooltip scan fallback found - Level: " .. level .. ", Dungeon: " .. dungeonName)
                        break
                    end
                end
            end
        end
    end
    
    tooltip:Hide()
    return foundKeystone
end

function MDW:ParseKeystoneLink(itemLink)
    if not itemLink then return nil end
    
    self:DebugPrint("MDW Debug: Parsing keystone link: " .. itemLink)
    
    -- Extract the display text from the link - this is what the player sees
    -- Format: |cffa335ee|Hkeystone:...|h[Keystone: DungeonName (+Level)]|h|r
    local visibleText = itemLink:match("|h%[([^%]]+)%]|h")
    self:DebugPrint("MDW Debug: Visible text: " .. tostring(visibleText))
    
    if visibleText then
        -- Extract level from (+XX) pattern
        local level = visibleText:match("%(+(%d+)%)")
        
        -- Extract dungeon name from "Keystone: DungeonName" pattern
        local dungeon = visibleText:match("Keystone: ([^%(]+)")
        
        self:DebugPrint("MDW Debug: Extracted level: " .. tostring(level) .. ", dungeon: " .. tostring(dungeon))
        
        if level and dungeon then
            -- Clean up the dungeon name (remove extra whitespace)
            dungeon = string.trim(dungeon)
            
            self:DebugPrint("MDW Debug: Successfully parsed - Level: " .. level .. ", Dungeon: '" .. dungeon .. "'")
            return {
                level = tonumber(level),
                dungeon = dungeon,
                link = itemLink
            }
        else
            self:DebugPrint("MDW Debug: Could not extract level or dungeon from visible text")
        end
    else
        self:DebugPrint("MDW Debug: Could not extract visible text from link")
    end
    
    self:DebugPrint("MDW Debug: Failed to parse keystone")
    return nil
end

function MDW:AddPlayerKeystone(keystoneIndex)
    if not self.session.active then
        if self.debugMode then
            print("|cffff0000No active session. Any party member can start one.|r")
        end
        return
    end
    
    -- Don't allow adding keystones while rolling animation is active
    if self.scrollingAnimation.isAnimating then
        if self.debugMode then
            print("|cffff0000Cannot add keystones while rolling is in progress.|r")
        end
        return
    end
    
    local playerName = UnitName("player")
    
    -- Check if player already has a keystone in the session
    for key, keystone in pairs(self.session.keystones) do
        if keystone.player == playerName then
            if self.debugMode then
                print("|cffff0000You already have a keystone in this session:|r " .. keystone.level .. " " .. keystone.dungeon)
            end
            return
        end
    end
    
    local keystones = self:GetPlayerKeystones()
    local keystone = keystones[keystoneIndex]
    
    if not keystone then
        if self.debugMode then
            print("|cffff0000Invalid keystone selection.|r")
        end
        return
    end
    
    -- Add keystone to session
    local keystoneKey = playerName .. "_" .. (keystone.level or "test") .. "_" .. (keystone.dungeon or "test")
    self.session.keystones[keystoneKey] = {
        player = playerName,
        level = keystone.level,
        dungeon = keystone.dungeon,
        link = keystone.link,
        isTest = keystone.isTest or self.testMode
    }
    
    -- Notify group (only if in a group)
    if IsInGroup() then
        self:SendMessage("KEYSTONE_ADDED", {
            player = playerName,
            level = tostring(keystone.level),
            dungeon = keystone.dungeon,
            isTest = tostring(keystone.isTest or self.testMode)
        })
    end
    
    if self.debugMode then
        print("|cff00ff00Keystone added to session!|r +" .. keystone.level .. " " .. keystone.dungeon)
    end
    self:UpdateInterface()
end

function MDW:GetPlayerKeystoneInSession()
    if not self.session.active then
        return nil
    end
    
    local playerName = UnitName("player")
    for key, keystone in pairs(self.session.keystones) do
        if keystone.player == playerName then
            return key, keystone
        end
    end
    return nil
end

function MDW:RemoveKeystoneFromSession(keystoneKey, keystone)
    if not self.session.active then
        if self.debugMode then
            print("|cffff0000No active session.|r")
        end
        return
    end
    
    -- Don't allow removing keystones while rolling animation is active
    if self.scrollingAnimation.isAnimating then
        if self.debugMode then
            print("|cffff0000Cannot remove keystones while rolling is in progress.|r")
        end
        return
    end
    
    -- Don't allow removing keystones while voting is active
    if self.session.voting and self.session.voting.active then
        if self.debugMode then
            print("|cffff0000Cannot remove keystones while voting is in progress.|r")
        end
        return
    end
    
    -- Only session owner can remove other players' keystones
    if not self.session.isOwner then
        if self.debugMode then
            print("|cffff0000Only the session owner can remove keystones.|r")
        end
        return
    end
    
    if not self.session.keystones[keystoneKey] then
        if self.debugMode then
            print("|cffff0000Keystone not found in session.|r")
        end
        return
    end
    
    -- Remove keystone from session
    self.session.keystones[keystoneKey] = nil
    
    -- Check if the removed keystone was the selected winner and update display
    if self.session.selectedKeystone and 
       self.session.selectedKeystone.player == keystone.player and
       self.session.selectedKeystone.level == keystone.level and
       self.session.selectedKeystone.dungeon == keystone.dungeon then
        -- Mark that the selected keystone was removed
        self.session.selectedKeystoneRemoved = true
        if self.debugMode then
            print("|cffffff00Marked selected keystone as removed|r")
        end
    end
    
    -- Notify group (only if in a group)
    if IsInGroup() then
        self:SendMessage("KEYSTONE_REMOVED", {
            player = keystone.player,
            level = tostring(keystone.level),
            dungeon = keystone.dungeon,
            removedBy = UnitName("player")
        })
    end
    
    if self.debugMode then
        print("|cff00ff00Removed keystone:|r " .. keystone.player .. "'s +" .. keystone.level .. " " .. keystone.dungeon)
    end
    self:UpdateInterface()
end

function MDW:RemovePlayerKeystone()
    if not self.session.active then
        if self.debugMode then
            print("|cffff0000No active session.|r")
        end
        return
    end
    
    -- Don't allow removing keystones while rolling animation is active
    if self.scrollingAnimation.isAnimating then
        if self.debugMode then
            print("|cffff0000Cannot remove keystones while rolling is in progress.|r")
        end
        return
    end
    
    -- Don't allow removing keystones while voting is active
    if self.session.voting and self.session.voting.active then
        if self.debugMode then
            print("|cffff0000Cannot remove keystones while voting is in progress.|r")
        end
        return
    end
    
    local playerName = UnitName("player")
    local keystoneKey, keystone = self:GetPlayerKeystoneInSession()
    
    if not keystoneKey then
        if self.debugMode then
            print("|cffff0000You don't have a keystone in this session.|r")
        end
        return
    end
    
    -- Remove keystone from session
    self.session.keystones[keystoneKey] = nil
    
    -- Check if the removed keystone was the selected winner and update display
    if self.session.selectedKeystone and 
       self.session.selectedKeystone.player == keystone.player and
       self.session.selectedKeystone.level == keystone.level and
       self.session.selectedKeystone.dungeon == keystone.dungeon then
        -- Mark that the selected keystone was removed
        self.session.selectedKeystoneRemoved = true
        if self.debugMode then
            print("|cffffff00Marked selected keystone as removed|r")
        end
    end
    
    -- Notify group (only if in a group)
    if IsInGroup() then
        self:SendMessage("KEYSTONE_REMOVED", {
            player = playerName,
            level = tostring(keystone.level),
            dungeon = keystone.dungeon
        })
    end
    
    if self.debugMode then
        print("|cff00ff00Keystone removed from session!|r +" .. keystone.level .. " " .. keystone.dungeon)
    end
    self:UpdateInterface()
end

function MDW:SelectRandomKeystone()
    if not self.session.active then
        print("|cffff0000No active session.|r")
        return
    end
    
    -- Anyone can now select a keystone (democratic approach)
    -- Removed the session leader restriction
    
    local keystoneList = {}
    for key, keystone in pairs(self.session.keystones) do
        table.insert(keystoneList, {key = key, keystone = keystone})
    end
    
    if #keystoneList == 0 then
        if self.debugMode then
            print("|cffff0000No keystones available for selection.|r")
        end
        return
    end
    
    -- Use scrolling animation for all selections
    self:StartScrollingAnimation(keystoneList)
end

-- Communication
function MDW:SendMessage(msgType, data)
    local message = msgType
    if data then
        message = msgType .. ":" .. self:SerializeData(data)
    end
    
    if IsInGroup() then
        if IsInRaid() then
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, message, "RAID")
        else
            C_ChatInfo.SendAddonMessage(COMM_PREFIX, message, "PARTY")
        end
    end
end

function MDW:SerializeData(data)
    -- Simple serialization - in a real addon you'd want something more robust
    local result = ""
    for k, v in pairs(data) do
        if type(v) == "table" then
            result = result .. k .. "=" .. self:SerializeData(v) .. ";"
        else
            result = result .. k .. "=" .. tostring(v) .. ";"
        end
    end
    return result
end

function MDW:DeserializeData(str)
    local data = {}
    for pair in str:gmatch("([^;]+)") do
        local key, value = pair:match("([^=]+)=([^=]*)")
        if key and value then
            data[key] = value
        end
    end
    return data
end

function MDW:CHAT_MSG_ADDON(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    if sender == UnitName("player") then return end -- Ignore our own messages
    
    local msgType, dataStr = message:match("^([^:]+):?(.*)")
    if not msgType then return end
    
    local data = nil
    if dataStr and dataStr ~= "" then
        data = self:DeserializeData(dataStr)
    end
    
    if msgType == "SESSION_START" then
        -- Only accept session start if no active session exists
        if not self.session.active then
            self.session.active = true
            self.session.owner = data and data.owner or sender
            self.session.isOwner = false
            self.session.keystones = {}
            self.session.selectedKeystone = nil
            if self.debugMode then
                print("|cff00ff00Session started by " .. (data and data.owner or sender) .. "|r")
            end
            self:UpdateInterface()
        else
            -- Session already exists, notify sender
            if self.debugMode then
                print("|cffff9999Ignoring session start from " .. sender .. " - session already active by " .. (self.session.owner or "Unknown") .. "|r")
            end
        end
        
    elseif msgType == "SESSION_RESET" then
        if self.session.active then
            local resetBy = data and data.resetBy or sender
            local previousOwner = data and data.previousOwner or "Unknown"
            self.session.active = false
            self.session.owner = nil
            self.session.participants = {}
            self.session.keystones = {}
            self.session.selectedKeystone = nil
            self.session.isOwner = false
            if self.debugMode then
                print("|cff00ff00Session reset by " .. resetBy .. "|r")
            end
            self:UpdateInterface()
        end
        
    elseif msgType == "KEYSTONE_ADDED" then
        if data and data.player and data.level and data.dungeon then
            local keystoneKey = data.player .. "_" .. data.level .. "_" .. data.dungeon
            self.session.keystones[keystoneKey] = {
                player = data.player,
                level = tonumber(data.level),
                dungeon = data.dungeon,
                isTest = data.isTest == "true"
            }
            if self.debugMode then
                print(data.player .. " added a keystone to the session.")
            end
            self:UpdateInterface()
        end
        
    elseif msgType == "KEYSTONE_REMOVED" then
        if data and data.player and data.level and data.dungeon then
            local keystoneKey = data.player .. "_" .. data.level .. "_" .. data.dungeon
            self.session.keystones[keystoneKey] = nil
            
            -- Show different message based on who removed it
            if data.removedBy and data.removedBy ~= data.player then
                if self.debugMode then
                    print(data.removedBy .. " removed " .. data.player .. "'s keystone from the session.")
                end
            else
                if self.debugMode then
                    print(data.player .. " removed their keystone from the session.")
                end
            end
            self:UpdateInterface()
        end
        
    elseif msgType == "KEYSTONE_SELECTED" then
        if data and data.player and data.level and data.dungeon then
            self.session.selectedKeystone = {
                player = data.player,
                level = tonumber(data.level),
                dungeon = data.dungeon,
                isTest = data.isTest == "true"
            }
            if self.debugMode then
                print("|cff00ff00Selected keystone:|r " .. data.player .. "'s +" .. data.level .. " " .. data.dungeon)
            end
            self:UpdateInterface()
        end
        
    elseif msgType == "VOTING_STARTED" then
        if data and data.totalMembers then
            self.session.voting.active = true
            self.session.voting.votes = {}
            self.session.voting.voteCount = 0
            self.session.voting.totalVotes = 0
            self.session.voting.totalMembers = tonumber(data.totalMembers)
            self.session.voting.timeLeft = 30
            self:ShowVotingUI()
            self:StartVotingTimer()
            self:DebugPrint("Voting started - 30 seconds for " .. data.totalMembers .. " members")
        end
        
    elseif msgType == "VOTE_CAST" then
        if data and data.player and data.vote and data.voteCount and data.totalVotes and data.totalMembers then
            self.session.voting.votes[data.player] = data.vote == "true"
            self.session.voting.voteCount = tonumber(data.voteCount)
            self.session.voting.totalVotes = tonumber(data.totalVotes)
            self.session.voting.totalMembers = tonumber(data.totalMembers)
            
            -- Update UI
            self:UpdateVotingProgress()
            
            self:DebugPrint(data.player .. " voted " .. data.vote .. " (" .. data.totalVotes .. "/" .. data.totalMembers .. ")")
        end
        
    elseif msgType == "VOTING_COMPLETE" then
        if data and data.passed and data.yesVotes and data.totalMembers then
            if self.session.voting.timer then
                self.session.voting.timer:Cancel()
                self.session.voting.timer = nil
            end
            
            self.session.voting.active = false
            
            -- Hide voting buttons
            local yesButton = MythicDungeonWheelFrameVoteYesButton
            local noButton = MythicDungeonWheelFrameVoteNoButton
            if yesButton then yesButton:Hide() end
            if noButton then noButton:Hide() end
            
            -- Show result
            local resultFrame = MythicDungeonWheelFrameVoteResult
            local resultText = MythicDungeonWheelFrameVoteResultText
            if resultFrame and resultText then
                resultFrame:Show()
                local passed = data.passed == "true"
                if passed then
                    resultText:SetText("Vote: Yes")
                else
                    resultText:SetText("Vote: No")
                end
            end
            
            self:DebugPrint("Vote " .. (data.passed == "true" and "passed" or "failed") .. " (" .. data.yesVotes .. "/" .. data.totalMembers .. ")")
        end
        
    elseif msgType == "STATS_UPDATE" then
        if data and data.passed and data.yesVotes and data.noVotes then
            -- Update local statistics to match the session owner's stats
            MythicDungeonWheelDB.statistics.yesVotes = tonumber(data.yesVotes) or 0
            MythicDungeonWheelDB.statistics.noVotes = tonumber(data.noVotes) or 0
            
            local passed = data.passed == "true"
            self:DebugPrint("Statistics synced from session owner - Group " .. (passed and "obeyed" or "disobeyed") .. " the wheel")
            self:DebugPrint("Updated lifetime group decisions: " .. MythicDungeonWheelDB.statistics.yesVotes .. " Obeyed, " .. MythicDungeonWheelDB.statistics.noVotes .. " Disobeyed")
        end
    end
end

-- Interface management
-- Event handler for when UI elements are loaded
function MDW:OnAddonLoaded()
    -- Cache UI element references to avoid undefined global warnings
    self.ui = {
        frame = MythicDungeonWheelFrame,
        statusText = MythicDungeonWheelFrameStatusText,
        keystoneList = MythicDungeonWheelFrameKeystoneList,
        keystoneListChild = MythicDungeonWheelFrameKeystoneListScrollChild,
        selectedKeystone = MythicDungeonWheelFrameSelectedKeystone,
        selectedKeystoneText = MythicDungeonWheelFrameSelectedKeystoneText,
        startButton = MythicDungeonWheelFrameStartButton,
        selectButton = MythicDungeonWheelFrameSelectButton,
        resetButton = MythicDungeonWheelFrameResetButton
    }
    
    -- Initialize the interface
    self:DebugPrint("MDW Debug: Addon loaded with scrolling animation enabled")
end

-- Event registration
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "MythicDungeonWheel" then
        MDW:OnAddonLoaded()
    end
end)

function MDW:ToggleInterface()
    local frame = (self.ui and self.ui.frame) or MythicDungeonWheelFrame
    if frame then
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
            self:UpdateInterface()
        end
    end
end

function MDW:UpdateInterface()
    local frame = (self.ui and self.ui.frame) or MythicDungeonWheelFrame
    if not frame or not frame:IsShown() then
        return
    end
    
    -- Calculate required width for all entries
    local maxWidth = 250 -- Minimum width
    local playerKeystones = self:GetPlayerKeystones()
    
    -- Check player keystone widths (approximate text width calculation)
    for _, keystone in ipairs(playerKeystones) do
        local text = "Add: +" .. (keystone.level or 0) .. " " .. (keystone.dungeon or "Unknown")
        local textWidth = string.len(text) * 7 + 40 -- Approximate width calculation + padding
        maxWidth = math.max(maxWidth, textWidth)
    end
    
    -- Check session keystone widths
    if self.session.active then
        for _, keystone in pairs(self.session.keystones) do
            local testIndicator = (keystone.isTest and " (TEST)") or ""
            local text = (keystone.player or "Unknown") .. "'s +" .. (keystone.level or 0) .. " " .. (keystone.dungeon or "Unknown") .. testIndicator
            local textWidth = string.len(text) * 7 + 40 -- Approximate width calculation + padding
            maxWidth = math.max(maxWidth, textWidth)
        end
    end
    
    local buttonWidth = math.min(maxWidth, 420) -- Cap at 420 to fit in our 450px container
    
    -- Update session owner display
    local ownerElement = MythicDungeonWheelFrameOwnerText
    if ownerElement then
        if self.session.active and self.session.owner then
            ownerElement:SetText("Session by: " .. self.session.owner)
            ownerElement:Show()
        else
            ownerElement:Hide()
        end
    end
    
    -- Update session status
    local statusText = "No active session"
    if self.session.active then
        local keystoneCount = 0
        for _ in pairs(self.session.keystones) do
            keystoneCount = keystoneCount + 1
        end
        statusText = "Session active - " .. keystoneCount .. " keystone(s)"
    end
    
    local statusElement = (self.ui and self.ui.statusText) or MythicDungeonWheelFrameStatusText
    if statusElement then
        statusElement:SetText(statusText)
    end
    
    -- Update keystone list
    self:UpdateKeystoneList()
    
    -- Update selected keystone
    self:UpdateSelectedKeystone()
    
    -- Update buttons
    self:UpdateButtons()
    
    -- Update voting statistics display
    self:UpdateVotingStatsDisplay()
end

function MDW:UpdateKeystoneList()
    local scrollFrame = (self.ui and self.ui.keystoneList) or MythicDungeonWheelFrameKeystoneList
    if not scrollFrame then return end
    
    local content = (self.ui and self.ui.keystoneListChild) or MythicDungeonWheelFrameKeystoneListScrollChild
    if not content then return end
    
    -- Initialize buttons table if it doesn't exist
    if not content.buttons then
        content.buttons = {}
    end
    
    -- Clear existing buttons
    for i = 1, #content.buttons do
        content.buttons[i]:Hide()
    end
    
    -- Player's available keystones
    local playerKeystones = self:GetPlayerKeystones()
    local yOffset = -10
    
    if self.session.active then
        -- Check if player already has a keystone in the session
        local playerKeystoneKey, playerSessionKeystone = self:GetPlayerKeystoneInSession()
        
        if playerKeystoneKey then
            -- Player has a keystone - show remove button
            local button = content.buttons[1]
            if not button then
                button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                content.buttons[1] = button
            end
            button:SetSize(420, 35)
            button:SetPoint("TOP", content, "TOP", 0, yOffset)
            
            local buttonText
            if playerSessionKeystone.isTest then
                buttonText = "Remove Your Key: +" .. (playerSessionKeystone.level or 0) .. " " .. (playerSessionKeystone.dungeon or "Unknown") .. " (TEST)"
            else
                buttonText = "Remove Your Key: +" .. (playerSessionKeystone.level or 0) .. " " .. (playerSessionKeystone.dungeon or "Unknown")
            end
            
            button:SetText(buttonText)
            button:SetNormalFontObject("GameFontNormal")
            button:SetScript("OnClick", function()
                MDW:RemovePlayerKeystone()
            end)
            
            -- Disable button during animation
            if self.scrollingAnimation.isAnimating then
                button:SetEnabled(false)
                button:SetAlpha(0.5) -- Make it visually appear disabled
            else
                button:SetEnabled(true)
                button:SetAlpha(1.0)
            end
            
            button:Show()
            
            yOffset = yOffset - 45
        else
            -- Player doesn't have a keystone - show add keystone buttons for player's keystones
            for i, keystone in ipairs(playerKeystones) do
                local button = content.buttons[i]
                if not button then
                    button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    content.buttons[i] = button
                end
                button:SetSize(420, 35) -- Use maximum width to fit all text
                
                button:SetPoint("TOP", content, "TOP", 0, yOffset)
                
                -- Better button text for single keystone vs multiple
                local buttonText
                if #playerKeystones == 1 then
                    -- Single keystone - more natural text
                    if keystone.isTest then
                        buttonText = "Add Your Key: +" .. (keystone.level or 0) .. " " .. (keystone.dungeon or "Unknown") .. " (TEST)"
                    else
                        buttonText = "Add Your Key: +" .. (keystone.level or 0) .. " " .. (keystone.dungeon or "Unknown")
                    end
                else
                    -- Multiple keystones - use original format
                    buttonText = "Add: +" .. (keystone.level or 0) .. " " .. (keystone.dungeon or "Unknown")
                end
                
                button:SetText(buttonText)
                button:SetNormalFontObject("GameFontNormal")
                button:SetScript("OnClick", function()
                    MDW:AddPlayerKeystone(i)
                end)
                
                -- Disable button during animation
                if self.scrollingAnimation.isAnimating then
                    button:SetEnabled(false)
                    button:SetAlpha(0.5) -- Make it visually appear disabled
                else
                    button:SetEnabled(true)
                    button:SetAlpha(1.0)
                end
                
                button:Show()
                
                yOffset = yOffset - 45
            end
        end
    end
    
    -- Session keystones
    if self.session.active then
        yOffset = yOffset - 10
        local buttonIndex = #playerKeystones + 1
        for key, keystone in pairs(self.session.keystones) do
            local button = content.buttons[buttonIndex]
            if not button then
                button = CreateFrame("Frame", nil, content)
                
                -- Add background texture for highlighting
                button.bg = button:CreateTexture(nil, "BACKGROUND")
                button.bg:SetAllPoints()
                button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8) -- Default gray background
                
                -- Create text for keystone info
                local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                text:SetPoint("LEFT", button, "LEFT", 5, 0)
                text:SetPoint("RIGHT", button, "RIGHT", -30, 0) -- Leave space for X button
                text:SetJustifyH("LEFT")
                button.text = text
                
                -- Create remove button (X) for session owner
                local removeButton = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
                removeButton:SetSize(25, 25)
                removeButton:SetPoint("RIGHT", button, "RIGHT", -5, 0)
                removeButton:SetText("×") -- Unicode multiplication sign looks like X
                removeButton:SetNormalFontObject("GameFontNormal")
                button.removeButton = removeButton
                
                content.buttons[buttonIndex] = button
            end
            button:SetSize(420, 30) -- Use maximum width to fit all text
            
            -- Store keystone reference for animation and remove button
            button.keystone = keystone
            button.keystoneKey = key
            
            button:SetPoint("TOP", content, "TOP", 0, yOffset)
            local testIndicator = (keystone.isTest and " (TEST)") or ""
            local player = keystone.player or "Unknown"
            local level = keystone.level or 0
            local dungeon = keystone.dungeon or "Unknown"
            button.text:SetText(player .. ": +" .. level .. " " .. dungeon .. testIndicator)
            
            -- Configure remove button based on session owner status
            if button.removeButton then
                if self.session.isOwner then
                    button.removeButton:Show()
                    button.removeButton:SetScript("OnClick", function()
                        MDW:RemoveKeystoneFromSession(key, keystone)
                    end)
                    
                    -- Disable remove button during animation
                    if self.scrollingAnimation.isAnimating then
                        button.removeButton:SetEnabled(false)
                        button.removeButton:SetAlpha(0.5) -- Make it visually appear disabled
                    else
                        button.removeButton:SetEnabled(true)
                        button.removeButton:SetAlpha(1.0)
                    end
                    
                    -- Add tooltip for clarity
                    button.removeButton:SetScript("OnEnter", function()
                        GameTooltip:SetOwner(button.removeButton, "ANCHOR_TOP")
                        if self.scrollingAnimation.isAnimating then
                            GameTooltip:AddLine("Cannot remove during rolling")
                            GameTooltip:AddLine("|cffff9999Wait for roll to complete|r", 0.6, 0.6, 0.6)
                        else
                            GameTooltip:AddLine("Remove this keystone from session")
                            GameTooltip:AddLine("|cffff9999(Session owner only)|r", 0.6, 0.6, 0.6)
                        end
                        GameTooltip:Show()
                    end)
                    button.removeButton:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                else
                    button.removeButton:Hide()
                end
            end
            
            button:Show()
            
            yOffset = yOffset - 40
            buttonIndex = buttonIndex + 1
        end
        
        -- Reset all session buttons to default gray, then highlight winner if present
        local playerKeystonesCount = #playerKeystones
        for i = playerKeystonesCount + 1, #content.buttons do
            local button = content.buttons[i]
            if button and button.bg then
                -- Reset to default gray
                button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                
                -- Check if this button's keystone is the selected winner and still in session
                if self.session.selectedKeystone and button.keystone and
                   button.keystone.player == self.session.selectedKeystone.player and
                   button.keystone.level == self.session.selectedKeystone.level and
                   button.keystone.dungeon == self.session.selectedKeystone.dungeon then
                    -- This keystone is still in session and is the winner - highlight it green
                    button.bg:SetColorTexture(0.2, 0.8, 0.2, 0.9)
                end
            end
        end
    end
end

function MDW:UpdateSelectedKeystone()
    local selectedFrame = (self.ui and self.ui.selectedKeystone) or MythicDungeonWheelFrameSelectedKeystone
    if not selectedFrame then return end
    
    if self.session.selectedKeystone then
        local keystone = self.session.selectedKeystone
        if keystone then
            local selectedText = (self.ui and self.ui.selectedKeystoneText) or MythicDungeonWheelFrameSelectedKeystoneText
            if selectedText then
                -- Set label and content separately
                local labelText = MythicDungeonWheelFrameSelectionLabelText
                if labelText then
                    labelText:SetText("Selected:")
                end
                
                -- Check if the selected keystone was removed
                if self.session.selectedKeystoneRemoved then
                    selectedText:SetText("REMOVED")
                else
                    local testIndicator = (keystone.isTest and " (TEST)") or ""
                    local player = keystone.player or "Unknown"
                    local level = keystone.level or 0
                    local dungeon = keystone.dungeon or "Unknown"
                    selectedText:SetText(player .. "'s +" .. level .. " " .. dungeon .. testIndicator)
                end
            end
            selectedFrame:Show()
            
            -- Also show the label
            local labelFrame = MythicDungeonWheelFrameSelectionLabel
            if labelFrame then
                labelFrame:Show()
            end
        end
    else
        selectedFrame:Hide()
        
        -- Clear the label text but keep the frame visible
        local labelFrame = MythicDungeonWheelFrameSelectionLabel
        local labelText = MythicDungeonWheelFrameSelectionLabelText
        if labelFrame then
            labelFrame:Show()
        end
        if labelText then
            labelText:SetText("")
        end
    end
end

function MDW:UpdateButtons()
    -- Start session button - show if no active session and in party/raid or test mode
    local startButton = (self.ui and self.ui.startButton) or MythicDungeonWheelFrameStartButton
    if startButton then
        if not self.session.active and (IsInGroup() or self.testMode) then
            startButton:Show()
        else
            startButton:Hide()
        end
    end
    
    -- "Get Rolling!" button - show if session is active and has keystones
    local selectButton = (self.ui and self.ui.selectButton) or MythicDungeonWheelFrameSelectButton
    if selectButton then
        local hasKeystones = false
        if self.session.active then
            for _ in pairs(self.session.keystones) do
                hasKeystones = true
                break
            end
        end
        
        if self.session.active and hasKeystones then
            selectButton:Show()
        else
            selectButton:Hide()
        end
    end
    
    -- Reset button - show if session is active (anyone can reset)
    local resetButton = (self.ui and self.ui.resetButton) or MythicDungeonWheelFrameResetButton
    if resetButton then
        if self.session.active then
            resetButton:Show()
        else
            resetButton:Hide()
        end
    end
    
    -- Test button - only show if debug mode is enabled
    local testButton = MythicDungeonWheelFrameTestButton
    if testButton then
        if self.debugMode then
            testButton:Show()
        else
            testButton:Hide()
        end
    end
    
    -- Party required text - show when not in session, not in group, and not in test mode
    local partyRequiredFrame = MythicDungeonWheelFramePartyRequiredFrame
    if partyRequiredFrame then
        if not self.session.active and not IsInGroup() and not self.testMode then
            partyRequiredFrame:Show()
        else
            partyRequiredFrame:Hide()
        end
    end
end

-- Event handlers
function MDW:GROUP_ROSTER_UPDATE()
    self:UpdateInterface()
end

function MDW:PARTY_LEADER_CHANGED()
    self:UpdateInterface()
end

-- Simple scrolling animation for wheel mode
function MDW:StartScrollingAnimation(keystoneList)
    if self.scrollingAnimation.isAnimating then
        if self.debugMode then
            print("|cffff0000Already animating selection.|r")
        end
        return
    end
    
    -- Hide voting UI during animation
    self:HideVotingUI()
    
    -- Take a snapshot of the current keystones to ensure consistency during animation
    local keystoneSnapshot = {}
    for _, item in ipairs(keystoneList) do
        table.insert(keystoneSnapshot, {
            key = item.key,
            keystone = {
                player = item.keystone.player,
                level = item.keystone.level,
                dungeon = item.keystone.dungeon,
                isTest = item.keystone.isTest
            }
        })
    end
    
    -- Select the final result from our snapshot
    local selectedIndex = math.random(1, #keystoneSnapshot)
    local selectedKeystone = keystoneSnapshot[selectedIndex].keystone
    self.scrollingAnimation.selectedKeystone = selectedKeystone
    self.scrollingAnimation.keystoneSnapshot = keystoneSnapshot
    self.scrollingAnimation.isAnimating = true
    
    if self.debugMode then
        print("|cff00ff00Starting selection animation...|r")
    end
    
    -- Get UI elements
    local scrollFrame = (self.ui and self.ui.keystoneList) or MythicDungeonWheelFrameKeystoneList
    local content = (self.ui and self.ui.keystoneListChild) or MythicDungeonWheelFrameKeystoneListScrollChild
    local selectedFrame = (self.ui and self.ui.selectedKeystone) or MythicDungeonWheelFrameSelectedKeystone
    local selectedText = (self.ui and self.ui.selectedKeystoneText) or MythicDungeonWheelFrameSelectedKeystoneText
    
    if not scrollFrame or not content or not content.buttons then
        if self.debugMode then
            print("|cffff0000Animation UI not available.|r")
        end
        self:FinishScrollingAnimation()
        return
    end
    
    -- Show the selection box during animation
    if selectedFrame then
        selectedFrame:Show()
    end
    
    -- Show the label frame during animation
    local labelFrame = MythicDungeonWheelFrameSelectionLabel
    if labelFrame then
        labelFrame:Show()
    end
    
    -- Use the keystone snapshot for animation instead of current session
    local sessionKeystones = {}
    local realUIButtons = {}
    
    if self.scrollingAnimation.keystoneSnapshot then
        -- Create UI elements for our snapshot keystones
        for i, item in ipairs(self.scrollingAnimation.keystoneSnapshot) do
            local keystone = item.keystone
            
            -- Try to find the corresponding real UI button for highlighting
            local realButton = nil
            if content and content.buttons then
                for _, uiButton in ipairs(content.buttons) do
                    if uiButton and uiButton.keystone and
                       uiButton.keystone.player == keystone.player and
                       uiButton.keystone.level == keystone.level and
                       uiButton.keystone.dungeon == keystone.dungeon then
                        realButton = uiButton
                        break
                    end
                end
            end
            
            local animationButton = {
                keystone = keystone,
                realUIButton = realButton, -- Reference to actual UI button for highlighting
                bg = realButton and realButton.bg or {
                    SetColorTexture = function() end -- Mock function for highlighting if no real button
                }
            }
            table.insert(sessionKeystones, animationButton)
        end
    else
        -- Fallback: try to use current UI buttons (may be inconsistent if keystones were removed)
        for _, button in ipairs(content.buttons) do
            if button and button.keystone then -- Only buttons with actual keystones
                table.insert(sessionKeystones, button)
            end
        end
    end
    
    if #sessionKeystones == 0 then
        if self.debugMode then
            print("|cffff0000No session keystones available for animation.|r")
        end
        self:FinishScrollingAnimation()
        return
    end
    
    -- Reset colors for all actual UI buttons
    if content and content.buttons then
        for _, button in ipairs(content.buttons) do
            if button and button.bg then
                button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8) -- Default gray
            end
        end
    end
    
    -- Find which position in sessionKeystones corresponds to our selected keystone
    local targetPosition = 1
    for i, button in ipairs(sessionKeystones) do
        if button.keystone and 
           button.keystone.player == selectedKeystone.player and
           button.keystone.level == selectedKeystone.level and
           button.keystone.dungeon == selectedKeystone.dungeon then
            targetPosition = i
            break
        end
    end
    
    -- Calculate total steps needed to land on the winner
    local animationDuration = 10.0 -- 10 seconds total for good dramatic feel
    local minCycles = 5 -- At least 5 full cycles through the list
    local totalSteps = minCycles * #sessionKeystones + (targetPosition - 1)
    
    -- Debug output
    self:DebugPrint("MDW Debug: animationDuration=" .. animationDuration .. ", totalSteps=" .. totalSteps .. ", keystones=" .. #sessionKeystones)
    
    -- Animation parameters
    local startTime = GetTime()
    local currentHighlightIndex = 1
    local currentStep = 0
    local lastUpdateTime = startTime
    
    local function AnimationTick()
        local currentTime = GetTime()
        
        -- Safety check: Stop animation if it was reset/stopped externally
        if not self.scrollingAnimation.isAnimating then
            self:DebugPrint("MDW Debug: Animation stopped externally, halting timer")
            return
        end
        
        -- Calculate current speed based on progress (smooth gradual slowdown throughout)
        local progress = currentStep / totalSteps
        
        -- Calculate next timer interval with linear progression - steady consistent slowdown, faster overall
        local nextInterval = 0.005 + progress * 0.5 -- 0.005s to 0.5s with linear curve
        
        currentStep = currentStep + 1
        
        -- Check if we've reached the target AFTER incrementing
        if currentStep >= totalSteps then
            -- Animation finished - show final selection
            self:FinishScrollingAnimation()
            return
        end
        
        -- Remove previous highlight (try real UI button first, then fall back to bg)
        local prevButton = sessionKeystones[currentHighlightIndex]
        if prevButton then
            if prevButton.realUIButton and prevButton.realUIButton.bg then
                prevButton.realUIButton.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            elseif prevButton.bg and prevButton.bg.SetColorTexture then
                prevButton.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            end
        end
        
        -- Move to next keystone
        currentHighlightIndex = currentHighlightIndex + 1
        if currentHighlightIndex > #sessionKeystones then
            currentHighlightIndex = 1 -- Cycle back to the top
        end
        
        -- Apply yellow highlight to current keystone (try real UI button first, then fall back to bg)
        local currentButton = sessionKeystones[currentHighlightIndex]
        if currentButton then
            if currentButton.realUIButton and currentButton.realUIButton.bg then
                currentButton.realUIButton.bg:SetColorTexture(0.8, 0.6, 0.2, 0.9) -- Yellow highlight
            elseif currentButton.bg and currentButton.bg.SetColorTexture then
                currentButton.bg:SetColorTexture(0.8, 0.6, 0.2, 0.9) -- Yellow highlight
            end
        end
        
        -- Update the selection display with the currently highlighted keystone from our snapshot
        local currentKeystone = sessionKeystones[currentHighlightIndex] and sessionKeystones[currentHighlightIndex].keystone
        if currentKeystone and selectedText then
            local testIndicator = (currentKeystone.isTest and " (TEST)") or ""
            local player = currentKeystone.player or "Unknown"
            local level = currentKeystone.level or 0
            local dungeon = currentKeystone.dungeon or "Unknown"
            
            -- Set label and content separately
            local labelText = MythicDungeonWheelFrameSelectionLabelText
            if labelText then
                labelText:SetText("Rolling:")
            end
            selectedText:SetText(player .. "'s +" .. level .. " " .. dungeon .. testIndicator)
        end
        
        -- Add safety check - if animation runs too long, force completion
        local elapsedTime = currentTime - startTime
        if elapsedTime > 15.0 then -- 15 second maximum safety limit (longer than expected 10s)
            self:DebugPrint("MDW Debug: Animation safety timeout reached, finishing")
            self:FinishScrollingAnimation()
            return
        end
        
        -- Continue animation with variable speed timer
        C_Timer.After(nextInterval, AnimationTick)
    end
    
    AnimationTick()
end

function MDW:FinishScrollingAnimation()
    -- Check if animation was already stopped (e.g., by reset)
    if not self.scrollingAnimation.isAnimating then
        self:DebugPrint("MDW Debug: Animation already stopped, skipping finish")
        return
    end
    
    if not self.scrollingAnimation.selectedKeystone then
        if self.debugMode then
            print("|cffff0000No keystone selected.|r")
        end
        self.scrollingAnimation.isAnimating = false
        return
    end
    
    local selectedKeystone = self.scrollingAnimation.selectedKeystone
    self.session.selectedKeystone = selectedKeystone
    self.session.selectedKeystoneRemoved = false -- Reset the removed flag when a new winner is selected
    self.scrollingAnimation.isAnimating = false
    
    -- Clear the snapshot since animation is done
    self.scrollingAnimation.keystoneSnapshot = nil
    
    -- Get UI elements
    local content = (self.ui and self.ui.keystoneListChild) or MythicDungeonWheelFrameKeystoneListScrollChild
    local selectedText = (self.ui and self.ui.selectedKeystoneText) or MythicDungeonWheelFrameSelectedKeystoneText
    
    if content and content.buttons then
        -- Find the winner in the current UI and highlight it gold
        -- (This may not find anything if the keystone was removed during animation, which is fine)
        for _, button in ipairs(content.buttons) do
            if button and button.bg then
                if button.keystone and 
                   button.keystone.player == selectedKeystone.player and
                   button.keystone.level == selectedKeystone.level and
                   button.keystone.dungeon == selectedKeystone.dungeon then
                    -- This is our winner - make it green
                    button.bg:SetColorTexture(0.2, 0.8, 0.2, 0.9) -- Green highlight for final selection
                else
                    -- Reset all others to gray
                    button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                end
            end
        end
    end
    
    -- Update the selection display with final result
    if selectedText then
        local testIndicator = (selectedKeystone.isTest and " (TEST)") or ""
        local player = selectedKeystone.player or "Unknown"
        local level = selectedKeystone.level or 0
        local dungeon = selectedKeystone.dungeon or "Unknown"
        
        -- Set label and content separately
        local labelText = MythicDungeonWheelFrameSelectionLabelText
        if labelText then
            labelText:SetText("Selected:")
        end
        selectedText:SetText(player .. "'s +" .. level .. " " .. dungeon .. testIndicator)
    end
    
    -- Notify group
    self:SendMessage("KEYSTONE_SELECTED", {
        player = selectedKeystone.player,
        level = tostring(selectedKeystone.level),
        dungeon = selectedKeystone.dungeon,
        isTest = tostring(selectedKeystone.isTest or false)
    })
    
    if self.debugMode then
        print("|cff00ff00Keystone selected:|r " .. selectedKeystone.player .. "'s +" .. selectedKeystone.level .. " " .. selectedKeystone.dungeon)
    end
    
    -- Start voting process
    self:StartVoting()
    
    self:UpdateInterface()
end

-- Voting System Functions
function MDW:StartVoting()
    -- In debug mode, always show voting UI even when solo
    if not IsInGroup() and not self.debugMode then
        -- Solo player - automatically complete the key
        self:CompleteKey()
        return
    end
    
    -- Reset voting state
    self.session.voting.active = true
    self.session.voting.votes = {}
    self.session.voting.voteCount = 0
    self.session.voting.totalVotes = 0
    
    -- Calculate total members who can vote
    local groupSize
    if IsInGroup() then
        groupSize = GetNumGroupMembers()
    elseif self.debugMode then
        -- In debug mode, use actual session participants + test players
        groupSize = self:GetSessionMemberCount()
    else
        groupSize = 1
    end
    self.session.voting.totalMembers = groupSize
    
    -- Show voting UI
    self:ShowVotingUI()

    -- Start 30-second timer
    self.session.voting.timeLeft = 30
    self:StartVotingTimer()

    -- Notify group about voting (skip in solo debug mode)
    if IsInGroup() then
        self:SendMessage("VOTING_STARTED", {
            totalMembers = tostring(groupSize)
        })
    end

    self:DebugPrint("Voting started - 30 seconds for " .. groupSize .. " members to vote")
end

function MDW:GetSessionMemberCount()
    -- Count unique players in the session
    local uniquePlayers = {}
    for key, keystone in pairs(self.session.keystones) do
        if keystone.player then
            uniquePlayers[keystone.player] = true
        end
    end
    
    local sessionCount = 0
    for _ in pairs(uniquePlayers) do
        sessionCount = sessionCount + 1
    end
    
    -- In debug mode when solo, simulate a 5-player group for testing
    if self.debugMode and not IsInGroup() then
        self:DebugPrint("Debug mode: Using simulated 5-player group (1 real + 4 test)")
        return 5 -- Always 5 for debug testing
    end
    
    -- Normal mode: return actual session participant count
    self:DebugPrint("Normal mode: " .. sessionCount .. " real session players")
    return sessionCount
end

function MDW:StartVotingTimer()
    if self.session.voting.timer then
        self.session.voting.timer:Cancel()
    end
    
    -- Initialize test voting simulation for debug mode
    if self.debugMode and not IsInGroup() then
        self:InitializeTestVoting()
    end
    
    self.session.voting.timer = C_Timer.NewTicker(1, function()
        if not self.session.voting.active then
            if self.session.voting.timer then
                self.session.voting.timer:Cancel()
                self.session.voting.timer = nil
            end
            return
        end
        
        self.session.voting.timeLeft = self.session.voting.timeLeft - 1
        
        -- Update timer display
        self:UpdateVotingTimer()
        
        -- In debug mode, simulate random test votes
        if self.debugMode and not IsInGroup() then
            self:SimulateTestVotes()
        end
        
        if self.session.voting.timeLeft <= 0 then
            -- Time's up, complete voting
            self:CompleteVoting()
        end
    end)
end

function MDW:InitializeTestVoting()
    -- This function should only be called in debug mode when solo
    if not self.debugMode or IsInGroup() then
        self:DebugPrint("InitializeTestVoting called incorrectly - not in debug mode or in group")
        return
    end
    
    -- In debug mode when solo, always create test players for a 5-person simulation
    local sessionPlayerCount = 1 -- You (the real player)
    local testPlayerCount = 4    -- Always 4 test players in debug mode
    
    self:DebugPrint("Debug mode: Forcing 1 real player + 4 test players for voting simulation")
    self:DebugPrint("Session keystones count: " .. self:CountSessionKeystones())
    
    -- Create a list of test players
    local testPlayerNames = {"TestWarrior", "TestMage", "TestPriest", "TestRogue"}
    self.session.voting.testPlayers = {}
    
    for i = 1, testPlayerCount do
        table.insert(self.session.voting.testPlayers, testPlayerNames[i])
        self:DebugPrint("Added test player: " .. testPlayerNames[i])
    end
    
    self:DebugPrint("Final test players count: " .. #self.session.voting.testPlayers)
end

function MDW:CountSessionKeystones()
    local count = 0
    for _ in pairs(self.session.keystones) do
        count = count + 1
    end
    return count
end

function MDW:SimulateTestVotes()
    self:DebugPrint("SimulateTestVotes called - testPlayers exists: " .. tostring(self.session.voting.testPlayers ~= nil))
    
    if self.session.voting.testPlayers then
        self:DebugPrint("testPlayers count: " .. #self.session.voting.testPlayers)
        for i, player in ipairs(self.session.voting.testPlayers) do
            self:DebugPrint("  Test player " .. i .. ": " .. player)
        end
    end
    
    if not self.session.voting.testPlayers or #self.session.voting.testPlayers == 0 then
        self:DebugPrint("No test players available to vote")
        return
    end
    
    self:DebugPrint("Simulating votes for " .. #self.session.voting.testPlayers .. " test players")
    
    -- Higher chance for a test player to vote each second (about 50% chance)
    if math.random(100) <= 50 then
        -- Pick a random test player who hasn't voted yet
        local playerIndex = math.random(#self.session.voting.testPlayers)
        local playerName = self.session.voting.testPlayers[playerIndex]
        
        -- Remove this player from the list
        table.remove(self.session.voting.testPlayers, playerIndex)
        
        -- Cast a random vote (60% chance for Yes, 40% chance for No)
        local vote = math.random(100) <= 60
        
        self:DebugPrint("Test player " .. playerName .. " is about to vote: " .. (vote and "Yes" or "No"))
        
        -- Simulate receiving their vote
        self:ProcessTestVote(playerName, vote)
    else
        self:DebugPrint("No test player voted this second (random chance)")
    end
end

function MDW:ProcessTestVote(playerName, vote)
    -- Add to votes tracking
    self.session.voting.votes[playerName] = vote
    self.session.voting.voteCount = self.session.voting.voteCount + 1
    self.session.voting.totalVotes = self.session.voting.totalVotes + (vote and 1 or 0)
    
    -- Update UI
    self:UpdateVotingProgress()
    
    local voteText = vote and "Yes" or "No"
    self:DebugPrint(playerName .. " voted: " .. voteText .. " (" .. self.session.voting.voteCount .. "/" .. self.session.voting.totalMembers .. ")")
    
    -- Check if voting should complete early (all members voted)
    if self.session.voting.voteCount >= self.session.voting.totalMembers then
        C_Timer.After(1, function() -- Small delay to see the final vote
            self:CompleteVoting()
        end)
    end
end

function MDW:ShowVotingUI()
    local votingDivider = MythicDungeonWheelFrameVotingDivider
    local votingTimer = MythicDungeonWheelFrameVotingTimer
    local votingTitle = MythicDungeonWheelFrameVotingTitle
    local progressFrame = MythicDungeonWheelFrameVotingProgress
    local yesButton = MythicDungeonWheelFrameVoteYesButton
    local noButton = MythicDungeonWheelFrameVoteNoButton
    local progressText = MythicDungeonWheelFrameVotingProgressText
    local resultFrame = MythicDungeonWheelFrameVoteResult
    
    self:DebugPrint("ShowVotingUI called")
    self:DebugPrint("Voting divider exists: " .. tostring(votingDivider ~= nil))
    self:DebugPrint("Voting timer exists: " .. tostring(votingTimer ~= nil))
    self:DebugPrint("Voting title exists: " .. tostring(votingTitle ~= nil))
    self:DebugPrint("Progress frame exists: " .. tostring(progressFrame ~= nil))
    self:DebugPrint("Yes button exists: " .. tostring(yesButton ~= nil))
    self:DebugPrint("No button exists: " .. tostring(noButton ~= nil))
    
    if votingDivider then
        votingDivider:Show()
        self:DebugPrint("Voting divider shown")
    end
    
    if votingTimer then
        votingTimer:Show()
        self:UpdateVotingTimer()
        self:DebugPrint("Voting timer shown")
    end
    
    if votingTitle then
        votingTitle:Show()
        self:DebugPrint("Voting title shown")
    end
    
    if progressFrame then
        progressFrame:Show()
        self:DebugPrint("Progress frame shown")
    end
    
    if yesButton then
        yesButton:Show()
        yesButton:SetEnabled(true)
        self:DebugPrint("Yes button shown")
    end
    
    if noButton then
        noButton:Show()
        noButton:SetEnabled(true)
        self:DebugPrint("No button shown")
    end
    
    if resultFrame then
        resultFrame:Hide()
    end
    
    self:UpdateVotingProgress()
    
    -- Adjust window height when voting UI is shown
    self:AdjustWindowHeight()
end

function MDW:UpdateVotingTimer()
    local timerText = MythicDungeonWheelFrameVotingTimerText
    if timerText and self.session.voting.active then
        timerText:SetText("Time remaining to vote: " .. self.session.voting.timeLeft)
    end
end

function MDW:UpdateVotingProgress()
    local progressText = MythicDungeonWheelFrameVotingProgressText
    local progressBar = MythicDungeonWheelFrameVotingProgressBar
    local progressFrame = MythicDungeonWheelFrameVotingProgress
    
    if progressText then
        progressText:SetText(self.session.voting.voteCount .. "/" .. self.session.voting.totalMembers .. " Votes")
    end
    
    if progressBar and progressFrame then
        local progress = 0
        if self.session.voting.totalMembers > 0 then
            progress = self.session.voting.voteCount / self.session.voting.totalMembers
        end
        local maxWidth = progressFrame:GetWidth() - 4 -- Account for borders
        progressBar:SetWidth(maxWidth * progress)
    end
end

function MDW:HideVotingUI()
    local votingDivider = MythicDungeonWheelFrameVotingDivider
    local votingTimer = MythicDungeonWheelFrameVotingTimer
    local votingTitle = MythicDungeonWheelFrameVotingTitle
    local progressFrame = MythicDungeonWheelFrameVotingProgress
    local yesButton = MythicDungeonWheelFrameVoteYesButton
    local noButton = MythicDungeonWheelFrameVoteNoButton
    local resultFrame = MythicDungeonWheelFrameVoteResult
    
    if votingDivider then
        votingDivider:Hide()
    end
    
    if votingTimer then
        votingTimer:Hide()
    end
    
    if votingTitle then
        votingTitle:Hide()
    end
    
    if progressFrame then
        progressFrame:Hide()
    end
    
    if yesButton then
        yesButton:Hide()
    end
    
    if noButton then
        noButton:Hide()
    end
    
    if resultFrame then
        resultFrame:Hide()
    end
    
    -- Adjust window height when voting UI is hidden
    self:AdjustWindowHeight()
end

function MDW:AdjustWindowHeight()
    local mainFrame = MythicDungeonWheelFrame
    if not mainFrame then
        return
    end
    
    -- Check if voting UI is active
    local votingDivider = MythicDungeonWheelFrameVotingDivider
    local isVotingActive = votingDivider and votingDivider:IsShown()
    
    if isVotingActive then
        -- Full height when voting is active (includes voting UI)
        mainFrame:SetHeight(650)
        self:DebugPrint("Window height set to 650 (voting active)")
    else
        -- Compact height when voting is not active (but still room for content)
        mainFrame:SetHeight(550)
        self:DebugPrint("Window height set to 550 (voting inactive)")
    end
end

function MDW:CastVote(vote)
    if not self.session.voting.active then
        return
    end
    
    local playerName = UnitName("player")
    
    -- Prevent double voting
    if self.session.voting.votes[playerName] ~= nil then
        self:DebugPrint("You have already voted!")
        return
    end
    
    -- Record vote
    self.session.voting.votes[playerName] = vote
    self.session.voting.voteCount = self.session.voting.voteCount + 1
    
    if vote then
        self.session.voting.totalVotes = self.session.voting.totalVotes + 1
    end
    
    -- Disable voting buttons for this player
    local yesButton = MythicDungeonWheelFrameVoteYesButton
    local noButton = MythicDungeonWheelFrameVoteNoButton
    if yesButton then yesButton:SetEnabled(false) end
    if noButton then noButton:SetEnabled(false) end
    
    -- Update UI
    self:UpdateVotingProgress()
    
    local voteText = vote and "Yes" or "No"
    self:DebugPrint("You voted: " .. voteText .. " (" .. self.session.voting.voteCount .. "/" .. self.session.voting.totalMembers .. ")")
    
    -- Notify group (skip in debug solo mode)
    if IsInGroup() then
        self:SendMessage("VOTE_CAST", {
            player = playerName,
            vote = tostring(vote),
            voteCount = tostring(self.session.voting.voteCount),
            totalVotes = tostring(self.session.voting.totalVotes),
        totalMembers = tostring(self.session.voting.totalMembers)
        })
    end
    
    -- Check if all members have voted
    if self.session.voting.voteCount >= self.session.voting.totalMembers then
        C_Timer.After(1, function() -- Small delay to see the final vote
            self:CompleteVoting()
        end)
    end
end

function MDW:CompleteVoting()
    if not self.session.voting.active then
        return
    end
    
    -- Cancel timer
    if self.session.voting.timer then
        self.session.voting.timer:Cancel()
        self.session.voting.timer = nil
    end
    
    self.session.voting.active = false
    
    -- Calculate result - majority needed for yes, non-voters count as no
    local yesVotes = self.session.voting.totalVotes
    local totalMembers = self.session.voting.totalMembers
    local majority = math.ceil(totalMembers / 2)
    local passed = yesVotes >= majority
    
    -- Calculate no votes for debug output
    local noVotes = self.session.voting.voteCount - yesVotes
    local nonVoters = totalMembers - self.session.voting.voteCount
    
    self:DebugPrint("Vote Results: " .. yesVotes .. " Yes, " .. noVotes .. " No, " .. nonVoters .. " didn't vote")
    self:DebugPrint("Majority needed: " .. majority .. "/" .. totalMembers .. " - Result: " .. (passed and "PASSED" or "FAILED"))
    
    -- Track group decision for statistics (only for session owner to avoid duplicates)
    if self.session.isOwner then
        if passed then
            MythicDungeonWheelDB.statistics.yesVotes = MythicDungeonWheelDB.statistics.yesVotes + 1
            self:DebugPrint("Group obeyed the wheel - stats updated")
        else
            MythicDungeonWheelDB.statistics.noVotes = MythicDungeonWheelDB.statistics.noVotes + 1
            self:DebugPrint("Group disobeyed the wheel - stats updated")
        end
        self:DebugPrint("Lifetime group decisions: " .. MythicDungeonWheelDB.statistics.yesVotes .. " Obeyed, " .. MythicDungeonWheelDB.statistics.noVotes .. " Disobeyed")
        
        -- Broadcast statistics update to all group members
        if IsInGroup() then
            self:SendMessage("STATS_UPDATE", {
                passed = tostring(passed),
                yesVotes = tostring(MythicDungeonWheelDB.statistics.yesVotes),
                noVotes = tostring(MythicDungeonWheelDB.statistics.noVotes)
            })
        end
    end
    
    -- Hide voting buttons
    local yesButton = MythicDungeonWheelFrameVoteYesButton
    local noButton = MythicDungeonWheelFrameVoteNoButton
    if yesButton then yesButton:Hide() end
    if noButton then noButton:Hide() end
    
    -- Update timer text to show "Finished"
    local timerText = MythicDungeonWheelFrameVotingTimerText
    if timerText then
        timerText:SetText("Time remaining to vote: Finished")
    end
    
    -- Show result
    local resultFrame = MythicDungeonWheelFrameVoteResult
    local resultText = MythicDungeonWheelFrameVoteResultText
    if resultFrame and resultText then
        resultFrame:Show()
        if passed then
            resultText:SetText("Vote: |cff00ff00Yes|r") -- Green "Yes"
            self:CompleteKey()
        else
            resultText:SetText("Vote: |cffff0000No|r") -- Red "No"
        end
    end
    
    self:DebugPrint("Voting complete - " .. (passed and "PASSED" or "FAILED") .. " (" .. yesVotes .. "/" .. totalMembers .. ")")
    
    -- Start auto-reset timer (1 minute) - only for session owner
    if self.session.isOwner then
        self.session.autoResetTimer = C_Timer.NewTimer(60, function()
            self:DebugPrint("Auto-resetting session after 1 minute...")
            self:ResetSession()
        end)
        self:DebugPrint("Auto-reset timer started - session will reset in 1 minute")
    end
    
    -- Notify group
    self:SendMessage("VOTING_COMPLETE", {
        passed = tostring(passed),
        yesVotes = tostring(yesVotes),
        totalMembers = tostring(totalMembers)
    })
end

function MDW:CompleteKey()
    if not self.session.selectedKeystone then
        return
    end
    
    local keystone = self.session.selectedKeystone
    local completedKey = {
        player = keystone.player,
        level = keystone.level,
        dungeon = keystone.dungeon,
        timestamp = time(),
        date = date("%Y-%m-%d %H:%M:%S")
    }
    
    -- Add to statistics
    table.insert(MythicDungeonWheelDB.statistics.completedKeys, completedKey)
    MythicDungeonWheelDB.statistics.totalCompleted = MythicDungeonWheelDB.statistics.totalCompleted + 1
    
    self:DebugPrint("Key completed and recorded! Total completed: " .. MythicDungeonWheelDB.statistics.totalCompleted)
    
    -- Show completion message
    if self.debugMode then
        print("|cff00ff00Key Completed!|r " .. keystone.dungeon)
        print("|cff00ff00Total wheel decisions completed: " .. MythicDungeonWheelDB.statistics.totalCompleted .. "|r")
    end
end
