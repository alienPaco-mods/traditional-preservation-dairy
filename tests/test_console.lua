-- Checks the debug console (TPD) loads and its commands run. Run from the mod folder: luajit tests/test_console.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- Engine stand-ins
function getClimateManager()
    return { isUpdated = function() return true end, getTemperature = function() return 18 end, getHumidity = function() return 50 end }
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
check("kit(\"butter\") gives nine butter, a salt, a pot, a saucepan, a cloth and a burnt pot", #player.given == before + 14
    and player.given[before + 1] == M.BUTTER and player.given[before + 10] == "Base.Salt" and player.given[before + 11] == "Base.Pot"
    and player.given[before + 12] == "Base.Saucepan" and player.given[before + 13] == "Base.RippedSheets"
    and player.given[before + 14] == M.BURNT_BUTTER["Base.Pot"])
run("give", "salted")
run("give", "clarified")
check("give spawns salted and clarified butter", player.given[before + 15] == M.SALTED_BUTTER
    and player.given[before + 16] == M.CLARIFIED_BUTTER)
local inventory = player:getInventory()
-- Kefir: given items answer for their modData and fluid.
local made = {}
local plainAdd = inventory.AddItem
function inventory:AddItem(fullType)
    plainAdd(self, fullType)
    local modData, fluids, name = {}, {}, fullType
    local item = { fullType = fullType, getModData = function() return modData end, modData = modData, fluids = fluids,
        getFluidContainer = function() return { Empty = function() end,
            addFluid = function(_, name, litres) fluids[name] = litres end } end,
        getFullType = function() return fullType end, getOutermostContainer = function() return nil end,
        getWorldItem = function() return nil end, getName = function() return name end,
        setName = function(_, text) name = text end, setCustomName = function() end }
    table.insert(made, item)
    return item
end
before = #player.given
run("kit", "kefir")
check("kit(\"kefir\") gives a packet, 25 live grains, pots of 2 L of cow's kefir and 1 L of cow's milk, a Strainer, a cloth, and a Sheet and 2 Stones",
    #player.given == before + 33
    and player.given[before + 1] == M.GRAIN_PACKET and player.given[before + 2] == M.GRAIN
    and made[2].modData[M.GRAIN_KEY].grainState == M.GRAIN_LIVE and made[26].modData[M.GRAIN_KEY].hour == 100
    and player.given[before + 27] == "Base.Pot" and made[27].fluids.CowKefir == 2
    and player.given[before + 28] == "Base.Pot" and made[28].fluids.CowMilk == 1
    and player.given[before + 29] == M.STRAINER and player.given[before + 30] == "Base.RippedSheets"
    and player.given[before + 31] == "Base.Sheet" and player.given[before + 33] == "Base.Stone2")
before = before + 3
run("give", "packet")
run("give", "dried", 3)
check("give spawns packets and dried grains", player.given[before + 31] == M.GRAIN_PACKET and player.given[before + 34] == M.DRIED_GRAIN
    and #player.given == before + 34)
check("give lists the kefir things", run("give"):find("packet, dried, grains, cloth", 1, true) ~= nil)
run("give", "cloth")
local cloth = made[#made]
check("give cloth: a Ripped Sheet of 10 grains, drying", player.given[before + 35] == M.GRAIN_DRYING
    and cloth.modData[M.DRYING_KEY].count == 10 and cloth.modData[M.DRYING_KEY].cloth == "Base.RippedSheets"
    and cloth:getName():find("Drying", 1, true) ~= nil)
check("a live grain given is named for its state", made[2]:getName() == getText("IGUI_TraditionalPreservationDairy_GrainName",
    getText("IGUI_TraditionalPreservationDairy_GrainLive")))
check("milk refuses what is neither milk nor kefir and names the kefirs", run("milk", 1, nil, "Water"):find("CowKefir", 1, true) ~= nil)
function inventory:getAllEvalRecurse() return { size = function() return 0 end } end
check("butter says so when you carry none", run("butter"):find("No Butter", 1, true) ~= nil)
check("rancid ages none", run("rancid", 5):find("Kept 0 butter for 5 days", 1, true) ~= nil)
check("grains says so when there are none", run("grains"):find("No Kefir Grains", 1, true) ~= nil)
check("starve starves none", run("starve"):find("0 item(s) by 48.0 hours", 1, true) ~= nil)

H.done()
