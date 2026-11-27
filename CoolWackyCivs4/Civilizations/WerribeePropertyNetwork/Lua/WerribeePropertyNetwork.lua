if WerribeePropertyNetworkLoaded then return end
WerribeePropertyNetworkLoaded = true

local types = GameInfoTypes
local civType = types.CIVILIZATION_WERRIBEE_PROPERTY_NETWORK
local office = types.BUILDING_WERRIBEE_REAL_ESTATE_OFFICE
local consultant = types.UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT
local dummy = {}
for _, name in ipairs({
    "PRIME_REAL_ESTATE", "PROPERTY_SALE", "CONNECTED_SUBURB", "CONNECTED_METROPOLIS",
    "APPRAISAL_YIELD", "APPRAISAL_MODIFIER", "VENDOR_NETWORK", "HOUSING_DEMAND", "PROPERTY_BOOM",
}) do
    dummy[name] = types["BUILDING_WERRIBEE_DUMMY_" .. name]
    if dummy[name] == nil then
        print("Werribee Property Network: missing database entry for " .. name)
        return
    end
end
if not (civType and office and consultant) then return end

local data = Modding.OpenSaveData()
local prefix = "CoolWackyCivs4.Werribee.1."
local cityStates = {}
local consultantPlots = {}

local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()]
local speeds = {
    GAMESPEED_QUICK = {67, 3, 7},
    GAMESPEED_STANDARD = {100, 5, 10},
    GAMESPEED_EPIC = {150, 8, 15},
    GAMESPEED_MARATHON = {200, 15, 30},
}
local growthPercent = speed and tonumber(speed.GrowthPercent) or 100
local scaling = speeds[speed and speed.Type] or {
    math.max(67, math.min(200, growthPercent)),
    math.max(3, math.min(15, math.floor(5 * growthPercent / 100 + 0.5))),
    math.max(7, math.min(30, math.floor(10 * growthPercent / 100 + 0.5))),
}
local rewardPercent, saleDuration, vendorDuration = unpack(scaling)
local eraPercent = {
    [types.ERA_ANCIENT] = 100, [types.ERA_CLASSICAL] = 100, [types.ERA_MEDIEVAL] = 150,
    [types.ERA_RENAISSANCE] = 200, [types.ERA_INDUSTRIAL] = 250, [types.ERA_MODERN] = 300,
    [types.ERA_POSTMODERN] = 350, [types.ERA_FUTURE] = 400,
}
local commissionClasses = {}
for building in GameInfo.Buildings() do
    local class = GameInfo.BuildingClasses[building.BuildingClass]
    if (tonumber(building.Cost) or -1) > 0 and building.IsDummy ~= true and building.IsDummy ~= 1
        and class and class.MaxGlobalInstances == -1 and class.MaxTeamInstances == -1
        and class.MaxPlayerInstances == -1 then
        commissionClasses[building.ID] = class.Type
    end
end

local function werribeePlayer(id)
    local player = Players[id]
    if player and player:GetCivilizationType() == civType then return player end
end

local function cityAt(x, y)
    if x < 0 or y < 0 then return end
    local plot = Map.GetPlot(x, y)
    return plot and plot:GetPlotCity()
end

local function cityKey(city)
    return table.concat({city:GetX(), city:GetY(), city:GetOriginalOwner(), city:GetGameTurnFounded()}, ".")
end

local function getCityState(key)
    local state = cityStates[key]
    if not state then
        local owner, peak, sale, vendor = tostring(data.GetValue(prefix .. "city." .. key) or "")
            :match("^(%-?%d+):(%d+):(%d+):(%d+)$")
        state = {
            owner = tonumber(owner), peak = tonumber(peak) or 0,
            sale = tonumber(sale) or 0, vendor = tonumber(vendor) or 0,
        }
        cityStates[key] = state
    end
    return state
end

local function saveCityState(key, state)
    data.SetValue(prefix .. "city." .. key, table.concat({state.owner, state.peak, state.sale, state.vendor}, ":"))
end

local function setBuilding(city, building, count)
    if city:GetNumRealBuilding(building) ~= count then
        city:SetNumRealBuilding(building, count)
    end
end

local function qualifyingTiles(city)
    local count = 0
    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
        local plot = Map.PlotDirection(city:GetX(), city:GetY(), direction)
        if plot and not plot:IsCity() and plot:GetOwner() == city:GetOwner()
            and plot:GetImprovementType() >= 0 and not plot:IsImprovementPillaged() then
            local workingCity = plot:GetWorkingCity()
            if workingCity and workingCity:GetOwner() == city:GetOwner()
                and workingCity:GetID() == city:GetID() and city:IsWorkingPlot(plot) then
                count = count + 1
            end
        end
    end
    return count
