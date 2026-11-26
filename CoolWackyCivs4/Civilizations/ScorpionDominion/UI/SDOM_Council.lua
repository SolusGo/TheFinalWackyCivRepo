include("IconSupport")
include("InstanceManager")
include("SDOM_State")
local council = SCORPION_DOMINION
local required = {
    EVENTS_UNIT_CREATED=true, EVENTS_UNIT_CONVERTS=true, EVENTS_UNIT_PREKILL=true,
    EVENTS_UNIT_CAPTURE=true, EVENTS_CITY=true, EVENTS_CITY_CAPITAL=true, EVENTS_NEW_ERA=true,
}
local ok = pcall(function()
    for row in DB.Query("SELECT Name FROM CustomModOptions WHERE Value = 1") do
        required[row.Name] = nil
    end
end)
if not ok or next(required) or not GameInfoTypes.CIVILIZATION_SCORPION_DOMINION then
    print("SDOM: Required standalone Community Patch v151 options are missing. War Council disabled.")
    return
end
include("SDOM_Rules")

local text = council.text
local rows = InstanceManager:new("SDOM_CouncilRow", "Root", Controls.List)
local tabs = {"ROSTER", "DESIGNATION", "EVOLUTION", "HALL"}
local atlas = "SDOM_MUTATION_ATLAS"
local badgeKeys = {"ASCENDANT", "PINCERS", "CARAPACE", "APEX", "EXOSKELETON"}
local shown, dirty, tab = false, true, 1
local selection, confirmation, failure

function council.dirty() dirty = true end
include("SDOM_Events")

local function kindName(id)
    local row = GameInfo.Units[id]
    return row and Locale.ConvertTextKey(row.Description) or text("UNKNOWN_UNIT")
end

local function branchName(branch)
    return text(({[0]="NO_BRANCH", "PINCERS", "CARAPACE"})[branch])
end

local function title(stage, branch)
    if stage == 3 then return text(branch == 1 and "DESTROYER" or "GUARDIAN") end
    return stage == 2 and branchName(branch) or text("ASCENDANT")
end

local function nextStage(stage, xp)
    if stage == 1 then return text("NEXT_BRANCH", math.min(xp, 30)) end
    if stage == 2 then return text("NEXT_APEX", math.min(xp, 100)) end
    return text("COMPLETE_APEX")
end

local function mark(control, index, size)
    IconHookup(index, size, atlas, control)
end

local function portrait(control, id)
    local unit = GameInfo.Units[id]
    if not unit or not IconHookup(unit.PortraitIndex, 48, unit.IconAtlas, control) then mark(control, 0, 48) end
end

local function setConfirmation(value)
    confirmation = value
    Controls.Confirm:SetHide(not value)
    if value then
        Controls.ConfirmTitle:SetText(text(value.title))
        Controls.ConfirmBody:SetText(value.body)
    end
end

local function close()
    shown, selection, failure = false, nil, nil
    setConfirmation(nil)
    Controls.Panel:SetHide(true)
end

local function details(unit)
    local stage, branch = council.stage(unit), council.branch(unit)
    Controls.DetailBody:SetText(text("UNIT_DETAIL", title(stage, branch), stage,
        unit:GetCurrHitPoints(), unit:GetMaxHitPoints(), unit:GetExperience(), branchName(branch),
        nextStage(stage, unit:GetExperience())))
    for index, key in ipairs(badgeKeys) do
        local control = Controls["Badge" .. index]
        local promo = council.promotions[index] or GameInfoTypes.PROMOTION_SDOM_EXOSKELETON
        control:SetHide(not unit:IsHasPromotion(promo))
        mark(control, index - 1, 32)
        control:SetToolTipString(text(key .. "_HELP"))
    end
    Controls.Locate:RegisterCallback(Mouse.eLClick, function()
        local player = council.active()
        local current = player and council.resolve(player, selection)
        if current and current:GetPlot() and current:GetPlot():IsRevealed(player:GetTeam()) then
            UI.LookAt(current:GetPlot())
            close()
        end
    end)
    Controls.Evolve:RegisterCallback(Mouse.eLClick, function() tab = 3; dirty = true end)
end

