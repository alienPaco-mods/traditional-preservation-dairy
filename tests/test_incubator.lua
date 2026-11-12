-- Checks the incubator's and the crock's rules outside the game. Run from the mod folder: luajit tests/test_incubator.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(10)
H.installModData()
H.installEvents()
dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
local Hearth = require "TraditionalPreservationCore/Hearth"

-- Heat
check("room heat is room temperature", M.heatCelsius(1.0) == Hearth.ROOM_C)
check("an item never reads hotter than the copper gets", M.heatCelsius(3.0) == Hearth.MAX_C)
check("heat goes back to the item it came from", near(M.heatCelsius(M.itemHeat(60)), 60))
check("a wrapped pot holds heat far longer", M.tau(5000, true) > 4 * M.tau(5000, false))
check("less milk cools faster", M.tau(3000, false) < M.tau(5000, false))
check("down to a floor, for balance", M.tau(500, false) == M.tau(M.TAU_FLOOR_ML, false))

-- Cooling a full lidded pot at 20 C
local batch = {}
check("pouring 5 L takes it all", M.addMilk(batch, 5000, 85, 0) == 5000 and M.stage(batch) == "Cooling")
local hours = M.forecast(batch, 20)
check("no starter: cooling never ends in a set", hours == nil or M.stage(batch) == "Cooling")
local copy = { ml = 5000, tempC = 85, starter = "Yogurt" }
local toWrap, nextStage = M.forecast(copy, 20)
check("85 to 45 C takes about two hours at 20 C", nextStage == "Incubating" and toWrap > 1.6 and toWrap < 2.4)

-- Topping up
local top = {}
M.addMilk(top, 2000, 85, 0)
M.advanceBatch(top, 1, 20, 0)
local before = top.tempC
check("topping up mixes by volume", M.addMilk(top, 2000, 85, 1) == 2000 and near(top.tempC, (before + 85) / 2))
check("only what fits goes in", M.addMilk(top, 5000, 85, 1) == 1000 and select(2, M.addMilk(top, 100, 85, 1)) == "Full")

-- Too cold
local cold = {}
M.addMilk(cold, 5000, 85, 0)
M.advanceBatch(cold, 6, 20, 0)
check("milk left without a starter goes too cold", M.stage(cold) == "TooCold")
check("and a starter won't take", not M.addStarter(cold, "Yogurt") and select(2, M.canAddStarter(cold)) == "TooCold")
local warm = {}
M.addMilk(warm, 3000, 85, 0)
M.advanceBatch(warm, 6, 20, 0)
M.addMilk(warm, 2000, 90, 6)
check("hot milk on top warms it back up", warm.tempC >= M.STARTER_MIN_C and M.stage(warm) == "Cooling")
local part = { ml = 3000, tempC = 30, last = 0 }
check("a small pot takes part of it out", M.pourOut(part, 1000) == 1000 and part.ml == 2000 and part.tempC == 30)
local ml, tempC = M.pourOut(cold)
check("it can be poured out to reheat", ml == 5000 and tempC < M.STARTER_MIN_C and M.stage(cold) == "Empty")
check("the starter can go in before the milk", M.addStarter(cold, "Starter") and M.stage(cold) == "Empty")
M.addMilk(cold, 5000, 88, 7)
check("and waits for it", cold.starter == "Starter" and M.stage(cold) == "Cooling")
check("one starter per batch", select(2, M.canAddStarter(cold)) == "HasStarter")

-- A whole batch in a warm kitchen
local pot = {}
M.addMilk(pot, 5000, 85, 0)
M.addStarter(pot, "Yogurt")
M.advanceBatch(pot, 3, 22, 0)
check("the wrap goes on by itself", M.stage(pot) == "Incubating")
check("no milk once it's wrapped", select(2, M.milkRoom(pot, 100)) == "Incubating" and M.pourOut(pot) == 0)
local set = M.forecast(pot, 22)
check("it sets in about 6 to 10 hours", set and set > 5 and set < 10)
M.advanceBatch(pot, 12, 22, 3)
check("and is ready", M.stage(pot) == "Ready" and pot.readyHour > 3 and pot.readyHour < 15)
check("age counts from setting", near(M.ageDays(pot, pot.readyHour + 48), 2))

