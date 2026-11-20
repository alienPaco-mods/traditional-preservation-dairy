-- Traditional Preservation (Dairy) B42: the Culturing Pot and the Starter Culture Crock are worked from their
-- right-click menus. The pot: pour milk steaming from a Stone Hearth's cauldron in, add a starter, pour the milk back out, and
-- collect the set yogurt into jars. The crock: load wheat and warm milk from the cauldron, or soured milk alone, feed it
-- fresh milk, collect the starters. The status line at the top says what the station is doing, and its hover says more. Both also have
-- info windows (TP Core's InfoWindow), opened from their menus or by clicking them. A Jar of Yogurt's own menu spoons
-- it into cups. The Stone Hearth's own menu and Stone Hearth Info are TP Core's (FireUI); Dairy adds its milk notes there (CauldronUI.addNotes).
require "TimedActions/TPYoghurtIncubator"
require "TimedActions/TPStarterCrock"
require "TimedActions/TPFillYoghurtCup"
require "TimedActions/TPKefirIncubator"
require "TimedActions/TPKefirGrains"
local UI = require "TraditionalPreservationCore/UI"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local CauldronUI = require "TraditionalPreservationCore/CauldronUI"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Transfer = require "TraditionalPreservationCore/Transfer"
local PlaceKeepingUI = require "TraditionalPreservationCore/PlaceKeepingUI"
local ItemFluidUI = require "TraditionalPreservationCore/ItemFluidUI"
local Tiles = require "TraditionalPreservationDairy/Tiles"

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
local GRAINS_ICON = "media/textures/Item_KefirGrains.png"
local STRAINER_ICON = "Item_Strainer"
local PotWindow, CrockWindow -- the info windows, below the menus

local REFUSALS = {
    HasStarter = "IGUI_TraditionalPreservationDairy_HasStarter",
    TooCold = "IGUI_TraditionalPreservationDairy_TooCold",
    Incubating = "IGUI_TraditionalPreservationDairy_Wrapped",
    Ready = "IGUI_TraditionalPreservationDairy_Wrapped",
    Full = "IGUI_TraditionalPreservationDairy_PotFull",
    NotScalded = "IGUI_TraditionalPreservationDairy_NotScalded",
    ColdForStarter = "IGUI_TraditionalPreservationDairy_ColdForStarter",
    KefirPot = "IGUI_TraditionalPreservationDairy_KefirPot",
    KefirReady = "IGUI_TraditionalPreservationDairy_KefirReadyRefusal",
    TooHot = "IGUI_TraditionalPreservationDairy_TooHotForGrains",
}

local function now()
    return getGameTime():getWorldAgeHours()
end

local litresText, degrees, hoursText = UI.litres, UI.degrees, UI.hoursText
local tooltipFor, disableWith, refuse, findItems = UI.tooltip, UI.disable, UI.refuse, UI.findItems
-- Dairy's World (TraditionalPreservationDairyWorld) is a server file, loaded after this one: named where it is used.

-- The first n of a list (all of it if shorter).
local function firstOf(list, n)
    local picked = {}
    for index = 1, math.min(n, #list) do picked[index] = list[index] end
    return picked
end

-- A wrapped pot, jar or bucket by its own name in every menu ("Wrapped Cooking Pot"): vanilla's display name doesn't
-- see the wrap, only the inventory's fluid name does. The Wrapped Clay Pot is named so already.
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

-- The pot's note for a stage that waits on the player, in its hover and in Incubator Info.
local WAITING_NOTES = { Empty = "IGUI_TraditionalPreservationDairy_HelpEmpty", TooCold = "IGUI_TraditionalPreservationDairy_TooCold" }

local function statusText(batch)
    local stage = M.stage(batch)
    if stage == "KefirGrains" then return say("IGUI_TraditionalPreservationDairy_StageKefirGrains", tostring(M.grainCount(batch))) end
    if stage == "Fermenting" then
        return say("IGUI_TraditionalPreservationDairy_StageFermenting", litresText(batch.ml), UI.percent(batch.progress or 0))
    end
    if stage == "KefirReady" then return say("IGUI_TraditionalPreservationDairy_StageKefirReady", litresText(batch.ml)) end
    if stage == "Empty" then
        return getText(batch.starter and "IGUI_TraditionalPreservationDairy_EmptyStarter" or "IGUI_TraditionalPreservationDairy_Empty")
    end
    return say("IGUI_TraditionalPreservationDairy_Stage" .. stage, litresText(batch.ml), degrees(batch.tempC))
end

-- Why a kefir pot won't ferment: no grain left alive, or the place is frozen.
local function stalledKey(batch)
    if select(2, M.grainCount(batch)) <= 0 then return "IGUI_TraditionalPreservationDairy_GrainsAllDead" end
    return "IGUI_TraditionalPreservationDairy_KefirStalled"
end

-- A kefir pot's grains and their share of full speed, and when it will be ready if the place's temperature holds.
local function kefirLines(batch, placeC, lines)
    local stage = M.stage(batch)
    if stage == "KefirGrains" then return table.insert(lines, getText("IGUI_TraditionalPreservationDairy_HelpKefirGrains")) end
    if stage == "KefirReady" then return table.insert(lines, getText("IGUI_TraditionalPreservationDairy_HelpKefirReady")) end
    table.insert(lines, say("IGUI_TraditionalPreservationDairy_KefirGrainsSpeed", tostring(M.grainCount(batch)),
        UI.percent(M.kefirRatio(batch)), UI.percent(M.kefirRate(placeC))))
    local hours = M.kefirHoursLeft(batch, placeC)
    table.insert(lines, hours and say("IGUI_TraditionalPreservationDairy_NextKefirReady", hoursText(hours))
        or getText(stalledKey(batch)))
end

-- The hover: where the pot stands, what comes next and when, if the place's temperature holds.
local function detailText(station, batch)
    local place = batch.place or M.placeOf(station)
    local placeC = M.placeTemperature(M.getLedger(), place)
    local lines = { UI.placeText(place, placeC) }
    if batch.culture then
        kefirLines(batch, placeC, lines)
        return table.concat(lines, " <LINE> ")
    end
    local stage = M.stage(batch)
    if WAITING_NOTES[stage] then
        table.insert(lines, getText(WAITING_NOTES[stage]))
    elseif stage == "Ready" then
        table.insert(lines, say("IGUI_TraditionalPreservationDairy_Jars", tostring(glassJars(batch.ml)), tostring(clayJars(batch.ml)), tostring(M.cupsInPot(batch))))
    else
        if stage == "Cooling" then
            table.insert(lines, getText(batch.starter and "IGUI_TraditionalPreservationDairy_StarterIn" or "IGUI_TraditionalPreservationDairy_NoStarter"))
        else
            table.insert(lines, say("IGUI_TraditionalPreservationDairy_SetProgress", UI.percent(math.min(batch.workHours / M.INCUBATE_HOURS, 1)),
                UI.percent(M.setRate(batch.tempC))))
        end
        -- Next: the wrap goes on, the yogurt sets, or the milk goes too cold for a starter.
        local hours, nextStage = M.forecast(batch, placeC)
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
        local itemOption = sub:addOption(label(item), playerObj, onAction, station, { item }, mode)
        itemOption.itemForTexture = item
    end
end

-- The cauldron's modData, brought up to now when the World runs here.
local cauldronOf = Cauldron.of

-- The first fire near the station whose cauldron passes test, else nil and the nearest one's cauldron.
local function cauldronFor(station, test)
    local nearest
    for _, fire in ipairs(M.cauldronsNear(station:getSquare())) do
        local cauldron = cauldronOf(fire)
        if test(cauldron) then return fire, cauldron end
        nearest = nearest or cauldron
    end
    return nil, nearest
end

-- Why the nearest cauldron won't do: none near, no milk in it, too cold, or steaming but not held long enough yet.
local function cauldronRefusal(cauldron, notHotKey)
    if not cauldron then return getText("IGUI_TraditionalPreservationDairy_NoCauldron") end
    if not M.MILKS[cauldron.fluid] then return getText("IGUI_TraditionalPreservationDairy_CauldronNoMilk") end
    if M.cauldronHot(cauldron) then return say("IGUI_TraditionalPreservationDairy_CauldronNotHeld", tostring(M.holdMinutesLeft(cauldron))) end
    return say(notHotKey, degrees(cauldron.tempC))
end

local function onCauldronPour(playerObj, station, fire)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    ISTimedActionQueue.add(TPYoghurtIncubator:new(playerObj, station, nil, "fire", fire))
end

local function addCauldronPourMenu(menu, playerObj, station, batch)
    local label = getText("ContextMenu_TraditionalPreservationDairy_PourFromCauldron")
    local room, reason = M.milkRoom(batch, 1)
    local fire, cauldron
    if room > 0 then fire, cauldron = cauldronFor(station, M.cauldronScalded) end
    if fire then label = say("ContextMenu_TraditionalPreservationDairy_MilkItem", label, litresText(cauldron.ml), degrees(cauldron.tempC)) end
    local option = menu:addOption(label, playerObj, onCauldronPour, station, fire)
    option.iconTexture = getTexture(CAULDRON_ICON)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    if not fire then return disableWith(option, cauldronRefusal(cauldron, "IGUI_TraditionalPreservationDairy_CauldronNotHot")) end
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
-- heat in minutes, a Wrapped Clay Pot in hours.
local function addCarriedPourMenu(menu, playerObj, station, batch)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourScalded"))
    local items = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    showFirst(option, items, BUCKET_ICON)
    local room, reason = M.milkRoom(batch, 1)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoMilkItem")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_ScaldedHelp"))
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local container = item:getFluidContainer()
        local ml = M.mlIn(container)
        local heat = M.carriedC(item, now(), playerObj)
        local itemOption = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", UI.itemName(item), litresText(ml),
            degrees(heat)), playerObj, onAction, station, { item }, "carried")
        itemOption.itemForTexture = item
        local _, parts = M.milkIn(container)
        local refusal = M.carriedRefusal(M.carryOf(item), ml, parts) or M.coldRefusal(batch, ml, heat)
        if refusal then refuse(itemOption, say(REFUSALS[refusal], degrees(heat))) end
    end
