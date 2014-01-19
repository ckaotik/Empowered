local addonName, ns, _ = ...

-- GLOBALS: _G, MidgetDB, LibStub, HIGHLIGHT_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, UIParent
-- GLOBALS: GetSpellInfo, UnitAura, UnitClass, GetSpecialization, IsPlayerSpell, CreateFrame, UnitSpellHaste, GetSpellBonusDamage, UnitAttackPower, UnitAttackSpeed, UnitGUID
-- GLOBALS: unpack, select, pairs, ipairs, type, wipe, tContains
local LibMasque = LibStub('Masque', true)
local Movable = LibStub('LibMovable-1.0')

local frame
local spells, handlers = nil, nil
local playerGUID, targetGUID = nil, nil
local spellsOrder = {}

local function GetClassModifier(spellID)
	local modifier
	local currentSpec = GetSpecialization()

	if not handlers then
		modifier = 1
	elseif type(handlers) == 'table' and handlers[currentSpec] then
		modifier = handlers[currentSpec](spellID)
	elseif type(handlers) == 'function' then
		modifier = handlers(spellID)
	end

	return modifier or 1
end

local function GetDamageModifier(spellID)
	local dmgModifier = 1
	-- handle generic aura modifiers
	for spellID, modifier in pairs(ns.modAuras) do
		local spellName = GetSpellInfo(spellID)
		local name, _, _, _, _, _, _, _, _, _, _, _, _, _, bonus, bonus2, bonus3 = UnitAura('player', spellName)
		if bonus then
			dmgModifier = dmgModifier * (1 + bonus/100)
		elseif type(modifier) == 'number' then
			dmgModifier = dmgModifier * modifier
		end
	end

	-- handle class/spec specific modifiers
	dmgModifier = dmgModifier * GetClassModifier(spellID)

	-- accomodate for haste (just basic, not checking for clipped ticks etc!)
	local haste = UnitSpellHaste('player')
	      haste = 1 + haste/100
	dmgModifier = dmgModifier * haste

	return dmgModifier
end

-- ========================================================
--  Track Spell Power
-- ========================================================
local state = {}
FOO = state
local function UpdateSpellButton(spellID, spellName)
	local button = frame[spellID]
	local spellName = spellName or GetSpellInfo(spellID)

	-- update text value
	local relative
	local appliedValue = state[spellID][targetGUID]
	if not appliedValue or appliedValue == 0 then
		relative = 0
	else
		relative = state[spellID].calculated / appliedValue
	end

	local color = HIGHLIGHT_FONT_COLOR_CODE
	if     relative > 0 and relative < 1 then   color = RED_FONT_COLOR_CODE
	elseif relative > 0 and relative > 1.1 then color = GREEN_FONT_COLOR_CODE
	end
	button.power:SetFormattedText('%s%d|r', color, relative*100)

	-- update button appearance
	local _, _, _, count, _, duration, expires = UnitDebuff('target', spellName, nil, 'PLAYER')
	if count and count > 1 then
		button.count:SetText(count)
	else
		button.count:SetText('')
	end

	if expires and duration then
		button.cooldown:SetCooldown(expires - duration, duration)
	end

	if (duration and duration == 0) or relative == 0 then
		button.power:SetText('')
		button.cooldown:SetCooldown(0, 1)
	end
end

local function UpdateCalculatedValues(self, event, unit)
	if unit and unit ~= 'player' then return end
	for _, spellID in ipairs(spellsOrder) do
		local value = spells[spellID][1](spellID)
		      value = value * GetDamageModifier(spellID)

		state[spellID].calculated = value

		UpdateSpellButton(spellID)
	end
end

local function UpdateAppliedValue(_, _, timestamp, event, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName)
	if sourceGUID ~= playerGUID or not tContains(spellsOrder, spellID) then return end
	if event == 'SPELL_AURA_REFRESH' or event == 'SPELL_AURA_APPLIED' or event == 'SPELL_AURA_APPLIED_DOSE' then
		-- apply calculated values to this target's dots
		state[spellID][destGUID] = state[spellID].calculated or state[spellID][destGUID] or 0
		UpdateSpellButton(spellID, spellName)
	elseif event == 'SPELL_AURA_REMOVED' then
		state[spellID][destGUID] = 0
		-- fade out button and reset stack count
		UpdateSpellButton(spellID, spellName)
	end
end

-- ========================================================
--  Initialization
-- ========================================================
local collectionTable = {}
-- check if any entry in <list | single value> fulfills (function) or equals (non-function) search
local function MatchesAny(collection, search)
	if not collection then
		return
	elseif type(collection) ~= 'table' then
		wipe(collectionTable)
		collectionTable[1] = collection
		collection = collectionTable
	end

	for key, value in pairs(collection) do
		if type(search) == 'function' then
			if search(value) then
				return key, value
			end
		else
			if value == search then
				return key, value
			end
		end
	end
end