-- A cold shed sets slowly or not at all
local shed = { ml = 5000, tempC = 45, starter = "Yogurt", incubating = true, done = 0 }
M.advanceBatch(shed, 48, 2, 0)
check("near freezing it never sets", M.stage(shed) == "Incubating")
M.SENSITIVITY = 0
M.advanceBatch(shed, 6, 2, 48)
check("unless temperature sensitivity is off", M.stage(shed) == "Ready")
M.SENSITIVITY = 1

-- Collecting
local now = pot.readyHour + 24
local first, age = M.collectJar(pot, now, "Base.EmptyJar")
check("a glass jar takes a litre, with the pot's age", first == 1000 and near(age, 1))
check("a clay jar takes 2.5 L", M.collectJar(pot, now, "Base.ClayJar") == 2500)
check("the last jar takes what's left, and the pot starts over", M.collectJar(pot, now, "Base.ClayJarGlazed") == 1500
    and M.stage(pot) == "Empty" and pot.starter == nil)
check("a pot fills the jars it can, in order", M.jarsFor(5000, { "Base.ClayJar", "Base.ClayJar", "Base.EmptyJar" }) == 2
    and M.jarsFor(5000, { "Base.EmptyJar", "Base.EmptyJar", "Base.ClayJar", "Base.EmptyJar", "Base.EmptyJar" }) == 4
    and M.jarsFor(600, { "Base.EmptyJar", "Base.EmptyJar" }) == 1 and M.jarsFor(0, { "Base.EmptyJar" }) == 0)
check("a litre fills four cups", M.cupsFor(1000) == 4 and M.cupsFor(250) == 1 and M.cupsFor(600) == 2)
check("an old jar goes by its cups, older still by its litres", M.cupsLeft({ tpdCups = 3, tpdMl = 1000 }) == 3
    and M.cupsLeft({ tpdMl = 1000 }) == 4 and M.cupsLeft({ tpdMl = 500 }) == 2 and M.cupsLeft({}) == 4)
check("a portion is vanilla Yogurt's hunger", near(M.portionsIn(-0.4), 4) and near(M.portionsIn(-0.25), 2.5))
check("a portion is a share of the full jar", near(M.portionShare(4, 4), 0.25) and near(M.portionShare(10, 10), 0.1)
    and near(M.portionShare(0.5, 10), 0.05) and M.portionShare(1, 0) == 1)
check("portions as text", M.portionsText(4) == "4" and M.portionsText(1.0000000149) == "1" and M.portionsText(2.5) == "2.5"
    and M.portionsText(7.46) == "7.5")
local cupPot = { ml = 600, readyHour = 10, starter = "Yogurt", incubating = true, fluid = "CowMilk" }
check("a pot of 0.6 L fills three cups", M.cupsInPot(cupPot) == 3)
local cupMl, cupAge = M.collectCup(cupPot, 34)
check("a cup takes 250 ml, as old as a jar from the same pot", cupMl == 250 and near(cupAge, 1))
M.collectCup(cupPot, 34)
local lastMl = M.collectCup(cupPot, 34)
check("the last cup takes what's left and the pot starts over", lastMl == 100 and M.stage(cupPot) == "Empty"
    and cupPot.starter == nil and M.cupsInPot(cupPot) == 0 and M.collectCup(cupPot, 34) == 0)

-- C23: yogurt keeps its milk's food, a quarter litre a portion
local cow = M.portionFood({ fluid = "CowMilk", ml = 5000 })
check("a cow's milk portion is a quarter litre of the milk", near(cow.calories, 153.75) and near(cow.hunger, -0.125)
    and near(cow.carbohydrates, 11.5) and near(cow.lipids, 5.5) and near(cow.proteins, 8.25))
check("a sheep's milk portion is richer", near(M.portionFood({ fluid = "SheepMilk", ml = 1000 }).calories, 205.75))
local mixed = M.portionFood({ fluid = "SheepMilk", ml = 4000, parts = { CowMilk = 1000, SheepMilk = 3000 } })
check("a mixed pot goes by its shares", near(mixed.calories, (615 + 3 * 823) / 16) and near(mixed.hunger, -0.125))
check("a pot from before the milk's kind was kept is cow's", near(M.portionFood({ ml = 1000 }).calories, 153.75))
local milkPot = { ml = 5000, readyHour = 10, starter = "Yogurt", incubating = true, fluid = "CowMilk" }
local total = 0
while M.stage(milkPot) == "Ready" do
    local ml, _, food = M.collectCup(milkPot, 34)
    total = total + food.calories * ml / M.CUP_ML
