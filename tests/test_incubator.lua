-- Checks the incubator's and the crock's rules outside the game. Run from the mod folder: luajit tests/test_incubator.lua
local H = dofile((os.getenv("TPCORE") or "../_tpcore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(10)
H.installModData()
H.installEvents()
dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy

-- Heat
check("room heat is room temperature", M.heatCelsius(1.0) == M.ROOM_C)
check("stove-hot milk is about 85 C or more", M.heatCelsius(M.MIN_POUR_HEAT) >= 85)
check("milk never goes past scalding", M.heatCelsius(3.0) == M.MILK_MAX_C)
check("heat goes back to the item it came from", near(M.heatCelsius(M.itemHeat(60)), 60))
check("only stove-hot milk counts", M.isHot(1.5) and not M.isHot(1.2))
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
check("a litre portions into three cups", M.cupsFor(1000) == 3 and M.cupsFor(300) == 1)

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

-- Crock
local crock = {}
M.startCrock(crock, ledger)
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
local hearthCrock = {}
M.startCrock(hearthCrock, ledger)
for hour = 74, 74 + 24 do
    H.setHours(hour)
    M.record(ledger, history, hour, -10)
end
M.updateCrock(hearthCrock, ledger, "Hearth")
check("by a fire the crock goes by the clock, not the frost", hearthCrock.stage == "Waiting"
    and M.crockStatus(hearthCrock, ledger, "Hearth").temperature == M.HEARTH_C)
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
