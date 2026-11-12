-- Checks the debug console (TPD) loads and its commands run. Run from the mod folder: luajit tests/test_console.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

-- Engine stand-ins
function getClimateManager()
    return { getTemperature = function() return 18 end, getHumidity = function() return 50 end }
end
SandboxVars = { TraditionalPreservationDairy = { IncubationHours = 6 } }
-- Nothing is built near the player, and no station is tracked (the World isn't loaded).
function getCell() return { getGridSquare = function() return nil end } end
local player = H.player({ z = -1 })
function getPlayer() return player end

dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
local TPD, run = H.checkConsole("42/media/lua/client/TraditionalPreservationDairyDev.lua", "TPD")

check("weather names every place", (function()
    local text = run("weather")
    for _, place in ipairs(M.PLACES) do
        if not text:find(place, 1, true) then return false end
    end
    return true
end)())
check("here says where the player stands", run("here"):find("Basement", 1, true) ~= nil)

check("pots says so when none is tracked", run("pots"):find("No incubator", 1, true) ~= nil)
check("crocks too", run("crocks"):find("No crock", 1, true) ~= nil)
local aged = run("age", 2)
check("age moves pots and crocks, here none", aged:find("Moved 0 incubator", 1, true) ~= nil and aged:find("Moved 0 crock", 1, true) ~= nil)
check("tiles finds no station on unloaded ground", run("tiles") == "")

run("fast", 1)
check("fast sets the test timer", M.INCUBATE_HOURS == 1)
run("fast")
check("fast with no number goes back to the sandbox", M.INCUBATE_HOURS == 6)

run("kit")
check("kit gives the yogurt kit", #player.given == 7 and player.given[1] == "Base.Yoghurt" and player.given[7] == M.EMPTY_CUP)
run("kit", "crock")
check("kit(\"crock\") gives the wheat", #player.given == 7 + M.CROCK_WHEAT and player.given[8] == M.WHEAT)
check("an unknown kind lists the kits and gives nothing", run("kit", "?"):find("TPD.kit(\"wrap\")", 1, true) ~= nil
    and #player.given == 7 + M.CROCK_WHEAT)

local before = #player.given
check("give with no name lists the things", run("give"):find("jar", 1, true) ~= nil and #player.given == before)
run("give", "starter", 2)
run("give", "cup")
check("give spawns starters and cups", #player.given == before + 3 and player.given[before + 1] == M.STARTER
    and player.given[before + 3] == M.EMPTY_CUP)
check("milk names the milks for a fluid that isn't one", run("milk", 1, nil, "Water"):find("SheepMilk", 1, true) ~= nil
    and #player.given == before + 3)

H.done()
