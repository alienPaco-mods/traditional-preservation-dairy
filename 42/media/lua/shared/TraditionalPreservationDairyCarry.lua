-- Traditional Preservation (Dairy): carried milk's heat and scald, kept as a record on the item, and the cauldron's
-- hooks that write it. Required by TraditionalPreservationDairy.lua, whose M it adds to.
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy
local Fire = require "TraditionalPreservationCore/Fire"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

-- Carried milk: a container filled from the cauldron, taken hot off a stove or a fire, or poured into from one of those
-- keeps a record of its heat in its item modData (vanilla's item heat drops to the room within seconds of leaving
-- the heat). An open pot or bucket cools in minutes; the Wrapped Yogurt Pot (a clay pot in its cloth) in hours.
M.CARRY_KEY = "tpdCarry"      -- { ml, c, hour, scalded }
M.WRAPPED_POT_TAU = 4.0       -- hours, for 5 L: 85 to 70 C in about an hour at 20 C
M.OPEN_TAU = 0.25             -- hours, for 5 L: 85 to 45 C in about 15 minutes at 20 C, to 35 C in about 8 more
M.STAMP_C = 30                -- milk taken off the heat warmer than this keeps a record of it

function M.carryTau(ml, open)
    return (open and M.OPEN_TAU or M.WRAPPED_POT_TAU) * (math.max(ml, Fire.FLOOR_ML) / M.CAPACITY_ML) ^ (1 / 3)
end

-- Records ml of milk at tempC going into a container that already holds hadMl at hadC. The milk stays scalded
-- only if the new milk is and everything already in it was recorded as scalded. Returns the new record.
function M.carryIn(carry, hadMl, hadC, ml, tempC, now, scalded)
    local kept = hadMl <= 0 or M.isScalded(carry, hadMl)
    local record = {
        ml = hadMl + ml,
        c = hadMl > 0 and (hadC * hadMl + tempC * ml) / (hadMl + ml) or tempC,
        hour = now,
        scalded = (scalded and kept) or nil,
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

-- True if the container's ml is all recorded, scalded milk. Taking milk out (vanilla's pour or drink too) is
-- harmless; holding more than the record means milk was added some other way, which voids it.
function M.isScalded(carry, ml)
    return carry ~= nil and carry.scalded == true and ml <= (carry.ml or 0) + 0.5
end

-- True if parts ({ name = ml }) is all scalded milk (TP Core's FluidAgeing names it so once it has been at 85 C, in
-- the cauldron, on a stove or a fire, or poured out of a store carton).
function M.allScalded(parts)
    local any = false
    for name in pairs(parts or {}) do
        if not M.SCALDED[name] then return false end
        any = true
    end
    return any
end

-- Shrinks the record to ml once milk has left by vanilla's menus, so milk added later can't hide in the gap.
-- Call it whenever a container is looked at (menus, tooltips). Returns the record, nil once the container is empty.
function M.noteCarry(carry, ml)
    if not carry then return nil end
    if ml <= 0.5 then return nil end
    if ml < carry.ml then carry.ml = ml end
    return carry
end

-- The heat of carried milk, brought up to now at placeC (the record is updated); open for anything but a Wrapped Pot.
function M.wrappedC(carry, now, placeC, open)
    if now > carry.hour then
        carry.c = M.cool(carry.c, placeC, now - carry.hour, M.carryTau(carry.ml, open))
        carry.hour = now
    end
    return carry.c
end

-- Why ml of carried milk can't go into the pot, or nil if it can: it must be scalded (parts, by name) or recorded as
-- scalded (when the sandbox has milk never going off, nothing is renamed).
function M.carriedRefusal(carry, ml, parts)
    if not M.allScalded(parts) and not M.isScalded(carry, ml) then return "NotScalded" end
end

-- The record on a carried item

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

