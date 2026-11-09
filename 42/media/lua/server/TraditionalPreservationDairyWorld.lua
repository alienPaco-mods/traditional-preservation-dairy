-- Traditional Preservation (Dairy) B42: keeps track of every Yoghurt Incubator, records the weather and its hourly
-- history, brings each pot's milk up to the hour and layers the sprite for its stage. The pot's state sits in
-- movableData, so it goes with the pot when it is picked up full and carried to the fire.
if isClient() then return end

TraditionalPreservationDairyWorld = TraditionalPreservationDairyWorld or {}
local M = TraditionalPreservationDairy
local World = TraditionalPreservationDairyWorld
local Station = require "TraditionalPreservationDairy/Core/Station"
local Weather = require "TraditionalPreservationDairy/Core/Weather"
local Tiles = require "TraditionalPreservationDairy/Tiles"

-- A pot too cold for a starter looks like a cooling one: the lid is still on.
local STAGE_SPRITES = { Cooling = "Cooling", TooCold = "Cooling", Incubating = "Incubating", Ready = "Ready" }

local function squareKey(object)
    local square = object:getSquare()
    return square and (square:getX() .. "," .. square:getY() .. "," .. square:getZ())
end

-- The pot's state, made on first use.
function World.incubatorState(station)
    return M.stateOf(Station.movableData(station), M.INCUBATOR_KEY)
end

-- Brings the pot up to now. The time since the last look counts at the place it was seen in then: a fire
-- is taken to burn on while the area is away. A pot that has been moved counts its time where it stands now.
function World.updateIncubator(station, now)
    local state = World.incubatorState(station)
    local place, here = M.placeOf(station), squareKey(station)
    local before = M.stage(state)
    M.catchUp(state, now, state.at == here and state.place or place, M.getHistory(), M.getLedger())
    state.place, state.at = place, here
    local after = M.stage(state)
    if after ~= before then
        print(string.format("[TPD] incubator %s -> %s: %.1f L at %.1f C, %s", before, after, (state.ml or 0) / 1000, state.tempC or 0, place))
    end
    return state
end

local function refresh(station, entry)
    local state = World.updateIncubator(station, getGameTime():getWorldAgeHours())
    local overlay = M.INCUBATOR_OVERLAYS[STAGE_SPRITES[M.stage(state)]]
    local names = {}
    if overlay then table.insert(names, M.spriteName(overlay + entry.faceIndex)) end
    Station.showSprites(station, entry, tostring(overlay), names)
end

-- Only this mod's stations: which way it faces.
local function newEntry(station)
    if not M.isIncubator(station) then return nil end
    local index = M.spriteIndex(station:getSprite():getName())
    return { faceIndex = index % M.FACE_COUNT }
end

local tracker = Station.tracker({ sprites = Tiles.STATIONS, entry = newEntry, refresh = refresh })

World.track = tracker.track

-- Redraws a tracked station now, without waiting for the next tick, e.g. after a pour.
function World.refresh(station)
    local entry = tracker.track(station)
    if entry then refresh(station, entry) end
end

-- Every tracked station that is loaded, for the dev console.
function World.stations()
    local list = {}
    for object in pairs(tracker.tracked) do
        if Station.isLoaded(object) then table.insert(list, object) end
    end
    return list
end

Weather.record(function(now, climate)
    M.record(M.getLedger(), M.getHistory(), now, climate:getTemperature())
end)

tracker.start()
