-- Traditional Preservation (Dairy): every vanilla Yogurt leaves an Empty Yogurt Container, and a Jar of Yogurt
-- is eaten from in portions. ReplaceOnUse covers eating and the evolved Oatmeal (both go through Use()); no vanilla
-- craft takes a Yogurt, so Salt's ISHandcraftAction wrap isn't needed here.
-- A jar's portions are its food values (a portion each of its milk's, kept in modData `tpdPortion`; vanilla
-- Yogurt's for a jar from before C23), so vanilla's own Eat, Eat Half and
-- Eat Quarter work on it too; the eat action is hooked only to relabel the jar and give the empty one back (TP
-- Core's Portions, which Fish & Meat's crock uses too).
require "TraditionalPreservationDairy"
local Portions = require "TraditionalPreservationCore/Portions"
local M = TraditionalPreservationDairy

local YOGHURT = "Base.Yoghurt"

-- Shop yogurt is cow's milk yogurt too (C23): new Yoghurts get a cow's milk portion's food, as script units
-- (hunger x100). Ones already in a save keep what they were made with; the engine saves each item's values.
function M.applyYoghurtReplacement()
    local yogurt = ScriptManager.instance:getItem(YOGHURT)
    if not yogurt then return end
    yogurt:DoParam("ReplaceOnUse = " .. M.EMPTY_CUP)
    local cow = M.portionFood({ fluid = "CowMilk", ml = M.CUP_ML })
    yogurt:DoParam("HungerChange = " .. cow.hunger * 100)
    yogurt:DoParam("Calories = " .. cow.calories)
    yogurt:DoParam("Carbohydrates = " .. cow.carbohydrates)
    yogurt:DoParam("Lipids = " .. cow.lipids)
    yogurt:DoParam("Proteins = " .. cow.proteins)
end

Events.OnInitGlobalModData.Add(M.applyYoghurtReplacement)

-- Sets a food item's values to the given number of portions of p (vanilla Yogurt's if not given); full is the
-- whole item's, for vanilla's eat shares.
function M.setPortions(food, portions, full, p)
    Portions.set(food, p or M.PORTION, portions, full)
end

-- One portion of a Jar of Yogurt's food.
function M.jarPortion(jar)
    return jar:getModData().tpdPortion or M.PORTION
end

-- Portions left in a Jar of Yogurt. A jar from before F4 (no tpdFood) holds no food values yet: it gets its
-- cups' worth, once. A clay jar filled before the icon fix gets its look here too.
function M.jarPortions(jar)
    local data = jar:getModData()
    if not data.customInventoryIcon then data.customInventoryIcon = M.JAR_ICONS[data.tpdJar] end
    if not data.tpdFood then
        M.setPortions(jar, M.cupsLeft(data), M.cupsFor(data.tpdMl or M.OLD_JAR_ML))
        data.tpdFood = true
    end
    return M.portionsIn(jar:getHungChange(), M.jarPortion(jar))
end

-- Portions in a full jar.
function M.jarFull(jar)
    return M.portionsIn(jar:getBaseHunger(), M.jarPortion(jar))
end

-- A Jar of Yogurt says how many portions are left and weighs the empty jar plus what's still in it.
function M.labelJar(jar)
    Portions.label(jar, getItemNameFromFullType(M.YOGHURT_JAR), M.jarPortions(jar), jar:getModData().tpdJar or "Base.ClayJar",
        M.CUP_KG)
end

-- A freshly collected jar: ml of yogurt in an empty jar of jarType, aged in days, portion being one portion's food.
function M.fillJar(jar, jarType, ml, age, portion)
    jar:setAge(age)
    local data = jar:getModData()
    data.tpdJar = jarType
    data.tpdMl = ml
    data.tpdFood = true
    data.tpdPortion = portion
    data.customInventoryIcon = M.JAR_ICONS[jarType]
    -- The last jar from a pot may be part-full: it is a full jar for eating shares, short of portions.
    M.setPortions(jar, ml / M.CUP_ML, (M.JAR_ML[jarType] or M.OLD_JAR_ML) / M.CUP_ML, portion)
    M.labelJar(jar)
end

-- Whether an item can start a batch: a starter that hasn't gone off, and a Jar of Yogurt only with a whole portion
-- left (the engine keeps hunger as a 32-bit float, so a portion may read a hair under 1).
function M.isStarter(item)
    local fullType = item:getFullType()
    if not M.STARTERS[fullType] or item:isRotten() then return false end
    return fullType ~= M.YOGHURT_JAR or M.jarPortions(item) >= 1 - 1e-3
end

-- Takes one portion out of a Jar of Yogurt for a starter. Returns the empty jar when that was the last.
function M.takeJarPortion(jar)
    local container = jar:getContainer()
    local left = M.jarPortions(jar)
    jar:multiplyFoodValues(math.max(left - 1, 0) / left)
    return M.afterJarUse(jar, container)
end

-- After any eat or spoonful: an emptied jar goes back to the container it was in as its own empty jar; one with
-- yogurt left is relabelled. Returns the empty jar, if any.
function M.afterJarUse(jar, container)
    return Portions.used(jar, container, function() return M.jarPortions(jar) >= M.EMPTY_PORTIONS end,
        jar:getModData().tpdJar or "Base.ClayJar", M.labelJar)
end

-- Eaten through vanilla's eat action (TP Core's Portions, the one wrap of it): the jar's portions are read first,
-- as a jar from before F4 gets its food values then, and afterwards it is relabelled or gives its empty jar back.
Portions.onEat(M.YOGHURT_JAR, function(jar) M.jarPortions(jar) end, function(jar, container) M.afterJarUse(jar, container) end)
