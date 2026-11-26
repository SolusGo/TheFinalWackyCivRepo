-- Run with the game's Lua 5.1 DLL via TestLua.ps1. Fixtures model native callback
-- order and keep a saved-value table while rebuilding the Lua context on load.
local source = "Civilizations/ScorpionDominion/Lua/SDOM_"
local id, saved = {}, {}
GameInfoTypes, GameInfo = id, {Units={}, GameSpeeds={}}
local function add(name)
    local number = #id + 1
    id[number], id[name] = name, number
    return number
end
local civ = add("CIVILIZATION_SCORPION_DOMINION")
local chamber = add("BUILDING_SDOM_MOLTING_CHAMBER")
for slot = 1, 6 do add("BUILDING_SDOM_APEX_" .. slot) end
local ascendant = add("PROMOTION_SDOM_ASCENDANT")
local pincers = add("PROMOTION_SDOM_PINCERS")
local carapace = add("PROMOTION_SDOM_CARAPACE")
local apex = add("PROMOTION_SDOM_APEX")
local imperial = add("PROMOTION_SDOM_EXOSKELETON")
local warrior, swordsman, longsword, archer
for _, kind in ipairs({"WARRIOR", "SWORDSMAN", "LONGSWORDSMAN", "ARCHER"}) do
    local name = "UNIT_" .. kind
    local number = add(name)
    GameInfo.Units[name] = {ID=number, Class="UNITCLASS_" .. kind,
        Domain="DOMAIN_LAND", Combat=10, RangedCombat=kind == "ARCHER" and 10 or 0}
end
warrior, longsword, archer = id.UNIT_WARRIOR, id.UNIT_LONGSWORDSMAN, id.UNIT_ARCHER
swordsman = add("UNIT_SDOM_EMPEROR_SCORPION")
for i, name in ipairs({"ANCIENT","CLASSICAL","MEDIEVAL","RENAISSANCE","INDUSTRIAL","MODERN","ATOMIC","INFORMATION"}) do
    id["ERA_" .. name] = i - 1
end
local marathon, standard = add("GAMESPEED_MARATHON"), add("GAMESPEED_STANDARD")
GameInfo.GameSpeeds[marathon] = {TrainPercent=300}
GameInfo.GameSpeeds[standard] = {TrainPercent=100}
local turn, active, speed = 35, 0, marathon

Game = {GetGameTurn=function() return turn end, GetActivePlayer=function() return active end,
    GetGameSpeedType=function() return speed end}
NotificationTypes = {NOTIFICATION_GENERIC=0}
Locale = {ConvertTextKey=function(key) return key end}
Modding = {OpenSaveData=function()
    return {GetValue=function(key) return saved[key] end, SetValue=function(key, value) saved[key]=value end}
end}

