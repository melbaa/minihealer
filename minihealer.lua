
minihealer = AceLibrary("AceAddon-2.0"):new("AceHook-2.1", "AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0")
minihealer:RegisterDB("minihealer_variables", "minihealer_variables_pc")
minihealer:RegisterDefaults("char", {
    ["RatioForSelf"] = 0.9, --less than this activates self preservation
    ["RatioFull"] = 0.9, -- don't heal with too little missing
    ["FlatForSelf"] = 500,
    ["FlatFromFull"] = 500,
    -- ["FlatFromFull"] = -1,
    ["TargetPriority"] = false, -- prioritize focused target?
    ["HealthbarLocked"] = false, -- can we move the healthbar?
})

local libHealComm = AceLibrary("HealComm-1.0")


local blacklist = {}
local lastBlacklistTime = 0;
local blacklistDuration = 5

local healingTarget = nil
local healingTargetMissing = 0
local DEBUG_ENABLED = true
local me = UnitName('player')
local myclass = string.lower(UnitClass('player'))

local spell_per_class = {
    priest='Flash Heal',
    paladin='Flash of Light',
}



local healspell = spell_per_class[myclass]

BINDING_HEADER_MINIHEALER = 'minihealer'
BINDING_NAME_MINIHEALER_HEAL = 'Heal'











local function strToArray(s)
    s = string.lower(s.." ")
    result = {};
    for match in string.gfind(s, '([^ ]+)') do
         table.insert(result, match)
    end
    return result
end


local function joinstr(...)
    local txt = ''
    for k, v in ipairs(arg) do
        txt = txt .. ' '
    end
    return txt
end

local function colorize(txt, prependAppName)
    if prependAppName == true then
        source = 'minihealer: ' .. txt
    end

    txt = string.gsub(txt, "@B", "|cFF008fec")
    txt = string.gsub(txt, "@W", "|cFFFFFFFF")
    txt = string.gsub(txt, "@Y", "|cFFFFFF00")
    txt = string.gsub(txt, "@R", "|cFFFF5179")
    txt = string.gsub(txt, "@G", "|cFF00FF7F")

    return txt
end


local function sayd(msg)
    if not DEBUG_ENABLED then
        return
    end
    minihealer:Print(colorize("@Y" .. msg))
end


local function GetIncomingHeals(healingTarget)


    local name = UnitName(healingTarget)
    local healcommincoming = libHealComm:getHeal(name)
    if healcommincoming then
        sayd('healcommincoming ' .. healcommincoming)
        return healcommincoming
    end

    local pfincoming = pfUI.api.libpredict:UnitGetIncomingHeals(healingTarget)
    if pfincoming then
        sayd('pfincoming ' .. pfincoming)
        return pfincoming
    end
    return 0
end


local function display(msg)
    if MikSBT.DisplayMessage then
        MikSBT.DisplayMessage(msg, nil, false, .2, .7, .9)
    end
    sayd(msg)
end

local function displayerr(msg)
     if MikSBT.DisplayMessage then
        MikSBT.DisplayMessage(msg, nil, false, 1, 0, 0)
    end
    sayd(msg)
end

local function sayc(msg)
    minihealer:Print(colorize("@B" .. msg))
end


local function print_usage()
    sayc('usage: ')
    sayc('minihealer lock - disable moving the healing bar')
    sayc('minihealer unlock - enable moving the healing bar')
end


function minihealer:cmd(arg)

    local commandlist = { }
    local command

    for command in string.gfind(arg, "[^ ]+") do
        table.insert(commandlist, command)
    end

    if commandlist[1] == nil then
        print_usage()
        return
    end

    commandlist[1] = string.lower(commandlist[1])


    if commandlist[1] == 'lock' then
        self.db.char.HealthbarLocked = true
        sayc("Healthbar position locked")
    elseif commandlist[1] == 'unlock' then
        self.db.char.HealthbarLocked = false
        sayc("Healthbar position unlocked")
    else
        sayc("unknown command")
    end
end