end
check("5 L of cow's milk is 3,075 kcal of yogurt, as it was of milk", near(total, 3075))
check("old jars and cups go by vanilla Yogurt", near(M.portionsIn(-0.4), 4) and near(M.portionsIn(-0.5, cow), 4))

-- Catching up while unloaded
local ledger, history = M.getLedger(), M.getHistory()
for hour = 11, 30 do
    H.setHours(hour)
    M.record(ledger, history, hour, hour < 20 and 30 or 0)
end
check("the history has each hour", M.pastTemperature(history, 15, "Open") == 30 and M.pastTemperature(history, 25, "Open") == 0)
check("and nothing for hours it never saw", M.pastTemperature(history, 5, "Open") == nil)
local away = { ml = 5000, tempC = 85, last = 11 }
M.catchUp(away, 30, "Open", history, ledger)
local stepped = { ml = 5000, tempC = 85 }
M.advanceBatch(stepped, 9, 30, 11)
M.advanceBatch(stepped, 10, 0, 20)
check("an unloaded pot replays the hours it missed", near(away.tempC, stepped.tempC, 1e-6) and away.last == 30)
check("a basement is 15 C whatever the history", M.pastTemperature(history, 25, "Basement") == 15)

-- A year away: the hours before the history run as one spell
local realCool, steps = M.cool, 0
M.cool = function(...) steps = steps + 1 return realCool(...) end
local YEAR = 8760
local yearAway = { ml = 5000, tempC = 85, starter = "Yogurt", last = 11 }
M.catchUp(yearAway, 11 + YEAR, "Hearth", history, ledger)
local yearCost = steps
local yearByHand = { ml = 5000, tempC = 85, starter = "Yogurt" }
M.advanceBatch(yearByHand, YEAR, Hearth.FIRE_C, 11)
check("a year away costs no more than the history's hours", yearCost < M.HISTORY_HOURS / M.STEP_HOURS + 500)
check("and comes out as the long way does", M.stage(yearAway) == "Ready" and near(yearAway.readyHour, yearByHand.readyHour, 0.2)
    and near(yearAway.tempC, yearByHand.tempC, 0.01) and yearAway.last == 11 + YEAR)
local coldYear = { ml = 5000, tempC = 85, last = 11 }
M.catchUp(coldYear, 11 + YEAR, "Basement", history, ledger)
check("milk with no starter just cools", M.stage(coldYear) == "TooCold" and near(coldYear.tempC, 15, 0.01))
local stalled = { ml = 5000, tempC = 85, starter = "Yogurt", last = 11 }
M.catchUp(stalled, 11 + YEAR, "Open", history, ledger)
local stalledByHand = { ml = 5000, tempC = 85, starter = "Yogurt" }
M.advanceBatch(stalledByHand, YEAR, M.placeTemperature(ledger, "Open"), 11)
check("a started pot too cold to set wraps and waits", M.stage(stalled) == "Incubating" and M.stage(stalledByHand) == "Incubating"
    and near(stalled.done, stalledByHand.done, 0.01) and near(stalled.wrapHour, stalledByHand.wrapHour, 1e-6))
local burntYear = { ml = 5000, tempC = 85, starter = "Yogurt", last = 11, fireUntil = 13, under = "Open" }
M.catchUp(burntYear, 11 + YEAR, "Hearth", history, ledger)
local burntByHand = { ml = 5000, tempC = 85, starter = "Yogurt" }
M.advanceBatch(burntByHand, 2, Hearth.FIRE_C, 11)
M.advanceBatch(burntByHand, YEAR - 2, M.placeTemperature(ledger, "Open"), 13)
check("a fire that burnt out early in it counts only till then", M.stage(burntYear) == M.stage(burntByHand)
    and near(burntYear.done, burntByHand.done, 0.01) and near(burntYear.tempC, burntByHand.tempC, 0.01))
