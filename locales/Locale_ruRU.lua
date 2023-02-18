local L = AceLibrary("AceLocale-2.2"):new("MiniHealer")

-- Russian localization
L:RegisterTranslations("ruRU", function()

	BINDING_HEADER_MINIHEALER = 'МиниЛекарь'
	BINDING_NAME_MINIHEALER_HEAL = 'Лечение'

	MH_NO_TARGET = "нет цели"

	return {
		-- SPELLS --
		['Flash Heal'] = "Быстрое исцеление",
		['Flash of Light'] = "Вспышка Света",
		
		--sayc
		['usage: '] = "Применение: ",
		['minihealer lock - disable moving the healing bar'] = "minihealer lock - отключить перемещение полосы исцеления",
		['minihealer unlock - enable moving the healing bar'] = "minihealer unlock - включить перемещение полосы исцеления",

		["Healthbar position locked"] = "Положение полосы здоровья заблокировано",
		["Healthbar position unlocked"] = "Положение полосы здоровья разблокировано",
		["unknown command"] = "неизвестная команда",

		["loaded"] = "загружен",
		['no unit selected for health info?'] = "для информации о здоровье не выбрана цель?",

		["********** Self Preservation **********"] = "********** Самосохранение **********",
		["********** Raid Target Priority **********"] = "********** Приоритет цели рейда **********",
		['implement me!'] = "реализуй меня!",

		--assert
		['dependency not found'] = "зависимость не найдена",
		['healspell for class '] = "заклинание исцеления для класса - ",
		[' not found'] = " не найдено",

		--ExplainFalseUnitCondition
		['does not exist'] = "не существует",
		["is not a friend"] = "это не союзник",
		["is an enemy"] = "это враг",
		["can be attacked by player"] = "может быть атакован игроком",
		["is not connected"] = "не подключен",
		["is dead or ghost"] = "мертв или призрак",
		["is not visible to client"] = "не виден клиенту",
		['is blacklisted'] = "занесен в черный список",
		[' not missing enough health '] = " не хватает здоровья ",

		--errmsg
		['LOS '] = "Вне поля зрения", --SPELL_FAILED_LINE_OF_SIGHT
		['OOR '] = "Вне зоны диапазона", --SPELL_FAILED_OUT_OF_RANGE
		
		['blacklisted '] = "занесен в черный список ", --displayerr
		["no target"] = "нет цели", --SetText

		--display
		['nothing to heal'] = "нечего лечить",
		['healing: '] = "исцеление: ",
	}
end)
