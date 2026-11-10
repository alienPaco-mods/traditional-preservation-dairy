-- Traditional Preservation (Dairy): commands for the debug Lua console, loaded only in debug mode.
-- Type TPD.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

local M = TraditionalPreservationDairy
TPD = {}

local function say(text) print("[TPD] " .. text) end

function TPD.help()
    say("TPD.weather()        the temperature by place, and how fast milk sets there")
    say("TPD.here()           which place you're standing in (outdoors, under a roof, a basement or by a fire)")
    say("TPD.pots()           every loaded incubator: stage, litres, milk temperature, what's next")
    say("TPD.skip(hours)      move every loaded incubator on by this many hours")
    say("TPD.fast(hours)      setting takes this many hours at the best temperature. TPD.fast() goes back to the sandbox")
    say("TPD.milk(litres, c)  a cooking pot of cow's milk (default 5 L), at c degrees if given")
    say("TPD.kit(kind)        the things a test of kind needs; TPD.kit() for yoghurt, TPD.kit(\"?\") lists the kinds")
    say("TPD.crocks()         every loaded crock: stage, progress, place")
    say("TPD.culture(hours)   move every loaded crock's current stage on by this many hours at the best temperature")
    say("TPD.tiles()          every station within 3 tiles: object class, sprite and square solid flags")
    say("The Hearth's commands (hearth, copper, fuel, hot, a Hearth kit) are TP Core's: TPC.help()")
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
    local World = TraditionalPreservationDairyWorld
    return World and World.stations() or {}
end

function TPD.pots()
    local now = getGameTime():getWorldAgeHours()
    local list = pots()
    if #list == 0 then return say("No incubator loaded and tracked. Right-click one to start tracking it.") end
    for _, station in ipairs(list) do
        local state = TraditionalPreservationDairyWorld.updateIncubator(station, now)
        local placeC = M.placeTemperature(M.getLedger(), state.place)
        local hours, nextStage = M.forecast(state, placeC)
        say(string.format("%d,%d,%d %s: %.1f L at %.1f C, starter %s, set %.1f/%.0f h, %s at %.1f C; next %s in %s h",
            station:getX(), station:getY(), station:getZ(), M.stage(state), (state.ml or 0) / 1000, state.tempC or 0,
            tostring(state.starter), state.done or 0, M.INCUBATE_HOURS, tostring(state.place), placeC,
            tostring(nextStage), hours and string.format("%.1f", hours) or "never"))
    end
end

