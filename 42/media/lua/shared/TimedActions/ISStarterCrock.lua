-- Traditional Preservation (Dairy): the hand jobs at a Starter Culture Crock. "load" puts in wheat and half a litre
-- of warm milk from a Hearth's copper (within 2 tiles), "feed" adds half a litre of fresh milk once the grain has cultivated, and "collect" takes out the
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

local function hasMilk(item, ml)
    local container = item and item:getFluidContainer()
    return M.milkIn(container) ~= nil and container:getAmount() * 1000 >= ml - 0.5
end

-- Half a litre of milk at 35 C or more in the copper.
local function copperReady(copper)
    return M.copperWarm(copper) and copper.ml >= M.CROCK_LOAD_ML - 0.5
end
ISStarterCrock.copperReady = copperReady

local function copperOf(hearth)
    local World = TraditionalPreservationDairyWorld
    if World then return World.updateHearth(hearth, getGameTime():getWorldAgeHours()) end
    return M.stateOf(hearth:getModData(), M.HEARTH_KEY)
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
        return stage == "Empty" and self.hearth:getSquare() ~= nil
            and copperReady(M.stateOf(self.hearth:getModData(), M.HEARTH_KEY))
    elseif self.mode == "feed" then
        return stage == "Waiting" and inInventory(self, self.item) and hasMilk(self.item, M.CROCK_FEED_ML)
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
        local copper = copperOf(self.hearth)
        if copperReady(copper) and M.loadCrock(crock, ledger) then
            for _, seed in ipairs(self.wheat) do
                local container = seed:getContainer()
                if container then container:DoRemoveItem(seed) end
            end
            M.takeFromCopper(copper, M.CROCK_LOAD_ML)
            if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.refresh(self.hearth) end
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

-- item is the milk's container for "feed"; wheat is the list of seeds and hearth the copper's for "load".
function ISStarterCrock:new(character, station, mode, item, wheat, hearth)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.hearth = hearth
    o.mode = mode
    o.item = item
    o.wheat = wheat or {}
    o.maxTime = o:getDuration()
    return o
end