end

local function hasConsultant(city, excludedID)
    local plot = city:Plot()
    for index = 0, plot:GetNumUnits() - 1 do
        local unit = plot:GetUnit(index)
        if unit and unit:GetOwner() == city:GetOwner() and unit:GetUnitType() == consultant
            and unit:GetID() ~= excludedID and not unit:IsDelayedDeath() and not unit:IsDead() then
            return true
        end
    end
    return false
end

local function refreshPropertyTiles(city, excludedID)
    local count = qualifyingTiles(city)
    local appraisal = hasConsultant(city, excludedID)
    setBuilding(city, dummy.PRIME_REAL_ESTATE, count)
    setBuilding(city, dummy.APPRAISAL_YIELD, appraisal and count or 0)
    setBuilding(city, dummy.APPRAISAL_MODIFIER, appraisal and 1 or 0)
end

local function refreshConnection(player, city)
    local connected = not city:IsCapital() and player:IsCapitalConnectedToCity(city)
    local metropolis = connected and city:GetPopulation() >= 10
    setBuilding(city, dummy.CONNECTED_SUBURB, connected and not metropolis and 1 or 0)
    setBuilding(city, dummy.CONNECTED_METROPOLIS, metropolis and 1 or 0)
end

local function refreshOffice(city)
    local hasOffice = city:GetNumBuilding(office) > 0
    setBuilding(city, dummy.HOUSING_DEMAND, hasOffice and math.floor(city:GetPopulation() / 3) or 0)
    local boom = hasOffice and not city:IsResistance() and not city:IsForcedAvoidGrowth()
        and not city:IsFoodProduction() and city:FoodDifferenceTimes100() > 0
    setBuilding(city, dummy.PROPERTY_BOOM, boom and 1 or 0)
end

local function refreshTimed(city, key, state, turn)
    local sale = state.sale > turn
    local vendor = state.vendor > turn
    if (not sale and state.sale > 0) or (not vendor and state.vendor > 0) then
        state.sale = sale and state.sale or 0
        state.vendor = vendor and state.vendor or 0
        saveCityState(key, state)
    end
    setBuilding(city, dummy.PROPERTY_SALE, sale and 1 or 0)
    setBuilding(city, dummy.VENDOR_NETWORK, vendor and 1 or 0)
end

local function reconcileCity(player, city, turn, transferred)
    local key = cityKey(city)
    local state = getCityState(key)
    if transferred or state.owner ~= city:GetOwner() or city:GetPopulation() > state.peak then
        if transferred or state.owner ~= city:GetOwner() then
            state.sale, state.vendor = 0, 0
        end
        state.owner = city:GetOwner()
        state.peak = math.max(state.peak, city:GetPopulation())
        saveCityState(key, state)
    end
    if player then
        refreshPropertyTiles(city)
        refreshConnection(player, city)
        refreshOffice(city)
        refreshTimed(city, key, state, turn)
    else
        for _, building in pairs(dummy) do setBuilding(city, building, 0) end
    end
end

local function notify(player, city, kind, gold, duration)
    if player:IsHuman() then
        player:AddNotification(NotificationTypes.NOTIFICATION_GENERIC,
            Locale.ConvertTextKey("TXT_KEY_WERRIBEE_" .. kind .. "_BODY", city:GetName(), gold, duration),
            Locale.ConvertTextKey("TXT_KEY_WERRIBEE_" .. kind .. "_TITLE"), city:GetX(), city:GetY())
    end
end

local function processPopulation(x, y, oldPopulation, newPopulation)
    if newPopulation == 0 then return end
    local city = cityAt(x, y)
    if not city then return end
    local player = werribeePlayer(city:GetOwner())
    if not player then return end
    local key = cityKey(city)
    local state = getCityState(key)
    -- Founding and acquisition call SetPopulation before registering the destination.
    if state.owner ~= city:GetOwner() then return end

    if newPopulation > math.max(oldPopulation, state.peak) then
        local first = math.max(oldPopulation, state.peak) + 1
        local hasOffice = city:GetNumBuilding(office) > 0
        local era = eraPercent[player:GetCurrentEra()] or 100
        local turn = Game.GetGameTurn()
        state.peak = newPopulation
        saveCityState(key, state)
        for population = first, newPopulation do
            if hasOffice then
                player:ChangeGold(math.floor(5 * population * rewardPercent / 100))
            end
            if Game.Rand(100, "Werribee Property Sale") < 25 then
                local gold = math.floor(10 * population * era * rewardPercent / 10000)
                player:ChangeGold(gold)
                state.sale = turn + saleDuration
                notify(player, city, "SALE", gold, saleDuration)
            end
        end
        saveCityState(key, state)
        refreshTimed(city, key, state, turn)
    end
    refreshPropertyTiles(city)
    refreshConnection(player, city)
    refreshOffice(city)
