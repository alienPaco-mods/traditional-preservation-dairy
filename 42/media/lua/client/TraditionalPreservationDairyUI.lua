-- Traditional Preservation (Dairy) B42: the Yoghurt Incubator and the Starter Culture Crock are worked from their
-- right-click menus. The pot: pour milk steaming from a Hearth's copper in, add a starter, pour the milk back out, and
-- collect the set yoghurt into jars. The crock: load wheat and warm milk from the copper, feed it fresh milk, collect
-- the starters. The status line at the top says what the station is doing, and its hover says more. Both also have
-- info windows (TP Core's InfoWindow), opened from their menus or by clicking them. A Jar of Yoghurt's own menu spoons
-- it into cups. The Hearth's own menu and Hearth Info are TP Core's (HearthUI); Dairy adds its milk notes there.
require "TimedActions/ISYoghurtIncubator"
require "TimedActions/ISStarterCrock"
require "TimedActions/ISFillYoghurtCup"
local UI = require "TraditionalPreservationCore/UI"
local Station = require "TraditionalPreservationCore/Station"
local Hearth = require "TraditionalPreservationCore/Hearth"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local HearthUI = require "TraditionalPreservationCore/HearthUI"

local M = TraditionalPreservationDairy
local say = UI.say
local STATION_ICON = "media/textures/Item_YoghurtIncubator.png"
local CROCK_ICON = "media/textures/Item_StarterCultureCrock.png"
local HEARTH_ICON = "media/textures/Item_TPHearth.png"
local WHEAT_ICON = "Item_WheatGrains"
local MILK_ICON = "Item_Milk"
local YOGHURT_ICON = "Item_Yoghurt"
local JAR_ICON = "Item_ClayJar_Fired"
local PotWindow, CrockWindow -- the info windows, below the menus

local PLACE_TEXT = {
    Open = "IGUI_TraditionalPreservationDairy_Open",
    Sheltered = "IGUI_TraditionalPreservationDairy_Roof",
    Basement = "IGUI_TraditionalPreservationDairy_Basement",
    [M.HEARTH] = "IGUI_TraditionalPreservationDairy_Hearth",
    [M.EMBERS] = "IGUI_TraditionalPreservationDairy_Embers",
}

local REFUSALS = {
    HasStarter = "IGUI_TraditionalPreservationDairy_HasStarter",
    TooCold = "IGUI_TraditionalPreservationDairy_TooCold",
    Incubating = "IGUI_TraditionalPreservationDairy_Wrapped",
    Ready = "IGUI_TraditionalPreservationDairy_Wrapped",
    Full = "IGUI_TraditionalPreservationDairy_PotFull",
    NotSteamed = "IGUI_TraditionalPreservationDairy_NotSteamed",
}

local function now()
    return getGameTime():getWorldAgeHours()
end

local function litresText(ml)
    return string.format("%.1f", ml / 1000)
end

local function degrees(celsius)
    return string.format("%.0f", celsius)
end

local function tooltipFor(option, text)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = text
    option.toolTip = tooltip
end

local function disableWith(option, text)
    option.isDisabled = true
    tooltipFor(option, text)
end

-- Every item on the player or in containers in reach that passes test.
local function findItems(playerObj, test)
    local found = {}
    local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
    for i = 0, containers:size() - 1 do
        local items = containers:get(i):getItems()
        for j = 0, items:size() - 1 do
            local item = items:get(j)
            if not item:isFavorite() and test(item) then table.insert(found, item) end
        end
    end
    return found
end

local function onAction(playerObj, station, items, mode)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, item in ipairs(items) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
        ISTimedActionQueue.add(ISYoghurtIncubator:new(playerObj, station, item, mode))
    end
end

-- Whole hours, or "under an hour".
local function hoursText(hours)
    if hours <= 1 then return getText("IGUI_TraditionalPreservationDairy_UnderHour") end
    return say("IGUI_TraditionalPreservationDairy_Hours", tostring(math.ceil(hours)))
end

local function statusText(state)
    local stage = M.stage(state)
    if stage == "Empty" then
        return getText(state.starter and "IGUI_TraditionalPreservationDairy_EmptyStarter" or "IGUI_TraditionalPreservationDairy_Empty")
    end
    return say("IGUI_TraditionalPreservationDairy_Stage" .. stage, litresText(state.ml), degrees(state.tempC))
end

-- The hover: where the pot stands, what comes next and when, if the place's temperature holds.
local function detailText(station, state)
    local place = state.place or M.placeOf(station)
    local placeC = M.placeTemperature(M.getLedger(), place)
    local lines = { say(PLACE_TEXT[place], degrees(placeC)) }
    local stage = M.stage(state)
    if stage == "Empty" then
        table.insert(lines, getText("IGUI_TraditionalPreservationDairy_HelpEmpty"))
    elseif stage == "TooCold" then
        table.insert(lines, getText("IGUI_TraditionalPreservationDairy_TooCold"))
    elseif stage == "Ready" then
        table.insert(lines, say("IGUI_TraditionalPreservationDairy_Jars", tostring(math.ceil(state.ml / M.JAR_ML)), tostring(M.cupsInPot(state))))
    else
        if stage == "Cooling" then
            table.insert(lines, getText(state.starter and "IGUI_TraditionalPreservationDairy_StarterIn" or "IGUI_TraditionalPreservationDairy_NoStarter"))
        else
            table.insert(lines, say("IGUI_TraditionalPreservationDairy_SetProgress", UI.percent(math.min(state.done / M.INCUBATE_HOURS, 1)),
                UI.percent(M.setRate(state.tempC))))
        end
        -- Next: the wrap goes on, the yoghurt sets, or the milk goes too cold for a starter.
        local hours, nextStage = M.forecast(state, placeC)
        if hours then
            table.insert(lines, say("IGUI_TraditionalPreservationDairy_Next" .. nextStage, hoursText(hours)))
        else
            table.insert(lines, getText(stage == "Incubating" and "IGUI_TraditionalPreservationDairy_NeverSets" or "IGUI_TraditionalPreservationDairy_NoChange"))
        end
    end
    return table.concat(lines, " <LINE> ")
end

-- One option per container, plus "all" when there are several. label(item) names each one.
local function addItemMenu(menu, option, playerObj, station, items, mode, label)
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    if #items > 1 then
        sub:addOption(say("ContextMenu_TraditionalPreservationDairy_All", tostring(#items)), playerObj, onAction, station, items, mode)
    end
    for _, item in ipairs(items) do
        local entry = sub:addOption(label(item), playerObj, onAction, station, { item }, mode)
        entry.iconTexture = item:getTex()
    end
end

-- The copper's state, brought up to now when the World runs here.
local copperOf = Hearth.copperOf

-- The first hearth near the station whose copper passes test, else nil and the nearest one's copper.
local function hearthFor(station, test)
    local nearest
    for _, hearth in ipairs(M.hearthsNear(station:getSquare())) do
        local copper = copperOf(hearth)
        if test(copper) then return hearth, copper end
        nearest = nearest or copper
    end
    return nil, nearest
end

-- Why the nearest copper won't do: none near, no milk in it, or too cold.
local function hearthRefusal(copper, notHotKey)
    if not copper then return getText("IGUI_TraditionalPreservationDairy_NoHearth") end
    if not M.MILKS[copper.fluid] then return getText("IGUI_TraditionalPreservationDairy_CopperNoMilk") end
    return say(notHotKey, degrees(copper.tempC))
end

local function onHearthPour(playerObj, station, hearth)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    ISTimedActionQueue.add(ISYoghurtIncubator:new(playerObj, station, nil, "hearth", hearth))
end

local function addHearthPourMenu(menu, playerObj, station, state)
    local label = getText("ContextMenu_TraditionalPreservationDairy_PourFromHearth")
    local room, reason = M.milkRoom(state, 1)
    local hearth, copper
    if room > 0 then hearth, copper = hearthFor(station, M.copperHot) end
    if hearth then label = say("ContextMenu_TraditionalPreservationDairy_MilkItem", label, litresText(copper.ml), degrees(copper.tempC)) end
    local option = menu:addOption(label, playerObj, onHearthPour, station, hearth)
    option.iconTexture = getTexture(HEARTH_ICON)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    if not hearth then return disableWith(option, hearthRefusal(copper, "IGUI_TraditionalPreservationDairy_CopperNotHot")) end
end

-- Every container of plain milk, wherever it was carried from. Milk that wasn't drawn steaming from a copper, or
-- the other animal's milk, shows in red with the reason. Only a Wrapped Yoghurt Pot keeps the milk hot on the way.
local function addCarriedPourMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourSteamed"))
    option.iconTexture = getTexture(MILK_ICON)
    local room, reason = M.milkRoom(state, 1)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    local items = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoMilkItem")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_SteamedHelp"))
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local container = item:getFluidContainer()
        local fluid, ml = M.milkIn(container), M.mlIn(container)
        local heat = M.carriedC(item, now(), playerObj)
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", item:getDisplayName(), litresText(ml),
            degrees(heat)), playerObj, onAction, station, { item }, "carried")
        entry.iconTexture = item:getTex()
        local refusal = M.carriedRefusal(M.carryOf(item), ml)
        local refusalText = refusal and getText(REFUSALS[refusal])
        if not refusal and select(2, M.milkRoom(state, 1, fluid)) == "Mixed" then
            refusalText = say("IGUI_TraditionalPreservationDairy_PotMixed", M.fluidName(state.fluid))
        end
        if refusalText then
            entry.notAvailable = true
            tooltipFor(entry, refusalText)
        end
    end
