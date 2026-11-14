-- Traditional Preservation (Dairy) B42: the Yogurt Incubator and the Starter Culture Crock are worked from their
-- right-click menus. The pot: pour milk steaming from a Hearth's cauldron in, add a starter, pour the milk back out, and
-- collect the set yogurt into jars. The crock: load wheat and warm milk from the cauldron, or soured milk alone, feed it
-- fresh milk, collect the starters. The status line at the top says what the station is doing, and its hover says more. Both also have
-- info windows (TP Core's InfoWindow), opened from their menus or by clicking them. A Jar of Yogurt's own menu spoons
-- it into cups. The Hearth's own menu and Hearth Info are TP Core's (HearthUI); Dairy adds its milk notes there.
require "TimedActions/TPYoghurtIncubator"
require "TimedActions/TPStarterCrock"
require "TimedActions/TPFillYoghurtCup"
local UI = require "TraditionalPreservationCore/UI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local HearthUI = require "TraditionalPreservationCore/HearthUI"
local Transfer = require "TraditionalPreservationCore/Transfer"

local M = TraditionalPreservationDairy
local say = UI.say
local STATION_ICON = "media/textures/Item_YoghurtIncubator.png"
local CROCK_ICON = "media/textures/Item_StarterCultureCrock.png"
local CAULDRON_ICON = "media/textures/Item_TPCauldronFull.png" -- TP Core's
local STARTER_ICON = "media/textures/Item_ActiveYoghurtStarter.png"
local JAR_ICON = "media/textures/Item_JarOfYoghurt.png"
local WHEAT_ICON = "Item_WheatGrains"
local BUCKET_ICON = "Item_MetalBucket"
local YOGHURT_ICON = "Item_Yoghurt"
local PotWindow, CrockWindow -- the info windows, below the menus

local REFUSALS = {
    HasStarter = "IGUI_TraditionalPreservationDairy_HasStarter",
    TooCold = "IGUI_TraditionalPreservationDairy_TooCold",
    Incubating = "IGUI_TraditionalPreservationDairy_Wrapped",
    Ready = "IGUI_TraditionalPreservationDairy_Wrapped",
    Full = "IGUI_TraditionalPreservationDairy_PotFull",
    NotScalded = "IGUI_TraditionalPreservationDairy_NotScalded",
    ColdForStarter = "IGUI_TraditionalPreservationDairy_ColdForStarter",
}

local function now()
    return getGameTime():getWorldAgeHours()
end

local litresText, degrees, hoursText = UI.litres, UI.degrees, UI.hoursText
local tooltipFor, disableWith, findItems = UI.tooltip, UI.disable, UI.findItems

-- A wrapped pot, jar or bucket by its own name in every menu ("Wrapped Cooking Pot"): vanilla's display name doesn't
-- see the wrap, only the inventory's fluid name does. The Wrapped Yogurt Pot is named so already.
UI.nameHook(function(item)
    if item:getFullType() ~= M.WRAPPED_POT and M.isWrapped(item) then
        return say("IGUI_TraditionalPreservationDairy_WrappedName", item:getDisplayName())
    end
end)

-- Glass and clay jars a pot of ml fills.
local function glassJars(ml) return math.ceil(ml / M.JAR_ML["Base.EmptyJar"]) end
local function clayJars(ml) return math.ceil(ml / M.JAR_ML["Base.ClayJar"]) end

local function onAction(playerObj, station, items, mode)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, item in ipairs(items) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
        ISTimedActionQueue.add(TPYoghurtIncubator:new(playerObj, station, item, mode))
    end
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
    local lines = { UI.placeText(place, placeC) }
    local stage = M.stage(state)
    if stage == "Empty" then
        table.insert(lines, getText("IGUI_TraditionalPreservationDairy_HelpEmpty"))
    elseif stage == "TooCold" then
        table.insert(lines, getText("IGUI_TraditionalPreservationDairy_TooCold"))
    elseif stage == "Ready" then
        table.insert(lines, say("IGUI_TraditionalPreservationDairy_Jars", tostring(glassJars(state.ml)), tostring(clayJars(state.ml)), tostring(M.cupsInPot(state))))
    else
        if stage == "Cooling" then
            table.insert(lines, getText(state.starter and "IGUI_TraditionalPreservationDairy_StarterIn" or "IGUI_TraditionalPreservationDairy_NoStarter"))
        else
            table.insert(lines, say("IGUI_TraditionalPreservationDairy_SetProgress", UI.percent(math.min(state.done / M.INCUBATE_HOURS, 1)),
                UI.percent(M.setRate(state.tempC))))
        end
        -- Next: the wrap goes on, the yogurt sets, or the milk goes too cold for a starter.
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
        entry.itemForTexture = item
    end
end

-- The cauldron's state, brought up to now when the World runs here.
local cauldronOf = Hearth.cauldronOf

-- The first hearth near the station whose cauldron passes test, else nil and the nearest one's cauldron.
local function hearthFor(station, test)
    local nearest
    for _, hearth in ipairs(M.hearthsNear(station:getSquare())) do
        local cauldron = cauldronOf(hearth)
        if test(cauldron) then return hearth, cauldron end
        nearest = nearest or cauldron
    end
    return nil, nearest
end

-- Why the nearest cauldron won't do: none near, no milk in it, too cold, or steaming but not held long enough yet.
local function hearthRefusal(cauldron, notHotKey)
    if not cauldron then return getText("IGUI_TraditionalPreservationDairy_NoHearth") end
    if not M.MILKS[cauldron.fluid] then return getText("IGUI_TraditionalPreservationDairy_CauldronNoMilk") end
    if M.cauldronHot(cauldron) then return say("IGUI_TraditionalPreservationDairy_CauldronNotHeld", tostring(M.holdMinutesLeft(cauldron))) end
    return say(notHotKey, degrees(cauldron.tempC))
end

local function onHearthPour(playerObj, station, hearth)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    ISTimedActionQueue.add(TPYoghurtIncubator:new(playerObj, station, nil, "hearth", hearth))
end

local function addHearthPourMenu(menu, playerObj, station, state)
    local label = getText("ContextMenu_TraditionalPreservationDairy_PourFromHearth")
    local room, reason = M.milkRoom(state, 1)
    local hearth, cauldron
    if room > 0 then hearth, cauldron = hearthFor(station, M.cauldronScalded) end
    if hearth then label = say("ContextMenu_TraditionalPreservationDairy_MilkItem", label, litresText(cauldron.ml), degrees(cauldron.tempC)) end
    local option = menu:addOption(label, playerObj, onHearthPour, station, hearth)
    option.iconTexture = getTexture(CAULDRON_ICON)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    if not hearth then return disableWith(option, hearthRefusal(cauldron, "IGUI_TraditionalPreservationDairy_CauldronNotHot")) end
end

-- A submenu's icon: the first item it lists, drawn as the inventory draws it (a bucket of milk shows milk), or
-- fallback when it lists none.
local function showFirst(option, items, fallback)
    if items[1] then
        option.itemForTexture = items[1]
    else
        option.iconTexture = getTexture(fallback)
    end
end

-- Every container of plain milk, wherever it was carried from. Milk that isn't scalded (never at 85 C: cauldron, stove
-- or fire), or is too cold for the starter already in the pot, shows in red with the reason. An open pot loses its
-- heat in minutes, a Wrapped Yogurt Pot in hours.
local function addCarriedPourMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourScalded"))
    local items = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    showFirst(option, items, BUCKET_ICON)
    local room, reason = M.milkRoom(state, 1)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoMilkItem")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_ScaldedHelp"))
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local container = item:getFluidContainer()
        local ml = M.mlIn(container)
        local heat = M.carriedC(item, now(), playerObj)
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", UI.itemName(item), litresText(ml),
            degrees(heat)), playerObj, onAction, station, { item }, "carried")
        entry.itemForTexture = item
        local _, parts = M.milkIn(container)
        local refusal = M.carriedRefusal(M.carryOf(item), ml, parts) or M.coldRefusal(state, ml, heat)
        if refusal then
            entry.notAvailable = true
            tooltipFor(entry, say(REFUSALS[refusal], degrees(heat)))
        end
    end
