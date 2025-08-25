 -- MythicDungeonWheel.lua
-- Main addon file for Mythic Dungeon Wheel

local addonName, addon = ...

-- Initialize addon without LibStub dependencies for simplicity
MythicDungeonWheel = CreateFrame("Frame")
local MDW = MythicDungeonWheel

-- Initialize interface mode
MDW.interfaceMode = "wheel" -- Always use wheel mode with scrolling animation

-- Initialize scrolling animation state
MDW.scrollingAnimation = {
    isAnimating = false,
    selectedKeystone = nil
}

-- Dungeon loading screen textures for Season 3 (using texture file IDs)
MDW.dungeonTextures = {
    -- The War Within Dungeons (using numeric file IDs that should work)
    ["Ara-Kara, City of Echoes"] = 5912204, -- Ara-Kara loading screen
    ["The Dawnbreaker"] = 5912205, -- Dawnbreaker loading screen
    ["Priory of the Sacred Flame"] = 5912206, -- Priory loading screen
    ["Operation: Floodgate"] = 5912207, -- Floodgate loading screen
    ["Eco-Dome Al'dani"] = 5912208, -- EcoDome loading screen
    
    -- Shadowlands Dungeons
    ["Halls of Atonement"] = 3675918, -- Halls loading screen
    ["Tazavesh: Streets of Wonder"] = 4226237, -- Tazavesh loading screen
    ["Tazavesh: So'leah's Gambit"] = 4226237, -- Same as Streets
    
    -- Alternative: Use known working WoW textures for War Within zones
    ["ara-kara-alt"] = "Interface\\WorldMap\\UI-WorldMap-Middle", -- Generic map texture
    ["dawnbreaker-alt"] = "Interface\\Glues\\LoadingScreens\\LoadingScreen_NeutralPandaren",
    
    -- Use actual spell/ability icons that we know exist
    ["spell-ara"] = 136235, -- Spell icon that exists
    ["spell-dawn"] = 136236,
    ["spell-priory"] = 136237,
    ["spell-flood"] = 136238,
    ["spell-eco"] = 136239,
    ["spell-halls"] = 136240,
    ["spell-taza"] = 136241,
    
    -- Simple colored backgrounds as absolute fallback
    ["color-blue"] = nil, -- Will be handled specially
    ["color-green"] = nil,
    ["color-purple"] = nil,
    ["color-orange"] = nil,
    ["color-red"] = nil,
    
    -- Fallback that definitely exists
    ["default"] = "Interface\\Buttons\\UI-Quickslot-Depress"
}

-- Helper function to get dungeon texture with fallbacks
function MDW:GetDungeonTexture(dungeonName)
    if not dungeonName then
        print("MDW Debug: No dungeon name provided, using default texture")
        return self.dungeonTextures["default"]
    end
    
    print("MDW Debug: Looking up texture for dungeon: '" .. dungeonName .. "'")
    
    -- Try exact match first
    local texture = self.dungeonTextures[dungeonName]
    if texture then
        print("MDW Debug: Found exact match texture: " .. tostring(texture))
        return texture
    end
    
    -- Try lowercase partial matches with priority order
    local lowerName = string.lower(dungeonName)
    
    -- Try numeric texture IDs first
    if string.find(lowerName, "ara-kara") then
        return self.dungeonTextures["Ara-Kara, City of Echoes"]
    elseif string.find(lowerName, "dawnbreaker") then
        return self.dungeonTextures["The Dawnbreaker"]
    elseif string.find(lowerName, "priory") then
        return self.dungeonTextures["Priory of the Sacred Flame"]
    elseif string.find(lowerName, "floodgate") then
        return self.dungeonTextures["Operation: Floodgate"]
    elseif string.find(lowerName, "eco-dome") or string.find(lowerName, "al'dani") then
        return self.dungeonTextures["Eco-Dome Al'dani"]
    elseif string.find(lowerName, "halls") then
        return self.dungeonTextures["Halls of Atonement"]
    elseif string.find(lowerName, "tazavesh") then
        return self.dungeonTextures["Tazavesh: Streets of Wonder"]
    end
    
    -- Try spell icons as backup
    if string.find(lowerName, "ara-kara") then
        return self.dungeonTextures["spell-ara"]
    elseif string.find(lowerName, "dawnbreaker") then
        return self.dungeonTextures["spell-dawn"]
    elseif string.find(lowerName, "priory") then
        return self.dungeonTextures["spell-priory"]
    elseif string.find(lowerName, "floodgate") then
        return self.dungeonTextures["spell-flood"]
    elseif string.find(lowerName, "eco-dome") or string.find(lowerName, "al'dani") then
        return self.dungeonTextures["spell-eco"]
    elseif string.find(lowerName, "halls") then
        return self.dungeonTextures["spell-halls"]
    elseif string.find(lowerName, "tazavesh") then
        return self.dungeonTextures["spell-taza"]
    end
    
    -- Debug: Print the dungeon name so we can see what's not matching
    print("MDW Debug: Unknown dungeon texture for: " .. tostring(dungeonName))
    
    -- Fallback to default
    return self.dungeonTextures["default"]