end

local function addStarterMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_AddStarter"))
    option.iconTexture = getTexture(YOGHURT_ICON)
    local ok, reason = M.canAddStarter(state)
    if not ok then return disableWith(option, getText(REFUSALS[reason])) end
    local starters = findItems(playerObj, function(item) return M.STARTERS[item:getFullType()] ~= nil and not item:isRotten() end)
    if #starters == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoStarterItem")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_StarterHelp"))
    -- One is all a batch takes, so there's no "all".
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    local seen = {}
    for _, item in ipairs(starters) do
        if not seen[item:getFullType()] then
            seen[item:getFullType()] = true
            local entry = sub:addOption(item:getDisplayName(), playerObj, onAction, station, { item }, "starter")
            entry.iconTexture = item:getTex()
        end
    end
end

local function addPourOutMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourOut"))
    option.iconTexture = getTexture(MILK_ICON)
    local empties = findItems(playerObj, M.isEmptyContainer)
    if #empties == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoContainer")) end
    addItemMenu(menu, option, playerObj, station, empties, "pourOut", function(item)
        return say("ContextMenu_TraditionalPreservationDairy_Holds", item:getDisplayName(), litresText(item:getFluidContainer():getCapacity() * 1000))
    end)
end

local function addCollectMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_Collect"))
    option.iconTexture = getTexture(JAR_ICON)
    local jars = findItems(playerObj, function(item) return M.JARS[item:getFullType()] == true and M.isEmptyContainer(item) end)
    if #jars == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoJar")) end
    local most = math.min(#jars, math.ceil(state.ml / M.JAR_ML))
    local picked = {}
    for index = 1, most do picked[index] = jars[index] end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    sub:addOption(getText("ContextMenu_TraditionalPreservationDairy_OneJar"), playerObj, onAction, station, { jars[1] }, "collect")
    if most > 1 then
        sub:addOption(say("ContextMenu_TraditionalPreservationDairy_All", tostring(most)), playerObj, onAction, station, picked, "collect")
    end
end

-- Empty Yoghurt Containers filled straight from the pot, a quarter of a jar each, as old as the batch.
local function addCupMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_FillPotCups"))
    option.iconTexture = getTexture(YOGHURT_ICON)
    local empties = findItems(playerObj, function(item) return item:getFullType() == M.EMPTY_CUP end)
    if #empties == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoEmptyCup")) end
    local most = math.min(#empties, M.cupsInPot(state))
    local picked = {}
    for index = 1, most do picked[index] = empties[index] end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    sub:addOption(getText("ContextMenu_TraditionalPreservationDairy_OneCup"), playerObj, onAction, station, { empties[1] }, "cup")
    if most > 1 then
        sub:addOption(say("ContextMenu_TraditionalPreservationDairy_All", tostring(most)), playerObj, onAction, station, picked, "cup")
    end
end

local function addIncubatorMenu(context, playerObj, station)
    local World = TraditionalPreservationDairyWorld
    local state = World and World.updateIncubator(station, getGameTime():getWorldAgeHours())
        or M.stateOf(station:getModData().movableData or {}, M.INCUBATOR_KEY)
    local option = context:addOption(getText("IGUI_CraftingWindow_YoghurtIncubator"))
    option.iconTexture = getTexture(STATION_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(statusText(state))
    status.isDisabled = true
    tooltipFor(status, detailText(station, state))
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PotInfo"), playerObj, PotWindow.open, station)
    info.iconTexture = getTexture(STATION_ICON)

    local stage = M.stage(state)
    if stage == "Ready" then
        addCollectMenu(menu, playerObj, station, state)
        return addCupMenu(menu, playerObj, station, state)
    end
    addHearthPourMenu(menu, playerObj, station, state)
    addCarriedPourMenu(menu, playerObj, station, state)
    if stage ~= "Incubating" then addStarterMenu(menu, playerObj, station, state) end
    if stage == "Cooling" or stage == "TooCold" then addPourOutMenu(menu, playerObj, station, state) end
end

-- Crock

local function onCrockAction(playerObj, station, mode, item, wheat, hearth)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, seed in ipairs(wheat or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, seed) end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(ISStarterCrock:new(playerObj, station, mode, item, wheat, hearth))
end

-- Containers holding at least ml of plain milk.
local function milkFor(playerObj, ml)
    return findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return M.milkIn(container) ~= nil and container:getAmount() * 1000 >= ml - 0.5
    end)
end

local LOAD_REFUSALS = {
    TooLittle = "IGUI_TraditionalPreservationDairy_CrockTooLittle",
    TooCool = "IGUI_TraditionalPreservationDairy_CrockTooCool",
    TooHot = "IGUI_TraditionalPreservationDairy_CrockTooHot",
}

local function refuseLoad(entry, ml, celsius)
    local refusal = M.crockLoadRefusal(ml, celsius)
    if not refusal then return end
    entry.notAvailable = true
    tooltipFor(entry, say(LOAD_REFUSALS[refusal], degrees(celsius)))
end

-- Wheat and half a litre of milk at 35 to 45 C: one entry for the nearest Hearth within 2 tiles, one per milk
-- container carried. Each shows its litres and heat, in red with the reason when it can't load.
local function addLoadMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_LoadCrock"))
    option.iconTexture = getTexture(WHEAT_ICON)
    local wheat = findItems(playerObj, function(item) return item:getFullType() == M.WHEAT end)
    if #wheat < M.CROCK_WHEAT then
        return disableWith(option, say("IGUI_TraditionalPreservationDairy_NeedWheat", tostring(M.CROCK_WHEAT), tostring(#wheat)))
    end
    local hearth, copper = hearthFor(station, ISStarterCrock.copperReady)
    local milks = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    if not copper and #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_CrockNoWarmMilk")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_LoadHelp"))
    local picked = {}
    for index = 1, M.CROCK_WHEAT do picked[index] = wheat[index] end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    if copper then
        local label = getText("ContextMenu_TraditionalPreservationDairy_LoadFromHearth")
        if M.MILKS[copper.fluid] then label = say("ContextMenu_TraditionalPreservationDairy_MilkItem", label, litresText(copper.ml), degrees(copper.tempC)) end
        local entry = sub:addOption(label, playerObj, onCrockAction, station, "load", nil, picked, hearth)
        entry.iconTexture = getTexture(MILK_ICON)
        if not hearth then
            if M.MILKS[copper.fluid] then
                refuseLoad(entry, copper.ml or 0, copper.tempC or 0)
            else
                entry.notAvailable = true
                tooltipFor(entry, getText("IGUI_TraditionalPreservationDairy_CopperNoMilk"))
            end
        end
    end
    for _, item in ipairs(milks) do
        local ml = M.mlIn(item:getFluidContainer())
        local heat = M.carriedC(item, now(), playerObj)
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", item:getDisplayName(), litresText(ml),
            degrees(heat)), playerObj, onCrockAction, station, "load", item, picked)
        entry.iconTexture = item:getTex()
        refuseLoad(entry, ml, heat)
    end
end

-- Fresh milk of any warmth, one entry per container.
local function addFeedMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_FeedCrock"))
    option.iconTexture = getTexture(MILK_ICON)
    local milks = milkFor(playerObj, M.CROCK_FEED_ML)
    if #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_CrockNoMilk")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(milks) do
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_FluidItem", item:getDisplayName(),
            litresText(item:getFluidContainer():getAmount() * 1000)), playerObj, onCrockAction, station, "feed", item)
        entry.iconTexture = item:getTex()
    end
end

local function crockDetail(station, state)
    local ledger = M.getLedger()
    local place = state.place or M.placeOf(station)
    local lines = { say(PLACE_TEXT[place], degrees(M.placeTemperature(ledger, place))) }
    local stage = M.crockStage(state)
    if stage == "Cultivating" or stage == "Developing" then
        local status = M.crockStatus(state, ledger, place)
        table.insert(lines, say("IGUI_TraditionalPreservationDairy_CrockProgress", UI.percent(status.progress), UI.percent(status.rate)))
        table.insert(lines, status.hoursLeft and say("IGUI_TraditionalPreservationDairy_Next" .. (stage == "Cultivating" and "Waiting" or "Starters"),
            hoursText(status.hoursLeft)) or getText("IGUI_TraditionalPreservationDairy_CrockStalled"))
    else
        table.insert(lines, getText("IGUI_TraditionalPreservationDairy_CrockHelp" .. stage))
    end
    return table.concat(lines, " <LINE> ")
end

local function addCrockMenu(context, playerObj, station)
    local World = TraditionalPreservationDairyWorld
    local state = World and World.updateCrock(station) or M.stateOf(station:getModData().movableData or {}, M.CROCK_KEY)
    local option = context:addOption(getText("IGUI_CraftingWindow_StarterCultureCrock"))
    option.iconTexture = getTexture(CROCK_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local stage = M.crockStage(state)
    local status = menu:addOption(getText("IGUI_TraditionalPreservationDairy_Crock" .. stage))
    status.isDisabled = true
    tooltipFor(status, crockDetail(station, state))
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_CrockInfo"), playerObj, CrockWindow.open, station)
    info.iconTexture = getTexture(CROCK_ICON)

    if stage == "Empty" then
        addLoadMenu(menu, playerObj, station)
    elseif stage == "Waiting" then
        addFeedMenu(menu, playerObj, station)
    elseif stage == "Ready" then
        local collect = menu:addOption(say("ContextMenu_TraditionalPreservationDairy_CollectStarters", tostring(M.CROCK_STARTERS)),
            playerObj, onCrockAction, station, "collect")
        collect.iconTexture = getTexture(YOGHURT_ICON)
    end
end

-- Pot Info: the status line and its hover laid out as a table, kept up to date while open.
local BAR_COLOURS = { contents = { 0.6, 0.57, 0.46 }, set = { 0.55, 0.6, 0.25 }, culture = { 0.7, 0.62, 0.35 } }
local STARTER_TEXT = { Yoghurt = "IGUI_TraditionalPreservationDairy_InfoStarterYoghurt", Starter = "IGUI_TraditionalPreservationDairy_InfoStarterCulture" }

PotWindow = InfoWindow:derive("TraditionalPreservationDairyPotWindow")

function PotWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = getText("IGUI_CraftingWindow_YoghurtIncubator")
    return o
end

function PotWindow.open(playerObj, station)
    InfoWindow.open(PotWindow, playerObj, station)
end

-- The forecast runs the pot ahead step by step, so it is worked out twice a second, not every frame.
function PotWindow:refresh()
    local World, station = TraditionalPreservationDairyWorld, self.station
    local state = World and World.updateIncubator(station, now()) or M.stateOf(station:getModData().movableData or {}, M.INCUBATOR_KEY)
    local place = state.place or M.placeOf(station)
    local placeC = M.placeTemperature(M.getLedger(), place)
    local hours, nextStage = M.forecast(state, placeC)
    self.info = { state = state, stage = M.stage(state), place = place, placeC = placeC, hours = hours, nextStage = nextStage }
end

-- Days since it set, and how long it stays fresh: the jar's own shelf life, which the age carries into.
local function ageText(state)
    local days = M.ageDays(state, now())
    local script = ScriptManager.instance:getItem(M.YOGHURT_JAR)
    local fresh = script and script:getDaysFresh() or 0
    local age = days < 1 and getText("IGUI_TraditionalPreservationDairy_InfoToday") or say("IGUI_TraditionalPreservationDairy_InfoDays", tostring(math.floor(days)))
    if days >= fresh then return say("IGUI_TraditionalPreservationDairy_InfoStale", age) end
    return say("IGUI_TraditionalPreservationDairy_InfoAge", age, tostring(math.ceil(fresh - days)))
end

function PotWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.info then return end
    local info = self.info
    local state, stage = info.state, info.stage
    local ml = state.ml or 0
    local y = self:top()

    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoStage", getText("IGUI_TraditionalPreservationDairy_InfoStage" .. stage))
    y = self:bar(y, "IGUI_TraditionalPreservationDairy_InfoContents", ml / M.CAPACITY_ML, BAR_COLOURS.contents,
        say("IGUI_TraditionalPreservationDairy_InfoLitres", litresText(ml), litresText(M.CAPACITY_ML)))
    local milkC = (ml > 0 and stage ~= "Ready") and say("IGUI_TraditionalPreservationDairy_InfoDegrees", degrees(state.tempC)) or "-"
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoMilk", milkC)
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoSetting",
        say("IGUI_TraditionalPreservationDairy_InfoSettingValue", degrees(M.SET_C), degrees(M.STARTER_MIN_C)))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoPlace", say(PLACE_TEXT[info.place], degrees(info.placeC)))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoStarter", getText(STARTER_TEXT[state.starter] or "IGUI_TraditionalPreservationDairy_InfoStarterNone"))
    if stage == "Incubating" or stage == "Ready" then
        local share = math.min((state.done or 0) / M.INCUBATE_HOURS, 1)
        y = self:bar(y, "IGUI_TraditionalPreservationDairy_InfoSet", share, BAR_COLOURS.set, UI.percent(share))
    end
    if stage == "Incubating" then
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoSpeed", UI.percent(M.setRate(state.tempC)))
    end
    if stage == "Cooling" or stage == "Incubating" then
        local nextText = info.hours and say("IGUI_TraditionalPreservationDairy_Next" .. info.nextStage, hoursText(info.hours))
            or getText(stage == "Incubating" and "IGUI_TraditionalPreservationDairy_InfoNever" or "IGUI_TraditionalPreservationDairy_InfoHolds")
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoNext", nextText)
    end
    if stage == "Ready" then
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoAgeLabel", ageText(state))
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoJars", tostring(math.ceil(ml / M.JAR_ML)))
    end

    local notes = {}
    if stage == "Empty" then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_HelpEmpty"))
    elseif stage == "TooCold" then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_TooCold"))
    elseif stage == "Cooling" and not state.starter then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_NoStarter"))
    elseif stage == "Incubating" and not info.hours then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_NeverSets"))
    end
    if (stage == "Cooling" or stage == "Incubating") and info.hours and info.place ~= "Basement" then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_InfoAssumes"))
    end
    self:drawNotes(y, notes)
