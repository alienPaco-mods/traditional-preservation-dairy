-- Checks a Jar of Yoghurt (F4): filled to its jar's size, eaten in portions through vanilla's eat action (stubbed
-- as the engine's Eat behaves), spooned into cups, an old 1 L jar from a save. Run from the mod folder:
-- luajit tests/test_jar.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

local realRequire = require
require = function(name)
    if name == "ffi" then return realRequire(name) end
    if name:find("^TraditionalPreservation") or name:find("^TimedActions/TP") then return realRequire(name) end
end

-- Engine stand-ins. Food values are kept as 32-bit floats, as the engine does.
local ffi = require "ffi"
local function f32(value) return tonumber(ffi.new("float", value)) end
local WEIGHTS = { ["Base.EmptyJar"] = 0.2, ["Base.ClayJar"] = 0.3, ["Base.ClayJarGlazed"] = 0.3 }
ScriptManager = { instance = { getItem = function(_, fullType)
    return WEIGHTS[fullType] and { getActualWeight = function() return WEIGHTS[fullType] end }
end } }
function getItemNameFromFullType() return "Jar of Yoghurt" end
function getTexture(name) return name end

local function food(fullType)
    local item = { fullType = fullType, data = {}, hung = 0, base = 0, calories = 0, age = 0 }
    function item:getFullType() return self.fullType end
    function item:getModData() return self.data end
    function item:setHungChange(v) self.hung = f32(v) end
    function item:getHungChange() return self.hung end
    function item:setBaseHunger(v) self.base = f32(v) end
    function item:getBaseHunger() return self.base end
    function item:setCalories(v) self.calories = f32(v) end
    function item:setCarbohydrates() end
    function item:setLipids() end
    function item:setProteins() end
    function item:multiplyFoodValues(by) self.hung = f32(self.hung * by) self.calories = f32(self.calories * by) end
    function item:setAge(v) self.age = v end
    function item:getAge() return self.age end
    function item:setTexture(t) self.texture = t end
    function item:setName(n) self.name = n end
    function item:setCustomName() end
    function item:setActualWeight(w) self.weight = w end
    function item:setCustomWeight(on) self.customWeight = on end
    function item:getContainer() return self.container end
    return item
end

local function container()
    local self = { items = {} }
    function self:contains(item) for _, held in ipairs(self.items) do if held == item then return true end end return false end
    self.containsRecursive = self.contains
    function self:DoRemoveItem(item)
        for index, held in ipairs(self.items) do if held == item then table.remove(self.items, index) item.container = nil return end end
    end
    function self:AddItem(item)
        if type(item) == "string" then item = food(item) end
        item.container = self
        table.insert(self.items, item)
        return item
    end
    function self:count(fullType)
        local n = 0
        for _, held in ipairs(self.items) do if held:getFullType() == fullType then n = n + 1 end end
        return n
    end
    return self
end

-- The engine's Eat: percentage is of the full item; under one hunger point left, the item is used up.
ISEatFoodAction = {}
function ISEatFoodAction:complete()
    local item, pct = self.item, self.percentage
    local used = math.min(math.abs(item:getBaseHunger() * pct) / math.abs(item:getHungChange()), 1)
    if item:getHungChange() * (1 - used) > -0.01 then used = 1 end
    if used >= 1 then item:getContainer():DoRemoveItem(item) else item:multiplyFoodValues(1 - used) end
    return true
end
function ISEatFoodAction:serverStop() end
local function eat(item, percentage)
    return setmetatable({ item = item, percentage = percentage }, { __index = ISEatFoodAction }):complete()
end

ISBaseTimedAction = H.class("ISBaseTimedAction")

require "TraditionalPreservationDairyYoghurt"
local M = TraditionalPreservationDairy
dofile("42/media/lua/shared/TimedActions/TPFillYoghurtCup.lua")

-- Filling
local bag = container()
local glass = bag:AddItem(M.YOGHURT_JAR)
M.fillJar(glass, "Base.EmptyJar", 1000, 2)
check("a glass jar holds four portions of vanilla Yoghurt's food", near(M.jarPortions(glass), 4) and near(M.jarFull(glass), 4)
    and near(glass.calories, 120) and glass.age == 2)
check("it is named and weighed by its portions", glass.name == "Jar of Yoghurt (4 portions)" and near(glass.weight, 1.2)
    and glass.customWeight == true)
local clay = bag:AddItem(M.YOGHURT_JAR)
M.fillJar(clay, "Base.ClayJar", 2500, 0)
check("a clay jar holds ten, with its own look", near(M.jarPortions(clay), 10) and clay.texture == M.JAR_ICONS["Base.ClayJar"]
    and near(clay.weight, 2.8))
local part = bag:AddItem(M.YOGHURT_JAR)
M.fillJar(part, "Base.ClayJar", 1500, 0)
check("a part-full clay jar: six portions, eaten as shares of a full one", near(M.jarPortions(part), 6) and near(M.jarFull(part), 10))

-- Eating a portion at a time
eat(glass, M.portionShare(M.jarPortions(glass), M.jarFull(glass)))
check("a portion eaten: three left", near(M.jarPortions(glass), 3) and glass.name == "Jar of Yoghurt (3 portions)" and near(glass.weight, 0.95))
eat(glass, M.portionShare(M.jarPortions(glass), M.jarFull(glass)))
eat(glass, M.portionShare(M.jarPortions(glass), M.jarFull(glass)))
check("one left reads as one portion", glass.name == "Jar of Yoghurt (1 portion)")
eat(glass, M.portionShare(M.jarPortions(glass), M.jarFull(glass)))
check("the last portion gives the glass jar back, once", not bag:contains(glass) and bag:count("Base.EmptyJar") == 1
    and bag:count(M.YOGHURT_JAR) == 2)

-- Vanilla's Eat Quarter on a clay jar, then the part-portion
eat(clay, 0.25)
check("Eat Quarter takes 2.5 portions", near(M.jarPortions(clay), 7.5) and clay.name == "Jar of Yoghurt (7.5 portions)")
for _ = 1, 7 do eat(clay, M.portionShare(M.jarPortions(clay), M.jarFull(clay))) end
check("half a portion left", near(M.jarPortions(clay), 0.5) and near(M.portionShare(M.jarPortions(clay), 10), 0.05))
eat(clay, M.portionShare(M.jarPortions(clay), M.jarFull(clay)))
check("eating it gives the clay jar back", not bag:contains(clay) and bag:count("Base.ClayJar") == 1)

-- Spooning into cups
local player = { inventory = bag }
function player:getInventory() return self.inventory end
function player:isTimedActionInstant() return false end
local cup = bag:AddItem(M.EMPTY_CUP)
local action = TPFillYoghurtCup:new(player, part, cup)
action:complete()
local yoghurt
for _, held in ipairs(bag.items) do if held:getFullType() == "Base.Yoghurt" then yoghurt = held end end
check("a cup takes one portion and the empty container", near(M.jarPortions(part), 5) and bag:count(M.EMPTY_CUP) == 0
    and yoghurt ~= nil and yoghurt.age == part.age)
eat(part, 0.45)
check("4.5 portions eaten: half a portion left", near(M.jarPortions(part), 0.5))
yoghurt.fullType = "Done"
local last = bag:AddItem(M.EMPTY_CUP)
TPFillYoghurtCup:new(player, part, last):complete()
check("the last part-portion makes a half-food cup and gives the jar back", not bag:contains(part)
    and bag:count("Base.ClayJar") == 2 and bag:count(M.YOGHURT_JAR) == 0)
check("no cup is filled from an empty jar", TPFillYoghurtCup.isValid({ character = player, jar = part, cup = last }) == false)

-- A jar from a save before F4: no food values, its cups in modData
local old = bag:AddItem(M.YOGHURT_JAR)
old.data.tpdJar, old.data.tpdMl, old.data.tpdCups = "Base.ClayJar", 1000, 3
check("an old jar gets its cups' worth of food once", near(M.jarPortions(old), 3) and near(M.jarFull(old), 4)
    and old.data.tpdFood == true)
eat(old, M.portionShare(M.jarPortions(old), M.jarFull(old)))
eat(old, M.portionShare(M.jarPortions(old), M.jarFull(old)))
eat(old, M.portionShare(M.jarPortions(old), M.jarFull(old)))
check("and empties back into its clay jar", not bag:contains(old) and bag:count("Base.ClayJar") == 3)

H.done()
