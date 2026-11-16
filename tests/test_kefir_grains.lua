-- Checks kefir grains out of milk (TraditionalPreservationDairyKefir.lua): each grain's starving clock on milk's curve,
-- the heats that weaken and kill them, the pot's grains starving in lots, and grains drying on a cloth. Run from the mod
-- folder: luajit tests/test_kefir_grains.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()
H.installGetText()
dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

local ledger, history = M.getLedger(), M.getHistory()

-- A steady place: every ten minutes at celsius through the real ledger; each step, look at what's given (items, pots).
local function run(hours, celsius, look)
    for _ = 1, math.floor(hours * 6 + 0.5) do
        H.setHours(H.hours + 1 / 6)
        M.recordWeather(ledger, history, H.hours, celsius)
        if look then look() end
    end
end

-- A grain item lying in the open, kept where it is said to be.
local function item(fullType, modData)
    modData = modData or {}
    local name = fullType
    return { getFullType = function() return fullType end, getModData = function() return modData end,
        getOutermostContainer = function() return nil end, getWorldItem = function() return nil end,
        getName = function() return name end, setName = function(_, text) name = text end, setCustomName = function() end }
end

local function grainItem(place)
    local grain = item(M.GRAIN)
    M.keepGrain(grain, H.hours, place or "Open", ledger)
    return grain
end

local function stateOf(grain) return grain:getModData()[M.GRAIN_KEY].grainState end

local function grains(n, state)
    local list = {}
    for i = 1, n do list[i] = { grainState = state or M.GRAIN_LIVE, stage = 0 } end
    return list
end

-- The rules
check("starved 2 days, a live grain goes Hungry", M.grainFate(M.GRAIN_LIVE, 48, 0, 0) == M.GRAIN_HUNGRY
    and M.grainFate(M.GRAIN_LIVE, 47.9, 0, 0) == M.GRAIN_LIVE)
check("at 7 days any grain is dead", M.grainFate(M.GRAIN_LIVE, 168, 0, 0) == M.GRAIN_DEAD
    and M.grainFate(M.GRAIN_HUNGRY, 168, 0, 0) == M.GRAIN_DEAD and M.grainFate(M.GRAIN_REACTIVATING, 168, 0, 0) == M.GRAIN_DEAD)
check("grains coming back from dried don't go Hungry", M.grainFate(M.GRAIN_REACTIVATING, 100, 5, 0) == M.GRAIN_REACTIVATING)
check("an hour over 35 C weakens a live grain, over 45 kills any", M.grainFate(M.GRAIN_LIVE, 0, 1 / 6, 0) == M.GRAIN_HUNGRY
    and M.grainFate(M.GRAIN_REACTIVATING, 0, 1 / 6, 1 / 6) == M.GRAIN_DEAD)
check("the heats count only past their line", M.grainHotRate(35) == 0 and M.grainHotRate(35.1) == 1
    and M.grainKillRate(45) == 0 and M.grainKillRate(45.1) == 1)

-- A grain item on its own clock
local grain = grainItem()
check("a grain's first look starts its clock and names it Live", grain:getModData()[M.GRAIN_KEY].clock ~= nil
    and grain:getName() == getText("IGUI_TraditionalPreservationDairy_GrainName", getText("IGUI_TraditionalPreservationDairy_GrainLive")))
run(47, 20)
M.keepGrain(grain, H.hours, "Open", ledger)
check("47 h at 20 C: still live", stateOf(grain) == M.GRAIN_LIVE)
run(2, 20)
M.keepGrain(grain, H.hours, "Open", ledger)
check("49 h: hungry, and named so", stateOf(grain) == M.GRAIN_HUNGRY
    and grain:getName():find(getText("IGUI_TraditionalPreservationDairy_GrainHungry"), 1, true) ~= nil)
run(120, 20)
M.keepGrain(grain, H.hours, "Open", ledger)
check("169 h: dead, the clock gone", stateOf(grain) == M.GRAIN_DEAD and grain:getModData()[M.GRAIN_KEY].clock == nil)

local cold = grainItem()
run(48, 4)
M.keepGrain(cold, H.hours, "Open", ledger)
check("2 days at 4 C: still live, a fifth of the way", stateOf(cold) == M.GRAIN_LIVE
    and near(cold:getModData()[M.GRAIN_KEY].clock.starve.age, 48 * M.milkRate(4), 0.2))
local frozen = grainItem()
run(200, -5)
M.keepGrain(frozen, H.hours, "Open", ledger)
check("frozen they wait", stateOf(frozen) == M.GRAIN_LIVE and near(frozen:getModData()[M.GRAIN_KEY].clock.starve.age, 0))
local inFridge = grainItem(FluidAgeing.FRIDGE)
run(48, 20)
M.keepGrain(inFridge, H.hours, FluidAgeing.FRIDGE, ledger)
check("a fridge counts at 4 C by the clock", near(inFridge:getModData()[M.GRAIN_KEY].clock.starve.age, 48 * M.milkRate(4), 0.01))