end

local function addStarterMenu(menu, playerObj, station, batch)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_AddStarter"))
    option.iconTexture = getTexture(STARTER_ICON)
    local ok, reason = M.canAddStarter(batch)
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
            local itemOption = sub:addOption(UI.itemName(item), playerObj, onAction, station, { item }, "starter")
            itemOption.itemForTexture = item
            if item:getFullType() == M.YOGHURT_JAR then tooltipFor(itemOption, getText("IGUI_TraditionalPreservationDairy_JarStarter")) end
        end
    end
end

local function addPourOutMenu(menu, playerObj, station, batch)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourOut"))
    local empties = findItems(playerObj, M.isEmptyContainer)
    showFirst(option, empties, BUCKET_ICON)
    if #empties == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoContainer")) end
    addItemMenu(menu, option, playerObj, station, empties, "pourOut", function(item)
        return say("ContextMenu_TraditionalPreservationDairy_Holds", UI.itemName(item), litresText(item:getFluidContainer():getCapacity() * 1000))
    end)
end

local function addCollectMenu(menu, playerObj, station, batch)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_Collect"))
    option.iconTexture = getTexture(JAR_ICON)
    local jars = findItems(playerObj, function(item) return M.JAR_ML[item:getFullType()] ~= nil and M.isEmptyContainer(item) end)
    if #jars == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoJar")) end
    local types = {}
    for index, jar in ipairs(jars) do types[index] = jar:getFullType() end
    local most = M.jarsFor(batch.ml, types)
    local picked = firstOf(jars, most)
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    -- One entry per kind of jar carried, so the player picks glass or clay.
    local seen = {}
    for _, jar in ipairs(jars) do
        local jarType = jar:getFullType()
        if not seen[jarType] then
            seen[jarType] = true
            local itemOption = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_OneJar", jar:getDisplayName(), litresText(M.JAR_ML[jarType])), playerObj, onAction, station, { jar }, "collect")
            itemOption.itemForTexture = jar
        end
    end
    if most > 1 then
        local all = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_All", tostring(most)), playerObj, onAction, station, picked, "collect")
        all.iconTexture = getTexture(JAR_ICON)
    end
end