-- The pot's clock is set back, so the next look runs those hours again from the recorded weather. Hours
-- before the history began count at the place's temperature now.
function TPD.skip(hours)
    hours = hours or 1
    for _, station in ipairs(pots()) do
        local state = TraditionalPreservationDairyWorld.incubatorState(station)
        if state.last then state.last = state.last - hours end
        if state.readyHour then state.readyHour = state.readyHour - hours end
        TraditionalPreservationDairyWorld.refresh(station)
    end
    say(string.format("Moved %d incubator(s) on by %.1f hours.", #pots(), hours))
    TPD.pots()
end

function TPD.fast(hours)
    if not hours then
        M.applySandbox()
        return say(string.format("Back to the sandbox time: %.1f hours to set.", M.INCUBATE_HOURS))
    end
    M.INCUBATE_HOURS = hours
    say(string.format("Test timer on: milk sets in %s hours at the best temperature.", tostring(hours)))
end

function TPD.milk(litres, celsius)
    local pot = getPlayer():getInventory():AddItem("Base.Pot")
    local container = pot:getFluidContainer()
    container:Empty()
    container:addFluid("CowMilk", math.min(litres or 5, container:getCapacity()))
    if celsius then pot:setItemHeat(M.itemHeat(celsius)) end
    say(string.format("Gave a pot of %.1f L of milk%s.", container:getAmount(), celsius and string.format(" at %.0f C", celsius) or ""))
end

-- One kit per kind of test, so each new dairy (kefir, emmental-style, brined cheese) adds an entry here.
local KITS = {
    yoghurt = {
        about = "a yoghurt for a starter, a Clay Jar, a glass jar and four empty yoghurt containers",
        give = function(inventory)
            inventory:AddItem("Base.Yoghurt")
            inventory:AddItem("Base.ClayJar")
            inventory:AddItem("Base.EmptyJar")
            for _ = 1, 4 do inventory:AddItem(M.EMPTY_CUP) end
        end,
    },
    crock = {
        about = string.format("%d wheat grains; warm the copper with TPC.copper(1, 40) by a Hearth", M.CROCK_WHEAT),
        give = function(inventory)
            for _ = 1, M.CROCK_WHEAT do inventory:AddItem(M.WHEAT) end
        end,
    },
    wrap = {
        about = "a Yoghurt Pot, a Sheet and Twine, to make a Wrapped Yoghurt Pot",
        give = function(inventory)
            inventory:AddItem("TraditionalPreservationDairy.YoghurtPot")
            inventory:AddItem("Base.Sheet")
            inventory:AddItem("Base.Twine")
        end,
    },
}

function TPD.kit(kind)
    local kit = KITS[kind or "yoghurt"]
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
    local World = TraditionalPreservationDairyWorld
    return World and World.stations(true) or {}
end

function TPD.crocks()
    local list = crocks()
    if #list == 0 then return say("No crock loaded and tracked. Right-click one to start tracking it.") end
    for _, station in ipairs(list) do
        local state = TraditionalPreservationDairyWorld.updateCrock(station)
        local line = string.format("%d,%d,%d %s, %s", station:getX(), station:getY(), station:getZ(), M.crockStage(state), tostring(state.place))
        if state.done then
            local status = M.crockStatus(state, M.getLedger(), state.place)
            line = line .. string.format(": %.1f/%.0f h at %.0f%% speed, %s h left", state.done, M.crockHours(state), status.rate * 100,
                status.hoursLeft and string.format("%.1f", status.hoursLeft) or "never")
        end
        say(line)
    end
end

function TPD.culture(hours)
    hours = hours or M.CULTIVATE_HOURS
    for _, station in ipairs(crocks()) do
        local state = TraditionalPreservationDairyWorld.crockState(station)
        if state.done then state.done = state.done + hours end
        TraditionalPreservationDairyWorld.refresh(station)
    end
    say(string.format("Moved %d crock(s) on by %.1f hours.", #crocks(), hours))
    TPD.crocks()
end

-- What makes a station's tile block: the object's class, its sprite's flags and the square's, within 3 tiles.
function TPD.tiles()
    local here = getPlayer():getSquare()
    for dx = -3, 3 do
        for dy = -3, 3 do
            local square = getCell():getGridSquare(here:getX() + dx, here:getY() + dy, here:getZ())
            local objects = square and square:getObjects()
            for i = 0, (objects and objects:size() or 0) - 1 do
                local object = objects:get(i)
                if M.isIncubator(object) or M.isCrock(object) or M.isHearth(object) then
                    local props, squareProps = object:getSprite():getProperties(), square:getProperties()
                    local attached = object:getAttachedAnimSprite()
                    local blocks = instanceof(object, "IsoThumpable") and string.format(" blockAll %s passThrough %s",
                        tostring(object:isBlockAllTheSquare()), tostring(object:isCanPassThrough())) or ""
                    say(string.format("%d,%d %s%s %s: sprite solid %s solidtrans %s; square solid %s solidtrans %s; attached %d",
                        square:getX(), square:getY(), object:getClass():getSimpleName(), blocks, object:getSprite():getName(),
                        tostring(props:has(IsoFlagType.solid)), tostring(props:has(IsoFlagType.solidtrans)),
                        tostring(squareProps:has(IsoFlagType.solid)), tostring(squareProps:has(IsoFlagType.solidtrans)),
                        attached and attached:size() or 0))
                end
            end
        end
    end
end

say("Debug commands loaded. Type TPD.help() in the Lua console.")
