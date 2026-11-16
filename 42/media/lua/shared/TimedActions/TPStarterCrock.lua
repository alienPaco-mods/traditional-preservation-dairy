-- Traditional Preservation (Dairy): the hand jobs at a Starter Culture Crock. "load" puts in wheat and half a litre
-- of milk at 35 to 45 C from a Stone Hearth's cauldron (within 2 tiles) or a carried container, "clabber" puts in half a litre
-- of soured milk instead (no wheat, any warmth), "feed" adds half a litre of fresh milk once the culture has taken, and
-- "collect" takes out the Active Yogurt Starters.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationDairy"

TPStarterCrock = ISBaseTimedAction:derive("TPStarterCrock")

local M = TraditionalPreservationDairy
local Action = require "TraditionalPreservationCore/Action"
local Fire = require "TraditionalPreservationCore/Fire"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local DURATIONS = { load = 120, clabber = 60, feed = 60, collect = 60 }

-- Brought up to the minute first, so a crock that has just turned is seen as it is now.
local function crockNow(self)
    TraditionalPreservationDairyWorld.refresh(self.station)
    return TraditionalPreservationDairyWorld.crockOf(self.station)
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
    local stage = M.crockStage(M.crockOf(self.station))
    if self.mode == "load" then
        -- The wheat is looked for once, before the action starts, and again as it ends: not on every tick.
        if not self.started and not hasWheat(self) then return false end
        if stage ~= "Empty" then return false end
        if self.item then return inInventory(self, self.item) and itemReady(self) end
        return self.fire:getSquare() ~= nil and cauldronReady(Cauldron.cauldronModData(self.fire:getModData()))
    elseif self.mode == "clabber" then
        return stage == "Empty" and inInventory(self, self.item) and M.clabberRefusal(self.item:getFluidContainer()) == nil
    elseif self.mode == "feed" then
        return stage == "Waiting" and inInventory(self, self.item) and M.hasMilk(self.item, M.CROCK_FEED_ML)
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
    local crock = crockNow(self)
    local ledger = M.getLedger()
    if self.mode == "load" then
        local cauldron = not self.item and Cauldron.of(self.fire)
        local ready = self.item and itemReady(self) or cauldron and cauldronReady(cauldron)
        if ready and hasWheat(self) and M.loadCrock(crock, ledger) then
            for _, seed in ipairs(self.wheat) do Action.removeItem(seed) end
            if self.item then
                local carry = M.carryOf(self.item)
                self.item:getFluidContainer():removeFluid(M.CROCK_LOAD_ML / 1000)
                M.recordTaken(self.item, carry, M.CROCK_LOAD_ML)
                FluidAgeing.clearIfEmpty(self.item)
            else
                CauldronFluid.take(cauldron, M.CROCK_LOAD_ML)
                Fire.redraw(self.fire)
            end
        end
    elseif self.mode == "clabber" then
        if M.clabberRefusal(self.item:getFluidContainer()) == nil and M.clabberCrock(crock) then
            self.item:getFluidContainer():removeFluid(M.CLABBER_ML / 1000)
            FluidAgeing.clearIfEmpty(self.item)
        end
    elseif self.mode == "feed" then
        if M.feedCrock(crock, ledger) then
            self.item:getFluidContainer():removeFluid(M.CROCK_FEED_ML / 1000)
            -- An emptied container forgets its milk's age (fixed 2026-11-14), as after a clabber.
            FluidAgeing.clearIfEmpty(self.item)
        end
    else
        for _ = 1, M.collectStarters(crock) do
            Actions.addOrDropItem(self.character, instanceItem(M.STARTER))
        end
        self.character:getXp():AddXP(Perks.Cooking, M.COLLECT_XP)
    end
    TraditionalPreservationDairyWorld.refresh(self.station)
    return true
end

function TPStarterCrock:perform()
    ISBaseTimedAction.perform(self)
end

function TPStarterCrock:getDuration()
    return Action.duration(self.character, DURATIONS[self.mode])
end

-- item is the milk's container for "clabber" and "feed", and for "load" from a carried container; wheat is the list of seeds
-- for "load", and fire the cauldron's when it loads from the Stone Hearth.
function TPStarterCrock:new(character, station, mode, item, wheat, fire)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.fire = fire
    o.mode = mode
    o.item = item
    o.wheat = wheat or {}
    o.maxTime = o:getDuration()
    return o
end
