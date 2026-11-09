-- Traditional Preservation (Dairy): the hand jobs at a Starter Culture Crock. "load" puts in wheat and half a litre
-- of warm milk, "feed" adds half a litre of fresh milk once the grain has cultivated, and "collect" takes out the
-- Active Yoghurt Starters.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

ISStarterCrock = ISBaseTimedAction:derive("ISStarterCrock")

local M = TraditionalPreservationDairy
local DURATIONS = { load = 120, feed = 60, collect = 60 }

local function state(self)
    local World = TraditionalPreservationDairyWorld
    -- Brought up to the minute first, so a crock that has just turned is seen as it is now.
    if World then
        World.refresh(self.station)
        return World.crockState(self.station)
    end
    return M.stateOf(self.station:getModData().movableData or {}, M.CROCK_KEY)
end

local function hasMilk(item, ml, warm)
    local container = item and item:getFluidContainer()
    if not M.milkIn(container) or container:getAmount() * 1000 < ml - 0.5 then return false end
    return not warm or M.isWarm(item:getItemHeat())
end

local function inInventory(self, item)
    return self.character:getInventory():containsRecursive(item)
end

function ISStarterCrock:isValid()
    if not self.station:getSquare() then return false end
    local stage = M.crockStage(M.stateOf(self.station:getModData().movableData or {}, M.CROCK_KEY))
    if self.mode == "load" then
        for _, seed in ipairs(self.wheat) do
            if not inInventory(self, seed) then return false end
        end
        return stage == "Empty" and inInventory(self, self.item) and hasMilk(self.item, M.CROCK_LOAD_ML, true)
    elseif self.mode == "feed" then
        return stage == "Waiting" and inInventory(self, self.item) and hasMilk(self.item, M.CROCK_FEED_ML, false)
    end
    return stage == "Ready"
end

function ISStarterCrock:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function ISStarterCrock:start()
    self:setActionAnim("Loot")
end

function ISStarterCrock:complete()
    local crock = state(self)
    local ledger = M.getLedger()
    if self.mode == "load" then
        if M.loadCrock(crock, ledger) then
            for _, seed in ipairs(self.wheat) do
                local container = seed:getContainer()
                if container then container:DoRemoveItem(seed) end
            end
            self.item:getFluidContainer():removeFluid(M.CROCK_LOAD_ML / 1000)
        end
    elseif self.mode == "feed" then
        if M.feedCrock(crock, ledger) then self.item:getFluidContainer():removeFluid(M.CROCK_FEED_ML / 1000) end
    else
        for _ = 1, M.collectStarters(crock) do
            Actions.addOrDropItem(self.character, instanceItem(M.STARTER))
        end
        self.character:getXp():AddXP(Perks.Cooking, M.COLLECT_XP)
    end
    if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.refresh(self.station) end
    return true
end

function ISStarterCrock:perform()
    ISBaseTimedAction.perform(self)
end

function ISStarterCrock:getDuration()
    return DURATIONS[self.mode]
end

-- item is the milk's container (nil to collect); wheat is the list of seeds for "load".
function ISStarterCrock:new(character, station, mode, item, wheat)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.item = item
    o.wheat = wheat or {}
    o.maxTime = o:getDuration()
    return o
end
