local brood = ARACHNID
local ids, text = GameInfoTypes, brood.text
local chamber, science = ids.BUILDING_ARACHNID_BROOD_CHAMBER, ids.BUILDING_ARACHNID_CHAMBER_SCIENCE
local regeneration, apex = ids.PROMOTION_ARACHNID_REGENERATION, ids.PROMOTION_ARACHNID_APEX
local cooldown = {[ids.GAMESPEED_EPIC]=2, [ids.GAMESPEED_MARATHON]=3}
local initialEra = ids.ERA_ANCIENT

local function originalCity(city, owner)
    return city and city:IsOriginalCapital() and city:GetOriginalOwner() == owner
end

-- The coordinates and founding turn continue to identify the original city after
-- capture changes its local city ID. The Palace and current capital are immaterial.
local function lairCity(owner)
    local state = brood.state(owner)
    if state.x < 0 then return end
    local plot = Map.GetPlot(state.x, state.y)
    local city = plot and plot:GetPlotCity()
    if originalCity(city, owner) and city:GetGameTurnFounded() == state.founded then return city end
end

function brood.queen(player)
    local city = lairCity(player:GetID())
    if city and city:GetOwner() == player:GetID() then return city end
end

function brood.income(player)
    if not brood.queen(player) then return 0 end
    local chambers = 0
    for city in player:Cities() do
        if city:GetNumBuilding(chamber) > 0 then
            chambers = chambers + 1
            if chambers == 2 then break end
        end
    end
    return 2 + chambers
end

function brood.updateLair(player)
    local owner = player:GetID()
    local state = brood.state(owner)
    if state.x < 0 then
        for city in player:Cities() do
            if originalCity(city, owner) then
                state.x, state.y, state.founded = city:GetX(), city:GetY(), city:GetGameTurnFounded()
                state.lair = 1
                brood.save(owner)
                return
            end
        end
        return
    end
    local status = brood.queen(player) and 1 or 0
    if status ~= state.lair then
        state.lair = status
        brood.save(owner)
        brood.notify(player, status == 1 and "NOTICE_RECOVERED" or "NOTICE_LOST")
    end
end

function brood.syncCity(city)
    if not city then return end
    local owner = city:GetOwner()
    local value = 0
    if brood.eligible(Players[owner]) and city:GetNumBuilding(chamber) > 0
        and brood.evolved(brood.state(owner), 4) then
        value = 1
    end
    if city:GetNumRealBuilding(science) ~= value then city:SetNumRealBuilding(science, value) end
end

function brood.syncCities(player)
    for city in player:Cities() do brood.syncCity(city) end
end

function brood.applyBiology(unit, specialization, state)
    for index, variant in ipairs(brood.variants) do
        unit:SetHasPromotion(variant.promotion, index == specialization)
    end
    unit:SetHasPromotion(regeneration, specialization == 3 and brood.evolved(state, 6))
    unit:SetHasPromotion(apex, specialization ~= nil and brood.evolved(state, 7))
end

function brood.stripBiology(unit)
    local name = unit:GetNameNoDesc()
    for _, variant in ipairs(brood.variants) do
        if name == text(variant.key) then unit:SetName(""); break end
    end
    if brood.specialization(unit) or unit:IsHasPromotion(regeneration) or unit:IsHasPromotion(apex) then
        brood.applyBiology(unit, nil)
    end
end

