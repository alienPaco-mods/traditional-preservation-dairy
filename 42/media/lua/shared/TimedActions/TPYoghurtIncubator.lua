-- Traditional Preservation (Dairy): the hand jobs at a Yogurt Incubator. "hearth" pours milk steaming from a
-- Hearth's cauldron (within 2 tiles) in, "carried" pours scalded milk in from a container, "starter" stirs in a yogurt or an Active Yogurt Starter, "pourOut" takes the milk back out into an empty
-- container (still scalded) to reheat it, "collect" fills an empty jar (glass 1 L, clay 2.5 L) with set yogurt,
-- and "cup" fills an Empty Yogurt Container with a quarter litre.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"
require "TraditionalPreservationDairyYoghurt"

TPYoghurtIncubator = ISBaseTimedAction:derive("TPYoghurtIncubator")

local M = TraditionalPreservationDairy
local Hearth = require "TraditionalPreservationCore/Hearth"
local Action = require "TraditionalPreservationCore/Action"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

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
    if self.mode == "hearth" then
        return M.cauldronScalded(Hearth.cauldronState(self.hearth:getModData())) and M.milkRoom(batch, 1) > 0
    elseif self.mode == "carried" then
        local container = self.item:getFluidContainer()
        local ml = M.mlIn(container)
        local name, parts = M.milkIn(container)
        return name ~= nil and M.carriedRefusal(M.carryOf(self.item), ml, parts) == nil and M.milkRoom(batch, 1) > 0
            and M.coldRefusal(batch, ml, M.carriedC(self.item, getGameTime():getWorldAgeHours(), self.character)) == nil
    elseif self.mode == "starter" then
        return M.isStarter(self.item) and M.canAddStarter(batch)
    elseif self.mode == "pourOut" then
        return M.isEmptyContainer(self.item) and (M.stage(batch) == "Cooling" or M.stage(batch) == "TooCold")
    elseif self.mode == "cup" then
        return self.item:getFullType() == M.EMPTY_CUP and M.stage(batch) == "Ready"
    end
    return M.JAR_ML[self.item:getFullType()] ~= nil and M.isEmptyContainer(self.item) and M.stage(batch) == "Ready"
end

function TPYoghurtIncubator:isValid()
    if not self.station:getSquare() then return false end
    if self.mode == "hearth" then
        if not self.hearth:getSquare() then return false end
    elseif not self.character:getInventory():containsRecursive(self.item) then
        return false
    end
    return canDo(self)
end

function TPYoghurtIncubator:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPYoghurtIncubator:start()
    self:setActionAnim("Loot")
end

local function removeItem(item)
    local container = item:getContainer()
    if container then container:DoRemoveItem(item) end
end

local function give(self, fullType)
    return self.character:getInventory():AddItem(fullType)
end

-- What each mode does once the action is through: fn(self, batch, now).
local COMPLETE = {}

function COMPLETE.hearth(self, batch, now)
    M.cauldronToPot(Hearth.cauldronOf(self.hearth), batch, now)
    if Hearth.World then Hearth.World.refresh(self.hearth) end
end

function COMPLETE.carried(self, batch, now)
    local container = self.item:getFluidContainer()
    local carry = M.carryOf(self.item)
    local _, parts = M.milkIn(container)
    local tempC = M.carriedC(self.item, now, self.character)
    local ml = parts and M.addMilk(batch, M.mlIn(container), tempC, now, parts) or 0
    if ml > 0 then
        container:removeFluid(ml / 1000)
        M.recordTaken(self.item, carry, ml)
    end
end

function COMPLETE.starter(self, batch)
    local fullType = self.item:getFullType()
    if M.addStarter(batch, M.STARTERS[fullType]) then
        if fullType == M.YOGHURT_JAR then return M.takeJarPortion(self.item) end
        removeItem(self.item)
        if fullType == "Base.Yoghurt" then give(self, M.EMPTY_CUP) end
    end
end

function COMPLETE.pourOut(self, batch, now)
    local container = self.item:getFluidContainer()
    local ml, tempC, parts = M.pourOut(batch, math.floor(container:getCapacity() * 1000))
    if ml > 0 then
        -- A pot from before the milk's kind was kept gives cow's milk.
        if not M.hasAny(parts) then parts = { CowMilk = ml } end
        FluidAgeing.clearIfEmpty(self.item)
        for name, part in pairs(parts) do container:addFluid(name, part / 1000) end
        -- Everything in the pot came in scalded, so it goes out scalded.
        M.recordCarry(self.item, nil, 0, 0, ml, tempC, now, true)
        FluidAgeing.markScalded(self.item, now)
    end
end

function COMPLETE.cup(self, batch, now)
    local ml, age, portion = M.collectCup(batch, now)
    if ml > 0 then
        removeItem(self.item)
        -- The milk's food; the pot's last cup may be short, and holds only what it took.
        local yogurt = give(self, "Base.Yoghurt")
        yogurt:setAge(age)
        M.setPortions(yogurt, ml / M.CUP_ML, 1, portion)
        self.character:getXp():AddXP(Perks.Cooking, M.COLLECT_XP * ml / 1000)
    end
end

function COMPLETE.collect(self, batch, now)
    local jarType = self.item:getFullType()
    local ml, age, portion = M.collectJar(batch, now, jarType)
    if ml > 0 then
        local jar = give(self, M.YOGHURT_JAR)
        removeItem(self.item)
        M.fillJar(jar, jarType, ml, age, portion)
        self.character:getXp():AddXP(Perks.Cooking, M.COLLECT_XP * ml / 1000)
    end
end

function TPYoghurtIncubator:complete()
    COMPLETE[self.mode](self, state(self), getGameTime():getWorldAgeHours())
    if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.refresh(self.station) end
    return true
end

function TPYoghurtIncubator:perform()
    ISBaseTimedAction.perform(self)
end

function TPYoghurtIncubator:getDuration()
    local container = self.item and self.item:getFluidContainer()
    local litres = 0
    if self.mode == "hearth" then
        local cauldron = Hearth.cauldronState(self.hearth:getModData())
        local batch = M.stateOf(self.station:getModData().movableData or {}, M.INCUBATOR_KEY)
        litres = math.min(cauldron.ml or 0, M.milkRoom(batch, cauldron.ml or 0)) / 1000
    end
    if self.mode == "pourOut" and container then litres = container:getCapacity() end
    if self.mode == "carried" and container then litres = container:getAmount() end
    if self.mode == "collect" then litres = (M.JAR_ML[self.item:getFullType()] or M.OLD_JAR_ML) / 1000 end
    if self.mode == "cup" then litres = M.CUP_ML / 1000 end
    return Action.pourDuration(self.character, litres, 5)
end

-- item is nil for "hearth", which takes the hearth instead.
function TPYoghurtIncubator:new(character, station, item, mode, hearth)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.hearth = hearth
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
