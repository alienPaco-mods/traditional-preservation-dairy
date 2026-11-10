-- Traditional Preservation (Dairy) B42: the rules for the Yoghurt Incubator and the Starter Culture Crock.
-- The incubator is a lidded clay pot: milk brought to the boil in the hearth's copper cools in it by Newton's law towards the temperature where
-- it stands, and once it is down to setting heat with a starter in, the pot is wrapped in cloth and the milk
-- sets at a speed that follows its own temperature. Cooling depends on what the milk was, not only on the
-- weather now, so the core ledger's running totals can't replay it: an hourly history of the weather in
-- global ModData lets an unloaded pot catch up hour by hour. The crock is an ordinary weather-weighted run
-- on the ledger, in two stages with a feed of fresh milk between them.
-- A batch is a plain table (modData[M.INCUBATOR_KEY] or [M.CROCK_KEY]); every function here works on it without the engine.
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy
local Weather = require "TraditionalPreservationCore/Weather"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Tiles = require "TraditionalPreservationDairy/Tiles"

-- Save keys: never rename these once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
M.MOD_DATA_KEY = "TraditionalPreservationDairy"
-- Each station keeps its state as one table under one key, so nothing else on the object can clash with it.
-- Inside the incubator's: ml, tempC, starter, incubating, wrapHour, done, last, readyHour, fluid, place, at,
-- fireUntil, under. Inside the crock's: stage, done, marks, fireUntil, under. The Hearth and its copper are TP
-- Core's (TraditionalPreservationCore/Hearth).
M.INCUBATOR_KEY = "tpdIncubator"
M.CROCK_KEY = "tpdCrock"

-- Incubator
M.CAPACITY_ML = 5000
M.ROOM_C = Hearth.ROOM_C
M.MILK_MAX_C = Hearth.MAX_C   -- the copper over a fire; milk never quite boils in it
M.SET_C = 45                  -- the wrap goes on when the milk is down to this with a starter in
M.STARTER_MIN_C = 40          -- below this a starter won't take: the milk must be reheated
M.LIDDED_TAU = 2.0            -- hours, for 5 L in the lidded clay pot
M.TAU_FLOOR_ML = 2500         -- smaller batches cool as if this big, so a litre or two still sets (balance)
M.WRAPPED_TAU = 16.0          -- hours, for 5 L once wrapped in cloth: about 10 C lost overnight in a 20 C room
M.INCUBATE_HOURS = 6          -- hours to set at the best temperature
M.STEP_HOURS = 1 / 6          -- the weather's own resolution
M.HISTORY_HOURS = 336         -- two weeks of hourly weather for catching up
-- By a lit fire, TP Core's opt-in place: a fireplace, an antique stove or a campfire, never an electric or gas
-- stove. The wrapped pot sat by the hearth in winter. Seen by a lit fire, a station notes fireUntil (now plus the
-- fuel left): while unloaded, the fire counts until then, and after it the place under the fire (under) does.
M.HEARTH = Hearth.PLACE
M.HEARTH_C = Hearth.FIRE_C

-- The Hearth's copper (TP Core) holds one fluid at a time and heats towards MILK_MAX_C while its fire burns.
M.COPPER_ML = Hearth.COPPER_ML
M.HOT_C = Hearth.HOT_C        -- milk this hot pours from the copper into a pot

-- Carried milk: a container filled from the copper keeps a record in its item modData, so the incubator knows
-- the milk was steamed. Only the Wrapped Pot (a cooking pot in a rug) holds the heat; any other container
-- follows vanilla's item heat, which drops to the room within seconds.
M.CARRY_KEY = "tpdCarry"      -- { ml, c, hour, steamed }
M.WRAPPED_POT_TAU = 4.0       -- hours, for 5 L: 85 to 70 C in about an hour at 20 C

