local council = SCORPION_DOMINION
local ids = GameInfoTypes
local civ = ids.CIVILIZATION_SCORPION_DOMINION
local chamber = ids.BUILDING_SDOM_MOLTING_CHAMBER
local emperor = ids.UNIT_SDOM_EMPEROR_SCORPION
local promotions = {
    ids.PROMOTION_SDOM_ASCENDANT, ids.PROMOTION_SDOM_PINCERS,
    ids.PROMOTION_SDOM_CARAPACE, ids.PROMOTION_SDOM_APEX,
}
local allowed = {}
local dummies, science = {}, {}
local marathon = GameInfo.GameSpeeds[ids.GAMESPEED_MARATHON].TrainPercent
local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()].TrainPercent / marathon
local cooldown = math.max(1, math.floor(6 * speed + 0.5))
local classical, medieval = ids.ERA_CLASSICAL, ids.ERA_MEDIEVAL
local industrial, atomic = ids.ERA_INDUSTRIAL, ids.ERA_ATOMIC
local birthRevision = {}
local birthSerial = 0
local busy = false

for _, kind in ipairs({
    "WARRIOR", "SWORDSMAN", "LONGSWORDSMAN", "MUSKETMAN", "RIFLEMAN",
    "GREAT_WAR_INFANTRY", "INFANTRY", "MECHANIZED_INFANTRY",
}) do
    local row = GameInfo.Units["UNIT_" .. kind]
    if row and row.Class == "UNITCLASS_" .. kind and row.Domain == "DOMAIN_LAND"
        and row.Combat > 0 and row.RangedCombat == 0 then
        allowed[row.ID] = true
    end
end
allowed[emperor] = allowed[ids.UNIT_SWORDSMAN]
for index = 1, 6 do
    local id = ids["BUILDING_SDOM_APEX_" .. index]
    dummies[index], science[id] = id, true
end

council.promotions = promotions
council.chamber = chamber

function council.text(key, ...)
    return Locale.ConvertTextKey("TXT_KEY_SDOM_" .. key, ...)
end

function council.isDominion(player)
    return player and player:GetCivilizationType() == civ
end

function council.isHuman(player)
    return council.isDominion(player) and player:IsAlive() and player:IsHuman()
end

function council.active()
    local player = Players[Game.GetActivePlayer()]
    if council.isHuman(player) then return player end
end

function council.live(unit)
    return unit and not unit:IsDead() and not unit:IsDelayedDeath()
end

function council.eligible(unit)
    return council.live(unit) and allowed[unit:GetUnitType()] and unit:IsCombatUnit()
end

function council.ascendant(unit)
    return council.eligible(unit) and unit:IsHasPromotion(promotions[1])
end

function council.branch(unit)
    local attack, defense = unit:IsHasPromotion(promotions[2]), unit:IsHasPromotion(promotions[3])
    if attack and not defense then return 1 end
    if defense and not attack then return 2 end
    return 0
end

function council.stage(unit)
    if council.branch(unit) == 0 then return 1 end
    return unit:IsHasPromotion(promotions[4]) and 3 or 2
end

function council.strip(unit)
    for _, promotion in ipairs(promotions) do
        if unit:IsHasPromotion(promotion) then unit:SetHasPromotion(promotion, false) end
    end
end

function council.capacity(player)
    local era, capacity = player:GetCurrentEra(), 2
    if era >= medieval then capacity = capacity + 1 end
    if era >= industrial then capacity = capacity + 1 end
    if era >= atomic then capacity = capacity + 1 end
    for city in player:Cities() do
        if city:GetNumBuilding(chamber) > 0 then
            return capacity + 1
        end
    end
    return capacity
end

function council.cost(player)
    return math.floor((120 + 60 * (player:GetCurrentEra() - ids.ERA_ANCIENT)) * speed + 0.5)
end

function council.remaining(player)
    return math.max(0, council.state(player:GetID()).ready - Game.GetGameTurn())
end

function council.roster(player)
    local units = {}
    for unit in player:Units() do
        if council.ascendant(unit) then units[#units + 1] = unit end
    end
    return units
end

function council.isScienceBuilding(id)
    return science[id] == true
end

function council.syncCity(city, slots)
    for index, id in ipairs(dummies) do
        local count = index <= slots and 1 or 0
        if city:GetNumRealBuilding(id) ~= count then city:SetNumRealBuilding(id, count) end
    end
end

function council.syncScience(player)
    local capital = council.isHuman(player) and player:GetCapitalCity()
    local slots = 0
    if capital then
        for unit in player:Units() do
            if council.ascendant(unit) and council.stage(unit) == 3 then slots = slots + 1 end
        end
    end
    for city in player:Cities() do
        council.syncCity(city, capital and city:GetID() == capital:GetID() and slots or 0)
    end
end

function council.activeScience(player)
    local city = player:GetCapitalCity()
    local slots = 0
    if city then
        for _, id in ipairs(dummies) do
            if city:GetNumRealBuilding(id) > 0 then slots = slots + 1 end
        end
    end
    return 2 * slots
end

function council.notify(player, key, unit)
    player:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, council.text(key .. "_BODY"),
        council.text(key), unit and unit:GetX() or -1, unit and unit:GetY() or -1)
