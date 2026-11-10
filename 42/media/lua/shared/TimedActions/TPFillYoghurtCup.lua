-- Traditional Preservation (Dairy): spoons one portion of yoghurt from a Jar of Yoghurt into an Empty Yoghurt
-- Container. The cup is as old as the jar, so freshness never resets; a part-portion left over makes a cup with
-- that much food, and the last spoonful gives the empty jar back.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"
require "TraditionalPreservationDairyYoghurt"

TPFillYoghurtCup = ISBaseTimedAction:derive("TPFillYoghurtCup")

local M = TraditionalPreservationDairy
local Action = require "TraditionalPreservationCore/Action"
local DURATION = 30

function TPFillYoghurtCup:isValid()
    local inventory = self.character:getInventory()
    return inventory:containsRecursive(self.jar) and inventory:containsRecursive(self.cup)
        and M.jarPortions(self.jar) >= M.EMPTY_PORTIONS
end

function TPFillYoghurtCup:start()
    self:setActionAnim("Loot")
end

local function removeItem(item)
    local container = item:getContainer()
    if container then container:DoRemoveItem(item) end
end

function TPFillYoghurtCup:complete()
    local inventory = self.character:getInventory()
    local left = M.jarPortions(self.jar)
    local take = math.min(left, 1)
    removeItem(self.cup)
    local yoghurt = inventory:AddItem("Base.Yoghurt")
    yoghurt:setAge(self.jar:getAge())
    if take < 1 then yoghurt:multiplyFoodValues(take) end
    self.jar:multiplyFoodValues((left - take) / left)
    M.afterJarUse(self.jar, self.jar:getContainer())
    return true
end

function TPFillYoghurtCup:perform()
    ISBaseTimedAction.perform(self)
end

function TPFillYoghurtCup:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPFillYoghurtCup:new(character, jar, cup)
    local o = ISBaseTimedAction.new(self, character)
    o.jar = jar
    o.cup = cup
    o.maxTime = o:getDuration()
    return o
end
