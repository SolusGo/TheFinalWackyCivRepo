include("IconSupport")
include("InstanceManager")
include("ARACHNID_State")
local brood = ARACHNID
if brood.incompatibleSave then return end
if not brood.hooksReady() then
    print("ARACHNID: Standalone Community Patch v151 with the required gameplay hooks is missing or disabled. Console disabled.")
    return
end
include("ARACHNID_Rules")

local text = brood.text
local tabs = {Controls.SpawnTab, Controls.EvolutionTab, Controls.SwarmTab}
local views = {Controls.SpawnView, Controls.EvolutionView, Controls.SwarmView}
local rows = InstanceManager:new("ARACHNID_SwarmRow", "Root", Controls.SwarmStack)
local shown, tab, failure, dirty = false, 1, nil, true

function brood.dirty()
    dirty = true
end
include("ARACHNID_Events")

local function status(reason, detail)
    return detail and text(reason, detail) or text(reason)
end

local function unitTypeName(row)
    return row and Locale.ConvertTextKey(row.Description) or text("UNKNOWN_UNIT")
end

local function eraName(era)
    return Locale.ConvertTextKey(GameInfo.Eras[era].Description)
end

local function close()
    shown, failure = false, nil
    Controls.Panel:SetHide(true)
end

local function paintSwarm(player, swarm, occupied, state)
    rows:ResetInstances()
    table.sort(swarm, function(a,b) return a.unit:GetID() < b.unit:GetID() end)
    Controls.SwarmSummary:SetText(#swarm == 0 and text("EMPTY_SWARM")
        or text("SWARM_SUMMARY", #swarm, occupied, brood.capacity(state)))
    for _, entry in ipairs(swarm) do
        local unit, variant = entry.unit, brood.variants[entry.variant]
        local instance = rows:GetInstance()
        local owner, id, born = player:GetID(), unit:GetID(), unit:GetGameTurnCreated()
        IconHookup(variant.icon, 48, "ARACHNID_SPIDER_ATLAS", instance.Icon)
        local upgrades = {text(variant.key)}
        if unit:IsHasPromotion(GameInfoTypes.PROMOTION_ARACHNID_REGENERATION) then
            upgrades[#upgrades + 1] = text("REGENERATION")
        end
        if unit:IsHasPromotion(GameInfoTypes.PROMOTION_ARACHNID_APEX) then
            upgrades[#upgrades + 1] = text("APEX")
        end
        if unit:IsHasPromotion(GameInfoTypes.PROMOTION_ARACHNID_POISON) then
            upgrades[#upgrades + 1] = text("POISON")
        end
        instance.UnitName:SetText(unit:GetName())
        instance.UnitDetails:SetText(text("SWARM_ROW", unitTypeName(GameInfo.Units[unit:GetUnitType()]),
            variant.cp, table.concat(upgrades, ", ")))
        instance.Icon:SetToolTipString(text(variant.key .. "_EFFECT"))
        instance.Locate:RegisterCallback(Mouse.eLClick, function()
            local selected = brood.liveUnit(owner, id)
            if selected and selected:GetGameTurnCreated() == born and brood.specialization(selected) then
                close()
                UI.SelectUnit(selected)
                UI.LookAt(selected:GetPlot(), 0)
            end
        end)
    end
    Controls.SwarmStack:CalculateSize()
    Controls.SwarmStack:ReprocessAnchoring()
    Controls.SwarmScroll:CalculateInternalSize()
end

local function paint()
    dirty = false
    local player = brood.active()
    Controls.Launcher:SetHide(not player)
    if not player then close(); return end
    if not shown then return end

    local state = brood.state(player:GetID())
    local swarm, occupied = brood.swarm(player)
    local capital = brood.queen(player)
    local lair = capital and "LAIR_OWNED" or (state.x < 0 and "LAIR_UNFOUNDED" or "LAIR_LOST")
    Controls.Capital:SetText(text(lair))
    Controls.SpawnBalance:SetText(text("SP_BALANCE", state.sp, brood.income(player)))
    Controls.EvolutionBalance:SetText(text("EP_BALANCE", state.ep))
    Controls.ControlBalance:SetText(text("CP_BALANCE", occupied, brood.capacity(state)))
    Controls.Cooldown:SetText(text("NEXT_SPAWN", brood.remaining(state)))
    Controls.Era:SetText(eraName(player:GetCurrentEra()))
    Controls.Footer:SetText(failure or text(({"SPAWN_FOOTER", "EVOLUTION_FOOTER", "SWARM_FOOTER"})[tab]))
    for index, view in ipairs(views) do
        view:SetHide(index ~= tab)
        tabs[index]:SetDisabled(index == tab)
    end

    if tab == 1 then
        for index, variant in ipairs(brood.variants) do
            local reason, detail, cost, row = brood.spawnStatus(player, index, occupied)
            local unlock = variant.unlock and text(brood.evolutions[variant.unlock].key) or text("NO_PREREQUISITE")
            local effectKey = variant.key .. "_EFFECT"
            if index == 2 and brood.evolved(state, 5) then effectKey = "VENOM_UPGRADED" end
            if index == 3 and brood.evolved(state, 6) then effectKey = "ARMOURED_UPGRADED" end
            local effect = text(effectKey)
            Controls["SpawnEffect" .. index]:SetText(effect)
            Controls["SpawnBase" .. index]:SetText(text("SPAWN_BASE", unitTypeName(row), unlock))
            local action = Controls["SpawnAction" .. index]
            action:SetText(text("SPAWN_PRICE", cost, variant.cp))
            action:SetDisabled(reason ~= nil)
            action:SetToolTipString(effect)
            Controls["SpawnStatus" .. index]:SetText(reason and status(reason, detail) or text("AVAILABLE"))
        end
    elseif tab == 2 then
        for index, node in ipairs(brood.evolutions) do
            local reason, detail = brood.evolutionStatus(player, index)
            local effect = text(node.key .. "_EFFECT")
            local prerequisites = {}
            for _, required in ipairs(node.requires) do
                prerequisites[#prerequisites + 1] = text(brood.evolutions[required].key)
            end
            local requirement = #prerequisites == 0 and text("NO_PREREQUISITE") or table.concat(prerequisites, ", ")
            Controls["EvolutionCost" .. index]:SetText(text("EVOLUTION_COST", node.cost, eraName(node.era)))
            Controls["EvolutionRequires" .. index]:SetText(requirement)
            Controls["EvolutionIcon" .. index]:SetToolTipString(effect)
            local action = Controls["EvolutionAction" .. index]
            action:SetDisabled(reason ~= nil)
            action:SetText(not reason and text("EVOLVE") or text(reason == "EVOLVED" and "EVOLVED" or "LOCKED"))
            action:SetToolTipString((reason and status(reason, detail) .. "[NEWLINE]" or "") .. effect)
            Controls["EvolutionName" .. index]:SetToolTipString(effect)
        end
    else
        paintSwarm(player, swarm, occupied, state)
    end
end

local function open()
    if not brood.active() then return end
    shown, failure = true, nil
    Controls.Panel:SetHide(false)
    paint()
end

local function act(handler, index)
    if not shown then return end
    local reason, detail = handler(index)
    failure = reason and status(reason, detail)
    paint()
end

for index, variant in ipairs(brood.variants) do
    IconHookup(variant.icon, 80, "ARACHNID_SPIDER_ATLAS", Controls["SpawnIcon" .. index])
    Controls["SpawnName" .. index]:SetText(text(variant.key))
    Controls["SpawnAction" .. index]:RegisterCallback(Mouse.eLClick, function() act(brood.spawn, index) end)
end
for index, node in ipairs(brood.evolutions) do
    IconHookup(index - 1, 48, "ARACHNID_EVOLUTION_ATLAS", Controls["EvolutionIcon" .. index])
    Controls["EvolutionName" .. index]:SetText(text(node.key))
    Controls["EvolutionAction" .. index]:RegisterCallback(Mouse.eLClick, function() act(brood.evolve, index) end)
end
for index, button in ipairs(tabs) do
    button:RegisterCallback(Mouse.eLClick, function() tab, failure = index, nil; paint() end)
end

Controls.Title:SetText(text("TITLE"))
Controls.Launcher:SetToolTipString(text("TRAIT_HELP"))
IconHookup(0, 48, "ARACHNID_CIV_ATLAS", Controls.Crest)
IconHookup(1, 32, "ARACHNID_BROOD_ATLAS", Controls.SpawnResource)
IconHookup(2, 32, "ARACHNID_BROOD_ATLAS", Controls.EvolutionResource)
IconHookup(3, 32, "ARACHNID_BROOD_ATLAS", Controls.ControlResource)
Controls.SpawnResource:SetToolTipString(text("SP_HELP"))
Controls.EvolutionResource:SetToolTipString(text("EP_HELP"))
Controls.ControlResource:SetToolTipString(text("CP_HELP"))
Controls.Launcher:RegisterCallback(Mouse.eLClick, open)
Controls.Close:RegisterCallback(Mouse.eLClick, close)

LuaEvents.AdditionalInformationDropdownGatherEntries.Add(function(entries)
    if brood.active() then
        entries[#entries + 1] = {text=text("TITLE"), tip="TXT_KEY_ARACHNID_TRAIT_HELP", call=open}
    end
end)
ContextPtr:SetInputHandler(function(message, key)
    if shown and message == KeyEvents.KeyDown and key == Keys.VK_ESCAPE then close(); return true end
end)

-- Multiple simulation/UI callbacks in one frame coalesce into one refresh.
ContextPtr:SetUpdate(function()
    if dirty then paint() end
end)
Events.SerialEventGameDataDirty.Add(function()
    if shown then brood.dirty() end
end)
Events.SerialEventUnitInfoDirty.Add(function()
    if shown then brood.dirty() end
end)
Events.ActivePlayerTurnStart.Add(brood.dirty)
Events.ActivePlayerTurnEnd.Add(close)
Events.GameplaySetActivePlayer.Add(function() close(); brood.dirty() end)
Events.LoadScreenClose.Add(function()
    brood.dirty()
    LuaEvents.RequestRefreshAdditionalInformationDropdownEntries()
end)
paint()