-- Share of full setting speed at the milk's own temperature. Thermophilic cultures: best at 40 to 45 C,
-- slow below 35, stalled below about 18; past 50 the heat starts to kill them.
local SET_CURVE = { { 18, 0 }, { 22, 0.05 }, { 27, 0.15 }, { 32, 0.35 }, { 37, 0.7 }, { 40, 1 }, { 45, 1 }, { 50, 0.5 }, { 55, 0 } }

-- Crock: loaded with wheat and warm milk, fed fresh milk of any warmth once cultivated.
M.CROCK_CAPACITY_ML = 1000
M.WHEAT = "Base.WheatSeed"
M.CROCK_WHEAT = 20
M.CROCK_LOAD_ML = 500
M.CROCK_FEED_ML = 500
M.CROCK_WARM_C = 35           -- milk for loading must be warm: at least this,
M.CROCK_HOT_C = 45            -- and no hotter than this, or it kills the grain's culture
M.CULTIVATE_HOURS = 24        -- wheat and warm milk, at the best temperature
M.DEVELOP_HOURS = 12          -- after the fresh-milk feed, at the best temperature
M.CROCK_STARTERS = 2
local CROCK_KIND = "culture"
-- Grain starters are kept warm, not hot: best at 25 to 35 C, slow when cool, near stopped by 5.
local CULTURE_CURVE = { { 5, 0.03 }, { 10, 0.1 }, { 15, 0.3 }, { 20, 0.6 }, { 25, 1 }, { 35, 1 }, { 40, 0.6 }, { 45, 0.1 } }

-- Yield
M.JAR_ML = 1000               -- each jar takes one litre of yoghurt
M.CUPS_PER_LITRE = 4          -- 8 oz cups
M.CUP_ML = M.JAR_ML / M.CUPS_PER_LITRE   -- an Empty Yoghurt Container takes a quarter of a jar
M.CUP_KG = 0.25               -- a cup's share of a full jar's weight

