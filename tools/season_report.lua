-- Cooling and setting times through the year, from forecasts read from the real game. It runs the mod's own
-- code (the ten-minute weather record, the hourly history, the pot's catch-up, the crock's ledger run), so it
-- doubles as a check that a change to that code keeps every number.
-- Run from the mod folder: luajit tools/season_report.lua [climate.csv]
-- Each line of the file: world month offset tempMin tempMean tempMax humMin humMean humMax rainy snowy
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
H.installClock(0)
H.installModData()
Events = { OnInitGlobalModData = { Add = function() end }, OnInitWorld = { Add = function() end },
    OnTick = { Add = function() end } }
dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
-- An open roof reads as indoors (the season's mean), so it gets no column of its own.
local PLACES = {}
for _, place in ipairs(M.PLACES) do
    if place ~= "Covered" then table.insert(PLACES, place) end
end
local STEPS_PER_HOUR = 6
local START_HOUR = 18   -- the evening milking, set overnight as it traditionally was
local POUR_C = 85
local GIVE_UP_HOURS = 72

local function readDays(path)
    local days = {}
    for line in io.lines(path) do
        local f = {}
        for value in line:gmatch("%S+") do table.insert(f, value) end
        -- Each month's forecast also holds the 10 days before it (offset below 0): skipped, so a month is 30 days.
        if #f >= 6 and tonumber(f[3]) >= 0 then
            table.insert(days, { world = tonumber(f[1]), offset = tonumber(f[3]), month = tonumber(f[2]), low = tonumber(f[4]), mean = tonumber(f[5]), high = tonumber(f[6]) })
        end
    end
    return days
end

-- The day's weather, coldest before dawn and warmest mid-afternoon.
local function temperatureAt(day, hour)
    local swing = math.cos((hour - 15) / 24 * 2 * math.pi)
    return swing >= 0 and day.mean + (day.high - day.mean) * swing or day.mean + (day.mean - day.low) * swing
end

-- The first sampled world's calendar year, settled (Weather.settledMeans).
local function settle(days)
    local year = {}
    for _, day in ipairs(days) do
        if day.world == days[1].world then table.insert(year, day) end
    end
    return require("TraditionalPreservationCore/Weather").settledMeans(year)
end

local days = readDays(arg[1] or "tools/climate_year.csv")
local ledger, history = M.getLedger(), M.getHistory()
-- The ledger starts as a long-running save's would on 1 January.
ledger.seasonTemperature, ledger.groundTemperature = settle(days)(days[1].month, days[1].offset)

-- Per month and place: a full 5 L pot and a 1 L pot with a starter, a 5 L pot with none (how long until
-- it is too cold for one), and a crock fed as soon as it asks. All start on the first of the month at
-- START_HOUR and are brought up to date every ten minutes, the same way an unloaded station catches up.
local runs = {}
local function startRuns(month)
    for _, place in ipairs(PLACES) do
        local function pot(kind, ml, starter)
            local batch = {}
            M.addMilk(batch, ml, POUR_C, H.hours)
            batch.starter = starter
            table.insert(runs, { kind = kind, place = place, month = month, start = H.hours, batch = batch })
        end
        pot("full", 5000, "Yogurt")
        pot("small", 1000, "Yogurt")
        pot("bare", 5000, nil)
        local crock = {}
        M.startCrock(crock, ledger)
        table.insert(runs, { kind = "crock", place = place, month = month, start = H.hours, batch = crock })
    end
end

local results = {}
local function result(run)
    local key = run.month .. run.place .. run.kind
    results[key] = results[key] or {}
    return results[key]
end

local function updatePot(run)
    local batch = run.batch
    local was = M.stage(batch)
    M.catchUp(batch, H.hours, run.place, history, ledger)
    local now, r = M.stage(batch), result(run)
    local since = H.hours - run.start
    if batch.wrapHour then r.wrap = batch.wrapHour - run.start end
    if was == "Cooling" and now == "TooCold" then r.cold = since end
    if now == "Ready" and not r.ready then
        r.ready = batch.readyHour - run.start
        r.milkC = batch.tempC
        run.finished = true
    end
    if since >= GIVE_UP_HOURS then run.finished = true end
end

local function updateCrock(run)
    local crock = run.batch
    M.updateCrock(crock, ledger, run.place)
    if crock.stage == "Waiting" then
        result(run).cultivated = H.hours - run.start
        M.feedCrock(crock, ledger)
    elseif crock.stage == "Ready" then
        result(run).ready = H.hours - run.start
        run.finished = true
    end
end

local started = {}
for _, day in ipairs(days) do
    for hour = 0, 23 do
        if hour == START_HOUR and not started[day.month] then
            started[day.month] = true
            startRuns(day.month)
        end
        for step = 1, STEPS_PER_HOUR do
            H.setHours(H.hours + 1 / STEPS_PER_HOUR)
            M.record(ledger, history, H.hours, temperatureAt(day, hour + step / STEPS_PER_HOUR))
            for _, run in ipairs(runs) do
                if not run.finished then
                    if run.kind == "crock" then updateCrock(run) else updatePot(run) end
                end
            end
        end
    end
end

local function hoursText(value)
    return value and string.format("%.1f", value) or "-"
end

local function get(month, place, kind, field)
    local r = results[month .. place .. kind]
    return r and r[field]
end

print(string.format("Yogurt Incubator: 5 L poured at %d C at %02d:00 on the first of the month, starter in.", POUR_C, START_HOUR))
print(string.format("Hours to cool to %d C (wrap on), then hours to set (%g h at the best temperature), and the", M.SET_C, M.INCUBATE_HOURS))
print(string.format("milk's temperature when it set. '-' means it hadn't set after %d hours.", GIVE_UP_HOURS))
print("")
print("| Month | Outdoors: cool / set / C | Indoors | Basement | By a fire | By banked embers |")
print("|---|---|---|---|---|---|")
for month = 1, 12 do
    local cells = {}
    for _, place in ipairs(PLACES) do
        local wrap, ready = get(month, place, "full", "wrap"), get(month, place, "full", "ready")
        local milkC = get(month, place, "full", "milkC")
        table.insert(cells, string.format("%s / %s / %s", hoursText(wrap), hoursText(ready and wrap and ready - wrap),
            milkC and string.format("%.0f", milkC) or "-"))
    end
    print(string.format("| %s | %s |", MONTHS[month], table.concat(cells, " | ")))
end

print("")
print("Same, 1 L: total hours from pouring to set")
print("| Month | Outdoors | Indoors | Basement | By a fire | By banked embers |")
print("|---|---|---|---|---|---|")
for month = 1, 12 do
    local cells = {}
    for _, place in ipairs(PLACES) do table.insert(cells, hoursText(get(month, place, "small", "ready"))) end
    print(string.format("| %s | %s |", MONTHS[month], table.concat(cells, " | ")))
end

print("")
print(string.format("No starter: hours after pouring 5 L until the milk is below %d C and must be reheated", M.STARTER_MIN_C))
print("| Month | Outdoors | Indoors | Basement | By a fire | By banked embers |")
print("|---|---|---|---|---|---|")
for month = 1, 12 do
    local cells = {}
    for _, place in ipairs(PLACES) do table.insert(cells, hoursText(get(month, place, "bare", "cold"))) end
    print(string.format("| %s | %s |", MONTHS[month], table.concat(cells, " | ")))
end

print("")
print(string.format("Starter Culture Crock: hours to cultivate (%g at best), then total hours to starter, fed at once", M.CULTIVATE_HOURS))
print("| Month | Outdoors | Indoors | Basement | By a fire | By banked embers |")
print("|---|---|---|---|---|---|")
for month = 1, 12 do
    local cells = {}
    for _, place in ipairs(PLACES) do
        table.insert(cells, string.format("%s / %s", hoursText(get(month, place, "crock", "cultivated")),
            hoursText(get(month, place, "crock", "ready"))))
    end
    print(string.format("| %s | %s |", MONTHS[month], table.concat(cells, " | ")))
end

print("")
print("Ledger at the end")
local keys = {}
for key in pairs(ledger) do table.insert(keys, key) end
table.sort(keys)
for _, key in ipairs(keys) do print(string.format("%-20s %.9f", key, ledger[key])) end
