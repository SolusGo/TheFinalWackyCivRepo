local brood = ARACHNID
local poison = GameInfoTypes.PROMOTION_ARACHNID_POISON
local attackerRole, defenderRole = 0, 1
local melee, ranged = 0, 1
local battle, lethal

local function clearCombat()
    battle, lethal = nil, nil
end

GameEvents.BattleStarted.Add(function(kind, x, y)
    clearCombat()
    if brood.active() then
        battle = {kind=kind, x=x, y=y, roles={}, members={}, rewarded={}}
    end
end)

GameEvents.BattleJoined.Add(function(owner, id, role, isCity)
    if not battle then return end
    local member = {owner=owner, id=id, city=isCity}
    battle.roles[role] = member
    if not isCity then battle.members[owner .. ":" .. id] = true end
    if isCity or (role ~= attackerRole and role ~= defenderRole) then return end
    local unit = brood.liveUnit(owner, id)
    if not unit then return end
    member.damage, member.born = unit:GetDamage(), unit:GetGameTurnCreated()
    if brood.eligible(Players[owner]) and brood.specialization(unit) == 2 then
        member.venom = brood.evolved(brood.state(owner), 5) and 10 or 5
    end
end)

GameEvents.CombatResult.Add(function(attacker, _, _, _, _, defender, _, _, _, _, interceptor, _, _, x, y)
    if battle and battle.x == x and battle.y == y then
        battle.sources = {[attacker]=true, [defender]=true, [interceptor]=true}
    end
end)

GameEvents.UnitPrekill.Add(function(owner, id, kind, _, _, delayed, killer)
    brood.clearPoison(owner, id)
    if brood.eligible(Players[owner]) then brood.dirty() end

    lethal = nil
    local player, victim = Players[killer], Players[owner]
    if not battle or not battle.sources or not battle.sources[killer] or not delayed
        or not brood.eligible(player) or not brood.hostile(player, victim) then return end
    local unit = victim:GetUnitByID(id)
    -- Delayed death is the first callback for damage-driven death. The immediate
    -- callback, voluntary removals, gifting and upgrade cleanup cannot qualify.
    local identity = owner .. ":" .. id
    if battle.members[identity] and not battle.rewarded[identity]
        and brood.military(unit) and unit:IsDead() and not unit:IsDelayedDeath() then
        lethal = {killer=killer, owner=owner, kind=kind, identity=identity}
    end
end)

GameEvents.UnitKilledInCombat.Add(function(killer, owner, kind)
    if not lethal or lethal.killer ~= killer or lethal.owner ~= owner or lethal.kind ~= kind then return end
    battle.rewarded[lethal.identity] = true
    lethal = nil
    brood.reward(Players[killer], Players[owner]:IsBarbarian())
    brood.dirty()
end)

local function envenom(source, target)
    if not source or not target or not source.venom or target.city then return end
    local player = Players[source.owner]
    if not brood.hostile(player, Players[target.owner]) then return end
    local unit = brood.liveUnit(target.owner, target.id)
    if not brood.military(unit) or unit:GetGameTurnCreated() ~= target.born
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
GameEvents.GameCoreUpdateEnd.Add(clearCombat)

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
        brood.stripBiology(oldUnit)
    elseif variant or brood.specialization(unit) then
        -- Gifts, captures and other conversions permanently sterilize the result.
        if variant and not brood.specialization(unit)
            and unit:GetNameNoDesc() == brood.text(brood.variants[variant].key) then unit:SetName("") end
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
    if not brood.eligible(old) and not brood.eligible(new) then return end
    local plot = Map.GetPlot(x, y)
    brood.syncCity(plot and plot:GetPlotCity())
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

local function initialize()
    local player = brood.active()
    if not player then return end
    brood.updateLair(player)
    brood.syncCities(player)
    local state = brood.state(player:GetID())
    for _, entry in ipairs(brood.swarm(player)) do brood.applyBiology(entry.unit, entry.variant, state) end
    brood.checkFirstEvolution(player)
    brood.dirty()
end
Events.SequenceGameInitComplete.Add(initialize)
Events.LoadScreenClose.Add(initialize)