local function tree(player, unit)
    Controls.DetailBody:SetText("")
    local stage, branch = council.stage(unit), council.branch(unit)
    local locked = council.canSpecialise(player, unit)
    local function node(index, status, content)
        local key = badgeKeys[index]
        Controls["TreeName" .. index]:SetText(text(key) .. "  ·  " .. text(status))
        Controls["TreeBody" .. index]:SetText(content)
    end
    node(1, "COMPLETED", text("ASCENDANT_HELP"))
    for index = 1, 2 do
        local key = badgeKeys[index + 1]
        local button = index == 1 and Controls.Pincers or Controls.Carapace
        local status = branch == index and "COMPLETED" or branch ~= 0 and "EXCLUDED"
            or locked and "LOCKED" or "AVAILABLE"
        node(index + 1, status, text(key .. "_BRIEF") .. "[NEWLINE]"
            .. (branch == 0 and text("REQ_BRANCH", math.min(30, unit:GetExperience())) or text("PERMANENT")))
        button:SetHide(branch ~= 0)
        button:SetDisabled(locked ~= nil)
        button:SetToolTipString(text(locked or "BRANCH_WARNING"))
        button:RegisterCallback(Mouse.eLClick, function()
            if council.canSpecialise(player, unit) then return end
            setConfirmation({title=key, body=text("CONFIRM_BRANCH", unit:GetName(), text(key)),
                token=council.token(unit), branch=index})
        end)
    end
    node(4, stage == 3 and "COMPLETED" or "LOCKED", text("APEX_BRIEF") ..
        "[NEWLINE]" .. (stage == 3 and title(stage, branch) or text("REQ_APEX", math.min(100, unit:GetExperience()))))
end

