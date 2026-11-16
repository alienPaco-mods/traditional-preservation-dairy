-- Traditional Preservation (Dairy) B42: the rules for the Yogurt Incubator and the Starter Culture Crock.
-- The incubator is a lidded clay pot: milk brought to the boil in the hearth's cauldron cools in it by Newton's law towards the temperature where
-- it stands, and once it is down to setting heat with a starter in, the pot is wrapped in cloth and the milk
-- sets at a speed that follows its own temperature. Cooling depends on what the milk was, not only on the
-- weather now, so the core ledger's running totals can't replay it: an hourly history of the weather in
-- global ModData lets an unloaded pot catch up hour by hour. The crock is an ordinary weather-weighted run
-- on the ledger, in two stages with a feed of fresh milk between them; soured milk (a clabber) skips the first.
-- A batch is a plain table (modData[M.INCUBATOR_KEY] or [M.CROCK_KEY]); every function here works on it without the engine.
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Station = require "TraditionalPreservationCore/Station"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Recipes = require "TraditionalPreservationCore/Recipes"
local Container = require "TraditionalPreservationCore/Container"
local Portions = require "TraditionalPreservationCore/Portions"
local Tiles = require "TraditionalPreservationDairy/Tiles"
-- Carried milk (Carry) and wrapped pots, jars and buckets (Wrap) are in their own files, required at the end; their
-- functions are on M as well, so callers name M only.

-- Save keys: never rename these once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
M.MOD_DATA_KEY = "TraditionalPreservationDairy"
-- Each station keeps its state as one table under one key, so nothing else on the object can clash with it.
-- Inside the incubator's: ml, tempC, starter, incubating, wrapHour, done, last, readyHour, fluid, parts, place, at,
-- fireUntil, under; for kefir (TraditionalPreservationDairyKefir.lua) culture, grains, progress, growProgress, kefirMarks,
-- kefirAge, partGrain. Inside the crock's: stage, done, marks, fireUntil, under. The Stone Hearth and its cauldron are TP
-- Core's (TraditionalPreservationCore/Fire).
M.INCUBATOR_KEY = "tpdIncubator"
M.CROCK_KEY = "tpdCrock"
-- What an emptied pot or crock forgets (place, at, fireUntil and under stay: where it stands).
local MILK_FIELDS = { "ml", "tempC", "lastHour", "fluid", "parts" }
local BATCH_FIELDS = { "ml", "tempC", "starter", "incubating", "wrapHour", "workHours", "lastHour", "readyHour", "fluid", "parts" }
-- What an emptied kefir pot forgets: all but the part-grain it keeps for the next batch.
M.KEFIR_FIELDS = { "ml", "tempC", "lastHour", "readyHour", "fluid", "parts", "culture", "grains", "progress", "growProgress",
    "kefirMarks", "kefirAge" }
local CROCK_FIELDS = { "stage", "workHours", "marks" }

local function clear(stationModData, fields)
    for _, key in ipairs(fields) do stationModData[key] = nil end
end
M.clearFields = clear

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
-- By a banked Stone Hearth (EMBERS) it is cooler, and the embers last three times as long.
M.CAULDRON_PLAIN = Fire.PLACE
M.EMBERS = Fire.EMBERS

