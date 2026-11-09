-- Traditional Preservation (Dairy): spoons one cup of yoghurt from a Jar of Yoghurt into an Empty Yoghurt
-- Container. The cup is as old as the jar, so freshness never resets; the last cup gives the empty jar back.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"
require "TraditionalPreservationDairyYoghurt"

ISFillYoghurtCup = ISBaseTimedAction:derive("ISFillYoghurtCup")

local M = TraditionalPreservationDairy
local DURATION = 30

function ISFillYoghurtCup:isValid()
    local inventory = self.character:getInventory()
    return inventory:containsRecursive(self.jar) and inventory:containsRecursive(self.cup)
        and M.cupsLeft(self.jar:getModData()) > 0
end

function ISFillYoghurtCup:start()
    self:setActionAnim("Loot")
end

local function removeItem(item)
    local container = item:getContainer()
    if container then container:DoRemoveItem(item) end
end

function ISFillYoghurtCup:complete()
    local inventory = self.character:getInventory()
    local data = self.jar:getModData()
    local left = M.takeCup(data)
    removeItem(self.cup)
    inventory:AddItem("Base.Yoghurt"):setAge(self.jar:getAge())
    if left > 0 then
        M.labelJar(self.jar)
    else
        removeItem(self.jar)
        inventory:AddItem(data.tpdJar or "Base.ClayJar")
    end
    return true
end

function ISFillYoghurtCup:perform()
    ISBaseTimedAction.perform(self)
end

function ISFillYoghurtCup:getDuration()
    return DURATION
end

function ISFillYoghurtCup:new(character, jar, cup)
    local o = ISBaseTimedAction.new(self, character)
    o.jar = jar
    o.cup = cup
    o.maxTime = o:getDuration()
    return o
end
