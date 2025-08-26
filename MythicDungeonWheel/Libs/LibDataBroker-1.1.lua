--[[
Name: LibDataBroker-1.1
Revision: $Rev: 104 $
Author: tekkub (tekkub@gmail.com)
Website: http://www.wowace.com/projects/libdatabroker-1-1/
Description: A central registry for addons looking to display data
Dependencies: LibStub
License: Public Domain
]]


assert(LibStub, "LibDataBroker-1.1 requires LibStub")

local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)

lib.attributestorage = lib.attributestorage or {}
lib.namestorage = lib.namestorage or {}
lib.proxystorage = lib.proxystorage or {}
local attributestorage = lib.attributestorage
local namestorage = lib.namestorage
local callbacks = lib.callbacks

local domt = {
	__metatable = "access denied",
	__index = function(self, key) return attributestorage[self] and attributestorage[self][key] end,
}


local function CreateDataObject(name, dataobj)
	if not name or namestorage[name] then return nil end

	dataobj = dataobj or {}

	namestorage[name] = dataobj
	attributestorage[dataobj] = {}

	for i,v in pairs(dataobj) do
		attributestorage[dataobj][i] = v
		dataobj[i] = nil
	end

	setmetatable(dataobj, domt)
	lib.proxystorage[dataobj] = setmetatable({}, domt)
	attributestorage[lib.proxystorage[dataobj]] = attributestorage[dataobj]

	callbacks:Fire("LibDataBroker_DataObjectCreated", name, dataobj)
	return dataobj
end

-- API
function lib:NewDataObject(name, dataobj)
	return CreateDataObject(name, dataobj)
end

function lib:DataObjectIterator()
	return pairs(namestorage)
end

function lib:GetDataObjectByName(dataobjectname)
	return namestorage[dataobjectname]
end

function lib:GetNameByDataObject(dataobject)
	return attributestorage[dataobject] and (namestorage[dataobject] or dataobject.label or dataobject.text or "<Unknown>")
end


-- Transitional stuff
local startedUp = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
	startedUp = true
end)

local function DoNothing() end
local function RegisterForEvents(self)
	if startedUp then
		self.RegisterEvent = DoNothing
		self.UnregisterEvent = DoNothing
		self.UnregisterAllEvents = DoNothing
	end
end

lib.domt = {
	__metatable = "access denied",
	__index = function(self, key)
		if key == "RegisterEvent" or key == "UnregisterEvent" or key == "UnregisterAllEvents" then
			RegisterForEvents(self)
			return self[key]
		elseif key == "IsEventRegistered" then return DoNothing end

		return attributestorage[self] and attributestorage[self][key]
	end,

	__newindex = function(self, key, val)
		if not attributestorage[self] then attributestorage[self] = {} end
		local oldval = attributestorage[self][key]
		attributestorage[self][key] = val
		local name = lib:GetNameByDataObject(self)
		if not name then return end
		callbacks:Fire("LibDataBroker_AttributeChanged", name, key, val, oldval)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name, name, key, val, oldval)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..key, name, key, val, oldval)
		return val
	end
}


-- Upgrade from 1.0
if oldminor and oldminor < 2 then
	local t = {}
	for name, dataobj in pairs(namestorage) do
		lib.proxystorage[dataobj] = setmetatable({}, lib.domt)
		attributestorage[lib.proxystorage[dataobj]] = attributestorage[dataobj]
		table.insert(t, dataobj)
	end

	for i,v in ipairs(t) do
		setmetatable(v, lib.domt)
	end
end
