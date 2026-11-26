-- One isolated InGameUIAddin owns both rules and presentation.
ARACHNID = {}
local brood = ARACHNID
local ids = GameInfoTypes

brood.text = function(key, ...)
    return Locale.ConvertTextKey("TXT_KEY_ARACHNID_" .. key, ...)
end

brood.variants = {
    {key="BROODLING", sp=45, cp=1, promotion=ids.PROMOTION_ARACHNID_BROODLING, icon=1},
    {key="VENOM", sp=65, cp=2, unlock=2, promotion=ids.PROMOTION_ARACHNID_VENOM, icon=2},
    {key="ARMOURED", sp=80, cp=2, unlock=3, promotion=ids.PROMOTION_ARACHNID_ARMOURED, icon=3},
}

local ancient, medieval, industrial = ids.ERA_ANCIENT, ids.ERA_MEDIEVAL, ids.ERA_INDUSTRIAL
brood.evolutions = {
    {key="INTELLIGENCE_I", cost=3, era=ancient, requires={}},
    {key="VENOM_GLANDS", cost=4, era=ancient, requires={}},
    {key="CHITIN_ARMOUR", cost=5, era=ancient, requires={}},
    {key="INTELLIGENCE_II", cost=6, era=medieval, requires={1}},
    {key="NEUROTOXIN", cost=6, era=medieval, requires={2}},
    {key="REGENERATION", cost=6, era=medieval, requires={3}},
    {key="APEX", cost=10, era=industrial, requires={4,5,6}},
}

function brood.eligible(player)
    return player and player:IsAlive() and player:IsHuman()
        and player:GetCivilizationType() == ids.CIVILIZATION_ARACHNID_EMPIRE
end

function brood.active()
    local player = Players[Game.GetActivePlayer()]
    if brood.eligible(player) then return player end
end

-- The unit's native promotion state is the identity and CP reservation. There is no
-- saved owner/ID roster to become stale after the engine reuses a unit ID.
function brood.specialization(unit)
    for index, variant in ipairs(brood.variants) do
        if unit:IsHasPromotion(variant.promotion) then return index end
    end
end

function brood.liveUnit(owner, id)
    local player = Players[owner]
    local unit = player and player:GetUnitByID(id)
    if unit and not unit:IsDelayedDeath() and not unit:IsDead() then return unit end
end

function brood.military(unit)
    return unit and (unit:IsCombatUnit() or unit:IsCanAttackRanged() or unit:CanNuke())
end

function brood.hostile(player, target)
    return target and target:GetID() ~= player:GetID()
        and Teams[player:GetTeam()]:IsAtWar(target:GetTeam())
end

function brood.notify(player, key, ...)
    player:AddNotification(NotificationTypes.NOTIFICATION_GENERIC,
        brood.text(key, ...), brood.text("TITLE"), -1, -1)
end

local data = Modding.OpenSaveData()
local prefix = "CoolWackyCivs4.ARACHNID."
local schema = tonumber(data.GetValue(prefix .. "schema"))
if schema and schema ~= 1 then
    print("ARACHNID: Unsupported save schema " .. schema)
    brood.incompatibleSave = true
    return
end

local states = {}
local fields = {
    "sp", "ep", "ready", "payout", "x", "y", "founded",
    "lair", "barbEra", "barbKills", "firstEvolution", "firstPoison", "evolved",
}
local defaults = {0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0}

function brood.state(owner)
    if not states[owner] then
        local state = {}
        local index = 0
        for number in tostring(data.GetValue(prefix .. "player." .. owner) or ""):gmatch("-?%d+") do
            index = index + 1
            if not fields[index] then break end
            state[fields[index]] = tonumber(number)
        end
        for i, field in ipairs(fields) do
            if state[field] == nil then state[field] = defaults[i] end
        end
        states[owner] = state
    end
    return states[owner]
end

local function write(key, value)
    if not schema then
        data.SetValue(prefix .. "schema", 1)
        schema = 1
    end
    data.SetValue(prefix .. key, value)
end

function brood.save(owner)
    local values = {}
    local state = brood.state(owner)
    for i, field in ipairs(fields) do values[i] = state[field] end
    write("player." .. owner, table.concat(values, ","))
end

function brood.evolved(state, index)
    return math.floor(state.evolved / 2 ^ (index - 1)) % 2 == 1
end

local poison = {}
function brood.poisonFor(owner)
    if not poison[owner] then
        local pending = {}
        local encoded = data.GetValue(prefix .. "poison." .. owner) or ""
        for id, born, damage in encoded:gmatch("(%d+):(-?%d+):(%d+)") do
            damage = tonumber(damage)
            if damage == 5 or damage == 10 then
                pending[tonumber(id)] = {born=tonumber(born), damage=damage}
            end
        end
        poison[owner] = pending
    end
    return poison[owner]
end

function brood.savePoison(owner)
    local values = {}
    for id, effect in pairs(brood.poisonFor(owner)) do
        values[#values + 1] = table.concat({id, effect.born, effect.damage}, ":")
    end
    table.sort(values)
    write("poison." .. owner, table.concat(values, ","))
end

function brood.clearPoison(owner, id)
    local pending = brood.poisonFor(owner)
    if pending[id] then
        pending[id] = nil
        brood.savePoison(owner)
    end
end
