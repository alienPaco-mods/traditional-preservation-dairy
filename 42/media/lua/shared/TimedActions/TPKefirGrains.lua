-- Traditional Preservation (Dairy): kefir grains in hand. "spread" spreads carried grains (none dead) on a cloth to
-- dry where it is left; "collect" takes the dry grains off it as Dried Kefir Grains, with the cloth back.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

TPKefirGrains = ISBaseTimedAction:derive("TPKefirGrains")

local M = TraditionalPreservationDairy
local Action = require "TraditionalPreservationCore/Action"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local DURATION = 60

local function carries(self, item)
    return self.character:getInventory():containsRecursive(item)
end

function TPKefirGrains:isValid()
    if self.mode == "spread" then
        if not carries(self, self.cloth) then return false end
        for _, item in ipairs(self.items) do
            if carries(self, item) then return true end
        end
        return false
    end
    if not carries(self, self.item) then return false end
    local drying = M.keepDrying(self.item)
    return drying ~= nil and M.isDry(drying)
end

function TPKefirGrains:start()
    self:setActionAnim("Loot")
end

local COMPLETE = {}

function COMPLETE.spread(self, hour)
    local count = 0
    for _, item in ipairs(self.items) do
        local grain = carries(self, item) and M.keepGrain(item, hour)
        if grain and grain.grainState ~= M.GRAIN_DEAD then
            Action.removeItem(item)
            count = count + 1
        end
    end
    if count == 0 then return end
    local clothType, weight = self.cloth:getFullType(), self.cloth:getActualWeight()
    Action.removeItem(self.cloth)
    local inventory = self.character:getInventory()
    local drying = inventory:AddItem(M.GRAIN_DRYING)
    drying:getModData()[M.DRYING_KEY] = M.newDrying(count, clothType, M.getLedger(), hour,
        FluidAgeing.placeOfItem(drying) or FluidAgeing.DEFAULT_PLACE)
    drying:setActualWeight(weight + count * 0.001)
    drying:setCustomWeight(true)
    M.keepDrying(drying, hour)
end

function COMPLETE.collect(self, hour)
    local drying = M.keepDrying(self.item, hour)
    local inventory = self.character:getInventory()
    Action.removeItem(self.item)
    for _ = 1, drying.count do inventory:AddItem(M.DRIED_GRAIN) end
    inventory:AddItem(drying.cloth)
end

function TPKefirGrains:complete()
    COMPLETE[self.mode](self, getGameTime():getWorldAgeHours())
    return true
end

function TPKefirGrains:perform()
    ISBaseTimedAction.perform(self)
end

function TPKefirGrains:getDuration()
    return Action.duration(self.character, DURATION)
end

-- "spread": items are the grain items, cloth the cloth; "collect": item is the cloth of grains.
function TPKefirGrains:new(character, mode, item, items, cloth)
    local o = ISBaseTimedAction.new(self, character)
    o.mode = mode
    o.item = item
    o.items = items
    o.cloth = cloth
    o.maxTime = o:getDuration()
    return o
end