M.cool = realCool

-- By a fire
check("a fire keeps its warmth whatever the weather", M.placeTemperature(ledger, "Hearth") == Hearth.FIRE_C
    and M.pastTemperature(history, 3, "Hearth") == Hearth.FIRE_C)
local winter = { ml = 5000, tempC = 85, starter = "Yogurt" }
M.advanceBatch(winter, 14, Hearth.FIRE_C, 0)
check("by the fire it sets even in winter", M.stage(winter) == "Ready")

-- The fire burns out while the pot is away
local burnt = { ml = 5000, tempC = 85, last = 11, fireUntil = 15, under = "Open" }
M.catchUp(burnt, 30, "Hearth", history, ledger)
local byHand = { ml = 5000, tempC = 85 }
M.advanceBatch(byHand, 4, Hearth.FIRE_C, 11)
M.advanceBatch(byHand, 5, 30, 15)
M.advanceBatch(byHand, 10, 0, 20)
check("by the fire only while the fuel lasts, then the place under it", near(burnt.tempC, byHand.tempC, 1e-6))
local onAndOn = { ml = 5000, tempC = 85, last = 11 }
M.catchUp(onAndOn, 30, "Hearth", history, ledger)
check("a fire with no burn-out noted burns on", onAndOn.tempC > Hearth.FIRE_C - 0.5)
local embersC = M.placeTemperature(ledger, M.EMBERS)
local embers = { ml = 5000, tempC = 85, last = 11 }
M.catchUp(embers, 30, M.EMBERS, history, ledger)
check("banked embers are a cooler fire, whatever the weather", embersC < Hearth.FIRE_C
    and M.pastTemperature(history, 3, M.EMBERS) == embersC and embers.tempC < onAndOn.tempC)
local emberOut = { ml = 5000, tempC = 85, last = 11, fireUntil = 15, under = "Open" }
M.catchUp(emberOut, 30, M.EMBERS, history, ledger)
local emberHand = { ml = 5000, tempC = 85 }
M.advanceBatch(emberHand, 4, embersC, 11)
M.advanceBatch(emberHand, 5, 30, 15)
M.advanceBatch(emberHand, 10, 0, 20)
check("by embers only while they last, then the place under them", near(emberOut.tempC, emberHand.tempC, 1e-6))

-- Hearth copper: TP Core's rules (its tests/test_hearth.lua); milk's own here
check("the copper's numbers are the core's", Hearth.COPPER_ML == 60000 and M.HOT_C == 85 and Hearth.MAX_C == 95)
check("water is never poured into a pot", M.copperToPot({ ml = 4000, fluid = "Water", tempC = 90 }, {}, 0) == 0
    and select(2, M.copperToPot({ ml = 4000, fluid = "Water", tempC = 90 }, {}, 0)) == "NoMilk")
check("the time to hot means nothing for water", M.hoursToHot({ ml = 100, fluid = "Water", tempC = 20 }) == nil
    and M.hoursToHot({ ml = 10000, fluid = "CowMilk", tempC = 20 }) > 1.3)
check("hot milk is copperHot, hot water isn't", M.copperHot({ ml = 100, fluid = "CowMilk", tempC = 90 })
    and not M.copperHot({ ml = 100, fluid = "Water", tempC = 90 }))

-- From the copper into the pot
local hotCopper = { ml = 10000, fluid = "SheepMilk", tempC = 90, last = 0 }
local fromHearth = {}
check("hot milk fills the pot up", M.copperToPot(hotCopper, fromHearth, 0) == 5000 and fromHearth.ml == 5000
    and fromHearth.tempC == 90 and fromHearth.fluid == "SheepMilk" and hotCopper.ml == 5000)
check("a full pot takes no more", select(2, M.copperToPot(hotCopper, fromHearth, 0)) == "Full")
local topUp = { ml = 3000, tempC = 50, fluid = "SheepMilk", last = 0 }
check("it tops up a cooling pot, mixing the heat", M.copperToPot(hotCopper, topUp, 0) == 2000 and near(topUp.tempC, 66)
    and topUp.fluid == "SheepMilk")