-- Empty Yogurt Containers filled straight from the pot, a quarter of a jar each, as old as the batch.
local function addCupMenu(menu, playerObj, station, batch)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_FillPotCups"))
    option.iconTexture = getTexture(YOGHURT_ICON)
    local empties = findItems(playerObj, function(item) return item:getFullType() == M.EMPTY_CUP end)
    if #empties == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoEmptyCup")) end
    local most = math.min(#empties, M.cupsInPot(batch))
    local picked = firstOf(empties, most)
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

-- Kefir

-- target is what the job works with: the grain items for "grains", the Stone Hearth for "fire", the container for
-- "milk" and "strain", nothing for "takeGrains".
local function onKefirAction(playerObj, station, mode, target)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    local item, items, fire
    if mode == "grains" then items = target elseif mode == "fire" then fire = target else item = target end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    for _, grain in ipairs(items or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, grain) end
    ISTimedActionQueue.add(TPKefirIncubator:new(playerObj, station, mode, item, items, fire))
end

-- The grain items carried, in groups by what they are: live, hungry, dried, coming back from dried, dead.
local GRAIN_GROUPS = { "Live", "Hungry", "Dried", "Reactivating", "Dead" }

local function grainGroup(item)
    if item:getFullType() == M.DRIED_GRAIN then return "Dried" end
    return M.keepGrain(item, now()).grainState
end

-- How many of a group bring the pot's milk to full speed, counting the grains already in; nil with no milk yet or when
-- it is already there.
local function enoughFor(batch, share)
    local ml = batch.ml or 0
    if ml <= 0 then return nil end
    local _, work = M.grainCount(batch)
    local need = math.ceil((ml / M.ML_PER_GRAIN - work) / share - 1e-9)
    return need > 0 and need or nil
end

-- Add Kefir Grains: a row per group carried, each with One, enough for the milk, and All; dead ones in red.
local function addGrainsMenu(menu, playerObj, station, batch)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_AddKefirGrains"))
    option.iconTexture = getTexture(GRAINS_ICON)
    local reason = M.grainRefusal(batch)
    if reason == "TooHot" then return disableWith(option, say(REFUSALS.TooHot, degrees(batch.tempC))) end
    if reason then return disableWith(option, getText(REFUSALS[reason])) end
    local groups, found = {}, findItems(playerObj, function(item)
        local fullType = item:getFullType()
        return fullType == M.GRAIN or fullType == M.DRIED_GRAIN
    end)
    for _, item in ipairs(found) do
        local group = grainGroup(item)
        groups[group] = groups[group] or {}
        table.insert(groups[group], item)
    end
    if #found == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoGrainItem")) end
    if (batch.ml or 0) > 0 and M.grainHeat(batch.tempC or 0) == M.GRAIN_HUNGRY then
        tooltipFor(option, say("IGUI_TraditionalPreservationDairy_WarmForGrainsWait", degrees(batch.tempC)))
    else
        tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_GrainsHelp"))
    end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, group in ipairs(GRAIN_GROUPS) do
        local items = groups[group]
        if items then
            local row = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_Grains" .. group, tostring(#items)))
            row.itemForTexture = items[1]
            if group == "Dead" then
                refuse(row, getText("IGUI_TraditionalPreservationDairy_GrainsDead"))
            else
                local rowMenu = sub:getNew(sub)
                sub:addSubMenu(row, rowMenu)
                rowMenu:addOption(getText("ContextMenu_TraditionalPreservationDairy_GrainsOne"), playerObj, onKefirAction, station,
                    "grains", { items[1] })
                local share = group == "Live" and 1 or 0.5
                local enough = enoughFor(batch, share)
                if enough and enough > 1 and enough < #items then
                    rowMenu:addOption(say("ContextMenu_TraditionalPreservationDairy_GrainsEnough", tostring(enough)), playerObj,
                        onKefirAction, station, "grains", firstOf(items, enough))
                end
                if #items > 1 then
                    rowMenu:addOption(say("ContextMenu_TraditionalPreservationDairy_All", tostring(#items)), playerObj, onKefirAction,
                        station, "grains", items)
                end
            end
        end
    end
end

-- Why milk at celsius can't go on the grains (in red), or a warning that it weakens them; nil when it is fine.
local function heatNote(option, batch, ml, celsius)
    local refusal = M.kefirMilkRefusal(batch, ml, celsius)
    if refusal then return refuse(option, say(REFUSALS[refusal], degrees(celsius))) end
    local had = batch.ml or 0
    local taken = M.milkRoom(batch, ml)
    local mixedC = had > 0 and (batch.tempC * had + celsius * taken) / (had + taken) or celsius
    if M.grainHeat(mixedC) == M.GRAIN_HUNGRY then
        tooltipFor(option, say("IGUI_TraditionalPreservationDairy_WarmForGrains", degrees(mixedC)))
    end
end

-- Pour Milk: the nearest Stone Hearth's cauldron of milk, and every container of milk carried, any milk at any heat
-- the grains survive.
local function addKefirMilkMenu(menu, playerObj, station, batch)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PourMilk"))
    local room, reason = M.milkRoom(batch, 1)
    local items = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    showFirst(option, items, BUCKET_ICON)
    if room <= 0 then return disableWith(option, getText(REFUSALS[reason])) end
    local fire, cauldron = cauldronFor(station, function(c) return M.MILKS[c.fluid] ~= nil end)
    if #items == 0 and not cauldron then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoKefirMilk")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_KefirMilkHelp"))
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    if cauldron then
        local label = getText("ContextMenu_TraditionalPreservationDairy_PourFromCauldron")
        if M.MILKS[cauldron.fluid] then label = say("ContextMenu_TraditionalPreservationDairy_MilkItem", label, litresText(cauldron.ml), degrees(cauldron.tempC)) end
        local cauldronOption = sub:addOption(label, playerObj, onKefirAction, station, "fire", fire)
        cauldronOption.iconTexture = getTexture(CAULDRON_ICON)
        if fire then
            heatNote(cauldronOption, batch, cauldron.ml or 0, cauldron.tempC or 0)
        else
            refuse(cauldronOption, getText("IGUI_TraditionalPreservationDairy_CauldronNoMilk"))
        end
    end
    for _, item in ipairs(items) do
        local ml = M.mlIn(item:getFluidContainer())
        local heat = M.carriedC(item, now(), playerObj)
        local itemOption = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", UI.itemName(item), litresText(ml),
            degrees(heat)), playerObj, onKefirAction, station, "milk", item)
        itemOption.itemForTexture = item
        heatNote(itemOption, batch, ml, heat)
    end
end

-- Strain Kefir: one entry per empty container, through the Strainer, or a cloth at twice the time.
local function addStrainMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_StrainKefir"))
    option.iconTexture = getTexture(STRAINER_ICON)
    local tool, cloth = M.strainTool(playerObj:getInventory())
    if not tool then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoStrainer")) end
    local empties = findItems(playerObj, M.isEmptyContainer)
    if #empties == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_NoContainer")) end
    tooltipFor(option, say(cloth and "IGUI_TraditionalPreservationDairy_StrainCloth" or "IGUI_TraditionalPreservationDairy_StrainHelp",
        UI.itemName(tool)))
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(empties) do
        local itemOption = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_Holds", UI.itemName(item),
            litresText(item:getFluidContainer():getCapacity() * 1000)), playerObj, onKefirAction, station, "strain", item)
        itemOption.itemForTexture = item
    end
end

local function addKefirMenu(menu, playerObj, station, batch)
    local stage = M.stage(batch)
    if stage == "KefirReady" then return addStrainMenu(menu, playerObj, station) end
    addKefirMilkMenu(menu, playerObj, station, batch)
    addGrainsMenu(menu, playerObj, station, batch)
    if stage == "KefirGrains" then
        local take = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_TakeGrains"), playerObj, onKefirAction, station,
            "takeGrains")
        take.iconTexture = getTexture(GRAINS_ICON)
    end
end

