-- Traditional Preservation (Dairy): Collect Dried Kefir Grains, from a Kefir Grains on a Cloth of an old save (new
-- grains dry on TP Core's Drying Cloth): the dry grains as Dried Kefir Grains, with the cloth back.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

TPKefirGrains = ISBaseTimedAction:derive("TPKefirGrains")

local M = TraditionalPreservationDairy
local Action = require "TraditionalPreservationCore/Action"
local DURATION = 60

local function carries(self, item)
    return self.character:getInventory():containsRecursive(item)
end

function TPKefirGrains:isValid()
    if not carries(self, self.item) then return false end
    local drying = M.keepDrying(self.item)
    return drying ~= nil and M.isDry(drying)
end

function TPKefirGrains:start()
    self:setActionAnim("Loot")
end

local COMPLETE = {}

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

-- "collect": item is the cloth of grains.
function TPKefirGrains:new(character, mode, item)
    local o = ISBaseTimedAction.new(self, character)
    o.mode = mode
    o.item = item
    o.maxTime = o:getDuration()
    return o
end
