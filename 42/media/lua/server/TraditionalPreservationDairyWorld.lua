-- Traditional Preservation (Dairy) B42: keeps track of every Yogurt Incubator and Starter Culture Crock, records
-- the weather and its hourly history, brings each pot's milk and each crock's culture up to the hour and layers the
-- sprite for its stage. A station's state sits in movableData, so it goes with it when it is picked up full and
-- carried to the fire. The Hearth is TP Core's, which keeps its copper up to date (TraditionalPreservationCore/HearthWorld).
if isClient() then return end

TraditionalPreservationDairyWorld = TraditionalPreservationDairyWorld or {}
local M = TraditionalPreservationDairy
local World = TraditionalPreservationDairyWorld
require "Fluids/ISFluidTransferAction"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "TraditionalPreservationDairy/Tiles"
local log = require "TraditionalPreservationCore/Log"

-- Each stage has its own look: an empty pot has its lid on the floor, one too cold for a starter has it slid half off.
local STAGE_SPRITES = { Empty = "Empty", Cooling = "Cooling", TooCold = "TooCold", Incubating = "Incubating",
    Ready = "Ready" }
-- A crock waiting for its feed still shows the cloth.
local CROCK_SPRITES = { Cultivating = "Cultivating", Waiting = "Cultivating", Developing = "Developing", Ready = "Ready" }

local function squareKey(object)
    local square = object:getSquare()
    return square and (square:getX() .. "," .. square:getY() .. "," .. square:getZ())
end

-- The pot's state, made on first use.
function World.incubatorState(station)
    return M.stateOf(Station.movableData(station), M.INCUBATOR_KEY)
end

-- Brings the pot up to now. The time since the last look counts at the place it was seen in then: by a fire,
-- while the fuel it had then lasts. A pot that has been moved counts its time where it stands now.
function World.updateIncubator(station, now)
    local state = World.incubatorState(station)
    local place, fire = M.placeOf(station)
    local here = squareKey(station)
    local before = M.stage(state)
    M.catchUp(state, now, state.at == here and state.place or place, M.getHistory(), M.getLedger())
    state.place, state.at = place, here
    M.noteFire(state, station, fire, now)
    local after = M.stage(state)
    if after ~= before then
        log("TPD", "incubator %s -> %s: %.1f L at %.1f C, %s", before, after, (state.ml or 0) / 1000, state.tempC or 0, place)
    end
    return state
end

function World.crockState(station)
    return M.stateOf(Station.movableData(station), M.CROCK_KEY)
end

-- Brings the crock up to now on the ledger, at the place it was seen in last, as for the pot.
function World.updateCrock(station)
    local state = World.crockState(station)
    local place, fire = M.placeOf(station)
    local here = squareKey(station)
    local before = M.crockStage(state)
    M.updateCrock(state, M.getLedger(), state.at == here and state.place or place)
    state.place, state.at = place, here
    M.noteFire(state, station, fire, getGameTime():getWorldAgeHours())
    local after = M.crockStage(state)
    if after ~= before then log("TPD", "crock %s -> %s, %s", before, after, place) end
    return state
end

-- A built station is a thumpable that blocks its whole square, whatever its tile says. The pot and the crock are
-- small enough to walk past (user, 2026-11-09), so that is switched off on each one the World looks at.
local function walkThrough(station)
    if instanceof(station, "IsoThumpable") and (station:isBlockAllTheSquare() or not station:isCanPassThrough()) then
        station:setBlockAllTheSquare(false)
        station:setCanPassThrough(true)
    end
end

local function refresh(station, entry)
    local overlay
    if entry.crock then
        overlay = M.CROCK_OVERLAYS[CROCK_SPRITES[M.crockStage(World.updateCrock(station))]]
    else
        local state = World.updateIncubator(station, getGameTime():getWorldAgeHours())
        overlay = M.INCUBATOR_OVERLAYS[STAGE_SPRITES[M.stage(state)]]
    end
    walkThrough(station)
    local names = {}
    if overlay then table.insert(names, M.spriteName(overlay + entry.faceIndex)) end
    Station.showSprites(station, entry, tostring(overlay), names)
end

-- Only this mod's stations: which kind, and which way it faces.
local function newEntry(station)
    local kind, face = M.stationKind(station)
    if not kind then return nil end
    return { faceIndex = face, crock = kind == "crock" }
end

-- A pot or crock just built or put down isn't known to the map loader, and its bare base must never show, so the
-- tracker looks for new ones round each player (scan): a new station gets its stage sprite at once.
local tracker = Station.tracker({ sprites = Tiles.STATIONS, entry = newEntry, refresh = refresh, scan = true })

World.track = tracker.track

-- Redraws a tracked station now, without waiting for the next tick, e.g. after a pour.
function World.refresh(station)
    local entry = tracker.track(station)
    if entry then refresh(station, entry) end
end

