-- Traditional Preservation (Dairy): kefir. Milk fermented by kefir grains in the Yogurt Incubator (the culture comes
-- in K2): no scald, no wrap, at the place's temperature. Kefir is a fluid, its milk's food less the lactose the grains
-- ate. A fluid's food is its type's, so cow's and sheep's milk each make a kefir of their own, mixed by share as the
-- milks were; both are called Kefir, as the engine shows two fluids of one name as one (three or more read Mixed
-- Beverages), so there are only two. Animal's milk (vanilla's, from Milk Powder and water: kefir grains ferment
-- reconstituted milk too) has cow's food, so it makes the cow's: never a third. Always a little sour; left long it over-ferments and separates into curds and whey (Separated, at
-- about 3 days at 20 C), then rots (about 10), on milk's curve through TP Core's FluidAgeing. Fresh kefir
-- eases food sickness, 10 a litre, through TP Core's Drink, on the shared "foodSickness" cooldown of 3 game hours.
-- Grains come only from loot, as a packet of dried ones; each grain is an item of a gram. Live grains keep a record
-- in modData (state and the hour it was last set), so the grains from one batch can be split any way. Required by
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
    kind = M.KEFIR_KIND,
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
-- Save key on a live grain: never rename it once the mod is out. Inside: state, stage (batches done reactivating),
-- hour (the world hour the state was last set).
M.GRAIN_KEY = "tpdGrain"
M.GRAIN_LIVE, M.GRAIN_HUNGRY, M.GRAIN_REACTIVATING, M.GRAIN_DEAD = "Live", "Hungry", "Reactivating", "Dead"
-- Dried grains come back over this many batches.
M.REACTIVATE_BATCHES = 2
-- What a grain counts for in a batch's speed, by state, and whether it grows: a dead one is refused.
M.GRAIN_WORK = {
    [M.GRAIN_LIVE] = { share = 1, grows = true },
    [M.GRAIN_HUNGRY] = { share = 0.5, grows = false },
    [M.GRAIN_REACTIVATING] = { share = 0.5, grows = false },
}

-- A new grain record: Live unless said, set at `hour`. A dried grain put in milk starts Reactivating at stage 0.
function M.newGrain(state, hour)
    return { state = state or M.GRAIN_LIVE, stage = 0, hour = hour }
end

-- A grain item's record, made Live at `hour` if it has none (a grain from the console or a debug spawn).
function M.grainOf(item, hour)
    local data = item:getModData()
    data[M.GRAIN_KEY] = data[M.GRAIN_KEY] or M.newGrain(M.GRAIN_LIVE, hour)
    return data[M.GRAIN_KEY]
end

-- What a grain record counts for in a batch (0 when dead), and whether it grows.
function M.grainShare(record)
    local work = M.GRAIN_WORK[record.state]
    if not work then return 0, false end
    return work.share, work.grows
end
