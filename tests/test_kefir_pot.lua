-- Checks kefir in the Yogurt Incubator (TraditionalPreservationDairyKefir.lua, the pot): grains first, then any milk,
-- the speed by the place and the grains' share, hot milk against the grains, growth, the kefir's age in the pot and
-- straining. Run from the mod folder: luajit tests/test_kefir_pot.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()
dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

-- A steady place: every ten minutes at celsius, through the real ledger, the pot brought up to now as the World does.
local ledger, history = M.getLedger(), M.getHistory()
local function run(batch, hours, celsius, place)
    for _ = 1, math.floor(hours * 6 + 0.5) do
        H.setHours(H.hours + 1 / 6)
        M.recordWeather(ledger, history, H.hours, celsius)
        M.catchUp(batch, H.hours, place or "Open", history, ledger)
    end
end

local function grains(n, state, stage)
    local list = {}
    for i = 1, n do list[i] = { grainState = state or M.GRAIN_LIVE, stage = stage or 0 } end
    return list
end

-- The curve
check("full speed from 18 to 25 C", M.kefirRate(18) == 1 and M.kefirRate(25) == 1)
check("slow in the cold: 0.15 at 4 C, 0.35 at 10, 0.6 at 15", near(M.kefirRate(4), 0.15) and near(M.kefirRate(10), 0.35)
    and near(M.kefirRate(15), 0.6))
check("quicker when warm: 1.3 at 28 C, 1.5 from 30 to 35", near(M.kefirRate(28), 1.3) and near(M.kefirRate(30), 1.5)
    and near(M.kefirRate(35), 1.5))
check("frozen, it pauses", M.kefirRate(0) == 0 and M.kefirRate(-5) == 0)
check("the grains grow only from 15 to 28 C", M.kefirGrowRate(14.9) == 0 and M.kefirGrowRate(15) > 0
    and M.kefirGrowRate(28) > 0 and M.kefirGrowRate(29) == 0)

-- Grains first
local pot = {}
check("grains go into an empty pot, and make it a kefir pot", M.addGrains(pot, grains(10), ledger) == 10
    and pot.culture == M.KEFIR_CULTURE and M.stage(pot) == "KefirGrains")
check("a kefir pot takes no yogurt starter", select(2, M.canAddStarter(pot)) == "KefirPot")
check("dead grains are refused", select(2, M.addGrains({}, grains(3, M.GRAIN_DEAD), ledger)) == "Dead")
local yoghurt = {}
M.addMilk(yoghurt, 2000, 85, 0)
check("a pot of yogurt milk takes no grains: one culture at a time", select(2, M.addGrains(yoghurt, grains(5), ledger)) == "YoghurtMilk")
check("nor one with a starter waiting", select(2, M.addGrains({ starter = "Yogurt" }, grains(5), ledger)) == "HasStarter")

-- Any milk, at a heat the grains survive
check("milk over 45 C is refused: it would kill the grains", M.addKefirMilk(pot, 400, 60, H.hours, "CowMilk", ledger) == 0
    and M.kefirMilkRefusal(pot, 400, 60) == "TooHot")
check("cold raw milk goes in", M.addKefirMilk(pot, 400, 4, H.hours, "CowMilk", ledger) == 400
    and M.stage(pot) == "Fermenting")
check("10 live grains to 400 ml is full speed", M.kefirRatio(pot) == 1)
check("ready in 24 h at 20 C", near(M.kefirHoursLeft(pot, 20), 24))
run(pot, 23.5, 20)
check("not yet at 23.5 h", M.stage(pot) == "Fermenting" and near(pot.progress, 23.5 / 24, 0.01))
run(pot, 1, 20)
check("ready by 24.5 h, about when it finished", M.stage(pot) == "KefirReady" and pot.readyHour and pot.readyHour > H.hours - 0.7)
check("no more milk once it's ready", M.milkRoom(pot, 100) == 0)

-- More grains are no faster; fewer are slower
local many = {}
M.addGrains(many, grains(40), ledger)
M.addKefirMilk(many, 400, 20, H.hours, "CowMilk", ledger)
check("four times the grains is still full speed, no faster", M.kefirRatio(many) == 1 and near(M.kefirHoursLeft(many, 20), 24))
local few = {}
M.addGrains(few, grains(10), ledger)
M.addKefirMilk(few, 1000, 20, H.hours, "SheepMilk", ledger)
check("10 grains in a litre: four times as long", near(M.kefirRatio(few), 0.4) and near(M.kefirHoursLeft(few, 20), 60))
check("125 grains for a full 5 L pot", M.grainsFor(M.CAPACITY_ML) == 125)
local dried = {}
M.addGrains(dried, grains(10, M.GRAIN_REACTIVATING), ledger)
M.addKefirMilk(dried, 400, 20, H.hours, "CowMilk", ledger)
check("dried grains coming back work at half speed", near(M.kefirRatio(dried), 0.5))
check("a 4 C fridge is far slower", M.kefirHoursLeft(many, 4) > 150)

-- Topping up
local top = {}
M.addGrains(top, grains(50), ledger)
M.addKefirMilk(top, 1000, 20, H.hours, "CowMilk", ledger)
run(top, 12, 20)
local half = top.progress
M.addKefirMilk(top, 1000, 20, H.hours, "CowMilk", ledger)
check("fresh milk dilutes what has fermented", near(top.progress, half / 2))
M.addGrains(top, grains(10), ledger)
check("grains added mid-batch count from then on", M.grainCount(top) == 60)

