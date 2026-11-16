-- Traditional Preservation (Dairy): kefir. Milk fermented by kefir grains in the Yogurt Incubator (the culture comes
-- in K2): no scald, no wrap, at the place's temperature. Kefir is a fluid, its milk's food less the lactose the grains
-- ate. A fluid's food is its type's, so cow's and sheep's milk each make a kefir of their own, mixed by share as the
-- milks were; both are called Kefir, as the engine shows two fluids of one name as one (three or more read Mixed
-- Beverages), so there are only two. Animal's milk (vanilla's, from Milk Powder and water: kefir grains ferment
-- reconstituted milk too) has cow's food, so it makes the cow's: never a third. Always a little sour; left long it over-ferments and separates into curds and whey (Separated, at
-- about 3 days at 20 C), then rots (about 10), on milk's curve through TP Core's FluidAgeing. Fresh kefir
-- eases food sickness, 10 a litre, through TP Core's Drink, on the shared "foodSickness" cooldown of 3 game hours.
-- Grains come only from loot, as a packet of dried ones; each grain is an item of a gram. Live grains keep their grainState
-- in modData (and the hour it was last set), so the grains from one batch can be split any way. Required by
-- TraditionalPreservationDairy.lua, whose M it adds to.
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
-- hour (the world hour the grainState was last set).
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

local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"

function M.kefirRate(celsius)
    return Weather.rate(KEFIR_CURVE, celsius, M.SENSITIVITY)
end

function M.kefirGrowRate(celsius)
    if celsius < M.GROW_LOW_C or celsius > M.GROW_HIGH_C then return 0 end
    return M.kefirRate(celsius)
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

-- The grain an item brings: a dried one comes back over REACTIVATE_BATCHES, a live one is its record. Nil for anything else.
function M.grainOfItem(item, hour)
    local fullType = item:getFullType()
    if fullType == M.DRIED_GRAIN then return M.newGrain(M.GRAIN_REACTIVATING, hour) end
    if fullType == M.GRAIN then return M.grainOf(item, hour) end
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
-- ones. Returns how many went in (0 with a reason when refused).
function M.addGrains(batch, grains, ledger)
    local reason = M.grainRefusal(batch)
    if reason then return 0, reason end
    local count = 0
    for _, grain in ipairs(grains) do
        if M.grainShare(grain) > 0 then
            local key = M.grainKey(grain)
            grainsOf(batch)[key] = (grainsOf(batch)[key] or 0) + 1
            count = count + 1
        end
    end
    if count == 0 then return 0, "Dead" end
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
    if M.grainHeat(batch.tempC) == M.GRAIN_HUNGRY then weaken(batch) end
    if not batch.kefirMarks then markKefir(batch, ledger) end
    return taken
end

-- Brings a fermenting pot up to the ledger's last record at place; a ready one's kefir ages on. When it finishes
-- inside the stretch, the part after that counts as the kefir's age, at the place's rate now.
function M.fermentKefir(batch, now, place, ledger)
    local stage = M.kefirStage(batch)
    if stage == "KefirReady" then
        if batch.kefirAge then FluidAgeing.advance(batch.kefirAge, FluidAgeing.fluidKind(M.KEFIR_PROCESS), ledger, now, place) end
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
end

-- The grains after a finished batch, as counts by key, and the part-grain the pot keeps: live ones grew by their share
-- of the work done in their range, hungry ones are live again, those coming back from dried move a stage. Grains
-- taken out before the milk (no batch) come out as they went in.
function M.grainsAfter(batch)
    local out, finished = {}, batch.readyHour ~= nil
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

-- Takes every grain out: counts by key, and keeps the part-grain on the pot. A pot left with no milk forgets its culture.
function M.takeGrains(batch)
    local out, part = M.grainsAfter(batch)
    batch.grains, batch.partGrain = nil, part
    if (batch.ml or 0) <= 0 then M.clearFields(batch, M.KEFIR_FIELDS) end
    return out
end

-- Strains up to maxMl of ready kefir out: the ml, its kefir by fluid ({ CowKefir = ml, ... }), its age (a copy of the
-- pot's kefirAge), and the grains (counts by key) the first time. An emptied pot starts over, keeping its part-grain.
function M.strainKefir(batch, maxMl)
    if M.stage(batch) ~= "KefirReady" then return 0 end
    local ml = math.min(batch.ml, maxMl or batch.ml)
    local kefir = {}
    for milk, part in pairs(CauldronFluid.partsOf(batch, ml)) do
        local name = M.KEFIRS[milk] or "CowKefir"
        kefir[name] = (kefir[name] or 0) + part
    end
    local age = batch.kefirAge and FluidAgeing.copy(batch.kefirAge)
    local grains = batch.grains and M.takeGrains(batch)
    batch.ml = batch.ml - ml
    if batch.ml <= 0.5 then M.clearFields(batch, M.KEFIR_FIELDS) end
    return ml, kefir, age, grains
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
-- the work is added straight. A fermenting pot that finishes inside them starts its kefir's age for the rest.
function M.ageKefir(batch, hours, placeC, now)
    local stage = M.kefirStage(batch)
    if stage == "KefirReady" then
        if batch.kefirAge then batch.kefirAge.age = batch.kefirAge.age + hours * M.milkRate(placeC) end
        return
    end
    if stage ~= "Fermenting" then return end
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
end