local function addIncubatorMenu(context, playerObj, station, summary)
    local batch = TraditionalPreservationDairyWorld.updateIncubator(station, now())
    local option = context:addOption(stationLabel("IGUI_CraftingWindow_YoghurtIncubator", statusText(batch), summary))
    option.iconTexture = getTexture(STATION_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(statusText(batch))
    status.isDisabled = true
    tooltipFor(status, detailText(station, batch))
    local infoOption = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_PotInfo"), playerObj, PotWindow.open, station)
    infoOption.iconTexture = getTexture(STATION_ICON)
    UI.topInfo(context, getText("ContextMenu_TraditionalPreservationDairy_PotInfo"), getTexture(STATION_ICON), playerObj, PotWindow.open, station)

    if batch.culture then return addKefirMenu(menu, playerObj, station, batch) end
    local stage = M.stage(batch)
    if stage == "Ready" then
        addCollectMenu(menu, playerObj, station, batch)
        return addCupMenu(menu, playerObj, station, batch)
    end
    addCauldronPourMenu(menu, playerObj, station, batch)
    addCarriedPourMenu(menu, playerObj, station, batch)
    if stage ~= "Incubating" then addStarterMenu(menu, playerObj, station, batch) end
    if stage == "Cooling" or stage == "TooCold" then addPourOutMenu(menu, playerObj, station, batch) end
    -- Kefir grains go into an empty pot, or milk with no starter cool enough for them; else the entry says why not.
    if stage ~= "Incubating" then addGrainsMenu(menu, playerObj, station, batch) end
end

-- Crock

local function onCrockAction(playerObj, station, mode, item, wheat, fire)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, seed in ipairs(wheat or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, seed) end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(TPStarterCrock:new(playerObj, station, mode, item, wheat, fire))
end

-- Containers holding at least ml of plain milk.
local function milkFor(playerObj, ml)
    return findItems(playerObj, function(item) return M.hasMilk(item, ml) end)
end

local LOAD_REFUSALS = {
    TooLittle = "IGUI_TraditionalPreservationDairy_CrockTooLittle",
    TooCool = "IGUI_TraditionalPreservationDairy_CrockTooCool",
    TooHot = "IGUI_TraditionalPreservationDairy_CrockTooHot",
}

local function refuseLoad(subOption, ml, celsius)
    local refusal = M.crockLoadRefusal(ml, celsius)
    if refusal then refuse(subOption, say(LOAD_REFUSALS[refusal], degrees(celsius))) end
end

-- Wheat and half a litre of milk at 35 to 45 C: one entry for the nearest Stone Hearth within 2 tiles, one per milk
-- container carried. Each shows its litres and heat, in red with the reason when it can't load.
local function addLoadMenu(menu, playerObj, station)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_LoadCrock"))
    option.iconTexture = getTexture(WHEAT_ICON)
    local wheat = findItems(playerObj, function(item) return item:getFullType() == M.WHEAT end)
    if #wheat < M.CROCK_WHEAT then
        return disableWith(option, say("IGUI_TraditionalPreservationDairy_NeedWheat", tostring(M.CROCK_WHEAT), tostring(#wheat)))
    end
    local fire, cauldron = cauldronFor(station, TPStarterCrock.cauldronReady)
    local milks = findItems(playerObj, function(item) return M.milkIn(item:getFluidContainer()) ~= nil end)
    if not cauldron and #milks == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationDairy_CrockNoWarmMilk")) end
    tooltipFor(option, getText("IGUI_TraditionalPreservationDairy_LoadHelp"))
    local picked = firstOf(wheat, M.CROCK_WHEAT)
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    if cauldron then
        local label = getText("ContextMenu_TraditionalPreservationDairy_LoadFromCauldron")
        if M.MILKS[cauldron.fluid] then label = say("ContextMenu_TraditionalPreservationDairy_MilkItem", label, litresText(cauldron.ml), degrees(cauldron.tempC)) end
        local cauldronOption = sub:addOption(label, playerObj, onCrockAction, station, "load", nil, picked, fire)
        cauldronOption.iconTexture = getTexture(CAULDRON_ICON)
        if not fire then
            if M.MILKS[cauldron.fluid] then
                refuseLoad(cauldronOption, cauldron.ml or 0, cauldron.tempC or 0)
            else
                refuse(cauldronOption, getText("IGUI_TraditionalPreservationDairy_CauldronNoMilk"))
            end
        end
    end
    for _, item in ipairs(milks) do
        local ml = M.mlIn(item:getFluidContainer())
        local heat = M.carriedC(item, now(), playerObj)
        local itemOption = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_MilkItem", UI.itemName(item), litresText(ml),
            degrees(heat)), playerObj, onCrockAction, station, "load", item, picked)
        itemOption.itemForTexture = item
        refuseLoad(itemOption, ml, heat)
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
        local itemOption = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_FluidItem", UI.itemName(item),
            litresText(container:getAmount() * 1000)), playerObj, onCrockAction, station, "clabber", item)
        itemOption.itemForTexture = item
        local refusal = M.clabberRefusal(container)
        if refusal then refuse(itemOption, getText(CLABBER_REFUSALS[refusal])) end
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
        local itemOption = sub:addOption(say("ContextMenu_TraditionalPreservationDairy_FluidItem", UI.itemName(item),
            litresText(item:getFluidContainer():getAmount() * 1000)), playerObj, onCrockAction, station, "feed", item)
        itemOption.itemForTexture = item
    end
end

-- What the working crock does next and when, or that it has stalled (stalled: the key for that).
local function crockNext(stage, status, stalled)
    if not status.hoursLeft then return getText(stalled) end
    return say("IGUI_TraditionalPreservationDairy_Next" .. (stage == "Cultivating" and "Waiting" or "Starters"), hoursText(status.hoursLeft))
end

local function crockDetail(station, crock)
    local ledger = M.getLedger()
    local place = crock.place or M.placeOf(station)
    local lines = { UI.placeText(place, M.placeTemperature(ledger, place)) }
    local stage = M.crockStage(crock)
    if stage == "Cultivating" or stage == "Developing" then
        local status = M.crockStatus(crock, ledger, place)
        table.insert(lines, say("IGUI_TraditionalPreservationDairy_CrockProgress", UI.percent(status.progress), UI.percent(status.rate)))
        table.insert(lines, crockNext(stage, status, "IGUI_TraditionalPreservationDairy_CrockStalled"))
    else
        table.insert(lines, getText("IGUI_TraditionalPreservationDairy_CrockHelp" .. stage))
    end
    return table.concat(lines, " <LINE> ")
end

local function addCrockMenu(context, playerObj, station, summary)
    local crock = TraditionalPreservationDairyWorld.updateCrock(station)
    local stage = M.crockStage(crock)
    local option = context:addOption(stationLabel("IGUI_CraftingWindow_StarterCultureCrock",
        getText("IGUI_TraditionalPreservationDairy_Crock" .. stage), summary))
    option.iconTexture = getTexture(CROCK_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(getText("IGUI_TraditionalPreservationDairy_Crock" .. stage))
    status.isDisabled = true
    tooltipFor(status, crockDetail(station, crock))
    local infoOption = menu:addOption(getText("ContextMenu_TraditionalPreservationDairy_CrockInfo"), playerObj, CrockWindow.open, station)
    infoOption.iconTexture = getTexture(CROCK_ICON)
    UI.topInfo(context, getText("ContextMenu_TraditionalPreservationDairy_CrockInfo"), getTexture(CROCK_ICON), playerObj, CrockWindow.open, station)

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

-- Culturing Pot Info on the settled look (art/incubator_mock.png, art/starter_path_mock.png; user, session 69): a band
-- with the pot's state, the Station block, then the starter's slot, an arrow into the milk's tank (its heat as a bar
-- beside it in every state) and, for kefir, an arrow out to the grains that come back; lore beside them; the main
-- actions as buttons, the notes under. A starter or grains dragged onto the slot go in, milk onto the tank pours in;
-- a click on the slot opens its menu, as does a right click; the grains' out slot strains the kefir when it is ready.
local KEY = "IGUI_TraditionalPreservationDairy_"
local POT_STATION_ICON = "media/textures/TPStation_CulturingPot.png"
local STARTER_TEXTURE = "media/textures/Item_ActiveYoghurtStarter.png"
local GRAINS_TEXTURE = "media/textures/Item_KefirGrains.png"
local MILK_COLOUR, YOGHURT_COLOUR, KEFIR_COLOUR = { 0.92, 0.91, 0.86 }, { 0.94, 0.93, 0.82 }, { 0.91, 0.89, 0.8 }
local DIM, NOTE_AMBER, NOTE_RED = { 0.47, 0.47, 0.47 }, InfoWindow.BAND_WAITING[1], { 0.86, 0.35, 0.27 }
local READY_GREEN = { 0.59, 0.82, 0.51 }
-- The heat bar's marks: yogurt's wrap and starter, kefir's limits for the grains; an empty pot shows both cultures'.
local YOGHURT_MARKS = { { M.SET_C, tostring(M.SET_C) }, { M.STARTER_MIN_C, tostring(M.STARTER_MIN_C) } }
local KEFIR_MARKS = { { M.GRAIN_DEAD_C, tostring(M.GRAIN_DEAD_C) }, { M.GRAIN_HUNGRY_C, tostring(M.GRAIN_HUNGRY_C) } }
local BOTH_MARKS = { YOGHURT_MARKS[1], YOGHURT_MARKS[2], KEFIR_MARKS[2] }

PotWindow = InfoWindow:derive("TraditionalPreservationDairyPotWindow")
-- The window's class for the tests (as TraditionalPreservationVinegarUI): its holdings and band read a view alone.
TraditionalPreservationDairyUI = TraditionalPreservationDairyUI or {}
TraditionalPreservationDairyUI.PotWindow = PotWindow

function PotWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = getText("IGUI_CraftingWindow_YoghurtIncubator")
    return o
end

function PotWindow.open(playerObj, station)
    InfoWindow.open(PotWindow, playerObj, station)
end

