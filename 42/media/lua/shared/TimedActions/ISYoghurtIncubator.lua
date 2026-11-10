-- Traditional Preservation (Dairy): the hand jobs at a Yoghurt Incubator. "hearth" pours milk steaming from a
-- Hearth's copper (within 2 tiles) in, "carried" pours steamed milk in from a container, "starter" stirs in a yoghurt or an Active Yoghurt Starter, "pourOut" takes the milk back out into an empty
-- container (still steamed) to reheat it, "collect" fills an empty Clay Jar with a litre of set yoghurt, and "cup"
-- fills an Empty Yoghurt Container with a quarter litre.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"
require "TraditionalPreservationDairyYoghurt"

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

local function copperOf(hearth)
    local World = TraditionalPreservationDairyWorld
    if World then return World.updateHearth(hearth, getGameTime():getWorldAgeHours()) end
    return M.stateOf(hearth:getModData(), M.HEARTH_KEY)
end

local function canDo(self)
    local batch = M.stateOf(self.station:getModData().movableData or {}, M.INCUBATOR_KEY)
    if self.mode == "hearth" then
        return M.copperHot(M.stateOf(self.hearth:getModData(), M.HEARTH_KEY)) and M.milkRoom(batch, 1) > 0
    elseif self.mode == "carried" then
        local container = self.item:getFluidContainer()
        local fluid = M.milkIn(container)
        return fluid ~= nil and M.carriedRefusal(M.carryOf(self.item), M.mlIn(container)) == nil
            and M.milkRoom(batch, 1, fluid) > 0
    elseif self.mode == "starter" then
        return M.STARTERS[self.item:getFullType()] ~= nil and not self.item:isRotten() and M.canAddStarter(batch)
    elseif self.mode == "pourOut" then
        return M.isEmptyContainer(self.item) and (M.stage(batch) == "Cooling" or M.stage(batch) == "TooCold")
    elseif self.mode == "cup" then
        return self.item:getFullType() == M.EMPTY_CUP and M.stage(batch) == "Ready"
    end
    return M.JARS[self.item:getFullType()] == true and M.isEmptyContainer(self.item) and M.stage(batch) == "Ready"
end

function ISYoghurtIncubator:isValid()
    if not self.station:getSquare() then return false end
    if self.mode == "hearth" then
        if not self.hearth:getSquare() then return false end
    elseif not self.character:getInventory():containsRecursive(self.item) then
        return false
    end
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
    local container = self.item and self.item:getFluidContainer()
    if self.mode == "hearth" then
        M.copperToPot(copperOf(self.hearth), batch, now)
        if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.refresh(self.hearth) end
    elseif self.mode == "carried" then
        local carry = M.carryOf(self.item)
        local fluid = M.milkIn(container)
        local tempC = M.carriedC(self.item, now, self.character)
        local ml = M.milkRoom(batch, M.mlIn(container), fluid)
        if ml > 0 and M.addMilk(batch, ml, tempC, now) > 0 then
            batch.fluid = batch.fluid or fluid
            container:removeFluid(ml / 1000)
            M.recordTaken(self.item, carry, ml)
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
            -- Everything in the pot came in steamed, so it goes out steamed.
            M.recordCarry(self.item, nil, 0, 0, ml, tempC, now, true)
        end
    elseif self.mode == "cup" then
        local ml, age = M.collectCup(batch, now)
        if ml > 0 then
            removeItem(self.item)
            give(self, "Base.Yoghurt"):setAge(age)
            self.character:getXp():AddXP(Perks.Cooking, M.COLLECT_XP * ml / M.JAR_ML)
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
            if M.JAR_ICONS[jarType] then jar:setTexture(getTexture(M.JAR_ICONS[jarType])) end
            jar:getModData().tpdMl = ml
            jar:getModData().tpdCups = M.cupsFor(ml)
            M.labelJar(jar)
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
    local container = self.item and self.item:getFluidContainer()
    local litres = 0
    if self.mode == "hearth" then
        local copper = M.stateOf(self.hearth:getModData(), M.HEARTH_KEY)
        local batch = M.stateOf(self.station:getModData().movableData or {}, M.INCUBATOR_KEY)
        litres = math.min(copper.ml or 0, M.milkRoom(batch, copper.ml or 0)) / 1000
    end
    if self.mode == "pourOut" and container then litres = container:getCapacity() end
    if self.mode == "carried" and container then litres = container:getAmount() end
    if self.mode == "collect" then litres = M.JAR_ML / 1000 end
    if self.mode == "cup" then litres = M.CUP_ML / 1000 end
    return BASE_DURATION + math.floor(math.min(litres, 5) * DURATION_PER_LITRE)
end

-- item is nil for "hearth", which takes the hearth instead.
function ISYoghurtIncubator:new(character, station, item, mode, hearth)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.hearth = hearth
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
