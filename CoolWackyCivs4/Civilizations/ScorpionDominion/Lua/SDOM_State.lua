SCORPION_DOMINION = {}
local council = SCORPION_DOMINION
local data = Modding.OpenSaveData()
local prefix = "CoolWackyCivs4.SDOM.1."
local states = {}

-- A single saved value per player keeps the roster, cooldown and memorial in sync.
-- Escape arbitrary unit names without evaluating save data as Lua.
local function encode(value)
    return (tostring(value):gsub("[%%|\r\n]", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function decode(line)
    local fields = {}
    for field in (line .. "|"):gmatch("(.-)|") do
        fields[#fields + 1] = field:gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
    end
    return fields
end

function council.state(owner)
    if states[owner] then return states[owner] end
    local state = { ready=0, serial=0, lifetime=0, roster={}, hall={} }
    for line in tostring(data.GetValue(prefix .. owner) or ""):gmatch("[^\n]+") do
        local f = decode(line)
        if f[1] == "player" then
            state.ready = tonumber(f[2]) or 0
            state.serial = tonumber(f[3]) or 0
            state.lifetime = tonumber(f[4]) or 0
        elseif f[1] == "unit" or f[1] == "hall" then
            local record = {
                id=tonumber(f[2]), born=tonumber(f[3]), serial=tonumber(f[4]),
                designated=tonumber(f[5]), name=f[6], kind=tonumber(f[7]),
                xp=tonumber(f[8]), branch=tonumber(f[9]), stage=tonumber(f[10]),
                removed=tonumber(f[11]), reason=f[12],
            }
            if record.id and record.serial and record.born and record.designated
                and record.kind and record.xp and record.branch and record.stage then
                state.serial = math.max(state.serial, record.serial)
                if f[1] == "unit" then
                    state.roster[record.id] = record
                elseif record.removed and #state.hall < 200 then
                    state.hall[#state.hall + 1] = record
                end
            end
        end
    end
    states[owner] = state
    return state
end

function council.save(owner)
    local state = council.state(owner)
    local lines = {table.concat({"player", state.ready, state.serial, state.lifetime}, "|")}
    local function append(category, record)
        lines[#lines + 1] = table.concat({
            category, record.id, record.born, record.serial, record.designated,
            encode(record.name), record.kind, record.xp, record.branch, record.stage,
            record.removed or "", record.reason or "",
        }, "|")
    end
    for _, record in pairs(state.roster) do append("unit", record) end
    for _, record in ipairs(state.hall) do append("hall", record) end
    data.SetValue(prefix .. owner, table.concat(lines, "\n"))
end

function council.record(unit, state, designated)
    state.serial = state.serial + 1
    local id = unit:GetID()
    local record = {
        id=id, born=unit:GetGameTurnCreated(), serial=state.serial, designated=designated,
    }
    state.roster[id] = record
    return record
end