local function eventTable()
    return setmetatable({}, {__index=function(list, name)
        local handlers = {}
        local event = {Add=function(handler) handlers[#handlers + 1] = handler end}
        setmetatable(event, {__call=function(_, ...)
            for _, handler in ipairs(handlers) do handler(...) end
        end})
        list[name] = event
        return event
    end})
end

local function unit(owner, index, kind, xp)
    local u = {index=index, owner=owner, kind=kind, xp=xp, born=turn, promotions={},
        name="Pincers | Veteran 100%\nSecond line", hp=75, moves=1}
    function u:GetUnitType() return self.kind end
    function u:GetID() return self.index end
    function u:GetOwner() return self.owner end
    function u:GetGameTurnCreated() return self.born end
    function u:GetName() return self.name end
    function u:GetExperience() return self.xp end
    function u:IsDead() return self.dead end
    function u:IsDelayedDeath() return self.delayed end
    function u:IsCombatUnit() return true end
    function u:IsHasPromotion(p) return self.promotions[p] == true end
    function u:SetHasPromotion(p, value) self.promotions[p]=value end
    function u:GetX() return 10 end
    function u:GetY() return 10 end
    if kind == swordsman then u:SetHasPromotion(imperial, true) end
    Players[owner].units[index] = u
    GameEvents.UnitCreated(owner, index, kind, 10, 10)
    return u
end

local function player(owner, kind)
    local p = {gold=0, era=0, units={}, cities={}, notices={}, human=true, canAct=true, unitScans=0}
    function p:GetID() return owner end
    function p:GetCivilizationType() return kind end
    function p:IsAlive() return true end
    function p:IsHuman() return self.human end
    function p:IsTurnActive() return self.canAct end
    function p:GetTeam() return owner end
    function p:GetCurrentEra() return self.era end
    function p:GetGold() return self.gold end
    function p:ChangeGold(amount) self.gold = self.gold + amount end
    function p:GetUnitByID(index) return self.units[index] end
    function p:GetCapitalCity() return self.capital end
    function p:AddNotification(_, _, title) self.notices[#self.notices+1] = title end
    function p:Units()
        self.unitScans = self.unitScans + 1
        local index
        return function() local value; index, value = next(self.units, index); return value end
    end
    function p:Cities()
        local i = 0
        return function() i = i + 1; return self.cities[i] end
    end
    return p
end

local function city(id)
    local c = {buildings={}}
    function c:GetID() return id end
    function c:GetNumBuilding(kind) return self.buildings[kind] or 0 end
    c.GetNumRealBuilding = c.GetNumBuilding
    function c:SetNumRealBuilding(kind, value) self.buildings[kind] = value end
    return c
end

local function loadContext()
    GameEvents, Events = eventTable(), eventTable()
    dofile(source .. "State.lua")
    dofile(source .. "Rules.lua")
    SCORPION_DOMINION.dirty = function() end
    dofile(source .. "Events.lua")
    Events.SequenceGameInitComplete()
    Events.LoadScreenClose()
    return SCORPION_DOMINION
end

local function kill(u, hostile)
    if hostile then u.dead = true end
    local killer = hostile and 1 or -1
    GameEvents.UnitPrekill(u.owner, u.index, u.kind, 10, 10, true, killer)
    if hostile then GameEvents.UnitKilledInCombat(killer, u.owner, u.kind, -1) end
    u.delayed = true
    GameEvents.GameCoreUpdateEnd()
    GameEvents.UnitPrekill(u.owner, u.index, u.kind, 10, 10, false, killer)
    Players[u.owner].units[u.index] = nil
end

local function eq(actual, expected)
    assert(actual == expected, ("expected %s, got %s"):format(tostring(expected), tostring(actual)))
end

Players = {[0]=player(0, civ)}
for i = 1, 33 do Players[i] = player(i, 99) end
local p = Players[0]
local old, new = city(0), city(1)
p.cities, p.capital = {old, new}, old
Map = {GetPlot=function() return {GetPlotCity=function() return old end} end}
local council = loadContext()
local first = unit(0, 2, warrior, 30)
local second = unit(0, 3, swordsman, 100)
local ranged = unit(0, 4, archer, 100)
local other = unit(0, 5, warrior, 0)
local function token(u) return council.token(u) end

eq(council.capacity(p), 2)
eq(council.cost(p), 120)
eq(council.designate(token(first), 120), "ERR_GOLD")
p.gold = 999
eq(council.designate(token(ranged), 120), "ERR_UNIT")
p.canAct = false
eq(council.designate(token(first), 120), "ERR_TURN")
p.canAct = true
local oldToken = token(first)
eq(council.designate(oldToken, 120), nil)
eq(p.gold, 879)
eq(council.remaining(p), 6)
eq(first.hp, 75)
eq(first.moves, 1)
eq(first.xp, 30)
eq(council.designate(oldToken, 120), "ERR_UNIT")
eq(p.gold, 879)
eq(council.designate(token(second), 120), "ERR_COOLDOWN")
eq(council.specialise(token(first), 1), "ERR_CLASSICAL")
p.era = id.ERA_CLASSICAL
eq(council.specialise(token(first), 1), nil)
eq(council.specialise(token(first), 2), "ERR_BRANCH")
eq(first:IsHasPromotion(pincers), true)
first.xp = 100
GameEvents.GameCoreUpdateEnd()
eq(first:IsHasPromotion(apex), false)
turn = turn + 6
eq(council.designate(token(second), 120), "ERR_PRICE_CHANGED")
eq(council.designate(token(second), 180), nil)
eq(council.specialise(token(second), 2), nil)
eq(council.specialise(token(second), 1), "ERR_BRANCH")
eq(council.designate(token(other), 180), "ERR_CAPACITY")
p.era = id.ERA_INDUSTRIAL
GameEvents.TeamSetEra(0, p.era, true)
GameEvents.GameCoreUpdateEnd()
eq(council.activeScience(p), 4)
eq(first:IsHasPromotion(apex), true)
eq(second:IsHasPromotion(apex), true)

local serial = token(second).serial
local upgraded = unit(0, 6, longsword, second.xp)
GameEvents.UnitConverted(0, 0, 3, 6, true)
kill(second)
eq(council.state(0).lifetime, 0)
eq(token(upgraded).serial, serial)
eq(upgraded:IsHasPromotion(imperial), true)
eq(upgraded:IsHasPromotion(carapace), true)
eq(upgraded:IsHasPromotion(apex), true)
eq(council.activeScience(p), 4)
eq(council.state(0).roster[6].designated, turn)

-- Capturing the old capital must remove its research and reconcile the new one.
p.capital, p.cities, Players[1].cities = new, {new}, {old}
GameEvents.CapitalChanged(0, 1, 0)
GameEvents.CityCaptureComplete(0, true, 10, 10, 1)
GameEvents.GameCoreUpdateEnd()
eq(old:GetNumBuilding(id.BUILDING_SDOM_APEX_1), 0)
eq(council.activeScience(p), 4)
local notices = #p.notices
council = loadContext()
eq(#p.notices, notices)
eq(council.activeScience(p), 4)
eq(council.remaining(p), 6)
eq(token(upgraded).serial, serial)

local gift = unit(1, 6, longsword, 100)
gift:SetHasPromotion(ascendant, true)
gift:SetHasPromotion(apex, true)
GameEvents.UnitConverted(0, 1, 6, 6, false)
kill(upgraded)
eq(gift:IsHasPromotion(apex), false)
eq(council.activeScience(p), 2)
eq(council.state(0).hall[1].reason, "REASON_TRANSFER")
kill(first, true)
GameEvents.GameCoreUpdateEnd()
eq(council.activeScience(p), 0)
eq(council.state(0).lifetime, 2)
eq(council.state(0).hall[1].reason, "REASON_COMBAT")
eq(council.state(0).hall[1].name, first.name)
council = loadContext()
eq(council.state(0).hall[1].name, first.name)
eq(council.state(0).lifetime, 2)
eq(#council.roster(p), 0)

-- Returning a delayed gift or reusing the same ID in the same turn cannot
-- recover another unit's identity. Foreign rosters are skipped after load.
local reused = unit(0, 5, warrior, 100)
local stale = token(reused)
Players[0].units[5] = nil
reused = unit(0, 5, warrior, 100)
eq(council.resolve(p, stale), nil)
reused:SetHasPromotion(ascendant, true)
local foreignScans = Players[1].unitScans
GameEvents.GameCoreUpdateEnd()
eq(reused:IsHasPromotion(ascendant), false)
eq(Players[1].unitScans, foreignScans)

p.era = id.ERA_ATOMIC
new.buildings[chamber] = 1
p.cities[2] = city(2)
p.cities[2].buildings[chamber] = 1
eq(council.capacity(p), 6)
local last
for index = 20, 25 do
    turn = turn + 6
    p.gold = 1000
    last = unit(0, index, warrior, 100)
    eq(council.designate(token(last), 480), nil)
    eq(council.specialise(token(last), 1), nil)
    GameEvents.GameCoreUpdateEnd()
end
eq(council.activeScience(p), 12)
new.buildings[chamber], p.cities[2].buildings[chamber] = 0, 0
GameEvents.CitySoldBuilding(0, 1, chamber)
eq(council.capacity(p), 5)
eq(#council.roster(p), 6)
eq(council.activeScience(p), 12)
eq(council.canDesignate(p, reused), "ERR_CAPACITY")
eq(council.stage(last), 3)
p.capital = nil
GameEvents.CapitalChanged(0, -1, 1)
GameEvents.GameCoreUpdateEnd()
eq(new:GetNumBuilding(id.BUILDING_SDOM_APEX_1), 0)
p.capital = new
GameEvents.CapitalChanged(0, 1, -1)
GameEvents.GameCoreUpdateEnd()
eq(council.activeScience(p), 12)
active = 1
eq(council.active(), nil)
eq(council.specialise(token(last), 2), "ERR_TURN")

-- Standard uses the same era schedule at one-third Marathon cost and cooldown.
active, speed, p.era = 0, standard, 0
p.units, saved = {}, {}
p.gold = 100
council = loadContext()
local standardWarrior = unit(0, 1, warrior, 0)
eq(council.cost(p), 40)
eq(council.designate(token(standardWarrior), 40), nil)
eq(council.remaining(p), 2)
eq(p.gold, 60)

-- Combat XP during Industrial is detected at the end of the core update.
p.era, standardWarrior.xp = id.ERA_INDUSTRIAL, 30
eq(council.specialise(token(standardWarrior), 1), nil)
eq(council.stage(standardWarrior), 2)
standardWarrior.xp = 100
GameEvents.GameCoreUpdateEnd()
eq(council.stage(standardWarrior), 3)
GameEvents.UnitCaptured(1, -1, 0, standardWarrior.index, false, 0)
kill(standardWarrior)
eq(council.state(0).hall[1].reason, "REASON_CAPTURE")
eq(council.activeScience(p), 0)

-- The detailed journal rolls over while preserving the lifetime total.
for _ = 1, 201 do
    turn = turn + 2
    p.gold = 1000
    local recruit = unit(0, 1, warrior, 0)
    eq(council.designate(token(recruit), 120), nil)
    kill(recruit)
end
eq(council.state(0).lifetime, 202)
eq(#council.state(0).hall, 200)
council = loadContext()
eq(council.state(0).lifetime, 202)
eq(#council.state(0).hall, 200)