local function UpdatePlayerSpells(self, event)
	if event and InCombatLockdown() then return end

	local numButtons = 0
	if not playerGUID then
		playerGUID = UnitGUID('player')
	end

	wipe(spellsOrder)
	for spellID, info in pairs(spells) do
		local button = frame[spellID]
		local currentSpec = GetSpecialization()
		local isSpecAppropriate = not info[2] or MatchesAny(info[2], currentSpec)
		if isSpecAppropriate and (IsPlayerSpell(spellID) or MatchesAny(info[3], IsPlayerSpell)) then
			table.insert(spellsOrder, spellID)
			if not state[spellID] then state[spellID] = {} end
			wipe(state[spellID])

			button:SetSize(ns.sharedDB.iconSize, ns.sharedDB.iconSize)
			button:Show()
			numButtons = numButtons + 1
		else
			-- LibMasque:Group(addonName, 'Spell Buttons'):RemoveButton(button, true)
			button:SetSize(0.0000001, 0.0000001)
			button:Hide()
		end
	end
	table.sort(spellsOrder)
	-- UpdateCalculatedValues()

	LibMasque:Group(addonName, 'Spell Buttons'):ReSkin()

	if numButtons == 0 then
		frame:SetSize(ns.sharedDB.iconSize, ns.sharedDB.iconSize)
	else
		frame:SetSize(numButtons*ns.sharedDB.iconSize + (numButtons-1)*ns.sharedDB.iconPadding, ns.sharedDB.iconSize)
	end
end

local function Initialize(self, event, addon)
	-- sets file local variables: frame, handlers, spells
	if addon ~= addonName then return end
	ns.UnregisterEvent('ADDON_LOADED', 'empowered')

	local _, playerClass = UnitClass('player')
	spells = ns.classSpells[playerClass]
	if not spells then return end

	handlers = ns.classModHandlers[playerClass]
	playerGUID = UnitGUID('player')

	frame = CreateFrame('Frame', addonName..'Tracker', UIParent)
	frame:SetPoint('CENTER')
	frame:SetSize(1, 1)

	Movable.RegisterMovable(addonName, frame, ns.sharedDB.position)

	local index, usedWidth, usedHeight = 1, 0, 0
	local size, padding, maxWidth = ns.sharedDB.iconSize, ns.sharedDB.iconPadding, ns.sharedDB.width
	local lastRowFirst = 1
	for spellID, info in pairs(spells) do
		local spellName, _, icon = GetSpellInfo(spellID)
		local button = CreateFrame('Button', '$parentButton'..index, frame, 'CompactAuraTemplate', spellID)
		      button:SetSize(size, size)
		      button:EnableMouse(false)
		      button:EnableMouseWheel(false)

		local power = button:CreateFontString(nil, 'OVERLAY', 'NumberFontNormalSmall')
		if ns.sharedDB.textAboveIcon then
			power:SetPoint('BOTTOM', '$parent', 'TOP', 0,  4)
		else
			power:SetPoint('TOP', '$parent', 'BOTTOM', 0, -4)
		end
		button.power = power
		button.icon:SetTexture(icon)

		if LibMasque then
			LibMasque:Group(addonName, 'Spell Buttons'):AddButton(button, {
				Icon     = button.icon,
				Cooldown = button.cooldown,
				Count    = button.count,
				Border   = button.overlay,
			})
		end

		if index == 1 then
			button:SetPoint('TOPLEFT')
			usedWidth = usedWidth + size
		else
			usedWidth = usedWidth + size + padding
			if maxWidth ~= 0 and usedWidth > maxWidth then
				usedWidth = 0
			end

			if usedWidth == 0 then
				-- this starts a new row
				if ns.sharedDB.growUp then
					button:SetPoint('BOTTOM', '$parentButton'..(lastRowFirst), 'TOP', 0, -padding)
				else
					button:SetPoint('TOP', '$parentButton'..(lastRowFirst), 'BOTTOM', 0,  padding)
				end
				lastRowFirst = index
			else
				if ns.sharedDB.growLeft then
					button:SetPoint('RIGHT', '$parentButton'..(index - 1), 'LEFT', -padding, 0)
				else
					button:SetPoint('LEFT', '$parentButton'..(index - 1), 'RIGHT',  padding, 0)
				end
			end
		end

		frame[spellID] = button
		index = index + 1
	end

	UpdatePlayerSpells()

	ns.RegisterEvent('UNIT_SPELL_HASTE',        UpdateCalculatedValues, 'dmg_haste')
	ns.RegisterEvent('PLAYER_DAMAGE_DONE_MODS', UpdateCalculatedValues, 'dmg_mods')
	ns.RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED', UpdateAppliedValue, 'dmg_cleu')
	ns.RegisterEvent('SPELLS_CHANGED', UpdatePlayerSpells, 'dot_visibility')

	ns.RegisterEvent('PLAYER_REGEN_ENABLED', function()
		-- remove any tracked GUIDs
		for _, spellID in ipairs(spellsOrder) do
			wipe(state[spellID])
		end
	end, 'dmg_purge')
	ns.RegisterEvent('PLAYER_TARGET_CHANGED', function()
		targetGUID = UnitGUID('target')
		for _, spellID in ipairs(spellsOrder) do
			UpdateSpellButton(spellID)
		end
	end, 'dmg_target')
end
ns.RegisterEvent('ADDON_LOADED', Initialize, 'empowered')