function minihealer:OnEnable()

    assert(SmartHealer, 'dependency not found')
    assert(pfUI.api.libpredict.UnitGetIncomingHeals, 'dependency not found')
    assert(healspell, 'healspell for class' .. myclass .. ' not found')

    self:RegisterEvent("UI_ERROR_MESSAGE")

    self:RegisterChatCommand(
        { "/minihealer" },
        function(arg) minihealer:cmd(arg) end,
        "MINIHEALER"
    )
    MINIHEALER_LOADED = true
    sayc("loaded")
end

local function IsBlacklisted(unitname)
    -- Returns true if the unit is blacklisted (because it could not be healed)
    -- Note that the parameter is the name of the unit, not 'party1', 'raid1' etc.

    local CurrentTime = GetTime()
    if CurrentTime < lastBlacklistTime then
        -- Game time info has overrun, clearing blacklist to prevent permanent bans
        blacklist = {};
        lastBlacklistTime = 0;
    end
    if (blacklist[unitname] == nil) or blacklist[unitname] < CurrentTime then
        return false
    else
        return true
    end
end



-- Returns true if the player is in a raid group
local function InRaid()
    return (GetNumRaidMembers() > 0);
end

-- Returns true if the player is in a party or a raid
local function InParty()
    return (GetNumPartyMembers() > 0);
end

-- Returns true if health information is available for the unit
--[[ TODO: Rewrite to use:
Unit Functions 
* New UnitPlayerOrPetInParty("unit") - Returns 1 if the specified unit is a member of the player's party, or is the pet of a member of the player's party, nil otherwise (Returns 1 for "player" and "pet") 
* New UnitPlayerOrPetInRaid("unit") - Returns 1 if the specified unit is a member of the player's raid, or is the pet of a member of the player's raid, nil otherwise (Returns 1 for "player" and "pet") 
]]
local function UnitHasHealthInfo(unit)
    local i;

    if not unit then
        sayd('no unit selected for health info?')
        return false
    end

    if UnitIsUnit('player', unit) then
        return true
    end

    if InRaid() then
        -- In raid
        for i = 1, 40 do
            if UnitIsUnit("raidpet" .. i, unit) or UnitIsUnit("raid" .. i, unit) then
                return true
            end
        end
    else
        -- Not in raid
        if UnitInParty(unit) or UnitIsUnit("pet", unit) then
            return true
        end ;
        for i = 1, 4 do
            if (UnitIsUnit("partypet" .. i, unit)) then
                return true
            end
        end
    end
    return false;
end



local function PredictedHealthPercentage(healingTarget)
    -- deprecated
    return (UnitHealth(healingTarget) + libHealComm:getHeal(healingTarget)) / UnitHealthMax(healingTarget);
end


local function PredictedHealthMissing(healingTarget)
    return UnitHealthMax(healingTarget) - (UnitHealth(healingTarget) + GetIncomingHeals(healingTarget))
end



local function UnitFullName(unit)
    local name, server = UnitName(unit);
    if server and type(server) == "string" and type(name) == "string" then
        return name .. " of " .. server;
    else
        return name;
    end
end



local function ExplainFalseUnitCondition(unit, condition, debugText, explain)
    if condition then
        -- nothing to explain, condition is true
        return false
    end

    if explain then
        sayd(unit .. ' ' .. debugText)
    end

    -- we had to explain
    return true
end

-- Return true if the unit is healable by player
function minihealer:UnitIsHealable(unit, explain)
    if ExplainFalseUnitCondition(unit, UnitExists(unit), 'does not exist') then
        return false
    end
    if ExplainFalseUnitCondition(unit, UnitIsFriend('player', unit), "is not a friend", explain) then
        return false
    end
    if ExplainFalseUnitCondition(unit, not UnitIsEnemy(unit, 'player'), "is an enemy", explain) then
        return false
    end
    if ExplainFalseUnitCondition(unit, not UnitCanAttack('player', unit), "can be attacked by player", explain) then
        return false
    end
    if ExplainFalseUnitCondition(unit, UnitIsConnected(unit), "is not connected", explain) then
        return false
    end
    if ExplainFalseUnitCondition(unit, not UnitIsDeadOrGhost(unit), "is dead or ghost", explain) then
        return false
    end
    if ExplainFalseUnitCondition(unit, UnitIsVisible(unit), "is not visible to client", explain) then
        return false
    end
    if ExplainFalseUnitCondition(unit, not IsBlacklisted(UnitFullName(unit)), 'is blacklisted', explain) then
        return false
    end

    local missing = PredictedHealthMissing(unit)
    if ExplainFalseUnitCondition(unit, (missing >= self.db.char.FlatFromFull), UnitFullName(unit) .. ' not missing enough health ' .. missing, explain) then
        return false
    end

    sayd(string.format("%s (%s) : %d/%d", UnitFullName(unit), unit, UnitHealth(unit), UnitHealthMax(unit)));

    return true
