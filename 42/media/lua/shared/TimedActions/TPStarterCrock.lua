-- Traditional Preservation (Dairy): the hand jobs at a Starter Culture Crock. "load" puts in wheat and half a litre
-- of milk at 35 to 45 C from a Hearth's cauldron (within 2 tiles) or a carried container, "clabber" puts in half a litre
-- of soured milk instead (no wheat, any warmth), "feed" adds half a litre of fresh milk once the culture has taken, and
-- "collect" takes out the Active Yogurt Starters.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

TPStarterCrock = ISBaseTimedAction:derive("TPStarterCrock")

local M = TraditionalPreservationDairy
local Action = require "TraditionalPreservationCore/Action"
local Hearth = require "TraditionalPreservationCore/Hearth"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local DURATIONS = { load = 120, clabber = 60, feed = 60, collect = 60 }

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

-- Half a litre of milk at 35 to 45 C in the cauldron.
local function cauldronReady(cauldron)
    return M.MILKS[cauldron.fluid] == true and M.crockLoadRefusal(cauldron.ml or 0, cauldron.tempC or 0) == nil
end
TPStarterCrock.cauldronReady = cauldronReady

local function inInventory(self, item)
    return self.character:getInventory():containsRecursive(item)
end

local function hasWheat(self)
    for _, seed in ipairs(self.wheat) do
        if not inInventory(self, seed) then return false end
    end
    return true
end

-- Half a litre of plain milk at 35 to 45 C in a carried container.
local function itemReady(self)
    local container = self.item:getFluidContainer()
    return M.milkIn(container) ~= nil
        and M.crockLoadRefusal(M.mlIn(container), M.carriedC(self.item, getGameTime():getWorldAgeHours(), self.character)) == nil
end

function TPStarterCrock:isValid()
    if not self.station:getSquare() then return false end
    local stage = M.crockStage(M.stateOf(self.station:getModData().movableData or {}, M.CROCK_KEY))
    if self.mode == "load" then
        -- The wheat is looked for once, before the action starts, and again as it ends: not on every tick.
        if not self.started and not hasWheat(self) then return false end
        if stage ~= "Empty" then return false end
        if self.item then return inInventory(self, self.item) and itemReady(self) end
        return self.hearth:getSquare() ~= nil and cauldronReady(Hearth.cauldronState(self.hearth:getModData()))
    elseif self.mode == "clabber" then
        return stage == "Empty" and inInventory(self, self.item) and M.clabberRefusal(self.item:getFluidContainer()) == nil
    elseif self.mode == "feed" then
        return stage == "Waiting" and inInventory(self, self.item) and hasMilk(self.item, M.CROCK_FEED_ML)
    end
    return stage == "Ready"
end

function TPStarterCrock:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPStarterCrock:start()
    self.started = true
    self:setActionAnim("Loot")
end

function TPStarterCrock:complete()
    local crock = state(self)
    local ledger = M.getLedger()
    if self.mode == "load" then
        local cauldron = not self.item and Hearth.cauldronOf(self.hearth)
        local ready = self.item and itemReady(self) or cauldron and cauldronReady(cauldron)
        if ready and hasWheat(self) and M.loadCrock(crock, ledger) then
            for _, seed in ipairs(self.wheat) do
                local container = seed:getContainer()
                if container then container:DoRemoveItem(seed) end
            end
            if self.item then
                local carry = M.carryOf(self.item)
                self.item:getFluidContainer():removeFluid(M.CROCK_LOAD_ML / 1000)
                M.recordTaken(self.item, carry, M.CROCK_LOAD_ML)
            else
                Hearth.take(cauldron, M.CROCK_LOAD_ML)
                if Hearth.World then Hearth.World.refresh(self.hearth) end
            end
        end
    elseif self.mode == "clabber" then
        if M.clabberRefusal(self.item:getFluidContainer()) == nil and M.clabberCrock(crock) then
            self.item:getFluidContainer():removeFluid(M.CLABBER_ML / 1000)
            FluidAgeing.clearIfEmpty(self.item)
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

function TPStarterCrock:perform()
    ISBaseTimedAction.perform(self)
end

function TPStarterCrock:getDuration()
    return Action.duration(self.character, DURATIONS[self.mode])
end

-- item is the milk's container for "clabber" and "feed", and for "load" from a carried container; wheat is the list of seeds
-- for "load", and hearth the cauldron's when it loads from the Hearth.
function TPStarterCrock:new(character, station, mode, item, wheat, hearth)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.hearth = hearth
    o.mode = mode
    o.item = item
    o.wheat = wheat or {}
    o.maxTime = o:getDuration()
    return o
end
