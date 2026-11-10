-- Checks the incubator's and the crock's right-click menus with stand-ins for the engine. Run from the mod folder:
-- luajit tests/test_menu.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The mod's own modules, TP Core's and both's actions load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") or name:find("^TimedActions/TP") then return realRequire(name) end
end

-- Engine stand-ins
local ui = H.installMenus()
function getClimateManager()
    return { getTemperature = function() return 18 end, getHumidity = function() return 50 end }
end
-- The ground: objects by "x,y", all on level 0.
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
local Hearth = require "TraditionalPreservationCore/Hearth"
dofile("42/media/lua/client/TraditionalPreservationDairyUI.lua")
-- The core's Hearth menu listens too; Dairy's is the last one added.
local handlers = H.handlers.OnFillWorldObjectContextMenu
local onFillMenu = handlers[#handlers]

local function named(menu, key)
    return menu:getOptionFromName(getText(key))
end

local function tile(x, y, class, sprite, modData)
    local square = { getX = function() return x end, getY = function() return y end, getZ = function() return 0 end,
        isOutside = function() return false end }
    local object = {
        class = class,
        getSprite = function() return { getName = function() return sprite end } end,
        getModData = function() return modData end,
        getSquare = function() return square end,
        isOutside = function() return false end,
        isLit = function() return false end,
        getFuelAmount = function() return 0 end,
        getName = function() return nil end,
    }
    ground[x .. "," .. y] = { object }
    return object
end

local function incubator(x, batch)
    return tile(x, 5, "IsoThumpable", M.spriteName(M.INCUBATOR_SPRITE), { movableData = { [M.INCUBATOR_KEY] = batch or {} } })
end

local function crock(x, state)
    return tile(x, 5, "IsoThumpable", M.spriteName(M.CROCK_SPRITE), { movableData = { [M.CROCK_KEY] = state or {} } })
end

-- A Hearth one tile from the pot at 5,5.
local function hearth(copper)
    return tile(6, 5, "IsoFireplace", Hearth.sprite("Empty", 0), { [Hearth.KEY] = copper })
end

-- Opens the menu on the stations and returns each one's submenu, then the whole menu.
local function open(...)
    local context = H.menu()
    onFillMenu(0, context, { ... }, false)
    local subs = {}
    for index, option in ipairs(context.options) do subs[index] = option.subOption end
    return subs, context
end

local POUR = "ContextMenu_TraditionalPreservationDairy_PourFromHearth"

-- The controller's probe
local pot = incubator(5)
local context = H.menu()
onFillMenu(0, context, { pot }, true)
check("the controller's probe is told there is a menu, and nothing is built", ui.probes == 1 and #context.options == 0)

-- An empty pot with no Hearth near
local subs
subs, context = open(pot)
local sub = subs[1]
check("one pot: one menu, under its plain name", #context.options == 1
    and context.options[1].name == getText("IGUI_CraftingWindow_YoghurtIncubator"))
check("the first line is the pot's status, greyed, with a hover", sub.options[1].name == getText("IGUI_TraditionalPreservationDairy_Empty")
    and sub.options[1].isDisabled == true and sub.options[1].toolTip.description ~= nil)
check("Incubator Info is on it", named(sub, "ContextMenu_TraditionalPreservationDairy_PotInfo") ~= nil)
local pour = named(sub, POUR)
check("pouring from a Hearth is greyed when none is near", pour.isDisabled == true
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationDairy_NoHearth"))
local carried = named(sub, "ContextMenu_TraditionalPreservationDairy_PourSteamed")
check("and carried milk when none is carried", carried.isDisabled == true
    and carried.toolTip.description == getText("IGUI_TraditionalPreservationDairy_NoMilkItem"))
check("with none carried, it shows an empty bucket", carried.iconTexture == "Item_MetalBucket" and carried.itemForTexture == nil)
check("an empty pot has nothing to pour out or collect", named(sub, "ContextMenu_TraditionalPreservationDairy_PourOut") == nil
    and named(sub, "ContextMenu_TraditionalPreservationDairy_Collect") == nil)

-- The copper
hearth({ ml = 4000, fluid = "Water", tempC = 95 })
pour = named(open(pot)[1], POUR)
check("a copper of water is refused", pour.isDisabled == true
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationDairy_CopperNoMilk"))
hearth({ ml = 4000, fluid = "CowMilk", tempC = 50 })
pour = named(open(pot)[1], POUR)
check("and milk that isn't steaming, with its heat", pour.isDisabled == true and pour.toolTip.description:find("50", 1, true) ~= nil)
local steaming = hearth({ ml = 4000, fluid = "CowMilk", tempC = 90 })
sub = open(pot)[1]
pour = sub.options[3]
check("steaming milk is offered, with its litres and heat", pour.isDisabled == nil and pour.onSelect ~= nil
    and pour.name:find("4.0", 1, true) ~= nil and pour.name:find("90", 1, true) ~= nil)
check("pouring from the Hearth shows its copper, full", pour.iconTexture == "media/textures/Item_TPCopperFull.png")
local character = { isTimedActionInstant = function() return false end }
pour.onSelect(character, unpack(pour.args))
check("choosing it walks over and queues the pour from that Hearth", ui.walks == 1 and #ui.queued == 1
    and ui.queued[1].Type == "TPYoghurtIncubator" and ui.queued[1].mode == "hearth" and ui.queued[1].hearth == steaming
    and ui.queued[1].station == pot)

-- The other animal's milk
hearth({ ml = 4000, fluid = "CowMilk", tempC = 90 })
pour = open(incubator(5, { ml = 1000, fluid = "SheepMilk", tempC = 80 }))[1].options[3]
check("cow's milk is offered to a pot of sheep's: milks mix", pour.isDisabled == nil and pour.onSelect ~= nil)

-- Carried milk and a starter already in the pot
local function steamedMilk(name, celsius)
    local modData = { [M.CARRY_KEY] = { ml = 2000, c = celsius, hour = 100, steamed = true } }
    return H.vessel(name, "CowMilk", 2, 5, { getFullType = function() return "Base.Bucket" end,
        getModData = function() return modData end, getItemHeat = function() return Hearth.itemHeat(celsius) end })
end
ui.carried = { steamedMilk("Hot Bucket", 80), steamedMilk("Cold Bucket", 25) }
carried = named(open(incubator(5, { starter = "Yoghurt" }))[1], "ContextMenu_TraditionalPreservationDairy_PourSteamed")
local potEntries = carried.subOption.options
check("with the starter in, hot carried milk is offered and cold milk is red with its heat", potEntries[1].notAvailable == nil
    and potEntries[2].notAvailable == true and potEntries[2].toolTip.description:find("25", 1, true) ~= nil)
carried = named(open(incubator(5))[1], "ContextMenu_TraditionalPreservationDairy_PourSteamed")
check("with no starter cold milk still goes in", carried.subOption.options[2].notAvailable == nil)
check("the option and each row show the real container, drawn with its milk", carried.itemForTexture == ui.carried[1]
    and carried.iconTexture == nil and carried.subOption.options[2].itemForTexture == ui.carried[2])
ui.carried = {}

-- A full pot, and one that has set
pour = named(open(incubator(5, { ml = M.CAPACITY_ML, fluid = "CowMilk", tempC = 80 }))[1], POUR)
check("a full pot takes no more", pour.isDisabled == true
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationDairy_PotFull"))
sub = open(incubator(5, { ml = 2000, fluid = "CowMilk", tempC = 30, starter = "Yoghurt", done = M.INCUBATE_HOURS, readyHour = 90 }))[1]
check("set yoghurt is collected, not poured", named(sub, "ContextMenu_TraditionalPreservationDairy_Collect") ~= nil
    and named(sub, "ContextMenu_TraditionalPreservationDairy_FillPotCups") ~= nil and named(sub, POUR) == nil)

-- Several stations under one click
local cooling = incubator(4, { ml = 2000, fluid = "CowMilk", tempC = 60 })
local starter = crock(5)
subs, context = open(cooling, starter, cooling)
check("each station under the click gets one menu", #context.options == 2)
check("named with its status, so they can be told apart", context.options[1].name:find("(", 1, true) ~= nil
    and context.options[1].name:find("2.0", 1, true) ~= nil and context.options[2].name:find("(", 1, true) ~= nil)
check("the crock's menu opens with its status and Crock Info", subs[2].options[1].isDisabled == true and #subs[2].options >= 2)

check("no text would make the game's formatter warn" .. (H.textWarnings[1] and " (" .. table.concat(H.textWarnings, "; ") .. ")" or ""),
    #H.textWarnings == 0)

H.done()
