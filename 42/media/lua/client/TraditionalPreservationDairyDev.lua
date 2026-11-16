-- Traditional Preservation (Dairy): commands for the debug Lua console, loaded only in debug mode.
-- Type TPD.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

local M = TraditionalPreservationDairy
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local PlaceKeepingUI = require "TraditionalPreservationCore/PlaceKeepingUI"
TPD = {}

local function say(text) print("[TPD] " .. text) end

function TPD.help()
    say("TPD.weather()        the temperature by place, and how fast milk sets there")
    say("TPD.here()           which place you're standing in (open air, an open roof, indoors, a basement or by a fire)")
    say("TPD.pots()           every loaded incubator: stage, litres, milk temperature, what's next")
    say("TPD.age(hours)       move every loaded incubator and crock on by this many hours (default 1; a crock's at the best temperature)")
    say("TPD.fast(hours)      setting takes this many hours at the best temperature. TPD.fast() goes back to the sandbox")
    say("TPD.milk(litres, c, fluid) a cooking pot of milk (default 5 L of CowMilk), at c degrees if given; fluid SheepMilk or AnimalMilk for the others, or a kefir (CowKefir, SheepKefir: both read Kefir (Fresh))")
    say("TPD.give(name, n, option) spawn n of: jar (a full Jar of Yogurt; option \"clay\" or \"glazed\"), starter, cup (an Empty Yogurt Container), butter, salted, clarified, packet (of kefir grains), dried, grains (live kefir grains), cloth (10 grains drying on a Ripped Sheet). TPD.give() lists them")
    say("TPD.kit(kind)        the things a test of kind needs; TPD.kit() for yogurt, TPD.kit(\"?\") lists the kinds")
    say("TPD.crocks()         every loaded crock: stage, progress, place")
    say("TPD.ages()           every container of milk you carry: fluid, stage, age, hours to the next stage, place")
    say("TPD.sour(hours)      age the milk and kefir you carry by this many hours at 20 C (milk sours at 36, spoils at 72; kefir separates at 72, rots at 240)")
    say("TPD.butter()         every butter you carry or within 4 tiles (a fridge, a freezer): place, rate, age, days to stale and rotten there")
    say("TPD.rancid(days)     age that butter by this many days at its place (default 10)")
    say("TPD.grains()         kefir grains and grains drying on a cloth, carried or within 4 tiles: state, hours starved, place, drying left")
    say("TPD.starve(hours)    those grains starve this many hours at 20 C (default 48: Hungry; 168 dead), and the cloths dry this many hours at full speed")
    say("TPD.tiles()          every station within 3 tiles: object class, sprite and square solid flags")
    say("The Stone Hearth's commands (cauldronInfo, stone, cauldron, fuel, hot, its kit) are TP Core's: TPC.help()")
end

function TPD.weather()
    local ledger = M.getLedger()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C. Setting takes %.1f hours at its best.",
        ledger.temperature or 0, ledger.seasonTemperature or 0, M.INCUBATE_HOURS))
    for _, place in ipairs(M.PLACES) do
        local celsius = M.placeTemperature(ledger, place)
        say(string.format("%-9s %.1f C: milk at that heat sets at %.0f%%", place, celsius, M.setRate(celsius) * 100))
    end
end

function TPD.here()
    say("You're in: " .. tostring(M.placeOf(getPlayer())))
end

local function pots()
    return TraditionalPreservationDairyWorld.stations()
end