local hot = grainItem()
run(1, 38)
M.keepGrain(hot, H.hours, "Open", ledger)
check("an hour at 38 C: hungry at once", stateOf(hot) == M.GRAIN_HUNGRY)
local scorched = grainItem()
run(0.5, 47)
M.keepGrain(scorched, H.hours, "Open", ledger)
check("half an hour at 47 C: dead", stateOf(scorched) == M.GRAIN_DEAD)

-- The pot: lots out of milk, fed in milk, starving from Ready
local function potLook(pot)
    return function() M.catchUp(pot, H.hours, "Open", history, ledger) end
end
local pot = {}
local old = grainItem()
run(30, 20)
M.keepGrain(old, H.hours, "Open", ledger)
M.addGrains(pot, { M.keepGrain(old, H.hours, "Open", ledger) }, ledger, H.hours)
M.addGrains(pot, grains(5), ledger, H.hours)
check("grains put in apart keep their own clocks: two lots", #pot.grainLots == 2 and M.grainCount(pot) == 6)
run(20, 20, potLook(pot))
check("20 h on, unfed: the old grain (50 h) is hungry, the fresh five (20 h) live",
    pot.grains[M.GRAIN_HUNGRY] == 1 and pot.grains[M.GRAIN_LIVE] == 5)
M.addKefirMilk(pot, 240, 20, H.hours, "CowMilk", ledger)
check("milk feeds them: no lots while they ferment", pot.grainLots == nil)
run(30, 20, potLook(pot))
check("fermented in milk: ready, the grains came out of it live (hungry ones back), and starving from Ready",
    M.stage(pot) == "KefirReady" and pot.grains[M.GRAIN_LIVE] == 6 and pot.grainLots ~= nil and pot.grainsDone)
local readyAge = pot.grainLots[1].age
check("their starving began at Ready, as the kefir's age did", near(readyAge, pot.kefirAge.age, 0.3))
run(50, 20, potLook(pot))
check("left 2 days past Ready: hungry, and they stay so", pot.grains[M.GRAIN_HUNGRY] == 6 and not pot.grains[M.GRAIN_LIVE]
    and M.grainsAfter(pot)[M.GRAIN_HUNGRY] == 6)
local ml, _, _, counts, lots = M.strainKefir(pot, 1000)
check("strained: the grains come out hungry, with the hours they starved", ml > 0 and counts[M.GRAIN_HUNGRY] == 6
    and lots[1].key == M.GRAIN_HUNGRY and lots[1].n == 6 and lots[1].age > 48)
local record = M.grainRecord(lots[1].key, H.hours, lots[1].age, ledger, "Open")
check("a grain item made from them carries that clock on", record.grainState == M.GRAIN_HUNGRY
    and near(record.clock.starve.age, lots[1].age))

local warm = {}
M.addGrains(warm, grains(10), ledger, H.hours)
M.addKefirMilk(warm, 400, 20, H.hours, "CowMilk", ledger)
run(1, 38, potLook(warm))
check("in milk, a place over 35 C turns the live grains Hungry", warm.grains[M.GRAIN_HUNGRY] == 10)

local console = {}
M.addGrains(console, grains(4), ledger, H.hours)
M.ageKefir(console, 50, 20, H.hours)
check("TPD.age: grains alone starve the hours at the place", console.grains[M.GRAIN_HUNGRY] == 4)

-- Drying on a cloth
check("drying: 2 days at 25 C and up, 5 at 10 C, frozen never", near(M.GRAIN_DRY_HOURS / M.grainDryRate(25), 48)
    and near(M.GRAIN_DRY_HOURS / M.grainDryRate(10), 120) and M.grainDryRate(0) == 0
    and M.dryingHoursLeft(M.newDrying(5, "Base.RippedSheets", ledger, H.hours, "Open"), -3) == nil)
local cloth = item(M.GRAIN_DRYING)
cloth:getModData()[M.DRYING_KEY] = M.newDrying(12, "Base.RippedSheets", ledger, H.hours, "Open")
M.keepDrying(cloth, H.hours, "Open", ledger)
check("a fresh cloth reads Drying", cloth:getName() == getText("IGUI_TraditionalPreservationDairy_GrainsOnClothDrying", "12"))
run(59, 20)
check("59 h at 20 C: not yet", not M.isDry(M.keepDrying(cloth, H.hours, "Open", ledger)))
run(2, 20)
check("61 h: dry, and named so", M.isDry(M.keepDrying(cloth, H.hours, "Open", ledger))
    and cloth:getName() == getText("IGUI_TraditionalPreservationDairy_GrainsOnClothDry", "12"))
check("keepGrain keeps a cloth too", M.keepGrain(cloth, H.hours, "Open", ledger) == cloth:getModData()[M.DRYING_KEY])

H.done()