function brood.swarm(player)
    local units, occupied = {}, 0
    for unit in player:Units() do
        if not unit:IsDelayedDeath() and not unit:IsDead() then
            local specialization = brood.specialization(unit)
            if specialization then
                units[#units + 1] = {unit=unit, variant=specialization}
                occupied = occupied + brood.variants[specialization].cp
            end
        end
    end
    return units, occupied
end

function brood.capacity(state)
    return 3 + (brood.evolved(state, 1) and 2 or 0) + (brood.evolved(state, 4) and 3 or 0)
end

function brood.remaining(state)
    return math.max(0, state.ready - Game.GetGameTurn())
end

function brood.evolutionStatus(player, index)
    if not brood.eligible(player) or not brood.evolutions[index] then return "INELIGIBLE" end
    local state, node = brood.state(player:GetID()), brood.evolutions[index]
    if brood.evolved(state, index) then return "EVOLVED" end
    if not brood.queen(player) then return "NO_LAIR" end
    if player:GetCurrentEra() < node.era then return "ERA_LOCK", Locale.ConvertTextKey(GameInfo.Eras[node.era].Description) end
    for _, prerequisite in ipairs(node.requires) do
        if not brood.evolved(state, prerequisite) then return "EVOLUTION_LOCK", text(brood.evolutions[prerequisite].key) end
    end
    if state.ep < node.cost then return "LOW_EP", node.cost end
end

function brood.checkFirstEvolution(player)
    local owner = player:GetID()
    local state = brood.state(owner)
    if state.firstEvolution == 1 then return end
    for index in ipairs(brood.evolutions) do
        if not brood.evolutionStatus(player, index) then
            state.firstEvolution = 1
            brood.save(owner)
            brood.notify(player, "NOTICE_AVAILABLE")
            return
        end
    end
end

-- Strongest first. These are explicit class allowlists, not the player's entire
-- build roster. Upgrades after spawning continue to use the ordinary DLL rules.
local melee = {
    "MECHANIZED_INFANTRY", "INFANTRY", "GREAT_WAR_INFANTRY", "RIFLEMAN", "MUSKETMAN",
    "LONGSWORDSMAN", "PIKEMAN", "SWORDSMAN", "SPEARMAN", "WARRIOR",
}
local ranged = {"BAZOOKA", "MACHINE_GUN", "GATLINGGUN", "CROSSBOWMAN", "COMPOSITE_BOWMAN", "ARCHER"}
local candidates = {{}, {}}
for index, lineage in ipairs({melee, ranged}) do
    for _, name in ipairs(lineage) do
        local classType = "UNITCLASS_" .. name
        local class = GameInfo.UnitClasses[classType]
        if class then
            local unitType = class.DefaultUnit
            for override in GameInfo.Civilization_UnitClassOverrides{
                CivilizationType="CIVILIZATION_ARACHNID_EMPIRE", UnitClassType=classType,
            } do
                unitType = override.UnitType
            end
            local row = unitType and GameInfo.Units[unitType]
            if row and row.Domain == "DOMAIN_LAND" and row.Combat > 0
                and ((index == 2 and row.RangedCombat > 0 and row.Range > 0)
                    or (index == 1 and row.RangedCombat == 0)) then
                local candidate = {row=row, tech={}, resources={}}
                if row.PrereqTech then candidate.tech[#candidate.tech + 1] = ids[row.PrereqTech] end
                for extra in GameInfo.Unit_TechTypes{UnitType=unitType} do
                    candidate.tech[#candidate.tech + 1] = ids[extra.TechType]
                end
                for need in GameInfo.Unit_ResourceQuantityRequirements{UnitType=unitType} do
                    candidate.resources[#candidate.resources + 1] = {id=ids[need.ResourceType], amount=need.Cost}
                end
                candidates[index][#candidates[index] + 1] = candidate
            end
        end
    end
    table.sort(candidates[index], function(a, b)
        local stat = index == 2 and "RangedCombat" or "Combat"
        if a.row[stat] == b.row[stat] then return a.row.ID < b.row.ID end
        return a.row[stat] > b.row[stat]
    end)
end

local function contemporary(player, index)
    local team = Teams[player:GetTeam()]
    for _, candidate in ipairs(candidates[index == 2 and 2 or 1]) do
        local available = true
        for _, tech in ipairs(candidate.tech) do
            if not team:IsHasTech(tech) then available = false; break end
        end
        if available then
            for _, resource in ipairs(candidate.resources) do
                if player:GetNumResourceAvailable(resource.id, true) < resource.amount then
                    available = false
                    break
                end
            end
        end
        if available then return candidate.row end
    end
end

local function legalPlot(player, plot, createdID)
    if not plot or plot:GetOwner() ~= player:GetID() or plot:IsWater()
        or plot:IsMountain() or plot:IsImpassable() then return false end
    local city = plot:GetPlotCity()
    if city and city:GetOwner() ~= player:GetID() then return false end
    for index = 0, plot:GetNumUnits() - 1 do
        local unit = plot:GetUnit(index)
        if unit and not (unit:GetOwner() == player:GetID() and unit:GetID() == createdID)
            and not unit:IsDelayedDeath()
            and (unit:GetOwner() ~= player:GetID() or brood.military(unit) or unit:IsEmbarked()) then
            return false
        end
    end
    return true
end

local function placement(player, city)
    local home = city:Plot()
    if legalPlot(player, home) then return home end
    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
        local plot = Map.PlotDirection(home:GetX(), home:GetY(), direction)
        if legalPlot(player, plot) then return plot end
    end
end

function brood.spawnStatus(player, index, occupied)
    local variant = brood.variants[index]
    if not brood.eligible(player) or not variant then return "INELIGIBLE" end
    local state = brood.state(player:GetID())
    local city = brood.queen(player)
    local cost = variant.sp + 15 * math.max(0, player:GetCurrentEra() - initialEra)
    local row = contemporary(player, index)
    local reason, detail
    if not city then reason = "NO_LAIR"
    elseif variant.unlock and not brood.evolved(state, variant.unlock) then
        reason, detail = "EVOLUTION_LOCK", text(brood.evolutions[variant.unlock].key)
    elseif brood.remaining(state) > 0 then reason, detail = "COOLDOWN_LOCK", brood.remaining(state)
    elseif state.sp < cost then reason, detail = "LOW_SP", cost
    elseif occupied + variant.cp > brood.capacity(state) then reason = "LOW_CP"
    elseif not row then reason = "NO_UNIT" end
    local plot
    if not reason then
        plot = placement(player, city)
        if not plot then reason = "NO_PLOT" end
    end
    return reason, detail, cost, row, plot
end

local acting = false
local function canAct(player)
    return not acting and brood.eligible(player) and Game.GetActivePlayer() == player:GetID()
        and player:IsTurnActive() and not Game.IsProcessingMessages()
end

function brood.spawn(index)
    local player = brood.active()
    if not canAct(player) then return "INELIGIBLE" end
    local _, occupied = brood.swarm(player)
    local reason, detail, cost, row, plot = brood.spawnStatus(player, index, occupied)
    if reason then return reason, detail end

    acting = true
    local owner = player:GetID()
    local existing = {}
    for prior in player:Units() do existing[prior:GetID()] = true end
    local x, y = plot:GetX(), plot:GetY()
    local ok, unit = pcall(player.InitUnit, player, row.ID, x, y)
    if ok and unit and unit:GetOwner() == owner and not existing[unit:GetID()] then
        unit = brood.liveUnit(owner, unit:GetID())
    else
        unit = nil
    end
    local created = unit ~= nil
    local valid = created and unit:GetUnitType() == row.ID and unit:GetX() == x and unit:GetY() == y
        and brood.queen(player) and legalPlot(player, unit:GetPlot(), unit:GetID())
    if valid then
        for need in GameInfo.Unit_ResourceQuantityRequirements{UnitType=row.Type} do
            -- A live unit is already included in CP's resource usage.
            if player:GetNumResourceAvailable(ids[need.ResourceType], true) < 0 then valid = false; break end
        end
    end
    if not valid then
        if created then unit:Kill(false, -1) end
        acting = false
        return "CREATE_FAILED"
    end
    local state = brood.state(owner)
    brood.applyBiology(unit, index, state)
    brood.retainBirth(unit)
    unit:SetName(text(brood.variants[index].key))
    state.sp = state.sp - cost
    state.ready = Game.GetGameTurn() + (cooldown[Game.GetGameSpeedType()] or 1)
    brood.save(owner)
    acting = false
    brood.notify(player, "NOTICE_SPAWN", text(brood.variants[index].key))
end

function brood.evolve(index)
    local player = brood.active()
    if not canAct(player) then return "INELIGIBLE" end
    local reason, detail = brood.evolutionStatus(player, index)
    if reason then return reason, detail end

    acting = true
    local owner = player:GetID()
    local state, node = brood.state(owner), brood.evolutions[index]
    state.ep, state.evolved = state.ep - node.cost, state.evolved + 2 ^ (index - 1)
    brood.save(owner)
    if index == 4 then brood.syncCities(player) end
    if index == 6 or index == 7 then
        for _, entry in ipairs(brood.swarm(player)) do brood.applyBiology(entry.unit, entry.variant, state) end
    end
    acting = false
    brood.notify(player, (index == 4 or index == 7) and "NOTICE_MILESTONE" or "NOTICE_EVOLVED", text(node.key))
end

function brood.reward(player, barbarian)
    local owner, era = player:GetID(), player:GetCurrentEra()
    local state = brood.state(owner)
    if barbarian then
        if state.barbEra ~= era then state.barbEra, state.barbKills = era, 0 end
        if state.barbKills >= 5 then return end
        state.barbKills, state.sp = state.barbKills + 1, state.sp + 1
    else
        state.sp, state.ep = state.sp + 4, state.ep + 1
    end
    brood.save(owner)
    brood.checkFirstEvolution(player)
end

function brood.payTurn(player)
    local owner, turn = player:GetID(), Game.GetGameTurn()
    local state = brood.state(owner)
    brood.updateLair(player)
    brood.syncCities(player)
    if state.payout ~= turn then
        state.payout, state.sp = turn, state.sp + brood.income(player)
        brood.save(owner)
    end
    brood.checkFirstEvolution(player)
end
