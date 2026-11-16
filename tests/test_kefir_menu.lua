-- Checks the Yogurt Incubator's kefir menu and its jobs (TPKefirIncubator) with stand-ins for the engine: grains by
-- group, any milk at a heat the grains survive, straining with a Strainer or a cloth, grains back out. Run from the mod
-- folder: luajit tests/test_kefir_menu.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") or name:find("^TimedActions/TP") then return realRequire(name) end
end

-- Engine stand-ins: the player carries ui.carried; tools are found by full type among them.
local ui = H.installMenus()
ISInventoryTransferAction = {}
local playerSquare = { getX = function() return 5 end, getY = function() return 4 end, getZ = function() return 0 end,
    isOutside = function() return false end, isInARoom = function() return true end }
local given = {}
local inventory = {
    getFirstTypeRecurse = function(_, fullType)
        for _, item in ipairs(ui.carried) do
            if item:getFullType() == fullType then return item end
        end
    end,
    containsRecursive = function(_, item)
        for _, carried in ipairs(ui.carried) do
            if carried == item then return true end
        end
        return false
    end,
    AddItem = function(_, fullType)
        local modData, name = {}, fullType
        local item = { fullType = fullType, getModData = function() return modData end, getFullType = function() return fullType end,
            getOutermostContainer = function() return nil end, getWorldItem = function() return nil end,
            getName = function() return name end, setName = function(_, text) name = text end, setCustomName = function() end }
        table.insert(given, item)
        return item
    end,
}
local playerObj = { getSquare = function() return playerSquare end, isOutside = function() return false end,
    getInventory = function() return inventory end, isTimedActionInstant = function() return false end }
function getSpecificPlayer() return playerObj end
function getClimateManager()
    return { getTemperature = function() return 18 end, getHumidity = function() return 50 end }
end
local ground = {}
function getCell()
    return {
        getGridSquare = function(_, x, y)
            local objects = ground[x .. "," .. y]
            return objects and { getObjects = function() return H.list(objects) end }
        end,
    }
end

