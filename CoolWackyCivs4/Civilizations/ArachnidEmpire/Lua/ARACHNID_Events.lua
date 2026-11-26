local brood = ARACHNID
local poison = GameInfoTypes.PROMOTION_ARACHNID_POISON
local attackerRole, defenderRole = 0, 1
local melee, ranged, air = 0, 1, 2
local battle, generating
local generated = {}
local created = {}

local function clearCombat()
    battle = nil
end

GameEvents.BattleStarted.Add(function(kind, x, y)
    generating = nil
    if not brood.active() then return end
    generating = {kind=kind, x=x, y=y, roles={}, members={}, pending={}, rewarded={}}
    -- Defensive fire support can generate a second battle before the first resolves.
    if #generated == 8 then table.remove(generated, 1) end
    generated[#generated + 1] = generating
end)

local function recordMember(transaction, owner, id, role, isCity)
    local member = {owner=owner, id=id, city=isCity}
    if role < 3 then transaction.roles[role] = member end
    if not isCity then transaction.members[owner .. ":" .. id] = true end
    if isCity or (role ~= attackerRole and role ~= defenderRole) then return end
    local unit = brood.liveUnit(owner, id)
    if not unit then return end
    member.damage, member.born = unit:GetDamage(), unit:GetGameTurnCreated()
    if brood.eligible(Players[owner]) and brood.specialization(unit) == 2 then
        member.venom = brood.evolved(brood.state(owner), 5) and 10 or 5
    end
end

GameEvents.BattleJoined.Add(function(owner, id, role, isCity)
    if generating then recordMember(generating, owner, id, role, isCity) end
end)

GameEvents.CombatResult.Add(function(attacker, attackerID, damageToAttacker, _, _,
    defender, defenderID, damageToDefender, _, _, interceptor, interceptorID, interceptionDamage, x, y)
    clearCombat()
    for index = #generated, 1, -1 do
        local candidate = generated[index]
        if candidate.x == x and candidate.y == y then
            battle = table.remove(generated, index)
            break
        end
    end
    generating = nil
    if not battle or battle.kind > 3 then return end
    battle.sources = {}
    local function confirm(role, owner, id, damage)
        if owner and owner >= 0 and id and id >= 0 and brood.liveUnit(owner, id) then
            local member = battle.roles[role]
            if not member or member.city or member.owner ~= owner or member.id ~= id then
                recordMember(battle, owner, id, role, false)
            end
        end
        local joined = battle.roles[role]
        if joined and ((joined.owner == owner and (joined.city or joined.id == id))
            or (joined.city and (owner == nil or owner < 0))) then
            battle.sources[joined.owner] = true
            joined.damageDealt = damage
        end
    end
    confirm(attackerRole, attacker, attackerID, damageToDefender)
    confirm(defenderRole, defender, defenderID, damageToAttacker)
    confirm(2, interceptor, interceptorID)
    if battle.kind == air and (interceptionDamage or 0) > 0 then
        local attackerUnit = battle.roles[attackerRole]
        if attackerUnit and not attackerUnit.city and attackerUnit.owner == attacker and attackerUnit.id == attackerID then
            -- CP aborts the strike and zeroes both principals' damage on a successful
            -- interception, but reports lethal damage under the intended target's owner.
            local interceptorUnit = battle.roles[2]
            local creditedOwner
            if damageToAttacker == 0 and damageToDefender == 0 and interceptorUnit and not interceptorUnit.city
                and interceptorUnit.owner == interceptor and interceptorUnit.id == interceptorID
                and brood.liveUnit(interceptor, interceptorID) then
                creditedOwner = interceptor
            end
            battle.interception = {victim=attacker .. ":" .. attackerID, nativeKiller=defender, owner=creditedOwner}
        end
    end
    if battle.kind == ranged and attacker == -1 and attackerID == -1
        and defender and defender >= 0 and defenderID and defenderID >= 0 and (damageToDefender or 0) > 0 then
        battle.cityTarget = defender .. ":" .. defenderID
    end
end)

GameEvents.UnitPrekill.Add(function(owner, id, kind, _, _, delayed, killer)
    brood.clearPoison(owner, id)
    if brood.eligible(Players[owner]) then brood.dirty() end

    if not battle or not battle.sources or not delayed then return end
    local identity = owner .. ":" .. id
    local beneficiary = killer
    local interception = battle.interception
    if interception and interception.victim == identity then
        if killer ~= interception.nativeKiller or interception.owner == nil then return end
        beneficiary = interception.owner
    elseif not (battle.sources[killer] or battle.cityTarget == identity) then
        return
    end
    local player, victim = Players[beneficiary], Players[owner]
    if not brood.eligible(player) or not brood.hostile(player, victim) then return end
    local unit = victim:GetUnitByID(id)
    -- Delayed death is the first callback for damage-driven death. The immediate
    -- callback, voluntary removals, gifting and upgrade cleanup cannot qualify.
    if battle.members[identity] and not battle.rewarded[identity]
        and brood.military(unit) and unit:IsDead() and not unit:IsDelayedDeath() then
        local key = killer .. ":" .. owner .. ":" .. kind
        -- setDamage confirms synchronously; ambiguous matches fail closed.
        local pending = battle.pending[key]
        if pending == nil then battle.pending[key] = {identity=identity, beneficiary=beneficiary}
        elseif pending and pending.identity ~= identity then battle.pending[key] = false end
    end
end)

GameEvents.UnitKilledInCombat.Add(function(killer, owner, kind)
    if not battle then return end
    local key = killer .. ":" .. owner .. ":" .. kind
    local confirmed = battle.pending[key]
    battle.pending[key] = nil
    if not confirmed or battle.rewarded[confirmed.identity] then return end
    local player = Players[confirmed.beneficiary]
    if not brood.eligible(player) then return end
    battle.rewarded[confirmed.identity] = true
    brood.reward(player, Players[owner]:IsBarbarian())
    brood.dirty()
end)

local function envenom(source, target)
    if not source or not target or not source.venom or (source.damageDealt or 0) <= 0 or target.city then return end
    local player = Players[source.owner]
    if not brood.hostile(player, Players[target.owner]) then return end
    local unit = brood.liveUnit(target.owner, target.id)
    if not target.damage or not brood.military(unit) or unit:GetGameTurnCreated() ~= target.born
        or unit:GetDamage() <= target.damage then return end

    local pending = brood.poisonFor(target.owner)
    local effect = pending[target.id]
    local damage = source.venom
    if effect and effect.born == target.born then damage = math.max(damage, effect.damage) end
    pending[target.id] = {born=target.born, damage=damage}
    unit:SetHasPromotion(poison, true)
    brood.savePoison(target.owner)

    local state = brood.state(source.owner)
    if state.firstPoison == 0 then
        state.firstPoison = 1
        brood.save(source.owner)
        brood.notify(player, "NOTICE_POISON")
    end
end

GameEvents.BattleFinished.Add(function()
    local completed = battle
    clearCombat()
    if not completed or not completed.sources then return end
    local attacker, defender = completed.roles[attackerRole], completed.roles[defenderRole]
    if completed.kind == ranged or completed.kind == melee then envenom(attacker, defender) end
    if completed.kind == melee then envenom(defender, attacker) end
end)
GameEvents.CombatEnded.Add(clearCombat)
-- UnitCreated precedes the city-state gift's promotion/name copy.
GameEvents.UnitCreated.Add(function(owner, id)
    if brood.active() then
        brood.clearPoison(owner, id)
        created[owner .. ":" .. id] = {owner=owner, id=id}
    end
end)

function brood.retainBirth(unit)
    local entry = created[unit:GetOwner() .. ":" .. unit:GetID()]
    if entry then entry.retain = true end
end

GameEvents.GameCoreUpdateEnd.Add(function()
    clearCombat()
    if #generated > 0 then generated = {} end
    generating = nil
    if not next(created) then return end
    local queue = created
    created = {}
    for _, entry in pairs(queue) do
        local unit = brood.liveUnit(entry.owner, entry.id)
        if unit then
            local player = Players[entry.owner]
            if not entry.retain or not brood.eligible(player) then
                brood.stripBiology(unit)
            end
            local pending = brood.poisonFor(entry.owner)[entry.id]
            if unit:IsHasPromotion(poison) and (not pending or pending.born ~= unit:GetGameTurnCreated()) then
                unit:SetHasPromotion(poison, false)
            end
        end
    end
end)

local function tickPoison(owner)
    local pending = brood.poisonFor(owner)
    if not next(pending) then return end
    for id, effect in pairs(pending) do
        local unit = brood.liveUnit(owner, id)
        pending[id] = nil
        if unit and unit:GetGameTurnCreated() == effect.born and unit:IsHasPromotion(poison) then
            unit:SetHasPromotion(poison, false)
            local current = unit:GetDamage()
            local capped = math.min(current + effect.damage, unit:GetMaxHitPoints() - 1)
            if capped > current then unit:SetDamage(capped) end
        end
    end
    brood.savePoison(owner)
end

GameEvents.UnitConverted.Add(function(oldOwner, newOwner, oldID, newID, upgrade)
    brood.clearPoison(oldOwner, oldID)
    local oldPlayer, newPlayer = Players[oldOwner], Players[newOwner]
    local unit = newPlayer and newPlayer:GetUnitByID(newID)
    if not unit then return end
    if unit:IsHasPromotion(poison) then unit:SetHasPromotion(poison, false) end

    local oldUnit = oldPlayer and oldPlayer:GetUnitByID(oldID)
    local variant = oldUnit and brood.specialization(oldUnit)
    if upgrade and oldOwner == newOwner and brood.eligible(newPlayer) and variant then
        brood.applyBiology(unit, variant, brood.state(newOwner))
        brood.retainBirth(unit)
        brood.stripBiology(oldUnit)
    elseif variant or brood.specialization(unit) or unit:IsHasPromotion(GameInfoTypes.PROMOTION_ARACHNID_APEX)
        or unit:IsHasPromotion(GameInfoTypes.PROMOTION_ARACHNID_REGENERATION) then
        -- Gifts, captures and other conversions permanently sterilize the result.
        brood.stripBiology(unit)
    end
    if brood.eligible(oldPlayer) or brood.eligible(newPlayer) then brood.dirty() end
end)

GameEvents.PlayerDoTurn.Add(function(owner)
    tickPoison(owner)
    if brood.eligible(Players[owner]) then
        brood.payTurn(Players[owner])
        brood.dirty()
    end
end)

GameEvents.PlayerCityFounded.Add(function(owner)
    local player = Players[owner]
    if brood.eligible(player) then
        brood.updateLair(player)
        brood.dirty()
    end
end)

GameEvents.CityCaptureComplete.Add(function(oldOwner, _, x, y, newOwner)
    local old, new = Players[oldOwner], Players[newOwner]
    local plot = Map.GetPlot(x, y)
    brood.syncCity(plot and plot:GetPlotCity())
    if not brood.eligible(old) and not brood.eligible(new) then return end
    if brood.eligible(old) then brood.updateLair(old) end
    if brood.eligible(new) then
        brood.updateLair(new)
        brood.checkFirstEvolution(new)
    end
    brood.dirty()
end)

local function buildingChanged(owner, cityID)
    local player = Players[owner]
    if brood.eligible(player) then
        brood.syncCity(player:GetCityByID(cityID))
        brood.dirty()
    end
end
GameEvents.CityConstructed.Add(buildingChanged)
GameEvents.CitySoldBuilding.Add(buildingChanged)

GameEvents.CityCanConstruct.Add(function(_, _, building)
    return building ~= GameInfoTypes.BUILDING_ARACHNID_CHAMBER_SCIENCE
end)

GameEvents.TeamSetEra.Add(function(team)
    local player = brood.active()
    if player and player:GetTeam() == team then
        brood.checkFirstEvolution(player)
        brood.dirty()
    end
end)

local reconciled = false
local function initialize()
    local player = brood.active()
    if not player then return end
    if not reconciled then
        reconciled = true
        for owner, other in pairs(Players) do
            if other:IsAlive() then
                local pending = brood.poisonFor(owner)
                for unit in other:Units() do
                    local effect = pending[unit:GetID()]
                    if unit:IsHasPromotion(poison) and (not effect or effect.born ~= unit:GetGameTurnCreated()) then
                        unit:SetHasPromotion(poison, false)
                    end
                    if not brood.eligible(other) and (brood.specialization(unit)
                        or unit:IsHasPromotion(GameInfoTypes.PROMOTION_ARACHNID_APEX)
                        or unit:IsHasPromotion(GameInfoTypes.PROMOTION_ARACHNID_REGENERATION)) then
                        brood.stripBiology(unit)
                    end
                end
            end
        end
    end
    brood.updateLair(player)
    brood.syncCities(player)
    local state = brood.state(player:GetID())
    for _, entry in ipairs(brood.swarm(player)) do brood.applyBiology(entry.unit, entry.variant, state) end
    brood.checkFirstEvolution(player)
    brood.dirty()
end
Events.SequenceGameInitComplete.Add(initialize)
Events.LoadScreenClose.Add(initialize)