end

function council.snapshot(record, unit)
    local name, kind, xp = unit:GetName(), unit:GetUnitType(), unit:GetExperience()
    local branch, stage = council.branch(unit), council.stage(unit)
    local changed = name ~= record.name or kind ~= record.kind or xp ~= record.xp
        or branch ~= record.branch or stage ~= record.stage
    record.name, record.kind, record.xp, record.branch, record.stage = name, kind, xp, branch, stage
    return changed
end

function council.apex(player, unit, silent)
    if council.ascendant(unit) and council.branch(unit) ~= 0 and unit:GetExperience() >= 100
        and player:GetCurrentEra() >= industrial and not unit:IsHasPromotion(promotions[4]) then
        unit:SetHasPromotion(promotions[4], true)
        if not silent then council.notify(player, "NOTICE_APEX", unit) end
        return true
    end
end

function council.birth(owner, id)
    local births = birthRevision[owner] or {}
    birthRevision[owner] = births
    birthSerial = birthSerial + 1
    births[id] = birthSerial
end

function council.endBirth(owner, id)
    local births = birthRevision[owner]
    if births then births[id] = nil end
end

function council.token(unit)
    local owner, id = unit:GetOwner(), unit:GetID()
    local record = council.state(owner).roster[id]
    local births = birthRevision[owner]
    return {owner=owner, id=id, born=unit:GetGameTurnCreated(),
        revision=births and births[id], serial=record and record.serial}
end

function council.resolve(player, token)
    if not token or player:GetID() ~= token.owner then return end
    local unit = player:GetUnitByID(token.id)
    if not council.eligible(unit) or unit:GetOwner() ~= token.owner then return end
    local current = council.token(unit)
    if current.born == token.born and current.revision == token.revision
        and current.serial == token.serial then return unit end
end

local function canAct(player)
    return council.isHuman(player) and Game.GetActivePlayer() == player:GetID()
        and player:IsTurnActive() and not busy
end

function council.designationStatus(player, occupied, capacity)
    if not canAct(player) then return "ERR_TURN" end
    if (occupied or #council.roster(player)) >= (capacity or council.capacity(player)) then return "ERR_CAPACITY" end
    if council.remaining(player) > 0 then return "ERR_COOLDOWN" end
    if player:GetGold() < council.cost(player) then return "ERR_GOLD" end
end

function council.canDesignate(player, unit)
    if not canAct(player) then return "ERR_TURN" end
    if not council.eligible(unit) or unit:GetOwner() ~= player:GetID() then return "ERR_UNIT" end
    if unit:IsHasPromotion(promotions[1]) then return "ERR_ASCENDANT" end
    return council.designationStatus(player)
end

function council.canSpecialise(player, unit)
    if not canAct(player) then return "ERR_TURN" end
    if not council.ascendant(unit) or unit:GetOwner() ~= player:GetID() then return "ERR_UNIT" end
    if unit:IsHasPromotion(promotions[2]) or unit:IsHasPromotion(promotions[3]) then return "ERR_BRANCH" end
    if player:GetCurrentEra() < classical then return "ERR_CLASSICAL" end
    if unit:GetExperience() < 30 then return "ERR_XP" end
end

function council.designate(token, confirmedCost)
    local player = council.active()
    local unit = player and council.resolve(player, token)
    local reason = council.canDesignate(player, unit)
    if reason then return reason end
    local cost = council.cost(player)
    if cost ~= confirmedCost then return "ERR_PRICE_CHANGED" end
    busy = true
    unit:SetHasPromotion(promotions[1], true)
    if not unit:IsHasPromotion(promotions[1]) then busy = false; return "ERR_UNIT" end
    local owner, turn = player:GetID(), Game.GetGameTurn()
    local state = council.state(owner)
    council.snapshot(council.record(unit, state, turn), unit)
    state.ready = turn + cooldown
    player:ChangeGold(-cost)
    council.save(owner)
    busy = false
    council.notify(player, "NOTICE_ASCENDANT", unit)
end

function council.specialise(token, branch)
    local player = council.active()
    local unit = player and council.resolve(player, token)
    local reason = council.canSpecialise(player, unit)
    if reason then return reason end
    if branch ~= 1 and branch ~= 2 then return "ERR_BRANCH" end
    local owner = player:GetID()
    local record = council.state(owner).roster[unit:GetID()]
    if not record then return "ERR_UNIT" end
    busy = true
    local promotion = promotions[branch + 1]
    unit:SetHasPromotion(promotion, true)
    if not unit:IsHasPromotion(promotion) then busy = false; return "ERR_UNIT" end
    council.notify(player, branch == 1 and "NOTICE_PINCERS" or "NOTICE_CARAPACE", unit)
    if council.apex(player, unit) then council.syncScience(player) end
    council.snapshot(record, unit)
    council.save(owner)
    busy = false
end