end

local function SelfPreservation()
    -- if we aren't alive, we can't heal others
    local db = minihealer.db.char
    local healingTargetCandidate = 'player'
    -- local percentage = PredictedHealthPercentage(healingTargetCandidate)
    -- if (percentage < db.RatioForSelf) and (percentage < db.RatioFull) then
    local missing = PredictedHealthMissing(healingTargetCandidate)
    if missing >= db.FlatForSelf or missing >= db.FlatFromFull
    then
        sayd("********** Self Preservation **********");
        return healingTargetCandidate
    end
end

local function RaidTargetPreservation()
    -- our targeted unit is assumed to be important when it's part of the raid
    local db = minihealer.db.char
    local healingTargetCandidate = 'target'
    if -- db.TargetPriority
        UnitHasHealthInfo(healingTargetCandidate) and
        minihealer:UnitIsHealable(healingTargetCandidate, true)
    then
        sayd("********** Raid Target Priority **********");
        return healingTargetCandidate;
    end
end

local function ExternalTargetPreservation()
    local db = minihealer.db.char
    local healingTargetCandidate = 'target'
    if minihealer:UnitIsHealable('target', true)
    then

        return healingTargetCandidate;
    end
end

local function GatherHealableRaidMembers()

    local playerIds = {}
    local petIds = {}
    -- Fill playerIds and petIds with healable targets
    if InRaid() then
        for i = 1, GetNumRaidMembers() do
            local unit = 'raid' .. i
            if minihealer:UnitIsHealable(unit, true)  then
                playerIds[unit] = i;
            end

            local unitpet = 'raidpet' .. i
            if minihealer:UnitIsHealable(unitpet, true) then
                petIds[unitpet] = i;
            end
        end
    else
        if minihealer:UnitIsHealable('player', true) then
            playerIds["player"] = 0
        end
        if minihealer:UnitIsHealable('pet', true) then
            petIds["pet"] = 0
        end
        for i = 1, GetNumPartyMembers() do
            if minihealer:UnitIsHealable("party" .. i, true) then
                playerIds["party" .. i] = i;
            end
            if minihealer:UnitIsHealable("partypet" .. i, true) then
                petIds["partypet" .. i] = i;
            end
        end
    end

    return playerIds, petIds
end


local function RandomRaidTargetPreservation()
    local db = minihealer.db.char
    sayd('implement me!')
end


local function FindWhoToHeal()
    local playerIds = {};
    local petIds = {};
    local i;
    local AllPlayersAreFull = true;
    local AllPetsAreFull = true;
    local db = minihealer.db.char

    healingTarget = nil
    --healingTarget = SelfPreservation()
    --if healingTarget then return healingTarget end

    healingTarget = RaidTargetPreservation()
    if healingTarget then return healingTarget end

    local playerIds, petIds = GatherHealableRaidMembers()
    for unit, i in playerIds do
        healingTarget = unit
        return healingTarget
    end

    healingTarget = ExternalTargetPreservation()
    if healingTarget then return healingTarget end

    for unit, i in petIds do
        healingTarget = unit
        return healingTarget
    end



    --[[

    -- Clear any healable target
    local OldPlaySound = PlaySound;
    PlaySound = function()
    end
    local TargetWasCleared = false;
    if UnitIsHealable('target') then
        TargetWasCleared = true;
        ClearTarget();
    end

    -- Cast the checkspell
    CastCheckSpell();
    if not SpellIsTargeting() then
        -- Reacquire target if it was cleared
        if TargetWasCleared then
            TargetLastTarget();
        end
        -- Reinsert the PlaySound
        PlaySound = OldPlaySound;
        return false;
    end
    --]]


    --[[
    -- Reacquire target if it was cleared earlier, and stop CheckSpell
    SpellStopTargeting();
    if TargetWasCleared then
        TargetLastTarget();
    end
    PlaySound = OldPlaySound;
    --]]
    return healingTarget;