end

local function addStarterMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_AddStarter"))
    option.iconTexture = getTexture(STARTER_ICON)
    local ok, reason = M.canAddStarter(state)
    if not ok then return disableWith(option, getText(REFUSALS[reason])) end
    local starters = findItems(playerObj, M.isStarter)
    if #starters == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoStarterItem")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_StarterHelp"))
    -- One is all a batch takes, so there's no "all".
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    local seen = {}
    for _, item in ipairs(starters) do
        if not seen[item:getFullType()] then
            seen[item:getFullType()] = true
            local entry = sub:addOption(UI.itemName(item), playerObj, onAction, station, { item }, "starter")
            entry.itemForTexture = item
            if item:getFullType() == M.YOGHURT_JAR then tooltipFor(entry, getText("IGUI_TraditionalPreservationDairy_JarStarter")) end
        end
    end
end

local function addPourOutMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourOut"))
    local empties = findItems(playerObj, M.isEmptyContainer)
    showFirst(option, empties, BUCKET_ICON)
    if #empties == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoContainer")) end
    addItemMenu(menu, option, playerObj, station, empties, "pourOut", function(item)
        return say("ContextMenu_TraditionalPreservationDairy_Holds", UI.itemName(item), litresText(item:getFluidContainer():getCapacity() * 1000))
    end)
