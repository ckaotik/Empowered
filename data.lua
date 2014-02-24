local addonName, ns, _ = ...

ns.modAuras = {
	[ 57934] = 1.15, -- Tricks of the Trade + 15%
	[118977] = 1.60, -- Fearless + 60%
	[138002] = 1.40, -- Fluidity +40%
	[140741] = 2.00, -- Primal Nutriment +100% +10% per stack
	[144364] = 1.15, -- Power of the Titans

	[124974] = 1.12, -- Druid: Nature's Vigil
	[ 12042] = 1.20, -- Mage: Arcane Power
	[ 81661] = 1.25, -- Priest: Evangelism
}

-- ========================================================
--  Spells
-- ========================================================
ns.classSpells = {
	-- spellID = { GetBasePowerFunc, RequiredSpec:table/number, skillSpellID:table/number }
	DEATHKNIGHT = {
		[ 55095] = {function() return UnitAttackPower('player') end, nil, 59921}, -- Frost Fever
		[ 55078] = {function() return UnitAttackPower('player') end, nil, 59879}, -- Blood Plague
	},
	DRUID = {
		[  8921] = {function() return GetSpellBonusDamage(7) end, 1}, -- Moonfire
		[ 93402] = {function() return GetSpellBonusDamage(4) end, 1}, -- Sunfire
		[ 33745] = {function() return UnitAttackPower('player') end, 3}, --
		[ 77758] = {function() return UnitAttackPower('player') end, 3}, --
	},
	WARLOCK = {
		[   172] = {function() return GetSpellBonusDamage(6) end, nil}, -- Corruption
		[   980] = {function() return GetSpellBonusDamage(6) end, nil}, -- Agony
		[ 30108] = {function() return GetSpellBonusDamage(6) end, nil}, -- Unstable Affliction
		-- [ 47960] = {1, GetSpellBonusDamage, 6}, -- Shadowflame
		-- [108366] = {1, GetSpellBonusDamage, 6}, -- Soulleech
		-- [108416] = {1, GetSpellBonusDamage, 6}, -- Pact of Sacrifice
		-- [ 80240] = {1, GetSpellBonusDamage, 3}, -- Havoc
		-- [117896] = {1, GetSpellBonusDamage, 3}, -- Backdraft
		-- 6229, 145075, 146043, 145164
	},
	PRIEST = {
		[   589] = {function() return GetSpellBonusDamage(6) end, 3}, -- Shadow Word: Pain
		[ 34914] = {function() return GetSpellBonusDamage(6) end, 3}, -- Vampiric Touch
		[  2944] = {function() return GetSpellBonusDamage(6) end, 3}, -- Devouring Plague
	},
	MAGE = {
		[114923] = {function() return GetSpellBonusDamage(7) end, nil}, -- Nether Tempest
	},
}

--[[
GetSpellBonusHealing()
power, posBuff, negBuff = UnitAttackPower("player")

melee:
	min, max, minOH, maxOH, physPlus, physNeg, modifier = UnitDamage("player")
	19742.634765625, 30469.759765625, 9871.1748046875, 15234.736328125, 0, 0, 1.1000000238419
ranged:
	speed, min, max, physPlus, physNeg, modifier = UnitRangedDamage("player")
--]]

-- ========================================================
--  Track Class Spell Modifiers
-- ========================================================
ns.classModHandlers = {
	DEATHKNIGHT = {
		[2] = function(spellID) -- Frost
			if spellID == 55095 then
				local masteryPercent = GetMasteryEffect()
				return 1 + masteryPercent/100
			end
		end,
		[3] = function(spellID) -- Unholy
			if spellID == 55078 then
				local masteryPercent = GetMasteryEffect()
				return 1 + masteryPercent/100
			end
		end
	},
	DRUID = {
		[1] = function(spellID) -- Balance
			local multiplier = 1
			local spellSchool = spellID == 8921 and 7 or 4 -- arcane or nature

			local incarnation = GetSpellInfo(102560)
			if UnitBuff('player', incarnation) then
				-- balance incarnation provides +25% damage but only during eclipses
				multiplier = 1.25
			end

			-- using buff-provided bonus values should even handle dream of cenarius
			local celestialAlignment = GetSpellInfo(112071)
			local bonus = select(15, UnitBuff('player', celestialAlignment))
			if bonus then
				return multiplier * (1 + bonus/100)
			end

			local lunarEclipse = GetSpellInfo(48518)
			bonus = select(15, UnitBuff('player', lunarEclipse))
			if bonus then
				-- buffs arcane spells (spell school 7)
				return multiplier * ((spellSchool == 7) and (1 + bonus/100) or 1)
			end
			local solarEclipse = GetSpellInfo(48517)
			bonus = select(15, UnitBuff('player', solarEclipse))
			if bonus then
				-- buffs nature spells (spell school 4)
				return multiplier * ((spellSchool == 4) and (1 + bonus/100) or 1)
			end
			return 1
		end
	},
	PRIEST = {
		[3] = function(spellID) -- Shadow
			local modifier = 1

			local shadowform = GetSpellInfo(15473)
			if UnitBuff('player', shadowform) then
				modifier = modifier * 1.25
			end

			local twistOfFate = GetSpellInfo(123254)
			if UnitBuff('player', twistOfFate) then
				modifier = modifier * 1.15
			end

			local powerInfusion = GetSpellInfo(10060)
			if UnitBuff('player', powerInfusion) then
				modifier = modifier * 1.05
			end

			local masteryPercent = GetMasteryEffect()
			modifier = modifier * (1 + masteryPercent/100)

			if spellID == 2944 then
				-- Devouring Plague, TODO: this will be incorrect
				modifier = modifier * UnitPower("player", SPELL_POWER_SHADOW_ORBS)
			end

			return modifier
		end
	},
}
