-- Traditional Preservation (Dairy) B42: the rules for the Yogurt Incubator and the Starter Culture Crock.
-- The incubator is a lidded clay pot: milk brought to the boil in the hearth's copper cools in it by Newton's law towards the temperature where
-- it stands, and once it is down to setting heat with a starter in, the pot is wrapped in cloth and the milk
-- sets at a speed that follows its own temperature. Cooling depends on what the milk was, not only on the
-- weather now, so the core ledger's running totals can't replay it: an hourly history of the weather in
-- global ModData lets an unloaded pot catch up hour by hour. The crock is an ordinary weather-weighted run
-- on the ledger, in two stages with a feed of fresh milk between them; soured milk (a clabber) skips the first.
-- A batch is a plain table (modData[M.INCUBATOR_KEY] or [M.CROCK_KEY]); every function here works on it without the engine.
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy
local Weather = require "TraditionalPreservationCore/Weather"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Station = require "TraditionalPreservationCore/Station"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Recipes = require "TraditionalPreservationCore/Recipes"
local Container = require "TraditionalPreservationCore/Container"
local Portions = require "TraditionalPreservationCore/Portions"
local Tiles = require "TraditionalPreservationDairy/Tiles"

-- Save keys: never rename these once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
M.MOD_DATA_KEY = "TraditionalPreservationDairy"
-- Each station keeps its state as one table under one key, so nothing else on the object can clash with it.
-- Inside the incubator's: ml, tempC, starter, incubating, wrapHour, done, last, readyHour, fluid, parts, place, at,
-- fireUntil, under. Inside the crock's: stage, done, marks, fireUntil, under. The Hearth and its copper are TP
-- Core's (TraditionalPreservationCore/Hearth).
M.INCUBATOR_KEY = "tpdIncubator"
M.CROCK_KEY = "tpdCrock"

-- Incubator
M.CAPACITY_ML = 5000
M.SET_C = 45                  -- the wrap goes on when the milk is down to this with a starter in
M.STARTER_MIN_C = 40          -- below this a starter won't take: the milk must be reheated
M.LIDDED_TAU = 2.0            -- hours, for 5 L in the lidded clay pot
M.TAU_FLOOR_ML = 2500         -- smaller batches cool as if this big, so a litre or two still sets (balance)
M.WRAPPED_TAU = 16.0          -- hours, for 5 L once wrapped in cloth: about 10 C lost overnight in a 20 C room
M.INCUBATE_HOURS = 6          -- hours to set at the best temperature
M.STEP_HOURS = 1 / 6          -- the weather's own resolution
M.HISTORY_HOURS = 336         -- two weeks of hourly weather for catching up
local SETTLED_C = 0.05        -- milk this near its place's temperature has stopped changing
-- By a lit fire, TP Core's opt-in place: a fireplace, an antique stove or a campfire, never an electric or gas
-- stove. The wrapped pot sat by the hearth in winter. Seen by a lit fire, a station notes fireUntil (now plus the
-- fuel left): while unloaded, the fire counts until then, and after it the place under the fire (under) does.
-- By a banked Hearth (EMBERS) it is cooler, and the embers last three times as long.
M.HEARTH = Hearth.PLACE
M.EMBERS = Hearth.EMBERS