require "TraditionalPreservationDairy"
local M = TraditionalPreservationDairy
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
function isClient() return false end
MapObjects = { OnLoadWithSprite = function() end }
dofile("42/media/lua/server/TraditionalPreservationDairyWorld.lua")
dofile("42/media/lua/client/TraditionalPreservationDairyUI.lua")
local handlers = H.handlers.OnFillWorldObjectContextMenu
local onFillMenu = handlers[#handlers]

local function named(menu, key, ...)
    return menu:getOptionFromName(select("#", ...) > 0 and getText(key, ...) or getText(key))
end

local function tile(x, y, class, sprite, modData)
    local square = { getX = function() return x end, getY = function() return y end, getZ = function() return 0 end,
        isOutside = function() return false end, isInARoom = function() return true end }
    local station = {
        class = class,
        getSprite = function() return { getName = function() return sprite end } end,
        getModData = function() return modData end,
        getSquare = function() return square end,
        isOutside = function() return false end,
        isLit = function() return false end,
        getFuelAmount = function() return 0 end,
        getName = function() return nil end,
        isBlockAllTheSquare = function() return false end,
        isCanPassThrough = function() return true end,
        clearAttachedAnimSprite = function() end,
        addAttachedAnimSpriteByName = function() end,
    }
    ground[x .. "," .. y] = { station }
    return station
end

local function incubator(batch)
    return tile(5, 5, "IsoThumpable", M.spriteName(M.INCUBATOR_SPRITE), { movableData = { [M.INCUBATOR_KEY] = batch or {} } })
end

local function open(station)
    local context = H.menu()
    onFillMenu(0, context, { station }, false)
    return context.options[1].subOption
end

-- Carried things
local function thing(fullType, modData)
    modData = modData or {}
    local item = { getFullType = function() return fullType end, getDisplayName = function() return fullType end,
        isFavorite = function() return false end, getModData = function() return modData end,
        getFluidContainer = function() return nil end, getOutermostContainer = function() return nil end,
        getWorldItem = function() return nil end }
    local name = fullType
    item.getName = function() return name end
    item.setName = function(_, text) name = text end
    item.setCustomName = function() end
    item.getContainer = function()
        return { Remove = function()
            for i, carried in ipairs(ui.carried) do
                if carried == item then table.remove(ui.carried, i) break end
            end
        end }
    end
    return item
end
local function grainItems(n, state)
    local list = {}
    for i = 1, n do list[i] = thing(M.GRAIN, { [M.GRAIN_KEY] = M.newGrain(state, 100) }) end
    return list
end
local function driedItems(n)
    local list = {}
    for i = 1, n do list[i] = thing(M.DRIED_GRAIN) end
    return list
end
local function carry(...)
    ui.carried = {}
    for _, list in ipairs({ ... }) do
        for _, item in ipairs(list) do table.insert(ui.carried, item) end
    end
end
local function milk(name, fluid, litres, celsius)
    return H.vessel(name, fluid, litres, 2, { getFullType = function() return "Base.Bucket" end,
        getItemHeat = function() return M.itemHeat(celsius) end })
end

local ADD = "ContextMenu_TraditionalPreservationDairy_AddKefirGrains"

-- An empty pot offers grains, by group
local live, dried, dead = grainItems(12, M.GRAIN_LIVE), driedItems(3), grainItems(2, M.GRAIN_DEAD)
carry(live, dried, dead)
local pot = incubator()
local add = named(open(pot), ADD)
check("an empty pot offers Add Kefir Grains", add ~= nil and add.isDisabled == nil and add.subOption ~= nil)
local rows = add.subOption.options
check("a row per group carried: live, dried, then dead", #rows == 3
    and rows[1].name == getText("ContextMenu_TraditionalPreservationDairy_GrainsLive", "12")
    and rows[2].name == getText("ContextMenu_TraditionalPreservationDairy_GrainsDried", "3")
    and rows[3].name == getText("ContextMenu_TraditionalPreservationDairy_GrainsDead", "2"))
check("dead grains are in red with the reason", rows[3].notAvailable == true and rows[3].subOption == nil)
check("no milk yet: One and All only", #rows[1].subOption.options == 2)
local all = rows[1].subOption.options[2]
all.onSelect(all.target, unpack(all.args))
local queued = ui.queued[#ui.queued]
check("All queues one job with every live grain", queued.Type == "TPKefirIncubator" and queued.mode == "grains" and #queued.items == 12)
queued:complete()
local batch = M.batchOf(pot)
check("done, the pot is a kefir pot holding 12 live grains, and they have left the inventory",
    batch.culture == M.KEFIR_CULTURE and M.grainCount(batch) == 12 and #ui.carried == 5)

-- A kefir pot's menu: grains, milk, take out
local sub = open(pot)
check("the status says grains wait for milk", sub.options[1].name == getText("IGUI_TraditionalPreservationDairy_StageKefirGrains", "12"))
check("no yogurt entries on a kefir pot", named(sub, "ContextMenu_TraditionalPreservationDairy_AddStarter") == nil
    and named(sub, "ContextMenu_TraditionalPreservationDairy_PourScalded") == nil)
check("grains can come back out before the milk", named(sub, "ContextMenu_TraditionalPreservationDairy_TakeGrains") ~= nil)
carry({ milk("Raw Bucket", "CowMilk", 0.4, 20), milk("Hot Bucket", "SheepMilk", 1, 70), milk("Warm Bucket", "CowMilk", 0.4, 40) })
local pour = named(open(pot), "ContextMenu_TraditionalPreservationDairy_PourMilk")
local milks = pour.subOption.options
check("raw cold milk is offered", milks[1].notAvailable == nil and milks[1].toolTip == nil)
check("milk at 70 C is red: it would kill the grains", milks[2].notAvailable == true
    and milks[2].toolTip.description:find("70", 1, true) ~= nil)
check("milk at 40 C goes in, with a warning", milks[3].notAvailable == nil and milks[3].toolTip.description:find("40", 1, true) ~= nil)
milks[1].onSelect(milks[1].target, unpack(milks[1].args))
queued = ui.queued[#ui.queued]
check("choosing milk queues its pour", queued.mode == "milk" and queued.item == ui.carried[1])

-- Pouring: the container stands in with the fluid calls the job makes
local bucket = ui.carried[1]
local fluidContainer = bucket:getFluidContainer()
function fluidContainer:removeFluid() end
fluidContainer.getSpecificFluidAmount = function() return 0 end
queued:complete()
check("the milk is in and fermenting, full speed for 400 ml", M.stage(batch) == "Fermenting" and batch.ml == 400 and M.kefirRatio(batch) == 1)
sub = open(pot)
check("fermenting, the status shows litres and how far along", sub.options[1].name:find("0.4", 1, true) ~= nil)
check("grains taken out only before the milk", named(sub, "ContextMenu_TraditionalPreservationDairy_TakeGrains") == nil)

-- Enough for the milk
carry(grainItems(30, M.GRAIN_LIVE))
batch.ml = 1000
local liveRow = named(open(pot), ADD).subOption.options[1]
check("with milk in, Enough tops the grains up to full speed: 25 for a litre less the 12 in",
    liveRow.subOption.options[2].name == getText("ContextMenu_TraditionalPreservationDairy_GrainsEnough", "13"))
batch.ml = 400

-- The cauldron
local hearth = tile(6, 5, "IsoFireplace", StoneHearth.cauldronSprite("Empty", 0), { [Fire.KEY] = { [Cauldron.ID] = { ml = 2000, fluid = "CowMilk", tempC = 90 } } })
pour = named(open(pot), "ContextMenu_TraditionalPreservationDairy_PourMilk")
check("steaming milk in the cauldron is red for the grains", pour.subOption.options[1].notAvailable == true)
ground["6,5"] = nil
hearth = nil

-- Ready: strain
batch.readyHour, batch.progress = 100, 1
batch.kefirAge = FluidAgeing.newFluidAge(FluidAgeing.fluidKind(M.KEFIR_PROCESS), M.getLedger(), 100, "Sheltered")
local jar = H.vessel("Jar", nil, 0, 1, { getFullType = function() return "Base.EmptyJar" end, class = "InventoryItem",
    getOutermostContainer = function() return nil end, getWorldItem = function() return nil end, getItemHeat = function() return 1 end })
carry({ jar })
local strain = named(open(pot), "ContextMenu_TraditionalPreservationDairy_StrainKefir")
check("ready kefir with no strainer or cloth: greyed, saying what it needs", strain.isDisabled == true
    and strain.toolTip.description == getText("IGUI_TraditionalPreservationDairy_NoStrainer"))
local sheet = thing("Base.RippedSheets")
carry({ jar, sheet })
strain = named(open(pot), "ContextMenu_TraditionalPreservationDairy_StrainKefir")
check("with Ripped Sheets it strains, at twice the time", strain.isDisabled == nil
    and strain.toolTip.description:find("twice", 1, true) ~= nil)
local clothTime = TPKefirIncubator:new(playerObj, pot, "strain", jar).maxTime
carry({ jar, sheet, thing(M.STRAINER) })
local strainerTime = TPKefirIncubator:new(playerObj, pot, "strain", jar).maxTime
check("a Strainer takes half as long, and is the one used", near(clothTime, strainerTime * M.CLOTH_STRAIN_TIMES)
    and select(2, M.strainTool(inventory)) == false)

-- The strain itself
local added = {}
local jarContainer = jar:getFluidContainer()
function jarContainer:addFluid(name, litres) added[name] = (added[name] or 0) + litres end
-- Fluids by name, so FluidAgeing sees the jar's kefir.
function jarContainer:getSpecificFluidAmount(name) return added[name] or 0 end
function jarContainer:isEmpty() return next(added) == nil end
Fluid.Get = function(name) return name end
local option = named(open(pot), "ContextMenu_TraditionalPreservationDairy_StrainKefir").subOption.options[1]
option.onSelect(option.target, unpack(option.args))
given = {}
ui.queued[#ui.queued]:complete()
check("a litre jar takes the 400 ml as cow's kefir", near(added.CowKefir, 0.4))
check("with the kefir's age from the pot", jar:getModData()[FluidAgeing.KEY] ~= nil)
check("and the 12 grains come out live, with their records", #given == 12 and given[1].fullType == M.GRAIN
    and given[1]:getModData()[M.GRAIN_KEY].grainState == M.GRAIN_LIVE)
check("the pot is empty again, no culture", M.stage(M.batchOf(pot)) == "Empty" and M.batchOf(pot).culture == nil)

-- A yogurt pot refuses grains
carry(grainItems(3, M.GRAIN_LIVE))
add = named(open(incubator({ ml = 2000, fluid = "CowMilk", tempC = 60 })), ADD)
check("a pot of yogurt milk greys Add Kefir Grains with the reason", add.isDisabled == true
    and add.toolTip.description == getText("IGUI_TraditionalPreservationDairy_YoghurtMilk"))

check("no text would make the game's formatter warn" .. (H.textWarnings[1] and " (" .. table.concat(H.textWarnings, "; ") .. ")" or ""),
    #H.textWarnings == 0)

H.done()
