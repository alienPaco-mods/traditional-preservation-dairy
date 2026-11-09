-- Traditional Preservation (Dairy) B42: building the Hearth. The built tile is swapped for a vanilla fireplace, as
-- the Barrel Oven's is (BuildRecipeCode.barrelOven.OnCreate), so vanilla gives it fuel, lighting, burn time, room
-- heat and a firebox to cook in. Every hearth tile carries the fireplace's properties, so it loads as one too.
require "TraditionalPreservationDairy"

local M = TraditionalPreservationDairy

function M.OnCreateHearth(params)
    local thumpable = params.thumpable
    local sprite = thumpable and thumpable:getSprite()
    local name = sprite and sprite:getName()
    if not M.hearthFace(name) then return nil end
    local square = thumpable:getSquare()
    local fire = IsoFireplace.new(getCell(), square, getSprite(name))
    square:AddTileObject(fire)
    if thumpable:getSquare() ~= nil then
        thumpable:removeFromWorld()
        thumpable:removeFromSquare()
        thumpable:setSquare(nil)
    end
    return { replaceObject = true, object = fire }
end

-- The Yoghurt Incubator and the Starter Culture Crock are built within HEARTH_RADIUS tiles of a Hearth: the build
-- cursor stays red anywhere else.
function M.OnIsValidNearHearth(params)
    return params.square ~= nil and #M.hearthsNear(params.square) > 0
end
