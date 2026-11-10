-- Checks the incubator's and the crock's rules outside the game. Run from the mod folder: luajit tests/test_incubator.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(10)
H.installModData()
H.installEvents()
dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy

-- Heat
check("room heat is room temperature", M.heatCelsius(1.0) == M.ROOM_C)
check("an item never reads hotter than the copper gets", M.heatCelsius(3.0) == M.MILK_MAX_C)
check("heat goes back to the item it came from", near(M.heatCelsius(M.itemHeat(60)), 60))
check("a wrapped pot holds heat far longer", M.tau(5000, true) > 4 * M.tau(5000, false))
check("less milk cools faster", M.tau(3000, false) < M.tau(5000, false))
check("down to a floor, for balance", M.tau(500, false) == M.tau(M.TAU_FLOOR_ML, false))

-- Cooling a full lidded pot at 20 C
local batch = {}
check("pouring 5 L takes it all", M.addMilk(batch, 5000, 85, 0) == 5000 and M.stage(batch) == "Cooling")
local hours = M.forecast(batch, 20)
check("no starter: cooling never ends in a set", hours == nil or M.stage(batch) == "Cooling")
local copy = { ml = 5000, tempC = 85, starter = "Yoghurt" }
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
check("and a starter won't take", not M.addStarter(cold, "Yoghurt") and select(2, M.canAddStarter(cold)) == "TooCold")
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
M.addStarter(pot, "Yoghurt")
M.advanceBatch(pot, 3, 22, 0)
check("the wrap goes on by itself", M.stage(pot) == "Incubating")
check("no milk once it's wrapped", select(2, M.milkRoom(pot, 100)) == "Incubating" and M.pourOut(pot) == 0)
local set = M.forecast(pot, 22)
check("it sets in about 6 to 10 hours", set and set > 5 and set < 10)
M.advanceBatch(pot, 12, 22, 3)
check("and is ready", M.stage(pot) == "Ready" and pot.readyHour > 3 and pot.readyHour < 15)
check("age counts from setting", near(M.ageDays(pot, pot.readyHour + 48), 2))

-- A cold shed sets slowly or not at all
local shed = { ml = 5000, tempC = 45, starter = "Yoghurt", incubating = true, done = 0 }
M.advanceBatch(shed, 48, 2, 0)
check("near freezing it never sets", M.stage(shed) == "Incubating")
M.SENSITIVITY = 0
M.advanceBatch(shed, 6, 2, 48)
check("unless temperature sensitivity is off", M.stage(shed) == "Ready")
M.SENSITIVITY = 1

-- Collecting
local now = pot.readyHour + 24
local first, age = M.collectJar(pot, now)
check("one Clay Jar takes a litre, with the pot's age", first == 1000 and near(age, 1))
for _ = 1, 4 do M.collectJar(pot, now) end
check("five jars empty a full pot, and it starts over", M.stage(pot) == "Empty" and pot.starter == nil)
check("a litre fills four cups", M.cupsFor(1000) == 4 and M.cupsFor(250) == 1 and M.cupsFor(600) == 2)
local jarData = { tpdMl = 1000 }
check("a jar from before the count goes by its litres", M.cupsLeft(jarData) == 4 and M.cupsLeft({ tpdMl = 500 }) == 2)
check("each cup comes out one at a time", M.takeCup(jarData) == 3 and M.cupsLeft(jarData) == 3)
for _ = 1, 3 do M.takeCup(jarData) end
check("the last cup empties the jar, and no further", M.cupsLeft(jarData) == 0 and M.takeCup(jarData) == 0)
local cupPot = { ml = 600, readyHour = 10, starter = "Yoghurt", incubating = true, fluid = "CowMilk" }
check("a pot of 0.6 L fills three cups", M.cupsInPot(cupPot) == 3)
local cupMl, cupAge = M.collectCup(cupPot, 34)
check("a cup takes 250 ml, as old as a jar from the same pot", cupMl == 250 and near(cupAge, 1))
M.collectCup(cupPot, 34)
local lastMl = M.collectCup(cupPot, 34)
check("the last cup takes what's left and the pot starts over", lastMl == 100 and M.stage(cupPot) == "Empty"
    and cupPot.starter == nil and M.cupsInPot(cupPot) == 0 and M.collectCup(cupPot, 34) == 0)

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

-- By a fire
check("a fire keeps its warmth whatever the weather", M.placeTemperature(ledger, "Hearth") == M.HEARTH_C
    and M.pastTemperature(history, 3, "Hearth") == M.HEARTH_C)
local winter = { ml = 5000, tempC = 85, starter = "Yoghurt" }
M.advanceBatch(winter, 14, M.HEARTH_C, 0)
check("by the fire it sets even in winter", M.stage(winter) == "Ready")

-- The fire burns out while the pot is away
local burnt = { ml = 5000, tempC = 85, last = 11, fireUntil = 15, under = "Open" }
M.catchUp(burnt, 30, "Hearth", history, ledger)
local byHand = { ml = 5000, tempC = 85 }
M.advanceBatch(byHand, 4, M.HEARTH_C, 11)
M.advanceBatch(byHand, 5, 30, 15)
M.advanceBatch(byHand, 10, 0, 20)
check("by the fire only while the fuel lasts, then the place under it", near(burnt.tempC, byHand.tempC, 1e-6))
local onAndOn = { ml = 5000, tempC = 85, last = 11 }
M.catchUp(onAndOn, 30, "Hearth", history, ledger)
check("a fire with no burn-out noted burns on", onAndOn.tempC > M.HEARTH_C - 0.5)
local embersC = M.placeTemperature(ledger, M.EMBERS)
local embers = { ml = 5000, tempC = 85, last = 11 }
M.catchUp(embers, 30, M.EMBERS, history, ledger)
check("banked embers are a cooler fire, whatever the weather", embersC < M.HEARTH_C
    and M.pastTemperature(history, 3, M.EMBERS) == embersC and embers.tempC < onAndOn.tempC)
