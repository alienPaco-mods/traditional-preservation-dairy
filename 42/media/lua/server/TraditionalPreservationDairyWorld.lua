-- Traditional Preservation (Dairy) B42: keeps track of every Yogurt Incubator and Starter Culture Crock, records
-- the weather and its hourly history, brings each pot's milk and each crock's culture up to the hour and layers the
-- sprite for its stage. A station's modData sits in movableData, so it goes with it when it is picked up full and
-- carried to the fire. The Stone Hearth is TP Core's, which keeps its cauldron up to date (TraditionalPreservationCore/FireWorld).
if isClient() then return end

TraditionalPreservationDairyWorld = TraditionalPreservationDairyWorld or {}
local M = TraditionalPreservationDairy
local World = TraditionalPreservationDairyWorld
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "TraditionalPreservationDairy/Tiles"
local log = require "TraditionalPreservationCore/Log"
local Pour = require "TraditionalPreservationCore/Pour"

-- Each pot stage has its own look, by its name (M.INCUBATOR_OVERLAYS): an empty pot has its lid on the floor, one too
-- cold for a starter has it slid half off. A crock waiting for its feed still shows the cloth.
local CROCK_SPRITES = { Cultivating = "Cultivating", Waiting = "Cultivating", Developing = "Developing", Ready = "Ready" }

local function squareKey(station)
    local square = station:getSquare()
    return square and (square:getX() .. "," .. square:getY() .. "," .. square:getZ())
end

-- The pot's batch and the crock's culture as saved, made on first use.
World.batchOf = M.batchOf
World.crockOf = M.crockOf

-- Brings a station's modData up to now: run(stationModData, place) counts the time since the last look at the place it was seen
-- in then (by a fire, while the fuel it had then lasts; a station that has been moved, where it stands now). Then
-- notes where it is and its fire, and logs a change of stage (stageOf; label and describe(stationModData, place) for the line).
local function bringUp(station, stationModData, now, stageOf, run, label, describe)
    local place, fire = M.placeOf(station)
    local here = squareKey(station)
    local before = stageOf(stationModData)
    run(stationModData, stationModData.at == here and stationModData.place or place)
    stationModData.place, stationModData.at = place, here
    M.noteFire(stationModData, station, fire, now)
    local after = stageOf(stationModData)
    if after ~= before then log("TPD", "%s %s -> %s%s", label, before, after, describe(stationModData, place)) end
    return stationModData
end

function World.updateIncubator(station, now)
    return bringUp(station, World.batchOf(station), now, M.stage, function(batch, place)
        M.catchUp(batch, now, place, M.getHistory(), M.getLedger())
    end, "incubator", function(batch, place)
        return string.format(": %.1f L at %.1f C, %s", (batch.ml or 0) / 1000, batch.tempC or 0, place)
    end)
end

-- On the ledger, as for the pot.
function World.updateCrock(station)
    return bringUp(station, World.crockOf(station), getGameTime():getWorldAgeHours(), M.crockStage, function(crock, place)
        M.updateCrock(crock, M.getLedger(), place)
    end, "crock", function(_, place)
        return ", " .. place
    end)
end

-- A built station is a thumpable that blocks its whole square, whatever its tile says. The pot and the crock are
-- small enough to walk past, so that is switched off on each one the World looks at.
local function walkThrough(station)
    if instanceof(station, "IsoThumpable") and (station:isBlockAllTheSquare() or not station:isCanPassThrough()) then
        station:setBlockAllTheSquare(false)
        station:setCanPassThrough(true)
    end
end

local function refresh(station, sessionState)
    local overlay
    if sessionState.crock then
        overlay = M.CROCK_OVERLAYS[CROCK_SPRITES[M.crockStage(World.updateCrock(station))]]
    else
        local batch = World.updateIncubator(station, getGameTime():getWorldAgeHours())
        overlay = M.INCUBATOR_OVERLAYS[M.stage(batch)]
    end
    walkThrough(station)
    local names = {}
    if overlay then table.insert(names, M.spriteName(overlay + sessionState.faceIndex)) end
    Station.showSprites(station, sessionState, tostring(overlay), names)
end

-- Only this mod's stations: which kind, and which way it faces.
local function newSessionState(station)
    local kind, face = M.stationKind(station)
    if not kind then return nil end
    return { faceIndex = face, crock = kind == "crock" }
end