-- Brings carried milk up to now at the place it was last carried in (herePlace if it has none yet), hour by hour
-- through the history as the incubator catches up: by a fire until the fuel ran out (fireUntil), then the place
-- under the fire. open: not in a Wrapped Pot, so it cools fast. Returns the heat.
function M.advanceCarry(carry, now, ledger, herePlace, history, open)
    M.walkHours(carry, carry.place or herePlace, carry.hour, now, history or M.getHistory(), ledger, function(_, to, placeC)
        M.wrappedC(carry, to, placeC, open)
    end)
    return carry.c
end

-- While a player carries warm milk, the World brings it up to now every game minute and notes where it is. Set
-- down, it keeps the last place it was carried in, so the time until it is next looked at counts there.
function M.carryTick(carry, now, ledger, place, fireUntil, under, open)
    M.advanceCarry(carry, now, ledger, place, nil, open)
    carry.place, carry.fireUntil, carry.under = place, fireUntil, under
end

-- The heat of an item's milk: its record's if it has one (cooling slowly in a Wrapped Pot, fast in anything else),
-- else vanilla's item heat. holder is whoever is looking at it, whose place counts if it was never carried.
function M.carriedC(item, now, holder)
    local carry = M.carryOf(item)
    if carry then
        return M.advanceCarry(carry, now, M.getLedger(), (M.placeOf(holder)), nil, not M.isWrapped(item))
    end
    return M.heatCelsius(item:getItemHeat())
end

-- Milk taken off a stove or a fire (from a container that hot) keeps its heat as a record, scalded if it was held at
-- 85 C or more for the hold (TP Core's FluidAgeing counts it while it sits on the heat): read now, while it is still there.
function M.stampHeat(item, now)
    local container = item:getFluidContainer()
    local _, parts = M.milkIn(container)
    if not parts then return end
    local tempC = M.heatCelsius(item:getItemHeat())
    if tempC < M.STAMP_C then return end
    local carry, ml = M.carryOf(item), M.mlIn(container)
    M.recordCarry(item, nil, 0, 0, ml, tempC, now, M.held(FluidAgeing.heldHours(item)) or M.isScalded(carry, ml))
end

-- After a vanilla pour: moved ml of milk at fromC (scalded or not) went into an item that held hadMl at hadC.
function M.pouredInto(item, carry, hadMl, hadC, moved, fromC, scalded, now)
    if moved <= 0.5 or not M.milkIn(item:getFluidContainer()) then return end
    M.recordCarry(item, carry, hadMl, hadC, moved, fromC, now, scalded)
end

-- Writes the record after ml of milk at tempC went into an item that held hadMl at hadC (carry: its record from
-- before), and sets vanilla's item heat to match.
function M.recordCarry(item, carry, hadMl, hadC, ml, tempC, now, scalded)
    local record = M.carryIn(carry, hadMl, hadC, ml, tempC, now, scalded)
    item:getModData()[M.CARRY_KEY] = record
    item:setItemHeat(M.itemHeat(record.c))
end

-- Writes the record after ml left the item.
function M.recordTaken(item, carry, ml)
    item:getModData()[M.CARRY_KEY] = M.carryOut(carry, ml)
end

-- The cauldron's hooks: a Wrapped Pot pours in at its own heat; milk drawn steaming is marked so the incubator takes
-- it. Milk that left an item is already gone from the container, so reading the record shrinks it to match.
Fire.hook("heatOf", function(item, now, character)
    local carry = M.carryOf(item)
    return carry and M.advanceCarry(carry, now, M.getLedger(), (M.placeOf(character)), nil, not M.isWrapped(item)) or nil
end)

Fire.hook("taken", function(item)
    M.carryOf(item)
end)

Fire.hook("filled", function(item, fill)
    if not M.MILKS[fill.fluid] then return false end
    -- Scalded once the cauldron's milk had its hold, hot or cooled since.
    M.recordCarry(item, item:getModData()[M.CARRY_KEY], fill.hadMl, fill.hadC, fill.ml, fill.tempC, fill.now, M.held(fill.held))
    return true
end)
