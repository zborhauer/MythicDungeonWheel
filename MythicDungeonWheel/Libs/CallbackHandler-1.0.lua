--[[ $Id: CallbackHandler-1.0.lua 22 2018-07-21 14:17:22Z funkydude $ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

-- Lua APIs
local tconcat = table.concat
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler

local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function Dispatch(handlers, ...)
	local index, method = next(handlers)
	if not method then return end
	repeat
		xpcall(method, errorhandler, ...)
		index, method = next(handlers, index)
	until not method
end

--------------------------------------------------------------------------
-- CallbackHandler:New
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks".  false == don't publish this API.

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we declare all objects and exported APIs inside this closure to quickly gain access
	-- to e.g. function names, the "target" parameter, etc


	-- Create the registry object
	local events = setmetatable({}, meta)
	local registry = { recurse=0, events=events }

	-- registry:Fire() - fires the given event/message into the registry
	function registry:Fire(eventname, ...)
		if not rawget(events, eventname) or not next(events[eventname]) then return end
		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		Dispatch(events[eventname], eventname, ...)

		registry.recurse = oldrecurse

		if registry.insertQueue and oldrecurse==0 then
			-- Something in one of our callbacks wanted to register more callbacks; they got queued
			for eventname, callbacks in pairs(registry.insertQueue) do
				local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.
				for self, func in pairs(callbacks) do
					events[eventname][self] = func
					-- fire OnUsed callback?
					if first and registry.OnUsed then
						registry.OnUsed(registry, target, eventname)
						first = nil
					end
				end
			end
			registry.insertQueue = nil
		end
	end

	-- Registration of a callback, handles:
	--   self["method"], leads to self["method"](self, ...)
	--   self with function ref, leads to functionref(...)
	--   "addonId" (instead of self) with function ref, leads to functionref(...)
	-- all with an optional arg, which, if present, gets passed as first argument (after self if present)
	target[RegisterName] = function(self, eventname, method, ... --[[actually just a single arg]])
		if type(eventname) ~= "string" then
			error("Usage: "..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.", 2)
		end

		method = method or eventname

		local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.

		if type(method) == "string" then
			-- self["method"] calling style
			if type(self) ~= "table" then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'self' - table expected.", 2)
			end
			if select("#", ...) ~= 0 then	-- this is not the same as testing for arg==nil!
				local arg = select(1, ...)
				if type(arg) ~= "nil" then
					error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"[, arg]): 'arg' - expected 'nil', got '"..type(arg).."'.", 2)
				end
			end
			local func = function(...) self[method](self, ...) end
			events[eventname][self] = func
		elseif type(method) == "function" then
			-- function ref with self=object or self="addonId" or self=thread
			local func
			if type(self)=="string" then
				if select("#", ...) ~= 0 then	-- this is not the same as testing for arg==nil!
					local arg = select(1, ...)
					func = function(...) method(arg, ...) end
				else
					func = method
				end
				self = self.."."..tostring(method)  -- append method ref to self identifier
			elseif nargs==0 then	-- self=thread
				func = method
			else
				local arg = select(1, ...)
				if select("#", ...) ~= 1 then
					error("Usage: "..RegisterName.."(self, \"eventname\", method): wrong number of arguments", 2)
				end
				if type(arg) ~= "nil" then
					func = function(...) method(arg, ...) end
				else
					func = method
				end
			end
			events[eventname][self] = func
		else
			error("Usage: "..RegisterName.."(eventname, method): 'method' - function or string expected.", 2)
		end

		if registry.recurse<1 then
			-- if fire OnUsed callback?
			if first and registry.OnUsed then
				registry.OnUsed(registry, target, eventname)
			end
		else
			-- we're currently processing a callback in this registry, so delay any OnUsed callbacks until we're done
			registry.insertQueue = registry.insertQueue or setmetatable({}, meta)
			registry.insertQueue[eventname][self] = events[eventname][self]
			events[eventname][self] = nil
		end
	end

	-- Unregister a callback
	target[UnregisterName] = function(self, eventname)
		if not self or not eventname then
			error("Usage: "..UnregisterName.."(eventname): 'self' and 'eventname' must be provided", 2)
		end
		if rawget(events, eventname) and events[eventname][self] then
			events[eventname][self] = nil
			-- if lastunused and registry.OnUnused then
			--   registry.OnUnused(registry, target, eventname)
			-- end
		end
		if registry.insertQueue and rawget(registry.insertQueue, eventname) and registry.insertQueue[eventname][self] then
			registry.insertQueue[eventname][self] = nil
		end
	end

	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	if UnregisterAllName then
		target[UnregisterAllName] = function(...)
			if select("#",...)<1 then
				error("Usage: "..UnregisterAllName.."([whatFor]): missing 'self' or \"addonId\" to unregister events for.", 2)
			end
			if select("#",...)==1 and ... == target then
				error("Usage: "..UnregisterAllName.."([whatFor]): supply a meaningful 'self' or \"addonId\"", 2)
			end


			for i=1,select("#",...) do
				local self = select(i,...)
				if registry.insertQueue then
					for eventname, callbacks in pairs(registry.insertQueue) do
						if callbacks[self] then
							callbacks[self] = nil
						end
					end
				end
				for eventname, callbacks in pairs(events) do
					if callbacks[self] then
						callbacks[self] = nil
						-- if lastunused and registry.OnUnused then
						--   registry.OnUnused(registry, target, eventname)
						-- end
					end
				end
			end
		end
	end

	return registry
end


-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.