-- Warm milk weakens live grains
local warm = {}
M.addGrains(warm, grains(10), ledger)
M.addGrains(warm, grains(4, M.GRAIN_REACTIVATING), ledger)
M.addKefirMilk(warm, 400, 40, H.hours, "CowMilk", ledger)
check("milk at 40 C: live grains turn Hungry, those coming back from dried stay as they are",
    (warm.grains[M.GRAIN_LIVE] or 0) == 0 and warm.grains[M.GRAIN_HUNGRY] == 10 and warm.grains.Reactivating0 == 4)
local hot = {}
M.addGrains(hot, grains(1), ledger)
hot.grains = nil
M.addMilk(hot, 400, 50, H.hours, "CowMilk")
check("grains into milk still over 45 C are refused", M.grainRefusal(hot) == "TooHot")
hot.tempC = 38
check("into milk at 38 C they go in, weakened", M.addGrains(hot, grains(5), ledger) == 5 and hot.grains[M.GRAIN_HUNGRY] == 5)

-- Coming out: growth, hungry back to live, dried moving on
local out, part = M.grainsAfter(pot)
check("a batch all at 20 C: live grains grow a tenth, the part-grain kept", out[M.GRAIN_LIVE] == 11 and near(part, 0))
local hungryOut = M.grainsAfter({ readyHour = 1, progress = 1, growProgress = 1, grains = { Hungry = 10, Reactivating0 = 4,
    Reactivating1 = 2 } })
check("hungry ones come back live and don't grow; dried ones move a stage, live after the second",
    hungryOut[M.GRAIN_LIVE] == 12 and hungryOut.Reactivating1 == 4 and not hungryOut.Reactivating0)
local halfOut, halfPart = M.grainsAfter({ readyHour = 1, progress = 1, growProgress = 0.5, partGrain = 0.7, grains = { Live = 10 } })
check("half the work out of their range: half the growth, added to the part-grain", halfOut[M.GRAIN_LIVE] == 11 and near(halfPart, 0.2))
local warmPot = {}
M.addGrains(warmPot, grains(20), ledger)
M.addKefirMilk(warmPot, 800, 20, H.hours, "CowMilk", ledger)
run(warmPot, 30, 31)
check("fermented at 31 C: quicker, but no growth", M.stage(warmPot) == "KefirReady" and M.grainsAfter(warmPot)[M.GRAIN_LIVE] == 20)

-- Taking grains out before the milk
local early = {}
M.addGrains(early, grains(5), ledger)
M.addGrains(early, grains(2, M.GRAIN_REACTIVATING), ledger)
local back = M.takeGrains(early)
check("grains taken out before the milk come out as they went in, and the pot forgets its culture",
    back[M.GRAIN_LIVE] == 5 and back.Reactivating0 == 2 and M.stage(early) == "Empty" and early.culture == nil)

-- The kefir's age in the pot
local kefirKind = FluidAgeing.fluidKind(M.KEFIR_PROCESS)
check("ready kefir starts young", pot.kefirAge and pot.kefirAge.age < 1)
run(pot, 72, 20)
check("left 3 days at 20 C in the pot, it has separated", FluidAgeing.stage(pot.kefirAge, kefirKind) == "Turned")

-- Straining
local mixed = {}
M.addGrains(mixed, grains(50), ledger)
M.addKefirMilk(mixed, 1500, 20, H.hours, "CowMilk", ledger)
M.addKefirMilk(mixed, 500, 20, H.hours, { ScaldedSheepMilk = 500 }, ledger)
check("nothing to strain before it's ready", M.strainKefir(mixed, 1000) == 0)
run(mixed, 25, 20)
local ml, kefir, age, firstGrains = M.strainKefir(mixed, 1000)
check("a litre strained: kefir by the milks' shares", ml == 1000 and near(kefir.CowKefir, 750) and near(kefir.SheepKefir, 250))
check("with its age, and the grains with the first strain", age and age.process == M.KEFIR_PROCESS and firstGrains
    and firstGrains[M.GRAIN_LIVE] == 55)
local ml2, _, _, secondGrains = M.strainKefir(mixed, 2000)
check("the rest, with no grains: the pot empties and forgets its culture, keeping its part-grain", ml2 == 1000
    and secondGrains == nil and M.stage(mixed) == "Empty" and mixed.culture == nil and mixed.partGrain ~= nil)
check("an emptied pot takes a yogurt starter again", M.canAddStarter(mixed) == true)

-- The console's ageing (TPD.age): work added straight
local aged = {}
M.addGrains(aged, grains(10), ledger)
M.addKefirMilk(aged, 400, 20, H.hours, "CowMilk", ledger)
M.ageKefir(aged, 12, 20, H.hours)
check("TPD.age: 12 h at 20 C is half done", near(aged.progress, 0.5))
M.ageKefir(aged, 24, 20, H.hours)
check("another 24: ready 12 h ago, its kefir 12 h old, grown in range", M.stage(aged) == "KefirReady"
    and near(aged.readyHour, H.hours - 12) and near(aged.kefirAge.age, 12) and M.grainsAfter(aged)[M.GRAIN_LIVE] == 11)

H.done()