end

-- Hearth Info (TP Core's) says what the copper's milk is for.
HearthUI.addNotes(function(info, notes)
    local ml = info.copper.ml or 0
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_HearthHelpEmpty"))
    elseif not M.MILKS[info.copper.fluid] then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_HearthHelpWater"))
    end
end)

-- Crock Info: the stage, the place and its heat, and how far the culture has got, laid out like Pot Info.
CrockWindow = PotWindow:derive("TraditionalPreservationDairyCrockWindow")

function CrockWindow:new(playerObj, crock)
    local o = InfoWindow.new(self, playerObj, crock)
    o.title = getText("IGUI_CraftingWindow_StarterCultureCrock")
    return o
end

function CrockWindow.open(playerObj, crock)
    InfoWindow.open(CrockWindow, playerObj, crock)
end

function CrockWindow:refresh()
    local World, station = TraditionalPreservationDairyWorld, self.station
    local state = World and World.updateCrock(station) or M.stateOf(station:getModData().movableData or {}, M.CROCK_KEY)
    local place = state.place or M.placeOf(station)
    self.info = { state = state, stage = M.crockStage(state), status = M.crockStatus(state, M.getLedger(), place) }
end

function CrockWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.info then return end
    local info = self.info
    local stage, status = info.stage, info.status
    local working = stage == "Cultivating" or stage == "Developing"
    local y = self:top()

    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoStage", getText("IGUI_TraditionalPreservationDairy_Crock" .. stage))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoPlace", say(PLACE_TEXT[status.place], degrees(status.temperature)))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoCultureHeat", getText("IGUI_TraditionalPreservationDairy_InfoCultureHeatValue"))
    if working then
        y = self:bar(y, "IGUI_TraditionalPreservationDairy_InfoProgress", status.progress, BAR_COLOURS.culture, UI.percent(status.progress))
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoCultureSpeed", UI.percent(status.rate))
        local nextText = status.hoursLeft and say("IGUI_TraditionalPreservationDairy_Next" .. (stage == "Cultivating" and "Waiting" or "Starters"),
            hoursText(status.hoursLeft)) or getText("IGUI_TraditionalPreservationDairy_InfoStopped")
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoNext", nextText)
    elseif stage == "Ready" then
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoStarters", tostring(M.CROCK_STARTERS))
    end

    local notes = {}
    if not working then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_CrockHelp" .. stage))
    elseif not status.hoursLeft then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_CrockStalled"))
    elseif status.place ~= "Basement" then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_InfoAssumes"))
    end
    self:drawNotes(y, notes)
