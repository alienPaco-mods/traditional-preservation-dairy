-- Traditional Preservation (Dairy): kefir. Milk fermented by kefir grains in the Yogurt Incubator (the culture comes
-- in K2): no scald, no wrap, at the place's temperature. Kefir is a fluid, its milk's food less the lactose the grains
-- ate. A fluid's food is its type's, so cow's and sheep's milk each make a kefir of their own, mixed by share as the
-- milks were; both are called Kefir, as the engine shows two fluids of one name as one (three or more read Mixed
-- Beverages), so there are only two. Animal's milk (vanilla's, from Milk Powder and water: kefir grains ferment
-- reconstituted milk too) has cow's food, so it makes the cow's: never a third. Always a little sour; left long it over-ferments and separates into curds and whey (Separated, at
-- about 3 days at 20 C), then rots (about 10), on milk's curve through TP Core's FluidAgeing. Fresh kefir
-- eases food sickness, 10 a litre, through TP Core's Drink, on the shared "foodSickness" cooldown of 3 game hours.
-- Grains come only from loot, as a packet of dried ones; each grain is an item of a gram. Live grains keep their grainState
-- in modData (and the hour it was last set), and their own starving clock, so the grains from one batch can be split any
-- way. Out of milk they go Hungry, then die, on milk's curve; a place too hot weakens or kills them. Spread on a cloth
-- they dry where they lie, and keep. Required by TraditionalPreservationDairy.lua, whose M it adds to.
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Drink = require "TraditionalPreservationCore/Drink"

-- Kefir fluids: each milk (scalded too) to the kefir it makes; each kefir to its separated and rotten ones.
M.KEFIRS = { CowMilk = "CowKefir", SheepMilk = "SheepKefir", AnimalMilk = "CowKefir",
    ScaldedCowMilk = "CowKefir", ScaldedSheepMilk = "SheepKefir", ScaldedAnimalMilk = "CowKefir" }
M.SEPARATED_KEFIRS = { CowKefir = "SeparatedCowKefir", SheepKefir = "SeparatedSheepKefir" }
M.ROTTEN_KEFIRS = { CowKefir = "RottenCowKefir", SheepKefir = "RottenSheepKefir" }
-- Hours at 20 C (milk's curve: a fridge about 5 times as long, a 15 C basement twice).
M.KEFIR_SEPARATE_HOURS = 72
M.KEFIR_ROT_HOURS = 240
-- Fresh kefir's cure: food sickness eased a litre drunk, and the shared cooldown (TP Core's Drink and Cooldown).
M.KEFIR_FOOD_SICKNESS = 10
M.FOOD_SICKNESS_COOLDOWN = "foodSickness"
M.KEFIR_COOLDOWN_HOURS = 3

FluidAgeing.register({
    process = M.KEFIR_PROCESS,
    rate = M.milkRate,
    turnHours = M.KEFIR_SEPARATE_HOURS,
    spoilHours = M.KEFIR_ROT_HOURS,
    fresh = M.SEPARATED_KEFIRS,
    spoiled = M.ROTTEN_KEFIRS,
    getLedger = function() return M.getLedger() end,
    enabled = function() return M.MILK_SPOILS end,
    speed = function() return M.MILK_SPEED * FluidAgeing.foodRotSpeed() end,
})

for kefir in pairs(M.SEPARATED_KEFIRS) do
    Drink.cure(kefir, { foodSickness = M.KEFIR_FOOD_SICKNESS, cooldown = M.FOOD_SICKNESS_COOLDOWN,
        hours = M.KEFIR_COOLDOWN_HOURS })
end

-- Grains
M.GRAIN_PACKET = "TraditionalPreservationDairy.KefirGrainsPacket"
M.DRIED_GRAIN = "TraditionalPreservationDairy.DriedKefirGrains"
M.GRAIN = "TraditionalPreservationDairy.KefirGrains"
M.GRAINS_IN_PACKET = 10
-- Save key on a live grain: never rename it once the mod is out. Inside: grainState, stage (batches done reactivating),
-- hour (the world hour the grainState was last set), clock (its starving clock, M.newGrainClock).
M.GRAIN_KEY = "tpdGrain"
M.GRAIN_LIVE, M.GRAIN_HUNGRY, M.GRAIN_REACTIVATING, M.GRAIN_DEAD = "Live", "Hungry", "Reactivating", "Dead"
-- Dried grains come back over this many batches.
M.REACTIVATE_BATCHES = 2
-- What a grain counts for in a batch's speed, by grainState, and whether it grows: a dead one is refused.
M.GRAIN_WORK = {
    [M.GRAIN_LIVE] = { share = 1, grows = true },
    [M.GRAIN_HUNGRY] = { share = 0.5, grows = false },
    [M.GRAIN_REACTIVATING] = { share = 0.5, grows = false },
}