-- Days since it set, and how long it stays fresh: the jar's own shelf life, which the age carries into.
local function ageText(batch)
    local days = M.ageDays(batch, now())
    local script = ScriptManager.instance:getItem(M.YOGHURT_JAR)
    local fresh = script and script:getDaysFresh() or 0
    local age = days < 1 and getText(KEY .. "InfoToday") or say(KEY .. "InfoDays", tostring(math.floor(days)))
    if days >= fresh then return say(KEY .. "InfoStale", age) end
    return say(KEY .. "InfoAge", age, tostring(math.ceil(fresh - days)))
end

-- What the starter slot takes now: yogurt's starter, grains, or both (the slot then shows them split).
local function startersThatFit(batch)
    if batch.culture then return { grains = M.grainRefusal(batch) == nil } end
    return { yoghurt = (M.canAddStarter(batch)), grains = M.grainRefusal(batch) == nil }
end

-- The grains the pot gives back at ready, as if it finished now with the growth it has had so far.
local function grainsAtReady(batch)
    local out = M.grainsAfter({ readyHour = 1, grains = batch.grains, progress = batch.progress, growProgress = batch.growProgress,
        partGrain = batch.partGrain })
    local count = 0
    for _, n in pairs(out) do count = count + n end
    return count
end

-- The forecast runs the pot ahead step by step, so it is worked out twice a second, not every frame.
function PotWindow:refresh()
    local station, playerObj, window = self.station, self.playerObj, self
    local batch = TraditionalPreservationDairyWorld.updateIncubator(station, now())
    local place = batch.place or M.placeOf(station)
    local placeC = M.placeTemperature(M.getLedger(), place)
    local hours, nextStage = M.forecast(batch, placeC)
    if batch.culture then hours = M.kefirHoursLeft(batch, placeC) end
    self.potView = { batch = batch, stage = M.stage(batch), place = place, placeC = placeC, hours = hours, nextStage = nextStage,
        fits = startersThatFit(batch) }
    self.starterDrop = self.starterDrop or { judge = function(items) return window:judgeStarter(items) end,
        drop = function(take) window:dropStarter(take) end }
    self.milkDrop = self.milkDrop or { judge = function(items) return window:judgeMilk(items) end,
        drop = function(take) window:dropMilk(take) end }
    self.cups = #findItems(playerObj, function(item) return item:getFullType() == M.EMPTY_CUP end)
    self.pour = self:cauldronPour()
end

-- Pour from the Cauldron as a button (user, session 69): the nearest Stone Hearth's cauldron within 2 tiles, while the
-- pot has room and takes milk (not wrapped, set or ready). A yogurt pot takes it scalded, a kefir pot any milk the
-- grains survive. Returns { fire, cauldron, reason } (reason nil when it pours), or nil with no cauldron near.
function PotWindow:cauldronPour()
    local batch, stage = self.potView.batch, self.potView.stage
    if stage == "Incubating" or stage == "Ready" or stage == "KefirReady" then return nil end
    if M.milkRoom(batch, 1) <= 0 then return nil end
    if batch.culture then
        local fire, cauldron = cauldronFor(self.station, function(c) return M.MILKS[c.fluid] ~= nil end)
        if not cauldron then return nil end
        if not fire then return { cauldron = cauldron, reason = getText(KEY .. "CauldronNoMilk") } end
        local refusal = M.kefirMilkRefusal(batch, cauldron.ml or 0, cauldron.tempC or 0)
        return { fire = fire, cauldron = cauldron, reason = refusal and say(REFUSALS[refusal], degrees(cauldron.tempC or 0)) or nil }
    end
    local fire, cauldron = cauldronFor(self.station, M.cauldronScalded)
    if not cauldron then return nil end
    if not fire then return { cauldron = cauldron, reason = cauldronRefusal(cauldron, KEY .. "CauldronNotHot") } end
    return { fire = fire, cauldron = cauldron }
end

