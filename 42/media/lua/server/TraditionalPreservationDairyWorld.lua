-- Traditional Preservation (Dairy) B42: keeps track of every Yoghurt Incubator, Starter Culture Crock and Hearth,
-- records the weather and its hourly history, brings each pot's milk and each crock's culture up to the hour and
-- layers the sprite for its stage. A station's state sits in movableData, so it goes with it when it is picked up
-- full and carried to the fire. The Hearth is a vanilla fireplace: its copper heats while vanilla's fire burns, and
-- its look is its own sprite swapped among the hearth tiles (vanilla's flames are attached sprites: never clear them).
if isClient() then return end

TraditionalPreservationDairyWorld = TraditionalPreservationDairyWorld or {}
local M = TraditionalPreservationDairy
local World = TraditionalPreservationDairyWorld
local Station = require "TraditionalPreservationDairy/Core/Station"
local Weather = require "TraditionalPreservationDairy/Core/Weather"
local Tiles = require "TraditionalPreservationDairy/Tiles"

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
        print(string.format("[TPD] incubator %s -> %s: %.1f L at %.1f C, %s", before, after, (state.ml or 0) / 1000, state.tempC or 0, place))
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
    if after ~= before then print(string.format("[TPD] crock %s -> %s, %s", before, after, place)) end
    return state
end

-- The copper's state, in the fireplace's own modData: a hearth can't be picked up while it holds anything.
function World.hearthState(fire)
    return M.stateOf(fire:getModData(), M.HEARTH_KEY)
end

-- Brings the copper up to now: heated while the fire burnt (as far as its fuel went), cooled to the room since.
-- Then notes how long the fire will burn on, and shows the copper empty, full or steaming.
function World.updateHearth(fire, now)
    local copper = World.hearthState(fire)
    local before = M.copperLook(copper)
    M.advanceCopper(copper, now, M.placeTemperature(M.getLedger(), Weather.placeOf(fire)))
    copper.fireUntil = fire:isLit() and now + fire:getFuelAmount() / 60 or nil
    local look = M.copperLook(copper)
    local face = M.hearthFace(fire:getSprite():getName())
    local name = face and M.hearthSprite(look, face)
    if name and fire:getSprite():getName() ~= name then fire:setSprite(getSprite(name)) end
    if look ~= before then
        print(string.format("[TPD] hearth copper %s -> %s: %.1f L %s at %.1f C", before, look, (copper.ml or 0) / 1000,
            tostring(copper.fluid), copper.tempC or 0))
    end
    return copper
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
    if entry.hearth then
        World.updateHearth(station, getGameTime():getWorldAgeHours())
        return
    elseif entry.crock then
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
    if M.isHearth(station) then return { hearth = true } end
    local crock = M.isCrock(station)
    if not crock and not M.isIncubator(station) then return nil end
    local index = M.spriteIndex(station:getSprite():getName())
    return { faceIndex = index % M.FACE_COUNT, crock = crock }
end

local sprites = {}
for _, name in ipairs(Tiles.STATIONS) do table.insert(sprites, name) end
for _, name in ipairs(M.HEARTH_SPRITES) do table.insert(sprites, name) end
local tracker = Station.tracker({ sprites = sprites, entry = newEntry, refresh = refresh })

World.track = tracker.track

-- Redraws a tracked station now, without waiting for the next tick, e.g. after a pour.
function World.refresh(station)
    local entry = tracker.track(station)
    if entry then refresh(station, entry) end
end

-- Every tracked station of the kind that is loaded, for the dev console: incubators, crocks if crock is true,
-- hearths if it is "hearth".
function World.stations(crock)
    local list = {}
    for object, entry in pairs(tracker.tracked) do
        local kind = entry.hearth and "hearth" or entry.crock == true
        if Station.isLoaded(object) and kind == (crock or false) then table.insert(list, object) end
    end
    return list
end

-- A pot or hearth just built or put down isn't known to the map loader, and its bare base must never show: the squares
-- round each player are looked over twice a second, so a new station gets its stage sprite at once.
local NEAR = 3
local SCAN_TICKS = 30
local scanTicks = 0

local function players()
    if isServer() then return getOnlinePlayers() end
    local list = ArrayList.new()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then list:add(player) end
    end
    return list
end

local function scanNear(player)
    local cell, px, py, z = getCell(), math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for x = px - NEAR, px + NEAR do
        for y = py - NEAR, py + NEAR do
            local square = cell:getGridSquare(x, y, z)
            local objects = square and square:getObjects()
            for i = 0, objects and objects:size() - 1 or -1 do
                local object = objects:get(i)
                if not tracker.entry(object) and (M.isIncubator(object) or M.isCrock(object) or M.isHearth(object)) then
                    World.refresh(object)
                end
            end
        end
    end
end

Events.OnTick.Add(function()
    scanTicks = scanTicks + 1
    if scanTicks < SCAN_TICKS then return end
    scanTicks = 0
    local list = players()
    for i = 0, list:size() - 1 do scanNear(list:get(i)) end
end)

-- A Wrapped Yoghurt Pot a player carries cools where the player is; set down, it keeps that place (M.carryTick).
local function tickWrappedPots(player, now, ledger)
    local pots = player:getInventory():getAllTypeRecurse(M.WRAPPED_POT)
    if pots:isEmpty() then return end
    local place, fire = M.placeOf(player)
    local notes = {}
    M.noteFire(notes, player, fire, now)
    -- Vanilla's item heat (the red row) follows the record; with no milk record it goes back to room.
    for i = 0, pots:size() - 1 do
        local pot = pots:get(i)
        local carry = M.carryOf(pot)
        if carry then
            M.carryTick(carry, now, ledger, place, notes.fireUntil, notes.under)
            pot:setItemHeat(M.itemHeat(carry.c))
        elseif pot:getItemHeat() ~= 1 then
            pot:setItemHeat(1)
        end
    end
end

Events.EveryOneMinute.Add(function()
    local now, ledger, list = getGameTime():getWorldAgeHours(), M.getLedger(), players()
    for i = 0, list:size() - 1 do tickWrappedPots(list:get(i), now, ledger) end
end)

Weather.record(function(now, climate)
    M.record(M.getLedger(), M.getHistory(), now, climate:getTemperature())
end)

tracker.start()