end




function minihealer:UI_ERROR_MESSAGE(arg1)
    -- looking for a reason to blacklist
    if not healingTarget or UnitIsUnit(healingTarget, "player") then
        return
    end

    local errmsg = nil
	if arg1 == SPELL_FAILED_LINE_OF_SIGHT then
        errmsg = 'LOS '
    elseif arg1 == ERR_SPELL_OUT_OF_RANGE
    or arg1 == SPELL_FAILED_OUT_OF_RANGE
    then
        errmsg = 'OOR '
    end

    if errmsg then
        lastBlacklistTime = GetTime();
        blacklist[UnitFullName(healingTarget)] = lastBlacklistTime + blacklistDuration
        displayerr('blacklisted ' .. UnitFullName(healingTarget))
	end
end



local function UpdateHealbar(healingTarget)
    local hp = UnitHealth(healingTarget)
    local hpmax = UnitHealthMax(healingTarget)
    local hpincoming = GetIncomingHeals(healingTarget)

    minihealerHealbarStatusbar:SetValue(hp/hpmax)
    minihealerHealbarStatusbarPost:SetValue((hp+hpincoming)/hpmax)

    local missing = hpmax - (hp + hpincoming)
    local realmissing = hpmax - hp
    minihealerHealbarText:SetText(''
    .. realmissing .. ' | '
    .. missing .. ' | '
    .. UnitFullName(healingTarget))

    -- TODO update colors and spark
end


local function StartMonitor(healingTarget)
    minihealer:RegisterEvent("CHAT_MSG_ADDON") -- for detecting overheal
    minihealer:RegisterEvent("UNIT_HEALTH"); -- For detecting overheal situations
    minihealer:RegisterEvent("SPELLCAST_STOP"); -- For detecting spellcast stop
    minihealer:RegisterEvent("SPELLCAST_FAILED"); -- For detecting spellcast stop
    minihealer:RegisterEvent("SPELLCAST_INTERRUPTED"); -- For detecting spellcast stop

    UpdateHealbar(healingTarget)
end


local function ResetHealbar()
    minihealerHealbarText:SetText("no target")
    minihealerHealbarStatusbar:SetValue(0)
    minihealerHealbarStatusbarPost:SetValue(0)
end

local function StopMonitor()
    ResetHealbar()

    healingTarget = nil

    -- TODO maybe unregister events? does the performance matter?
end

function minihealer:CHAT_MSG_ADDON()
    if not healingTarget then return end
    if arg1 ~= 'HealComm' then return end

    sayd('1: ' .. arg1 .. ' 2: ' .. arg2 .. ' 3: ' .. arg3 .. ' 4: ' .. arg4)
    UpdateHealbar(healingTarget)
end


function minihealer:UNIT_HEALTH(arg1)
    if not healingTarget then return end
    if not arg1 then return end
    if not UnitIsUnit(healingTarget, arg1) then return end

    UpdateHealbar(healingTarget)
end

function minihealer:SPELLCAST_STOP()
    StopMonitor()
end

function minihealer:SPELLCAST_FAILED()
    StopMonitor()
end

function minihealer:SPELLCAST_INTERRUPTED()
    StopMonitor()
end




function miniheal(healingTarget)
    if healingTarget then
        healingTarget = string.lower(healingTarget)
    else
        healingTarget = FindWhoToHeal()
    end
    if not healingTarget then
        display('nothing to heal')
        return
    else
        display('healing: ' .. UnitFullName(healingTarget))
    end

    -- set healing target
    local oldt = true
    if UnitIsUnit("target", healingTarget) then oldt = nil end
    TargetUnit(healingTarget)

    StartMonitor(healingTarget)
    -- CastSpellByName(msg)
    SmartHealer:CastHeal(healspell)

    -- reset healing target
    if oldt then
      TargetLastTarget()
    end

end


