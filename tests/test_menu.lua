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
ISInventoryTransferAction = {}
-- Carried milk with a heat record reads it where the player stands: indoors, by the pot.
local playerSquare = { getX = function() return 5 end, getY = function() return 4 end, getZ = function() return 0 end,
    isOutside = function() return false end, isInARoom = function() return true end }
local playerObj = { getSquare = function() return playerSquare end, isOutside = function() return false end }
function getSpecificPlayer() return playerObj end
function getClimateManager()
    return { isUpdated = function() return true end, getTemperature = function() return 18 end, getHumidity = function() return 50 end }
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
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
-- The World runs here, as in single player: the menus bring each station up to now through it.
function isClient() return false end
MapObjects = { OnLoadWithSprite = function() end }
dofile("42/media/lua/server/TraditionalPreservationDairyWorld.lua")
dofile("42/media/lua/client/TraditionalPreservationDairyUI.lua")
-- The core's Stone Hearth menu listens too; Dairy's is the last one added.
local handlers = H.handlers.OnFillWorldObjectContextMenu
local onFillMenu = handlers[#handlers]

local function named(menu, key)
    return menu:getOptionFromName(getText(key))
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
        -- What the World's redraw asks of a built station.
        isBlockAllTheSquare = function() return false end,
        isCanPassThrough = function() return true end,
        clearAttachedAnimSprite = function() end,
        addAttachedAnimSpriteByName = function() end,
    }
    ground[x .. "," .. y] = { station }
    return station
end

local function incubator(x, batch)
    return tile(x, 5, "IsoThumpable", M.spriteName(M.INCUBATOR_SPRITE), { movableData = { [M.INCUBATOR_KEY] = batch or {} } })
end

local function crock(x, crockModData)
    return tile(x, 5, "IsoThumpable", M.spriteName(M.CROCK_SPRITE), { movableData = { [M.CROCK_KEY] = crockModData or {} } })
end

-- A Stone Hearth one tile from the pot at 5,5.
local function withCauldron(cauldron)
    return tile(6, 5, "IsoFireplace", StoneHearth.cauldronSprite("Empty", 0), { [Fire.KEY] = { [Cauldron.ID] = cauldron } })
end

-- Opens the menu on the stations and returns each one's submenu, then the whole menu.
local function open(...)
    local context = H.menu()
    onFillMenu(0, context, { ... }, false)
    local subs = {}
    for index, option in ipairs(context.options) do subs[index] = option.subOption end
    return subs, context
end

local POUR = "ContextMenu_TraditionalPreservationDairy_PourFromCauldron"