hotCopper.tempC = 80
check("below 85 C it won't pour", select(2, M.copperToPot(hotCopper, {}, 0)) == "NotHot")
local sheepPot = { ml = 1000, tempC = 80, fluid = "SheepMilk" }
check("cow's milk goes in with sheep's", M.copperToPot({ ml = 2000, fluid = "CowMilk", tempC = 90 }, sheepPot, 0) == 2000
    and sheepPot.fluid == "CowMilk" and sheepPot.parts.SheepMilk == 1000)
local herdCopper = {}
Hearth.pourInto(herdCopper, "CowMilk", 3000, 90, 0)
check("and the two share a copper", Hearth.pourInto(herdCopper, "SheepMilk", 1000, 90, 0) == 1000 and M.copperHot(herdCopper))
local animalPot = { ml = 1000, tempC = 80, fluid = "AnimalMilk" }
check("the game's generic AnimalMilk is milk and blends with cow's",
    M.copperHot({ ml = 100, fluid = "AnimalMilk", tempC = 90 })
    and M.copperToPot({ ml = 1000, fluid = "CowMilk", tempC = 90 }, animalPot, 0) == 1000 and animalPot.parts.AnimalMilk == 1000)
local herdPot = {}
M.copperToPot(herdCopper, herdPot, 0)
local _, _, herdOut = M.pourOut(herdPot, 2000)
check("a blend keeps its shares into the pot and back out", near(herdOut.CowMilk, 1500) and near(herdOut.SheepMilk, 500)
    and herdPot.ml == 2000)
M.pourOut(herdPot)
check("an emptied pot forgets its milk", herdPot.fluid == nil and herdPot.parts == nil)

-- Cold milk and a starter already in the pot
local started = { starter = "Yogurt" }
check("cold milk is refused once the starter is in", select(2, M.addMilk(started, 2000, 20, 0)) == "ColdForStarter"
    and M.stage(started) == "Empty")
check("hot milk isn't", M.addMilk(started, 2000, 85, 0) == 2000)
local warm = { ml = 2000, tempC = 50, starter = "Yogurt" }
check("a top-up that leaves the pot warm enough goes in", M.coldRefusal(warm, 1000, 20) == nil
    and M.coldRefusal(warm, 3000, 20) == "ColdForStarter")
check("with no starter cold milk still goes in, to be reheated", M.addMilk({}, 2000, 20, 0) == 2000)

-- Carried milk
local carry = M.carryIn(nil, 0, 20, 3000, 90, 0, true)
check("milk drawn hot from the copper is scalded", M.isScalded(carry, 3000) and M.carriedRefusal(carry, 3000) == nil)
check("milk added some other way voids it", not M.isScalded(carry, 4000) and M.carriedRefusal(carry, 4000) == "NotScalded")
check("milk taken out by vanilla is harmless", M.isScalded(carry, 2000))
local drunk = M.carryIn(nil, 0, 20, 3000, 90, 0, true)
M.noteCarry(drunk, 2000)
check("seen after, the record shrinks, so a top-up is caught", drunk.ml == 2000 and not M.isScalded(drunk, 3000))
check("an emptied container drops its record", M.noteCarry(drunk, 0) == nil)
check("no record, no steaming", M.carriedRefusal(nil, 1000) == "NotScalded")
local mixed = M.carryIn(carry, 3000, 90, 1000, 20, 0, false)
check("unscalded milk poured in voids it, heat mixes", not mixed.scalded and near(mixed.c, 72.5) and mixed.ml == 4000)
check("scalded into scalded stays scalded", M.isScalded(M.carryIn(carry, 3000, 90, 2000, 88, 0, true), 5000))
local wrapped = M.carryIn(nil, 0, 20, 5000, 85, 0, true)
check("a wrapped pot loses about 15 C in an hour at 20 C", M.wrappedC(wrapped, 1, 20) > 68 and wrapped.c < 72 and wrapped.hour == 1)
local ledger5 = M.getLedger()
local shed = M.carryIn(nil, 0, 20, 5000, 85, 0, true)
M.carryTick(shed, 0, ledger5, "Basement")
local byFire = M.advanceCarry(shed, 8, ledger5, M.HEARTH)
check("set down, the gap counts where it was last carried, not where it is looked at",
    near(byFire, M.cool(85, 15, 8, M.carryTau(5000))))