end

local function processConstruction(owner, cityID, building, gold, faith)
    local player = werribeePlayer(owner)
    if not player then return end
    local city = player:GetCityByID(cityID)
    if not city then return end
    local key = cityKey(city)
    -- Free start-era buildings emit the same flags as Production, before PlayerCityFounded.
    if getCityState(key).owner ~= owner then return end

    local class = commissionClasses[building]
    if gold == false and faith == false and class and city:GetNumRealBuilding(building) > 0 then
        local commissionKey = prefix .. "commission." .. key .. "." .. class
        if not data.GetValue(commissionKey) then
            local cost = city:GetBuildingProductionNeeded(building)
            data.SetValue(commissionKey, 1)
            player:ChangeGold(math.floor(cost / 5))
        end
    end
    refreshOffice(city)
    refreshConnection(player, city)
end

local function unitKey(owner, unitID)
    return prefix .. "consultant." .. owner .. "." .. unitID
end

local function registerOrigin(player, unit, x, y)
    local city = cityAt(x, y)
    local owner = unit:GetOwner()
    if not city or city:GetOwner() ~= owner then
        city = nil
        local nearestDistance
        for candidate in player:Cities() do
            local distance = Map.PlotDistance(x, y, candidate:GetX(), candidate:GetY())
            if not nearestDistance or distance < nearestDistance
                or (distance == nearestDistance and candidate:GetID() < city:GetID()) then
                city, nearestDistance = candidate, distance
            end
        end
    end
    local origin = city and cityKey(city) or ""
    data.SetValue(unitKey(owner, unit:GetID()), unit:GetGameTurnCreated() .. ":" .. origin)
end

local function trackConsultant(unit, x, y)
    local owner, unitID = unit:GetOwner(), unit:GetID()
    local city = cityAt(x, y)
    local locations = consultantPlots[owner]
    if not locations then
        locations = {}
        consultantPlots[owner] = locations
    end
    local previous = locations[unitID]
    locations[unitID] = {x = x, y = y}
    if previous and (previous.x ~= x or previous.y ~= y) then
        local oldCity = cityAt(previous.x, previous.y)
        if oldCity and oldCity:GetOwner() == owner then
            refreshPropertyTiles(oldCity, unitID)
        end
    end
    if city and city:GetOwner() == owner then refreshPropertyTiles(city) end
end

local function processTradeMission(owner, unitID, unitType, x, y)
    if unitType ~= consultant then return end
    local player = werribeePlayer(owner)
    if not player then return end
    local unit = player:GetUnitByID(unitID)
    local plot = Map.GetPlot(x, y)
    local minor = plot and Players[plot:GetOwner()]
    -- CP invokes GreatPersonExpended after the trade pays out. The cloned Merchant's
    -- other expend action is a build, and its Customs House cannot be built on this plot.
    if not unit or unit:GetUnitType() ~= consultant or not minor or not minor:IsMinorCiv()
        or unit:GetX() ~= x or unit:GetY() ~= y or unit:GetBuildType() >= 0
        or minor:GetTeam() == player:GetTeam() or not unit:CanTrade(plot, 0) then return end

    local key = unitKey(owner, unitID)
    local born, origin = tostring(data.GetValue(key) or ""):match("^(%d+):(.*)$")
    if tonumber(born) ~= unit:GetGameTurnCreated() or origin == "paid" then return end
    data.SetValue(key, born .. ":paid")

    local ox, oy = origin:match("^(%d+)%.(%d+)%.")
    local city = ox and cityAt(tonumber(ox), tonumber(oy))
    if not city or city:GetOwner() ~= owner or cityKey(city) ~= origin then
        city = player:GetCapitalCity()
    end
    if not city then return end

    local gold = 25 * city:GetPopulation()
    player:ChangeGold(gold)
    local cityStateKey = cityKey(city)
    local state = getCityState(cityStateKey)
    local turn = Game.GetGameTurn()
    state.vendor = turn + vendorDuration
    saveCityState(cityStateKey, state)
    refreshTimed(city, cityStateKey, state, turn)
    notify(player, city, "MISSION", gold, vendorDuration)
end

GameEvents.PlayerCityFounded.Add(function(owner, x, y)
    local player = werribeePlayer(owner)
    local city = player and cityAt(x, y)
    if city then reconcileCity(player, city, Game.GetGameTurn(), true) end
end)