-- Items and fluids. Only a cow's or a sheep's milk sets; yoghurt is yoghurt, so the two may share a pot.
M.MILKS = { CowMilk = true, SheepMilk = true }
M.STARTER = "TraditionalPreservationDairy.ActiveYoghurtStarter"
M.STARTERS = { ["Base.Yoghurt"] = "Yoghurt", [M.STARTER] = "Starter" }
M.EMPTY_CUP = "TraditionalPreservationDairy.EmptyYoghurtContainer"
-- Clay Jars need Pottery 5 and are rare loot; the glass canning jar is common and holds exactly a litre.
M.JARS = { ["Base.ClayJar"] = true, ["Base.ClayJarGlazed"] = true, ["Base.EmptyJar"] = true }
M.YOGHURT_JAR = "TraditionalPreservationDairy.JarOfYoghurt"
-- One item whatever the jar; a clay one changes only its icon (the engine saves an item's own texture).
M.JAR_ICONS = { ["Base.ClayJar"] = "Item_JarOfYoghurt_Clay", ["Base.ClayJarGlazed"] = "Item_JarOfYoghurt_Glazed" }
M.COLLECT_XP = 2              -- Cooking, per jar (a litre); a cup earns its share

-- Stations: FACE_COUNT tiles from each base, one per facing. Stage sprites are layered on top once the art
-- builder makes them (Tiles.OVERLAYS); until then the station shows its base tile only.
M.INCUBATOR_SPRITE = Tiles.INCUBATOR
M.CROCK_SPRITE = Tiles.CROCK
M.FACE_COUNT = Tiles.FACE_COUNT
M.INCUBATOR_OVERLAYS = Tiles.OVERLAYS and Tiles.OVERLAYS.incubator or {}
M.CROCK_OVERLAYS = Tiles.OVERLAYS and Tiles.OVERLAYS.crock or {}

function M.spriteIndex(name)
    if not name or string.sub(name, 1, #Tiles.PREFIX) ~= Tiles.PREFIX then return nil end
    return tonumber(string.sub(name, #Tiles.PREFIX + 1))
end

function M.spriteName(index)
    return Tiles.PREFIX .. index
end

-- The fluid in a container if it is all one kind, else nil.
function M.fluidIn(container)
    if not container or container:isEmpty() then return nil end
    local fluid = container:getPrimaryFluid()
    if not fluid or container:getPrimaryFluidAmount() < container:getAmount() - 0.001 then return nil end
    return fluid:getFluidTypeString()
end

-- The fluid in a container if it is all one kind of milk, else nil.
function M.milkIn(container)
    local name = M.fluidIn(container)
    return M.MILKS[name] and name or nil
end

function M.fluidName(name)
    local fluid = name and Fluid.Get(name)
    return fluid and fluid:getTranslatedName() or tostring(name)
end

-- Only empty containers take milk or yoghurt out, so nothing is ever topped up into a mixture.
function M.isEmptyContainer(item)
    local container = item:getFluidContainer()
    return container ~= nil and container:isEmpty() and container:getCapacity() > 0
end

local function isStationSprite(spriteName, base)
    local index = spriteName and M.spriteIndex(spriteName)
    return index ~= nil and index >= base and index < base + M.FACE_COUNT
end

local function isStation(object, base)
    local sprite = object and object:getSprite()
    return sprite ~= nil and isStationSprite(sprite:getName(), base)
end

function M.isIncubator(object)
    return isStation(object, M.INCUBATOR_SPRITE)
end

function M.isCrock(object)
    return isStation(object, M.CROCK_SPRITE)
end

-- Off, Forgiving, Normal, Harsh: how much of a temperature's slowdown applies.
M.SENSITIVITY_SCALES = { 0, 0.5, 1, 1.5 }
M.SENSITIVITY = 1

M.PLACES = { "Open", "Sheltered", "Basement", M.HEARTH }

M.placeTemperature = Hearth.placeTemperature
M.fireNear = Hearth.fireNear
M.placeOf = Hearth.placeOf
M.noteFire = Hearth.noteFire
M.hearthsNear = Hearth.hearthsNear
M.isHearth = Hearth.isHearth

-- Temperatures: vanilla's item heat, for milk poured between our stores and the player's containers. Vanilla
-- cools a container in the player's hands to room heat within seconds, so only the copper and the pot keep heat.
M.heatCelsius = Hearth.heatCelsius
M.itemHeat = Hearth.itemHeat

-- More milk holds its heat longer: the time constant grows with the pot's size, so with the cube root of litres.
function M.tau(ml, wrapped)
    local base = wrapped and M.WRAPPED_TAU or M.LIDDED_TAU
    return base * (math.max(ml, M.TAU_FLOOR_ML) / M.CAPACITY_ML) ^ (1 / 3)
end

M.cool = Hearth.cool

function M.setRate(milkC)
    return Weather.scaled(Weather.curve(SET_CURVE, milkC), M.SENSITIVITY, 0)
end

function M.cultureRate(celsius)
    return Weather.scaled(Weather.curve(CULTURE_CURVE, celsius), M.SENSITIVITY, 0)
end

-- Weather ledger and history

local KINDS = { [CROCK_KIND] = function(celsius) return M.cultureRate(celsius) end }

function M.newLedger(now)
    return Weather.newLedger(now, KINDS)
end

function M.getLedger()
    return Weather.getLedger(M.MOD_DATA_KEY, M.newLedger)
end

function M.getHistory()
    local data = ModData.getOrCreate(M.MOD_DATA_KEY)
    data.history = data.history or {}
    return data.history
end

-- One ten-minute reading: the ledger for the crock, and the hour's slot in the history for the incubator.
-- An hour's slot keeps the last reading in it, with the season mean that goes with it.
function M.record(ledger, history, now, temperature)
    Weather.advance(ledger, now, temperature, KINDS)
    local hour = math.floor(now)
    history[hour % M.HISTORY_HOURS + 1] = { hour = hour, temperature = ledger.temperature, season = ledger.seasonTemperature }
end

-- The place's temperature in a past hour, or nil when the history has no reading for it.
function M.pastTemperature(history, hour, place)
    local entry = history[hour % M.HISTORY_HOURS + 1]
    if place == M.HEARTH then return M.HEARTH_C end
    if not entry or entry.hour ~= hour then return nil end
    return Weather.placeTemperature({ temperature = entry.temperature, seasonTemperature = entry.season }, place)
end

-- Incubator

-- Empty, Cooling, TooCold, Incubating or Ready.
function M.stage(batch)
    if (batch.ml or 0) <= 0 then return "Empty" end
    if batch.readyHour then return "Ready" end
    if batch.incubating then return "Incubating" end
    if not batch.starter and batch.tempC < M.STARTER_MIN_C then return "TooCold" end
    return "Cooling"
end

-- How much of ml fits, or 0 with the reason it can't go in. Given a fluid, cow's and sheep's milk don't mix.
function M.milkRoom(batch, ml, fluid)
    local stage = M.stage(batch)
    if stage == "Incubating" or stage == "Ready" then return 0, stage end
    if fluid and stage ~= "Empty" and batch.fluid and batch.fluid ~= fluid then return 0, "Mixed" end
    local room = M.CAPACITY_ML - (batch.ml or 0)
    if room <= 0 then return 0, "Full" end
    return math.min(ml, room)
end

-- Pours hot milk in; the temperatures mix by volume. Returns the ml taken (0 with a reason when refused).
function M.addMilk(batch, ml, milkC, now)
    local taken, reason = M.milkRoom(batch, ml)
    if taken <= 0 then return 0, reason end
    local had = batch.ml or 0
    batch.tempC = had > 0 and (batch.tempC * had + milkC * taken) / (had + taken) or milkC
    batch.ml = had + taken
    batch.last = batch.last or now
    return taken
end

-- The starter waits beside the pot until the milk is down to setting heat. It can go in before the milk.
function M.canAddStarter(batch)
    if batch.starter then return false, "HasStarter" end
    local stage = M.stage(batch)
    if stage == "Incubating" or stage == "Ready" then return false, stage end
    if stage == "TooCold" then return false, "TooCold" end
    return true
end

function M.addStarter(batch, kind)
    local ok, reason = M.canAddStarter(batch)
    if not ok then return false, reason end
    batch.starter = kind
    return true
end

-- Takes up to maxMl of the milk back out (to reheat it), all of it if left out. Returns the ml and its
-- temperature. The starter, if any, stays for the next pour.
function M.pourOut(batch, maxMl)
    local stage = M.stage(batch)
    if stage ~= "Cooling" and stage ~= "TooCold" then return 0 end
    local ml, tempC = math.min(batch.ml, maxMl or batch.ml), batch.tempC
    batch.ml = batch.ml - ml
    if batch.ml <= 0 then
        for _, key in ipairs({ "ml", "tempC", "last", "fluid" }) do batch[key] = nil end
    end
    return ml, tempC
end

-- Runs the pot for hours at one place temperature, from hour now. Each step cools exactly; the wrap goes on
-- and the yoghurt is done within a step's resolution.
function M.advanceBatch(batch, hours, placeC, now)
    if (batch.ml or 0) <= 0 then return end
    local t = 0
    while t < hours - 1e-9 do
        local step = math.min(M.STEP_HOURS, hours - t)
        local wrapped = batch.incubating and not batch.readyHour
        batch.tempC = M.cool(batch.tempC, placeC, step, M.tau(batch.ml, wrapped))
        t = t + step
        if not batch.incubating and batch.starter and batch.tempC <= M.SET_C then
            batch.incubating = true
            batch.wrapHour = now + t
            batch.done = 0
        elseif wrapped then
            batch.done = batch.done + M.setRate(batch.tempC) * step
            if batch.done >= M.INCUBATE_HOURS then batch.readyHour = now + t end
        end
    end
end

-- By a fire until it burns out (fireUntil), then the place under it.
local function placeAt(state, place, hour)
    if place == M.HEARTH and state.fireUntil and hour >= state.fireUntil then return state.under or "Sheltered" end
    return place
end

-- Brings the pot up to now: hour by hour through the history, at the place's current temperature where the
-- history has no reading (a gap longer than it keeps, or the hour now).
function M.catchUp(batch, now, place, history, ledger)
    if (batch.ml or 0) <= 0 then batch.last = now return end
    local t = batch.last or now
    while t < now do
        local hour = math.floor(t)
        local stop = math.min(hour + 1, now)
        if place == M.HEARTH and batch.fireUntil and t < batch.fireUntil then stop = math.min(stop, batch.fireUntil) end
        local here = placeAt(batch, place, t)
        M.advanceBatch(batch, stop - t, M.pastTemperature(history, hour, here) or M.placeTemperature(ledger, here), t)
        t = stop
    end
    batch.last = now
end

-- Days since the yoghurt set, for the jar's food age: freshness carries over and never resets.
function M.ageDays(batch, now)
    return batch.readyHour and math.max(now - batch.readyHour, 0) / 24 or 0
end

-- Takes up to want ml of set yoghurt. Returns the ml taken and the age in days; an emptied pot starts over.
local function collect(batch, now, want)
    if M.stage(batch) ~= "Ready" then return 0 end
    local ml = math.min(want, batch.ml)
    local age = M.ageDays(batch, now)
    batch.ml = batch.ml - ml
    if batch.ml <= 0 then
        for _, key in ipairs({ "ml", "tempC", "starter", "incubating", "wrapHour", "done", "last", "readyHour", "fluid" }) do batch[key] = nil end
    end
    return ml, age
end

-- Fills one Clay Jar.
function M.collectJar(batch, now)
    return collect(batch, now, M.JAR_ML)
end

-- Fills one Empty Yoghurt Container straight from the pot, a quarter of a jar; the last one takes what is left.
function M.collectCup(batch, now)
    return collect(batch, now, M.CUP_ML)
end

-- Empty Yoghurt Containers a Ready pot still fills.
function M.cupsInPot(batch)
    if M.stage(batch) ~= "Ready" then return 0 end
    return math.ceil(batch.ml / M.CUP_ML)
end

function M.cupsFor(ml)
    return math.max(math.floor(ml / 1000 * M.CUPS_PER_LITRE + 0.5), 1)
end

-- Cups still in a Jar of Yoghurt, from its modData: a jar from before the count was kept goes by its litres.
function M.cupsLeft(jarData)
    return jarData.tpdCups or M.cupsFor(jarData.tpdMl or M.JAR_ML)
end

-- Spoons one cup out of the jar. Returns the cups left; at 0 the jar is empty and goes back to its own type.
function M.takeCup(jarData)
    local left = math.max(M.cupsLeft(jarData) - 1, 0)
    jarData.tpdCups = left
    return left
end

-- Hours until the next change (wrap on, or set) if the place's temperature holds; nil if it never comes.
function M.forecast(batch, placeC)
    local copy = {}
    for key, value in pairs(batch) do copy[key] = value end
    local stage = M.stage(copy)
    if stage == "Empty" or stage == "Ready" or stage == "TooCold" then return nil end
    local hours, limit = 0, 96
    while hours < limit do
        M.advanceBatch(copy, M.STEP_HOURS, placeC, hours)
        hours = hours + M.STEP_HOURS
        local now = M.stage(copy)
        if now ~= stage then return hours, now end
    end
    return nil
end

-- Hearth copper: the rules are TP Core's; these are milk's.

-- Hours until the copper is hot if the fire burns on; 0 if it is already, nil if it holds no milk.
function M.hoursToHot(copper)
    if not M.MILKS[copper.fluid] then return nil end
    return Hearth.hoursToHot(copper)
end

function M.copperHot(copper)
    return M.MILKS[copper.fluid] == true and (copper.tempC or 0) >= M.HOT_C
end

function M.copperWarm(copper)
    return M.MILKS[copper.fluid] == true and M.isWarm(copper.tempC or 0)
end

-- Fills the pot from the copper with hot milk, as much as fits. Returns the ml (0 with a reason when refused).
function M.copperToPot(copper, batch, now)
    if not M.copperHot(copper) then return 0, M.MILKS[copper.fluid] and "NotHot" or "NoMilk" end
    local room, reason = M.milkRoom(batch, copper.ml, copper.fluid)
    if room <= 0 then return 0, reason end
    local ml, fluid, tempC = Hearth.take(copper, room)
    M.addMilk(batch, ml, tempC, now)
    batch.fluid = batch.fluid or fluid
    return ml
end

-- Carried milk

function M.carryTau(ml)
    return M.WRAPPED_POT_TAU * (math.max(ml, Hearth.FLOOR_ML) / M.CAPACITY_ML) ^ (1 / 3)
end

-- Records ml of milk at tempC going into a container that already holds hadMl at hadC. The milk stays steamed
-- only if the new milk is and everything already in it was recorded as steamed. Returns the new record.
function M.carryIn(carry, hadMl, hadC, ml, tempC, now, steamed)
    local kept = hadMl <= 0 or M.isSteamed(carry, hadMl)
    local record = {
        ml = hadMl + ml,
        c = hadMl > 0 and (hadC * hadMl + tempC * ml) / (hadMl + ml) or tempC,
        hour = now,
        steamed = (steamed and kept) or nil,
    }
    if carry and hadMl > 0 then record.place, record.fireUntil, record.under = carry.place, carry.fireUntil, carry.under end
    return record
end

-- Takes ml out of the record; nil once it is empty.
function M.carryOut(carry, ml)
    if not carry then return nil end
    carry.ml = carry.ml - ml
    if carry.ml <= 0.5 then return nil end
    return carry
end

-- True if the container's ml is all recorded, steamed milk. Taking milk out (vanilla's pour or drink too) is
-- harmless; holding more than the record means milk was added some other way, which voids it.
function M.isSteamed(carry, ml)
    return carry ~= nil and carry.steamed == true and ml <= (carry.ml or 0) + 0.5
end

-- Shrinks the record to ml once milk has left by vanilla's menus, so milk added later can't hide in the gap.
-- Call it whenever a container is looked at (menus, tooltips). Returns the record, nil once the container is empty.
function M.noteCarry(carry, ml)
    if not carry then return nil end
    if ml <= 0.5 then return nil end
    if ml < carry.ml then carry.ml = ml end
    return carry
end

-- The heat of milk in a Wrapped Pot, brought up to now at placeC (the record is updated).
function M.wrappedC(carry, now, placeC)
    if now > carry.hour then
        carry.c = M.cool(carry.c, placeC, now - carry.hour, M.carryTau(carry.ml))
        carry.hour = now
    end
    return carry.c
end

-- Why ml of carried milk can't go into the pot, or nil if it can.
function M.carriedRefusal(carry, ml)
    if not M.isSteamed(carry, ml) then return "NotSteamed" end
end

-- The record on a carried item

M.WRAPPED_POT = "TraditionalPreservationDairy.WrappedYoghurtPot"

function M.isWrappedPot(item)
    return item:getFullType() == M.WRAPPED_POT
end

function M.mlIn(container)
    return math.floor(container:getAmount() * 1000 + 0.5)
end

-- An item's record, shrunk to the milk it holds now; nil (and dropped) once it holds no plain milk.
function M.carryOf(item)
    local modData = item:getModData()
    local carry = modData[M.CARRY_KEY]
    if not carry then return nil end
    local container = item:getFluidContainer()
    carry = container and M.milkIn(container) and M.noteCarry(carry, M.mlIn(container)) or nil
    modData[M.CARRY_KEY] = carry
    return carry
end

-- Brings a Wrapped Pot's milk up to now at the place it was last carried in (herePlace if it has none yet), hour
-- by hour through the history as the incubator catches up: by a fire until the fuel ran out (fireUntil), then the
-- place under the fire. Returns the heat.
function M.advanceCarry(carry, now, ledger, herePlace, history)
    local place = carry.place or herePlace
    history = history or M.getHistory()
    local t = carry.hour
    while t < now do
        local hour = math.floor(t)
        local stop = math.min(hour + 1, now)
        if place == M.HEARTH and carry.fireUntil and t < carry.fireUntil then stop = math.min(stop, carry.fireUntil) end
        local here = placeAt(carry, place, t)
        M.wrappedC(carry, stop, M.pastTemperature(history, hour, here) or M.placeTemperature(ledger, here))
        t = stop
    end
    return carry.c
end

-- While a player carries a Wrapped Pot, the World brings it up to now every game minute and notes where it is.
-- Set down, the pot keeps the last place it was carried in, so the time until it is next looked at counts there.
function M.carryTick(carry, now, ledger, place, fireUntil, under)
    M.advanceCarry(carry, now, ledger, place)
    carry.place, carry.fireUntil, carry.under = place, fireUntil, under
end

-- The heat of an item's milk: a Wrapped Pot keeps its own, any other container follows vanilla's item heat. holder
-- is whoever is looking at it, whose place counts if the pot was never carried.
function M.carriedC(item, now, holder)
    local carry = M.carryOf(item)
    if carry and M.isWrappedPot(item) then return M.advanceCarry(carry, now, M.getLedger(), (M.placeOf(holder))) end
    return M.heatCelsius(item:getItemHeat())
end

-- Writes the record after ml of milk at tempC went into an item that held hadMl at hadC (carry: its record from
-- before), and sets vanilla's item heat to match.
function M.recordCarry(item, carry, hadMl, hadC, ml, tempC, now, steamed)
    local record = M.carryIn(carry, hadMl, hadC, ml, tempC, now, steamed)
    item:getModData()[M.CARRY_KEY] = record
    item:setItemHeat(M.itemHeat(record.c))
end

-- Writes the record after ml left the item.
function M.recordTaken(item, carry, ml)
    item:getModData()[M.CARRY_KEY] = M.carryOut(carry, ml)
end

-- The copper's hooks: a Wrapped Pot pours in at its own heat; milk drawn steaming is marked so the incubator takes
-- it. Milk that left an item is already gone from the container, so reading the record shrinks it to match.
Hearth.hook("heatOf", function(item, now, character)
    local carry = M.isWrappedPot(item) and M.carryOf(item)
    return carry and M.advanceCarry(carry, now, M.getLedger(), (M.placeOf(character))) or nil
end)

Hearth.hook("taken", function(item)
    M.carryOf(item)
end)

Hearth.hook("filled", function(item, fill)
    if not M.MILKS[fill.fluid] then return false end
    M.recordCarry(item, item:getModData()[M.CARRY_KEY], fill.hadMl, fill.hadC, fill.ml, fill.tempC, fill.now, fill.hot)
    return true
end)


-- Crock: Cultivating, then Waiting for fresh milk, then Developing, then Ready.

-- The ledger keeps totals for the weather's places only, so time by a fire counts by the clock at HEARTH_C.
local function markCrock(crock, ledger)
    crock.marks = Weather.mark({}, ledger, CROCK_KIND)
    crock.marks.hour = ledger.lastHour
end

function M.startCrock(crock, ledger)
    crock.stage = "Cultivating"
    crock.done = 0
    markCrock(crock, ledger)
end

-- Empty, Cultivating, Waiting, Developing or Ready.
function M.crockStage(crock)
    return crock.stage or "Empty"
end

function M.isWarm(celsius)
    return celsius >= M.CROCK_WARM_C and celsius <= M.CROCK_HOT_C
end

-- Why milk at celsius can't load the crock, or nil if it can.
function M.crockMilkRefusal(celsius)
    if celsius < M.CROCK_WARM_C then return "TooCool" end
    if celsius > M.CROCK_HOT_C then return "TooHot" end
end

-- Why ml of milk at celsius, from the copper or a container, can't load the crock, or nil if it can.
function M.crockLoadRefusal(ml, celsius)
    if ml < M.CROCK_LOAD_ML - 0.5 then return "TooLittle" end
    return M.crockMilkRefusal(celsius)
end

-- Wheat and warm milk go into an empty crock only.
function M.loadCrock(crock, ledger)
    if M.crockStage(crock) ~= "Empty" then return false end
    M.startCrock(crock, ledger)
    return true
end

-- Empties a ready crock. Returns how many starters it gives, 0 if it isn't ready.
function M.collectStarters(crock)
    if M.crockStage(crock) ~= "Ready" then return 0 end
    for _, key in ipairs({ "stage", "done", "marks" }) do crock[key] = nil end
    return M.CROCK_STARTERS
end

-- The station's state table, made on first use.
function M.stateOf(modData, key)
    modData[key] = modData[key] or {}
    return modData[key]
end

function M.feedCrock(crock, ledger)
    if crock.stage ~= "Waiting" then return false end
    crock.stage = "Developing"
    crock.done = 0
    markCrock(crock, ledger)
    return true
end

function M.crockHours(crock)
    return crock.stage == "Cultivating" and M.CULTIVATE_HOURS or M.DEVELOP_HOURS
end

function M.updateCrock(crock, ledger, place)
    local stage = crock.stage
    if stage ~= "Cultivating" and stage ~= "Developing" then return end
    if place == M.HEARTH then
        -- The ledger's totals can't be split at the hour the fire went out, so the place under it gets its
        -- share of the gap's weather by time.
        local from, to = crock.marks.hour or ledger.lastHour, ledger.lastHour
        local byFire = math.max(math.min(crock.fireUntil or to, to) - from, 0)
        local done = byFire * M.cultureRate(M.HEARTH_C)
        if to - from > byFire then
            done = done + Weather.catchUp(crock.marks, ledger, CROCK_KIND, crock.under or "Sheltered") * (to - from - byFire) / (to - from)
        end
        crock.done = crock.done + done
    else
        crock.done = crock.done + Weather.catchUp(crock.marks, ledger, CROCK_KIND, place)
    end
    markCrock(crock, ledger)
    if crock.done >= M.crockHours(crock) then
        crock.stage = stage == "Cultivating" and "Waiting" or "Ready"
    end
end

function M.crockStatus(crock, ledger, place)
    local temperature = M.placeTemperature(ledger, place)
    local rate = M.cultureRate(temperature)
    local hours = M.crockHours(crock)
    return {
        progress = math.min((crock.done or 0) / hours, 1),
        hoursLeft = rate > 0 and math.max(hours - (crock.done or 0), 0) / rate or nil,
        temperature = temperature,
        place = place,
        rate = rate,
    }
end

-- Sandbox

function M.applySandbox()
    local options = SandboxVars and SandboxVars.TraditionalPreservationDairy
    if not options then return end
    if options.IncubationHours then M.INCUBATE_HOURS = options.IncubationHours end
    if options.CultureHours then
        M.CULTIVATE_HOURS = options.CultureHours
        M.DEVELOP_HOURS = options.CultureHours / 2
    end
    if options.TemperatureSensitivity then M.SENSITIVITY = M.SENSITIVITY_SCALES[options.TemperatureSensitivity] or 1 end
end

Events.OnInitGlobalModData.Add(M.applySandbox)