end

-- Not while paused, aiming or out of reach: vanilla's own checks for a click.
local function canClick(object, playerObj)
    return playerObj and not playerObj:isAiming()
        and not (UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0)
        and InfoWindow.inReach(playerObj, object)
end

-- Clicking a pot opens Incubator Info, and clicking a crock Crock Info, as clicking a door opens it (a Hearth's click
-- is TP Core's). The click handler is in vanilla's server folder, which loads after this one, so it is wrapped once
-- the game has started.
local function wrapClickHandler()
    if not ISObjectClickHandler or ISObjectClickHandler.tpdPotClick then return end
    local vanillaClickObject = ISObjectClickHandler.doClickSpecificObject
    ISObjectClickHandler.tpdPotClick = true
    function ISObjectClickHandler.doClickSpecificObject(object, playerNum, playerObj)
        local window = object and (M.isIncubator(object) and PotWindow or M.isCrock(object) and CrockWindow)
        if window and canClick(object, playerObj) then
            if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.track(object) end
            window.open(playerObj, object)
            return true
        end
        return vanillaClickObject(object, playerNum, playerObj)
    end
end

Events.OnGameStart.Add(wrapClickHandler)

local function onFillContextMenu(playerNum, context, worldobjects)
    local playerObj = getSpecificPlayer(playerNum)
    for _, object in ipairs(worldobjects) do
        local incubator, crock = M.isIncubator(object), M.isCrock(object)
        if incubator or crock then
            -- A station built or placed this session isn't tracked until its area reloads, so its menu starts it.
            if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.track(object) end
            if crock then return addCrockMenu(context, playerObj, object) end
            return addIncubatorMenu(context, playerObj, object)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Jar of Yoghurt: one cup, or every cup the jar and the empty containers allow.
local function onFillCups(playerObj, jar, cups)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, jar)
    for _, cup in ipairs(cups) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, cup)
        ISTimedActionQueue.add(ISFillYoghurtCup:new(playerObj, jar, cup))
    end
end

local function onFillInventoryMenu(playerNum, context, items)
    local jar
    for _, entry in ipairs(items) do
        local item = instanceof(entry, "InventoryItem") and entry or entry.items[1]
        if item and item:getFullType() == M.YOGHURT_JAR then jar = item break end
    end
    if not jar then return end
    local playerObj = getSpecificPlayer(playerNum)
    local left = M.cupsLeft(jar:getModData())
    local empties = findItems(playerObj, function(item) return item:getFullType() == M.EMPTY_CUP end)
    local one = context:addOption(getText("ContextMenu_TraditionalPreservationDairy_FillCup"), playerObj, onFillCups, jar, { empties[1] })
    one.iconTexture = getTexture(YOGHURT_ICON)
    if #empties == 0 then return disableWith(one, getText("IGUI_TraditionalPreservationDairy_NoEmptyCup")) end
    local most = math.min(left, #empties)
    if most > 1 then
        local picked = {}
        for index = 1, most do picked[index] = empties[index] end
        local all = context:addOption(say("ContextMenu_TraditionalPreservationDairy_FillAllCups", tostring(most)), playerObj, onFillCups, jar, picked)
        all.iconTexture = getTexture(YOGHURT_ICON)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryMenu)
