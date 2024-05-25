local L = AceLibrary("AceLocale-2.2"):new("MiniHealer")

-- English localization
L:RegisterTranslations("enUS", function()

	BINDING_HEADER_MINIHEALER = 'minihealer'
	BINDING_NAME_MINIHEALER_HEAL = 'Heal'

	MH_NO_TARGET = "no target"

	return {
		-- SPELLS --
		['Flash Heal'] = true,
		['Flash of Light'] = true,

		--sayc
		['usage:'] = true,
		['disable moving the healing bar'] = true,
		['enable moving the healing bar'] = true,
		['enable or disable debug output'] = true,

		["Healthbar position locked"] = true,
		["Healthbar position unlocked"] = true,
		['debug output enabled'] = true,
		['debug output disabled'] = true,
		["unknown command"] = true,

		["loaded"] = true,
		['no unit selected for health info?'] = true,

		["********** Self Preservation **********"] = true,
		["********** Raid Target Priority **********"] = true,
		['implement me!'] = true,

		--assert
		['dependency not found'] = true,
		['healspell for class '] = true,
		[' not found'] = true,

		--ExplainFalseUnitCondition
		['does not exist'] = true,
		["is not a friend"] = true,
		["is an enemy"] = true,
		["can be attacked by player"] = true,
		["is not connected"] = true,
		["is dead or ghost"] = true,
		["is not visible to client"] = true,
		['is blacklisted'] = true,
		['not missing enough health'] = true,

		--errmsg
		['LOS'] = true, --SPELL_FAILED_LINE_OF_SIGHT
		['OOR'] = true, --SPELL_FAILED_OUT_OF_RANGE
		
		['blacklisted'] = true, --displayerr
		["no target"] = true, --SetText

		--display
		['already casting'] = true,
		['nothing to heal'] = true,
		['healing:'] = true,
	}
end)