GameEvents.CityCaptureComplete.Add(function(oldOwner, _, x, y, newOwner)
    local player = werribeePlayer(newOwner)
    if not player and not werribeePlayer(oldOwner) then return end
    local city = cityAt(x, y)
    if city and city:GetOwner() == newOwner then
        reconcileCity(player, city, Game.GetGameTurn(), true)
    end
end)

GameEvents.SetPopulation.Add(processPopulation)
GameEvents.CityConstructed.Add(processConstruction)
GameEvents.CitySoldBuilding.Add(function(owner, cityID, building)
    if building ~= office then return end
    local player = werribeePlayer(owner)
    local city = player and player:GetCityByID(cityID)
    if city then refreshOffice(city) end
end)

GameEvents.UnitCreated.Add(function(owner, unitID, unitType, x, y)
    if unitType ~= consultant then return end
    local player = werribeePlayer(owner)
    local unit = player and player:GetUnitByID(unitID)
    if not unit then return end
    registerOrigin(player, unit, x, y)
    trackConsultant(unit, x, y)
end)

GameEvents.UnitConverted.Add(function(oldOwner, owner, oldID, unitID)
    local player = werribeePlayer(owner)
    local unit = player and player:GetUnitByID(unitID)
    if not unit or unit:GetUnitType() ~= consultant then return end
    -- The DLL copies the old creation turn after UnitCreated and before UnitConverted.
    local old = oldOwner == owner and player:GetUnitByID(oldID)
    local _, origin
    if old and old:GetUnitType() == consultant then
        _, origin = tostring(data.GetValue(unitKey(owner, oldID)) or ""):match("^(%d+):(.*)$")
    end
    if origin then
        data.SetValue(unitKey(owner, unitID), unit:GetGameTurnCreated() .. ":" .. origin)
    else
        registerOrigin(player, unit, unit:GetX(), unit:GetY())
    end
    trackConsultant(unit, unit:GetX(), unit:GetY())
end)

GameEvents.UnitSetXY.Add(function(owner, unitID, x, y)
    local player = werribeePlayer(owner)
    local unit = player and player:GetUnitByID(unitID)
    if unit and unit:GetUnitType() == consultant then
        trackConsultant(unit, x, y)
    end
end)

GameEvents.UnitPrekill.Add(function(owner, unitID, unitType, x, y)
    if unitType ~= consultant or not werribeePlayer(owner) then return end
    local locations = consultantPlots[owner]
    if locations then locations[unitID] = nil end
    local city = cityAt(x, y)
    if city and city:GetOwner() == owner then refreshPropertyTiles(city, unitID) end
    data.SetValue(unitKey(owner, unitID), "")
end)

GameEvents.GreatPersonExpended.Add(processTradeMission)

GameEvents.TileImprovementChanged.Add(function(x, y, owner)
    if not werribeePlayer(owner) then return end
    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetWorkingCity()
    if city and city:GetOwner() == owner then
        refreshPropertyTiles(city)
        refreshOffice(city)
    end
end)

GameEvents.CapitalChanged.Add(function(owner)
    local player = werribeePlayer(owner)
    if not player then return end
    for city in player:Cities() do refreshConnection(player, city) end
end)

GameEvents.PlayerDoTurn.Add(function(owner)
    local player = werribeePlayer(owner)
    if not player then return end
    local turn = Game.GetGameTurn()
    for city in player:Cities() do reconcileCity(player, city, turn) end
end)

GameEvents.PlayerDoneTurn.Add(function(owner)
    local player = werribeePlayer(owner)
    if not player then return end
    local turn = Game.GetGameTurn()
    for city in player:Cities() do
        reconcileCity(player, city, turn)
        -- City Production runs before PlayerDoTurn. Remove effects that expire before that tick.
        local key = cityKey(city)
        local state = getCityState(key)
        refreshTimed(city, key, state, turn + 1)
    end
end)

local reconciled = false
Events.SequenceGameInitComplete.Add(function()
    if reconciled then return end
    reconciled = true
    local turn = Game.GetGameTurn()
    for owner = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local player = werribeePlayer(owner)
        if player and player:IsAlive() then
            for city in player:Cities() do reconcileCity(player, city, turn) end
            for unit in player:Units() do
                if unit:GetUnitType() == consultant and not unit:IsDelayedDeath() and not unit:IsDead() then
                    local saved = tostring(data.GetValue(unitKey(owner, unit:GetID())) or "")
                    if tonumber(saved:match("^(%d+):")) ~= unit:GetGameTurnCreated() then
                        -- An older save without an origin can only fall back to the current capital.
                        data.SetValue(unitKey(owner, unit:GetID()), unit:GetGameTurnCreated() .. ":")
                    end
                    trackConsultant(unit, unit:GetX(), unit:GetY())
                end
            end
        end
    end
end)
