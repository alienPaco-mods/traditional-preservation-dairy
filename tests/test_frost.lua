-- Checks frost on Dairy's things (TP Core's Frost at 0 C): wet kefir grains go Hungry once frozen through (6 h in all),
-- loose, on a Drying Cloth or in a kefir pot; kefir separates, in a container or in the pot; a yogurt is Thawed once
-- (unhappiness +10); an Active Yogurt Starter loses 1/48 of the way to rotten a frozen hour. A basement or a fire never
-- freezes, cooked or burnt food never does, and with the sandbox's Frost harms off nothing changes. Run from the mod
-- folder: luajit tests/test_frost.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- Engine stand-ins: a fluid is its name; every stand-in is an item; names by full type.
Fluid = { Get = function(name) return name end }
function instanceof() return true end
local NAMES = { ["Base.Yoghurt"] = "Yogurt", ["TraditionalPreservationDairy.JarOfYoghurt"] = "Jar of Yogurt" }
function getItemNameFromFullType(fullType) return NAMES[fullType] or fullType end
ScriptManager = { instance = { getItem = function() return { getActualWeight = function() return 0.3 end } end } }

require "TraditionalPreservationDairy"
dofile("42/media/lua/shared/TraditionalPreservationDairyYoghurt.lua")
local M = TraditionalPreservationDairy
local Frost = require "TraditionalPreservationCore/Frost"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local Fire = require "TraditionalPreservationCore/Fire"

local ledger, history = M.getLedger(), M.getHistory()

-- Every quarter hour at celsius, through Dairy's ledger and Core's frost ledger (the game records that one itself, every
-- ten minutes; quarters sum exactly, so 6 h reads 6); each step, look() if given.
local function frostWeather(hours, celsius, look)
    for _ = 1, math.floor(hours * 4 + 0.5) do
        H.setHours(H.hours + 1 / 4)
        M.recordWeather(ledger, history, H.hours, celsius)
        Frost.recordWeather(H.hours, celsius)
        if look then look() end
    end
end

-- An item lying where it is said to be: its modData, a name, and food values for a yogurt or a starter.
local function item(fullType, food)
    local modData, name = {}, fullType
    local self = { modData = modData, unhappy = 0, age = 0, offAgeMax = 10, cooked = false, burnt = false, hung = -0.2, base = -0.2 }
    function self:getFullType() return fullType end
    function self:getModData() return modData end
    function self:getOutermostContainer() return nil end
    function self:getWorldItem() return nil end
    function self:getName() return name end
    function self:setName(text) name = text end
    function self:setCustomName() end
    if food then
        function self:isCooked() return self.cooked end
        function self:isBurnt() return self.burnt end
        function self:getUnhappyChangeUnmodified() return self.unhappy end
        function self:setUnhappyChange(v) self.unhappy = v end
        function self:getAge() return self.age end
        function self:setAge(v) self.age = v end
        function self:getOffAgeMax() return self.offAgeMax end
        function self:getHungChange() return self.hung end
        function self:getBaseHunger() return self.base end
        function self:setActualWeight() end
        function self:setCustomWeight() end
    end
    return self
end

local function grainItem(place)
    local grain = item(M.GRAIN)
    M.keepGrain(grain, H.hours, place, ledger)
    return grain
end

local function stateOf(grain) return grain:getModData()[M.GRAIN_KEY].grainState end

local function grains(n)
    local list = {}
    for i = 1, n do list[i] = { grainState = M.GRAIN_LIVE, stage = 0 } end
    return list
end

check("everything here freezes at 0 C", M.FROST.celsius == 0 and M.FROST.rate(0) == 1 and M.FROST.rate(0.1) == 0)

-- Loose grains
local open, basement, byFire = grainItem("Open"), grainItem("Basement"), grainItem(Fire.PLACE)
local function lookGrains()
    M.keepGrain(open, H.hours, "Open", ledger)
    M.keepGrain(basement, H.hours, "Basement", ledger)
    M.keepGrain(byFire, H.hours, Fire.PLACE, ledger)