function TPD.pots()
    local now = getGameTime():getWorldAgeHours()
    local stations = pots()
    if #stations == 0 then return say("No incubator loaded and tracked. Right-click one to start tracking it.") end
    for _, station in ipairs(stations) do
        local batch = TraditionalPreservationDairyWorld.updateIncubator(station, now)
        local placeC = M.placeTemperature(M.getLedger(), batch.place)
        if batch.culture then
            local left = M.kefirHoursLeft(batch, placeC)
            local count, work = M.grainCount(batch)
            say(string.format("%d,%d,%d %s: %.1f L at %.1f C, %d grains (%.1f at work, %.0f%% speed), fermented %.0f%%, %s at %.1f C; ready in %s h",
                station:getX(), station:getY(), station:getZ(), M.stage(batch), (batch.ml or 0) / 1000, batch.tempC or 0, count, work,
                M.kefirRatio(batch) * 100, (batch.progress or 0) * 100, tostring(batch.place), placeC, left and string.format("%.1f", left) or "never"))
        else
            local hours, nextStage = M.forecast(batch, placeC)
            say(string.format("%d,%d,%d %s: %.1f L at %.1f C, starter %s, set %.1f/%.0f h, %s at %.1f C; next %s in %s h",
                station:getX(), station:getY(), station:getZ(), M.stage(batch), (batch.ml or 0) / 1000, batch.tempC or 0,
                tostring(batch.starter), batch.workHours or 0, M.INCUBATE_HOURS, tostring(batch.place), placeC,
                tostring(nextStage), hours and string.format("%.1f", hours) or "never"))
        end
    end
end