-- A pot or crock just built or put down isn't known to the map loader, and its bare base must never show, so the
-- tracker looks for new ones round each player (scan): a new station gets its stage sprite at once.
local tracker = Station.tracker({ sprites = Tiles.STATIONS, newSessionState = newSessionState, refresh = refresh, scan = true })

World.track = tracker.track

-- Redraws a tracked station now, without waiting for the next tick, e.g. after a pour.
function World.refresh(station)
    local sessionState = tracker.track(station)
    if sessionState then refresh(station, sessionState) end
end

-- Every tracked station of the kind that is loaded, for the dev console: incubators, or crocks if crock is true.
function World.stations(crock)
    local stations = {}
    for station, sessionState in pairs(tracker.tracked) do
        if Station.isLoaded(station) and sessionState.crock == (crock or false) then table.insert(stations, station) end
    end
    return stations
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
    -- Vanilla's item heat (the red row) follows the carry; with no carry it goes back to room.
    for i = 0, pots:size() - 1 do
        local pot = pots:get(i)
        local carry = M.carryOf(pot)
        if carry then
            M.carryTick(carry, now, ledger, place, notes.fireUntil, notes.placeWithoutFire, not M.isWrapped(pot))
            pot:setItemHeat(M.itemHeat(carry.c))
        elseif pot:getItemHeat() ~= 1 then
            pot:setItemHeat(1)
        end
    end
end

-- A wrap in a hot stove, oven, barbecue or fire burns: the Sheet and Twine are gone (M.burnWrap). On a stove, oven or
-- barbecue it sets the kitchen alight, as vanilla's burnt food does; in an open fire (a fireplace, the Stone Hearth's
-- firebox, a campfire) it burns away in the fire, as burnt food there never spreads (ENGINE_NOTES). TP Core's minute
-- look at the heat round each player (Station.onHeatNear, within Station.HEAT_NEAR) finds the hot containers.
local function isOpenFire(heatSource)
    return instanceof(heatSource, "IsoFireplace") or heatSource:getName() == "Campfire"
end

Station.onHeatNear(M.BURN_HEAT, function(container, _, heatSource)
    local wrapped = container:getAllEvalRecurse(M.isWrapped)
    for i = 0, wrapped:size() - 1 do
        local item = wrapped:get(i)
        log("TPD", "a wrap burnt on %s at %d,%d,%d", item:getFullType(), heatSource:getX(), heatSource:getY(), heatSource:getZ())
        M.burnWrap(item)
        if not isOpenFire(heatSource) and heatSource:getSquare() then
            IsoFireManager.StartFire(getCell(), heatSource:getSquare(), true, 500000)
        end
    end
end)

Events.EveryOneMinute.Add(function()
    local now, ledger, players = getGameTime():getWorldAgeHours(), M.getLedger(), Station.players()
    for i = 0, players:size() - 1 do tickWrappedPots(players:get(i), now, ledger) end
end)

Weather.onReading(function(now, climate)
    M.recordWeather(M.getLedger(), M.getHistory(), now, climate:getTemperature())
    M.BUTTER_KEEPER.recordWeather(now, climate:getTemperature())
end)

-- A vanilla pour carries the heat: what goes in mixes, by volume, with what was there, so a pot just off the stove
-- poured into a Wrapped Pot keeps its heat. Read at the start, written when the pour ends or is stopped.
local function itemOf(fluidObject)
    local owner = fluidObject and fluidObject:getOwner()
    return instanceof(owner, "InventoryItem") and owner or nil
end

-- Through TP Core's Pour, the one wrap of vanilla's transfer action (the core's own FluidAgeing rides on it too).
Pour.before("start", function(self)
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
end)

local function finishPour(self)
    local pour, target = self.tpdPour, itemOf(self.target)
    self.tpdPour = nil
    if not pour or not target then return end
    -- Only warm milk, or milk onto a carry, needs one: cold onto nothing stays vanilla.
    local carry = target:getModData()[M.CARRY_KEY]
    if not pour.warm and not carry then return end
    local moved = M.mlIn(target:getFluidContainer()) - pour.hadMl
    M.pouredInto(target, carry, pour.hadMl, pour.hadC, moved, pour.fromC, pour.scalded, getGameTime():getWorldAgeHours())
end

Pour.before("stop", finishPour)
Pour.after("complete", finishPour)

tracker.start()
