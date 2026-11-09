-- Traditional Preservation (Dairy) B42: the Yoghurt Incubator has no window. Everything is done from its
-- right-click menu: pour hot milk in, add a starter, pour the milk back out to reheat it, and collect the set
-- yoghurt into a Clay Jar. The status line at the top says what the pot is doing, and its hover says more.
require "TimedActions/ISYoghurtIncubator"
local UI = require "TraditionalPreservationDairy/Core/UI"

local M = TraditionalPreservationDairy
local say = UI.say
local STATION_ICON = "media/textures/Item_YoghurtIncubator.png"
local MILK_ICON = "Item_Milk"
local YOGHURT_ICON = "Item_Yoghurt"
local JAR_ICON = "Item_ClayJar_Fired"

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
}

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
        table.insert(lines, say("IGUI_TraditionalPreservationDairy_Jars", tostring(math.ceil(state.ml / M.JAR_ML))))
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

local function addMilkMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourMilk"))
    option.iconTexture = getTexture(MILK_ICON)
    local room, reason = M.milkRoom(state, 1)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    local milks = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    local hot = {}
    for _, item in ipairs(milks) do
        if M.isHot(item:getItemHeat()) then table.insert(hot, item) end
    end
    if #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoMilk")) end
    if #hot == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_MilkNotHot")) end
    addItemMenu(menu, option, playerObj, station, hot, "milk", function(item)
        return say("ContextMenu_TraditionalPreservationDairy_MilkItem", item:getDisplayName(), litresText(item:getFluidContainer():getAmount() * 1000),
            degrees(M.heatCelsius(item:getItemHeat())))
    end)
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
    local jars = findItems(playerObj, function(item) return M.JARS[item:getFullType()] and M.isEmptyContainer(item) end)
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

    local stage = M.stage(state)
    if stage == "Ready" then return addCollectMenu(menu, playerObj, station, state) end
    addMilkMenu(menu, playerObj, station, state)
    if stage ~= "Incubating" then addStarterMenu(menu, playerObj, station, state) end
    if stage == "Cooling" or stage == "TooCold" then addPourOutMenu(menu, playerObj, station, state) end
end

local function onFillContextMenu(playerNum, context, worldobjects)
    local playerObj = getSpecificPlayer(playerNum)
    for _, object in ipairs(worldobjects) do
        if M.isIncubator(object) then
            -- A pot built or placed this session isn't tracked until its area reloads, so its menu starts it.
            if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.track(object) end
            return addIncubatorMenu(context, playerObj, object)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)
