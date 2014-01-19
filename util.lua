local addonName, ns, _ = ...

-- GLOBALS: _G, DEFAULT_CHAT_FRAME, GameTooltip, CreateFrame
-- GLOBALS: table, string, math, strsplit, type, tonumber, pairs, assert, tostring, tostringall

-- settings -- TODO: put into ns. so modules can have settings, too
local globalDefaults = {
	scanGems = false,
	debugMode = false,
	textAboveIcon = false,
	growLeft = false,
	growUp = false,
	width = 0,
	iconSize = 30,
	iconPadding = 2,
	position = {},
}
local localDefaults = {}

local function UpdateDatabase()
	-- keep database up to date, i.e. remove artifacts + add new options
	if _G[addonName..'_GlobalDB'] == nil then
		_G[addonName..'_GlobalDB'] = globalDefaults
	else
		--[[for key,value in pairs(_G[addonName..'_GlobalDB']) do
			if globalDefaults[key] == nil then _G[addonName..'_GlobalDB'][key] = nil end
		end--]]
		for key, value in pairs(globalDefaults) do
			if _G[addonName..'_GlobalDB'][key] == nil then
				_G[addonName..'_GlobalDB'][key] = value
			end
		end
	end
	ns.sharedDB = _G[addonName..'_GlobalDB']

	--[[if charDB == nil then
		charDB = localDefaults
	else
		for key,value in pairs(charDB) do
			if localDefaults[key] == nil then charDB[key] = nil end
		end
		for key, value in pairs(localDefaults) do
			if charDB[key] == nil then
				charDB[key] = value
			end
		end
	end--]]
	-- ns.charDB = _G[addonName..'_LocalDB']
end

local function Initialize()
	UpdateDatabase()

	-- expose us to the world
	_G[addonName] = ns
end

local frame, eventHooks = CreateFrame('Frame', addonName..'EventHandler'), {}
local function eventHandler(frame, event, arg1, ...)
	if event == 'ADDON_LOADED' and arg1 == addonName then
		-- make sure we always init before any other module
		Initialize()

		if not eventHooks[event] or ns.Count(eventHooks[event]) < 1 then
			frame:UnregisterEvent(event)
		end
	end

	if eventHooks[event] then
		for id, listener in pairs(eventHooks[event]) do
			listener(frame, event, arg1, ...)
		end
	end
end
frame:SetScript("OnEvent", eventHandler)
frame:RegisterEvent("ADDON_LOADED")

function ns.RegisterEvent(event, callback, id, silentFail)
	assert(callback and event and id, string.format("Usage: RegisterEvent(event, callback, id[, silentFail])"))
	if not eventHooks[event] then
		eventHooks[event] = {}
		frame:RegisterEvent(event)
	end
	assert(silentFail or not eventHooks[event][id], string.format("Event %s already registered by id %s.", event, id))

	eventHooks[event][id] = callback
end
function ns.UnregisterEvent(event, id)
	if not eventHooks[event] or not eventHooks[event][id] then return end
	eventHooks[event][id] = nil
	if ns.Count(eventHooks[event]) < 1 then
		eventHooks[event] = nil
		frame:UnregisterEvent(event)
	end
end

-- ================================================
-- Little Helpers
-- ================================================
function ns.Print(text, ...)
	if ... and text:find('%%') then
		text = string.format(text, ...)
	elseif ... then
		text = string.join(', ', tostringall(text, ...))
	end
	DEFAULT_CHAT_FRAME:AddMessage('|cff22CCDD'..addonName..'|r '..text)
end

function ns.Debug(...)
  if ns.sharedDB.debugMode then
	ns.Print("! "..string.join(', ', tostringall(...)))
  end
end

function ns.ShowTooltip(self, anchor)
	if not self.tiptext and not self.link then return end
	if anchor and type(anchor) == 'table' then
		GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip:ClearLines()

	if self.link then
		GameTooltip:SetHyperlink(self.link)
	elseif type(self.tiptext) == "string" and self.tiptext ~= "" then
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	elseif type(self.tiptext) == "function" then
		self.tiptext(self, GameTooltip)
	end
	GameTooltip:Show()
end
function ns.HideTooltip() GameTooltip:Hide() end

-- counts table entries. for numerically indexed tables, use #table
function ns.Count(table)
	if not table then return 0 end
	local i = 0
	for _, _ in pairs(table) do
		i = i + 1
	end
	return i
end

function ns.Find(where, what)
	for k, v in pairs(where) do
		if v == what then
			return k
		end
	end
end
