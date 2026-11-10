-- Traditional Preservation (Dairy) B42: the Yoghurt Incubator, the Starter Culture Crock and the Hearth are worked
-- from their right-click menus. The Hearth: pour a fluid into its copper, fill a container from it; vanilla's own
-- menu lights and feeds the fire. The pot: pour milk steaming from a Hearth's copper in, add a starter, pour the milk
-- back out, and collect the set yoghurt into jars. The crock: load wheat and warm milk from the copper, feed it fresh
-- milk, collect the starters. The status line at the top says what the station is doing, and its hover says more.
-- The pot and the Hearth also have info windows, opened from their menus (the pot's also by clicking it). A Jar of Yoghurt's own
-- menu spoons it into cups.
require "TimedActions/ISYoghurtIncubator"
require "TimedActions/ISStarterCrock"
require "TimedActions/ISFillYoghurtCup"
require "TimedActions/ISDairyHearth"
require "ISUI/ISCollapsableWindow"
local UI = require "TraditionalPreservationDairy/Core/UI"
local Station = require "TraditionalPreservationDairy/Core/Station"

local M = TraditionalPreservationDairy
local say = UI.say
local STATION_ICON = "media/textures/Item_YoghurtIncubator.png"
local CROCK_ICON = "media/textures/Item_StarterCultureCrock.png"
local HEARTH_ICON = "media/textures/Item_DairyHearth.png"
local WHEAT_ICON = "Item_WheatGrains"
local MILK_ICON = "Item_Milk"
local YOGHURT_ICON = "Item_Yoghurt"
local JAR_ICON = "Item_ClayJar_Fired"
local PotWindow, HearthWindow -- the info windows, below the menus

local PLACE_TEXT = {
    Open = "IGUI_TraditionalPreservationDairy_Open",
    Sheltered = "IGUI_TraditionalPreservationDairy_Roof",
    Basement = "IGUI_TraditionalPreservationDairy_Basement",
    [M.HEARTH] = "IGUI_TraditionalPreservationDairy_Hearth",
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
local function copperOf(hearth)
    local World = TraditionalPreservationDairyWorld
    if World then return World.updateHearth(hearth, now()) end
    return M.stateOf(hearth:getModData(), M.HEARTH_KEY)
end

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
        table.insert(lines, status.hoursLeft and say("IGUI_TraditionalPreservationDairy_Next" .. (stage == "Cultivating" and "Waiting" or "Ready"),
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

-- Hearth: vanilla's own menu lights and feeds the fire; this one works the copper.

local function onHearthAction(playerObj, hearth, item, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(ISDairyHearth:new(playerObj, hearth, item, mode))
end

local function copperStatus(copper)
    if (copper.ml or 0) <= 0 then return getText("IGUI_TraditionalPreservationDairy_CopperEmpty") end
    return say("IGUI_TraditionalPreservationDairy_CopperStatus", litresText(copper.ml), litresText(M.COPPER_ML),
        M.fluidName(copper.fluid), degrees(copper.tempC))
end

-- Every container with a fluid in it. A mix, or a fluid other than the copper's, shows in red with the reason.
local function addPourInMenu(menu, playerObj, hearth, copper)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourIntoCopper"))
    option.iconTexture = getTexture(MILK_ICON)
    if (copper.ml or 0) >= M.COPPER_ML then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_CopperFull")) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and not container:isEmpty()
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoFluidItem")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local container = item:getFluidContainer()
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_FluidItem", item:getDisplayName(),
            litresText(container:getAmount() * 1000)), playerObj, onHearthAction, hearth, item, "pourIn")
        entry.iconTexture = item:getTex()
        local fluid = M.fluidIn(container)
        local refusal
        if not fluid then
            refusal = getText("IGUI_TraditionalPreservationDairy_NotOneFluid")
        elseif select(2, M.copperRoom(copper, fluid, 1)) == "Mixed" then
            refusal = say("IGUI_TraditionalPreservationDairy_CopperMixed", M.fluidName(copper.fluid))
        end
        if refusal then
            entry.notAvailable = true
            tooltipFor(entry, refusal)
        end
    end
end

-- Empty containers, and those holding the copper's fluid with room left.
local function addFillMenu(menu, playerObj, hearth, copper)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_FillFromCopper"))
    option.iconTexture = getTexture(HEARTH_ICON)
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and ISDairyHearth.canFillFrom(container, copper)
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoRoomItem")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_Holds", item:getDisplayName(),
            litresText(item:getFluidContainer():getCapacity() * 1000)), playerObj, onHearthAction, hearth, item, "fillFrom")
        entry.iconTexture = item:getTex()
    end
end

-- Vanilla gives every fire its own submenu, named after the tile (ISBBQMenu): the copper's options go in there too,
-- so there is one Hearth menu, not two.
local function hearthSubMenu(context, hearth)
    local vanilla = context:getOptionFromName(hearth:getTileName())
    local menu = vanilla and vanilla.subOption and context:getSubMenu(vanilla.subOption)
    if menu then return menu end
    local option = context:addOption(getText("IGUI_CraftingWindow_DairyHearth"))
    option.iconTexture = getTexture(HEARTH_ICON)
    menu = context:getNew(context)
    context:addSubMenu(option, menu)
    return menu
end

local function addHearthMenu(context, playerObj, hearth)
    local copper = copperOf(hearth)
    local menu = hearthSubMenu(context, hearth)

    local status = menu:addOption(copperStatus(copper))
    status.isDisabled = true
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_HearthInfo"), playerObj, HearthWindow.open, hearth)
    info.iconTexture = getTexture(HEARTH_ICON)
    addPourInMenu(menu, playerObj, hearth, copper)
    if (copper.ml or 0) > 0 then addFillMenu(menu, playerObj, hearth, copper) end
end

-- Picking the Hearth up while the fire burns or the copper holds anything would lose them.
local vanillaCanPickUp = ISMoveableSpriteProps.canPickUpMoveable
local vanillaInfoFlags = ISMoveableSpriteProps.getInfoPanelFlagsPerTile

local function mustStay(object)
    if not object or not M.isHearth(object) then return false end
    return object:isLit() or (M.stateOf(object:getModData(), M.HEARTH_KEY).ml or 0) > 0
end

function ISMoveableSpriteProps:canPickUpMoveable(character, square, object)
    if mustStay(object) then return false end
    return vanillaCanPickUp(self, character, square, object)
end

-- And the pick-up cursor says why, with vanilla's own line for a full container.
function ISMoveableSpriteProps:getInfoPanelFlagsPerTile(square, object, player, mode)
    vanillaInfoFlags(self, square, object, player, mode)
    if mode == "pickup" and mustStay(object) then InfoPanelFlags.hasItems = true end
end

-- Pot Info: the status line and its hover laid out as a table, kept up to date while open. It closes when
-- the player walks off or the pot is gone. One info window at a time: opening another closes the last.
local WINDOW_WIDTH = 360
local WINDOW_REACH = 6
local WINDOW_PADDING = 10
local LABEL_WIDTH = 120
local BAR_HEIGHT = 12
local REFRESH_TICKS = 30
local BAR_COLOURS = { contents = { 0.6, 0.57, 0.46 }, set = { 0.55, 0.6, 0.25 }, fuel = { 0.75, 0.42, 0.18 }, copper = { 0.72, 0.45, 0.3 } }
local FUEL_SCALE_MIN = 12 * 60 -- a full Fuel bar: 12 hours of burning
local STARTER_TEXT = { Yoghurt = "IGUI_TraditionalPreservationDairy_InfoStarterYoghurt", Starter = "IGUI_TraditionalPreservationDairy_InfoStarterCulture" }

PotWindow = ISCollapsableWindow:derive("TraditionalPreservationDairyPotWindow")
local current -- the info window open, pot or hearth

local function inReach(playerObj, station)
    local square = station:getSquare()
    return square ~= nil and not playerObj:isDead() and square:getZ() == playerObj:getZ()
        and IsoUtils.DistanceTo(playerObj:getX(), playerObj:getY(), square:getX() + 0.5, square:getY() + 0.5) <= WINDOW_REACH
end

function PotWindow:new(playerObj, station)
    local x = getCore():getScreenWidth() / 2 - WINDOW_WIDTH / 2
    local o = ISCollapsableWindow.new(self, x, getCore():getScreenHeight() / 3, WINDOW_WIDTH, 200)
    o.playerObj, o.station = playerObj, station
    o.title = getText("IGUI_CraftingWindow_YoghurtIncubator")
    o.resizable = false
    o.ticks = REFRESH_TICKS
    return o
end

local function openInfo(class, playerObj, station)
    if current then current:close() end
    current = class:new(playerObj, station)
    current:initialise()
    current:addToUIManager()
end

function PotWindow.open(playerObj, station)
    openInfo(PotWindow, playerObj, station)
end

function PotWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if current == self then current = nil end
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

function PotWindow:update()
    ISCollapsableWindow.update(self)
    if not Station.isLoaded(self.station) or not inReach(self.playerObj, self.station) then return self:close() end
    self.ticks = self.ticks + 1
    if self.ticks >= REFRESH_TICKS then
        self.ticks = 0
        self:refresh()
    end
end

-- Words that run past the window go on to the next line.
local function wrapped(text, width)
    local lines, line = {}, ""
    for word in string.gmatch(text, "%S+") do
        local longer = line == "" and word or line .. " " .. word
        if line ~= "" and getTextManager():MeasureStringX(UIFont.Small, longer) > width then
            table.insert(lines, line)
            line = word
        else
            line = longer
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

-- Draws a label and value line at y and returns the next line's y. bar does the same with a filled bar.
function PotWindow:row(y, label, value)
    self:drawText(getText(label), WINDOW_PADDING, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawText(value, WINDOW_PADDING + LABEL_WIDTH, y, 1, 1, 1, 1, UIFont.Small)
    return y + getTextManager():getFontHeight(UIFont.Small) + 2
end

function PotWindow:bar(y, label, share, colour, value)
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local x = WINDOW_PADDING + LABEL_WIDTH
    local width = self.width - x - WINDOW_PADDING
    local top = y + (lineHeight - BAR_HEIGHT) / 2
    self:drawText(getText(label), WINDOW_PADDING, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawRect(x, top, width, BAR_HEIGHT, 0.6, 0.1, 0.1, 0.1)
    self:drawRect(x, top, width * math.max(0, math.min(share, 1)), BAR_HEIGHT, 0.9, colour[1], colour[2], colour[3])
    self:drawRectBorder(x, top, width, BAR_HEIGHT, 0.8, 0.4, 0.4, 0.4)
    self:drawTextCentre(value, x + width / 2, y, 1, 1, 1, 1, UIFont.Small)
    return y + lineHeight + 4
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
    local y = self:titleBarHeight() + WINDOW_PADDING

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

-- The notes in a muted colour, wrapped to the window, which then fits its height to them.
function PotWindow:drawNotes(y, notes)
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    for _, note in ipairs(notes) do
        y = y + 4
        for _, line in ipairs(wrapped(note, self.width - WINDOW_PADDING * 2)) do
            self:drawText(line, WINDOW_PADDING, y, 0.8, 0.8, 0.65, 1, UIFont.Small)
            y = y + lineHeight
        end
    end
    local height = y + WINDOW_PADDING
    if self.height ~= height then self:setHeight(height) end
end

-- Hearth Info: the fire, its fuel and the copper, laid out like Pot Info.
HearthWindow = PotWindow:derive("TraditionalPreservationDairyHearthWindow")

function HearthWindow:new(playerObj, hearth)
    local o = PotWindow.new(self, playerObj, hearth)
    o.title = getText("IGUI_CraftingWindow_DairyHearth")
    return o
end

function HearthWindow.open(playerObj, hearth)
    openInfo(HearthWindow, playerObj, hearth)
end

function HearthWindow:refresh()
    local hearth = self.station
    self.info = { copper = copperOf(hearth), lit = hearth:isLit(), fuelMin = hearth:getFuelAmount() }
end

function HearthWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.info then return end
    local info = self.info
    local copper, ml = info.copper, info.copper.ml or 0
    local y = self:titleBarHeight() + WINDOW_PADDING

    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoFire",
        getText(info.lit and "IGUI_TraditionalPreservationDairy_InfoFireLit" or "IGUI_TraditionalPreservationDairy_InfoFireOut"))
    local fuelMin = math.floor(info.fuelMin)
    y = self:bar(y, "IGUI_TraditionalPreservationDairy_InfoFuel", fuelMin / FUEL_SCALE_MIN, BAR_COLOURS.fuel,
        say("IGUI_TraditionalPreservationDairy_InfoFuelValue", tostring(math.floor(fuelMin / 60)), tostring(fuelMin % 60)))
    y = self:bar(y, "IGUI_TraditionalPreservationDairy_InfoCopper", ml / M.COPPER_ML, BAR_COLOURS.copper,
        say("IGUI_TraditionalPreservationDairy_InfoLitres", litresText(ml), litresText(M.COPPER_ML)))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoFluid",
        ml > 0 and M.fluidName(copper.fluid) or getText("IGUI_TraditionalPreservationDairy_InfoNothing"))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoTemp",
        ml > 0 and say("IGUI_TraditionalPreservationDairy_InfoDegrees", degrees(copper.tempC)) or "-")
    local milk = ml > 0 and M.MILKS[copper.fluid]
    if milk then
        -- Steaming already, or when it will be while the fire burns on.
        local hotIn = info.lit and M.hoursToHot(copper)
        local ready = M.copperHot(copper) and getText("IGUI_TraditionalPreservationDairy_InfoHotYes")
            or hotIn and hotIn <= info.fuelMin / 60 and say("IGUI_TraditionalPreservationDairy_InfoHotIn", hoursText(hotIn))
            or getText("IGUI_TraditionalPreservationDairy_InfoHotNo")
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoHot", ready)
    end

    local notes = {}
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_HearthHelpEmpty"))
    else
        if not milk then table.insert(notes, getText("IGUI_TraditionalPreservationDairy_HearthHelpWater")) end
        if not info.lit then table.insert(notes, getText("IGUI_TraditionalPreservationDairy_HearthHelpOut")) end
    end
    self:drawNotes(y, notes)
