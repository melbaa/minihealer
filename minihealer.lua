
minihealer = AceLibrary("AceAddon-2.0"):new("AceHook-2.1", "AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0")
minihealer:RegisterDB("minihealer_variables", "minihealer_variables_pc")
minihealer:RegisterDefaults("char", {
    ["RatioForSelf"] = 0.9, --less than this activates self preservation
    ["RatioFull"] = 0.9, -- don't heal with too little missing
    ["FlatForSelf"] = 500,
    -- ["FlatFromFull"] = 500,
    ["FlatFromFull"] = -1,
    ["TargetPriority"] = false, -- prioritize focused target?
})

local libHealComm = AceLibrary("HealComm-1.0")


local blacklist = {}
local lastBlacklistTime = 0;
local blacklistDuration = 5

local healingTarget = nil
local DEBUG_ENABLED = true
local me = UnitName('player')


BINDING_HEADER_MINIHEALER = 'minihealer'
BINDING_NAME_MINIHEALER_HEAL = 'Heal'



function miniheal_cmd(args)

end






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


local function GetIncomingHeals(unit)
   return pfUI.api.libpredict:UnitGetIncomingHeals(unit) or libHealComm:getHeal(unit)
end

local function sayd(msg)
    if not DEBUG_ENABLED then
        return
    end
    minihealer:Print(colorize("@Y" .. msg))
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


function minihealer:OnEnable()

    SlashCmdList["MINIHEALER"] = miniheal_cmd
    SLASH_MINIHEALER1 = "/mh";
    SLASH_MINIHEALER2 = "/miniheal";

    --Register for Addon message event
    -- minihealer:RegisterEvent("CHAT_MSG_ADDON")


    assert(SmartHealer, 'dependency not found')
    assert(pfUI.api.libpredict.UnitGetIncomingHeals, 'dependency not found')

    self:RegisterEvent("UI_ERROR_MESSAGE")

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
    return UnitHealthMax(healingTarget) - UnitHealth(healingTarget) + GetIncomingHeals(healingTarget)
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




local function StartMonitor(healingTarget)
    minihealer:RegisterEvent("UNIT_HEALTH"); -- For detecting overheal situations
    minihealer:RegisterEvent("SPELLCAST_STOP"); -- For detecting spellcast stop
    minihealer:RegisterEvent("SPELLCAST_FAILED"); -- For detecting spellcast stop
    minihealer:RegisterEvent("SPELLCAST_INTERRUPTED"); -- For detecting spellcast stop

    minihealerHealbarText:SetText("healing " .. UnitFullName(healingTarget))
end


local function StopMonitor()
    healingTarget = nil
    minihealerHealbarText:SetText("no target")
end

function minihealer:UNIT_HEALTH(arg1)
    if not UnitIsUnit(healingTarget, arg1) then
        return
    end

    -- TODO update status bar
end

function minihealer:SPELLCAST_STOP(arg1)
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
    SmartHealer:CastHeal('Flash Heal')

    -- reset healing target
    if oldt then
      TargetLastTarget()
    end

end