end

local function addCollectMenu(menu, playerObj, station, state)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_Collect"))
    option.iconTexture = getTexture(JAR_ICON)
    local jars = findItems(playerObj, function(item) return M.JAR_ML[item:getFullType()] ~= nil and M.isEmptyContainer(item) end)
    if #jars == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoJar")) end
    local types, picked = {}, {}
    for index, jar in ipairs(jars) do types[index] = jar:getFullType() end
    local most = M.jarsFor(state.ml, types)
    for index = 1, most do picked[index] = jars[index] end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    -- One entry per kind of jar carried, so the player picks glass or clay.
    local seen = {}
    for _, jar in ipairs(jars) do
        local jarType = jar:getFullType()
        if not seen[jarType] then
            seen[jarType] = true
            local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_OneJar", jar:getDisplayName(), litresText(M.JAR_ML[jarType])), playerObj, onAction, station, { jar }, "collect")
            entry.itemForTexture = jar
        end
    end
    if most > 1 then
        local all = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_All", tostring(most)), playerObj, onAction, station, picked, "collect")
        all.iconTexture = getTexture(JAR_ICON)
    end
end

-- Empty Yogurt Containers filled straight from the pot, a quarter of a jar each, as old as the batch.
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
    local one = sub:addOption(getText("ContextMenu_TraditionalPreservationDairy_OneCup"), playerObj, onAction, station, { empties[1] }, "cup")
    one.iconTexture = getTexture(YOGHURT_ICON)
    if most > 1 then
        local all = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_All", tostring(most)), playerObj, onAction, station, picked, "cup")
        all.iconTexture = getTexture(YOGHURT_ICON)
    end
end

-- A station's menu entry: its name, with its status after it when the click took in several (summary), so each
-- can be told from the others.
local function stationLabel(name, status, summary)
    if not summary then return getText(name) end
    return getText(name) .. " (" .. status .. ")"
end

local function addIncubatorMenu(context, playerObj, station, summary)
    local World = TraditionalPreservationDairyWorld
    local state = World and World.updateIncubator(station, getGameTime():getWorldAgeHours())
        or M.stateOf(station:getModData().movableData or {}, M.INCUBATOR_KEY)
    local option = context:addOption(stationLabel("IGUI_CraftingWindow_YoghurtIncubator", statusText(state), summary))
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
    ISTimedActionQueue.add(TPStarterCrock:new(playerObj, station, mode, item, wheat, hearth))
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
    local hearth, cauldron = hearthFor(station, TPStarterCrock.cauldronReady)
    local milks = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    if not cauldron and #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_CrockNoWarmMilk")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_LoadHelp"))
    local picked = {}
    for index = 1, M.CROCK_WHEAT do picked[index] = wheat[index] end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    if cauldron then
        local label = getText("ContextMenu_TraditionalPreservationDairy_LoadFromHearth")
        if M.MILKS[cauldron.fluid] then label = say("ContextMenu_TraditionalPreservationDairy_MilkItem", label, litresText(cauldron.ml), degrees(cauldron.tempC)) end
        local entry = sub:addOption(label, playerObj, onCrockAction, station, "load", nil, picked, hearth)
        entry.iconTexture = getTexture(CAULDRON_ICON)
        if not hearth then
            if M.MILKS[cauldron.fluid] then
                refuseLoad(entry, cauldron.ml or 0, cauldron.tempC or 0)
            else
                entry.notAvailable = true
                tooltipFor(entry, getText("IGUI_TraditionalPreservationDairy_CauldronNoMilk"))
            end
        end
    end
    for _, item in ipairs(milks) do
        local ml = M.mlIn(item:getFluidContainer())
        local heat = M.carriedC(item, now(), playerObj)
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", UI.itemName(item), litresText(ml),
            degrees(heat)), playerObj, onCrockAction, station, "load", item, picked)
        entry.itemForTexture = item
        refuseLoad(entry, ml, heat)
    end