end
frostWeather(5, -5, lookGrains)
check("5 h frozen in the open: still live", stateOf(open) == M.GRAIN_LIVE
    and near(open:getModData()[M.FROST_KEY].age, 5, 0.01))
frostWeather(1, -5, lookGrains)
check("6 h: frozen through, Hungry, and named so", stateOf(open) == M.GRAIN_HUNGRY
    and open:getName():find(getText("IGUI_TraditionalPreservationDairy_GrainHungry"), 1, true) ~= nil)
frostWeather(6, -5, lookGrains)
check("a basement never freezes", stateOf(basement) == M.GRAIN_LIVE and basement:getModData()[M.FROST_KEY].age == 0)
check("nor a place by a lit fire", stateOf(byFire) == M.GRAIN_LIVE and byFire:getModData()[M.FROST_KEY].age == 0)

-- One look after a long frost catches up at the place it was seen in
local away = grainItem("Open")
frostWeather(10, -5)
M.keepGrain(away, H.hours, "Open", ledger)
check("left alone, it catches up at the next look", stateOf(away) == M.GRAIN_HUNGRY)

-- Grains in a kefir pot, then their milk change, then the kefir in it
local pot = {}
M.addGrains(pot, grains(10), ledger, H.hours)
local function potLook() M.catchUp(pot, H.hours, "Open", history, ledger) end
potLook()
frostWeather(5, -5, potLook)
check("a kefir pot's grains, 5 h frozen: still live", pot.grains[M.GRAIN_LIVE] == 10)
frostWeather(1, -5, potLook)
check("6 h: the live grains in the pot go Hungry", pot.grains[M.GRAIN_HUNGRY] == 10 and not pot.grains[M.GRAIN_LIVE])
M.addKefirMilk(pot, 400, 20, H.hours, "CowMilk", ledger)
frostWeather(50, 20, potLook)
check("one milk change brings them back, and their frost starts over", M.stage(pot) == "KefirReady"
    and pot.grains[M.GRAIN_LIVE] == 10 and pot.grainFrost.age == 0 and pot.kefirFrost ~= nil)
local kefirKind = FluidAgeing.fluidKind(M.KEFIR_PROCESS)
check("the kefir is fresh", FluidAgeing.stage(pot.kefirAge, kefirKind) == "Fresh")
frostWeather(6, -5, potLook)
check("frozen through in the pot, the kefir separates", FluidAgeing.stage(pot.kefirAge, kefirKind) == "Turned")
local ml, _, _, _, _, frost = M.strainKefir(pot, 1000)
check("strained, the kefir's frost record goes with it", ml > 0 and frost and near(frost.age, 6, 0.01) and pot.kefirFrost == nil)

-- Kefir in a container
local fluids = { CowKefir = 1 }
local container = {
    isEmpty = function() return next(fluids) == nil end,
    getSpecificFluidAmount = function(_, fluid) return fluids[fluid] or 0 end,
    adjustSpecificFluidAmount = function(_, fluid, amount) fluids[fluid] = amount > 0 and amount or nil end,
    addFluid = function(_, name, litres) fluids[name] = (fluids[name] or 0) + litres end,
}
local jug = item("Base.Pot")
function jug:getFluidContainer() return container end
jug:getModData()[FluidAgeing.KEY] = FluidAgeing.newFluidAge(kefirKind, ledger, H.hours, "Open")
M.keepKefirFrost(jug, H.hours)
frostWeather(5, -5, function() M.keepKefirFrost(jug, H.hours) end)
check("kefir in a container, 5 h frozen: still Kefir", fluids.CowKefir == 1 and not fluids.SeparatedCowKefir)
frostWeather(1, -5, function() M.keepKefirFrost(jug, H.hours) end)
check("6 h: separated, and the fluid renamed", fluids.SeparatedCowKefir == 1 and not fluids.CowKefir)
fluids = { Water = 1 }
container.isEmpty = function() return false end
M.keepKefirFrost(jug, H.hours)
check("a container with no kefir forgets its record", jug:getModData()[M.KEFIR_FROST_KEY] == nil)