-- The Stone Hearth's cauldron (TP Core) holds one fluid at a time, or a blend of milks, and heats while its fire burns.
M.HOT_C = CauldronFluid.HOT_C        -- milk this hot pours from the cauldron into a pot
-- Milk counts as scalded only once it has been at HOT_C or more this long in all: the hold is what
-- changes the whey proteins and gives a firm set. The cauldron counts it (CauldronFluid.heldHours), a pot on a stove or a
-- fire too (TP Core's FluidAgeing, scaldHold).
M.SCALD_HOLD_HOURS = 1 / 3

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
local CROCK_PROCESS = "culture"
-- Grain starters are kept warm, not hot: best at 25 to 35 C, slow when cool, near stopped by 5.
local CULTURE_CURVE = { { 5, 0.03 }, { 10, 0.1 }, { 15, 0.3 }, { 20, 0.6 }, { 25, 1 }, { 35, 1 }, { 40, 0.6 }, { 45, 0.1 } }

-- Milk going off (TP Core's FluidAgeing). Raw milk sours on its own lactic bacteria, then spoils as long again after;
-- scalded milk never sours (the heat killed them) and spoils at the same age. Ages are hours at 20 C: about a day
-- and a half to sour in a 20 C room, 3 days in a 15 C basement, 8 in a fridge, a day at 30 C. Store milk (sealed
-- cartons and bottles) keeps until it is poured out, and then counts as scalded: it was pasteurised. Scalded milk goes
-- by its scalded name (Cow's Milk (Scalded, Fresh)) until raw milk is mixed in.
M.MILK_PROCESS = "milk"
M.MILK_TURN_HOURS = 36
M.MILK_SPOIL_HOURS = 72
M.MILK_SPOILS = true          -- sandbox: Milk goes off
M.MILK_SPEED = 1              -- sandbox: how fast, 1 as above, on top of vanilla's Food Spoilage
M.SOUR_MILKS = { CowMilk = "SourCowMilk", SheepMilk = "SourSheepMilk", AnimalMilk = "SourAnimalMilk" }
M.ROTTEN_MILKS = { CowMilk = "RottenCowMilk", SheepMilk = "RottenSheepMilk", AnimalMilk = "RottenAnimalMilk" }
M.SCALDED_MILKS = { CowMilk = "ScaldedCowMilk", SheepMilk = "ScaldedSheepMilk", AnimalMilk = "ScaldedAnimalMilk" }
-- The name of scalded milk's state in TP Core's FluidAgeing fluidAge.
M.SCALDED_STATE = "Scalded"
M.SCALDED = {}
for _, scalded in pairs(M.SCALDED_MILKS) do M.SCALDED[scalded] = true end
M.STORE_MILK = { ["Base.Milk"] = true, ["Base.MilkBottle"] = true, ["Base.Milk_Personalsized"] = true }
M.SOURED, M.ROTTEN = {}, {}
for milk, sour in pairs(M.SOUR_MILKS) do M.SOURED[sour], M.ROTTEN[M.ROTTEN_MILKS[milk]] = true, true end
CauldronFluid.blend("SourCowMilk", "SourSheepMilk", "SourAnimalMilk")
-- Souring speed against 20 C. Mesophilic bacteria: frozen milk stops, a fridge crawls, best near blood heat; past
-- 50 C the heat starts to kill them.
local MILK_CURVE = { { 0, 0 }, { 2, 0.12 }, { 4, 0.19 }, { 10, 0.33 }, { 15, 0.5 }, { 20, 1 }, { 25, 1.25 }, { 30, 1.5 },
    { 37, 1.8 }, { 45, 1.2 }, { 55, 0 } }

-- Yield
-- A jar takes yogurt to its vanilla capacity and is eaten from in portions of a cup, 250 ml.
M.CUPS_PER_LITRE = 4          -- 8 oz cups
M.CUP_ML = 1000 / M.CUPS_PER_LITRE   -- an Empty Yogurt Container, and one portion from a jar
M.CUP_KG = 0.25               -- a portion's weight
-- One portion's food: vanilla Yogurt's (hunger as the engine keeps it, -10 in the script), for a jar never filled at a
-- pot (a debug spawn: M.jarPortions); yogurt from a pot keeps its milk's food instead (MILK_FOOD).
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
-- cauldron, a container and a pot, as a mixed herd's milk always did. Scalded milk is milk too.
M.MILKS = { CowMilk = true, SheepMilk = true, AnimalMilk = true }
for milk, scalded in pairs(M.SCALDED_MILKS) do M.MILKS[scalded] = true end
CauldronFluid.blend("CowMilk", "SheepMilk", "AnimalMilk", "ScaldedCowMilk", "ScaldedSheepMilk", "ScaldedAnimalMilk")
M.STARTER = "TraditionalPreservationDairy.ActiveYoghurtStarter"
M.YOGHURT = "Base.Yoghurt"    -- vanilla's cup of Yogurt
-- A Jar of Yogurt gives one portion, as much as a Yogurt cup holds, and keeps the rest (M.isStarter).
M.STARTERS = { [M.YOGHURT] = "Yogurt", [M.STARTER] = "Starter", ["TraditionalPreservationDairy.JarOfYoghurt"] = "Yogurt" }
M.EMPTY_CUP = "TraditionalPreservationDairy.EmptyYoghurtContainer"
-- The jars yogurt is collected into, with the ml each holds (vanilla capacities). Clay Jars need Pottery 5 and
-- are rare loot; the glass canning jar is common.
M.JAR_ML = { ["Base.EmptyJar"] = 1000, ["Base.ClayJar"] = 2500, ["Base.ClayJarGlazed"] = 2500 }
M.SPAWNED_JAR_ML = 1000       -- a Jar of Yogurt never filled at a pot holds a glass jar's worth
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
    local parts, name = CauldronFluid.partsIn(container)
    if not M.MILKS[name] then return nil end
    return name, parts
end

-- True if the item holds at least ml of plain milk.
function M.hasMilk(item, ml)
    local container = item and item:getFluidContainer()
    return M.milkIn(container) ~= nil and M.mlIn(container) >= ml - 0.5
end

-- Only empty containers take milk or yogurt out, so nothing is ever topped up into a mixture (TP Core's).
M.isEmptyContainer = Container.isEmptyVessel

-- Which station this is ("incubator" or "crock") and which way it faces, or nil for anything else.
M.stationKind = Station.kinds(Tiles.PREFIX, M.FACE_COUNT, { incubator = M.INCUBATOR_SPRITE, crock = M.CROCK_SPRITE })

function M.isIncubator(isoObject)
    return M.stationKind(isoObject) == "incubator"
end

function M.isCrock(isoObject)
    return M.stationKind(isoObject) == "crock"
end

M.SENSITIVITY = 1

-- Core's places, then by a fire and by banked embers.
M.PLACES = {}
for _, place in ipairs(Weather.PLACES) do table.insert(M.PLACES, place) end
table.insert(M.PLACES, M.CAULDRON_PLAIN)
table.insert(M.PLACES, M.EMBERS)

M.placeTemperature = Weather.placeTemperature
M.placeOf = Fire.placeOf
M.noteFire = Fire.noteFire
-- A Stone Hearth with the cauldron fitted, and those near a square.
function M.cauldronsNear(square) return Fire.fittedNear(square, Cauldron.ID) end
function M.hasCauldron(isoObject) return Fire.isFitted(isoObject, Cauldron.ID) end

-- Temperatures: vanilla's item heat, for milk poured between our stores and the player's containers. Vanilla
-- cools a container in the player's hands to room heat within seconds, so only the cauldron and the pot keep heat.
M.heatCelsius = CauldronFluid.heatCelsius
M.itemHeat = CauldronFluid.itemHeat

-- More milk holds its heat longer: the time constant grows with the pot's size, so with the cube root of litres.
function M.tau(ml, wrapped)
    local base = wrapped and M.WRAPPED_TAU or M.LIDDED_TAU
    return base * (math.max(ml, M.TAU_FLOOR_ML) / M.CAPACITY_ML) ^ (1 / 3)
end

M.cool = CauldronFluid.cool

-- Frozen milk doesn't set (TP Core's Weather.frozen), whatever the sensitivity.
function M.setRate(milkC)
    return Weather.rate(SET_CURVE, milkC, M.SENSITIVITY)
end

-- Frozen the crock's culture pauses (TP Core's Weather.frozen), and goes on once thawed.
function M.cultureRate(celsius)
    return Weather.rate(CULTURE_CURVE, celsius, M.SENSITIVITY)
end

-- Weather ledger and history

function M.milkRate(celsius)
    return Weather.curve(MILK_CURVE, celsius)
end

-- Kefir ages on its own kind (TraditionalPreservationDairyKefir.lua), at milk's rate. In the pot it ferments on its own
-- curve, and its grains grow only while that is in their range (M.kefirRate, M.kefirGrowRate there).
M.KEFIR_PROCESS = "kefir"
M.KEFIR_FERMENT = "kefirFerment"
M.KEFIR_GROW = "kefirGrow"
local PROCESSES = { [CROCK_PROCESS] = function(celsius) return M.cultureRate(celsius) end,
    [M.MILK_PROCESS] = function(celsius) return M.milkRate(celsius) end,
    [M.KEFIR_PROCESS] = function(celsius) return M.milkRate(celsius) end,
    [M.KEFIR_FERMENT] = function(celsius) return M.kefirRate(celsius) end,
    [M.KEFIR_GROW] = function(celsius) return M.kefirGrowRate(celsius) end }

function M.newLedger(now)
    return Weather.newLedger(now, PROCESSES)
end

function M.getLedger()
    return Weather.getLedger(M.MOD_DATA_KEY, M.newLedger)
end

function M.getHistory()
    local dairyModData = ModData.getOrCreate(M.MOD_DATA_KEY)
    dairyModData.history = dairyModData.history or {}
    return dairyModData.history
end

FluidAgeing.register({
    process = M.MILK_PROCESS,
    scaldHeat = CauldronFluid.itemHeat(M.HOT_C),
    scaldHold = M.SCALD_HOLD_HOURS,
    rate = M.milkRate,
    turnHours = M.MILK_TURN_HOURS,
    spoilHours = M.MILK_SPOIL_HOURS,
    fresh = M.SOUR_MILKS,
    spoiled = M.ROTTEN_MILKS,
    -- Scalded milk is milk in a state made by heat: it never sours and keeps the plain milk's spoilHours.
    states = { [M.SCALDED_STATE] = { fluids = M.SCALDED_MILKS, heat = true } },
    sealed = M.STORE_MILK,
    getLedger = function() return M.getLedger() end,
    enabled = function() return M.MILK_SPOILS end,
    -- Vanilla's Food Spoilage setting, then Dairy's own.
    speed = function() return M.MILK_SPEED * FluidAgeing.foodRotSpeed() end,
})

-- One ten-minute reading: the ledger for the crock, and the hour's slot in the history for the incubator.
-- An hour's slot keeps the last reading in it, with the season mean that goes with it.
function M.recordWeather(ledger, history, now, temperature)
    Weather.advance(ledger, now, temperature, PROCESSES)
    local hour = math.floor(now)
    history[hour % M.HISTORY_HOURS + 1] = { hour = hour, temperature = ledger.temperature, season = ledger.seasonTemperature,
        ground = ledger.groundTemperature, grid = ledger.gridOn }
end

-- The place's temperature in a past hour, or nil when the history has no reading for it.
function M.pastTemperature(history, hour, place)
    local slot = history[hour % M.HISTORY_HOURS + 1]
    local reading = slot and slot.hour == hour and { temperature = slot.temperature, seasonTemperature = slot.season,
        groundTemperature = slot.ground, gridOn = slot.grid } or nil
    -- A fire indoors needs no reading; one under a roof or in the open does.
    if Fire.isFirePlace(place) then return Fire.fireC(place, reading) end
    if not reading then return nil end
    return Weather.placeTemperature(reading, place)
end

-- Incubator

-- Empty, Cooling, TooCold, Incubating or Ready; a kefir pot's are KefirGrains, Fermenting and KefirReady (M.kefirStage).
function M.stage(batch)
    if batch.culture == M.KEFIR_CULTURE then return M.kefirStage(batch) end
    if (batch.ml or 0) <= 0 then return "Empty" end
    if batch.readyHour then return "Ready" end
    if batch.incubating then return "Incubating" end
    if not batch.starter and batch.tempC < M.STARTER_MIN_C then return "TooCold" end
    return "Cooling"
end

-- How much of ml fits, or 0 with the reason it can't go in.
function M.milkRoom(batch, ml)
    local stage = M.stage(batch)
    if stage == "Incubating" or stage == "Ready" or stage == "KefirReady" then return 0, stage end
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
    if fluid then CauldronFluid.addParts(batch, fluid, taken) end
    batch.ml = had + taken
    batch.lastHour = batch.lastHour or now
    return taken
end

-- The starter waits beside the pot until the milk is down to setting heat. It can go in before the milk.
function M.canAddStarter(batch)
    if batch.culture == M.KEFIR_CULTURE then return false, "KefirPot" end
    if batch.starter then return false, "HasStarter" end
    local stage = M.stage(batch)
    if stage == "Incubating" or stage == "Ready" then return false, stage end
    if stage == "TooCold" then return false, "TooCold" end
    return true
end

function M.addStarter(batch, starter)
    local ok, reason = M.canAddStarter(batch)
    if not ok then return false, reason end
    batch.starter = starter
    return true
end

-- Takes up to maxMl of the milk back out (to reheat it), all of it if left out. Returns the ml, its
-- temperature and the ml by fluid. The starter, if any, stays for the next pour.
function M.pourOut(batch, maxMl)
    local stage = M.stage(batch)
    if stage ~= "Cooling" and stage ~= "TooCold" then return 0 end
    local ml, tempC = math.min(batch.ml, maxMl or batch.ml), batch.tempC
    local parts = CauldronFluid.partsOf(batch, ml)
    batch.ml = batch.ml - ml
    if batch.ml <= 0 then clear(batch, MILK_FIELDS) end
    return ml, tempC, parts
end

-- Runs the pot for hours at one place temperature, from hour now. Each step cools exactly; the wrap goes on
-- the moment the milk crosses SET_C (on the step's reading it went on a degree or two cold, and
-- November's pots indoors never set), and the yogurt is done within a step's resolution.
function M.advanceBatch(batch, hours, placeC, now)
    if (batch.ml or 0) <= 0 then return end
    local elapsed = 0
    while elapsed < hours - 1e-9 do
        local step = math.min(M.STEP_HOURS, hours - elapsed)
        local wrapped = batch.incubating and not batch.readyHour
        local before = batch.tempC
        batch.tempC = M.cool(before, placeC, step, M.tau(batch.ml, wrapped))
        if not batch.incubating and batch.starter and before > M.SET_C and batch.tempC < M.SET_C then
            -- Cooling is exponential, so the crossing is exact: lidded to SET_C, wrapped for the rest of the step.
            local cross = M.tau(batch.ml, false) * math.log((before - placeC) / (M.SET_C - placeC))
            batch.tempC = M.cool(M.SET_C, placeC, step - cross, M.tau(batch.ml, true))
            batch.incubating, batch.wrapHour = true, now + elapsed + cross   -- read by tools/season_report.lua
            batch.workHours = M.setRate(batch.tempC) * (step - cross)
        end
        elapsed = elapsed + step
        if not batch.incubating and batch.starter and batch.tempC <= M.SET_C then
            batch.incubating = true
            batch.wrapHour = now + elapsed   -- read by tools/season_report.lua
            batch.workHours = 0
        elseif wrapped then
            batch.workHours = batch.workHours + M.setRate(batch.tempC) * step
            if batch.workHours >= M.INCUBATE_HOURS then batch.readyHour = now + elapsed end
        end
    end
end

-- By a fire until it burns out (fireUntil), then the place under it.
local function placeAt(milk, place, hour)
    if Fire.isFirePlace(place) and milk.fireUntil and hour >= milk.fireUntil then return milk.placeWithoutFire or Weather.DEFAULT_PLACE end
    return place
end

-- Where a stretch from walkedTo that would end at stop ends instead: when the fire it stands by burns out, if that is sooner.
local function fireStop(milk, place, walkedTo, stop)
    if Fire.isFirePlace(place) and milk.fireUntil and walkedTo < milk.fireUntil then return math.min(stop, milk.fireUntil) end
    return stop
end

-- Walks a pot or carried milk (milk, with its fireUntil and placeWithoutFire) from hour walkedTo to now, at place: one stretch an hour,
-- broken where the fire burns out, each at the history's reading for that hour (the ledger's now where it has none).
-- step(from, to, placeC) runs each stretch.
function M.walkHours(milk, place, walkedTo, now, history, ledger, step)
    while walkedTo < now do
        local hour = math.floor(walkedTo)
        local stop = fireStop(milk, place, walkedTo, math.min(hour + 1, now))
        local here = placeAt(milk, place, walkedTo)
        step(walkedTo, stop, M.pastTemperature(history, hour, here) or M.placeTemperature(ledger, here))
        walkedTo = stop
    end
end

-- Runs the pot for a long spell at one place temperature. Ten-minute steps only while a started pot is still
-- settling to the place; after that nothing changes but at a steady rate, so the rest is one exact step.
function M.advanceSpell(batch, hours, placeC, now)
    if (batch.ml or 0) <= 0 then return end
    local elapsed = 0
    while elapsed < hours - 1e-9 and batch.starter and not batch.readyHour and math.abs(batch.tempC - placeC) >= SETTLED_C do
        local step = math.min(M.STEP_HOURS, hours - elapsed)
        M.advanceBatch(batch, step, placeC, now + elapsed)
        elapsed = elapsed + step
    end
    local left = hours - elapsed
    if left <= 1e-9 then return end
    if batch.starter and not batch.incubating and batch.tempC <= M.SET_C then
        batch.incubating, batch.wrapHour, batch.workHours = true, now + elapsed, 0
    end
    local wrapped = batch.incubating and not batch.readyHour
    if wrapped then
        local rate, need = M.setRate(batch.tempC), M.INCUBATE_HOURS - batch.workHours
        if rate * left >= need then
            batch.workHours, batch.readyHour = M.INCUBATE_HOURS, now + elapsed + need / rate
        else
            batch.workHours = batch.workHours + rate * left
        end
    end
    batch.tempC = M.cool(batch.tempC, placeC, left, M.tau(batch.ml, wrapped))
end

-- Brings the pot up to now: hour by hour through the history, at the place's current temperature where the
-- history has no reading (a gap longer than it keeps, or the hour now). The hours before the history all read
-- alike, so they run as one spell (two when a fire burnt out in them), however long the pot was away.
function M.catchUp(batch, now, place, history, ledger)
    if (batch.ml or 0) <= 0 then batch.lastHour = now return end
    -- A kefir pot's milk cools as a lidded pot's, with no wrap: no starter, so advanceBatch only cools it.
    local walkedTo = batch.lastHour or now
    local kept = math.floor(now) - M.HISTORY_HOURS + 1
    while walkedTo < kept do
        local stop = fireStop(batch, place, walkedTo, kept)
        M.advanceSpell(batch, stop - walkedTo, M.placeTemperature(ledger, placeAt(batch, place, walkedTo)), walkedTo)
        walkedTo = stop
    end
    M.walkHours(batch, place, walkedTo, now, history, ledger, function(from, to, placeC)
        M.advanceBatch(batch, to - from, placeC, from)
    end)
    batch.lastHour = now
    if batch.culture == M.KEFIR_CULTURE then M.fermentKefir(batch, now, place, ledger) end
end

-- Days since the yogurt set, for the jar's food age: freshness carries over and never resets.
function M.ageDays(batch, now)
    return batch.readyHour and math.max(now - batch.readyHour, 0) / 24 or 0
end

-- One portion's food from the pot's milk, by its shares of each kind.
function M.portionFood(batch)
    local parts = CauldronFluid.partsOf(batch, 1)
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
    if batch.ml <= 0 then clear(batch, BATCH_FIELDS) end
    return ml, age, food
end

-- Fills one jar of the given type to its size.
function M.collectJar(batch, now, jarType)
    return collect(batch, now, M.JAR_ML[jarType])
end

-- How many of the given jars (types, in order) the ml fill: the last may be part-full.
function M.jarsFor(ml, jarTypes)
    local count = 0
    for _, jarType in ipairs(jarTypes) do
        if ml <= 0 then break end
        ml = ml - M.JAR_ML[jarType]
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
    if stage == "Empty" or stage == "Ready" or stage == "TooCold" or batch.culture then return nil end
    local hours, limit = 0, 96
    while hours < limit do
        M.advanceBatch(copy, M.STEP_HOURS, placeC, hours)
        hours = hours + M.STEP_HOURS
        local now = M.stage(copy)
        if now ~= stage then return hours, now end
    end
    return nil
end

-- Stone Hearth cauldron: the rules are TP Core's; these are milk's.

-- Hours until the cauldron is hot if the fire burns on; 0 if it is already, nil if it holds no milk or the fire is
-- banked.
function M.hoursToHot(cauldron, banked)
    if not M.MILKS[cauldron.fluid] then return nil end
    return CauldronFluid.hoursToHot(cauldron, banked)
end

function M.cauldronHot(cauldron)
    return M.MILKS[cauldron.fluid] == true and (cauldron.tempC or 0) >= M.HOT_C
end

-- True once the cauldron's milk has steamed for the hold: what may go into the pot.
function M.held(hours)
    return (hours or 0) >= M.SCALD_HOLD_HOURS - 1e-9
end

function M.cauldronScalded(cauldron)
    return M.cauldronHot(cauldron) and M.held(CauldronFluid.heldHours(cauldron))
end

-- Minutes of the hold still to go for the cauldron's milk (0 once held).
function M.holdMinutesLeft(cauldron)
    return math.max(math.ceil((M.SCALD_HOLD_HOURS - CauldronFluid.heldHours(cauldron)) * 60 - 1e-6), 0)
end

-- Fills the pot from the cauldron with hot milk, as much as fits. Returns the ml (0 with a reason when refused).
function M.cauldronToPot(cauldron, batch, now)
    if not M.cauldronHot(cauldron) then return 0, M.MILKS[cauldron.fluid] and "NotHot" or "NoMilk" end
    if not M.cauldronScalded(cauldron) then return 0, "NotHeld" end
    local room, reason = M.milkRoom(batch, cauldron.ml)
    if room <= 0 then return 0, reason end
    local ml, _, tempC, parts = CauldronFluid.take(cauldron, room)
    M.addMilk(batch, ml, tempC, now, parts)
    return ml
end

M.mlIn = Container.ml


-- Crock: Cultivating, then Waiting for fresh milk, then Developing, then Ready.

-- The ledger keeps totals for the weather's places only, so time by a fire counts by the clock (Fire.catchUp).
local function markCrock(crock, ledger)
    crock.marks = Weather.mark({}, ledger, CROCK_PROCESS)
end

function M.startCrock(crock, ledger)
    crock.stage = "Cultivating"
    crock.workHours = 0
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

-- Why ml of milk at celsius, from the cauldron or a container, can't load the crock, or nil if it can.
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
    local parts, name = CauldronFluid.partsIn(container)
    if parts and M.SOURED[name] then return "Soured" end
    local primary = container and not container:isEmpty() and container:getPrimaryFluid()
    if primary and M.ROTTEN[primary:getFluidTypeString()] then return "Rotten" end
end

-- Why a container can't clabber the crock ("Rotten", "TooLittle", "NoSour"), or nil if it can.
function M.clabberRefusal(container)
    local clabber = M.clabberIn(container)
    if clabber == "Rotten" then return "Rotten" end
    if not clabber then return "NoSour" end
    if M.mlIn(container) < M.CLABBER_ML - 0.5 then return "TooLittle" end
end

-- Soured milk goes into an empty crock only, and it waits for fresh milk straight away.
function M.clabberCrock(crock)
    if M.crockStage(crock) ~= "Empty" then return false end
    crock.stage = "Waiting"
    crock.workHours = 0
    return true
end

-- Empties a ready crock. Returns how many starters it gives, 0 if it isn't ready.
function M.collectStarters(crock)
    if M.crockStage(crock) ~= "Ready" then return 0 end
    clear(crock, CROCK_FIELDS)
    return M.CROCK_STARTERS
end

-- The station's own table under key in its modData, made on first use.
function M.stationModData(modData, key)
    modData[key] = modData[key] or {}
    return modData[key]
end

-- A pot's batch or a crock's culture as saved, not brought up to now (the World's updateIncubator / updateCrock do that): for
-- checks that run every tick of an action.
function M.batchOf(station)
    return M.stationModData(Station.movableData(station), M.INCUBATOR_KEY)
end

function M.crockOf(station)
    return M.stationModData(Station.movableData(station), M.CROCK_KEY)
end

function M.feedCrock(crock, ledger)
    if crock.stage ~= "Waiting" then return false end
    crock.stage = "Developing"
    crock.workHours = 0
    markCrock(crock, ledger)
    return true
end

function M.crockHours(crock)
    return crock.stage == "Cultivating" and M.CULTIVATE_HOURS or M.DEVELOP_HOURS
end

function M.updateCrock(crock, ledger, place)
    local stage = crock.stage
    if stage ~= "Cultivating" and stage ~= "Developing" then return end
    crock.workHours = crock.workHours + Fire.catchUp(crock, crock.marks, ledger, CROCK_PROCESS, place, M.cultureRate)
    if crock.workHours >= M.crockHours(crock) then
        crock.stage = stage == "Cultivating" and "Waiting" or "Ready"
    end
end

function M.crockStatus(crock, ledger, place)
    local temperature = M.placeTemperature(ledger, place)
    local rate = M.cultureRate(temperature)
    local hours = M.crockHours(crock)
    return {
        progress = math.min((crock.workHours or 0) / hours, 1),
        hoursLeft = rate > 0 and math.max(hours - (crock.workHours or 0), 0) / rate or nil,
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

-- The parts in their own files: wrapping first, as carried milk asks whether its pot is wrapped.
require "TraditionalPreservationDairyWrap"
require "TraditionalPreservationDairyCarry"
require "TraditionalPreservationDairyButter"
require "TraditionalPreservationDairyKefir"
