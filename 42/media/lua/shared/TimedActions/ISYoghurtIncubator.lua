-- Traditional Preservation (Dairy): the hand jobs at a Yoghurt Incubator. "milk" pours hot milk in from a pot,
-- "starter" stirs in a yoghurt or an Active Yoghurt Starter, "pourOut" takes the milk back out into an empty
-- container to reheat it, and "collect" fills an empty Clay Jar with a litre of set yoghurt.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

ISYoghurtIncubator = ISBaseTimedAction:derive("ISYoghurtIncubator")

local M = TraditionalPreservationDairy
local BASE_DURATION = 40
local DURATION_PER_LITRE = 12

local function state(self)
    local World = TraditionalPreservationDairyWorld
    -- Brought up to the minute first, so hot milk mixes with the pot as it is now.
    if World then
        World.refresh(self.station)
        return World.incubatorState(self.station)
    end
    return M.stateOf(self.station:getModData().movableData or {}, M.INCUBATOR_KEY)
end

local function canDo(self)
    local batch = M.stateOf(self.station:getModData().movableData or {}, M.INCUBATOR_KEY)
    if self.mode == "milk" then
        return M.milkIn(self.item:getFluidContainer()) ~= nil and M.isHot(self.item:getItemHeat()) and M.milkRoom(batch, 1) > 0
    elseif self.mode == "starter" then
        return M.STARTERS[self.item:getFullType()] ~= nil and not self.item:isRotten() and M.canAddStarter(batch)
    elseif self.mode == "pourOut" then
        return M.isEmptyContainer(self.item) and (M.stage(batch) == "Cooling" or M.stage(batch) == "TooCold")
    end
    return M.JARS[self.item:getFullType()] == true and M.isEmptyContainer(self.item) and M.stage(batch) == "Ready"
end

function ISYoghurtIncubator:isValid()
    if not self.station:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    return canDo(self)
end

function ISYoghurtIncubator:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function ISYoghurtIncubator:start()
    self:setActionAnim("Loot")
end

local function removeItem(item)
    local container = item:getContainer()
    if container then container:DoRemoveItem(item) end
end

local function give(self, fullType)
    if not ScriptManager.instance:getItem(fullType) then
        print("[TPD] no item script for " .. fullType .. " yet")
        return nil
    end
    return self.character:getInventory():AddItem(fullType)
end

function ISYoghurtIncubator:complete()
    local batch = state(self)
    local now = getGameTime():getWorldAgeHours()
    local container = self.item:getFluidContainer()
    if self.mode == "milk" then
        local fluid = M.milkIn(container)
        local ml = math.floor(container:getAmount() * 1000 + 0.5)
        local taken = M.addMilk(batch, ml, M.heatCelsius(self.item:getItemHeat()), now)
        if taken > 0 then
            container:removeFluid(taken / 1000)
            batch.fluid = batch.fluid or fluid
        end
    elseif self.mode == "starter" then
        local fullType = self.item:getFullType()
        if M.addStarter(batch, M.STARTERS[fullType]) then
            removeItem(self.item)
            if fullType == "Base.Yoghurt" then give(self, M.EMPTY_CUP) end
        end
    elseif self.mode == "pourOut" then
        local fluid = batch.fluid or "CowMilk"
        local ml, tempC = M.pourOut(batch, math.floor(container:getCapacity() * 1000))
        if ml > 0 then
            container:addFluid(fluid, ml / 1000)
            self.item:setItemHeat(M.itemHeat(tempC))
        end
    else
        -- Nothing is taken from the pot unless the jar can be made.
        local jarType = self.item:getFullType()
        local ml, age = 0, 0
        if ScriptManager.instance:getItem(M.YOGHURT_JAR) then ml, age = M.collectJar(batch, now) end
        if ml > 0 then
            local jar = give(self, M.YOGHURT_JAR)
            removeItem(self.item)
            jar:setAge(age)
            jar:getModData().tpdJar = jarType
            jar:getModData().tpdMl = ml
            self.character:getXp():AddXP(Perks.Cooking, M.COLLECT_XP)
        else
            print("[TPD] no item script for " .. M.YOGHURT_JAR .. " yet")
        end
    end
    if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.refresh(self.station) end
    return true
end

function ISYoghurtIncubator:perform()
    ISBaseTimedAction.perform(self)
end

function ISYoghurtIncubator:getDuration()
    local container = self.item:getFluidContainer()
    local litres = 0
    if self.mode == "milk" and container then litres = container:getAmount() end
    if self.mode == "pourOut" and container then litres = container:getCapacity() end
    if self.mode == "collect" then litres = M.JAR_ML / 1000 end
    return BASE_DURATION + math.floor(math.min(litres, 5) * DURATION_PER_LITRE)
end

function ISYoghurtIncubator:new(character, station, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