end

local CLABBER_REFUSALS = {
    Rotten = "IGUI_TraditionalPreservationDairy_ClabberRotten",
    TooLittle = "IGUI_TraditionalPreservationDairy_CrockTooLittle",
}

-- Half a litre of soured milk of any warmth, no wheat: one entry per container of soured or rotten milk, rotten
-- and too little in red with the reason.
local function addClabberMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_ClabberCrock"))
    local milks = findItems(playerObj, function(item) return M.clabberIn(item:getFluidContainer()) ~= nil end)
    showFirst(option, milks, BUCKET_ICON)
    if #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_ClabberNoMilk")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_ClabberHelp"))
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(milks) do
        local container = item:getFluidContainer()
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_FluidItem", UI.itemName(item),
            litresText(container:getAmount() * 1000)), playerObj, onCrockAction, station, "clabber", item)
        entry.itemForTexture = item
        local refusal = M.clabberRefusal(container)
        if refusal then
            entry.notAvailable = true
            tooltipFor(entry, getText(CLABBER_REFUSALS[refusal]))
        end
    end
end

-- Fresh milk of any warmth, one entry per container.
local function addFeedMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_FeedCrock"))
    local milks = milkFor(playerObj, M.CROCK_FEED_ML)
    showFirst(option, milks, BUCKET_ICON)
    if #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_CrockNoMilk")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(milks) do
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_FluidItem", UI.itemName(item),
            litresText(item:getFluidContainer():getAmount() * 1000)), playerObj, onCrockAction, station, "feed", item)
        entry.itemForTexture = item
    end
end

local function crockDetail(station, state)
    local ledger = M.getLedger()
    local place = state.place or M.placeOf(station)
    local lines = { UI.placeText(place, M.placeTemperature(ledger, place)) }
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