-- Every tracked station of the kind that is loaded, for the dev console: incubators, or crocks if crock is true.
function World.stations(crock)
    local list = {}
    for object, entry in pairs(tracker.tracked) do
        if Station.isLoaded(object) and entry.crock == (crock or false) then table.insert(list, object) end
    end
    return list
end

-- Warm milk a player carries (in a wrapped pot, jar or bucket, or an open pot off the heat) cools where the player is;
-- set down, it keeps that place (M.carryTick).
local function carried(item)
    return item:getModData()[M.CARRY_KEY] ~= nil or M.isWrapped(item)
end

local function tickWrappedPots(player, now, ledger)
    local pots = player:getInventory():getAllEvalRecurse(carried)
    if pots:isEmpty() then return end
    local place, fire = M.placeOf(player)
    local notes = {}
    M.noteFire(notes, player, fire, now)
    -- Vanilla's item heat (the red row) follows the record; with no milk record it goes back to room.
    for i = 0, pots:size() - 1 do
        local pot = pots:get(i)
        local carry = M.carryOf(pot)
        if carry then
            M.carryTick(carry, now, ledger, place, notes.fireUntil, notes.under, not M.isWrappedPot(pot))
            pot:setItemHeat(M.itemHeat(carry.c))
        elseif pot:getItemHeat() ~= 1 then
            pot:setItemHeat(1)
        end
    end
end

-- A wrap in a hot stove, oven, barbecue or fire burns: the Sheet and Twine are gone (M.burnWrap). On a stove, oven or
-- barbecue it sets the kitchen alight, as vanilla's burnt food does; in an open fire (a fireplace, the Hearth's
-- firebox, a campfire) it burns away in the fire, as burnt food there never spreads (ENGINE_NOTES).
World.BURN_RADIUS = 8

local function isOpenFire(object)
    return instanceof(object, "IsoFireplace") or object:getName() == "Campfire"
end

local function burnWraps(square)
    Station.hotContainers(square, World.BURN_RADIUS, M.BURN_HEAT, function(container, object)
        local wrapped = container:getAllEvalRecurse(M.isWrapped)
        for i = 0, wrapped:size() - 1 do
            local item = wrapped:get(i)
            log("TPD", "a wrap burnt on %s at %d,%d,%d", item:getFullType(), object:getX(), object:getY(), object:getZ())
            M.burnWrap(item)
            if not isOpenFire(object) and object:getSquare() then
                IsoFireManager.StartFire(getCell(), object:getSquare(), true, 500000)
            end
        end
    end)
end

Events.EveryOneMinute.Add(function()
    local now, ledger, list = getGameTime():getWorldAgeHours(), M.getLedger(), Station.players()
    for i = 0, list:size() - 1 do
        tickWrappedPots(list:get(i), now, ledger)
        burnWraps(list:get(i):getSquare())
    end
end)

Weather.record(function(now, climate)
    M.record(M.getLedger(), M.getHistory(), now, climate:getTemperature())
end)

-- A vanilla pour carries the heat: what goes in mixes, by volume, with what was there, so a pot just off the stove
-- poured into a Wrapped Pot keeps its heat. Read at the start, written when the pour ends or is stopped.
local function itemOf(fluidObject)
    local owner = fluidObject and fluidObject:getOwner()
    return instanceof(owner, "InventoryItem") and owner or nil
end

local vanillaStart, vanillaStop, vanillaComplete = ISFluidTransferAction.start, ISFluidTransferAction.stop, ISFluidTransferAction.complete

function ISFluidTransferAction:start()
    local source, target = itemOf(self.source), itemOf(self.target)
    if source and target and M.milkIn(source:getFluidContainer()) then
        local now, character = getGameTime():getWorldAgeHours(), self.character
        local sourceCarry, targetContainer = M.carryOf(source), target:getFluidContainer()
        local hadMl = M.mlIn(targetContainer)
        self.tpdPour = {
            fromC = M.carriedC(source, now, character),
            scalded = M.isScalded(sourceCarry, M.mlIn(source:getFluidContainer())),
            warm = sourceCarry ~= nil,
            hadMl = hadMl,
            hadC = hadMl > 0 and M.carriedC(target, now, character) or 0,
        }
    end
    return vanillaStart(self)
end

local function finishPour(self)
    local pour, target = self.tpdPour, itemOf(self.target)
    self.tpdPour = nil
    if not pour or not target then return end
    -- Only warm milk, or milk onto a record, needs one: cold onto nothing stays vanilla.
    local carry = target:getModData()[M.CARRY_KEY]
    if not pour.warm and not carry then return end
    local moved = M.mlIn(target:getFluidContainer()) - pour.hadMl
    M.pouredInto(target, carry, pour.hadMl, pour.hadC, moved, pour.fromC, pour.scalded, getGameTime():getWorldAgeHours())
end

function ISFluidTransferAction:stop()
    finishPour(self)
    return vanillaStop(self)
end

function ISFluidTransferAction:complete()
    local result = vanillaComplete(self)
    finishPour(self)
    return result
end

tracker.start()
