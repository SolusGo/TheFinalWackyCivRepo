local council = SCORPION_DOMINION
local promotions = council.promotions
local imperial = GameInfoTypes.PROMOTION_SDOM_EXOSKELETON
local owners, cityChanges = {}, {}
local pending, created = {}, {}
local combat = {}
local initialized, hasDominion = false, false

local function identity(owner, id)
    return owner .. ":" .. id
end

local function combatKey(killer, owner, kind)
    return killer .. ":" .. owner .. ":" .. kind
end

local function retire(player, record, reason, silent)
    local owner = player:GetID()
    local state = council.state(owner)
    if state.roster[record.id] ~= record then return end
    state.roster[record.id] = nil
    record.reason, record.removed = reason, Game.GetGameTurn()
    table.insert(state.hall, 1, record)
    if #state.hall > 200 then table.remove(state.hall) end
    state.lifetime = state.lifetime + 1
    council.save(owner)
    cityChanges[owner] = true
    council.dirty()
    if not silent and (reason == "REASON_COMBAT" or reason == "REASON_FALLEN")
        and council.isHuman(player) then council.notify(player, "NOTICE_FALLEN") end
end

-- This pass is limited to the Ascendant identities. Full roster sanitation is
-- reserved for loading and the owning player's turn.
local function track(player, silent)
    local owner = player:GetID()
    local state = council.state(owner)
    local changed = false
    for id, record in pairs(state.roster) do
        local unit = player:GetUnitByID(id)
        if not council.ascendant(unit) or unit:GetGameTurnCreated() ~= record.born then
            local removal = pending[identity(owner, id)]
            retire(player, record, removal and removal.reason or "REASON_REMOVED", silent)
            pending[identity(owner, id)] = nil
        elseif not council.isHuman(player) then
            council.strip(unit)
            retire(player, record, "REASON_CONTROL", true)
        else
            if council.apex(player, unit, silent) then cityChanges[owner] = true end
            changed = council.snapshot(record, unit) or changed
        end
    end
    if changed then council.save(owner); council.dirty() end
    if cityChanges[owner] then
        cityChanges[owner] = nil
        council.syncScience(player)
        council.dirty()
    end
end

local function reconcile(player, silent)
    local owner = player:GetID()
    local state = council.state(owner)
    local changed = false
    track(player, silent)
    for unit in player:Units() do
        if council.isHuman(player) and council.ascendant(unit) then
            local id = unit:GetID()
            local record = state.roster[id]
            -- Promotions survive saves and are authoritative for stage. A unit
            -- carrying an untracked designation can only be recovered on load.
            if not record and silent then
                record = council.record(unit, state, -1)
                changed = council.snapshot(record, unit) or changed
            elseif not record then
                council.strip(unit)
            end
            if record then
                if unit:IsHasPromotion(promotions[2]) and unit:IsHasPromotion(promotions[3]) then
                    -- Inconsistent foreign state grants neither branch.
                    unit:SetHasPromotion(promotions[2], false)
                    unit:SetHasPromotion(promotions[3], false)
                    changed = true
                end
                if council.branch(unit) == 0 and unit:IsHasPromotion(promotions[4]) then
                    unit:SetHasPromotion(promotions[4], false)
                    changed = true
                end
            end
        else
            council.strip(unit)
        end
    end
    if changed then council.save(owner) end
    cityChanges[owner] = true
    track(player, silent)
end

GameEvents.UnitCreated.Add(function(owner, id)
    local player = Players[owner]
    local key = identity(owner, id)
    if council.isDominion(player) then
        owners[owner], hasDominion = true, true
        council.birth(owner, id)
        local record = council.state(owner).roster[id]
        if record then
            local removal = pending[key]
            retire(player, record, removal and removal.reason or "REASON_REMOVED")
            pending[key] = nil
        end
        council.dirty()
    end
    -- The city-state gift path copies promotions after UnitCreated.
    if hasDominion then created[key] = {owner=owner, id=id} end
end)

GameEvents.UnitConverted.Add(function(oldOwner, newOwner, oldID, newID, upgrade)
    local player, recipient = Players[oldOwner], Players[newOwner]
    local oldUnit = player and player:GetUnitByID(oldID)
    local newUnit = recipient and recipient:GetUnitByID(newID)
    if not oldUnit or not newUnit then return end
    local sameOwnerUpgrade = upgrade and oldOwner == newOwner
    if sameOwnerUpgrade and oldUnit:IsHasPromotion(imperial) then
        newUnit:SetHasPromotion(imperial, true)
    end
    if not council.isDominion(player) and not council.isDominion(recipient) then return end

    local record = council.isDominion(player) and council.state(oldOwner).roster[oldID]
    if record and record.born == oldUnit:GetGameTurnCreated() then
        council.snapshot(record, oldUnit)
        if sameOwnerUpgrade and council.isHuman(player) and council.ascendant(oldUnit)
            and council.eligible(newUnit) then
            local roster = council.state(oldOwner).roster
            roster[oldID] = nil
            roster[newID] = record
            record.id, record.born = newID, newUnit:GetGameTurnCreated()
            for _, promotion in ipairs(promotions) do
                newUnit:SetHasPromotion(promotion, oldUnit:IsHasPromotion(promotion))
            end
            council.strip(oldUnit)
            council.snapshot(record, newUnit)
            council.save(oldOwner)
        else
            council.strip(oldUnit)
            council.strip(newUnit)
            retire(player, record, oldOwner ~= newOwner and "REASON_TRANSFER" or "REASON_REMOVED")
        end
        pending[identity(oldOwner, oldID)] = nil
        cityChanges[oldOwner] = true
    else
        council.strip(newUnit)
    end
    council.dirty()
end)