local function render()
    dirty = false
    local player = council.active()
    Controls.Launcher:SetHide(not player)
    if not player then close(); return end
    if not shown then return end

    local ascendants = council.roster(player)
    local occupied, maxSlots, apex = #ascendants, council.capacity(player), 0
    local cost, remaining = council.cost(player), council.remaining(player)
    local cooldown = remaining == 0 and text("READY") or text("TURNS", remaining)
    local selected
    for _, unit in ipairs(ascendants) do
        if council.stage(unit) == 3 then apex = apex + 1 end
        if selection and selection.serial and council.token(unit).serial == selection.serial then selected = unit end
    end
    selected = selected or ascendants[1]
    selection = selected and council.token(selected)
    Controls.Treasury:SetText(text("TREASURY", player:GetGold(), cost, cooldown))
    Controls.Capacity:SetText(text(occupied > maxSlots and "OVER_CAPACITY" or "CAPACITY", occupied, maxSlots))
    Controls.Science:SetText(text("SCIENCE", apex, council.activeScience(player)))
    for index, key in ipairs(tabs) do
        Controls["Tab" .. index]:SetText(text("TAB_" .. key))
        Controls["Tab" .. index]:SetDisabled(index == tab)
    end
    Controls.Tree:SetHide(tab ~= 3 or not selected)
    Controls.UnitDetail:SetHide(tab ~= 1 or not selected)

    local state = council.state(player:GetID())
    local scroll = Controls.Scroll:GetScrollValue()
    rows:ResetInstances()
    if tab == 4 then
        mark(Controls.DetailIcon, 6, 48)
        Controls.DetailTitle:SetText(text("TAB_HALL"))
        Controls.DetailType:SetText(text("HALL_TOTAL", state.lifetime))
        Controls.DetailBody:SetText(text("HALL_DETAIL", #state.hall, math.max(0, state.lifetime - #state.hall)))
        for _, record in ipairs(state.hall) do
            local row = rows:GetInstance()
            portrait(row.Icon, record.kind)
            row.Name:SetText(record.name)
            row.Summary:SetText(text("HALL_ROW", kindName(record.kind), record.stage, record.xp, branchName(record.branch)))
            row.Progress:SetText(text("HALL_DATES",
                record.designated >= 0 and tostring(record.designated) or text("UNKNOWN_TURN"),
                record.removed, text(record.reason)))
            row.Action:SetHide(true)
        end
    elseif tab == 2 then
        mark(Controls.DetailIcon, 5, 48)
        Controls.DetailTitle:SetText(text("TAB_DESIGNATION"))
        Controls.DetailType:SetText(text("DESIGNATION_PRICE", cost))
        Controls.DetailBody:SetText(text("DESIGNATION_DETAIL"))
        local reason = council.designationStatus(player, occupied, maxSlots)
        for unit in player:Units() do
            if council.eligible(unit) and not council.ascendant(unit) then
                local row = rows:GetInstance()
                local token, name = council.token(unit), unit:GetName()
                portrait(row.Icon, unit:GetUnitType())
                row.Name:SetText(name)
                row.Summary:SetText(text("CANDIDATE_ROW", kindName(unit:GetUnitType()),
                    unit:GetCurrHitPoints(), unit:GetMaxHitPoints(), unit:GetExperience(), cost))
                row.Progress:SetText(text(reason or "AVAILABLE"))
                row.Action:SetText(text("DESIGNATE"))
                row.Action:SetHide(false)
                row.Action:SetDisabled(reason ~= nil)
                row.Action:SetToolTipString(text(reason or "DESIGNATE_TIP", cost))
                row.Action:RegisterCallback(Mouse.eLClick, function()
                    setConfirmation({title="NOTICE_ASCENDANT", body=text("CONFIRM_DESIGNATION", name, cost),
                        token=token, cost=cost})
                end)
            end
        end
    else
        for _, unit in ipairs(ascendants) do
            local row = rows:GetInstance()
            local token = council.token(unit)
            local stage, branch = council.stage(unit), council.branch(unit)
            mark(row.Icon, stage == 3 and 3 or branch, 48)
            row.Icon:SetToolTipString(text(badgeKeys[(stage == 3 and 3 or branch) + 1] .. "_HELP"))
            row.Name:SetText(unit:GetName())
            row.Summary:SetText(text("ROSTER_ROW", kindName(unit:GetUnitType()), title(stage, branch),
                unit:GetCurrHitPoints(), unit:GetMaxHitPoints(), unit:GetExperience()))
            row.Progress:SetText(text("ROSTER_PROGRESS", stage, nextStage(stage, unit:GetExperience())))
            row.Action:SetText(text("INSPECT"))
            row.Action:SetHide(false)
            row.Action:SetDisabled(selected == unit)
            row.Action:SetToolTipString(text("INSPECT"))
            row.Action:RegisterCallback(Mouse.eLClick, function() selection = token; dirty = true end)
        end
        if selected then
            portrait(Controls.DetailIcon, selected:GetUnitType())
            Controls.DetailTitle:SetText(selected:GetName())
            Controls.DetailType:SetText(kindName(selected:GetUnitType()))
            if tab == 1 then details(selected) else tree(player, selected) end
        else
            mark(Controls.DetailIcon, 0, 48)
            Controls.DetailTitle:SetText(text("EMPTY_ROSTER"))
            Controls.DetailType:SetText("")
            Controls.DetailBody:SetText(text("EMPTY_DETAIL"))
        end
    end
    Controls.List:CalculateSize()
    Controls.List:ReprocessAnchoring()
    Controls.Scroll:CalculateInternalSize()
    Controls.Scroll:SetScrollValue(scroll)
    Controls.Footer:SetText(failure and text(failure) or text(({ "ROSTER_FOOT", "DESIGNATION_FOOT", "TREE_FOOT", "HALL_FOOT" })[tab]))
end

local function open()
    if not council.active() then return end
    shown, failure = true, nil
    Controls.Panel:SetHide(false)
    render()
end

Controls.Title:SetText(text("TITLE"))
Controls.Motto:SetText(text("MOTTO"))
mark(Controls.Insignia, 5, 48)
for index = 1, 4 do mark(Controls["TreeArt" .. index], index - 1, 32) end
for index = 1, #tabs do
    Controls["Tab" .. index]:RegisterCallback(Mouse.eLClick, function()
        tab, failure = index, nil
        Controls.Scroll:SetScrollValue(0)
        render()
    end)
end
Controls.Launcher:RegisterCallback(Mouse.eLClick, open)
Controls.Close:RegisterCallback(Mouse.eLClick, close)
Controls.Cancel:RegisterCallback(Mouse.eLClick, function() setConfirmation(nil) end)
Controls.Accept:RegisterCallback(Mouse.eLClick, function()
    local request = confirmation
    if not request or not shown then return end
    setConfirmation(nil)
    if request.branch then failure = council.specialise(request.token, request.branch)
    else failure = council.designate(request.token, request.cost) end
    if not failure and request.cost then tab = 1; selection = nil end
    render()
end)

LuaEvents.AdditionalInformationDropdownGatherEntries.Add(function(entries)
    if council.active() then
        entries[#entries + 1] = {text=text("TITLE"), tip="TXT_KEY_SDOM_TRAIT_HELP", call=open}
    end
end)
ContextPtr:SetInputHandler(function(message, key)
    if shown and message == KeyEvents.KeyDown and key == Keys.VK_ESCAPE then
        if confirmation then setConfirmation(nil) else close() end
        return true
    end
end)
ContextPtr:SetUpdate(function() if dirty then render() end end)
Events.SerialEventGameDataDirty.Add(function() if shown then council.dirty() end end)
Events.SerialEventUnitInfoDirty.Add(function() if shown then council.dirty() end end)
Events.ActivePlayerTurnStart.Add(council.dirty)
Events.ActivePlayerTurnEnd.Add(close)
Events.GameplaySetActivePlayer.Add(function() close(); council.dirty() end)
Events.LoadScreenClose.Add(function()
    council.dirty()
    LuaEvents.RequestRefreshAdditionalInformationDropdownEntries()
end)