-- A new grain: Live unless said, set at `hour`. A dried grain put in milk starts Reactivating at stage 0.
function M.newGrain(grainState, hour)
    return { grainState = grainState or M.GRAIN_LIVE, stage = 0, hour = hour }
end

-- A grain item's saved grain, made Live at `hour` if it has none (a grain from the console or a debug spawn).
function M.grainOf(item, hour)
    local itemModData = item:getModData()
    itemModData[M.GRAIN_KEY] = itemModData[M.GRAIN_KEY] or M.newGrain(M.GRAIN_LIVE, hour)
    return itemModData[M.GRAIN_KEY]
end

-- Starving: out of milk (on their own, or left in a finished batch) grains go Hungry at GRAIN_HUNGRY_HOURS and die at
-- GRAIN_DEAD_HOURS, hours at 20 C on milk's curve (a fridge about 5 times as long, frozen they wait). In milk they don't
-- starve. A place over GRAIN_HUNGRY_C turns live grains Hungry, over GRAIN_DEAD_C kills them, in milk or out. Grains
-- coming back from dried don't go Hungry: they die at GRAIN_DEAD_HOURS.
M.GRAIN_HUNGRY_HOURS = 48
M.GRAIN_DEAD_HOURS = 168
-- The starving clock's ageing (a TP Core FluidAgeing kind): the kefir process, counted at milk's rate.
M.GRAIN_STARVING = { process = M.KEFIR_PROCESS, rate = M.milkRate }

local Weather = require "TraditionalPreservationCore/Weather"

-- A clock: starve, a FluidAgeing age (its age is the hours starved, its place where the grains were last seen), and the
-- ledger marks of the two heats.
function M.newGrainClock(ledger, now, place)
    return { starve = FluidAgeing.newFluidAge(M.GRAIN_STARVING, ledger, now, place),
        hot = Weather.mark({}, ledger, M.GRAIN_HOT), kill = Weather.mark({}, ledger, M.GRAIN_KILL) }
end

-- Hours a heat's process counted at place since the marks (none in a fridge, a freezer or by a fire), the marks moved on.
local function hoursOver(marks, ledger, process, place)
    local total = place and ledger[process .. place]
    local hours = total and total - (marks[place] or total) or 0
    Weather.mark(marks, ledger, process)
    return hours
end