end

-- Not while paused, aiming or out of reach: vanilla's own checks for a click.
local function canClick(object, playerObj)
    return playerObj and not playerObj:isAiming()
        and not (UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0)
        and inReach(playerObj, object)
end

-- Clicking a pot opens Incubator Info, as clicking a door opens it. A Hearth is left to vanilla (its firebox in the
-- loot pane); Hearth Info is on its menu. The click handler is in vanilla's server folder, which loads after
-- this one, so it is wrapped once the game has started.
local function wrapClickHandler()
    if not ISObjectClickHandler or ISObjectClickHandler.tpdPotClick then return end
    local vanillaClickObject = ISObjectClickHandler.doClickSpecificObject
    ISObjectClickHandler.tpdPotClick = true
    function ISObjectClickHandler.doClickSpecificObject(object, playerNum, playerObj)
        if object and M.isIncubator(object) and canClick(object, playerObj) then
            if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.track(object) end
            PotWindow.open(playerObj, object)
            return true
        end
        return vanillaClickObject(object, playerNum, playerObj)
    end
end

Events.OnGameStart.Add(wrapClickHandler)

local function onFillContextMenu(playerNum, context, worldobjects)
    local playerObj = getSpecificPlayer(playerNum)
    for _, object in ipairs(worldobjects) do
        local incubator, crock, hearth = M.isIncubator(object), M.isCrock(object), M.isHearth(object)
        if incubator or crock or hearth then
            -- A station built or placed this session isn't tracked until its area reloads, so its menu starts it.
            if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.track(object) end
            if hearth then return addHearthMenu(context, playerObj, object) end
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