-- The controller's probe
local pot = incubator(5)
local context = H.menu()
onFillMenu(0, context, { pot }, true)
check("the controller's probe is told there is a menu, and nothing is built", ui.probes == 1 and #context.options == 0)

-- An empty pot with no Stone Hearth near
local subs
subs, context = open(pot)
local sub = subs[1]
check("one pot: one menu, under its plain name", #context.options == 1
    and context.options[1].name == getText("IGUI_CraftingWindow_YoghurtIncubator"))
check("the first line is the pot's status, greyed, with a hover", sub.options[1].name == getText("IGUI_TraditionalPreservationDairy_Empty")
    and sub.options[1].isDisabled == true and sub.options[1].toolTip.description ~= nil)
check("Incubator Info is on it", named(sub, "ContextMenu_TraditionalPreservationDairy_PotInfo") ~= nil)
local pour = named(sub, POUR)
check("pouring from a Stone Hearth is greyed when none is near", pour.isDisabled == true
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationDairy_NoCauldron"))
local carried = named(sub, "ContextMenu_TraditionalPreservationDairy_PourScalded")
check("and carried milk when none is carried", carried.isDisabled == true
    and carried.toolTip.description == getText("IGUI_TraditionalPreservationDairy_NoMilkItem"))
check("with none carried, it shows an empty bucket", carried.iconTexture == "Item_MetalBucket" and carried.itemForTexture == nil)
check("an empty pot has nothing to pour out or collect", named(sub, "ContextMenu_TraditionalPreservationDairy_PourOut") == nil
    and named(sub, "ContextMenu_TraditionalPreservationDairy_Collect") == nil)

-- The cauldron
withCauldron({ ml = 4000, fluid = "Water", tempC = 95 })
pour = named(open(pot)[1], POUR)
check("a cauldron of water is refused", pour.isDisabled == true
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationDairy_CauldronNoMilk"))
withCauldron({ ml = 4000, fluid = "CowMilk", tempC = 50 })
pour = named(open(pot)[1], POUR)
check("and milk that isn't steaming, with its heat", pour.isDisabled == true and pour.toolTip.description:find("50", 1, true) ~= nil)
local unheld = withCauldron({ ml = 4000, fluid = "CowMilk", tempC = 90, held = 0.1 })
pour = named(open(pot)[1], POUR)
check("steaming but not held yet, it says how many minutes to go", pour.isDisabled == true
    and pour.toolTip.description:find("14 more minutes", 1, true) ~= nil)
local steaming = withCauldron({ ml = 4000, fluid = "CowMilk", tempC = 90, held = 0.5 })
sub = open(pot)[1]
pour = sub.options[3]
check("steaming milk is offered, with its litres and heat", pour.isDisabled == nil and pour.onSelect ~= nil
    and pour.name:find("4.0", 1, true) ~= nil and pour.name:find("90", 1, true) ~= nil)
check("pouring from the Stone Hearth shows its cauldron, full", pour.iconTexture == "media/textures/Item_TPCauldronFull.png")
local character = { isTimedActionInstant = function() return false end }
pour.onSelect(character, unpack(pour.args))
check("choosing it walks over and queues the pour from that Stone Hearth", ui.walks == 1 and #ui.queued == 1
    and ui.queued[1].Type == "TPYoghurtIncubator" and ui.queued[1].mode == "fire" and ui.queued[1].fire == steaming
    and ui.queued[1].station == pot)

-- The other animal's milk
withCauldron({ ml = 4000, fluid = "CowMilk", tempC = 90, held = 1 })
pour = open(incubator(5, { ml = 1000, fluid = "SheepMilk", tempC = 80 }))[1].options[3]
check("cow's milk is offered to a pot of sheep's: milks mix", pour.isDisabled == nil and pour.onSelect ~= nil)

-- Carried milk and a starter already in the pot
local function scaldedMilk(name, celsius)
    local modData = { [M.CARRY_KEY] = { ml = 2000, c = celsius, hour = 100, scalded = true } }
    return H.vessel(name, "CowMilk", 2, 5, { getFullType = function() return "Base.Bucket" end,
        getModData = function() return modData end, getItemHeat = function() return CauldronFluid.itemHeat(celsius) end })
end
ui.carried = { scaldedMilk("Hot Bucket", 80), scaldedMilk("Cold Bucket", 25) }
carried = named(open(incubator(5, { starter = "Yogurt" }))[1], "ContextMenu_TraditionalPreservationDairy_PourScalded")
local potEntries = carried.subOption.options
check("with the starter in, hot carried milk is offered and cold milk is red with its heat", potEntries[1].notAvailable == nil
    and potEntries[2].notAvailable == true and potEntries[2].toolTip.description:find("25", 1, true) ~= nil)
carried = named(open(incubator(5))[1], "ContextMenu_TraditionalPreservationDairy_PourScalded")
check("with no starter cold milk still goes in", carried.subOption.options[2].notAvailable == nil)
check("the option and each row show the real container, drawn with its milk", carried.itemForTexture == ui.carried[1]
    and carried.iconTexture == nil and carried.subOption.options[2].itemForTexture == ui.carried[2])
ui.carried[2]:getModData()[M.WRAP_KEY] = { name = "Bucket", rain = 0.5 }
carried = named(open(incubator(5))[1], "ContextMenu_TraditionalPreservationDairy_PourScalded")
check("a wrapped bucket is named so in the menu", carried.subOption.options[2].name:find(
    getText("IGUI_TraditionalPreservationDairy_WrappedName", "Cold Bucket"), 1, true) == 1
    and carried.subOption.options[1].name:find("Hot Bucket", 1, true) == 1)
ui.carried = {}

-- A full pot, and one that has set
pour = named(open(incubator(5, { ml = M.CAPACITY_ML, fluid = "CowMilk", tempC = 80 }))[1], POUR)
check("a full pot takes no more", pour.isDisabled == true
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationDairy_PotFull"))
sub = open(incubator(5, { ml = 2000, fluid = "CowMilk", tempC = 30, starter = "Yogurt", workHours = M.INCUBATE_HOURS, readyHour = 90 }))[1]
check("set yogurt is collected, not poured", named(sub, "ContextMenu_TraditionalPreservationDairy_Collect") ~= nil
    and named(sub, "ContextMenu_TraditionalPreservationDairy_FillPotCups") ~= nil and named(sub, POUR) == nil)

-- Several stations under one click
local cooling = incubator(4, { ml = 2000, fluid = "CowMilk", tempC = 60 })
local starter = crock(5)
subs, context = open(cooling, starter, cooling)
check("each station under the click gets one menu", #context.options == 2)
check("named with its status, so they can be told apart", context.options[1].name:find("(", 1, true) ~= nil
    and context.options[1].name:find("2.0", 1, true) ~= nil and context.options[2].name:find("(", 1, true) ~= nil)
check("the crock's menu opens with its status and Crock Info", subs[2].options[1].isDisabled == true and #subs[2].options >= 2)

-- A Jar of Yogurt as a starter: a whole portion left, not gone off
local function jarOf(name, portions, rotten)
    local modData = { tpdFood = true, customInventoryIcon = "icon" }
    return { getFullType = function() return M.YOGHURT_JAR end, getDisplayName = function() return name end,
        isFavorite = function() return false end, isRotten = function() return rotten end, getModData = function() return modData end,
        getHungChange = function() return M.PORTION.hunger * portions end, getFluidContainer = function() return nil end }
end
ui.carried = { jarOf("Low Jar", 0.5), jarOf("Bad Jar", 3, true), jarOf("Good Jar", 2) }
local addStarter = named(open(incubator(5))[1], "ContextMenu_TraditionalPreservationDairy_AddStarter")
local starters = addStarter.subOption.options
check("a jar with a whole portion is offered as a starter, a low or rotten one isn't", #starters == 1
    and starters[1].name == "Good Jar" and starters[1].itemForTexture == ui.carried[3])
check("its hover says it takes one portion", starters[1].toolTip.description == getText("IGUI_TraditionalPreservationDairy_JarStarter"))
ui.carried = { jarOf("Low Jar", 0.5) }
addStarter = named(open(incubator(5))[1], "ContextMenu_TraditionalPreservationDairy_AddStarter")
check("with only a nearly empty jar, Add Starter is greyed", addStarter.isDisabled == true
    and addStarter.toolTip.description == getText("IGUI_TraditionalPreservationDairy_NoStarterItem"))
ui.carried = {}

-- An empty crock: soured milk alone (a clabber)
local CLABBER = "ContextMenu_TraditionalPreservationDairy_ClabberCrock"
local clabber = named(open(crock(5))[1], CLABBER)
check("with no soured milk carried, Load Soured Milk is greyed and says why", clabber.isDisabled == true
    and clabber.toolTip.description == getText("IGUI_TraditionalPreservationDairy_ClabberNoMilk"))
local function jug(name, fluid, litres)
    return H.vessel(name, fluid, litres, 2, { getFullType = function() return "Base.WaterBottle" end })
end
ui.carried = { jug("Sour Jug", "SourSheepMilk", 1), jug("Rotten Jug", "RottenCowMilk", 1), jug("Small Jug", "SourCowMilk", 0.3),
    jug("Fresh Jug", "CowMilk", 1) }
clabber = named(open(crock(5))[1], CLABBER)
local rows = clabber.subOption.options
check("soured and rotten milk are listed, fresh milk isn't", #rows == 3 and clabber.itemForTexture == ui.carried[1])
check("soured milk is offered, whatever its heat", rows[1].notAvailable == nil and rows[1].name:find("1.0", 1, true) ~= nil)
check("rotten milk is red: pour it out", rows[2].notAvailable == true
    and rows[2].toolTip.description == getText("IGUI_TraditionalPreservationDairy_ClabberRotten"))
check("too little soured milk is red", rows[3].notAvailable == true
    and rows[3].toolTip.description == getText("IGUI_TraditionalPreservationDairy_CrockTooLittle"))
ui.queued = {}
rows[1].onSelect(character, unpack(rows[1].args))
check("choosing it queues the clabber with that container", #ui.queued == 1 and ui.queued[1].Type == "TPStarterCrock"
    and ui.queued[1].mode == "clabber" and ui.queued[1].item == ui.carried[1])
local started = {}
M.startCrock(started, M.getLedger())
check("a crock already started offers no clabber", named(open(crock(5, started))[1], CLABBER) == nil)
ui.carried = {}

check("no text would make the game's formatter warn" .. (H.textWarnings[1] and " (" .. table.concat(H.textWarnings, "; ") .. ")" or ""),
    #H.textWarnings == 0)

-- Fixed 2026-11-14: a feed that empties its container forgets the milk's age (FluidAgeing's record), as a clabber does
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local function feedJug(litres)
    local container = { litres = litres }
    function container:isEmpty() return self.litres <= 0 end
    function container:getAmount() return self.litres end
    function container:removeFluid(l) self.litres = self.litres - l end
    function container:getSpecificFluidAmount(fluid) return fluid == "CowMilk" and self.litres or 0 end
    local modData = { [FluidAgeing.KEY] = { process = M.MILK_PROCESS, age = 30 } }
    return { getFluidContainer = function() return container end, getModData = function() return modData end }, modData
end
local function feed(litres)
    local station = crock(5)
    M.clabberCrock(M.crockOf(station))
    local jug, modData = feedJug(litres)
    TPStarterCrock:new(character, station, "feed", jug):complete()
    return M.crockStage(M.crockOf(station)), modData[FluidAgeing.KEY]
end
-- Fluids by name, so FluidAgeing sees the jug's milk.
local realGet = Fluid.Get
Fluid.Get = function(name) return name end
local stage, fluidAge = feed(M.CROCK_FEED_ML / 1000)
check("a feed that empties the jug starts the crock and forgets the milk's age", stage == "Developing" and fluidAge == nil)
stage, fluidAge = feed(1)
check("a jug with milk left keeps its age", stage == "Developing" and fluidAge ~= nil)
Fluid.Get = realGet

-- Put Butter in the Cauldron on the Stone Hearth's menu (TP Core's CauldronUI.addPieces)
require "TraditionalPreservationCore/FireUI"
local onHearthMenu = handlers[#handlers]
local function hearth(cauldron)
    local modData = { [Fire.KEY] = { [Cauldron.ID] = cauldron or {} } }
    local square = { getX = function() return 9 end, getY = function() return 9 end, getZ = function() return 0 end }
    return { class = "IsoFireplace", getModData = function() return modData end, getSquare = function() return square end,
        getSprite = function() return { getName = function() return StoneHearth.cauldronSprite("Empty", 0) end } end,
        getTileName = function() return "Stone Oven" end, isLit = function() return false end,
        getFuelAmount = function() return 120 end }
end
local function butterRow(aHearth)
    local context = H.menu()
    onHearthMenu(0, context, { aHearth }, false)
    local cauldronOption = context:getOptionFromName(getText("IGUI_CraftingWindow_TPStoneHearthCauldron"))
    local option = cauldronOption and cauldronOption.subOption:getOptionFromName(getText("ContextMenu_TraditionalPreservationDairy_ButterInCauldron"))
    return option and option.subOption.options[1]
end
local function butter(fullType, rotten, age)
    local modData = {}
    return { getFullType = function() return fullType end, isRotten = function() return rotten or false end,
        getFluidContainer = function() return nil end, isFavorite = function() return false end,
        hasTag = function() return false end, getModData = function() return modData end,
        getAge = function() return age or 0 end, getOffAgeMax = function() return 45 end, setOffAge = function() end,
        setOffAgeMax = function() end, getOffAge = function() return 30 end, setAge = function() end,
        getOutermostContainer = function() return nil end, getWorldItem = function() return nil end }
end
local cook = 2
Perks = Perks or { Cooking = "Cooking" }
playerObj.getPerkLevel = function() return cook end
playerObj.isTimedActionInstant = function() return false end
ui.carried = {}
check("no butter carried, no butter row", butterRow(hearth()) == nil)
local plainButter, saltedButter = butter(M.BUTTER, false, 10), butter(M.SALTED_BUTTER)
ui.carried = { plainButter, saltedButter, butter(M.BUTTER, true), butter(M.CLARIFIED_BUTTER) }
local row = butterRow(hearth())
check("butter and salted butter count together, rotten and clarified left out",
    row and row.name == getText("ContextMenu_TraditionalPreservationDairy_ButterPieces", "2") and not row.notAvailable)
local picks = row.subOption.options
check("the row opens One and All (2)", #picks == 2 and picks[2].name == getText("ContextMenu_TraditionalPreservationCore_PiecesAll", "2"))
picks[1].onSelect(picks[1].target, unpack(picks[1].args))
local queued = ui.queued[#ui.queued]
check("One puts the oldest butter", #queued.pieces == 1 and queued.pieces[1] == plainButter)
picks[2].onSelect(picks[2].target, unpack(picks[2].args))
queued = ui.queued[#ui.queued]
check("All queues the core's job with melting butter, oldest first", queued.Type == "TPPutPieces" and queued.asFluid.fluid == M.MELTING_BUTTER
    and queued.asFluid.pieceMl == M.BUTTER_PIECE_ML and queued.pieces[1] == plainButter and queued.pieces[2] == saltedButter)
row = butterRow(hearth({ ml = 500, fluid = "Water", tempC = 20 }))
check("a cauldron of water refuses it with the reason", row.notAvailable == true
    and row.toolTip.description == getText("IGUI_TraditionalPreservationDairy_ButterNoRoom"))
cook = 1
row = butterRow(hearth())
check("under Cooking 2 it is refused, saying so", row.notAvailable == true
    and row.toolTip.description == getText("IGUI_TraditionalPreservationDairy_ButterSkill"))

-- Put Butter in a Pot, on a butter's own menu (TP Core's ItemFluidUI): one row per pot or saucepan in reach
local inventoryHandlers = H.handlers.OnFillInventoryObjectContextMenu
local onButterMenu = inventoryHandlers[#inventoryHandlers]
local function potMenu(clicked)
    local context = H.menu()
    clicked.class = "InventoryItem"
    onButterMenu(0, context, { clicked })
    return context:getOptionFromName(getText("ContextMenu_TraditionalPreservationDairy_ButterInPot"))
end
local function vessel(name, fullType, fluid, litres, capacity)
    return H.vessel(name, fluid, litres, capacity, { getFullType = function() return fullType end })
end
cook = 2
local pot, saucepan = vessel("Cooking Pot", "Base.Pot", nil, 0, 1.5), vessel("Saucepan", "Base.Saucepan", nil, 0, 0.6)
local kettle = vessel("Kettle", "Base.Kettle", nil, 0, 1.5)
ui.carried = { plainButter, saltedButter, butter(M.BUTTER, true), kettle }
local option = potMenu(plainButter)
check("no pot or saucepan in reach: greyed out, saying what it needs (a kettle doesn't count)", option and option.isDisabled
    and option.toolTip.description == getText("IGUI_TraditionalPreservationDairy_ButterNoPot"))
ui.carried = { plainButter, saltedButter, pot, saucepan, vessel("Pot of Water", "Base.Pot", "Water", 1, 1.5) }
option = potMenu(saltedButter)
local rows = option.subOption.options
check("a row for each empty pot and saucepan, the pot of water left out", #rows == 2
    and rows[1].name == getText("ContextMenu_TraditionalPreservationDairy_ButterPotRow", "Cooking Pot", "2")
    and rows[1].itemForTexture == pot and not rows[1].notAvailable)
picks = rows[2].subOption.options
picks[1].onSelect(picks[1].target, unpack(picks[1].args))
queued = ui.queued[#ui.queued]
check("a vessel's One puts the oldest butter in it", queued.Type == "TPPutPieces" and queued.into.item == saucepan
    and #queued.pieces == 1 and queued.pieces[1] == plainButter)
picks[2].onSelect(picks[2].target, unpack(picks[2].args))
queued = ui.queued[#ui.queued]
check("its All queues the core's job with melting butter into that vessel", queued.Type == "TPPutPieces"
    and queued.into.item == saucepan and queued.asFluid.fluid == M.MELTING_BUTTER and queued.asFluid.pieceMl == M.BUTTER_PIECE_ML
    and #queued.pieces == 2)
ui.carried = { plainButter, vessel("Pot of Butter", "Base.Pot", M.MELTED_CLARIFIED, 1.5, 1.5), vessel("Half Pot", "Base.Pot", M.MELTING_BUTTER, 0.5, 1.5) }
rows = potMenu(plainButter).subOption.options
check("a pot of melting butter takes more; clarified butter must be strained out first", #rows == 1
    and rows[1].name == getText("ContextMenu_TraditionalPreservationDairy_ButterPotRow", "Half Pot", "1"))
check("with one carried the row puts it straight in, no One or All", rows[1].subOption == nil and rows[1].onSelect ~= nil)
ui.carried = { plainButter, vessel("Full Pot", "Base.Pot", M.MELTING_BUTTER, 1.5, 1.5) }
rows = potMenu(plainButter).subOption.options
check("a full one is refused with the reason", rows[1].notAvailable
    and rows[1].toolTip.description == getText("IGUI_TraditionalPreservationDairy_ButterPotNoRoom"))
cook = 1
ui.carried = { plainButter, pot }
rows = potMenu(plainButter).subOption.options
check("under Cooking 2 it is refused, saying so", rows[1].notAvailable
    and rows[1].toolTip.description == getText("IGUI_TraditionalPreservationDairy_ButterSkill"))
check("a clarified butter has no such row", potMenu(butter(M.CLARIFIED_BUTTER)) == nil)

-- A pot of raw butter is sealed against pouring, but can always be emptied: Empty in vanilla's (bare) Fluid menu
local function fluidMenu(clicked)
    local context = H.menu()
    local fluidOption = context:addOption(getText("ContextMenu_Fluid"))
    context:addSubMenu(fluidOption, context:getNew(context))
    clicked.class = "InventoryItem"
    for _, handler in ipairs(inventoryHandlers) do handler(0, context, { clicked }) end
    return fluidOption.subOption:getOptionFromName(getText("Fluid_Empty"))
end
local rawPot = vessel("Raw Pot", "Base.Pot", M.MELTING_BUTTER, 0.5, 1.5)
local empty = fluidMenu(rawPot)
check("a pot of melting butter gets Empty in its Fluid menu", empty ~= nil)
empty.onSelect(empty.target, unpack(empty.args))
check("choosing it queues the core's empty job for that pot", ui.queued[#ui.queued].Type == "TPEmptyFluid"
    and ui.queued[#ui.queued].item == rawPot)
check("a pot of clarified butter is left to vanilla's Empty", fluidMenu(vessel("Done Pot", "Base.Pot", M.MELTED_CLARIFIED, 0.5, 1.5)) == nil)

H.done()