GameEvents.UnitPrekill.Add(function(owner, id, kind, _, _, delayed, killer)
    if not owners[owner] then return end
    council.endBirth(owner, id)
    local player = Players[owner]
    local record = council.state(owner).roster[id]
    local unit = player:GetUnitByID(id)
    if not record or not unit or record.born ~= unit:GetGameTurnCreated() then return end
    council.snapshot(record, unit)
    local key = identity(owner, id)
    local event = pending[key] or {reason="REASON_REMOVED"}
    pending[key] = event
    if delayed and killer >= 0 and killer ~= owner and unit:IsDead() and not unit:IsDelayedDeath()
        and event.reason ~= "REASON_TRANSFER" and event.reason ~= "REASON_CAPTURE" then
        event.reason = "REASON_FALLEN"
        local tuple = combatKey(killer, owner, kind)
        local previous = combat[tuple]
        if previous == nil or previous == event then combat[tuple] = event else combat[tuple] = false end
    end
    cityChanges[owner] = true
end)

GameEvents.UnitKilledInCombat.Add(function(killer, owner, kind)
    if not owners[owner] then return end
    local key = combatKey(killer, owner, kind)
    local event = combat[key]
    if event and event.reason ~= "REASON_TRANSFER" and event.reason ~= "REASON_CAPTURE" then event.reason = "REASON_COMBAT" end
    combat[key] = nil
end)

GameEvents.UnitCaptured.Add(function(by, _, owner, id, willBeKilled)
    if not owners[owner] or by == owner or willBeKilled then return end
    if council.state(owner).roster[id] then
        pending[identity(owner, id)] = {reason="REASON_CAPTURE"}
    end
end)

GameEvents.GameCoreUpdateEnd.Add(function()
    if not initialized or not hasDominion then return end
    for _, entry in pairs(created) do
        local player = Players[entry.owner]
        local unit = player and player:GetUnitByID(entry.id)
        if council.live(unit) then
            local record = owners[entry.owner] and council.state(entry.owner).roster[entry.id]
            if not (record and record.born == unit:GetGameTurnCreated() and council.isHuman(player)) then
                council.strip(unit)
            end
        end
    end
    if next(created) then created = {} end
    if next(combat) then combat = {} end
    for owner in pairs(owners) do track(Players[owner]) end
end)

GameEvents.CityCanConstruct.Add(function(_, _, building)
    return not council.isScienceBuilding(building)
end)

local function cityChanged(owner)
    if owners[owner] then cityChanges[owner] = true end
end

GameEvents.CityCaptureComplete.Add(function(oldOwner, _, x, y, newOwner)
    if owners[oldOwner] or owners[newOwner] then
        local plot = Map.GetPlot(x, y)
        local city = plot and plot:GetPlotCity()
        if city then council.syncCity(city, 0) end
        cityChanged(oldOwner)
        cityChanged(newOwner)
    end
end)
GameEvents.CapitalChanged.Add(cityChanged)
GameEvents.CityRazed.Add(cityChanged)
GameEvents.PlayerCityFounded.Add(cityChanged)

local function chamberChanged(owner, _, building)
    if owners[owner] and building == council.chamber then council.dirty() end
end
GameEvents.CityConstructed.Add(chamberChanged)
GameEvents.CitySoldBuilding.Add(chamberChanged)

GameEvents.TeamSetEra.Add(function(team)
    for owner in pairs(owners) do
        if Players[owner]:GetTeam() == team then cityChanged(owner) end
    end
end)

GameEvents.PlayerDoTurn.Add(function(owner)
    if owners[owner] then reconcile(Players[owner], false) end
end)

local function initialize()
    if initialized then return end
    initialized = true
    for owner, player in pairs(Players) do
        if council.isDominion(player) then owners[owner], hasDominion = true, true end
    end
    if not hasDominion then return end
    for owner, player in pairs(Players) do
        if owners[owner] then
            reconcile(player, true)
        elseif player:IsAlive() then
            for unit in player:Units() do council.strip(unit) end
            for city in player:Cities() do council.syncCity(city, 0) end
        end
    end
end
Events.SequenceGameInitComplete.Add(initialize)
Events.LoadScreenClose.Add(initialize)