local function addCrockMenu(context, playerObj, station, summary)
    local World = TraditionalPreservationDairyWorld
    local state = World and World.updateCrock(station) or M.stateOf(station:getModData().movableData or {}, M.CROCK_KEY)
    local stage = M.crockStage(state)
    local option = context:addOption(stationLabel("IGUI_CraftingWindow_StarterCultureCrock",
        getText("IGUI_TraditionalPreservationDairy_Crock" .. stage), summary))
    option.iconTexture = getTexture(CROCK_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(getText("IGUI_TraditionalPreservationDairy_Crock" .. stage))
    status.isDisabled = true
    tooltipFor(status, crockDetail(station, state))
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_CrockInfo"), playerObj, CrockWindow.open, station)
    info.iconTexture = getTexture(CROCK_ICON)

    if stage == "Empty" then
        addLoadMenu(menu, playerObj, station)
        addClabberMenu(menu, playerObj, station)
    elseif stage == "Waiting" then
        addFeedMenu(menu, playerObj, station)
    elseif stage == "Ready" then
        local collect = menu:addOption(say("ContextMenu_TraditionalPreservationDairy_CollectStarters", tostring(M.CROCK_STARTERS)),
            playerObj, onCrockAction, station, "collect")
        collect.iconTexture = getTexture(STARTER_ICON)
    end
end

-- Pot Info: the status line and its hover laid out as a table, kept up to date while open.
local BAR_COLOURS = { contents = { 0.6, 0.57, 0.46 }, set = { 0.55, 0.6, 0.25 }, culture = { 0.7, 0.62, 0.35 } }
local STARTER_TEXT = { Yogurt = "IGUI_TraditionalPreservationDairy_InfoStarterYoghurt", Starter = "IGUI_TraditionalPreservationDairy_InfoStarterCulture" }

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
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoPlace", UI.placeText(info.place, info.placeC))
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
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoJars", say("IGUI_TraditionalPreservationDairy_InfoJarsCount", tostring(glassJars(ml)), tostring(clayJars(ml))))
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
    if (stage == "Cooling" or stage == "Incubating") and info.hours then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_InfoAssumes"))
    end
    self:drawNotes(y, notes)
end

-- Hearth Info (TP Core's) says what the cauldron's milk is for.
HearthUI.addNotes(function(info, notes)
    local ml = info.cauldron.ml or 0
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_HearthHelpEmpty"))
    elseif not M.MILKS[info.cauldron.fluid] then
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
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoPlace", UI.placeText(status.place, status.temperature))
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
    else
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_InfoAssumes"))
    end
    self:drawNotes(y, notes)
end

-- Clicking a pot opens Incubator Info, and clicking a crock Crock Info, as clicking a door opens it (a Hearth's click
-- is TP Core's).
InfoWindow.clickOpens(function(object) return M.stationKind(object) ~= nil end, function(playerObj, object)
    if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.track(object) end
    local window = M.isCrock(object) and CrockWindow or PotWindow
    window.open(playerObj, object)
end)

-- The crock stands on a counter or a table, never on a stove, a fridge or a freezer.
local crockFaces = {}
for face = 0, M.FACE_COUNT - 1 do crockFaces[M.spriteName(M.CROCK_SPRITE + face)] = true end
UI.offAppliances(crockFaces)
-- No station, the incubator or the crock, is put down in front of a door (TP Core's Doors).
UI.keepDoorsFree(require("TraditionalPreservationDairy/Tiles").STATIONS)

-- Every pot and crock the click took in gets its own menu. With more than one, each is named with its status
-- ("Yogurt Incubator (Cooling: 2.0 L at 60 C)"), so the player picks the right one.
local function onFillContextMenu(playerNum, context, worldobjects, test)
    local stations, seen = {}, {}
    for _, object in ipairs(worldobjects) do
        if M.stationKind(object) and not seen[object] then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[object] = true
            table.insert(stations, object)
        end
    end
    local playerObj = getSpecificPlayer(playerNum)
    for _, station in ipairs(stations) do
        -- A station built or placed this session isn't tracked until its area reloads, so its menu starts it.
        if TraditionalPreservationDairyWorld then TraditionalPreservationDairyWorld.track(station) end
        if M.isCrock(station) then
            addCrockMenu(context, playerObj, station, #stations > 1)
        else
            addIncubatorMenu(context, playerObj, station, #stations > 1)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- One portion through vanilla's eat action (mask, utensils and all); its share is of the full jar.
local function onEatPortion(playerObj, jar)
    ISInventoryPaneContextMenu.eatItem(jar, M.portionShare(M.jarPortions(jar), M.jarFull(jar)), playerObj:getPlayerNum())
end

-- Jar of Yogurt: eat a portion, or spoon one cup, or every cup the jar and the empty containers allow.
local function onFillCups(playerObj, jar, cups)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, jar)
    for _, cup in ipairs(cups) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, cup)
        ISTimedActionQueue.add(TPFillYoghurtCup:new(playerObj, jar, cup))
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
    local left = math.ceil(M.jarPortions(jar) - M.EMPTY_PORTIONS)
    M.labelJar(jar)
    local eat = context:addOption(getText("ContextMenu_TraditionalPreservationDairy_EatPortion"), playerObj, onEatPortion, jar)
    eat.itemForTexture = jar
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

-- Milk taken off a stove or a fire keeps its heat as a record (vanilla's drops within seconds): read as it is moved,
-- while it is still on the heat.
Transfer.before(function(action, item)
    local from = action.srcContainer
    if item:getFluidContainer() and from and not from:isInCharacterInventory(action.character)
        and from:getTemperature() > 1 then
        M.stampHeat(item, getGameTime():getWorldAgeHours())
    end
end)
