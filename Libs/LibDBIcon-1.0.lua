-----------------------------------------------------------------------
-- LibDBIcon-1.0
--
-- Allows addons to easily create a lightweight minimap icon as an alternative to heavier LDB displays.
--

local MAJOR, MINOR = "LibDBIcon-1.0", 45
assert(LibStub, MAJOR.." requires LibStub")
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.radius = lib.radius or 5
lib.tooltip = lib.tooltip or CreateFrame("GameTooltip", "LibDBIconTooltip", UIParent, "GameTooltipTemplate")

local next, Minimap = next, Minimap
local isDraggingButton = false

function lib:IconCallback(event, name, key, value, dataobj)
	if lib.objects[name] then
		if key == "icon" then
			lib.objects[name].icon:SetTexture(value)
		elseif key == "iconCoords" then
			if value then
				lib.objects[name].icon:SetTexCoord(value[1], value[2], value[3], value[4])
			else
				lib.objects[name].icon:SetTexCoord(0, 1, 0, 1)
			end
		elseif key == "iconR" then
			local _, g, b = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(value, g, b)
		elseif key == "iconG" then
			local r, _, b = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(r, value, b)
		elseif key == "iconB" then
			local r, g, _ = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(r, g, value)
		end
	end
end

local function getAnchors(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

local function onEnter(self)
	if isDraggingButton then return end

	for _, button in next, lib.objects do
		if button.showOnMouseover then
			button.fadeOut:Stop()
			button:SetAlpha(button.db.minimapPos.lock and 1 or 0.8)
		end
	end

	local obj = self.dataObject
	if obj.OnTooltipShow then
		lib.tooltip:SetOwner(self, "ANCHOR_NONE")
		lib.tooltip:SetPoint(getAnchors(self))
		obj.OnTooltipShow(lib.tooltip)
		lib.tooltip:Show()
	elseif obj.OnEnter then
		obj.OnEnter(self)
	end
end

local function onLeave(self)
	lib.tooltip:Hide()

	if not isDraggingButton then
		for _, button in next, lib.objects do
			if button.showOnMouseover and not button:IsMouseOver() then
				button.fadeOut:Play()
			end
		end
	end

	local obj = self.dataObject
	if obj.OnLeave then
		obj.OnLeave(self)
	end
end

local function onClick(self, button)
	if self.dataObject.OnClick then
		self.dataObject.OnClick(self, button)
	end
end

local function updatePosition(button, position)
	local angle = math.rad(position or 225) -- start position
	local x, y = math.cos(angle), math.sin(angle)
	local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local round = minimapShape == "ROUND"
	local w = (Minimap:GetWidth() / 2) + lib.radius
	local h = (Minimap:GetHeight() / 2) + lib.radius

	if round then
		x, y = x*w, y*h
	else
		x = math.max(-w, math.min(x*w, w))
		y = math.max(-h, math.min(y*h, h))
	end

	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onUpdate(self)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale

	local pos = 225
	if mx and my and px and py then
		local d = math.deg(math.atan2(py - my, px - mx)) % 360
		pos = math.floor(d)
	end

	if self.db then
		self.db.minimapPos.minimapPos = pos
		updatePosition(self, pos)
	end
end

local function onDragStart(self)
	self:LockHighlight()
	self.isMoving = true
	isDraggingButton = true
	self:SetScript("OnUpdate", onUpdate)
	lib.tooltip:Hide()
	for _, button in next, lib.objects do
		if button.showOnMouseover then
			button.fadeOut:Stop()
			button:SetAlpha(0.8)
		end
	end
end

local function onDragStop(self)
	self:SetScript("OnUpdate", nil)
	self.isMoving = nil
	isDraggingButton = false
	self:UnlockHighlight()
	for _, button in next, lib.objects do
		if button.showOnMouseover and not button:IsMouseOver() then
			button.fadeOut:Play()
		end
	end
end

local defaultCoords = {0, 1, 0, 1}
local function createButton(name, object, db)
	local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
	button:SetFrameStrata("MEDIUM")
	button:SetSize(31, 31)
	button:SetFrameLevel(8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(136477) --"Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture(136430) --"Interface\\Minimap\\MiniMap-TrackingBorder"
	overlay:SetPoint("TOPLEFT")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture(136467) --"Interface\\Minimap\\UI-Minimap-Background"
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon

	button.isMoving = false
	button.dataObject = object
	button.db = db

	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)

	local fadeOut = button:CreateAnimationGroup()
	local alpha = fadeOut:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(0.2)
	alpha:SetSmoothing("OUT")
	alpha:SetScript("OnFinished", function() button:SetAlpha(0.6) end)
	button.fadeOut = fadeOut

	return button
end

-- We hook SetParent specifically to handle Minimap Frame changes
local function onSetParent(self, parent)
	if parent == Minimap then
		return
	end
	self:SetParent(Minimap)
end

function lib:Register(name, object, db)
	if not object.icon then return end

	if lib.objects[name] then
		lib.objects[name]:Hide()
	end

	local button = createButton(name, object, db)
	button.dataObject = object
	button.db = db

	if not lib.callbackRegistered then
		local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
		if LDB then
			LDB.RegisterCallback(lib, "LibDataBroker_AttributeChanged", "IconCallback")
			lib.callbackRegistered = true
		end
	end

	lib.objects[name] = button

	if object.icon then
		button.icon:SetTexture(object.icon)
	end
	if object.iconCoords then
		button.icon:SetTexCoord(object.iconCoords[1], object.iconCoords[2], object.iconCoords[3], object.iconCoords[4])
	else
		button.icon:SetTexCoord(0, 1, 0, 1)
	end

	button:SetScript("OnDragStart", db.lock and function() end or onDragStart)
	button:EnableMouse(not db.hide)

	button:ClearAllPoints()
	updatePosition(button, db.minimapPos.minimapPos)

	if not db.hide then
		button:Show()
		if db.showOnMouseover then
			button.showOnMouseover = true
			button:SetAlpha(0)
		else
			button.showOnMouseover = false
			button:SetAlpha(db.minimapPos.lock and 1 or 0.8)
		end
	end

	lib.callbacks:Fire("LibDBIcon_IconRegistered", name, button)
end

function lib:Hide(name)
	if not lib.objects[name] then return end
	lib.objects[name]:Hide()
end

function lib:Show(name)
	local button = lib.objects[name]
	if not button then return end
	button:Show()
	if button.showOnMouseover then
		button:SetAlpha(0)
	else
		button:SetAlpha(button.db.minimapPos.lock and 1 or 0.8)
	end
end

function lib:IsRegistered(name)
	return (lib.objects[name] and true) or false
end

function lib:Refresh(name, db)
	local button = lib.objects[name]
	if not button then return end

	button.db = db
	button:SetScript("OnDragStart", db.lock and function() end or onDragStart)
	button:EnableMouse(not db.hide)

	if db.hide then
		button:Hide()
	elseif not button:IsShown() then
		button:Show()
	end

	updatePosition(button, db.minimapPos.minimapPos)

	if db.showOnMouseover then
		button.showOnMouseover = true
		button:SetAlpha(0)
	else
		button.showOnMouseover = false
		button:SetAlpha(db.minimapPos.lock and 1 or 0.8)
	end
end

function lib:GetMinimapButton(name)
	return lib.objects[name]
end

function lib:GetButtonList()
	local t = {}
	for name in next, lib.objects do
		t[#t+1] = name
	end
	return t
end

function lib:SetButtonRadius(radius)
	if type(radius) == "number" then
		lib.radius = radius
		for _, button in next, lib.objects do
			updatePosition(button, button.db.minimapPos.minimapPos)
		end
	end
end

function lib:SetButtonToPosition(name, position)
	local button = lib.objects[name]
	if not button then return end
	updatePosition(button, position)
	button.db.minimapPos.minimapPos = position
end

-- Upgrades
for name, button in next, lib.objects do
	local db = button.db
	if not db or not db.minimapPos then
		lib.objects[name] = nil
	else
		if not db.minimapPos.lock then
			db.minimapPos.lock = false
		end
		if not db.minimapPos.minimapPos then
			db.minimapPos.minimapPos = 225
		end
		if not db.hide then
			db.hide = false
		end
		if db.showOnMouseover == nil then
			db.showOnMouseover = true
		end

		button:SetScript("OnDragStart", db.lock and function() end or onDragStart)
		button:SetScript("OnDragStop", onDragStop)

		-- Restore position
		updatePosition(button, db.minimapPos.minimapPos)

		if db.showOnMouseover then
			button.showOnMouseover = true
			button:SetAlpha(0)
		else
			button.showOnMouseover = false
			button:SetAlpha(db.minimapPos.lock and 1 or 0.8)
		end

		button:SetScript("OnEnter", onEnter)
		button:SetScript("OnLeave", onLeave)
	end
end