-- Brings a clock up to now at the place it was seen in last, and counts from place on (by a fire, fireNote: the pot's
-- noted fire, else the clock's own). Returns the hours starved since, and the hours over each heat.
function M.advanceGrainClock(clock, ledger, now, place, fireNote)
    local was = clock.starve.place
    local hot = hoursOver(clock.hot, ledger, M.GRAIN_HOT, was)
    local killed = hoursOver(clock.kill, ledger, M.GRAIN_KILL, was)
    local before = clock.starve.age
    FluidAgeing.advance(clock.starve, M.GRAIN_STARVING, ledger, now, place, fireNote)
    return clock.starve.age - before, hot, killed
end

-- What a grain in grainState becomes, starved so many hours in all, after hours over each heat.
function M.grainFate(grainState, starved, hot, killed)
    if grainState == M.GRAIN_DEAD or killed > 0 or starved >= M.GRAIN_DEAD_HOURS then return M.GRAIN_DEAD end
    if grainState == M.GRAIN_LIVE and (hot > 0 or starved >= M.GRAIN_HUNGRY_HOURS) then return M.GRAIN_HUNGRY end
    return grainState
end

-- A grain item's name says its grainState: Kefir Grains (Live), (Hungry), (Reviving), (Dead).
function M.nameGrain(item, grain)
    local name = getText("IGUI_TraditionalPreservationDairy_GrainName", getText("IGUI_TraditionalPreservationDairy_Grain" .. grain.grainState))
    if item:getName() ~= name then
        item:setName(name)
        item:setCustomName(true)
    end
end

-- Brings a grain item's clock up to now, where it is (or place), and its grainState and name with it. The first look
-- starts the clock. Returns its grain. A drying cloth of grains is kept by M.keepDrying.
function M.keepGrain(item, now, place, ledger)
    if item:getFullType() == M.GRAIN_DRYING then return M.keepDrying(item, now, place, ledger) end
    if item:getFullType() ~= M.GRAIN then return nil end
    now = now or getGameTime():getWorldAgeHours()
    ledger = ledger or M.getLedger()
    local grain = M.grainOf(item, now)
    local fire, holder
    if not place then place, fire, holder = FluidAgeing.placeOfItem(item) end
    place = place or (grain.clock and grain.clock.starve.place) or Weather.DEFAULT_PLACE
    if grain.grainState ~= M.GRAIN_DEAD then
        if not grain.clock then
            grain.clock = M.newGrainClock(ledger, now, place)
        else
            local _, hot, killed = M.advanceGrainClock(grain.clock, ledger, now, place)
            local fate = M.grainFate(grain.grainState, grain.clock.starve.age, hot, killed)
            if fate ~= grain.grainState then
                grain.grainState, grain.hour = fate, now
                if fate == M.GRAIN_DEAD then grain.clock = nil end
            end
        end
        if holder and grain.clock then FluidAgeing.noteFire(grain.clock.starve, fire, holder, now) end
    end
    M.nameGrain(item, grain)
    return grain
end

-- A grain item's record for a grain of key, starved so many hours already, its clock counting from place.
function M.grainRecord(key, hour, starved, ledger, place)
    local grain = M.grainOfKey(key, hour)
    if grain.grainState ~= M.GRAIN_DEAD then
        grain.clock = M.newGrainClock(ledger, hour, place)
        grain.clock.starve.age = starved or 0
    end
    return grain
end

-- What a grain counts for in a batch (0 when dead), and whether it grows.
function M.grainShare(grain)
    local work = M.GRAIN_WORK[grain.grainState]
    if not work then return 0, false end
    return work.share, work.grows
end

-- The pot: kefir in the Yogurt Incubator (K2)
-- Grains go into an empty pot first: that makes it a kefir pot (culture), one culture at a time. Then any milk, raw or
-- scalded, from a container or the cauldron. No scald, no wrap: a linen cap. The milk ferments at the speed of the
-- place's temperature (kefirRate), times the grains' share of the milk: a live grain to every 40 ml is full speed, more
-- grains no faster. The grains in the pot are counts by grain key (Live, Hungry, Reactivating0, Reactivating1).
-- The milk's own heat matters only where it meets the grains: over GRAIN_DEAD_C it is refused (it would kill them),
-- over GRAIN_HUNGRY_C the live grains come out Hungry. Kefir waits in the pot once ready, ageing as kefir (kefirAge,
-- TP Core's FluidAgeing), until it is strained: the grains come out with the first strain.
M.KEFIR_CULTURE = "kefir"
M.KEFIR_HOURS = 24            -- hours to ferment at full speed and full grains
M.ML_PER_GRAIN = 40           -- milk a live grain ferments at full speed
M.GRAIN_GROWTH = 0.1          -- a good batch adds this share of its live grains
M.GROW_LOW_C, M.GROW_HIGH_C = 15, 28   -- the grains grow only in this range
M.GRAIN_HUNGRY_C = 35         -- milk hotter than this weakens live grains: they come out Hungry
M.GRAIN_DEAD_C = 45           -- and hotter than this would kill them: refused
-- Speed by the place's temperature, 1 = 24 h at full grains: frozen pauses, cold crawls, warm is quicker.
local KEFIR_CURVE = { { 4, 0.15 }, { 10, 0.35 }, { 15, 0.6 }, { 18, 1 }, { 25, 1 }, { 28, 1.3 }, { 30, 1.5 } }
-- What a strain takes: vanilla's Strainer, or a cloth at twice the time (the butter's cloths). None is used up.
M.STRAINER = "Base.Strainer"
M.STRAIN_CLOTHS = { "Base.CheeseCloth", "Base.DishCloth", "Base.RippedSheets", "Base.Sheet" }
M.CLOTH_STRAIN_TIMES = 2

local Fire = require "TraditionalPreservationCore/Fire"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"

function M.kefirRate(celsius)
    return Weather.rate(KEFIR_CURVE, celsius, M.SENSITIVITY)
end

function M.kefirGrowRate(celsius)
    if celsius < M.GROW_LOW_C or celsius > M.GROW_HIGH_C then return 0 end
    return M.kefirRate(celsius)
end

-- An hour over each heat counts 1 on its process.
function M.grainHotRate(celsius)
    return celsius > M.GRAIN_HUNGRY_C and 1 or 0
end

function M.grainKillRate(celsius)
    return celsius > M.GRAIN_DEAD_C and 1 or 0
end

-- A grain's key in the pot's counts: its grainState, and for one coming back from dried its stage.
function M.grainKey(grain)
    if grain.grainState == M.GRAIN_REACTIVATING then return M.GRAIN_REACTIVATING .. (grain.stage or 0) end
    return grain.grainState
end

-- The grain a key stands for, set at hour.
function M.grainOfKey(key, hour)
    local stage = key:match("^" .. M.GRAIN_REACTIVATING .. "(%d+)$")
    if stage then return { grainState = M.GRAIN_REACTIVATING, stage = tonumber(stage), hour = hour } end
    return M.newGrain(key, hour)
end

-- The grain an item brings: a dried one comes back over REACTIVATE_BATCHES, a live one is its record brought up to now.
-- Nil for anything else.
function M.grainOfItem(item, hour)
    local fullType = item:getFullType()
    if fullType == M.DRIED_GRAIN then return M.newGrain(M.GRAIN_REACTIVATING, hour) end
    if fullType == M.GRAIN then return M.keepGrain(item, hour) end
end

-- The pot's grains out of milk: lots, each { key, n, age } (age: hours starved), so grains put in apart keep their own
-- clocks; the pot's grainClock counts the hours for them all. Lots are kept only while the grains are unfed: on their
-- own, or once the batch is done (all starting at Ready). In milk the counts alone do.
local function lotsOf(batch)
    if not batch.grainLots then
        batch.grainLots = {}
        for key, n in pairs(batch.grains or {}) do table.insert(batch.grainLots, { key = key, n = n, age = 0 }) end
    end
    return batch.grainLots
end

-- Adds n grains of key starved age hours to lots, joining a lot of the same key and age.
local function addLot(lots, key, n, age)
    for _, lot in ipairs(lots) do
        if lot.key == key and math.abs(lot.age - age) < 1e-6 then
            lot.n = lot.n + n
            return
        end
    end
    table.insert(lots, { key = key, n = n, age = age })
end

-- The key a grain of key is under after starving to age and the hours over each heat.
local function fateOfKey(key, age, hot, killed)
    local grainState = M.grainOfKey(key).grainState
    local fate = M.grainFate(grainState, age, hot, killed)
    return fate == grainState and key or fate
end

-- The pot's grains after starved more hours (unfed lots only) and hours over each heat: they go Hungry or die.
function M.grainFates(batch, starved, hot, killed)
    if not batch.grains then return end
    if batch.grainLots then
        local lots = {}
        for _, lot in ipairs(batch.grainLots) do
            local age = lot.age + starved
            addLot(lots, fateOfKey(lot.key, age, hot, killed), lot.n, age)
        end
        batch.grainLots, batch.grains = lots, {}
        for _, lot in ipairs(lots) do batch.grains[lot.key] = (batch.grains[lot.key] or 0) + lot.n end
        return
    end
    local grains = {}
    for key, n in pairs(batch.grains) do
        local outKey = fateOfKey(key, 0, hot, killed)
        grains[outKey] = (grains[outKey] or 0) + n
    end
    batch.grains = grains
end

-- Brings the pot's grains up to now at place: unfed they starve; in milk only the place's heat reaches them.
function M.keepPotGrains(batch, now, place, ledger)
    if not batch.grains then return end
    if not batch.grainClock then
        batch.grainClock = M.newGrainClock(ledger, now, place)
        return
    end
    local starved, hot, killed = M.advanceGrainClock(batch.grainClock, ledger, now, place, batch)
    M.grainFates(batch, starved, hot, killed)
end

-- A batch done: the grains come out of it as grainsAfter says (grown, hungry ones live again, dried ones a stage on),
-- and from Ready they starve, all alike, starved hours since.
local function finishGrains(batch, starved)
    batch.grains, batch.partGrain = M.grainsAfter(batch)
    batch.grainsDone = true
    batch.grainLots = {}
    for key, n in pairs(batch.grains) do addLot(batch.grainLots, key, n, 0) end
    M.grainFates(batch, starved, 0, 0)
end

local function grainsOf(batch)
    batch.grains = batch.grains or {}
    return batch.grains
end

-- Grains in the pot, and what they count for together (each by its share).
function M.grainCount(batch)
    local count, work = 0, 0
    for key, n in pairs(batch.grains or {}) do
        count = count + n
        work = work + n * (M.grainShare(M.grainOfKey(key)))
    end
    return count, work
end

-- Live grains to bring ml to full speed.
function M.grainsFor(ml)
    return math.ceil(ml / M.ML_PER_GRAIN - 1e-9)
end

-- The grains' share of full speed for the milk in the pot: 1 at a live grain to every 40 ml or more.
function M.kefirRatio(batch)
    local ml = batch.ml or 0
    if ml <= 0 then return 0 end
    local _, work = M.grainCount(batch)
    return math.min(work * M.ML_PER_GRAIN / ml, 1)
end

-- Empty, KefirGrains (grains, no milk yet), Fermenting or KefirReady. An empty pot has no culture.
function M.kefirStage(batch)
    local grains = M.grainCount(batch)
    if (batch.ml or 0) <= 0 then return grains > 0 and "KefirGrains" or "Empty" end
    if batch.readyHour then return "KefirReady" end
    return "Fermenting"
end

-- What milk at celsius does to the grains it meets: nil, "Hungry" (live ones are weakened) or "TooHot" (refused).
function M.grainHeat(celsius)
    if celsius > M.GRAIN_DEAD_C then return "TooHot" end
    if celsius > M.GRAIN_HUNGRY_C then return M.GRAIN_HUNGRY end
end

local function weaken(batch)
    local grains = grainsOf(batch)
    if (grains[M.GRAIN_LIVE] or 0) > 0 then
        grains[M.GRAIN_HUNGRY] = (grains[M.GRAIN_HUNGRY] or 0) + grains[M.GRAIN_LIVE]
        grains[M.GRAIN_LIVE] = nil
    end
end

local function markKefir(batch, ledger)
    batch.kefirMarks = { ferment = Weather.mark({}, ledger, M.KEFIR_FERMENT), grow = Weather.mark({}, ledger, M.KEFIR_GROW) }
end

-- Why grains can't go into the pot ("HasStarter", "YoghurtMilk", "KefirReady", "TooHot"), or nil.
function M.grainRefusal(batch)
    local stage = M.stage(batch)
    if stage == "KefirReady" then return "KefirReady" end
    if not batch.culture then
        if batch.starter then return "HasStarter" end
        if stage ~= "Empty" then return "YoghurtMilk" end
    end
    if (batch.ml or 0) > 0 and M.grainHeat(batch.tempC or 0) == "TooHot" then return "TooHot" end
end

-- Puts grains in (a list of grain records), making the pot a kefir pot. Milk already in that is warm weakens the live
-- ones. Into a pot with no milk, each keeps the hours it has starved. Returns how many went in (0 with a reason when
-- refused).
function M.addGrains(batch, grains, ledger, now)
    local reason = M.grainRefusal(batch)
    if reason then return 0, reason end
    -- Lots made before any grain goes in, from the grains already there.
    local lots = (batch.ml or 0) <= 0 and lotsOf(batch)
    local count = 0
    for _, grain in ipairs(grains) do
        if M.grainShare(grain) > 0 then
            local key = M.grainKey(grain)
            grainsOf(batch)[key] = (grainsOf(batch)[key] or 0) + 1
            if lots then addLot(lots, key, 1, grain.clock and grain.clock.starve.age or 0) end
            count = count + 1
        end
    end
    if count == 0 then
        if M.grainCount(batch) == 0 then batch.grainLots = nil end
        return 0, "Dead"
    end
    batch.grainClock = batch.grainClock or M.newGrainClock(ledger, now or ledger.lastHour, batch.place or Weather.DEFAULT_PLACE)
    batch.culture = M.KEFIR_CULTURE
    if (batch.ml or 0) > 0 and M.grainHeat(batch.tempC or 0) == M.GRAIN_HUNGRY then weaken(batch) end
    if (batch.ml or 0) > 0 and not batch.kefirMarks then markKefir(batch, ledger) end
    return count
end

-- Why ml of milk at milkC can't go into the kefir pot, or nil: the heat it mixes to with what is there.
function M.kefirMilkRefusal(batch, ml, milkC)
    local taken, reason = M.milkRoom(batch, ml)
    if taken <= 0 then return reason end
    local had = batch.ml or 0
    local mixedC = had > 0 and (batch.tempC * had + milkC * taken) / (had + taken) or milkC
    if M.grainHeat(mixedC) == "TooHot" then return "TooHot" end
end

-- Pours milk (a name, or its ml by fluid) into the kefir pot. Fresh milk dilutes what has fermented so far. Returns the
-- ml taken (0 with a reason when refused).
function M.addKefirMilk(batch, ml, milkC, now, fluid, ledger)
    local reason = M.kefirMilkRefusal(batch, ml, milkC)
    if reason then return 0, reason end
    local had = batch.ml or 0
    local taken = M.addMilk(batch, ml, milkC, now, fluid)
    if taken <= 0 then return 0 end
    batch.progress = (batch.progress or 0) * had / batch.ml
    batch.growProgress = (batch.growProgress or 0) * had / batch.ml
    -- Fed: the grains stop starving.
    batch.grainLots = nil
    if M.grainHeat(batch.tempC) == M.GRAIN_HUNGRY then weaken(batch) end
    if not batch.kefirMarks then markKefir(batch, ledger) end
    return taken
end

-- Brings a fermenting pot up to the ledger's last record at place; a ready one's kefir ages on. When it finishes
-- inside the stretch, the part after that counts as the kefir's age, at the place's rate now.
function M.fermentKefir(batch, now, place, ledger)
    M.keepPotGrains(batch, now, place, ledger)
    local stage = M.kefirStage(batch)
    if stage == "KefirReady" then
        if batch.kefirAge then FluidAgeing.advance(batch.kefirAge, FluidAgeing.fluidKind(M.KEFIR_PROCESS), ledger, now, place, batch) end
        return
    end
    if stage ~= "Fermenting" then return end
    if not batch.kefirMarks then return markKefir(batch, ledger) end
    local from = batch.kefirMarks.ferment.hour or ledger.lastHour
    local work = Fire.catchUp(batch, batch.kefirMarks.ferment, ledger, M.KEFIR_FERMENT, place, M.kefirRate)
    local grow = Fire.catchUp(batch, batch.kefirMarks.grow, ledger, M.KEFIR_GROW, place, M.kefirGrowRate)
    local ratio = M.kefirRatio(batch) / M.KEFIR_HOURS
    local step, growStep = work * ratio, grow * ratio
    local progress = batch.progress or 0
    if progress + step < 1 then
        batch.progress, batch.growProgress = progress + step, (batch.growProgress or 0) + growStep
        return
    end
    -- Done inside the stretch: only the part up to then counts towards growth.
    local used = step > 0 and (1 - progress) / step or 1
    batch.progress, batch.growProgress = 1, (batch.growProgress or 0) + growStep * used
    local to = ledger.lastHour or now
    batch.readyHour = from + (to - from) * used
    local kefirKind = FluidAgeing.fluidKind(M.KEFIR_PROCESS)
    batch.kefirAge = FluidAgeing.newFluidAge(kefirKind, ledger, now, place)
    batch.kefirAge.age = math.max(now - batch.readyHour, 0) * M.milkRate(M.placeTemperature(ledger, place))
    finishGrains(batch, batch.kefirAge.age)
end

-- The grains after a finished batch, as counts by key, and the part-grain the pot keeps: live ones grew by their share
-- of the work done in their range, hungry ones are live again, those coming back from dried move a stage. Grains
-- taken out before the milk (no batch) come out as they went in, as do those of a batch already done (grainsDone).
function M.grainsAfter(batch)
    local out, finished = {}, batch.readyHour ~= nil and not batch.grainsDone
    local part = batch.partGrain or 0
    for key, n in pairs(batch.grains or {}) do
        local grain = M.grainOfKey(key)
        local outKey = key
        if finished then
            if grain.grainState == M.GRAIN_HUNGRY then
                outKey = M.GRAIN_LIVE
            elseif grain.grainState == M.GRAIN_REACTIVATING then
                outKey = grain.stage + 1 >= M.REACTIVATE_BATCHES and M.GRAIN_LIVE or M.GRAIN_REACTIVATING .. (grain.stage + 1)
            elseif grain.grainState == M.GRAIN_LIVE then
                local inRange = (batch.progress or 0) > 0 and math.min((batch.growProgress or 0) / batch.progress, 1) or 0
                part = part + n * M.GRAIN_GROWTH * inRange
            end
        end
        out[outKey] = (out[outKey] or 0) + n
    end
    if finished then
        local whole = math.floor(part + 1e-9)
        out[M.GRAIN_LIVE] = (out[M.GRAIN_LIVE] or 0) + whole
        part = part - whole
    end
    return out, part
end

-- Takes every grain out: counts by key, and their lots ({ key, n, age }: the hours each has starved), and keeps the
-- part-grain on the pot. A pot left with no milk forgets its culture.
function M.takeGrains(batch)
    local out, part = M.grainsAfter(batch)
    local lots = batch.grainLots
    if not lots then
        lots = {}
        for key, n in pairs(out) do addLot(lots, key, n, 0) end
    end
    batch.grains, batch.partGrain, batch.grainLots, batch.grainClock, batch.grainsDone = nil, part, nil, nil, nil
    if (batch.ml or 0) <= 0 then M.clearFields(batch, M.KEFIR_FIELDS) end
    return out, lots
end

-- Strains up to maxMl of ready kefir out: the ml, its kefir by fluid ({ CowKefir = ml, ... }), its age (a copy of the
-- pot's kefirAge), and the grains (counts by key, then their lots) the first time. An emptied pot starts over, keeping
-- its part-grain.
function M.strainKefir(batch, maxMl)
    if M.stage(batch) ~= "KefirReady" then return 0 end
    local ml = math.min(batch.ml, maxMl or batch.ml)
    local kefir = {}
    for milk, part in pairs(CauldronFluid.partsOf(batch, ml)) do
        local name = M.KEFIRS[milk] or "CowKefir"
        kefir[name] = (kefir[name] or 0) + part
    end
    local age = batch.kefirAge and FluidAgeing.copy(batch.kefirAge)
    local grains, lots
    if batch.grains then grains, lots = M.takeGrains(batch) end
    batch.ml = batch.ml - ml
    if batch.ml <= 0.5 then M.clearFields(batch, M.KEFIR_FIELDS) end
    return ml, kefir, age, grains, lots
end

-- Hours until the kefir is ready if the place's temperature holds, or nil if it never is.
function M.kefirHoursLeft(batch, placeC)
    if M.kefirStage(batch) ~= "Fermenting" then return nil end
    local perHour = M.kefirRate(placeC) * M.kefirRatio(batch) / M.KEFIR_HOURS
    if perHour <= 0 then return nil end
    return (1 - (batch.progress or 0)) / perHour
end

-- Fills the kefir pot from the cauldron with any milk at a heat the grains survive, as much as fits. Returns the ml
-- (0 with a reason when refused).
function M.cauldronToKefir(cauldron, batch, now, ledger)
    if not M.MILKS[cauldron.fluid] then return 0, "NoMilk" end
    local room, reason = M.milkRoom(batch, cauldron.ml)
    if room <= 0 then return 0, reason end
    reason = M.kefirMilkRefusal(batch, room, cauldron.tempC or 0)
    if reason then return 0, reason end
    local ml, _, tempC, parts = CauldronFluid.take(cauldron, room)
    return M.addKefirMilk(batch, ml, tempC, now, parts, ledger)
end

-- The tool a character strains with: the Strainer if carried, else a cloth (slower), else nil. Second: true for a cloth.
function M.strainTool(inventory)
    local strainer = inventory:getFirstTypeRecurse(M.STRAINER)
    if strainer then return strainer, false end
    for _, cloth in ipairs(M.STRAIN_CLOTHS) do
        local item = inventory:getFirstTypeRecurse(cloth)
        if item then return item, true end
    end
end

-- Moves a kefir pot on by hours at placeC, for the dev console (TPD.age): the ledger's totals can't be set back, so
-- the work is added straight. A fermenting pot that finishes inside them starts its kefir's age, and its grains'
-- starving, for the rest. Grains out of milk starve the hours; the heats reach them in milk or out.
function M.ageKefir(batch, hours, placeC, now)
    local stage = M.kefirStage(batch)
    local hot = M.grainHotRate(placeC) * hours
    local killed = M.grainKillRate(placeC) * hours
    if stage ~= "Fermenting" then
        M.grainFates(batch, batch.grainLots and hours * M.milkRate(placeC) or 0, hot, killed)
        if stage == "KefirReady" and batch.kefirAge then batch.kefirAge.age = batch.kefirAge.age + hours * M.milkRate(placeC) end
        return
    end
    M.grainFates(batch, 0, hot, killed)
    local perHour = M.kefirRate(placeC) * M.kefirRatio(batch) / M.KEFIR_HOURS
    local grows = M.kefirGrowRate(placeC) > 0
    local progress = batch.progress or 0
    local need = 1 - progress
    if perHour * hours < need then
        batch.progress = progress + perHour * hours
        if grows then batch.growProgress = (batch.growProgress or 0) + perHour * hours end
        return
    end
    local used = need / perHour
    batch.progress = 1
    if grows then batch.growProgress = (batch.growProgress or 0) + need end
    batch.readyHour = now - (hours - used)
    batch.kefirAge = FluidAgeing.newFluidAge(FluidAgeing.fluidKind(M.KEFIR_PROCESS), M.getLedger(), now, batch.place)
    batch.kefirAge.age = (hours - used) * M.milkRate(placeC)
    finishGrains(batch, batch.kefirAge.age)
end

-- Drying: live grains laid on TP Core's Drying Cloth dry by the air where it lies: about 2 days at 25 C and up, 5 at
-- 10 C, frozen they wait, and in a shut room they wait for a window (the cloth's rule for everything that dries by
-- air). Ten grains to a lot. Dry, they are Dried Kefir Grains again, to keep or to bring back over 2 batches; taken off
-- before they are dry they come back as live grains. Dead grains aren't laid. A Kefir Grains on a Cloth from before
-- the Drying Cloth (an old save) still dries where it lies and is collected as it always was: its save key on the
-- cloth item, never renamed once the mod is out, holds count (grains), cloth (the cloth's full type), dry (a
-- FluidAgeing age: hours at full drying).
M.GRAIN_DRYING = "TraditionalPreservationDairy.KefirGrainsOnCloth"
M.DRYING_KEY = "tpdDrying"
M.DRY_CLOTHS = M.STRAIN_CLOTHS
M.GRAIN_DRY_HOURS = 48
M.STILL_AIR_PLACE = "Sheltered"
local DRY_CURVE = { { 0, 0 }, { 5, 0.2 }, { 10, 0.4 }, { 20, 0.8 }, { 25, 1 } }
M.GRAIN_DRYING_KIND = { process = M.GRAIN_DRY, rate = function(celsius) return M.grainDryRate(celsius) end }

function M.grainDryRate(celsius)
    return Weather.curve(DRY_CURVE, celsius)
end

-- A cloth of count grains, set drying now at place.
function M.newDrying(count, cloth, ledger, now, place)
    return { count = count, cloth = cloth, dry = FluidAgeing.newFluidAge(M.GRAIN_DRYING_KIND, ledger, now, place) }
end

function M.isDry(drying)
    return drying.dry.age >= M.GRAIN_DRY_HOURS
end

-- Hours until dry at placeC, or nil if it never is there (frozen, or a shut room's still air).
function M.dryingHoursLeft(drying, placeC, place)
    local left = M.GRAIN_DRY_HOURS - drying.dry.age
    if left <= 0 then return 0 end
    local rate = place == M.STILL_AIR_PLACE and 0 or M.grainDryRate(placeC)
    return rate > 0 and left / rate or nil
end

-- Brings a cloth of grains up to now, where it is (or place), and its name with it: Kefir Grains on a Cloth (Drying), (Dry).
-- Returns its drying record, or nil for a cloth with none.
function M.keepDrying(item, now, place, ledger)
    local drying = item:getModData()[M.DRYING_KEY]
    if not drying then return nil end
    now = now or getGameTime():getWorldAgeHours()
    local fire, holder
    if not place then place, fire, holder = FluidAgeing.placeOfItem(item) end
    place = place or drying.dry.place or Weather.DEFAULT_PLACE
    -- A stretch in a shut room's still air dries nothing.
    local was, age = drying.dry.place, drying.dry.age
    FluidAgeing.advance(drying.dry, M.GRAIN_DRYING_KIND, ledger or M.getLedger(), now, place)
    if was == M.STILL_AIR_PLACE then drying.dry.age = age end
    if holder then FluidAgeing.noteFire(drying.dry, fire, holder, now) end
    local name = getText(M.isDry(drying) and "IGUI_TraditionalPreservationDairy_GrainsOnClothDry"
        or "IGUI_TraditionalPreservationDairy_GrainsOnClothDrying", tostring(drying.count))
    if item:getName() ~= name then
        item:setName(name)
        item:setCustomName(true)
    end
    return drying
end

M.GRAINS_PER_LOT = 10
local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local Tiles = require "TraditionalPreservationDairy/Tiles"

M.GRAINS_ON_CLOTH = DryingCloth.register({
    name = "kefirGrains", title = "IGUI_TraditionalPreservationDairy_GrainsTitle", types = { [M.GRAIN] = true },
    perLot = M.GRAINS_PER_LOT, hours = M.GRAIN_DRY_HOURS, curve = DRY_CURVE,
    sprite = function(lot, state)
        return Tiles.PREFIX .. (Tiles.GRAINS + Tiles.GRAIN_STATES[state == "dry" and "dry" or "wet"] * DryingCloth.LOTS + lot)
    end,
    layable = function(item)
        return M.keepGrain(item).grainState == M.GRAIN_DEAD and "IGUI_TraditionalPreservationDairy_GrainsDeadNoLay" or nil
    end,
    give = function(lot, inventory, state)
        for _ = 1, lot.count do inventory:AddItem(state == "dry" and M.DRIED_GRAIN or M.GRAIN) end
    end,
})