local warm = M.carryIn(nil, 0, 20, 5000, 85, 0, true)
M.carryTick(warm, 0, ledger5, M.HEARTH, 2, "Basement")
local fireOut = M.advanceCarry(warm, 6, ledger5, M.HEARTH)
check("by a fire until its fuel ran out, then the place under it",
    near(fireOut, M.cool(M.cool(85, Hearth.FIRE_C, 2, M.carryTau(5000)), 15, 4, M.carryTau(5000))))
local night = M.carryIn(nil, 0, 20, 5000, 85, 11, true)
M.carryTick(night, 11, ledger5, "Open")
local stepped = M.cool(M.cool(85, 30, 9, M.carryTau(5000)), 0, 10, M.carryTau(5000))
check("a long gap replays the weather hour by hour", near(M.advanceCarry(night, 30, ledger5, M.HEARTH), stepped, 1e-6))
check("topping up keeps the place notes", M.carryIn(warm, 5000, 50, 0, 85, 6, true).place == M.HEARTH)
check("a smaller amount cools faster", M.carryTau(1000) < M.carryTau(5000) and M.carryTau(200) == M.carryTau(1000))
local open = M.carryIn(nil, 0, 20, 5000, 85, 0, true)
M.wrappedC(open, 0.25, 20, true)
check("an open pot off the heat is at about 45 C after a quarter hour", open.c > 40 and open.c < 50)
M.wrappedC(open, 0.3, 20, true)
check("and in the crock's window a few minutes later", open.c >= 35 and open.c <= 45)
check("scalded milk goes in with no record", M.carriedRefusal(nil, 1000, { ScaldedCowMilk = 600, ScaldedSheepMilk = 400 }) == nil)
check("plain milk among it doesn't", M.carriedRefusal(nil, 1000, { ScaldedCowMilk = 600, CowMilk = 400 }) == "NotScalded")
check("a scalded record still does, for when milk never goes off", M.carriedRefusal(carry, 3000, { CowMilk = 3000 }) == nil)
check("a scalded milk is in the scalded set, a plain one isn't", M.SCALDED.ScaldedAnimalMilk and not M.SCALDED.AnimalMilk)
local part = M.carryIn(nil, 0, 20, 2000, 85, 0, true)
check("pouring part out keeps the record", M.isScalded(M.carryOut(part, 500), 1500))
check("pouring it all out drops the record", M.carryOut(part, 1500) == nil)

-- Crock
local crock = {}
check("a new crock is empty", M.crockStage(crock) == "Empty" and M.collectStarters(crock) == 0)
check("it loads once", M.loadCrock(crock, ledger) and crock.stage == "Cultivating" and not M.loadCrock(crock, ledger))
check("loading milk must be warm, not hot", M.isWarm(40) and not M.isWarm(M.HOT_C) and not M.isWarm(Hearth.ROOM_C)
    and M.crockMilkRefusal(30) == "TooCool" and M.crockMilkRefusal(50) == "TooHot" and M.crockMilkRefusal(45) == nil)
check("a load needs half a litre in the window", M.crockLoadRefusal(400, 40) == "TooLittle" and M.crockLoadRefusal(500, 40) == nil
    and M.crockLoadRefusal(2000, 90) == "TooHot" and M.crockLoadRefusal(2000, 20) == "TooCool")
for hour = 31, 31 + 24 do
    H.setHours(hour)
    M.record(ledger, history, hour, 30)
end
M.updateCrock(crock, ledger, "Open")
check("a day of warm weather cultivates the crock", crock.stage == "Waiting")
H.setHours(60)
M.record(ledger, history, 60, 30)
M.updateCrock(crock, ledger, "Open")
check("then it waits for fresh milk", crock.stage == "Waiting" and M.feedCrock(crock, ledger))
for hour = 61, 61 + 12 do
    H.setHours(hour)
    M.record(ledger, history, hour, 30)
end
M.updateCrock(crock, ledger, "Open")
check("and develops into starter", crock.stage == "Ready")
check("collecting gives the starters and empties it", M.collectStarters(crock) == M.CROCK_STARTERS
    and M.crockStage(crock) == "Empty" and crock.marks == nil)