-- A starter dragged onto the slot: the first yogurt starter that would take, else every grain item.
function PotWindow:judgeStarter(items)
    local batch, fits = self.potView.batch, self.potView.fits
    local starter, grains = nil, {}
    for _, item in ipairs(items) do
        local fullType = item:getFullType()
        if not starter and M.isStarter(item) then starter = item end
        if fullType == M.GRAIN or fullType == M.DRIED_GRAIN then table.insert(grains, item) end
    end
    if starter and fits.yoghurt then
        return { take = { starter }, lines = { say(KEY .. "SlotAddStarter", UI.itemName(starter)) },
            refused = #items > 1 and getText(KEY .. "SlotOneStarter") or nil }
    end
    if #grains > 0 and fits.grains then
        return { take = grains, lines = { say(KEY .. "SlotAddGrains", tostring(#grains)) },
            refused = #grains < #items and getText(KEY .. "SlotOnlyGrains") or nil }
    end
    local reason
    if starter then
        local _, why = M.canAddStarter(batch)
        reason = why and getText(REFUSALS[why] or KEY .. "SlotTakes")
    elseif #grains > 0 then
        local why = M.grainRefusal(batch)
        reason = why == "TooHot" and say(REFUSALS.TooHot, degrees(batch.tempC)) or getText(REFUSALS[why] or KEY .. "SlotTakes")
    end
    return { take = {}, lines = { reason or getText(KEY .. "SlotTakes") } }
end

function PotWindow:dropStarter(take)
    local first = take[1]
    if not first then return end
    if M.isStarter(first) then return onAction(self.playerObj, self.station, { first }, "starter") end
    onKefirAction(self.playerObj, self.station, "grains", take)
end

-- Milk dragged onto the tank: a kefir pot's by the grains' heat, a yogurt pot's scalded and warm enough for a starter
-- in it; as much as there is room for.
function PotWindow:judgeMilk(items)
    local batch, playerObj = self.potView.batch, self.playerObj
    local room = M.milkRoom(batch, M.CAPACITY_ML)
    local take, poured, refused = {}, 0, nil
    for _, item in ipairs(items) do
        local container = item.getFluidContainer and item:getFluidContainer()
        local fluid, parts = nil, nil
        if container then fluid, parts = M.milkIn(container) end
        local why
        if not fluid then
            why = getText(KEY .. "TankTakes")
        elseif poured >= room then
            local _, reason = M.milkRoom(batch, 1)
            why = getText(REFUSALS[reason or "Full"] or REFUSALS.Full)
        else
            local ml = M.mlIn(container)
            local heat = M.carriedC(item, now(), playerObj)
            local reason
            if batch.culture then
                reason = M.kefirMilkRefusal(batch, ml, heat)
            else
                reason = M.carriedRefusal(M.carryOf(item), ml, parts) or M.coldRefusal(batch, ml, heat)
            end
            if reason then
                why = say(REFUSALS[reason], degrees(heat))
            else
                poured = poured + math.min(ml, room - poured)
                table.insert(take, item)
            end
        end
        if why then refused = refused or why end
    end
    local lines = { #take > 0 and say(KEY .. "TankPour", litresText(poured), tostring(#take)) or refused or getText(KEY .. "TankTakes") }
    return { take = take, lines = lines, refused = #take < #items and refused or nil, adds = poured / M.CAPACITY_ML }
end

function PotWindow:dropMilk(take)
    if self.potView.batch.culture then
        for _, item in ipairs(take) do onKefirAction(self.playerObj, self.station, "milk", item) end
        return
    end
    onAction(self.playerObj, self.station, take, "carried")
end

-- A menu at the mouse filled by fill(context): the slot's click and right click, the buttons' lists.
function PotWindow:menuAt(fill, x, y)
    local context = ISContextMenu.get(self.playerObj:getPlayerNum(), x or getMouseX(), y or getMouseY())
    fill(context)
    if #context.options == 0 then context:setVisible(false) end
end

-- The slot's menu: what the pot takes now, as the right-click menu offers it, and taking grains back out.
function PotWindow:starterMenu(context)
    local playerObj, station, batch, stage = self.playerObj, self.station, self.potView.batch, self.potView.stage
    if not batch.culture and stage ~= "Incubating" and stage ~= "Ready" then addStarterMenu(context, playerObj, station, batch) end
    if stage ~= "Incubating" and stage ~= "Ready" and stage ~= "KefirReady" then addGrainsMenu(context, playerObj, station, batch) end
    if stage == "KefirGrains" then
        local take = context:addOption(getText("ContextMenu_TraditionalPreservationDairy_TakeGrains"), playerObj, onKefirAction, station,
            "takeGrains")
        take.iconTexture = getTexture(GRAINS_ICON)
    end
end

-- The band: the pot's state at a glance, the time to its next change.
local function potBand(potView)
    local batch, stage, hours = potView.batch, potView.stage, potView.hours
    local ml = litresText(batch.ml or 0)
    local B = InfoWindow
    if stage == "Empty" then return "PotBandEmpty", getText(KEY .. "PotBandEmptyText"), B.BAND_IDLE end
    if stage == "KefirGrains" then return "PotBandGrains", getText(KEY .. "PotBandGrainsText"), B.BAND_WAITING end
    if stage == "Fermenting" then
        if not hours then return "PotBandFermenting", getText(KEY .. "PotBandStalledText"), B.BAND_WAITING end
        return "PotBandFermenting", say(KEY .. "PotBandFermentingText", UI.shortDuration(hours)), B.BAND_WORKING
    end
    if stage == "KefirReady" then return "PotBandKefirReady", say(KEY .. "PotBandKefirReadyText", ml), B.BAND_WAITING end
    if stage == "Ready" then return "PotBandSet", say(KEY .. "PotBandSetText", ml, tostring(glassJars(batch.ml))), B.BAND_WORKING end
    if stage == "TooCold" then return "PotBandTooCold", getText(KEY .. "PotBandTooColdText"), B.BAND_AT_RISK end
    if stage == "Incubating" then
        if not hours then return "PotBandSetting", getText(KEY .. "PotBandNeverText"), B.BAND_WAITING end
        return "PotBandSetting", say(KEY .. "PotBandSettingText", UI.shortDuration(hours)), B.BAND_WORKING
    end
    if not batch.starter then return "PotBandCooling", getText(KEY .. "PotBandNoStarterText"), B.BAND_WAITING end
    if not hours then return "PotBandCooling", getText(KEY .. "PotBandHoldsText"), B.BAND_WAITING end
    return "PotBandCooling", say(KEY .. "PotBandCoolingText", UI.shortDuration(hours)), B.BAND_WORKING
end

-- The Station block's own rows: the working rate while it works, a set pot's age.
local function potRows(potView)
    local batch, stage = potView.batch, potView.stage
    if stage == "Incubating" then return { { KEY .. "InfoRate", UI.percent(M.setRate(batch.tempC)) } } end
    if stage == "Fermenting" then return { { KEY .. "InfoRate", UI.percent(M.kefirRate(potView.placeC) * M.kefirRatio(batch)) } } end
    if stage == "Ready" then return { { KEY .. "InfoAgeLabel", ageText(batch) } } end
    return {}
end

-- The starter's slot: what goes in, greyed while it waits for one, "used" once yogurt's has gone into the set.
function PotWindow:starterSlot()
    local potView, window = self.potView, self
    local batch, stage, fits = potView.batch, potView.stage, potView.fits
    local slot = { kind = "slot", arrow = "", drop = self.starterDrop, click = function() window:menuAt(function(c) window:starterMenu(c) end) end,
        menu = function(context) window:starterMenu(context) end }
    local grains = M.grainCount(batch)
    if grains > 0 then
        slot.look, slot.icons, slot.count = "in", { GRAINS_TEXTURE }, tostring(grains)
        slot.name = getText(KEY .. "SlotGrains")
        if (batch.ml or 0) > 0 then slot.amount = say(KEY .. "SlotGrainsFor", tostring(M.grainsFor(batch.ml))) end
        return slot
    end
    slot.look = "empty"
    -- Yogurt's starter is used once the wrap goes on: the slot clears (user).
    if stage == "Incubating" or stage == "Ready" then
        slot.icons, slot.name, slot.nameColour, slot.arrowColour = { STARTER_TEXTURE }, getText(KEY .. "SlotUsed"), InfoWindow.NOTE_COLOUR, DIM
        return slot
    end
    if batch.starter then
        slot.look, slot.icons, slot.name = "in", { STARTER_TEXTURE }, getText(KEY .. "SlotStarter")
        return slot
    end
    slot.icons = {}
    if fits.yoghurt then table.insert(slot.icons, STARTER_TEXTURE) end
    if fits.grains then table.insert(slot.icons, GRAINS_TEXTURE) end
    slot.name, slot.nameColour, slot.arrowColour = getText(KEY .. "SlotAdd"), DIM, DIM
    return slot
end

-- The pot's milk: named by what it is, its heat beside it, at work while it sets or ferments.
function PotWindow:milkTank()
    local potView = self.potView
    local batch, stage, hours = potView.batch, potView.stage, potView.hours
    local ml = batch.ml or 0
    local tank = { kind = "tank", share = ml / M.CAPACITY_ML, drop = self.milkDrop,
        amount = say(KEY .. "TankAmount", litresText(ml), litresText(M.CAPACITY_ML)) }
    local marks = batch.culture and KEFIR_MARKS or (stage == "Empty" and BOTH_MARKS or YOGHURT_MARKS)
    tank.heat = { celsius = ml > 0 and batch.tempC or nil, marks = marks }
    local left = hours and UI.shortDuration(hours) or getText("IGUI_TraditionalPreservationCore_Paused")
    if stage == "Empty" or stage == "KefirGrains" then
        tank.name, tank.colour = getText(KEY .. "TankEmpty"), MILK_COLOUR
    elseif stage == "Fermenting" then
        tank.name, tank.colour = getText(KEY .. "TankFermenting"), KEFIR_COLOUR
        tank.state = say(KEY .. "TankWorkState", UI.percent(batch.progress or 0), left)
        tank.working = { speed = hours and 1 or 0, foam = 0 }
        if not hours then tank.stateColour = NOTE_AMBER end
    elseif stage == "KefirReady" then
        tank.name, tank.colour, tank.state = getText(KEY .. "TankKefir"), KEFIR_COLOUR, getText(KEY .. "TankKefirReady")
    elseif stage == "Ready" then
        tank.name, tank.colour, tank.state = getText(KEY .. "TankYoghurt"), YOGHURT_COLOUR, getText(KEY .. "TankSet")
    elseif stage == "Incubating" then
        local share = math.min((batch.workHours or 0) / M.INCUBATE_HOURS, 1)
        tank.name, tank.colour = getText(KEY .. "TankSetting"), YOGHURT_COLOUR
        tank.state = say(KEY .. "TankWorkState", UI.percent(share), left)
        tank.working = { speed = hours and M.setRate(batch.tempC) or 0, foam = 0 }
        if not hours then tank.stateColour = NOTE_AMBER end
    else
        tank.name, tank.colour = getText(KEY .. "TankMilk"), MILK_COLOUR
        if stage == "TooCold" then
            tank.state, tank.stateColour = getText(KEY .. "TankTooCold"), NOTE_RED
        elseif batch.starter and hours then
            tank.state = say(KEY .. "TankToWrap", UI.shortDuration(hours))
        else
            tank.state = getText(KEY .. "TankLidOn")
        end
    end
    return tank
end

-- What the pot holds: the starter's slot, the milk, and for kefir the grains that come back.
function PotWindow:holdings()
    local potView, window = self.potView, self
    local batch, stage = potView.batch, potView.stage
    local holdings = { self:starterSlot(), self:milkTank() }
    if batch.culture and M.grainCount(batch) > 0 then
        local ready = stage == "KefirReady"
        holdings[2].arrow = ""
        holdings[2].arrowColour = ready and READY_GREEN or DIM
        local back = { kind = "slot", icons = { GRAINS_TEXTURE }, look = ready and "ready" or "pending" }
        if stage == "KefirGrains" then
            back.count, back.name = tostring(M.grainCount(batch)), getText(KEY .. "SlotBack")
        else
            back.count = tostring(grainsAtReady(batch))
            back.name = getText(ready and KEY .. "SlotStrain" or KEY .. "SlotAtReady")
            if ready then
                back.nameColour = READY_GREEN
                back.click = function() window:menuAt(function(c) addStrainMenu(c, window.playerObj, window.station) end) end
                back.menu = function(context) addStrainMenu(context, window.playerObj, window.station) end
            end
        end
        if not ready then back.nameColour = InfoWindow.NOTE_COLOUR end
        table.insert(holdings, back)
    end
    return holdings
end

-- The main actions by state: Fill Jars and Fill Cups once set, Pour Out while it cools, Strain Kefir once ready. Each
-- opens its list under the button, as the right-click's submenu.
function PotWindow:potButtons(y)
    local potView, window = self.potView, self
    local batch, stage = potView.batch, potView.stage
    local playerObj, station = self.playerObj, self.station
    local function under(fill)
        return function(button)
            window:menuAt(fill, window:getAbsoluteX() + button.x, window:getAbsoluteY() + button.y + button.height)
        end
    end
    local buttons = {}
    local pour = self.pour
    if pour then
        local cauldron = pour.cauldron
        table.insert(buttons, { title = getText("ContextMenu_TraditionalPreservationDairy_PourFromCauldron"), icon = CAULDRON_ICON,
            enabled = pour.reason == nil,
            tooltip = pour.reason or (M.MILKS[cauldron.fluid] and say(KEY .. "ButtonPourCauldron", litresText(cauldron.ml or 0),
                degrees(cauldron.tempC or 0))) or nil,
            onClick = function()
                if pour.reason then return end
                if batch.culture then return onKefirAction(playerObj, station, "fire", pour.fire) end
                onCauldronPour(playerObj, station, pour.fire)
            end })
    end
    if stage == "Ready" then
        table.insert(buttons, { title = say(KEY .. "ButtonFillJars", tostring(glassJars(batch.ml))), icon = JAR_ICON, enabled = true,
            onClick = under(function(c) addCollectMenu(c, playerObj, station, batch) end) })
        table.insert(buttons, { title = say(KEY .. "ButtonFillCups", tostring(M.cupsInPot(batch))), icon = YOGHURT_ICON,
            enabled = self.cups > 0, tooltip = self.cups == 0 and getText(KEY .. "NoEmptyCup") or nil,
            onClick = under(function(c) addCupMenu(c, playerObj, station, batch) end) })
    elseif stage == "Cooling" or stage == "TooCold" then
        table.insert(buttons, { title = getText("ContextMenu_TraditionalPreservationDairy_PourOut"), icon = BUCKET_ICON, enabled = true,
            onClick = under(function(c) addPourOutMenu(c, playerObj, station, batch) end) })
    elseif stage == "KefirReady" then
        table.insert(buttons, { title = getText("ContextMenu_TraditionalPreservationDairy_StrainKefir"), icon = STRAINER_ICON, enabled = true,
            onClick = under(function(c) addStrainMenu(c, playerObj, station) end) })
    end
    return self:buttonRow(y, buttons)
end

-- The notes: what the pot waits on, else that the times assume the place's temperature holds.
local function potNotes(potView)
    local batch, stage = potView.batch, potView.stage
    local notes = {}
    if stage == "KefirGrains" then table.insert(notes, getText(KEY .. "HelpKefirGrains")) end
    if stage == "KefirReady" then table.insert(notes, getText(KEY .. "HelpKefirReady")) end
    if stage == "Fermenting" then table.insert(notes, getText(potView.hours and KEY .. "InfoAssumes" or stalledKey(batch))) end
    if WAITING_NOTES[stage] then
        table.insert(notes, getText(WAITING_NOTES[stage]))
    elseif stage == "Cooling" and not batch.starter then
        table.insert(notes, getText(KEY .. "NoStarter"))
    elseif stage == "Incubating" and not potView.hours then
        table.insert(notes, getText(KEY .. "NeverSets"))
    elseif (stage == "Cooling" or stage == "Incubating") and potView.hours then
        table.insert(notes, getText(KEY .. "InfoAssumes"))
    elseif stage == "Ready" then
        table.insert(notes, say(KEY .. "Jars", tostring(glassJars(batch.ml)), tostring(clayJars(batch.ml)), tostring(M.cupsInPot(batch))))
    end
    if stage ~= "Incubating" and stage ~= "Ready" and stage ~= "KefirReady" then table.insert(notes, getText(KEY .. "PotNoteDrag")) end
    return notes
end

function PotWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.potView then return end
    local potView = self.potView
    local word, text, look = potBand(potView)
    local y = self:band(getText(KEY .. word), text, look[1], look[2])
    y = self:stationBlock(y, POT_STATION_ICON, potView.place, potView.placeC, potRows(potView))
    y = self:section(y, "IGUI_TraditionalPreservationCore_SectionHolds")
    y = self:holds(y, self:holdings(), getText(potView.batch.culture and KEY .. "KefirLore" or KEY .. "YoghurtLore"))
    y = self:potButtons(y)
    self:drawNotes(y, potNotes(potView))
end

-- Stone Hearth Info (TP Core's) says what the cauldron's milk is for.
CauldronUI.addNotes(function(fireView, notes)
    local ml = fireView.part.ml or 0
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_CauldronHelpEmpty"))
    elseif not M.MILKS[fireView.part.fluid] then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_CauldronHelpWater"))
    end
end)

local BAR_COLOURS = { culture = { 0.7, 0.62, 0.35 } }

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
    local station = self.station
    local crock = TraditionalPreservationDairyWorld.updateCrock(station)
    local place = crock.place or M.placeOf(station)
    self.crockView = { crock = crock, stage = M.crockStage(crock), status = M.crockStatus(crock, M.getLedger(), place) }
end

function CrockWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.crockView then return end
    local crockView = self.crockView
    local stage, status = crockView.stage, crockView.status
    local working = stage == "Cultivating" or stage == "Developing"
    local y = self:top()

    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoStage", getText("IGUI_TraditionalPreservationDairy_Crock" .. stage))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoPlace", UI.placeText(status.place, status.temperature))
    y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoCultureHeat", getText("IGUI_TraditionalPreservationDairy_InfoCultureHeatValue"))
    if working then
        y = self:bar(y, "IGUI_TraditionalPreservationDairy_InfoProgress", status.progress, BAR_COLOURS.culture, UI.percent(status.progress))
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoCultureSpeed", UI.percent(status.rate))
        y = self:row(y, "IGUI_TraditionalPreservationDairy_InfoNext", crockNext(stage, status, "IGUI_TraditionalPreservationDairy_InfoStopped"))
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

-- Clicking a pot opens Incubator Info, and clicking a crock Crock Info, as clicking a door opens it (a Stone Hearth's click
-- is TP Core's).
-- The crock stands on a counter or a table, never on a stove, a fridge or a freezer.
local crockFaces = {}
for face = 0, M.FACE_COUNT - 1 do crockFaces[M.spriteName(M.CROCK_SPRITE + face)] = true end
UI.offAppliances(crockFaces)
-- A pot or crock with anything in it stays where it is: milk, a starter, kefir grains or a culture, its time goes by
-- its place (user, 2026-11-19: no station is moved mid-process; hot milk travels in a Wrapped Clay Pot, an item).
-- Empty, it picks up as any moveable.
UI.keepInPlace(function(isoObject)
    local kind = M.stationKind(isoObject)
    if not kind or not isoObject:hasModData() then return nil end
    local movableData = isoObject:getModData().movableData
    if kind == "crock" then
        local crock = movableData and movableData[M.CROCK_KEY]
        return (crock ~= nil and M.crockStage(crock) ~= "Empty") or nil
    end
    local batch = movableData and movableData[M.INCUBATOR_KEY]
    return (batch ~= nil and (M.stage(batch) ~= "Empty" or batch.starter ~= nil)) or nil
end)
-- No station, the incubator or the crock, is put down in front of a door (TP Core's Doors).
UI.keepDoorsFree(Tiles.STATIONS)

-- Every pot and crock the click took in gets its own menu. With more than one, each is named with its status
-- ("Culturing Pot (Cooling: 2.0 L at 60 C)"), so the player picks the right one.
local function onFillContextMenu(playerNum, context, worldobjects, test)
    local stations, seen = {}, {}
    for _, isoObject in ipairs(worldobjects) do
        if M.stationKind(isoObject) and not seen[isoObject] then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[isoObject] = true
            table.insert(stations, isoObject)
        end
    end
    local playerObj = getSpecificPlayer(playerNum)
    for _, station in ipairs(stations) do
        -- A station built or placed this session isn't tracked until its area reloads, so its menu starts it.
        TraditionalPreservationDairyWorld.track(station)
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
    local jar = UI.firstSelected(items, function(item) return item:getFullType() == M.YOGHURT_JAR end)
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
        local all = context:addOption(say("ContextMenu_TraditionalPreservationDairy_FillAllCups", tostring(most)), playerObj, onFillCups, jar,
            firstOf(empties, most))
        all.iconTexture = getTexture(YOGHURT_ICON)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryMenu)

-- Kefir grains dry on TP Core's Drying Cloth (its own menu lays them). A Kefir Grains on a Cloth from an old save is
-- still collected here once dry: Collect Dried Kefir Grains.
local function onGrainsAction(playerObj, mode, item)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(TPKefirGrains:new(playerObj, mode, item))
end

local function addCollectMenu(context, playerObj, item)
    local drying = M.keepDrying(item, now())
    if not drying then return end
    local option = context:addOption(getText("ContextMenu_TraditionalPreservationDairy_CollectDriedGrains"), playerObj,
        onGrainsAction, "collect", item)
    option.iconTexture = getTexture(GRAINS_ICON)
    if M.isDry(drying) then return end
    local place = drying.dry.place
    local hours = M.dryingHoursLeft(drying, M.placeTemperature(M.getLedger(), place), place)
    disableWith(option, hours and say("IGUI_TraditionalPreservationDairy_DryingLeft", hoursText(hours))
        or getText(place == M.STILL_AIR_PLACE and "IGUI_TraditionalPreservationDairy_DryingShut"
            or "IGUI_TraditionalPreservationDairy_DryingFrozen"))
end

local function onFillGrainsMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    local onCloth = UI.firstSelected(items, function(item) return item:getFullType() == M.GRAIN_DRYING end)
    if onCloth then return addCollectMenu(context, playerObj, onCloth) end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillGrainsMenu)

-- Milk taken off a stove or a fire keeps its heat as a record (vanilla's drops within seconds): read as it is moved,
-- while it is still on the heat.
Transfer.before(function(action, item)
    local from = action.srcContainer
    if item:getFluidContainer() and from and not from:isInCharacterInventory(action.character)
        and from:getTemperature() > 1 then
        M.stampHeat(item, getGameTime():getWorldAgeHours())
    end
end)

-- Butter catches up on its keeping whenever it is looked at or moved (TP Core's PlaceKeepingUI); so do kefir grains on
-- their starving clocks, and grains drying on a cloth.
PlaceKeepingUI.watch(M.BUTTER_KEEPER, M.BUTTER_DAYS)
PlaceKeepingUI.watch({ keep = M.keepGrain }, { [M.GRAIN] = true, [M.GRAIN_DRYING] = true })

-- Every step of clarifying takes Cooking 2.
local function butterRefusal(playerObj)
    if playerObj:getPerkLevel(Perks.Cooking) < M.BUTTER_SKILL then return getText("IGUI_TraditionalPreservationDairy_ButterSkill") end
end

-- Put Butter in the Cauldron on the Stone Hearth's menu (TP Core's CauldronUI.addPieces), and its notes in Stone
-- Hearth Info.
CauldronUI.addPieces({
    title = getText("ContextMenu_TraditionalPreservationDairy_ButterInCauldron"),
    icon = "Item_Butter",
    pieceMl = M.BUTTER_PIECE_ML,
    hoursLeft = M.butterHoursLeft,
    fluidRows = { { fluid = M.MELTING_BUTTER, items = M.CAULDRON_BUTTERS, label = function(count)
        return getText("ContextMenu_TraditionalPreservationDairy_ButterPieces", tostring(count))
    end } },
    help = getText("IGUI_TraditionalPreservationDairy_ButterHelp"),
    noRoom = getText("IGUI_TraditionalPreservationDairy_ButterNoRoom"),
    refusal = butterRefusal,
})

-- Put Butter in a Pot on a butter's right-click menu (TP Core's ItemFluidUI.addPieces): a pot or saucepan, the
-- cauldron's route at a smaller size.
ItemFluidUI.addPieces({
    title = getText("ContextMenu_TraditionalPreservationDairy_ButterInPot"),
    icon = "Item_Butter",
    items = M.CAULDRON_BUTTERS,
    fluid = M.MELTING_BUTTER,
    pieceMl = M.BUTTER_PIECE_ML,
    hoursLeft = M.butterHoursLeft,
    vessels = M.BUTTER_VESSELS,
    label = function(pot, count)
        return getText("ContextMenu_TraditionalPreservationDairy_ButterPotRow", pot:getDisplayName(), tostring(count))
    end,
    help = getText("IGUI_TraditionalPreservationDairy_ButterPotHelp"),
    noRoom = getText("IGUI_TraditionalPreservationDairy_ButterPotNoRoom"),
    noVessel = getText("IGUI_TraditionalPreservationDairy_ButterNoPot"),
    refusal = butterRefusal,
})

CauldronUI.addNotes(function(fireView, notes)
    local cauldron = fireView.part
    if (cauldron.ml or 0) <= 0 then return end
    if cauldron.fluid == M.RANCID_BUTTER then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_ButterRancid"))
    elseif cauldron.fluid == M.MELTED_CLARIFIED then
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_ButterMelted"))
    elseif cauldron.fluid == M.MELTING_BUTTER then
        local now = getGameTime():getWorldAgeHours()
        table.insert(notes, getText("IGUI_TraditionalPreservationDairy_ButterMelting",
            UI.hoursText(CauldronFluid.hoursToTurn(cauldron) or 0), UI.hoursText(math.max((cauldron.offAt or now) - now, 0))))
    end
end)

