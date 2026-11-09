-- Traditional Preservation (Dairy) B42: the Yoghurt Incubator and the Starter Culture Crock are worked from their
-- right-click menus. The pot: pour hot milk in, add a starter, pour the milk back out to reheat it, and collect the
-- set yoghurt into jars. The crock: load wheat and warm milk, feed it fresh milk, collect the starters. The status
-- line at the top says what the station is doing, and its hover says more. The pot also has an info window, opened
-- from its menu or by clicking it. A Jar of Yoghurt's own menu spoons it into cups.
require "TimedActions/ISYoghurtIncubator"
require "TimedActions/ISStarterCrock"
require "TimedActions/ISFillYoghurtCup"
require "ISUI/ISCollapsableWindow"
local UI = require "TraditionalPreservationDairy/Core/UI"
local Station = require "TraditionalPreservationDairy/Core/Station"

local M = TraditionalPreservationDairy
local say = UI.say
local STATION_ICON = "media/textures/Item_YoghurtIncubator.png"
local CROCK_ICON = "media/textures/Item_StarterCultureCrock.png"
local WHEAT_ICON = "Item_WheatGrains"
local MILK_ICON = "Item_Milk"
local YOGHURT_ICON = "Item_Yoghurt"
local JAR_ICON = "Item_ClayJar_Fired"
local PotWindow -- the info window, below the menus

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
        if M.itemScalded(item) then table.insert(hot, item) end
    end
    if #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoMilk")) end
    if #hot == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_MilkNotHot")) end
    addItemMenu(menu, option, playerObj, station, hot, "milk", function(item)
        return say("ContextMenu_TraditionalPreservationDairy_MilkItem", item:getDisplayName(), litresText(item:getFluidContainer():getAmount() * 1000),
            degrees(M.itemMilkC(item, now())))
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
    if stage == "Ready" then return addCollectMenu(menu, playerObj, station, state) end
    addMilkMenu(menu, playerObj, station, state)
    if stage ~= "Incubating" then addStarterMenu(menu, playerObj, station, state) end
    if stage == "Cooling" or stage == "TooCold" then addPourOutMenu(menu, playerObj, station, state) end
end

-- Crock

local function onCrockAction(playerObj, station, mode, item, wheat)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, seed in ipairs(wheat or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, seed) end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(ISStarterCrock:new(playerObj, station, mode, item, wheat))
end

-- Containers holding at least ml of plain milk, warm enough if warm is set.
local function milkFor(playerObj, ml, warm)
    return findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return M.milkIn(container) ~= nil and container:getAmount() * 1000 >= ml - 0.5 and (not warm or M.isWarm(M.itemMilkC(item, now())))
    end)
end

-- Load or Feed, with one entry per container of milk. wheat is the seeds a load takes.
local function addCrockMilkMenu(menu, option, playerObj, station, mode, milks, wheat)
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(milks) do
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", item:getDisplayName(),
            litresText(item:getFluidContainer():getAmount() * 1000), degrees(M.itemMilkC(item, now()))),
            playerObj, onCrockAction, station, mode, item, wheat)
        entry.iconTexture = item:getTex()
    end
end

local function addLoadMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_LoadCrock"))
    option.iconTexture = getTexture(WHEAT_ICON)
    local wheat = findItems(playerObj, function(item) return item:getFullType() == M.WHEAT end)
    if #wheat < M.CROCK_WHEAT then
        return disableWith(option, say("IGUI_TraditionalPreservationDairy_NeedWheat", tostring(M.CROCK_WHEAT), tostring(#wheat)))
    end
    local milks = milkFor(playerObj, M.CROCK_LOAD_ML, true)
    if #milks == 0 then
        local cold = #milkFor(playerObj, M.CROCK_LOAD_ML, false) > 0
        return disableWith(option, getText(cold and "IGUI_TraditionalPreservationDairy_CrockMilkCold" or "IGUI_TraditionalPreservationDairy_CrockNoMilk"))
    end
    local picked = {}
    for index = 1, M.CROCK_WHEAT do picked[index] = wheat[index] end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_LoadHelp"))
    addCrockMilkMenu(menu, option, playerObj, station, "load", milks, picked)
end

local function addFeedMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_FeedCrock"))
    option.iconTexture = getTexture(MILK_ICON)
    local milks = milkFor(playerObj, M.CROCK_FEED_ML, false)
    if #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_CrockNoMilk")) end
    addCrockMilkMenu(menu, option, playerObj, station, "feed", milks)
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

-- Pot Info: the status line and its hover laid out as a table, kept up to date while open. It closes when
-- the player walks off or the pot is gone. One at a time: opening another closes the last.
local WINDOW_WIDTH = 360
local WINDOW_REACH = 6
local WINDOW_PADDING = 10
local LABEL_WIDTH = 120
local BAR_HEIGHT = 12
local REFRESH_TICKS = 30
local BAR_COLOURS = { contents = { 0.6, 0.57, 0.46 }, set = { 0.55, 0.6, 0.25 } }
local STARTER_TEXT = { Yoghurt = "IGUI_TraditionalPreservationDairy_InfoStarterYoghurt", Starter = "IGUI_TraditionalPreservationDairy_InfoStarterCulture" }

PotWindow = ISCollapsableWindow:derive("TraditionalPreservationDairyPotWindow")

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

function PotWindow.open(playerObj, station)
    if PotWindow.instance then PotWindow.instance:close() end
    local window = PotWindow:new(playerObj, station)
    window:initialise()
    window:addToUIManager()
    PotWindow.instance = window
end

function PotWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if PotWindow.instance == self then PotWindow.instance = nil end
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

-- Clicking a pot opens Pot Info, as clicking a door opens it. Vanilla's own checks come first: not while
-- paused, aiming or dead. The click handler is in vanilla's server folder, which loads after this one, so it is
-- wrapped once the game has started.
local function wrapClickHandler()
    if not ISObjectClickHandler or ISObjectClickHandler.tpdPotClick then return end
    local vanillaClickObject = ISObjectClickHandler.doClickSpecificObject
    ISObjectClickHandler.tpdPotClick = true
    function ISObjectClickHandler.doClickSpecificObject(object, playerNum, playerObj)
        if object and M.isIncubator(object) and playerObj and not playerObj:isAiming()
                and not (UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0)
                and inReach(playerObj, object) then
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

-- Stamps the heat of milk the player has, or can reach (a pot on the stove), twice a second.
local SCAN_TICKS = 30
local ticks = 0
local function noteMilkHeat()
    ticks = ticks + 1
    if ticks < SCAN_TICKS then return end
    ticks = 0
    local playerObj = getPlayer()
    if not playerObj then return end
    local hour = now()
    findItems(playerObj, function(item)
        if M.milkIn(item:getFluidContainer()) then M.noteHeat(item, hour) end
        return false
    end)
end
Events.OnTick.Add(noteMilkHeat)