end

-- Helper function to create colored background for dungeons
function MDW:CreateColoredBackground(texture, r, g, b)
    if texture then
        texture:SetColorTexture(r or 0.2, g or 0.3, b or 0.8, 1.0)
        return true
    end
    return false
end

-- Constants
local COMM_PREFIX = "MDW"
local KEYSTONE_ITEM_ID = 180653 -- Mythic Keystone item ID (Dragonflight)
local KEYSTONE_ITEM_NAME = "Mythic Keystone" -- For fallback detection

-- Session data
MDW.session = {
    active = false,
    owner = nil,  -- Who started the session
    participants = {},
    keystones = {},
    selectedKeystone = nil,
    isOwner = false  -- Whether this player owns the session
}

-- Test mode for development
MDW.testMode = false

-- Developer mode (enables test button visibility)
MDW.devMode = false

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
            tooltip:AddLine("|cffeda55fUse /mdw test|r to enable test mode")
        end,
    })
    
    -- Register the minimap button
    LDBIcon:Register("MythicDungeonWheel", minimapButton, MythicDungeonWheelDB)
    print("|cff00ff00MythicDungeonWheel:|r Minimap button created successfully!")
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
        GameTooltip:AddLine("|cffeda55fUse /mdw test|r to enable test mode")
        GameTooltip:AddLine("|cffff9999Note:|r Install LibDBIcon for draggable button")
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Store reference
    self.minimapButton = button
    
    print("|cffffff00MythicDungeonWheel:|r Simple minimap button created (question mark icon).")
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
    SLASH_MDW2 = "/mythicwheel"
    SlashCmdList["MDW"] = function(msg) self:SlashHandler(msg) end
    
    print("|cff00ff00MythicDungeonWheel|r loaded! Use /mdw to open interface or /mdw test to enable test mode.")
end

