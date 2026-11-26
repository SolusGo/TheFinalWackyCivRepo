local civPath = "Civilizations/ArachnidEmpire/Lua/"
local function expect(actual, expected, label)
    assert(actual == expected, (label or "") .. " expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function iter(items)
    local i = 0
    return function() i = i + 1; return items[i] end
end
local function eventTable()
    return setmetatable({}, {__index=function(self, key)
        local callbacks = {}
        local event = {
            Add=function(fn) callbacks[#callbacks + 1] = fn end,
            fire=function(...) for _, fn in ipairs(callbacks) do fn(...) end end,
        }
        self[key] = event
        return event
    end})
end
local function info(rows)
    return setmetatable(rows, {__call=function(self, filter)
        local list = {}
        for key, row in pairs(self) do
            if type(key) == "number" then
                local match = true
                for field, value in pairs(filter or {}) do
                    if row[field] ~= value then match = false end
                end
                if match then list[#list+1] = row end
            end
        end
        return iter(list)
    end})
end

GameInfoTypes = setmetatable({ERA_ANCIENT=0, ERA_MEDIEVAL=2, ERA_INDUSTRIAL=4}, {__index=function(t, k)
    local id = 1000
    for _ in pairs(t) do id = id + 1 end
    t[k] = id
    return id
end})
local ids = GameInfoTypes
local eras, units, classes, resources = {}, {}, {}, {}
for index = 0, 7 do eras[index] = {Description="Era " .. index} end
local function addUnit(name, strength, ranged, tech, resource)
    local typeName, class = "UNIT_" .. name, "UNITCLASS_" .. name
    local unit = {ID=ids[typeName], Type=typeName, Domain="DOMAIN_LAND", Combat=strength,
        RangedCombat=ranged, Range=(ranged > 0 and 2 or 0), PrereqTech=tech, Description=name}
    units[typeName], units[unit.ID] = unit, unit
    if name ~= "ARACHNID_BLACK_WIDOW" then classes[class] = {DefaultUnit=typeName} end
    if resource then resources[#resources + 1] = {UnitType=typeName, ResourceType=resource, Cost=1} end
end
addUnit("WARRIOR", 8, 0)
addUnit("SWORDSMAN", 14, 0, "TECH_IRON_WORKING", "RESOURCE_IRON")
addUnit("MECHANIZED_INFANTRY", 90, 0, "TECH_MOBILE_TACTICS")
addUnit("ARCHER", 5, 7, "TECH_ARCHERY")
addUnit("ARACHNID_BLACK_WIDOW", 5, 8, "TECH_ARCHERY")
addUnit("BAZOOKA", 85, 85, "TECH_NUCLEAR_FISSION")
GameInfo = {Units=info(units), UnitClasses=info(classes), Unit_TechTypes=info({}), Eras=info(eras),
    Unit_ResourceQuantityRequirements=info(resources),
    Civilization_UnitClassOverrides=info({{CivilizationType="CIVILIZATION_ARACHNID_EMPIRE",
        UnitClassType="UNITCLASS_ARCHER", UnitType="UNIT_ARACHNID_BLACK_WIDOW"}})}

local saved, turn, tech, iron, notices, active = {}, 0, {}, 0, {}, 0
Modding = {OpenSaveData=function()
    return {GetValue=function(k) return saved[k] end, SetValue=function(k,v) saved[k]=v end}
end}
Locale = {ConvertTextKey=function(key) return key end}
Game = {GetGameTurn=function() return turn end, GetActivePlayer=function() return active end,
    GetGameSpeedType=function() return ids.GAMESPEED_MARATHON end, IsProcessingMessages=function() return false end}
DirectionTypes = {NUM_DIRECTION_TYPES=6}
NotificationTypes = {NOTIFICATION_GENERIC=1}
Teams = {
    [0]={IsAtWar=function(_, id) return id > 0 and id < 4 end, IsHasTech=function(_, id) return tech[id] end}
}
local function newPlayer(owner, human, barbarian)
    return {owner=owner,human=human,barbarian=barbarian,alive=true,era=0, roster={},cities={},
        GetID=function(self) return self.owner end, GetTeam=function(self) return self.owner end,
        IsAlive=function(self) return self.alive end, IsHuman=function(self) return self.human end,
        IsBarbarian=function(self) return self.barbarian end, IsTurnActive=function() return true end,
        GetCivilizationType=function(self) return self.owner == 0 and ids.CIVILIZATION_ARACHNID_EMPIRE or -1 end,
        GetCurrentEra=function(self) return self.era end,
        GetNumResourceAvailable=function() return iron end,
        AddNotification=function(_, _, body) notices[body]=(notices[body] or 0)+1 end,
        Units=function(self)
            local list = {}
            for _, unit in pairs(self.roster) do list[#list+1] = unit end
            return iter(list)
        end,
        Cities=function(self) return iter(self.cities) end,
        GetUnitByID=function(self, id) return self.roster[id] end,
        GetCityByID=function(self, id) return self.cities[id] end}
end
local player, enemy, minor, barb, friend = newPlayer(0,true), newPlayer(1,false),
    newPlayer(2,false), newPlayer(3,false,true), newPlayer(4,false)
Players = {[0]=player, enemy, minor, barb, friend}
local chamber, science = ids.BUILDING_ARACHNID_BROOD_CHAMBER, ids.BUILDING_ARACHNID_CHAMBER_SCIENCE
local function makePlot(x, city)
    return {owner=0, terrain="land", residents={},
        IsWater=function(self) return self.terrain=="water" end,
        IsMountain=function(self) return self.terrain=="mountain" end,
        IsImpassable=function(self) return self.terrain=="blocked" end,
        GetX=function() return x end, GetY=function() return 0 end,
        GetOwner=function(self) return self.owner end, GetPlotCity=function() return city end,
        GetNumUnits=function(self) return #self.residents end, GetUnit=function(self,i) return self.residents[i+1] end}
end
local function newCity(x, capital)
    local city = {owner=0, founded=turn, buildings={},
        GetOwner=function(self) return self.owner end, GetOriginalOwner=function() return 0 end,
        GetGameTurnFounded=function(self) return self.founded end, IsOriginalCapital=function() return capital end,
        GetX=function() return x end, GetY=function() return 0 end,
        GetNumBuilding=function(self,id) return self.buildings[id] or 0 end,
        GetNumRealBuilding=function(self,id) return self.buildings[id] or 0 end,
        SetNumRealBuilding=function(self,id,value) self.buildings[id]=value end,
        Plot=function(self) return self.plot end}
    city.plot = makePlot(x, city)
    city.buildings[chamber] = 1
    return city
end
local home, second, third = newCity(0,true), newCity(10,false), newCity(20,false)
for _, city in ipairs({home,second,third}) do player.cities[#player.cities+1] = city end
local adjacent = makePlot(1)
Map = {GetPlot=function(x) if x==0 then return home.plot elseif x==10 then return second.plot end end,
    PlotDirection=function(_, _, d) if d==0 then return adjacent end end}
local nextID = 0
local function makeUnit(owner, kind, military, id)
    nextID = nextID + 1
    local unit = {owner=owner.owner, id=id or nextID, kind=kind, born=turn, promotions={},
        damage=0, military=military, ranged=false, delayed=false, name="",
        GetOwner=function(self) return self.owner end, GetID=function(self) return self.id end,
        GetUnitType=function(self) return self.kind end,
        GetX=function(self) return self.x end, GetY=function() return 0 end,
        GetPlot=function(self) return self.x == 0 and home.plot or adjacent end,
        Kill=function(self) Players[self.owner].roster[self.id]=nil end,
        GetGameTurnCreated=function(self) return self.born end,
        IsDelayedDeath=function(self) return self.delayed end,
        IsDead=function(self) return self.damage>=100 end,
        IsEmbarked=function() return false end,
        IsCombatUnit=function(self) return self.military end, CanNuke=function() return false end,
        IsCanAttackRanged=function(self) return self.ranged end,
        GetDamage=function(self) return self.damage end, GetMaxHitPoints=function() return 100 end,
        SetDamage=function(self,n) self.damage=n end,
        IsHasPromotion=function(self,p) return self.promotions[p] == true end,
        SetHasPromotion=function(self,p,v) self.promotions[p] = v end,
        GetNameNoDesc=function(self) return self.name end, SetName=function(self,n) self.name=n end}
    owner.roster[unit.id] = unit
    return unit
end
local spawned
function player:InitUnit(kind,x)
    spawned = makeUnit(self,kind,true); spawned.x = x
    return spawned
end
local function load()
    GameEvents, Events = eventTable(), eventTable()
    dofile(civPath .. "ARACHNID_State.lua")
    dofile(civPath .. "ARACHNID_Rules.lua")
    ARACHNID.dirty = function() end
    dofile(civPath .. "ARACHNID_Events.lua")
    Events.SequenceGameInitComplete.fire()
    return ARACHNID, ARACHNID.state(0)
end

local brood, state = load()
local function occupied() local _, cp = brood.swarm(player); return cp end
local function payout() GameEvents.PlayerDoTurn.fire(0) end
local function spawnReason(i) return brood.spawnStatus(player, i, occupied()) end
local function battleStart(source, target, kind)
    GameEvents.BattleStarted.fire(kind or 1, 1, 2)
    GameEvents.BattleJoined.fire(source.owner, source.id, 0, false)
    GameEvents.BattleJoined.fire(target.owner, target.id, 1, false)
    GameEvents.CombatResult.fire(source.owner, source.id, 20, 20, 100, target.owner, target.id, 20, 20, 100, -1, -1, 0, 1, 2)
end
local function kill(source, target, kind)
    battleStart(source, target, kind)
    target.damage = 100
    GameEvents.UnitPrekill.fire(target.owner, target.id, target.kind, 1, 2, true, source.owner)
    GameEvents.UnitKilledInCombat.fire(source.owner, target.owner, target.kind)
    GameEvents.UnitPrekill.fire(target.owner, target.id, target.kind, 1, 2, true, source.owner)
    GameEvents.UnitKilledInCombat.fire(source.owner, target.owner, target.kind)
    target.delayed = true
    GameEvents.UnitPrekill.fire(target.owner, target.id, target.kind, 1, 2, false, source.owner)
    GameEvents.BattleFinished.fire()
    Players[target.owner].roster[target.id] = nil
end
expect(state.sp,0); expect(state.ep,0); expect(occupied(),0); expect(brood.capacity(state),3)
expect(brood.income(player),4); expect(brood.income(enemy),0)
payout(); payout(); expect(state.sp,4,"once per turn")
brood,state = load(); payout(); expect(state.sp,4,"reload payout")
expect(spawnReason(1),"LOW_SP"); expect(spawnReason(2),"EVOLUTION_LOCK")
local conventional = makeUnit(player,ids.UNIT_ARACHNID_BLACK_WIDOW,true)
expect(occupied(),0,"trained units are free")
kill(conventional, makeUnit(enemy,2,true),0)
kill(conventional, makeUnit(minor,2,true))
kill(conventional, makeUnit(enemy,2,true),2)
expect(state.sp,16); expect(state.ep,3)
expect(notices.TXT_KEY_ARACHNID_NOTICE_AVAILABLE,1)
kill(conventional, makeUnit(enemy,2,false))
kill(conventional, makeUnit(friend,2,true))
local deleted = makeUnit(enemy,2,true)
GameEvents.UnitPrekill.fire(1,deleted.id,2,1,2,false,-1)
GameEvents.UnitKilledInCombat.fire(0,1,2)
expect(state.sp,16,"civilian, friendly and deletion exclusions")
battleStart(conventional, makeUnit(enemy,2,true))
deleted.damage = 100
GameEvents.UnitPrekill.fire(1,deleted.id,2,1,2,true,0)
GameEvents.UnitKilledInCombat.fire(0,1,2)
GameEvents.BattleFinished.fire()
expect(state.sp,16,"unrelated scripted death during combat")
for i=1,7 do kill(conventional,makeUnit(barb,3,true)) end
expect(state.sp,21); expect(state.ep,3); expect(state.barbKills,5)
player.era=1; kill(conventional,makeUnit(barb,3,true)); expect(state.sp,22); expect(state.barbKills,1)
player.era=0
expect(brood.evolve(1),nil); expect(state.ep,0); expect(brood.capacity(state),5)
expect(brood.evolve(1),"EVOLVED"); expect(brood.evolve(2),"LOW_EP")
state.ep=50
expect(brood.evolve(4),"ERA_LOCK")
expect(brood.evolve(2),nil); expect(brood.evolve(3),nil)
player.era=4
expect(brood.evolve(7),"EVOLUTION_LOCK")
state.sp=2000
tech[ids.TECH_ARCHERY] = true
local tier = {45,65,80}
for era=0,7 do
    player.era=era
    for index=1,3 do
        local _,_,price = brood.spawnStatus(player,index,0)
        expect(price,tier[index]+15*era)
    end
end
player.era=0
tech[ids.TECH_IRON_WORKING] = true
local _,_,_,base = brood.spawnStatus(player,1,0)
expect(base.Type,"UNIT_WARRIOR","iron fallback")
iron=1
home.plot.residents={conventional}; adjacent.terrain="water"
expect(spawnReason(1),"NO_PLOT")
adjacent.terrain="land"; adjacent.owner=1
expect(spawnReason(1),"NO_PLOT")
adjacent.owner=0
expect(brood.spawn(1),nil)
local broodling=spawned
expect(broodling.kind,ids.UNIT_SWORDSMAN); expect(broodling.x,1); expect(occupied(),1)
expect(brood.spawn(2),"COOLDOWN_LOCK"); expect(state.sp,1955)
brood,state=load()
expect(brood.spawn(2),"COOLDOWN_LOCK"); expect(occupied(),1)
turn=turn+3
expect(brood.spawn(2),nil); local venom=spawned
expect(venom.kind,ids.UNIT_ARACHNID_BLACK_WIDOW); expect(occupied(),3)
turn=turn+3
expect(brood.spawn(3),nil); local armour=spawned
expect(occupied(),5)
turn=turn+3; expect(brood.spawn(1),"LOW_CP")
local victim=makeUnit(enemy,9,true)
battleStart(venom,victim); victim.damage=24; GameEvents.BattleFinished.fire()
expect(brood.poisonFor(1)[victim.id].damage,5)
brood,state=load()
GameEvents.PlayerDoTurn.fire(1); GameEvents.PlayerDoTurn.fire(1)
expect(victim.damage,29); expect(next(brood.poisonFor(1)),nil)
battleStart(venom,victim); victim.damage=40; GameEvents.BattleFinished.fire()
player.era=2
expect(brood.evolve(4),nil); expect(brood.capacity(state),8)
expect(third:GetNumRealBuilding(science),1)
expect(brood.evolve(5),nil); expect(brood.evolve(6),nil)
expect(armour:IsHasPromotion(ids.PROMOTION_ARACHNID_REGENERATION),true)
expect(venom:IsHasPromotion(ids.PROMOTION_ARACHNID_REGENERATION),false)
battleStart(venom,victim); victim.damage=98; GameEvents.BattleFinished.fire()
expect(brood.poisonFor(1)[victim.id].damage,10)
GameEvents.PlayerDoTurn.fire(1); expect(victim.damage,99,"nonlethal")
battleStart(venom,victim); GameEvents.BattleFinished.fire()
expect(next(brood.poisonFor(1)),nil,"no damage")
victim.damage=50
battleStart(venom,victim); victim.damage=65; GameEvents.BattleFinished.fire()
local captured = makeUnit(minor,9,true)
GameEvents.UnitConverted.fire(1,2,victim.id,captured.id,false)
GameEvents.PlayerDoTurn.fire(1); expect(victim.damage,65,"conversion cancels poison")
expect(captured:IsHasPromotion(ids.PROMOTION_ARACHNID_POISON),false)
player.era=4
expect(brood.evolve(7),nil)
expect(venom:IsHasPromotion(ids.PROMOTION_ARACHNID_APEX),true)
expect(conventional:IsHasPromotion(ids.PROMOTION_ARACHNID_APEX),false)
local upgraded=makeUnit(player,11,true)
GameEvents.UnitConverted.fire(0,0,venom.id,upgraded.id,true)
expect(occupied(),5); expect(brood.specialization(upgraded),2); expect(brood.specialization(venom),nil)
local gift=makeUnit(friend,11,true)
gift.promotions[ids.PROMOTION_ARACHNID_VENOM]=true
gift.promotions[ids.PROMOTION_ARACHNID_APEX]=true
GameEvents.UnitConverted.fire(0,4,upgraded.id,gift.id,false)
player.roster[upgraded.id]=nil
expect(occupied(),3); expect(brood.specialization(gift),nil)
expect(gift:IsHasPromotion(ids.PROMOTION_ARACHNID_APEX),false)
local returned=makeUnit(player,11,true)
GameEvents.UnitConverted.fire(4,0,gift.id,returned.id,false)
expect(occupied(),3)
player.roster[broodling.id]=nil
expect(occupied(),2,"capacity reconciles death")
tech[ids.TECH_NUCLEAR_FISSION]=true
local _,_,_,late = brood.spawnStatus(player,2,occupied())
expect(late.Type,"UNIT_BAZOOKA")
home.owner,home.plot.owner=1,1
player.cities={second,third}
GameEvents.CityCaptureComplete.fire(0,true,0,0,1)
expect(spawnReason(1),"NO_LAIR"); expect(brood.income(player),0)
expect(third:GetNumRealBuilding(science),1); expect(occupied(),2)
turn=turn+1; local sp=state.sp
payout(); expect(state.sp,sp)
kill(conventional, makeUnit(enemy,2,true)); expect(state.sp,sp+4)
brood,state=load(); expect(spawnReason(1),"NO_LAIR")
home.owner,home.plot.owner=0,0; player.cities={home,second,third}
GameEvents.CityCaptureComplete.fire(1,true,0,0,0)
expect(brood.income(player),4); expect(notices.TXT_KEY_ARACHNID_NOTICE_RECOVERED,1)
third.buildings[chamber]=0
GameEvents.CitySoldBuilding.fire(0,3,chamber)
expect(third:GetNumRealBuilding(science),0)
third.buildings[chamber]=1
GameEvents.CityConstructed.fire(0,3,chamber,false,false)
expect(third:GetNumRealBuilding(science),1)
expect(spawnReason(1),nil)
player.human=false
expect(brood.spawn(1),"INELIGIBLE"); expect(brood.evolve(1),"INELIGIBLE")
player.human=true

-- 5.4.6's city bombardment uses -1/-1 for the attacking RED owner/ID.
local target = makeUnit(enemy,12,true)
local before = state.sp
GameEvents.BattleStarted.fire(1,2,3)
GameEvents.CombatResult.fire(-1,-1,0,0,200,1,target.id,100,100,100,-1,-1,0,2,3)
target.damage=100
GameEvents.UnitPrekill.fire(1,target.id,12,2,3,true,0)
GameEvents.UnitKilledInCombat.fire(0,1,12,-1)
GameEvents.BattleFinished.fire()
expect(state.sp,before+4,"city bombardment")

-- Quick melee can resolve after defensive fire support at another plot.
local attacker = makeUnit(enemy,12,true)
local collateral = makeUnit(enemy,13,true)
GameEvents.BattleStarted.fire(0,5,6)
GameEvents.BattleJoined.fire(1,collateral.id,3,false)
GameEvents.BattleStarted.fire(1,7,8)
GameEvents.CombatResult.fire(1,attacker.id,0,0,100,0,conventional.id,1,1,100,-1,-1,0,7,8)
GameEvents.BattleFinished.fire()
GameEvents.CombatEnded.fire()
GameEvents.CombatResult.fire(1,attacker.id,100,100,100,0,conventional.id,10,10,100,-1,-1,0,5,6)
attacker.damage=100
GameEvents.UnitPrekill.fire(1,attacker.id,12,5,6,true,0)
GameEvents.UnitKilledInCombat.fire(0,1,12,-1)
collateral.damage=100
GameEvents.UnitPrekill.fire(1,collateral.id,13,5,6,true,0)
GameEvents.UnitKilledInCombat.fire(0,1,13,-1)
GameEvents.BattleFinished.fire()
expect(state.sp,before+12,"defensive and subsequent participant kills")

-- Successful air-strike interception aborts the strike. RED reports the
-- interceptor and suppresses principal damage, but CP's lethal callback uses the target owner.
local function airDefense(targetOwner, targetID, interceptorOwner, interceptorID, interceptorDamage, retaliation)
    local aircraft = makeUnit(enemy,14,false)
    aircraft.ranged = true
    GameEvents.BattleStarted.fire(2,1,2)
    local finalDamage = interceptorDamage > 0 and 0 or retaliation
    GameEvents.CombatResult.fire(1,aircraft.id,retaliation,finalDamage,100,targetOwner,targetID,0,0,100,
        interceptorOwner,interceptorID,interceptorDamage,1,2)
    aircraft.damage=100
    GameEvents.UnitPrekill.fire(1,aircraft.id,14,1,2,true,targetOwner)
    GameEvents.UnitKilledInCombat.fire(targetOwner,1,14,-1)
    GameEvents.UnitKilledInCombat.fire(targetOwner,1,14,-1)
    GameEvents.BattleFinished.fire()
end
local thirdPartyGuard = makeUnit(minor,15,true)
local airSP, airEP = state.sp, state.ep
airDefense(2,-1,0,conventional.id,100,0)
expect(state.sp,airSP+4,"Arachnid interceptor over another owner's city")
expect(state.ep,airEP+1)
airDefense(0,conventional.id,2,thirdPartyGuard.id,100,0)
expect(state.sp,airSP+4,"foreign interceptor over Arachnid target")
airDefense(0,conventional.id,2,-1,100,0)
expect(state.sp,airSP+4,"unidentified interceptor fails closed")
airDefense(0,conventional.id,2,thirdPartyGuard.id,0,100)
expect(state.sp,airSP+8,"ordinary retaliation after a failed interception")

local expired = makeUnit(enemy,12,true)
battleStart(conventional,expired)
GameEvents.GameCoreUpdateEnd.fire()
expired.damage=100
GameEvents.UnitPrekill.fire(1,expired.id,12,1,2,true,0)
GameEvents.UnitKilledInCombat.fire(0,1,12,-1)
expect(state.sp,airSP+8,"expired combat cannot pay")
local retainedVenom = makeUnit(player,9,true)
brood.applyBiology(retainedVenom,2,state)
local unharmed = makeUnit(enemy,12,true)
GameEvents.BattleStarted.fire(1,1,2)
GameEvents.CombatResult.fire(0,retainedVenom.id,0,0,100,1,unharmed.id,0,0,100,-1,-1,0,1,2)
unharmed.damage=5
GameEvents.BattleFinished.fire()
expect(brood.poisonFor(1)[unharmed.id],nil,"unattributed HP loss cannot apply venom")
player.roster[retainedVenom.id]=nil

local bypass = makeUnit(minor,9,true)
GameEvents.UnitCreated.fire(2,bypass.id,9,0,0)
bypass:SetHasPromotion(ids.PROMOTION_ARACHNID_VENOM,true)
bypass:SetHasPromotion(ids.PROMOTION_ARACHNID_APEX,true)
bypass:SetName(brood.text("VENOM"))
GameEvents.GameCoreUpdateEnd.fire()
expect(brood.specialization(bypass),nil,"delayed gift copy")
expect(bypass:IsHasPromotion(ids.PROMOTION_ARACHNID_APEX),false)
expect(bypass:GetNameNoDesc(),"")
local restoredGift = makeUnit(player,9,true)
GameEvents.UnitCreated.fire(0,restoredGift.id,9,0,0)
restoredGift:SetHasPromotion(ids.PROMOTION_ARACHNID_VENOM,true)
restoredGift:SetHasPromotion(ids.PROMOTION_ARACHNID_ARMOURED,true)
GameEvents.GameCoreUpdateEnd.fire()
expect(brood.specialization(restoredGift),nil,"returned gift with unverified specialization")

local orphan = makeUnit(enemy,9,true)
orphan:SetHasPromotion(ids.PROMOTION_ARACHNID_POISON,true)
brood,state=load()
expect(orphan:IsHasPromotion(ids.PROMOTION_ARACHNID_POISON),false,"orphan on load")
brood.poisonFor(1)[orphan.id]={born=orphan.born,damage=10}
GameEvents.PlayerDoTurn.fire(1)
expect(orphan.damage,0,"missing marker")
brood.poisonFor(1)[orphan.id]={born=orphan.born,damage=10}
GameEvents.UnitCreated.fire(1,orphan.id,9,0,0)
expect(brood.poisonFor(1)[orphan.id],nil,"reused ID in the same turn")

local normalInit = player.InitUnit
local beforeSP, beforeReady, beforeCP = state.sp, state.ready, occupied()
player.InitUnit = function() return nil end
expect(brood.spawn(1),"CREATE_FAILED","null return")
player.InitUnit = function(self, kind, x)
    local unit = normalInit(self,kind,x)
    unit.x=x+2
    return unit
end
expect(brood.spawn(1),"CREATE_FAILED","unexpected tile")
expect(player.roster[spawned.id],nil,"rollback removes only created unit")
player.InitUnit = function() return conventional end
expect(brood.spawn(1),"CREATE_FAILED","existing unit returned")
expect(player.roster[conventional.id],conventional)
player.InitUnit = function(self, kind, x)
    local unit = normalInit(self,kind,x)
    iron=-1
    return unit
end
expect(brood.spawn(1),"CREATE_FAILED","resource changed during creation")
expect(player.roster[spawned.id],nil)
iron=1
expect(state.sp,beforeSP); expect(state.ready,beforeReady); expect(occupied(),beforeCP)
player.InitUnit=normalInit
expect(brood.spawn(1),nil,"guard recovered")
expect(brood.hooksReady(),false,"missing CP schema")
local savedProgress = state.evolved
player.alive=false
home.owner,home.plot.owner=1,1
GameEvents.CityCaptureComplete.fire(0,true,0,0,1,1,false)
expect(home:GetNumRealBuilding(science),0,"capture strips Science through elimination")
expect(brood.spawn(1),"INELIGIBLE")
player.alive=true
brood,state=load()
expect(state.evolved,savedProgress,"resurrection preserves progression")
expect(spawnReason(1),"NO_LAIR")
home.owner,home.plot.owner=0,0
GameEvents.CityCaptureComplete.fire(1,true,0,0,0,1,false)
expect(home:GetNumRealBuilding(science),1,"liberation restores Science")
