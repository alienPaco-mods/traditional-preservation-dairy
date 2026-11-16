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
-- Nothing is built near the player, and no station is tracked.
function getCell() return { getGridSquare = function() return nil end } end
local player = H.player({ z = -1 })
function getPlayer() return player end

dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
function isClient() return false end
MapObjects = { OnLoadWithSprite = function() end }
dofile("42/media/lua/server/TraditionalPreservationDairyWorld.lua")
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

before = #player.given
run("kit", "butter")
check("kit(\"butter\") gives three butter, a salt, a pot and a cloth", #player.given == before + 6 and player.given[before + 1] == M.BUTTER
    and player.given[before + 4] == "Base.Salt" and player.given[before + 5] == "Base.Pot" and player.given[before + 6] == "Base.RippedSheets")
run("give", "salted")
run("give", "clarified")
check("give spawns salted and clarified butter", player.given[before + 7] == M.SALTED_BUTTER
    and player.given[before + 8] == M.CLARIFIED_BUTTER)
local inventory = player:getInventory()
-- Kefir: given items answer for their modData and fluid.
local made = {}
local plainAdd = inventory.AddItem
function inventory:AddItem(fullType)
    plainAdd(self, fullType)
    local data, fluids = {}, {}
    local item = { fullType = fullType, getModData = function() return data end, data = data, fluids = fluids,
        getFluidContainer = function() return { Empty = function() end,
            addFluid = function(_, name, litres) fluids[name] = litres end } end }
    table.insert(made, item)
    return item
end
before = #player.given
run("kit", "kefir")
check("kit(\"kefir\") gives a packet, 10 live grains and a pot of 2 L of cow's kefir", #player.given == before + 12
    and player.given[before + 1] == M.GRAIN_PACKET and player.given[before + 2] == M.GRAIN
    and made[2].data[M.GRAIN_KEY].state == M.GRAIN_LIVE and made[11].data[M.GRAIN_KEY].hour == 100
    and player.given[before + 12] == "Base.Pot" and made[12].fluids.CowKefir == 2)
run("give", "packet")
run("give", "dried", 3)
check("give spawns packets and dried grains", player.given[before + 13] == M.GRAIN_PACKET and player.given[before + 16] == M.DRIED_GRAIN
    and #player.given == before + 16)
check("give lists the kefir things", run("give"):find("packet, dried, grains", 1, true) ~= nil)
check("milk refuses what is neither milk nor kefir and names the kefirs", run("milk", 1, nil, "Water"):find("CowKefir", 1, true) ~= nil)
function inventory:getAllEvalRecurse() return { size = function() return 0 end } end
check("butter says so when you carry none", run("butter"):find("No Butter", 1, true) ~= nil)
check("rancid ages none", run("rancid", 5):find("Kept 0 butter for 5 days", 1, true) ~= nil)

H.done()