-- Slash command handler
function MDW:SlashHandler(msg)
    local command = string.lower(string.trim(msg))
    
    if command == "" then
        self:ToggleInterface()
    elseif command == "test" then
        self:ToggleTestMode()
    elseif command == "reset" then
        self:ResetSession()
    elseif command == "start" then
        self:StartSession()
    elseif command == "devmode" then
        self:ToggleDevMode()
    elseif command == "help" then
        self:ShowHelp()
    elseif command == "debug" then
        print("|cff00ff00Debug Info:|r")
        print("Addon loaded: " .. tostring(MythicDungeonWheel ~= nil))
        print("Main frame exists: " .. tostring(MythicDungeonWheelFrame ~= nil))
        print("Session active: " .. tostring(self.session.active))
        print("Test mode: " .. tostring(self.testMode))
        print("Dev mode: " .. tostring(self.devMode))
        
        -- Debug keystone detection
        local keystones = self:GetPlayerKeystones()
        print("Keystones found: " .. #keystones)
        for i, keystone in ipairs(keystones) do
            print("  " .. i .. ": +" .. (keystone.level or 0) .. " " .. (keystone.dungeon or "Unknown"))
        end
        
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
    else
        print("|cffff0000Unknown command:|r " .. command)
        self:ShowHelp()
    end
end

function MDW:ShowHelp()
    print("|cff00ff00Mythic Dungeon Wheel Commands:|r")
    print("  /mdw - Toggle interface")
    print("  /mdw start - Start a new session (any party member)")
    print("  /mdw reset - Reset current session (any party member)")
    print("  /mdw test - Toggle test mode (adds fake keystones)")
    print("  /mdw devmode - Toggle developer mode (shows test button)")
    print("  /mdw scan - Scan bags for keystones")
    print("  /mdw debug - Show debug information")
    print("  /mdw help - Show this help")
end

function MDW:ToggleTestMode()
    self.testMode = not self.testMode
    if self.testMode then
        print("|cff00ff00Test mode enabled|r - Fake keystones will be available")
        self:AddTestKeystones()
    else
        print("|cffff0000Test mode disabled|r")
        -- Clear test data
        self.testPlayerKeystones = nil
        -- Reset session if it was a test session
        if self.session.active then
            print("|cffffff00Resetting test session...|r")
            self:ResetSession()
        end
    end
    self:UpdateInterface()
end

function MDW:ToggleDevMode()
    self.devMode = not self.devMode
    if self.devMode then
        print("|cff00ff00Developer mode enabled|r - Test button is now visible")
    else
        print("|cffff0000Developer mode disabled|r - Test button is now hidden")
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
    
    -- Add keystones from fake players (simulate other group members)
    for i = 1, 3 do
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
    
    -- Keep some keystones available for the current player to add
    -- Store available keystones for the player
    if not self.testPlayerKeystones then
        self.testPlayerKeystones = {}
        for i = 4, 6 do
            table.insert(self.testPlayerKeystones, testKeystones[i])
        end
    end
    
    print("|cff00ff00Test mode:|r Added 3 fake players with keystones. You have 3 keystones available to add.")
end

-- Session management
function MDW:StartSession()
    -- Check if there's already an active session
    if self.session.active then
        print("|cffff0000A session is already active (owned by " .. (self.session.owner or "Unknown") .. "). Reset it first.|r")
        return
    end
    
    -- Allow any party member to start a session (or solo in test mode)
    if not self.testMode and not IsInGroup() then
        print("|cffff0000You must be in a party or raid to start a session.|r")
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
    
    print("|cff00ff00Session started!|r Players can now add their keystones.")
    self:UpdateInterface()
end

function MDW:ResetSession()
    -- Anyone can reset a session
    if not self.session.active then
        print("|cffff0000No active session to reset.|r")
        return
    end
    
    local wasOwner = self.session.isOwner
    local previousOwner = self.session.owner
    
    self.session.active = false
    self.session.owner = nil
    self.session.participants = {}
    self.session.keystones = {}
    self.session.selectedKeystone = nil
    self.session.isOwner = false
    
    -- Notify group if in a group
    if IsInGroup() then
        self:SendMessage("SESSION_RESET", {
            resetBy = UnitName("player"),
            previousOwner = previousOwner
        })
    end
    
    print("|cff00ff00Session reset.|r")
    self:UpdateInterface()
end

function MDW:IsGroupLeader()
    return UnitIsGroupLeader("player")
end

-- Keystone management
function MDW:GetPlayerKeystones()
    local keystones = {}
    
    -- In test mode, simulate having a single keystone (more realistic)
    if self.testMode then
        -- Return a single test keystone to simulate finding one in bags
        return {
            {level = 16, dungeon = "Priory of the Sacred Flame", isTest = true}
        }
    end
    
    -- Scan bags for actual keystones using multiple detection methods
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo then
                    local itemLink = C_Container.GetContainerItemLink(bag, slot)
                    if itemLink then
                        -- Method 1: Check by item ID
                        if itemInfo.itemID == KEYSTONE_ITEM_ID then
                            local keystone = self:ParseKeystoneLink(itemLink)
                            if keystone then
                                table.insert(keystones, keystone)
                            end
                        -- Method 2: Check by item name (fallback)
                        elseif itemLink:find(KEYSTONE_ITEM_NAME) then
                            local keystone = self:ParseKeystoneLink(itemLink)
                            if keystone then
                                table.insert(keystones, keystone)
                            end
                        -- Method 3: Check by tooltip scanning (most reliable)
                        else
                            local keystone = self:ScanKeystoneTooltip(bag, slot, itemLink)
                            if keystone then
                                table.insert(keystones, keystone)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- If no keystones found, show a helpful message
    if #keystones == 0 and self.session.active then
        print("|cffffff00No keystones found in bags.|r Make sure you have a Mythic Keystone.")
    end
    
    return keystones
end

function MDW:ScanKeystoneTooltip(bag, slot, itemLink)
    -- Simple tooltip scan - just look for keystone level
    local tooltip = CreateFrame("GameTooltip", "MDWKeystoneTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetBagItem(bag, slot)
    
    -- Check tooltip lines for keystone level
    for i = 1, tooltip:NumLines() do
        local line = _G["MDWKeystoneTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Look for keystone level indicators
                if text:find("Mythic") and text:find("Level") then
                    local level = text:match("Level (%d+)")
                    if level then
                        tooltip:Hide()
                        return {
                            level = tonumber(level),
                            dungeon = "Keystone", -- Simple fallback
                            link = itemLink
                        }
                    end
                end
            end
        end
    end
    
    tooltip:Hide()
    return nil
end

function MDW:ParseKeystoneLink(itemLink)
    -- Simple keystone parsing - just get level and dungeon name
    
    if not itemLink then return nil end
    
    -- Method 1: Extract info from the visible text in the link
    -- Format: |cffa335ee|Hkeystone:...|h[Keystone: DungeonName (+Level)]|h|r
    local visibleText = itemLink:match("|h%[([^%]]+)%]|h")
    if visibleText then
        local level = visibleText:match("%+(%d+)")
        local dungeon = visibleText:match("Keystone: ([^%(]+)")
        if level and dungeon then
            return {
                level = tonumber(level),
                dungeon = dungeon:trim(),
                link = itemLink
            }
        end
    end
    
    -- Method 2: Try to get level and mapID from link data, then use API for dungeon name
    local linkData = itemLink:match("|H([^|]*)|h")
    if linkData then
        local parts = {strsplit(":", linkData)}
        if parts[1] == "keystone" and parts[3] then
            local mapID = tonumber(parts[2])
            local level = tonumber(parts[3])
            
            -- Get dungeon name from API only (no manual fallback needed)
            local dungeonName = "Unknown Dungeon"
            if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
                local mapInfo = C_ChallengeMode.GetMapUIInfo(mapID)
                if mapInfo and mapInfo.name then
                    dungeonName = mapInfo.name
                end
            end
            
            return {
                level = level,
                dungeon = dungeonName,
                link = itemLink
            }
        end
    end
    
    return nil
end

function MDW:AddPlayerKeystone(keystoneIndex)
    if not self.session.active then
        print("|cffff0000No active session. Any party member can start one.|r")
        return
    end
    
    -- Don't allow adding keystones while rolling animation is active
    if self.scrollingAnimation.isAnimating then
        print("|cffff0000Cannot add keystones while rolling is in progress.|r")
        return
    end
    
    local playerName = UnitName("player")
    
    -- Check if player already has a keystone in the session
    for key, keystone in pairs(self.session.keystones) do
        if keystone.player == playerName then
            print("|cffff0000You already have a keystone in this session:|r " .. keystone.level .. " " .. keystone.dungeon)
            return
        end
    end
    
    local keystones = self:GetPlayerKeystones()
    local keystone = keystones[keystoneIndex]
    
    if not keystone then
        print("|cffff0000Invalid keystone selection.|r")
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
    
    print("|cff00ff00Keystone added to session!|r +" .. keystone.level .. " " .. keystone.dungeon)
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
        print("|cffff0000No active session.|r")
        return
    end
    
    -- Don't allow removing keystones while rolling animation is active
    if self.scrollingAnimation.isAnimating then
        print("|cffff0000Cannot remove keystones while rolling is in progress.|r")
        return
    end
    
    -- Only session owner can remove other players' keystones
    if not self.session.isOwner then
        print("|cffff0000Only the session owner can remove keystones.|r")
        return
    end
    
    if not self.session.keystones[keystoneKey] then
        print("|cffff0000Keystone not found in session.|r")
        return
    end
    
    -- Remove keystone from session
    self.session.keystones[keystoneKey] = nil
    
    -- Notify group (only if in a group)
    if IsInGroup() then
        self:SendMessage("KEYSTONE_REMOVED", {
            player = keystone.player,
            level = tostring(keystone.level),
            dungeon = keystone.dungeon,
            removedBy = UnitName("player")
        })
    end
    
    print("|cff00ff00Removed keystone:|r " .. keystone.player .. "'s +" .. keystone.level .. " " .. keystone.dungeon)
    self:UpdateInterface()
end

function MDW:RemovePlayerKeystone()
    if not self.session.active then
        print("|cffff0000No active session.|r")
        return
    end
    
    -- Don't allow removing keystones while rolling animation is active
    if self.scrollingAnimation.isAnimating then
        print("|cffff0000Cannot remove keystones while rolling is in progress.|r")
        return
    end
    
    local playerName = UnitName("player")
    local keystoneKey, keystone = self:GetPlayerKeystoneInSession()
    
    if not keystoneKey then
        print("|cffff0000You don't have a keystone in this session.|r")
        return
    end
    
    -- Remove keystone from session
    self.session.keystones[keystoneKey] = nil
    
    -- Notify group (only if in a group)
    if IsInGroup() then
        self:SendMessage("KEYSTONE_REMOVED", {
            player = playerName,
            level = tostring(keystone.level),
            dungeon = keystone.dungeon
        })
    end
    
    print("|cff00ff00Keystone removed from session!|r +" .. keystone.level .. " " .. keystone.dungeon)
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
        print("|cffff0000No keystones available for selection.|r")
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
            print("|cff00ff00Session started by " .. (data and data.owner or sender) .. "|r")
            self:UpdateInterface()
        else
            -- Session already exists, notify sender
            print("|cffff9999Ignoring session start from " .. sender .. " - session already active by " .. (self.session.owner or "Unknown") .. "|r")
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
            print("|cff00ff00Session reset by " .. resetBy .. "|r")
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
            print(data.player .. " added a keystone to the session.")
            self:UpdateInterface()
        end
        
    elseif msgType == "KEYSTONE_REMOVED" then
        if data and data.player and data.level and data.dungeon then
            local keystoneKey = data.player .. "_" .. data.level .. "_" .. data.dungeon
            self.session.keystones[keystoneKey] = nil
            
            -- Show different message based on who removed it
            if data.removedBy and data.removedBy ~= data.player then
                print(data.removedBy .. " removed " .. data.player .. "'s keystone from the session.")
            else
                print(data.player .. " removed their keystone from the session.")
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
            print("|cff00ff00Selected keystone:|r " .. data.player .. "'s +" .. data.level .. " " .. data.dungeon)
            self:UpdateInterface()
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
    print("MDW Debug: Addon loaded with scrolling animation enabled")
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
            button:SetSize(420, 25)
            button:SetPoint("TOP", content, "TOP", 0, yOffset)
            
            local buttonText
            if playerSessionKeystone.isTest then
                buttonText = "Remove Your Key: +" .. (playerSessionKeystone.level or 0) .. " " .. (playerSessionKeystone.dungeon or "Unknown") .. " (TEST)"
            else
                buttonText = "Remove Your Key: +" .. (playerSessionKeystone.level or 0) .. " " .. (playerSessionKeystone.dungeon or "Unknown")
            end
            
            button:SetText(buttonText)
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
            
            yOffset = yOffset - 30
        else
            -- Player doesn't have a keystone - show add keystone buttons for player's keystones
            for i, keystone in ipairs(playerKeystones) do
                local button = content.buttons[i]
                if not button then
                    button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    content.buttons[i] = button
                end
                button:SetSize(420, 25) -- Use maximum width to fit all text
                
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
                
                yOffset = yOffset - 30
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
                local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetPoint("LEFT", button, "LEFT", 5, 0)
                text:SetPoint("RIGHT", button, "RIGHT", -30, 0) -- Leave space for X button
                text:SetJustifyH("LEFT")
                button.text = text
                
                -- Create remove button (X) for session owner
                local removeButton = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
                removeButton:SetSize(20, 18)
                removeButton:SetPoint("RIGHT", button, "RIGHT", -5, 0)
                removeButton:SetText("×") -- Unicode multiplication sign looks like X
                removeButton:SetNormalFontObject("GameFontNormalSmall")
                button.removeButton = removeButton
                
                content.buttons[buttonIndex] = button
            end
            button:SetSize(420, 20) -- Use maximum width to fit all text
            
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
            
            yOffset = yOffset - 25
            buttonIndex = buttonIndex + 1
        end
    end
end

function MDW:UpdateSelectedKeystone()
    local selectedFrame = (self.ui and self.ui.selectedKeystone) or MythicDungeonWheelFrameSelectedKeystone
    if not selectedFrame then return end
    
    if self.session.selectedKeystone then
        local keystone = self.session.selectedKeystone
        if keystone then
            local testIndicator = (keystone.isTest and " (TEST)") or ""
            local player = keystone.player or "Unknown"
            local level = keystone.level or 0
            local dungeon = keystone.dungeon or "Unknown"
            
            local selectedText = (self.ui and self.ui.selectedKeystoneText) or MythicDungeonWheelFrameSelectedKeystoneText
            if selectedText then
                -- Set label and content separately
                local labelText = MythicDungeonWheelFrameSelectionLabelText
                if labelText then
                    labelText:SetText("Selected:")
                end
                selectedText:SetText(player .. "'s +" .. level .. " " .. dungeon .. testIndicator)
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
    
    -- Test button - only show if developer mode is enabled
    local testButton = MythicDungeonWheelFrameTestButton
    if testButton then
        if self.devMode then
            testButton:Show()
        else
            testButton:Hide()
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
        print("|cffff0000Already animating selection.|r")
        return
    end
    
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
    
    print("|cff00ff00Starting selection animation...|r")
    
    -- Get UI elements
    local scrollFrame = (self.ui and self.ui.keystoneList) or MythicDungeonWheelFrameKeystoneList
    local content = (self.ui and self.ui.keystoneListChild) or MythicDungeonWheelFrameKeystoneListScrollChild
    local selectedFrame = (self.ui and self.ui.selectedKeystone) or MythicDungeonWheelFrameSelectedKeystone
    local selectedText = (self.ui and self.ui.selectedKeystoneText) or MythicDungeonWheelFrameSelectedKeystoneText
    
    if not scrollFrame or not content or not content.buttons then
        print("|cffff0000Animation UI not available.|r")
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
        print("|cffff0000No session keystones available for animation.|r")
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
    local animationDuration = 12.0 -- 12 seconds total for longer dramatic feel
    local minCycles = 5 -- At least 5 full cycles through the list
    local totalSteps = minCycles * #sessionKeystones + (targetPosition - 1)
    
    -- Debug output
    print("MDW Debug: animationDuration=" .. animationDuration .. ", totalSteps=" .. totalSteps .. ", keystones=" .. #sessionKeystones)
    
    -- Animation parameters
    local startTime = GetTime()
    local currentHighlightIndex = 1
    local currentStep = 0
    local lastUpdateTime = startTime
    
    local function AnimationTick()
        local currentTime = GetTime()
        
        -- Calculate current speed based on progress (smooth gradual slowdown throughout)
        local progress = currentStep / totalSteps
        
        -- Calculate next timer interval with linear progression - steady consistent slowdown, slightly faster overall
        local nextInterval = 0.008 + progress * 0.8 -- 0.008s to 0.8s with linear curve
        
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
        
        -- Apply green highlight to current keystone (try real UI button first, then fall back to bg)
        local currentButton = sessionKeystones[currentHighlightIndex]
        if currentButton then
            if currentButton.realUIButton and currentButton.realUIButton.bg then
                currentButton.realUIButton.bg:SetColorTexture(0.2, 0.8, 0.2, 0.9) -- Green highlight
            elseif currentButton.bg and currentButton.bg.SetColorTexture then
                currentButton.bg:SetColorTexture(0.2, 0.8, 0.2, 0.9) -- Green highlight
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
        if elapsedTime > 18.0 then -- 18 second maximum safety limit (longer than expected 12s)
            print("MDW Debug: Animation safety timeout reached, finishing")
            self:FinishScrollingAnimation()
            return
        end
        
        -- Continue animation with variable speed timer
        C_Timer.After(nextInterval, AnimationTick)
    end
    
    AnimationTick()
end

function MDW:FinishScrollingAnimation()
    if not self.scrollingAnimation.selectedKeystone then
        print("|cffff0000No keystone selected.|r")
        return
    end
    
    local selectedKeystone = self.scrollingAnimation.selectedKeystone
    self.session.selectedKeystone = selectedKeystone
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
                    -- This is our winner - make it gold
                    button.bg:SetColorTexture(0.8, 0.6, 0.2, 0.9) -- Gold highlight for final selection
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
    
    print("|cff00ff00Keystone selected:|r " .. selectedKeystone.player .. "'s +" .. selectedKeystone.level .. " " .. selectedKeystone.dungeon)
    self:UpdateInterface()
end