-- Clabber: soured milk alone, any warmth, no wheat
Fluid = Fluid or { Get = function() return nil end }
local function jug(fluid, litres) return H.vessel("Jug", fluid, litres, 2):getFluidContainer() end
check("soured milk clabbers, of any kind", M.clabberIn(jug("SourCowMilk", 1)) == "Soured"
    and M.clabberIn(jug("SourSheepMilk", 1)) == "Soured" and M.clabberRefusal(jug("SourAnimalMilk", 0.5)) == nil)
check("rotten milk is refused, and said so", M.clabberIn(jug("RottenCowMilk", 1)) == "Rotten"
    and M.clabberRefusal(jug("RottenSheepMilk", 1)) == "Rotten")
check("fresh, scalded or no milk isn't soured", M.clabberRefusal(jug("CowMilk", 1)) == "NoSour"
    and M.clabberRefusal(jug("ScaldedCowMilk", 1)) == "NoSour" and M.clabberRefusal(jug("Water", 1)) == "NoSour"
    and M.clabberIn(jug("SourCowMilk", 0)) == nil)
check("it needs half a litre", M.clabberRefusal(jug("SourCowMilk", 0.4)) == "TooLittle")
check("soured milk may share the copper, as fresh milk does", Hearth.blends("SourCowMilk", "SourSheepMilk")
    and not Hearth.blends("SourCowMilk", "CowMilk"))
local clabber = {}
check("a clabber skips Cultivating: the crock waits for fresh milk at once", M.clabberCrock(clabber)
    and clabber.stage == "Waiting" and not M.clabberCrock(clabber) and M.feedCrock(clabber, ledger)
    and clabber.stage == "Developing")
check("a crock already started takes no clabber", not M.clabberCrock({ stage = "Cultivating" }))

local hearthCrock = {}
M.startCrock(hearthCrock, ledger)
for hour = 74, 74 + 24 do
    H.setHours(hour)
    M.record(ledger, history, hour, -10)
end
M.updateCrock(hearthCrock, ledger, "Hearth")
check("by a fire the crock goes by the clock, not the frost", hearthCrock.stage == "Waiting"
    and M.crockStatus(hearthCrock, ledger, "Hearth").temperature == Hearth.FIRE_C)
local outCrock = {}
M.startCrock(outCrock, ledger)
outCrock.fireUntil, outCrock.under = 74 + 24 + 12, "Open"
for hour = 99, 99 + 24 do
    H.setHours(hour)
    M.record(ledger, history, hour, -10)
end
M.updateCrock(outCrock, ledger, "Hearth")
check("by a fire that burns out, a crock counts only the fire's hours in a frost",
    near(outCrock.done, 12 * M.cultureRate(Hearth.FIRE_C) + 13 * M.cultureRate(-10), 0.2))
local emberCrock = {}
M.startCrock(emberCrock, ledger)
emberCrock.fireUntil, emberCrock.under = 123 + 100, "Open"
for hour = 124, 123 + 11 do
    H.setHours(hour)
    M.record(ledger, history, hour, -10)
end
M.updateCrock(emberCrock, ledger, M.EMBERS)
check("a crock by banked embers cultivates at their heat, not the frost's",
    near(emberCrock.done, 11 * M.cultureRate(M.placeTemperature(ledger, M.EMBERS)), 0.2))
check("grain cultures like warm, not hot", M.cultureRate(30) == 1 and M.cultureRate(5) < 0.1)

-- Save keys
local modData = {}
local state = M.stateOf(modData, M.INCUBATOR_KEY)
M.addMilk(state, 1000, 85, 0)
check("state lives under one prefixed key", modData.tpdIncubator.ml == 1000 and modData.ml == nil and M.stateOf(modData, M.INCUBATOR_KEY) == state)

-- Sandbox
SandboxVars = { TraditionalPreservationDairy = { IncubationHours = 8, CultureHours = 36, TemperatureSensitivity = 1 } }
H.fire("OnInitGlobalModData")
check("the sandbox sets the times and sensitivity", M.INCUBATE_HOURS == 8 and M.CULTIVATE_HOURS == 36 and M.DEVELOP_HOURS == 18 and M.SENSITIVITY == 0)
H.done()
