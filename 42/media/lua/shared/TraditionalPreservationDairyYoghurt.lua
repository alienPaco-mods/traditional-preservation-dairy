-- Traditional Preservation (Dairy): every vanilla Yoghurt leaves an Empty Yoghurt Container, and a Jar of Yoghurt
-- is eaten from in portions. ReplaceOnUse covers eating and the evolved Oatmeal (both go through Use()); no vanilla
-- craft takes a Yoghurt, so Salt's ISHandcraftAction wrap isn't needed here.
-- A jar's portions are its food values (a portion each of vanilla Yoghurt's), so vanilla's own Eat, Eat Half and
-- Eat Quarter work on it too; the eat action is wrapped only to relabel the jar and give the empty one back.
require "TraditionalPreservationDairy"
require "TimedActions/ISEatFoodAction"
local M = TraditionalPreservationDairy

local YOGHURT = "Base.Yoghurt"

function M.applyYoghurtReplacement()
    local yoghurt = ScriptManager.instance:getItem(YOGHURT)
    if yoghurt then yoghurt:DoParam("ReplaceOnUse = " .. M.EMPTY_CUP) end
end

Events.OnInitGlobalModData.Add(M.applyYoghurtReplacement)

-- Sets a food item's values to the given number of portions; full is the whole item's, for vanilla's eat shares.
function M.setPortions(food, portions, full)
    local p = M.PORTION
    food:setHungChange(p.hunger * portions)
    food:setBaseHunger(p.hunger * (full or portions))
    food:setCalories(p.calories * portions)
    food:setCarbohydrates(p.carbohydrates * portions)
    food:setLipids(p.lipids * portions)
    food:setProteins(p.proteins * portions)
end

-- Portions left in a Jar of Yoghurt. A jar from before F4 (no tpdFood) holds no food values yet: it gets its
-- cups' worth, once. A clay jar filled before the icon fix gets its look here too.
function M.jarPortions(jar)
    local data = jar:getModData()
    if not data.customInventoryIcon then data.customInventoryIcon = M.JAR_ICONS[data.tpdJar] end
    if not data.tpdFood then
        M.setPortions(jar, M.cupsLeft(data), M.cupsFor(data.tpdMl or M.OLD_JAR_ML))
        data.tpdFood = true
    end
    return M.portionsIn(jar:getHungChange())
end

-- Portions in a full jar.
function M.jarFull(jar)
    return M.portionsIn(jar:getBaseHunger())
end

-- A Jar of Yoghurt says how many portions are left and weighs the empty jar plus what's still in it.
function M.labelJar(jar)
    local left = M.jarPortions(jar)
    local base = getItemNameFromFullType(M.YOGHURT_JAR)
    -- By the text: the engine keeps hunger as a 32-bit float, so one portion reads 1.00000001.
    local text = M.portionsText(left)
    jar:setName(getText(text == "1" and "IGUI_TraditionalPreservationDairy_JarOnePortion" or "IGUI_TraditionalPreservationDairy_JarPortions", base, text))
    jar:setCustomName(true)
    local empty = ScriptManager.instance:getItem(jar:getModData().tpdJar or "Base.ClayJar")
    jar:setActualWeight((empty and empty:getActualWeight() or 0) + left * M.CUP_KG)
    -- The engine saves only a custom weight; without this a reloaded jar weighs a full one again (and eating
    -- would scale it by its own rule).
    jar:setCustomWeight(true)
end

-- A freshly collected jar: ml of yoghurt in an empty jar of jarType, aged in days.
function M.fillJar(jar, jarType, ml, age)
    jar:setAge(age)
    local data = jar:getModData()
    data.tpdJar = jarType
    data.tpdMl = ml
    data.tpdFood = true
    data.customInventoryIcon = M.JAR_ICONS[jarType]
    -- The last jar from a pot may be part-full: it is a full jar for eating shares, short of portions.
    M.setPortions(jar, ml / M.CUP_ML, (M.JAR_ML[jarType] or M.OLD_JAR_ML) / M.CUP_ML)
    M.labelJar(jar)
end

-- After any eat or spoonful: an emptied jar goes back to the container it was in as its own empty jar; one with
-- yoghurt left is relabelled. Returns the empty jar, if any.
function M.afterJarUse(jar, container)
    if container and container:contains(jar) and M.portionsIn(jar:getHungChange()) >= M.EMPTY_PORTIONS then
        M.labelJar(jar)
        return nil
    end
    if container and container:contains(jar) then container:DoRemoveItem(jar) end
    local target = container or jar:getContainer()
    return target and target:AddItem(jar:getModData().tpdJar or "Base.ClayJar")
end

local function wrapEat(name)
    local original = ISEatFoodAction[name]
    ISEatFoodAction[name] = function(self, ...)
        local jar = self.item and self.item:getFullType() == M.YOGHURT_JAR and self.item
        if jar then M.jarPortions(jar) end
        local container = jar and jar:getContainer()
        local result = original(self, ...)
        if jar then M.afterJarUse(jar, container) end
        return result
    end
end

-- complete eats what was asked; serverStop eats the part done when the action is cut short. Outside the game
-- (tests) there is no eat action unless one is stubbed.
if ISEatFoodAction then
    wrapEat("complete")
    wrapEat("serverStop")
end
