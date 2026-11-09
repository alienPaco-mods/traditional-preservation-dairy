-- Traditional Preservation (Dairy): commands for the debug Lua console, loaded only in debug mode.
-- Type TPD.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

local M = TraditionalPreservationDairy
local Weather = require "TraditionalPreservationDairy/Core/Weather"
TPD = {}

local RECIPE_NAME = "TraditionalPreservationDairy.ProcessBatch"

local function say(text) print("[TPD] " .. text) end

function TPD.help()
    say("TPD.weather()        the temperature by place, and how fast a batch works there")
    say("TPD.here()           which place you're standing in (outdoors, under a roof or a basement)")
    say("TPD.age(hours)       give every station this many hours of perfect weather")
    say("TPD.fast(hours)      test timer: a batch takes this many hours. TPD.fast() goes back to the sandbox time")
    say("TPD.batches(n)       spawn n raw batches")
end

function TPD.weather()
    local ledger = M.getLedger()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C. A batch takes %.1f hours at full speed.",
        ledger.temperature or 0, ledger.seasonTemperature or 0, M.PROCESS_HOURS))
    for _, place in ipairs(M.PLACES) do
        local rate = ledger["process" .. place .. "Rate"] or 0
        say(string.format("%-9s %.1f C: %.0f%% speed, about %.1f days a batch", place, M.placeTemperature(ledger, place),
            rate * 100, rate > 0 and M.PROCESS_HOURS / rate / 24 or 0))
    end
end

function TPD.here()
    say("You're in: " .. tostring(M.placeOf(getPlayer():getCurrentSquare())))
end

function TPD.age(hours)
    hours = hours or 24
    local ledger = M.getLedger()
    for _, place in ipairs(M.PLACES) do ledger["process" .. place] = (ledger["process" .. place] or 0) + hours end
    say(string.format("Added %.0f hours of perfect weather. Batches update within a few seconds.", hours))
end

function TPD.fast(hours)
    if not hours then
        M.applyProcessTime()
        return say(string.format("Back to the sandbox time: %.1f hours.", M.PROCESS_HOURS))
    end
    M.PROCESS_HOURS = hours
    Weather.setRecipeHours(RECIPE_NAME, hours, "TraditionalPreservationDairy")
    say(string.format("Test timer on: a batch takes %s hours at full speed.", tostring(hours)))
end

function TPD.batches(count)
    local inventory = getPlayer():getInventory()
    for _ = 1, count or 1 do inventory:AddItem("TraditionalPreservationDairy.RawBatch") end
    say("Gave " .. (count or 1) .. " raw batch(es).")
end

say("Debug commands loaded. Type TPD.help() in the Lua console.")
