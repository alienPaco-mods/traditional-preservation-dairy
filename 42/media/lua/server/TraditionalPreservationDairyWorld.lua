-- Traditional Preservation (Dairy) B42: keeps track of every Yoghurt Incubator, records the weather and tells each
-- running batch where its station stands. TEMPLATE: layer attached sprites here to show the station's state
-- (Station.showSprites; Yeast's shelf shows one jar per culture).
if isClient() then return end

TraditionalPreservationDairyWorld = TraditionalPreservationDairyWorld or {}
local Station = require "TraditionalPreservationDairy/Core/Station"
local Weather = require "TraditionalPreservationDairy/Core/Weather"
local Tiles = require "TraditionalPreservationDairy/Tiles"

local function refresh(station, entry)
    local logic = station:getComponent(ComponentType.CraftLogic)
    if not logic then return end
    local uiLogic = Station.uiLogic(station, entry, logic)
    if not uiLogic then return end
    local place = Weather.placeOf(station)
    for craftData in pairs(uiLogic:getItemsInProgress()) do
        craftData:getModData().place = place
    end
end

local tracker = Station.tracker({ sprites = Tiles.STATIONS, refresh = refresh })

TraditionalPreservationDairyWorld.track = tracker.track

Weather.record(function(now, climate)
    local M = TraditionalPreservationDairy
    M.advance(M.getLedger(), now, climate:getTemperature())
end)

tracker.start()
