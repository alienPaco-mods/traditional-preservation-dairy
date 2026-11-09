-- Traditional Preservation (Dairy): the hand jobs at a Hearth's copper. "pourIn" empties a container of one plain
-- fluid into the copper, as much as fits; "fillFrom" fills an empty container, or one of the same fluid, from it.
-- The copper holds one fluid at a time: cow's and sheep's milk count as two.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

ISDairyHearth = ISBaseTimedAction:derive("ISDairyHearth")

local M = TraditionalPreservationDairy
local BASE_DURATION = 40
local DURATION_PER_LITRE = 12

local function copperOf(hearth)
    local World = TraditionalPreservationDairyWorld
    -- Brought up to the minute first, so poured fluid mixes with the copper as it is now.
    if World then return World.updateHearth(hearth, getGameTime():getWorldAgeHours()) end
    return M.stateOf(hearth:getModData(), M.HEARTH_KEY)
end

-- Millilitres the container has room for.
local function roomIn(container)
    return math.floor((container:getCapacity() - container:getAmount()) * 1000 + 0.5)
end

local function canFillFrom(container, copper)
    if (copper.ml or 0) <= 0 or roomIn(container) <= 0 then return false end
    return container:isEmpty() or M.fluidIn(container) == copper.fluid
end
ISDairyHearth.canFillFrom = canFillFrom

function ISDairyHearth:isValid()
    if not self.hearth:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    local container = self.item:getFluidContainer()
    local copper = M.stateOf(self.hearth:getModData(), M.HEARTH_KEY)
    if self.mode == "pourIn" then
        local fluid = M.fluidIn(container)
        return fluid ~= nil and M.copperRoom(copper, fluid, 1) > 0
    end
    return canFillFrom(container, copper)
end

function ISDairyHearth:waitToStart()
    self.character:faceThisObject(self.hearth)
    return self.character:shouldBeTurning()
end

function ISDairyHearth:start()
    self:setActionAnim("Loot")
end

function ISDairyHearth:complete()
    local copper = copperOf(self.hearth)
    local now = getGameTime():getWorldAgeHours()
    local container = self.item:getFluidContainer()
    if self.mode == "pourIn" then
        local fluid = M.fluidIn(container)
        local ml = math.floor(container:getAmount() * 1000 + 0.5)
        local taken = fluid and M.pourIntoCopper(copper, fluid, ml, M.heatCelsius(self.item:getItemHeat()), now) or 0
        if taken > 0 then container:removeFluid(taken / 1000) end
    elseif canFillFrom(container, copper) then
        local ml, fluid, tempC = M.takeFromCopper(copper, roomIn(container))
        if ml > 0 then
            container:addFluid(fluid, ml / 1000)
            self.item:setItemHeat(M.itemHeat(tempC))
        end
    end
    if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.refresh(self.hearth) end
    return true
end

function ISDairyHearth:perform()
    ISBaseTimedAction.perform(self)
end

function ISDairyHearth:getDuration()
    local container = self.item:getFluidContainer()
    local litres = 0
    if container and self.mode == "pourIn" then litres = container:getAmount() end
    if container and self.mode == "fillFrom" then litres = container:getCapacity() - container:getAmount() end
    return BASE_DURATION + math.floor(math.min(litres, 10) * DURATION_PER_LITRE)
end

function ISDairyHearth:new(character, hearth, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.hearth = hearth
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