local emberOut = { ml = 5000, tempC = 85, last = 11, fireUntil = 15, under = "Open" }
M.catchUp(emberOut, 30, M.EMBERS, history, ledger)
local emberHand = { ml = 5000, tempC = 85 }
M.advanceBatch(emberHand, 4, embersC, 11)
M.advanceBatch(emberHand, 5, 30, 15)
M.advanceBatch(emberHand, 10, 0, 20)
check("by embers only while they last, then the place under them", near(emberOut.tempC, emberHand.tempC, 1e-6))

-- Hearth copper: TP Core's rules (its tests/test_hearth.lua); milk's own here
check("the copper's numbers are the core's", M.COPPER_ML == 10000 and M.HOT_C == 85 and M.MILK_MAX_C == 95)
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
check("cow's milk won't go into sheep's", select(2, M.copperToPot({ ml = 2000, fluid = "CowMilk", tempC = 90 }, sheepPot, 0)) == "Mixed"
    and select(2, M.milkRoom(sheepPot, 100, "CowMilk")) == "Mixed" and M.milkRoom(sheepPot, 100, "SheepMilk") == 100)
check("too hot for the crock", not M.copperWarm(hotCopper) and not M.copperWarm({ fluid = "CowMilk", tempC = 30 })
    and M.copperWarm({ fluid = "CowMilk", tempC = 40 }))

-- Carried milk
local carry = M.carryIn(nil, 0, 20, 3000, 90, 0, true)
check("milk drawn hot from the copper is steamed", M.isSteamed(carry, 3000) and M.carriedRefusal(carry, 3000) == nil)
check("milk added some other way voids it", not M.isSteamed(carry, 4000) and M.carriedRefusal(carry, 4000) == "NotSteamed")
check("milk taken out by vanilla is harmless", M.isSteamed(carry, 2000))
local drunk = M.carryIn(nil, 0, 20, 3000, 90, 0, true)
M.noteCarry(drunk, 2000)
check("seen after, the record shrinks, so a top-up is caught", drunk.ml == 2000 and not M.isSteamed(drunk, 3000))
check("an emptied container drops its record", M.noteCarry(drunk, 0) == nil)
check("no record, no steaming", M.carriedRefusal(nil, 1000) == "NotSteamed")
local mixed = M.carryIn(carry, 3000, 90, 1000, 20, 0, false)
check("unsteamed milk poured in voids it, heat mixes", not mixed.steamed and near(mixed.c, 72.5) and mixed.ml == 4000)
check("steamed into steamed stays steamed", M.isSteamed(M.carryIn(carry, 3000, 90, 2000, 88, 0, true), 5000))
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
    near(fireOut, M.cool(M.cool(85, M.HEARTH_C, 2, M.carryTau(5000)), 15, 4, M.carryTau(5000))))
local night = M.carryIn(nil, 0, 20, 5000, 85, 11, true)
M.carryTick(night, 11, ledger5, "Open")
local stepped = M.cool(M.cool(85, 30, 9, M.carryTau(5000)), 0, 10, M.carryTau(5000))
check("a long gap replays the weather hour by hour", near(M.advanceCarry(night, 30, ledger5, M.HEARTH), stepped, 1e-6))
check("topping up keeps the place notes", M.carryIn(warm, 5000, 50, 0, 85, 6, true).place == M.HEARTH)
check("a smaller amount cools faster", M.carryTau(1000) < M.carryTau(5000) and M.carryTau(200) == M.carryTau(1000))
local part = M.carryIn(nil, 0, 20, 2000, 85, 0, true)
check("pouring part out keeps the record", M.isSteamed(M.carryOut(part, 500), 1500))
check("pouring it all out drops the record", M.carryOut(part, 1500) == nil)

-- Crock
local crock = {}
check("a new crock is empty", M.crockStage(crock) == "Empty" and M.collectStarters(crock) == 0)
check("it loads once", M.loadCrock(crock, ledger) and crock.stage == "Cultivating" and not M.loadCrock(crock, ledger))
check("loading milk must be warm, not hot", M.isWarm(40) and not M.isWarm(M.HOT_C) and not M.isWarm(M.ROOM_C)
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
local hearthCrock = {}
M.startCrock(hearthCrock, ledger)
for hour = 74, 74 + 24 do
    H.setHours(hour)
    M.record(ledger, history, hour, -10)
end
M.updateCrock(hearthCrock, ledger, "Hearth")
check("by a fire the crock goes by the clock, not the frost", hearthCrock.stage == "Waiting"
    and M.crockStatus(hearthCrock, ledger, "Hearth").temperature == M.HEARTH_C)
local outCrock = {}
M.startCrock(outCrock, ledger)
outCrock.fireUntil, outCrock.under = 74 + 24 + 12, "Open"
for hour = 99, 99 + 24 do
    H.setHours(hour)
    M.record(ledger, history, hour, -10)
end
M.updateCrock(outCrock, ledger, "Hearth")
check("by a fire that burns out, a crock counts only the fire's hours in a frost",
    near(outCrock.done, 12 * M.cultureRate(M.HEARTH_C) + 13 * M.cultureRate(-10), 0.2))
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