-- The Hearth's copper (TP Core) holds one fluid at a time, or a blend of milks, and heats while its fire burns.
M.HOT_C = Hearth.HOT_C        -- milk this hot pours from the copper into a pot
-- Milk counts as scalded only once it has been at HOT_C or more this long in all (user, 2026-11-13): the hold is what
-- changes the whey proteins and gives a firm set. The copper counts it (Hearth.heldHours), a pot on a stove or a
-- fire too (TP Core's FluidAgeing, scaldHold).
M.SCALD_HOLD_HOURS = 1 / 3

-- Carried milk: a container filled from the copper, taken hot off a stove or a fire, or poured into from one of those
-- keeps a record of its heat in its item modData (vanilla's item heat drops to the room within seconds of leaving
-- the heat). An open pot or bucket cools in minutes; the Wrapped Yogurt Pot (a clay pot in its cloth) in hours.
M.CARRY_KEY = "tpdCarry"      -- { ml, c, hour, scalded }
M.WRAPPED_POT_TAU = 4.0       -- hours, for 5 L: 85 to 70 C in about an hour at 20 C
M.OPEN_TAU = 0.25             -- hours, for 5 L: 85 to 45 C in about 15 minutes at 20 C, to 35 C in about 8 more
M.STAMP_C = 30                -- milk taken off the heat warmer than this keeps a record of it

-- Share of full setting speed at the milk's own temperature. Thermophilic cultures: best at 40 to 45 C,
-- slow below 35, stalled below about 18; past 50 the heat starts to kill them.
local SET_CURVE = { { 18, 0 }, { 22, 0.05 }, { 27, 0.15 }, { 32, 0.35 }, { 37, 0.7 }, { 40, 1 }, { 45, 1 }, { 50, 0.5 }, { 55, 0 } }

-- Crock: loaded with wheat and warm milk, fed fresh milk of any warmth once cultivated.
M.CROCK_CAPACITY_ML = 1000
M.WHEAT = "Base.WheatSeed"
M.CROCK_WHEAT = 20
M.CROCK_LOAD_ML = 500
M.CROCK_FEED_ML = 500
M.CROCK_WARM_C = 35           -- milk for loading must be warm: at least this,
M.CROCK_HOT_C = 45            -- and no hotter than this, or it kills the grain's culture
M.CULTIVATE_HOURS = 24        -- wheat and warm milk, at the best temperature
M.DEVELOP_HOURS = 12          -- after the fresh-milk feed, at the best temperature
M.CROCK_STARTERS = 2
-- Clabber: half a litre of soured milk, of any warmth, starts the crock with no wheat. Its own lactic bacteria are
-- the culture the grain would have grown, so it skips Cultivating and waits for fresh milk at once.
M.CLABBER_ML = 500
local CROCK_KIND = "culture"
-- Grain starters are kept warm, not hot: best at 25 to 35 C, slow when cool, near stopped by 5.
local CULTURE_CURVE = { { 5, 0.03 }, { 10, 0.1 }, { 15, 0.3 }, { 20, 0.6 }, { 25, 1 }, { 35, 1 }, { 40, 0.6 }, { 45, 0.1 } }

-- Milk going off (TP Core's FluidAgeing). Raw milk sours on its own lactic bacteria, then spoils as long again after;
-- scalded milk never sours (the heat killed them) and spoils at the same age. Ages are hours at 20 C: about a day
-- and a half to sour in a 20 C room, 3 days in a 15 C basement, 8 in a fridge, a day at 30 C. Store milk (sealed
-- cartons and bottles) keeps until it is poured out, and then counts as scalded: it was pasteurised. Scalded milk goes
-- by its scalded name (Cow's Milk (Scalded)) until raw milk is mixed in.
M.MILK_KIND = "milk"
M.MILK_TURN_HOURS = 36
M.MILK_SPOIL_HOURS = 72
M.MILK_SPOILS = true          -- sandbox: Milk goes off
M.MILK_SPEED = 1              -- sandbox: how fast, 1 as above
M.SOUR_MILKS = { CowMilk = "SourCowMilk", SheepMilk = "SourSheepMilk", AnimalMilk = "SourAnimalMilk" }
M.ROTTEN_MILKS = { CowMilk = "RottenCowMilk", SheepMilk = "RottenSheepMilk", AnimalMilk = "RottenAnimalMilk" }
M.SCALDED_MILKS = { CowMilk = "ScaldedCowMilk", SheepMilk = "ScaldedSheepMilk", AnimalMilk = "ScaldedAnimalMilk" }
M.SCALDED = {}
for _, scalded in pairs(M.SCALDED_MILKS) do M.SCALDED[scalded] = true end
M.STORE_MILK = { ["Base.Milk"] = true, ["Base.MilkBottle"] = true, ["Base.Milk_Personalsized"] = true }
M.SOURED, M.ROTTEN = {}, {}
for milk, sour in pairs(M.SOUR_MILKS) do M.SOURED[sour], M.ROTTEN[M.ROTTEN_MILKS[milk]] = true, true end
Hearth.blend("SourCowMilk", "SourSheepMilk", "SourAnimalMilk")
-- Souring speed against 20 C. Mesophilic bacteria: frozen milk stops, a fridge crawls, best near blood heat; past
-- 50 C the heat starts to kill them.
local MILK_CURVE = { { 0, 0 }, { 2, 0.12 }, { 4, 0.19 }, { 10, 0.33 }, { 15, 0.5 }, { 20, 1 }, { 25, 1.25 }, { 30, 1.5 },
    { 37, 1.8 }, { 45, 1.2 }, { 55, 0 } }

-- Yield
-- A jar takes yogurt to its vanilla capacity and is eaten from in portions of a cup, 250 ml.
M.CUPS_PER_LITRE = 4          -- 8 oz cups
M.CUP_ML = 1000 / M.CUPS_PER_LITRE   -- an Empty Yogurt Container, and one portion from a jar
M.CUP_KG = 0.25               -- a portion's weight
-- One portion's food: vanilla Yogurt's (hunger as the engine keeps it, -10 in the script). Jars and cups from
-- before C23 keep it; new yogurt keeps its milk's food instead (MILK_FOOD).
M.PORTION = { hunger = -0.1, calories = 30, carbohydrates = 1, lipids = 1, proteins = 5 }
-- A litre of each milk's food, as vanilla's fluid scripts state it (hunger as the engine keeps it, -50 there).
-- Yogurt is the milk set, so a portion is a quarter of this: eating it is worth drinking the milk.
M.MILK_FOOD = {
    CowMilk = { hunger = -0.5, calories = 615, carbohydrates = 46, lipids = 22, proteins = 33 },
    SheepMilk = { hunger = -0.5, calories = 823, carbohydrates = 23, lipids = 17, proteins = 23 },
    AnimalMilk = { hunger = -0.5, calories = 615, carbohydrates = 46, lipids = 22, proteins = 33 },
}
for milk, scalded in pairs(M.SCALDED_MILKS) do M.MILK_FOOD[scalded] = M.MILK_FOOD[milk] end

-- Items and fluids. Only animal milk sets: a cow's, a sheep's, or the game's generic AnimalMilk (debug spawns and
-- some loot, which vanilla's own milking and cheese accept as milk). Yogurt is yogurt, so they may share a
-- copper, a container and a pot, as a mixed herd's milk always did. Scalded milk is milk too.
M.MILKS = { CowMilk = true, SheepMilk = true, AnimalMilk = true }
for milk, scalded in pairs(M.SCALDED_MILKS) do M.MILKS[scalded] = true end
Hearth.blend("CowMilk", "SheepMilk", "AnimalMilk", "ScaldedCowMilk", "ScaldedSheepMilk", "ScaldedAnimalMilk")
M.STARTER = "TraditionalPreservationDairy.ActiveYoghurtStarter"
-- A Jar of Yogurt gives one portion, as much as a Yogurt cup holds, and keeps the rest (M.isStarter).
M.STARTERS = { ["Base.Yoghurt"] = "Yogurt", [M.STARTER] = "Starter", ["TraditionalPreservationDairy.JarOfYoghurt"] = "Yogurt" }
M.EMPTY_CUP = "TraditionalPreservationDairy.EmptyYoghurtContainer"
-- The jars yogurt is collected into, with the ml each holds (vanilla capacities). Clay Jars need Pottery 5 and
-- are rare loot; the glass canning jar is common.
M.JAR_ML = { ["Base.EmptyJar"] = 1000, ["Base.ClayJar"] = 2500, ["Base.ClayJarGlazed"] = 2500 }
M.OLD_JAR_ML = 1000           -- every jar took a litre before F4
M.YOGHURT_JAR = "TraditionalPreservationDairy.JarOfYoghurt"
-- One item whatever the jar; a clay one changes only its icon, through modData `customInventoryIcon` (read by
-- InventoryItem.getTexture, saved with the item). Full paths: a bare "Item_X" name finds a mod texture only
-- when some script uses it as its Icon, so it was nil here.
M.JAR_ICONS = { ["Base.ClayJar"] = "media/textures/Item_JarOfYoghurt_Clay.png",
    ["Base.ClayJarGlazed"] = "media/textures/Item_JarOfYoghurt_Glazed.png" }
M.COLLECT_XP = 2              -- Cooking, per litre collected, into a jar or cups alike

-- Stations: FACE_COUNT tiles from each base, one per facing. Stage sprites are layered on top once the art
-- builder makes them (Tiles.OVERLAYS); until then the station shows its base tile only.
M.INCUBATOR_SPRITE = Tiles.INCUBATOR
M.CROCK_SPRITE = Tiles.CROCK
M.FACE_COUNT = Tiles.FACE_COUNT
M.INCUBATOR_OVERLAYS = Tiles.OVERLAYS and Tiles.OVERLAYS.incubator or {}
M.CROCK_OVERLAYS = Tiles.OVERLAYS and Tiles.OVERLAYS.crock or {}

function M.spriteName(index)
    return Tiles.PREFIX .. index
end

-- The main fluid in a container if it is all milk (one kind, or a blend), and its ml by fluid; else nil.
function M.milkIn(container)
    local parts, name = Hearth.partsIn(container)
    if not M.MILKS[name] then return nil end
    return name, parts
end

-- Only empty containers take milk or yogurt out, so nothing is ever topped up into a mixture (TP Core's).
M.isEmptyContainer = Container.isEmptyVessel

-- Which station this is ("incubator" or "crock") and which way it faces, or nil for anything else.
M.stationKind = Station.kinds(Tiles.PREFIX, M.FACE_COUNT, { incubator = M.INCUBATOR_SPRITE, crock = M.CROCK_SPRITE })

function M.isIncubator(object)
    return M.stationKind(object) == "incubator"
end

function M.isCrock(object)
    return M.stationKind(object) == "crock"
end

M.SENSITIVITY = 1

M.PLACES = { "Open", "Covered", "Sheltered", "Loft", "Basement", M.HEARTH, M.EMBERS }

M.placeTemperature = Hearth.placeTemperature
M.placeOf = Hearth.placeOf
M.noteFire = Hearth.noteFire
M.hearthsNear = Hearth.hearthsNear
M.isHearth = Hearth.isHearth

-- Temperatures: vanilla's item heat, for milk poured between our stores and the player's containers. Vanilla
-- cools a container in the player's hands to room heat within seconds, so only the copper and the pot keep heat.
M.heatCelsius = Hearth.heatCelsius
M.itemHeat = Hearth.itemHeat

-- More milk holds its heat longer: the time constant grows with the pot's size, so with the cube root of litres.
function M.tau(ml, wrapped)
    local base = wrapped and M.WRAPPED_TAU or M.LIDDED_TAU
    return base * (math.max(ml, M.TAU_FLOOR_ML) / M.CAPACITY_ML) ^ (1 / 3)
end

M.cool = Hearth.cool

function M.setRate(milkC)
    return Weather.scaled(Weather.curve(SET_CURVE, milkC), M.SENSITIVITY, 0)
end

-- Frozen the crock's culture pauses (TP Core's Weather.frozen), and goes on once thawed.
function M.cultureRate(celsius)
    if Weather.frozen(celsius, M.SENSITIVITY) then return 0 end
    return Weather.scaled(Weather.curve(CULTURE_CURVE, celsius), M.SENSITIVITY, 0)
end

-- Weather ledger and history

function M.milkRate(celsius)
    return Weather.curve(MILK_CURVE, celsius)
end

local KINDS = { [CROCK_KIND] = function(celsius) return M.cultureRate(celsius) end,
    [M.MILK_KIND] = function(celsius) return M.milkRate(celsius) end }

function M.newLedger(now)
    return Weather.newLedger(now, KINDS)
end

function M.getLedger()
    return Weather.getLedger(M.MOD_DATA_KEY, M.newLedger)
end

function M.getHistory()
    local data = ModData.getOrCreate(M.MOD_DATA_KEY)
    data.history = data.history or {}
    return data.history
end

FluidAgeing.register({
    kind = M.MILK_KIND,
    scaldHeat = Hearth.itemHeat(M.HOT_C),
    scaldHold = M.SCALD_HOLD_HOURS,
    rate = M.milkRate,
    turnHours = M.MILK_TURN_HOURS,
    spoilHours = M.MILK_SPOIL_HOURS,
    fresh = M.SOUR_MILKS,
    spoiled = M.ROTTEN_MILKS,
    scalded = M.SCALDED_MILKS,
    sealed = M.STORE_MILK,
    getLedger = function() return M.getLedger() end,
    enabled = function() return M.MILK_SPOILS end,
    speed = function() return M.MILK_SPEED end,
})

-- One ten-minute reading: the ledger for the crock, and the hour's slot in the history for the incubator.
-- An hour's slot keeps the last reading in it, with the season mean that goes with it.
function M.record(ledger, history, now, temperature)
    Weather.advance(ledger, now, temperature, KINDS)
    local hour = math.floor(now)
    history[hour % M.HISTORY_HOURS + 1] = { hour = hour, temperature = ledger.temperature, season = ledger.seasonTemperature,
        ground = ledger.groundTemperature, grid = ledger.gridOn }
end

-- The place's temperature in a past hour, or nil when the history has no reading for it.
function M.pastTemperature(history, hour, place)
    local entry = history[hour % M.HISTORY_HOURS + 1]
    local reading = entry and entry.hour == hour and { temperature = entry.temperature, seasonTemperature = entry.season,
        groundTemperature = entry.ground, gridOn = entry.grid } or nil
    -- A fire indoors needs no reading; one under a roof or in the open does.
    if Hearth.isFirePlace(place) then return Hearth.fireC(place, reading) end
    if not reading then return nil end
    return Weather.placeTemperature(reading, place)
end

-- Incubator

-- Empty, Cooling, TooCold, Incubating or Ready.
function M.stage(batch)
    if (batch.ml or 0) <= 0 then return "Empty" end
    if batch.readyHour then return "Ready" end
    if batch.incubating then return "Incubating" end
    if not batch.starter and batch.tempC < M.STARTER_MIN_C then return "TooCold" end
    return "Cooling"
end

-- How much of ml fits, or 0 with the reason it can't go in.
function M.milkRoom(batch, ml)
    local stage = M.stage(batch)
    if stage == "Incubating" or stage == "Ready" then return 0, stage end
    local room = M.CAPACITY_ML - (batch.ml or 0)
    if room <= 0 then return 0, "Full" end
    return math.min(ml, room)
end

-- Why ml of milk at milkC can't join the pot, or nil. With the starter in, milk that would bring the pot below
-- the heat a starter takes at is refused: the wrap would go on over milk too cold to set, with no way to pour it
-- back out.
function M.coldRefusal(batch, ml, milkC)
    if not batch.starter then return nil end
    local taken, had = M.milkRoom(batch, ml), batch.ml or 0
    if taken <= 0 then return nil end
    local mixedC = had > 0 and (batch.tempC * had + milkC * taken) / (had + taken) or milkC
    if mixedC < M.STARTER_MIN_C then return "ColdForStarter" end
end

-- Pours hot milk in; the temperatures mix by volume. fluid is the milk's name, or its ml by fluid for a blend.
-- Returns the ml taken (0 with a reason when refused).
function M.addMilk(batch, ml, milkC, now, fluid)
    local taken, reason = M.milkRoom(batch, ml)
    if taken <= 0 then return 0, reason end
    reason = M.coldRefusal(batch, ml, milkC)
    if reason then return 0, reason end
    local had = batch.ml or 0
    batch.tempC = had > 0 and (batch.tempC * had + milkC * taken) / (had + taken) or milkC
    if fluid then Hearth.addParts(batch, fluid, taken) end
    batch.ml = had + taken
    batch.last = batch.last or now
    return taken
end

-- The starter waits beside the pot until the milk is down to setting heat. It can go in before the milk.
function M.canAddStarter(batch)
    if batch.starter then return false, "HasStarter" end
    local stage = M.stage(batch)
    if stage == "Incubating" or stage == "Ready" then return false, stage end
    if stage == "TooCold" then return false, "TooCold" end
    return true
end

function M.addStarter(batch, kind)
    local ok, reason = M.canAddStarter(batch)
    if not ok then return false, reason end
    batch.starter = kind
    return true
end

-- Takes up to maxMl of the milk back out (to reheat it), all of it if left out. Returns the ml, its
-- temperature and the ml by fluid. The starter, if any, stays for the next pour.
function M.pourOut(batch, maxMl)
    local stage = M.stage(batch)
    if stage ~= "Cooling" and stage ~= "TooCold" then return 0 end
    local ml, tempC = math.min(batch.ml, maxMl or batch.ml), batch.tempC
    local parts = Hearth.partsOf(batch, ml)
    batch.ml = batch.ml - ml
    if batch.ml <= 0 then
        for _, key in ipairs({ "ml", "tempC", "last", "fluid", "parts" }) do batch[key] = nil end
    end
    return ml, tempC, parts
end

-- Runs the pot for hours at one place temperature, from hour now. Each step cools exactly; the wrap goes on
-- the moment the milk crosses SET_C (user, 2026-11-14: on the step's reading it went on a degree or two cold, and
-- November's pots indoors never set), and the yogurt is done within a step's resolution.
function M.advanceBatch(batch, hours, placeC, now)
    if (batch.ml or 0) <= 0 then return end
    local t = 0
    while t < hours - 1e-9 do
        local step = math.min(M.STEP_HOURS, hours - t)
        local wrapped = batch.incubating and not batch.readyHour
        local before = batch.tempC
        batch.tempC = M.cool(before, placeC, step, M.tau(batch.ml, wrapped))
        if not batch.incubating and batch.starter and before > M.SET_C and batch.tempC < M.SET_C then
            -- Cooling is exponential, so the crossing is exact: lidded to SET_C, wrapped for the rest of the step.
            local cross = M.tau(batch.ml, false) * math.log((before - placeC) / (M.SET_C - placeC))
            batch.tempC = M.cool(M.SET_C, placeC, step - cross, M.tau(batch.ml, true))
            batch.incubating, batch.wrapHour = true, now + t + cross   -- read by tools/season_report.lua
            batch.done = M.setRate(batch.tempC) * (step - cross)
        end
        t = t + step
        if not batch.incubating and batch.starter and batch.tempC <= M.SET_C then
            batch.incubating = true
            batch.wrapHour = now + t   -- read by tools/season_report.lua
            batch.done = 0
        elseif wrapped then
            batch.done = batch.done + M.setRate(batch.tempC) * step
            if batch.done >= M.INCUBATE_HOURS then batch.readyHour = now + t end
        end
    end
end

-- By a fire until it burns out (fireUntil), then the place under it.
local function placeAt(state, place, hour)
    if Hearth.isFirePlace(place) and state.fireUntil and hour >= state.fireUntil then return state.under or "Sheltered" end
    return place
end

-- Runs the pot for a long spell at one place temperature. Ten-minute steps only while a started pot is still
-- settling to the place; after that nothing changes but at a steady rate, so the rest is one exact step.
function M.advanceSpell(batch, hours, placeC, now)
    if (batch.ml or 0) <= 0 then return end
    local t = 0
    while t < hours - 1e-9 and batch.starter and not batch.readyHour and math.abs(batch.tempC - placeC) >= SETTLED_C do
        local step = math.min(M.STEP_HOURS, hours - t)
        M.advanceBatch(batch, step, placeC, now + t)
        t = t + step
    end
    local left = hours - t
    if left <= 1e-9 then return end
    if batch.starter and not batch.incubating and batch.tempC <= M.SET_C then
        batch.incubating, batch.wrapHour, batch.done = true, now + t, 0
    end
    local wrapped = batch.incubating and not batch.readyHour
    if wrapped then
        local rate, need = M.setRate(batch.tempC), M.INCUBATE_HOURS - batch.done
        if rate * left >= need then
            batch.done, batch.readyHour = M.INCUBATE_HOURS, now + t + need / rate
        else
            batch.done = batch.done + rate * left
        end
    end
    batch.tempC = M.cool(batch.tempC, placeC, left, M.tau(batch.ml, wrapped))
end

-- Brings the pot up to now: hour by hour through the history, at the place's current temperature where the
-- history has no reading (a gap longer than it keeps, or the hour now). The hours before the history all read
-- alike, so they run as one spell (two when a fire burnt out in them), however long the pot was away.
function M.catchUp(batch, now, place, history, ledger)
    if (batch.ml or 0) <= 0 then batch.last = now return end
    local t = batch.last or now
    local kept = math.floor(now) - M.HISTORY_HOURS + 1
    while t < kept do
        local stop = kept
        if Hearth.isFirePlace(place) and batch.fireUntil and t < batch.fireUntil then stop = math.min(stop, batch.fireUntil) end
        M.advanceSpell(batch, stop - t, M.placeTemperature(ledger, placeAt(batch, place, t)), t)
        t = stop
    end
    while t < now do
        local hour = math.floor(t)
        local stop = math.min(hour + 1, now)
        if Hearth.isFirePlace(place) and batch.fireUntil and t < batch.fireUntil then stop = math.min(stop, batch.fireUntil) end
        local here = placeAt(batch, place, t)
        M.advanceBatch(batch, stop - t, M.pastTemperature(history, hour, here) or M.placeTemperature(ledger, here), t)
        t = stop
    end
    batch.last = now
end

-- Days since the yogurt set, for the jar's food age: freshness carries over and never resets.
function M.ageDays(batch, now)
    return batch.readyHour and math.max(now - batch.readyHour, 0) / 24 or 0
end

-- One portion's food from the pot's milk, by its shares of each kind. A pot from before the milk's kind was kept
-- is cow's milk, as Pour Out treats it.
-- True if a table has anything in it (the game's Lua has no next()).
function M.hasAny(t)
    for _ in pairs(t) do return true end
    return false
end

function M.portionFood(batch)
    local parts = Hearth.partsOf(batch, 1)
    if not M.hasAny(parts) then parts = { CowMilk = 1 } end
    local food = {}
    for key in pairs(M.PORTION) do food[key] = 0 end
    for name, share in pairs(parts) do
        local litre = M.MILK_FOOD[name] or M.MILK_FOOD.CowMilk
        for key, value in pairs(litre) do food[key] = food[key] + value * share * M.CUP_ML / 1000 end
    end
    return food
end

-- Takes up to want ml of set yogurt. Returns the ml taken, the age in days and a portion's food; an emptied pot
-- starts over.
local function collect(batch, now, want)
    if M.stage(batch) ~= "Ready" then return 0 end
    local ml = math.min(want, batch.ml)
    local age, food = M.ageDays(batch, now), M.portionFood(batch)
    batch.ml = batch.ml - ml
    if batch.ml <= 0 then
        for _, key in ipairs({ "ml", "tempC", "starter", "incubating", "wrapHour", "done", "last", "readyHour", "fluid", "parts" }) do
            batch[key] = nil
        end
    end
    return ml, age, food
end

-- Fills one jar of the given type to its size.
function M.collectJar(batch, now, jarType)
    return collect(batch, now, M.JAR_ML[jarType] or M.OLD_JAR_ML)
end

-- How many of the given jars (types, in order) the ml fill: the last may be part-full.
function M.jarsFor(ml, jarTypes)
    local count = 0
    for _, jarType in ipairs(jarTypes) do
        if ml <= 0 then break end
        ml = ml - (M.JAR_ML[jarType] or M.OLD_JAR_ML)
        count = count + 1
    end
    return count
end

-- Fills one Empty Yogurt Container straight from the pot, a quarter of a jar; the last one takes what is left.
function M.collectCup(batch, now)
    return collect(batch, now, M.CUP_ML)
end

-- Empty Yogurt Containers a Ready pot still fills.
function M.cupsInPot(batch)
    if M.stage(batch) ~= "Ready" then return 0 end
    return math.ceil(batch.ml / M.CUP_ML)
end

function M.cupsFor(ml)
    return math.max(math.floor(ml / 1000 * M.CUPS_PER_LITRE + 0.5), 1)
end

-- Cups in a Jar of Yogurt from before F4 (eaten by the cup only), from its modData; older still, by its litres.
function M.cupsLeft(jarData)
    return jarData.tpdCups or M.cupsFor(jarData.tpdMl or M.OLD_JAR_ML)
end

-- Portions left in a Jar of Yogurt, from the hunger it still holds and one portion's (vanilla Yogurt's if not
-- given). Vanilla's Eat Half / Quarter may leave a part.
function M.portionsIn(hunger, portion)
    return Portions.left(hunger, (portion or M.PORTION).hunger)
end

-- A jar counts as empty below a tenth of a portion (the engine's own cut-off is one hunger point).
M.EMPTY_PORTIONS = 0.1

-- One portion as a share of a full jar, for vanilla's eat action (its percentage is of the full item); the last
-- part-portion is all that's left.
function M.portionShare(left, full)
    if full <= 0 then return 1 end
    return math.min(left, 1) / full
end

-- A jar's portions as text: whole numbers plain, a part-portion to one place (TP Core's).
M.portionsText = Portions.text

-- Hours until the next change (wrap on, or set) if the place's temperature holds; nil if it never comes.
function M.forecast(batch, placeC)
    local copy = {}
    for key, value in pairs(batch) do copy[key] = value end
    local stage = M.stage(copy)
    if stage == "Empty" or stage == "Ready" or stage == "TooCold" then return nil end
    local hours, limit = 0, 96
    while hours < limit do
        M.advanceBatch(copy, M.STEP_HOURS, placeC, hours)
        hours = hours + M.STEP_HOURS
        local now = M.stage(copy)
        if now ~= stage then return hours, now end
    end
    return nil
end

-- Hearth copper: the rules are TP Core's; these are milk's.

-- Hours until the copper is hot if the fire burns on; 0 if it is already, nil if it holds no milk.
function M.hoursToHot(copper)
    if not M.MILKS[copper.fluid] then return nil end
    return Hearth.hoursToHot(copper)
end

function M.copperHot(copper)
    return M.MILKS[copper.fluid] == true and (copper.tempC or 0) >= M.HOT_C
end

-- True once the copper's milk has steamed for the hold: what may go into the pot.
function M.held(hours)
    return (hours or 0) >= M.SCALD_HOLD_HOURS - 1e-9
end

function M.copperScalded(copper)
    return M.copperHot(copper) and M.held(Hearth.heldHours(copper))
end

-- Minutes of the hold still to go for the copper's milk (0 once held).
function M.holdMinutesLeft(copper)
    return math.max(math.ceil((M.SCALD_HOLD_HOURS - Hearth.heldHours(copper)) * 60 - 1e-6), 0)
end

-- Fills the pot from the copper with hot milk, as much as fits. Returns the ml (0 with a reason when refused).
function M.copperToPot(copper, batch, now)
    if not M.copperHot(copper) then return 0, M.MILKS[copper.fluid] and "NotHot" or "NoMilk" end
    if not M.copperScalded(copper) then return 0, "NotHeld" end
    local room, reason = M.milkRoom(batch, copper.ml)
    if room <= 0 then return 0, reason end
    local ml, _, tempC, parts = Hearth.take(copper, room)
    M.addMilk(batch, ml, tempC, now, parts)
    return ml
end

-- Carried milk

function M.carryTau(ml, open)
    return (open and M.OPEN_TAU or M.WRAPPED_POT_TAU) * (math.max(ml, Hearth.FLOOR_ML) / M.CAPACITY_ML) ^ (1 / 3)
end

-- Records ml of milk at tempC going into a container that already holds hadMl at hadC. The milk stays scalded
-- only if the new milk is and everything already in it was recorded as scalded. Returns the new record.
function M.carryIn(carry, hadMl, hadC, ml, tempC, now, scalded)
    local kept = hadMl <= 0 or M.isScalded(carry, hadMl)
    local record = {
        ml = hadMl + ml,
        c = hadMl > 0 and (hadC * hadMl + tempC * ml) / (hadMl + ml) or tempC,
        hour = now,
        scalded = (scalded and kept) or nil,
    }
    if carry and hadMl > 0 then record.place, record.fireUntil, record.under = carry.place, carry.fireUntil, carry.under end
    return record
end

-- Takes ml out of the record; nil once it is empty.
function M.carryOut(carry, ml)
    if not carry then return nil end
    carry.ml = carry.ml - ml
    if carry.ml <= 0.5 then return nil end
    return carry
end

-- True if the container's ml is all recorded, scalded milk. Taking milk out (vanilla's pour or drink too) is
-- harmless; holding more than the record means milk was added some other way, which voids it.
function M.isScalded(carry, ml)
    return carry ~= nil and carry.scalded == true and ml <= (carry.ml or 0) + 0.5
end

-- True if parts ({ name = ml }) is all scalded milk (TP Core's FluidAgeing names it so once it has been at 85 C, in
-- the copper, on a stove or a fire, or poured out of a store carton).
function M.allScalded(parts)
    local any = false
    for name in pairs(parts or {}) do
        if not M.SCALDED[name] then return false end
        any = true
    end
    return any
end

-- Shrinks the record to ml once milk has left by vanilla's menus, so milk added later can't hide in the gap.
-- Call it whenever a container is looked at (menus, tooltips). Returns the record, nil once the container is empty.
function M.noteCarry(carry, ml)
    if not carry then return nil end
    if ml <= 0.5 then return nil end
    if ml < carry.ml then carry.ml = ml end
    return carry
end

-- The heat of carried milk, brought up to now at placeC (the record is updated); open for anything but a Wrapped Pot.
function M.wrappedC(carry, now, placeC, open)
    if now > carry.hour then
        carry.c = M.cool(carry.c, placeC, now - carry.hour, M.carryTau(carry.ml, open))
        carry.hour = now
    end
    return carry.c
end

-- Why ml of carried milk can't go into the pot, or nil if it can: it must be scalded (parts, by name) or recorded as
-- scalded (when the sandbox has milk never going off, nothing is renamed).
function M.carriedRefusal(carry, ml, parts)
    if not M.allScalded(parts) and not M.isScalded(carry, ml) then return "NotScalded" end
end

-- The record on a carried item

M.WRAPPED_POT = "TraditionalPreservationDairy.WrappedYoghurtPot"

-- Wrapping: a vanilla pot, jar or bucket, empty, wrapped in a Sheet tied with Twine, keeps milk hot as the Wrapped
-- Yogurt Pot does, and keeps its own capacity. The mark is the fluid container's own name, which the game saves and
-- the inventory shows ("Pot" becomes "TPDWrappedPot", "Wrapped Pot"); the old name and rain factor are kept in
-- modData WRAP_KEY. A wrapped item seen in a hot cooking container burns its wrap (World).
M.WRAP_KEY = "tpdWrapped"     -- { name, rain }
M.WRAPPABLE = {
    ["Base.Pot"] = true, ["Base.PotForged"] = true,
    ["Base.EmptyJar"] = true, ["Base.JarCrafted"] = true, ["Base.ClayJar"] = true,
    ["Base.Bucket"] = true, ["Base.BucketEmpty"] = true, ["Base.BucketCarved"] = true,
}
M.WRAPPED_NAMES = { Pot = "TPDWrappedPot", Jar = "TPDWrappedJar", Bucket = "TPDWrappedBucket" }
-- What a wrapped one looks like: its own icon bundled in towels (tools/build_tileset.py) and, on the ground, the towel
-- bundle sized to it (tools/build_model.py, the TowelBundle_* models). Both go on the item's modData, which the engine
-- reads first and saves: customInventoryIcon and worldStaticModel.
M.WRAPPED_LOOKS = {
    ["Base.Pot"] = "Pot", ["Base.PotForged"] = "PotForged",
    ["Base.EmptyJar"] = "Jar", ["Base.JarCrafted"] = "Jar", ["Base.ClayJar"] = "ClayJar",
    ["Base.Bucket"] = "Bucket", ["Base.BucketEmpty"] = "Bucket", ["Base.BucketCarved"] = "BucketCarved",
}

local function setLook(item, look)
    local modData = item:getModData()
    modData.customInventoryIcon = look and ("media/textures/Item_Wrapped" .. look .. ".png") or nil
    modData.worldStaticModel = look and ("TraditionalPreservationDairy.TowelBundle_" .. look) or nil
end

function M.isWrapped(item)
    return item:getFullType() == M.WRAPPED_POT or item:getModData()[M.WRAP_KEY] ~= nil
end

-- Kept for the callers that knew only the Wrapped Yogurt Pot.
M.isWrappedPot = M.isWrapped

-- Gives an item's fluid container another name, in place: the game saves it, so it shows from the next load. Vanilla
-- caches the shown name and nothing Lua can call clears it (reset() is protected, add/removeComponent package-private:
-- ENGINE_NOTES), so to show it now the item is swapped a tick later for a new one of its type (M.refreshName). The
-- wait matters: a recipe still holds its kept item while OnCreate runs.
local function rename(item, name, rain)
    local container = item:getFluidContainer()
    container:setContainerName(name)
    container:setRainCatcher(rain)
    M.refreshName(item)
end

local renamed = {}

-- A new item of the same type, given the old one's fluid container name, fluids, rain, ModData, heat, condition and
-- favourite before its name is ever shown, in the old one's place. Items on the floor keep theirs (shown after a
-- load). Returns the new item, or nil.
function M.swapForFresh(item)
    local container = item:getContainer()
    if not container or item:getWorldItem() or not container:contains(item) then return nil end
    local new = instanceItem(item:getFullType())
    local old, fresh = item:getFluidContainer(), new and new:getFluidContainer()
    if not old or not fresh then return nil end
    fresh:setContainerName(old:getContainerName())
    fresh:setRainCatcher(old:getRainCatcher())
    fresh:copyFluidsFrom(old)
    local modData = new:getModData()
    for key, value in pairs(item:getModData()) do modData[key] = value end
    new:setItemHeat(item:getItemHeat())
    new:setCondition(item:getCondition())
    new:setFavorite(item:isFavorite())
    container:DoRemoveItem(item)
    container:AddItem(new)
    return new
end

function M.refreshName(item)
    table.insert(renamed, item)
end

local function onTick()
    if #renamed == 0 then return end
    local list = renamed
    renamed = {}
    for _, item in ipairs(list) do M.swapForFresh(item) end
end

Events.OnTick.Add(onTick)

-- Wraps a pot, jar or bucket: it no longer catches rain under its cloth.
function M.wrap(item)
    local container = item:getFluidContainer()
    if not container or not M.WRAPPABLE[item:getFullType()] or M.isWrapped(item) then return false end
    local name, rain = container:getContainerName(), container:getRainCatcher()
    -- Marked only once renamed, so a rename that fails leaves a plain item.
    setLook(item, M.WRAPPED_LOOKS[item:getFullType()])
    rename(item, M.WRAPPED_NAMES[name] or "TPDWrappedPot", 0)
    item:getModData()[M.WRAP_KEY] = { name = name, rain = rain }
    return true
end

function M.unwrap(item)
    local modData = item:getModData()
    local was = modData[M.WRAP_KEY]
    local container = item:getFluidContainer()
    if not was or not container then return false end
    setLook(item, nil)
    rename(item, was.name, was.rain or 0)
    modData[M.WRAP_KEY] = nil
    return true
end

-- Recipes: the wrap goes on a pot, jar or bucket not yet wrapped, and comes off a wrapped one (both only when empty,
-- by the recipe's flag). Other inputs (the Sheet, the Twine) pass.
function M.canWrap(item)
    return not M.WRAPPABLE[item:getFullType()] or not M.isWrapped(item)
end

function M.canUnwrap(item)
    return not M.WRAPPABLE[item:getFullType()] or M.isWrapped(item)
end

local function keptCarrier(craftRecipeData)
    local items = craftRecipeData:getAllKeepInputItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if M.WRAPPABLE[item:getFullType()] then return item end
    end
end

function M.onWrapped(craftRecipeData)
    local item = keptCarrier(craftRecipeData)
    if item then M.wrap(item) end
end

function M.onUnwrapped(craftRecipeData)
    local item = keptCarrier(craftRecipeData)
    if item then M.unwrap(item) end
end

-- Burnt in a hot cooking container: the Sheet and the Twine are gone. A wrapped pot, jar or bucket is itself again;
-- the Wrapped Yogurt Pot is a bare Yogurt Pot, which holds no fluid (its milk is lost). Returns the item now there.
M.BURN_HEAT = 1.3             -- a container this hot burns a wrap (vanilla: 1.0 cold; the lowest stove setting about 1.5)

function M.burnWrap(item)
    if item:getFullType() ~= M.WRAPPED_POT then
        M.unwrap(item)
        return item
    end
    local container = item:getContainer()
    if not container then return item end
    local bare = container:AddItem("TraditionalPreservationDairy.YoghurtPot")
    container:DoRemoveItem(item)
    return bare
end

M.mlIn = Container.ml

-- An item's record, shrunk to the milk it holds now; nil (and dropped) once it holds no plain milk.
function M.carryOf(item)
    local modData = item:getModData()
    local carry = modData[M.CARRY_KEY]
    if not carry then return nil end
    local container = item:getFluidContainer()
    carry = container and M.milkIn(container) and M.noteCarry(carry, M.mlIn(container)) or nil
    modData[M.CARRY_KEY] = carry
    return carry
end

-- Brings carried milk up to now at the place it was last carried in (herePlace if it has none yet), hour by hour
-- through the history as the incubator catches up: by a fire until the fuel ran out (fireUntil), then the place
-- under the fire. open: not in a Wrapped Pot, so it cools fast. Returns the heat.
function M.advanceCarry(carry, now, ledger, herePlace, history, open)
    local place = carry.place or herePlace
    history = history or M.getHistory()
    local t = carry.hour
    while t < now do
        local hour = math.floor(t)
        local stop = math.min(hour + 1, now)
        if Hearth.isFirePlace(place) and carry.fireUntil and t < carry.fireUntil then stop = math.min(stop, carry.fireUntil) end
        local here = placeAt(carry, place, t)
        M.wrappedC(carry, stop, M.pastTemperature(history, hour, here) or M.placeTemperature(ledger, here), open)
        t = stop
    end
    return carry.c
end

-- While a player carries warm milk, the World brings it up to now every game minute and notes where it is. Set
-- down, it keeps the last place it was carried in, so the time until it is next looked at counts there.
function M.carryTick(carry, now, ledger, place, fireUntil, under, open)
    M.advanceCarry(carry, now, ledger, place, nil, open)
    carry.place, carry.fireUntil, carry.under = place, fireUntil, under
end

-- The heat of an item's milk: its record's if it has one (cooling slowly in a Wrapped Pot, fast in anything else),
-- else vanilla's item heat. holder is whoever is looking at it, whose place counts if it was never carried.
function M.carriedC(item, now, holder)
    local carry = M.carryOf(item)
    if carry then
        return M.advanceCarry(carry, now, M.getLedger(), (M.placeOf(holder)), nil, not M.isWrappedPot(item))
    end
    return M.heatCelsius(item:getItemHeat())
end

-- Milk taken off a stove or a fire (from a container that hot) keeps its heat as a record, scalded if it was held at
-- 85 C or more for the hold (TP Core's FluidAgeing counts it while it sits on the heat): read now, while it is still there.
function M.stampHeat(item, now)
    local container = item:getFluidContainer()
    local _, parts = M.milkIn(container)
    if not parts then return end
    local tempC = M.heatCelsius(item:getItemHeat())
    if tempC < M.STAMP_C then return end
    local carry, ml = M.carryOf(item), M.mlIn(container)
    M.recordCarry(item, nil, 0, 0, ml, tempC, now, M.held(FluidAgeing.heldHours(item)) or M.isScalded(carry, ml))
end

-- After a vanilla pour: moved ml of milk at fromC (scalded or not) went into an item that held hadMl at hadC.
function M.pouredInto(item, carry, hadMl, hadC, moved, fromC, scalded, now)
    if moved <= 0.5 or not M.milkIn(item:getFluidContainer()) then return end
    M.recordCarry(item, carry, hadMl, hadC, moved, fromC, now, scalded)
end

-- Writes the record after ml of milk at tempC went into an item that held hadMl at hadC (carry: its record from
-- before), and sets vanilla's item heat to match.
function M.recordCarry(item, carry, hadMl, hadC, ml, tempC, now, scalded)
    local record = M.carryIn(carry, hadMl, hadC, ml, tempC, now, scalded)
    item:getModData()[M.CARRY_KEY] = record
    item:setItemHeat(M.itemHeat(record.c))
end

-- Writes the record after ml left the item.
function M.recordTaken(item, carry, ml)
    item:getModData()[M.CARRY_KEY] = M.carryOut(carry, ml)
end

-- The copper's hooks: a Wrapped Pot pours in at its own heat; milk drawn steaming is marked so the incubator takes
-- it. Milk that left an item is already gone from the container, so reading the record shrinks it to match.
Hearth.hook("heatOf", function(item, now, character)
    local carry = M.carryOf(item)
    return carry and M.advanceCarry(carry, now, M.getLedger(), (M.placeOf(character)), nil, not M.isWrappedPot(item)) or nil
end)

Hearth.hook("taken", function(item)
    M.carryOf(item)
end)

Hearth.hook("filled", function(item, fill)
    if not M.MILKS[fill.fluid] then return false end
    -- Scalded once the copper's milk had its hold, hot or cooled since.
    M.recordCarry(item, item:getModData()[M.CARRY_KEY], fill.hadMl, fill.hadC, fill.ml, fill.tempC, fill.now, M.held(fill.held))
    return true
end)


-- Crock: Cultivating, then Waiting for fresh milk, then Developing, then Ready.

-- The ledger keeps totals for the weather's places only, so time by a fire counts by the clock (Hearth.catchUp).
local function markCrock(crock, ledger)
    crock.marks = Hearth.mark({}, ledger, CROCK_KIND)
end

function M.startCrock(crock, ledger)
    crock.stage = "Cultivating"
    crock.done = 0
    markCrock(crock, ledger)
end

-- Empty, Cultivating, Waiting, Developing or Ready.
function M.crockStage(crock)
    return crock.stage or "Empty"
end

function M.isWarm(celsius)
    return celsius >= M.CROCK_WARM_C and celsius <= M.CROCK_HOT_C
end

-- Why milk at celsius can't load the crock, or nil if it can.
function M.crockMilkRefusal(celsius)
    if celsius < M.CROCK_WARM_C then return "TooCool" end
    if celsius > M.CROCK_HOT_C then return "TooHot" end
end

-- Why ml of milk at celsius, from the copper or a container, can't load the crock, or nil if it can.
function M.crockLoadRefusal(ml, celsius)
    if ml < M.CROCK_LOAD_ML - 0.5 then return "TooLittle" end
    return M.crockMilkRefusal(celsius)
end

-- Wheat and warm milk go into an empty crock only.
function M.loadCrock(crock, ledger)
    if M.crockStage(crock) ~= "Empty" then return false end
    M.startCrock(crock, ledger)
    return true
end

-- What a container holds for a clabber: "Soured" if it is all soured milk (one kind or a blend), "Rotten" if its
-- main fluid is rotten milk, else nil.
function M.clabberIn(container)
    local parts, name = Hearth.partsIn(container)
    if parts and M.SOURED[name] then return "Soured" end
    local primary = container and not container:isEmpty() and container:getPrimaryFluid()
    if primary and M.ROTTEN[primary:getFluidTypeString()] then return "Rotten" end
end

-- Why a container can't clabber the crock ("Rotten", "TooLittle", "NoSour"), or nil if it can.
function M.clabberRefusal(container)
    local kind = M.clabberIn(container)
    if kind == "Rotten" then return "Rotten" end
    if not kind then return "NoSour" end
    if M.mlIn(container) < M.CLABBER_ML - 0.5 then return "TooLittle" end
end

-- Soured milk goes into an empty crock only, and it waits for fresh milk straight away.
function M.clabberCrock(crock)
    if M.crockStage(crock) ~= "Empty" then return false end
    crock.stage = "Waiting"
    crock.done = 0
    return true
end

-- Empties a ready crock. Returns how many starters it gives, 0 if it isn't ready.
function M.collectStarters(crock)
    if M.crockStage(crock) ~= "Ready" then return 0 end
    for _, key in ipairs({ "stage", "done", "marks" }) do crock[key] = nil end
    return M.CROCK_STARTERS
end

-- The station's state table, made on first use.
function M.stateOf(modData, key)
    modData[key] = modData[key] or {}
    return modData[key]
end

function M.feedCrock(crock, ledger)
    if crock.stage ~= "Waiting" then return false end
    crock.stage = "Developing"
    crock.done = 0
    markCrock(crock, ledger)
    return true
end

function M.crockHours(crock)
    return crock.stage == "Cultivating" and M.CULTIVATE_HOURS or M.DEVELOP_HOURS
end

function M.updateCrock(crock, ledger, place)
    local stage = crock.stage
    if stage ~= "Cultivating" and stage ~= "Developing" then return end
    crock.done = crock.done + Hearth.catchUp(crock, crock.marks, ledger, CROCK_KIND, place, M.cultureRate)
    if crock.done >= M.crockHours(crock) then
        crock.stage = stage == "Cultivating" and "Waiting" or "Ready"
    end
end

function M.crockStatus(crock, ledger, place)
    local temperature = M.placeTemperature(ledger, place)
    local rate = M.cultureRate(temperature)
    local hours = M.crockHours(crock)
    return {
        progress = math.min((crock.done or 0) / hours, 1),
        hoursLeft = rate > 0 and math.max(hours - (crock.done or 0), 0) / rate or nil,
        temperature = temperature,
        place = place,
        rate = rate,
    }
end

-- Sandbox

function M.applySandbox()
    local options = SandboxVars and SandboxVars.TraditionalPreservationDairy
    if not options then return end
    if options.IncubationHours then M.INCUBATE_HOURS = options.IncubationHours end
    if options.CultureHours then
        M.CULTIVATE_HOURS = options.CultureHours
        M.DEVELOP_HOURS = options.CultureHours / 2
    end
    if options.TemperatureSensitivity then M.SENSITIVITY = Weather.sensitivity(options.TemperatureSensitivity) end
    if options.MilkSpoils ~= nil then M.MILK_SPOILS = options.MilkSpoils end
    if options.MilkSpoilSpeed then M.MILK_SPEED = options.MilkSpoilSpeed end
end

Events.OnInitGlobalModData.Add(M.applySandbox)

-- Baking

-- Any milk bakes, and soured milk bakes as fresh does (clabbered milk was the old baker's buttermilk), so vanilla's
-- cake batter, muffins and cereal take all three milks (vanilla: cow's only, cereal sheep's too), fresh, scalded or
-- soured. Butter and mildew cure want fresh milk and keep their milks, scalded or not: store milk poured out is
-- scalded, so without that they would refuse what they took before.
M.SOUR_BAKING = { "Base.MakeCakeBatter", "Base.PrepareMuffins", "Base.MakeBowlOfCereal" }
M.SCALDED_ONLY = { "Base.churn_butter", "Base.MakeMildewCure" }

-- What a line naming any milk should also take: every milk, its scalded and its soured twin.
function M.bakingMilks()
    local all, extra = {}, {}
    for milk in pairs(M.SOUR_MILKS) do all[#all + 1] = milk end
    table.sort(all)
    local plain = #all
    for i = 1, plain do all[#all + 1] = M.SCALDED_MILKS[all[i]] end
    for i = 1, plain do all[#all + 1] = M.SOUR_MILKS[all[i]] end
    for milk in pairs(M.SOUR_MILKS) do extra[milk] = all end
    return extra
end

-- What a line naming a milk should also take: that milk scalded.
function M.scaldedMilks()
    local extra = {}
    for milk, scalded in pairs(M.SCALDED_MILKS) do extra[milk] = { scalded } end
    return extra
end

function M.applyBaking()
    local extra = M.bakingMilks()
    for _, recipe in ipairs(M.SOUR_BAKING) do Recipes.addFluids(recipe, extra, "TPD") end
    extra = M.scaldedMilks()
    for _, recipe in ipairs(M.SCALDED_ONLY) do Recipes.addFluids(recipe, extra, "TPD") end
end

-- Before the game builds each recipe's fluid filter (Recipes).
Events.OnInitWorld.Add(M.applyBaking)