-- Yogurts
local cup, jar = item(M.YOGHURT, true), item(M.YOGHURT_JAR, true)
local starter, cooked, burnt = item(M.STARTER, true), item(M.YOGHURT, true), item(M.STARTER, true)
cooked.cooked, burnt.burnt = true, true
-- A jar filled at a pot: its food set already (two portions of vanilla's).
jar:getModData().tpdFood = true
local function lookFoods()
    for _, food in ipairs({ cup, jar, starter, cooked, burnt }) do M.keepFrost(food, H.hours, "Open") end
end
lookFoods()
frostWeather(5, -5, lookFoods)
check("a yogurt 5 h frozen: not yet thawed", cup.unhappy == 0 and not cup:getModData()[M.THAWED_KEY])
check("a starter loses 1/48 of the way to rotten each frozen hour", near(starter.age, 5 / 48 * 10, 0.01))
frostWeather(1, -5, lookFoods)
check("6 h: the yogurt is Thawed, unhappiness +10, named so", cup.unhappy == 10
    and cup:getName() == getText("IGUI_TraditionalPreservationDairy_Thawed", "Yogurt"))
check("a Jar of Yogurt too, (Thawed) before its portions", jar.unhappy == 10
    and jar:getName():find("Jar of Yogurt (Thawed)", 1, true) == 1)
frostWeather(48, -5, lookFoods)
check("only once", cup.unhappy == 10 and jar.unhappy == 10)
check("two days of frost in all spend a starter, never past rotten", near(starter.age, 10, 1e-6))
check("cooked or burnt food never freezes: no record, no change", cooked:getModData()[M.FROST_KEY] == nil
    and burnt:getModData()[M.FROST_KEY] == nil and cooked.unhappy == 0 and burnt.age == 0)
local spooned = item(M.YOGHURT, true)
M.carryFrost(jar, spooned)
check("a cup spooned from a thawed jar is Thawed too, on the jar's frost", spooned.unhappy == 10
    and spooned:getModData()[M.FROST_KEY].age == jar:getModData()[M.FROST_KEY].age)

-- Grains on a Drying Cloth
local cloth = { modData = {} }
function cloth:getModData() return self.modData end
local laid = {}
for i = 1, 5 do laid[i] = item(M.GRAIN) end
local wetId = DryingCloth.lay(cloth, laid, H.hours, "Open")
local function lookCloth() DryingCloth.update(cloth, H.hours, "Open") end
frostWeather(5, -5, lookCloth)
check("wet on a cloth, 5 h frozen: not hungry yet", not DryingCloth.lotById(DryingCloth.recordOf(cloth), wetId).data.hungry)
frostWeather(1, -5, lookCloth)
check("6 h: the lot is hungry", DryingCloth.lotById(DryingCloth.recordOf(cloth), wetId).data.hungry == true)
local given = {}
local inventory = { AddItem = function(_, fullType)
    local grain = item(fullType)
    table.insert(given, grain)
    return grain
end }
DryingCloth.take(cloth, wetId, inventory)
check("taken off wet, the grains come back Hungry", #given == 5 and stateOf(given[1]) == M.GRAIN_HUNGRY
    and given[5]:getName():find(getText("IGUI_TraditionalPreservationDairy_GrainHungry"), 1, true) ~= nil)

-- The sandbox off
SandboxVars = { TraditionalPreservationDairy = { FrostDamage = false } }
local offGrain, offCup, offStarter = grainItem("Open"), item(M.YOGHURT, true), item(M.STARTER, true)
local function lookOff()
    M.keepGrain(offGrain, H.hours, "Open", ledger)
    M.keepFrost(offCup, H.hours, "Open")
    M.keepFrost(offStarter, H.hours, "Open")
end
lookOff()
frostWeather(12, -5, lookOff)
check("Frost harms off: no harm, but the records go on", stateOf(offGrain) == M.GRAIN_LIVE and offCup.unhappy == 0
    and offStarter.age == 0 and offGrain:getModData()[M.FROST_KEY].age > 11.9 and offCup:getModData()[M.FROST_KEY].age > 11.9)
SandboxVars = nil

H.done()
