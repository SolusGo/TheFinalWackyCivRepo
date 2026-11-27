local script = arg and arg[1] or "Civilizations/WerribeePropertyNetwork/Lua/WerribeePropertyNetwork.lua"
local civilization = 1
local consultant = 2
local office = 3
local granary = 4
local wonder = 5
local function expect(actual, expected, description)
    assert(actual == expected, description .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

GameInfoTypes = {
    CIVILIZATION_WERRIBEE_PROPERTY_NETWORK = civilization,
    UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT = consultant,
    BUILDING_WERRIBEE_REAL_ESTATE_OFFICE = office,
    ERA_ANCIENT = 0, ERA_CLASSICAL = 1, ERA_MEDIEVAL = 2, ERA_RENAISSANCE = 3,
    ERA_INDUSTRIAL = 4, ERA_MODERN = 5, ERA_POSTMODERN = 6, ERA_FUTURE = 7,
}
local dummy = {}
for i, name in ipairs({
    "PRIME_REAL_ESTATE", "PROPERTY_SALE", "CONNECTED_SUBURB", "CONNECTED_METROPOLIS",
    "APPRAISAL_YIELD", "APPRAISAL_MODIFIER", "VENDOR_NETWORK", "HOUSING_DEMAND", "PROPERTY_BOOM",
}) do
    dummy[name] = 10 + i
    GameInfoTypes["BUILDING_WERRIBEE_DUMMY_" .. name] = dummy[name]
end
local speed, turn, rolls = 0, 0, 0
Game = {
    GetGameSpeedType = function() return speed end,
    GetGameTurn = function() return turn end,
    Rand = function(maximum)
        expect(maximum, 100, "synchronized roll range")
        rolls = rolls + 1
        return 0
    end,
}
GameInfo = {
    GameSpeeds = {[0] = {Type = "GAMESPEED_MARATHON", GrowthPercent = 300}},
    BuildingClasses = {
        MARKET = {Type = "MARKET", MaxGlobalInstances = -1, MaxTeamInstances = -1, MaxPlayerInstances = -1},
        GRANARY = {Type = "GRANARY", MaxGlobalInstances = -1, MaxTeamInstances = -1, MaxPlayerInstances = -1},
        WONDER = {Type = "WONDER", MaxGlobalInstances = 1, MaxTeamInstances = -1, MaxPlayerInstances = -1},
    },
    Buildings = function()
        local buildings = {
            {ID = office, Cost = 100, BuildingClass = "MARKET"},
            {ID = granary, Cost = 60, BuildingClass = "GRANARY"},
            {ID = wonder, Cost = 180, BuildingClass = "WONDER"},
        }
        local i = 0
        return function()
            i = i + 1
            return buildings[i]
        end
    end,
}

local function events()
    return setmetatable({}, {__index = function(self, name)
        local callbacks = {}
        local event = setmetatable({
            Add = function(callback) callbacks[#callbacks + 1] = callback end,
        }, {__call = function(_, ...)
            for _, callback in ipairs(callbacks) do callback(...) end
        end})
        self[name] = event
        return event
    end})
end

local saved = {}
Modding = {OpenSaveData = function()
    return {
        GetValue = function(key) return saved[key] end,
        SetValue = function(key, value) saved[key] = value end,
    }
end}
NotificationTypes = {NOTIFICATION_GENERIC = 1}
Locale = {ConvertTextKey = function(key) return key end}
GameDefines = {MAX_MAJOR_CIVS = 34}
DirectionTypes = {NUM_DIRECTION_TYPES = 6}

local playerMethods = {}
function playerMethods:GetCivilizationType() return self.civ end
function playerMethods:GetCurrentEra() return self.era end
function playerMethods:IsHuman() return self.human end
function playerMethods:IsAlive() return true end
function playerMethods:IsMinorCiv() return self.minor end
function playerMethods:GetTeam() return self.team end
function playerMethods:GetCapitalCity() return self.capital end
function playerMethods:GetCityByID(id) return self.cities[id] end
function playerMethods:GetUnitByID(id) return self.units[id] end
function playerMethods:IsCapitalConnectedToCity(city) return city.connected end
function playerMethods:Cities() return coroutine.wrap(function()
    for _, city in pairs(self.cities) do coroutine.yield(city) end
end) end
function playerMethods:Units() return coroutine.wrap(function()
    for _, unit in pairs(self.units) do coroutine.yield(unit) end
end) end
function playerMethods:ChangeGold(delta) self.gold = self.gold + delta end
function playerMethods:AddNotification() self.notices = self.notices + 1 end
local function player(civ, team, human, minor)
    return setmetatable({
        civ = civ, era = 2, team = team, human = human, minor = minor, cities = {}, units = {}, gold = 0, notices = 0,
    }, {__index = playerMethods})
end
local human, ai, minor, outsider = player(civilization, 0, true), player(civilization, 1, false),
    player(0, 34, false, true), player(0, 3, false)
Players = {[0] = human, [1] = ai, [3] = outsider, [34] = minor}

local cityMethods = {}
function cityMethods:GetX() return self.x end
function cityMethods:GetY() return 0 end
function cityMethods:GetOwner() return self.owner end
function cityMethods:GetOriginalOwner() return self.original end
function cityMethods:GetGameTurnFounded() return 0 end
function cityMethods:GetID() return self.id end
function cityMethods:GetName() return "Werribee" end
function cityMethods:GetPopulation() return self.population end
function cityMethods:IsCapital() return self == Players[self.owner].capital end
function cityMethods:IsResistance() return self.resistance end
function cityMethods:IsForcedAvoidGrowth() return self.avoid end
function cityMethods:IsFoodProduction() return self.foodProduction end
function cityMethods:FoodDifferenceTimes100() return self.food end
function cityMethods:GetNumRealBuilding(id) return self.buildings[id] or 0 end
function cityMethods:GetNumBuilding(id) return self:GetNumRealBuilding(id) end
function cityMethods:SetNumRealBuilding(id, count) self.buildings[id] = count end
function cityMethods:IsWorkingPlot(plot) return plot.worked end
function cityMethods:Plot() return self.plot end
function cityMethods:GetBuildingProductionNeeded(id) return id == granary and 183 or 300 end

local plots = {}
local plotMethods = {}
function plotMethods:GetOwner() return self.city and self.city.owner or self.owner end
function plotMethods:GetPlotCity() return self.city end
function plotMethods:GetWorkingCity() return self.workingCity end
function plotMethods:IsCity() return self.city ~= nil end
function plotMethods:GetImprovementType() return self.improvement end
function plotMethods:IsImprovementPillaged() return self.pillaged end
function plotMethods:GetNumUnits() return #self.units end
function plotMethods:GetUnit(index) return self.units[index + 1] end
local function newPlot(x, owner)
    local plot = setmetatable({owner = owner, improvement = -1, units = {}}, {__index = plotMethods})
    plots[x] = plot
    return plot
end
local function newCity(id, x, owner, population)
    local city = setmetatable({
        id = id, x = x, owner = owner, original = owner, population = population, buildings = {}, food = 1,
        plot = newPlot(x, owner),
    }, {__index = cityMethods})
    city.plot.city = city
    Players[owner].cities[id] = city
    return city
end
Map = {
    GetPlot = function(x) return plots[x] end,
    PlotDirection = function(x, _, direction) return direction == 0 and plots[x + 1] or nil end,
    PlotDistance = function(x, _, cx) return math.abs(x - cx) end,
}

local unitMethods = {}
function unitMethods:GetOwner() return self.owner end
function unitMethods:GetUnitType() return consultant end
function unitMethods:GetID() return self.id end
function unitMethods:GetGameTurnCreated() return self.created end
function unitMethods:GetX() return self.x end
function unitMethods:GetY() return 0 end
function unitMethods:GetBuildType() return self.build or -1 end
function unitMethods:IsDelayedDeath() return self.dead end
function unitMethods:IsDead() return self.dead end
function unitMethods:CanTrade(plot, testVisible)
    expect(testVisible, 0, "native CanTrade numeric argument")
    return plot:GetOwner() == 34 and not self.tradeBlocked
end
local function newUnit(owner, id, x)
    local unit = setmetatable({owner = owner, id = id, created = turn, x = x}, {__index = unitMethods})
    Players[owner].units[id] = unit
    table.insert(plots[x].units, unit)
    GameEvents.UnitCreated(owner, id, consultant, x, 0)
    return unit
end
local function move(unit, x)
    local units = plots[unit.x].units
    for i, candidate in ipairs(units) do
        if candidate == unit then table.remove(units, i); break end
    end
    unit.x = x
    table.insert(plots[x].units, unit)
    GameEvents.UnitSetXY(unit.owner, unit.id, x, 0)
end
local function loadGame()
    GameEvents, Events = events(), events()
    WerribeePropertyNetworkLoaded = nil
    dofile(script)
    dofile(script)
    Events.SequenceGameInitComplete()
end
local function grow(city, population)
    local old = city.population
    city.population = population
    GameEvents.SetPopulation(city.x, 0, old, population)
end
local function effect(city, name, count)
    expect(city:GetNumRealBuilding(dummy[name]), count, name)
end

loadGame()
local capital = newCity(8, 0, 0, 0)
human.capital = capital
grow(capital, 1)
capital.buildings[granary] = 1
GameEvents.CityConstructed(0, 8, granary, false, false)
GameEvents.PlayerCityFounded(0, 0, 0)
expect(human.gold, 0, "founding population and free start-era building")
expect(rolls, 0, "founding draws no RNG")

local farm = newPlot(1, 0)
farm.improvement, farm.workingCity, farm.worked = 0, capital, true
GameEvents.TileImprovementChanged(1, 0, 0)
effect(capital, "PRIME_REAL_ESTATE", 1)
farm.pillaged = true
GameEvents.TileImprovementChanged(1, 0, 0)
effect(capital, "PRIME_REAL_ESTATE", 0)
farm.pillaged, farm.worked = false, false
GameEvents.PlayerDoneTurn(0)
effect(capital, "PRIME_REAL_ESTATE", 0)
farm.worked = true

capital.buildings[office] = 1
GameEvents.CityConstructed(0, 8, office, true, false)
GameEvents.CityConstructed(0, 8, office, false, true)
capital.buildings[wonder] = 1
GameEvents.CityConstructed(0, 8, wonder, false, false)
GameEvents.CityConstructed(0, 8, dummy.PROPERTY_BOOM, false, false)
expect(human.gold, 0, "purchases, wonders and dummy buildings")
effect(capital, "PROPERTY_BOOM", 1)
capital.avoid = true
GameEvents.PlayerDoneTurn(0)
effect(capital, "PROPERTY_BOOM", 0)

capital.buildings[granary] = 0
GameEvents.CityConstructed(0, 8, granary, false, false)
capital.buildings[granary] = 1
GameEvents.CityConstructed(0, 8, granary, false, false)
GameEvents.CityConstructed(0, 8, granary, false, false)
expect(human.gold, 36, "commission uses full 183 Production and pays once")
turn = 2
grow(capital, 3)
effect(capital, "HOUSING_DEMAND", 1)
effect(capital, "PROPERTY_SALE", 1)
expect(human.gold, 236, "multi-population Marathon sales and settlements")
expect(rolls, 2, "one roll per new threshold")
loadGame()
grow(capital, 1)
grow(capital, 3)
expect(rolls, 2, "reload and regrowth do not roll")
expect(human.gold, 236, "reload and regrowth do not pay")

local suburb = newCity(9, 3, 0, 9)
GameEvents.PlayerCityFounded(0, 3, 0)
suburb.connected = true
GameEvents.PlayerDoTurn(0)
effect(suburb, "CONNECTED_SUBURB", 1)
grow(suburb, 10)
effect(suburb, "CONNECTED_SUBURB", 0)
effect(suburb, "CONNECTED_METROPOLIS", 1)
suburb.connected = false
GameEvents.PlayerDoTurn(0)
effect(suburb, "CONNECTED_METROPOLIS", 0)

newPlot(2, 34)
local first = newUnit(0, 4, 0)
local second = newUnit(0, 5, 0)
effect(capital, "APPRAISAL_YIELD", 1)
effect(capital, "APPRAISAL_MODIFIER", 1)
move(first, 2)
effect(capital, "APPRAISAL_MODIFIER", 1)
GameEvents.UnitPrekill(0, 5, consultant, 0, 0, true, -1)
second.dead = true
effect(capital, "APPRAISAL_MODIFIER", 0)

local baseline = human.gold
first.build = 7
GameEvents.GreatPersonExpended(0, 4, consultant, 2, 0)
expect(human.gold, baseline, "build expenditure cannot pay for a trade mission")
first.build = nil
first.tradeBlocked = true
GameEvents.GreatPersonExpended(0, 4, consultant, 2, 0)
expect(human.gold, baseline, "invalid trade location cannot pay")
first.tradeBlocked = false
loadGame()
GameEvents.GreatPersonExpended(0, 4, consultant, 2, 0)
GameEvents.GreatPersonExpended(0, 4, consultant, 2, 0)
expect(human.gold, baseline + 75, "confirmed Trade Mission pays exactly once for original city")
effect(capital, "VENDOR_NETWORK", 1)
loadGame()
effect(capital, "VENDOR_NETWORK", 1)

turn = 16
GameEvents.PlayerDoneTurn(0)
effect(capital, "PROPERTY_SALE", 0)
effect(capital, "VENDOR_NETWORK", 1)
turn = 31
GameEvents.PlayerDoneTurn(0)
effect(capital, "VENDOR_NETWORK", 0)

human.cities[8], outsider.cities[44], capital.owner, capital.id = nil, capital, 3, 44
GameEvents.CityCaptureComplete(0, true, 0, 0, 3, 3, true)
effect(capital, "HOUSING_DEMAND", 0)
effect(capital, "PRIME_REAL_ESTATE", 0)
grow(capital, 4)
outsider.cities[44], human.cities[46], capital.owner, capital.id = nil, capital, 0, 46
GameEvents.CityCaptureComplete(3, false, 0, 0, 0, 4, true)
expect(human.gold, baseline + 75, "recapture grants no retroactive Gold")
GameEvents.CityConstructed(0, 46, granary, false, false)
expect(human.gold, baseline + 75, "commission history survives changing city IDs")
effect(capital, "HOUSING_DEMAND", 1)

local aiCity = newCity(1, 10, 1, 2)
ai.capital = aiCity
GameEvents.PlayerCityFounded(1, 10, 0)
grow(aiCity, 3)
expect(ai.gold, 90, "a second Werribee player receives AI benefits")
expect(ai.notices, 0, "AI does not receive human notifications")
local gift = newUnit(1, 90, 10)
gift.created = 7
GameEvents.UnitConverted(0, 1, 4, 90)
move(gift, 2)
GameEvents.GreatPersonExpended(1, 90, consultant, 2, 0)
expect(ai.gold, 165, "converted consultant tracks the copied creation turn and new owner")
expect(ai.notices, 0, "AI missions do not create human notifications")
print("Werribee Lua callback, reward, expiry, and save/load simulations passed.")