-- The pot's clock is set back, so the next look runs those hours again from the recorded weather. Hours
-- before the history began count at the place's temperature now.
-- A kefir pot ferments on the ledger, which can't be set back: its work is added straight (M.ageKefir), at its place now.
local function agePots(hours)
    local now = getGameTime():getWorldAgeHours()
    for _, station in ipairs(pots()) do
        local batch = TraditionalPreservationDairyWorld.updateIncubator(station, now)
        if batch.culture then
            M.ageKefir(batch, hours, M.placeTemperature(M.getLedger(), batch.place), now)
        elseif batch.readyHour then
            batch.readyHour = batch.readyHour - hours
        end
        if batch.lastHour then batch.lastHour = batch.lastHour - hours end
        TraditionalPreservationDairyWorld.refresh(station)
    end
    say(string.format("Moved %d incubator(s) on by %.1f hours.", #pots(), hours))
end

function TPD.fast(hours)
    if not hours then
        M.applySandbox()
        return say(string.format("Back to the sandbox time: %.1f hours to set.", M.INCUBATE_HOURS))
    end
    M.INCUBATE_HOURS = hours
    say(string.format("Test timer on: milk sets in %s hours at the best temperature.", tostring(hours)))
end

function TPD.milk(litres, celsius, fluid)
    if fluid and not M.MILKS[fluid] and not M.SEPARATED_KEFIRS[fluid] then
        return say("Milks: CowMilk, SheepMilk, AnimalMilk; kefirs: CowKefir, SheepKefir")
    end
    local pot = getPlayer():getInventory():AddItem("Base.Pot")
    local container = pot:getFluidContainer()
    container:Empty()
    container:addFluid(fluid or "CowMilk", math.min(litres or 5, container:getCapacity()))
    if celsius then pot:setItemHeat(M.itemHeat(celsius)) end
    -- A pot given at the steam counts as having had its hold, so it scalds at the next look.
    if celsius and celsius >= M.HOT_C then pot:getModData()[FluidAgeing.HELD_KEY] = { hours = M.SCALD_HOLD_HOURS } end
    say(string.format("Gave a pot of %.1f L of %s%s.", container:getAmount(), fluid or "CowMilk", celsius and string.format(" at %.0f C", celsius) or ""))
end

-- The other things a test wants, by name. A jar is full, new, of cow's milk yogurt, in glass unless option says
-- "clay" or "glazed".
local JAR_TYPES = { clay = "Base.ClayJar", glazed = "Base.ClayJarGlazed" }
local GIVES = {
    jar = function(inventory, option)
        local jarType = JAR_TYPES[option] or "Base.EmptyJar"
        M.fillJar(inventory:AddItem(M.YOGHURT_JAR), jarType, M.JAR_ML[jarType], 0,
            M.portionFood({ fluid = "CowMilk", ml = M.CUP_ML }))
    end,
    starter = function(inventory) inventory:AddItem(M.STARTER) end,
    cup = function(inventory) inventory:AddItem(M.EMPTY_CUP) end,
    butter = function(inventory) inventory:AddItem(M.BUTTER) end,
    salted = function(inventory) inventory:AddItem(M.SALTED_BUTTER) end,
    clarified = function(inventory) inventory:AddItem(M.CLARIFIED_BUTTER) end,
    packet = function(inventory) inventory:AddItem(M.GRAIN_PACKET) end,
    dried = function(inventory) inventory:AddItem(M.DRIED_GRAIN) end,
    grains = function(inventory) M.keepGrain(inventory:AddItem(M.GRAIN), getGameTime():getWorldAgeHours()) end,
    -- A Ripped Sheet of 10 grains, set drying now.
    cloth = function(inventory)
        local item, now = inventory:AddItem(M.GRAIN_DRYING), getGameTime():getWorldAgeHours()
        item:getModData()[M.DRYING_KEY] = M.newDrying(10, "Base.RippedSheets", M.getLedger(), now,
            FluidAgeing.placeOfItem(item) or FluidAgeing.DEFAULT_PLACE)
        M.keepDrying(item, now)
    end,
}

function TPD.give(name, count, option)
    if not GIVES[name] then return say("Things: jar (option \"clay\" or \"glazed\"), starter, cup, butter, salted, clarified, packet, dried, grains, cloth") end
    local inventory = getPlayer():getInventory()
    for _ = 1, count or 1 do GIVES[name](inventory, option) end
    say(string.format("Gave %d %s%s.", count or 1, name, option and (" (" .. option .. ")") or ""))
end

-- One kit per kind of test, so each new dairy (kefir, emmental-style, brined cheese) adds an entry here.
local KITS = {
    yogurt = {
        about = "a yogurt for a starter, a Clay Jar, a glass jar and four empty yogurt containers",
        give = function(inventory)
            inventory:AddItem(M.YOGHURT)
            inventory:AddItem("Base.ClayJar")
            inventory:AddItem("Base.EmptyJar")
            for _ = 1, 4 do inventory:AddItem(M.EMPTY_CUP) end
        end,
    },
    crock = {
        about = string.format("%d wheat grains; warm the cauldron with TPC.cauldron(1, 40) by a Stone Hearth (Cauldron)", M.CROCK_WHEAT),
        give = function(inventory)
            for _ = 1, M.CROCK_WHEAT do inventory:AddItem(M.WHEAT) end
        end,
    },
    butter = {
        about = "nine Butter, a Salt, a cooking pot, a saucepan, a Ripped Sheet to strain through and a burnt pot to scrape out: salt one, clarify six in the pot and two in the saucepan (Cooking 2); TPC.kit() for the cauldron",
        give = function(inventory)
            for _ = 1, 9 do inventory:AddItem(M.BUTTER) end
            inventory:AddItem("Base.Salt")
            inventory:AddItem("Base.Pot")
            inventory:AddItem("Base.Saucepan")
            inventory:AddItem("Base.RippedSheets")
            inventory:AddItem(M.BURNT_BUTTER["Base.Pot"]):setBurnt(true)
        end,
    },
    kefir = {
        about = "a Packet of Kefir Grains, 25 live Kefir Grains, a pot of 2 L of cow's milk kefir, a pot of 1 L of cow's milk (25 grains are the full ratio for it: 24 h in the incubator at 18-25 C), a Strainer and a Ripped Sheet",
        give = function(inventory)
            inventory:AddItem(M.GRAIN_PACKET)
            for _ = 1, M.grainsFor(1000) do GIVES.grains(inventory) end
            for _, fill in ipairs({ { "CowKefir", 2 }, { "CowMilk", 1 } }) do
                local pot = inventory:AddItem("Base.Pot")
                pot:getFluidContainer():Empty()
                pot:getFluidContainer():addFluid(fill[1], fill[2])
            end
            inventory:AddItem(M.STRAINER)
            inventory:AddItem("Base.RippedSheets")
        end,
    },
    wrap = {
        about = "a Yogurt Pot, a Sheet and Twine, to make a Wrapped Yogurt Pot",
        give = function(inventory)
            inventory:AddItem("TraditionalPreservationDairy.YoghurtPot")
            inventory:AddItem("Base.Sheet")
            inventory:AddItem("Base.Twine")
        end,
    },
}

function TPD.kit(kind)
    local kit = KITS[kind or "yogurt"]
    if not kit then
        local names = {}
        for name in pairs(KITS) do table.insert(names, name) end
        table.sort(names)
        for _, name in ipairs(names) do say(string.format("TPD.kit(\"%s\"): %s", name, KITS[name].about)) end
        return
    end
    kit.give(getPlayer():getInventory())
    say("Gave " .. kit.about .. ".")
end

local function crocks()
    return TraditionalPreservationDairyWorld.stations(true)
end

function TPD.crocks()
    local stations = crocks()
    if #stations == 0 then return say("No crock loaded and tracked. Right-click one to start tracking it.") end
    for _, station in ipairs(stations) do
        local crock = TraditionalPreservationDairyWorld.updateCrock(station)
        local line = string.format("%d,%d,%d %s, %s", station:getX(), station:getY(), station:getZ(), M.crockStage(crock), tostring(crock.place))
        if crock.workHours then
            local status = M.crockStatus(crock, M.getLedger(), crock.place)
            line = line .. string.format(": %.1f/%.0f h at %.0f%% speed, %s h left", crock.workHours, M.crockHours(crock), status.rate * 100,
                status.hoursLeft and string.format("%.1f", status.hoursLeft) or "never")
        end
        say(line)
    end
end

local function ageCrocks(hours)
    for _, station in ipairs(crocks()) do
        local crock = TraditionalPreservationDairyWorld.crockOf(station)
        if crock.workHours then crock.workHours = crock.workHours + hours end
        TraditionalPreservationDairyWorld.refresh(station)
    end
    say(string.format("Moved %d crock(s) on by %.1f hours.", #crocks(), hours))
end

-- Every loaded station on by this many hours: an incubator runs them again from the recorded weather, a crock's
-- stage takes them as hours at the best temperature.
function TPD.age(hours)
    hours = hours or 1
    agePots(hours)
    ageCrocks(hours)
    TPD.pots()
    TPD.crocks()
end

-- Every milk container in the player's inventory, brought up to now.
local function carriedMilk()
    local now, carried = getGameTime():getWorldAgeHours(), {}
    local items = getPlayer():getInventory():getAllEvalRecurse(function(item) return item:getFluidContainer() ~= nil end)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fluidAge, fluidKind = FluidAgeing.look(item, now)
        if fluidAge or FluidAgeing.fluidKindIn(item:getFluidContainer()) then table.insert(carried, { item = item, fluidAge = fluidAge, fluidKind = fluidKind }) end
    end
    return carried
end

function TPD.ages()
    local carried = carriedMilk()
    if #carried == 0 then return say("You carry no milk or kefir.") end
    for _, milk in ipairs(carried) do
        local item, fluidAge, fluidKind = milk.item, milk.fluidAge, milk.fluidKind
        local fluid = item:getFluidContainer():getPrimaryFluid()
        if not fluidAge then
            say(string.format("%s: %s, no age (sealed store milk, or milk going off is switched off)", item:getDisplayName(),
                fluid and fluid:getFluidTypeString() or "?"))
        else
            local left = FluidAgeing.hoursLeft(fluidAge, fluidKind)
            say(string.format("%s: %s, %s%s, age %.1f h at 20 C, next stage in %s h at 20 C, %s", item:getDisplayName(),
                fluid and fluid:getFluidTypeString() or "?", FluidAgeing.stage(fluidAge, fluidKind), FluidAgeing.inState(fluidAge, M.SCALDED_STATE) and " (scalded)" or "",
                fluidAge.age, left and string.format("%.1f", left) or "never", tostring(fluidAge.place)))
        end
    end
end

function TPD.sour(hours)
    hours = hours or M.MILK_TURN_HOURS
    local count = 0
    for _, milk in ipairs(carriedMilk()) do
        if milk.fluidAge then
            milk.fluidAge.age = milk.fluidAge.age + hours
            FluidAgeing.apply(milk.item:getFluidContainer(), milk.fluidAge, milk.fluidKind)
            count = count + 1
        end
    end
    say(string.format("Aged %d container(s) of milk or kefir by %.1f hours. TPD.ages() to see them.", count, hours))
end

-- What makes a station's tile block: the object's class, its sprite's flags and the square's, within 3 tiles.
local TILES_RADIUS = 3

-- Butter

-- Butter carried, and in containers (a fridge, a freezer, a crate) within TP Core's PlaceKeepingUI.REACH tiles.
local function nearbyButter()
    return PlaceKeepingUI.near(M.BUTTER_DAYS)
end

function TPD.butter()
    if not M.butterByPlace() then say("Butter keeping by place is off in the sandbox.") end
    local butter = nearbyButter()
    if #butter == 0 then return say("No Butter or Salted Butter on you or within " .. PlaceKeepingUI.REACH .. " tiles.") end
    for _, item in ipairs(butter) do say(M.BUTTER_KEEPER.describe(item)) end
end

function TPD.rancid(days)
    days = days or 10
    local butter = nearbyButter()
    for _, item in ipairs(butter) do M.BUTTER_KEEPER.age(item, days) end
    say(string.format("Kept %d butter for %d days at their places. TPD.butter() to see them.", #butter, days))
end

-- Kefir grains

local GRAIN_TYPES = { [M.GRAIN] = true, [M.GRAIN_DRYING] = true }

function TPD.grains()
    local found = PlaceKeepingUI.near(GRAIN_TYPES)
    if #found == 0 then return say("No Kefir Grains or grains on a cloth on you or within " .. PlaceKeepingUI.REACH .. " tiles.") end
    local now, ledger = getGameTime():getWorldAgeHours(), M.getLedger()
    for _, item in ipairs(found) do
        if item:getFullType() == M.GRAIN then
            local grain = M.keepGrain(item, now)
            local clock = grain.clock
            say(string.format("%s: %s, starved %.1f h at 20 C (Hungry at %d, dead at %d), in %s", item:getDisplayName(),
                grain.grainState, clock and clock.starve.age or 0, M.GRAIN_HUNGRY_HOURS, M.GRAIN_DEAD_HOURS,
                tostring(clock and clock.starve.place)))
        else
            local drying = M.keepDrying(item, now)
            if drying then
                local left = M.dryingHoursLeft(drying, M.placeTemperature(ledger, drying.dry.place))
                say(string.format("%s: %d grains, dried %.1f of %d h, %s h left in %s", item:getDisplayName(), drying.count,
                    drying.dry.age, M.GRAIN_DRY_HOURS, left and string.format("%.1f", left) or "never", tostring(drying.dry.place)))
            end
        end
    end
end

function TPD.starve(hours)
    hours = hours or M.GRAIN_HUNGRY_HOURS
    local found, now = PlaceKeepingUI.near(GRAIN_TYPES), getGameTime():getWorldAgeHours()
    for _, item in ipairs(found) do
        if item:getFullType() == M.GRAIN then
            local grain = M.keepGrain(item, now)
            if grain.clock then
                grain.clock.starve.age = grain.clock.starve.age + hours
                M.keepGrain(item, now)
            end
        else
            local drying = M.keepDrying(item, now)
            if drying then
                drying.dry.age = drying.dry.age + hours
                M.keepDrying(item, now)
            end
        end
    end
    say(string.format("Starved or dried %d item(s) by %.1f hours. TPD.grains() to see them.", #found, hours))
end

function TPD.tiles()
    local stations = Station.near(getPlayer():getSquare(), TILES_RADIUS, function(isoObject)
        return M.isIncubator(isoObject) or M.isCrock(isoObject) or M.hasCauldron(isoObject)
    end)
    for _, station in ipairs(stations) do
        local square = station:getSquare()
        local props, squareProps = station:getSprite():getProperties(), square:getProperties()
        local attached = station:getAttachedAnimSprite()
        local blocks = instanceof(station, "IsoThumpable") and string.format(" blockAll %s passThrough %s",
            tostring(station:isBlockAllTheSquare()), tostring(station:isCanPassThrough())) or ""
        say(string.format("%d,%d %s%s %s: sprite solid %s solidtrans %s; square solid %s solidtrans %s; attached %d",
            square:getX(), square:getY(), station:getClass():getSimpleName(), blocks, station:getSprite():getName(),
            tostring(props:has(IsoFlagType.solid)), tostring(props:has(IsoFlagType.solidtrans)),
            tostring(squareProps:has(IsoFlagType.solid)), tostring(squareProps:has(IsoFlagType.solidtrans)),
            attached and attached:size() or 0))
    end
end

say("Debug commands loaded. Type TPD.help() in the Lua console.")
