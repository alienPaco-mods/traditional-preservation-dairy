-- Traditional Preservation (Dairy): the hand jobs at a Yogurt Incubator making kefir. "grains" puts kefir grains in
-- (items, one action for them all), "fire" pours milk from a Stone Hearth's cauldron (within 2 tiles), "milk" pours
-- milk in from a container, "strain" strains ready kefir into an empty container through a Strainer or a cloth
-- (twice as long; the grains come out with the first strain), "takeGrains" takes the grains back out of a pot with no milk.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

TPKefirIncubator = ISBaseTimedAction:derive("TPKefirIncubator")

local M = TraditionalPreservationDairy
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local Fire = require "TraditionalPreservationCore/Fire"
local Action = require "TraditionalPreservationCore/Action"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

-- Brought up to the minute first, so what goes in meets the pot as it is now.
local function batchNow(self)
    TraditionalPreservationDairyWorld.refresh(self.station)
    return TraditionalPreservationDairyWorld.batchOf(self.station)
end

local function now()
    return getGameTime():getWorldAgeHours()
end

local function carries(self, item)
    return self.character:getInventory():containsRecursive(item)
end

local function canDo(self)
    local batch = M.batchOf(self.station)
    if self.mode == "grains" then
        return M.grainRefusal(batch) == nil
    elseif self.mode == "fire" then
        local cauldron = Cauldron.cauldronModData(self.fire:getModData())
        return M.MILKS[cauldron.fluid] ~= nil and M.kefirMilkRefusal(batch, cauldron.ml or 0, cauldron.tempC or 0) == nil
    elseif self.mode == "milk" then
        local container = self.item:getFluidContainer()
        return M.milkIn(container) ~= nil
            and M.kefirMilkRefusal(batch, M.mlIn(container), M.carriedC(self.item, now(), self.character)) == nil
    elseif self.mode == "strain" then
        return M.isEmptyContainer(self.item) and M.stage(batch) == "KefirReady" and M.strainTool(self.character:getInventory()) ~= nil
    end
    return M.stage(batch) == "KefirGrains"
end

function TPKefirIncubator:isValid()
    if not self.station:getSquare() then return false end
    if self.mode == "fire" then
        if not self.fire:getSquare() then return false end
    elseif self.item and not carries(self, self.item) then
        return false
    end
    return canDo(self)
end

function TPKefirIncubator:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPKefirIncubator:start()
    self:setActionAnim("Loot")
end

-- Gives the grains (counts by grain key) as items, each with its record, set at hour.
local function giveGrains(self, grains, hour)
    local inventory = self.character:getInventory()
    for key, n in pairs(grains or {}) do
        for _ = 1, n do
            local item = inventory:AddItem(M.GRAIN)
            if item then item:getModData()[M.GRAIN_KEY] = M.grainOfKey(key, hour) end
        end
    end
end

-- What each mode does once the action is through: fn(self, batch, now).
local COMPLETE = {}

function COMPLETE.grains(self, batch, hour)
    local grains, items = {}, {}
    for _, item in ipairs(self.items) do
        local grain = carries(self, item) and M.grainOfItem(item, hour)
        if grain and M.grainShare(grain) > 0 then
            table.insert(grains, grain)
            table.insert(items, item)
        end
    end
    if M.addGrains(batch, grains, M.getLedger()) > 0 then
        for _, item in ipairs(items) do Action.removeItem(item) end
    end
end

function COMPLETE.fire(self, batch, hour)
    M.cauldronToKefir(Cauldron.of(self.fire), batch, hour, M.getLedger())
    Fire.redraw(self.fire)
end

function COMPLETE.milk(self, batch, hour)
    local container = self.item:getFluidContainer()
    local carry = M.carryOf(self.item)
    local _, parts = M.milkIn(container)
    local tempC = M.carriedC(self.item, hour, self.character)
    local ml = parts and M.addKefirMilk(batch, M.mlIn(container), tempC, hour, parts, M.getLedger()) or 0
    if ml > 0 then
        container:removeFluid(ml / 1000)
        M.recordTaken(self.item, carry, ml)
        FluidAgeing.clearIfEmpty(self.item)
    end
end

-- The kefir keeps the age it had in the pot (TP Core's FluidAgeing), and is renamed for it: separated if it was.
function COMPLETE.strain(self, batch, hour)
    local container = self.item:getFluidContainer()
    local ml, kefir, age, grains = M.strainKefir(batch, math.floor(container:getCapacity() * 1000))
    if ml <= 0 then return end
    FluidAgeing.clearIfEmpty(self.item)
    for name, part in pairs(kefir) do container:addFluid(name, part / 1000) end
    if age then self.item:getModData()[FluidAgeing.KEY] = age end
    FluidAgeing.look(self.item, hour)
    giveGrains(self, grains, hour)
end

function COMPLETE.takeGrains(self, batch, hour)
    giveGrains(self, M.takeGrains(batch), hour)
end

function TPKefirIncubator:complete()
    COMPLETE[self.mode](self, batchNow(self), now())
    TraditionalPreservationDairyWorld.refresh(self.station)
    return true
end

function TPKefirIncubator:perform()
    ISBaseTimedAction.perform(self)
end

function TPKefirIncubator:getDuration()
    if self.mode == "grains" or self.mode == "takeGrains" then return Action.duration(self.character, 60) end
    local litres = 0
    if self.mode == "fire" then
        local cauldron = Cauldron.cauldronModData(self.fire:getModData())
        litres = math.min(cauldron.ml or 0, M.milkRoom(M.batchOf(self.station), cauldron.ml or 0)) / 1000
    elseif self.mode == "milk" then
        litres = self.item:getFluidContainer():getAmount()
    elseif self.mode == "strain" then
        litres = math.min(self.item:getFluidContainer():getCapacity(), (M.batchOf(self.station).ml or 0) / 1000)
    end
    local duration = Action.pourDuration(self.character, litres, 5)
    if self.mode == "strain" and select(2, M.strainTool(self.character:getInventory())) then
        duration = duration * M.CLOTH_STRAIN_TIMES
    end
    return duration
end

-- item: the container for "milk" and "strain"; items: the grain items for "grains"; fire: the Stone Hearth for "fire".
function TPKefirIncubator:new(character, station, mode, item, items, fire)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.item = item
    o.items = items
    o.fire = fire
    o.maxTime = o:getDuration()
    return o
end
