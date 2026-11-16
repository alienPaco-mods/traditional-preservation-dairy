-- Checks kefir (TraditionalPreservationDairyKefir.lua): its fluids against their milks, going off on TP Core's
-- FluidAgeing, the cure through TP Core's Drink, the grain records, the packet and the loot. Run from the mod folder:
-- luajit tests/test_kefir.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Drink = require "TraditionalPreservationCore/Drink"

local function read(path)
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    return text
end

-- Each fluid's Properties block from the fluid script: { name = { Property = number } }.
local fluids = {}
for name, body in read("42/media/scripts/TraditionalPreservationDairy_fluids.txt"):gmatch("fluid (%w+)%s*(%b{})") do
    local props = {}
    for key, number in (body:match("Properties%s*(%b{})") or ""):gmatch("(%w+) = (%-?[%d.]+)") do props[key] = tonumber(number) end
    props.hazardous = body:find("Hazardous") ~= nil
    fluids[name] = props
end

-- Fluids
local LACTOSE_KCAL, LACTOSE_G = 25, 6
for milk, kefir in pairs(M.KEFIRS) do
    local food, k = M.MILK_FOOD[milk], fluids[kefir]
    check(kefir .. ": its milk's food less the lactose, hunger and thirst as milk",
        k and k.Calories == food.calories - LACTOSE_KCAL and k.Carbohydrates == food.carbohydrates - LACTOSE_G
        and k.Lipids == food.lipids and k.Proteins == food.proteins and k.HungerChange == -50 and k.ThirstChange == -50
        and not k.UnhappyChange and not k.hazardous)
    local separated = fluids[M.SEPARATED_KEFIRS[kefir]]
    check(kefir .. ": separated keeps the food with a little unhappiness, as soured milk",
        separated and separated.Calories == k.Calories and separated.UnhappyChange == 10 and not separated.hazardous)
    local rotten = fluids[M.ROTTEN_KEFIRS[kefir]]
    check(kefir .. ": rotten is hazardous, as rotten milk", rotten and rotten.hazardous and rotten.UnhappyChange == 30
        and not rotten.Calories)
end
check("no kefir carries a foodSicknessChange (it never reaches the drinker: TP Core's Drink does it)",
    not read("42/media/scripts/TraditionalPreservationDairy_fluids.txt"):find("FoodSickness"))

-- Going off
local kefir = FluidAgeing.fluidKind(M.KEFIR_PROCESS)
check("kefir ages on its own kind, at milk's rate", kefir and kefir.process == "kefir" and kefir.rate == M.milkRate)
local fluidAge = { process = M.KEFIR_PROCESS, age = 0 }
check("fresh at first", FluidAgeing.stage(fluidAge, kefir) == "Fresh")
fluidAge.age = 71.9
check("still fresh just short of 3 days at 20 C", FluidAgeing.stage(fluidAge, kefir) == "Fresh")
fluidAge.age = 72
check("separated at 3 days", FluidAgeing.stage(fluidAge, kefir) == "Turned")
fluidAge.age = 240
check("rotten at 10 days", FluidAgeing.stage(fluidAge, kefir) == "Spoiled")
check("each kefir separates to its own and rots to its own", kefir.fresh.SheepKefir == "SeparatedSheepKefir"
    and kefir.spoiledOf.SeparatedCowKefir == "RottenCowKefir" and kefir.spoiledOf.SheepKefir == "RottenSheepKefir")
check("a 15 C basement keeps it twice as long as a 20 C room, a fridge about five times",
    near(M.milkRate(15), 0.5) and M.milkRate(4) < 0.2)

-- The cure
local opened, started = {}, {}
local eased = Drink.eased({ SheepKefir = 1 }, { SheepKefir = 0.25 }, opened, function() return true end,
    function(key, hours) started[key] = hours end, true)
check("fresh kefir eases 10 food sickness a litre drunk", near(eased, 7.5))
check("on the shared foodSickness cooldown of 3 game hours", started.foodSickness == 3)
check("separated kefir eases nothing", Drink.eased({ SeparatedCowKefir = 1 }, { SeparatedCowKefir = 0 }, {},
    function() return true end, function() end, true) == 0)

-- Grains
local grain = M.newGrain(nil, 100)
check("a new grain is live, at no reactivation stage, set now", grain.grainState == M.GRAIN_LIVE and grain.stage == 0 and grain.hour == 100)
local share, grows = M.grainShare(grain)
check("a live grain counts 1 and grows", share == 1 and grows)
share, grows = M.grainShare(M.newGrain(M.GRAIN_HUNGRY, 0))
check("a hungry one counts half and doesn't grow", share == 0.5 and not grows)
share, grows = M.grainShare(M.newGrain(M.GRAIN_REACTIVATING, 0))
check("one coming back from dried counts half and doesn't grow", share == 0.5 and not grows)
check("a dead one counts nothing", M.grainShare(M.newGrain(M.GRAIN_DEAD, 0)) == 0)
local itemModData = {}
local item = { getModData = function() return itemModData end }
local first = M.grainOf(item, 5)
check("a grain with no record gets a live one, kept under its key", first.grainState == M.GRAIN_LIVE and itemModData[M.GRAIN_KEY] == first
    and M.grainOf(item, 9) == first and first.hour == 5)

-- Items, the packet and the loot
local items = read("42/media/scripts/TraditionalPreservationDairy_items.txt")
for _, name in ipairs({ "KefirGrainsPacket", "DriedKefirGrains", "KefirGrains" }) do
    local body = items:match("item " .. name .. "%s*(%b{})")
    check(name .. ": a plain item (never eaten) with its icon", body and body:find("ItemType = base:normal")
        and body:find("Icon = " .. name) and io.open("42/media/textures/Item_" .. name .. ".png") ~= nil)
end
check("a grain weighs a gram", items:match("item KefirGrains%s*(%b{})"):find("Weight = 0.001"))
local recipe = read("42/media/scripts/TraditionalPreservationDairy.txt"):match("craftRecipe OpenKefirGrainsPacket%s*(%b{})")
check("a packet opens into 10 dried grains, as a seed packet, on a double click", recipe
    and recipe:find("item " .. M.GRAINS_IN_PACKET .. " TraditionalPreservationDairy.DriedKefirGrains")
    and items:match("item KefirGrainsPacket%s*(%b{})"):find("DoubleClickRecipe = OpenKefirGrainsPacket"))
check("no recipe makes grains", not read("42/media/scripts/TraditionalPreservationDairy.txt"):find("item %d+ TraditionalPreservationDairy.KefirGrains[^P]"))

ProceduralDistributions = { list = { CrateFarming = { items = { "WheatBagSeed", 8 } }, GigamartFarming = { items = {} },
    FridgeGeneric = { items = {} }, KitchenDryFood = { items = {} } } }
package.preload["TraditionalPreservationDairy"] = function() return true end
dofile("42/media/lua/server/TraditionalPreservationDairyLoot.lua")
local function weightIn(list)
    local lootItems = ProceduralDistributions.list[list].items
    for i = 1, #lootItems, 2 do
        if lootItems[i] == M.GRAIN_PACKET then return lootItems[i + 1] end
    end
end
check("packets on farm storage shelves and a Gigamart's farming shelf, very rarely in a home fridge or kitchen cupboard",
    weightIn("CrateFarming") == 1 and weightIn("GigamartFarming") == 1 and weightIn("FridgeGeneric") == 0.2
    and weightIn("KitchenDryFood") == 0.5 and ProceduralDistributions.list.CrateFarming.items[2] == 8)
-- Every list must be one a room rolls: vanilla's Distributions.lua names it.
local game = os.getenv("PZ_GAME") or (os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid")
local distributions = io.open(game .. "/media/lua/server/Items/Distributions.lua")
if distributions then
    local text = distributions:read("*a")
    distributions:close()
    for _, list in ipairs({ "CrateFarming", "GigamartFarming", "FridgeGeneric", "KitchenDryFood" }) do
        check(list .. " is rolled by some room", text:find('name="' .. list .. '"', 1, true) ~= nil)
    end
end

-- Names: every kefir is called Kefir, and there are only two, so no mix reads Mixed Beverages (three types or more)
local names = read("42/media/lua/shared/Translate/EN/Fluids.json")
local kinds = {}
for milk, kefir in pairs(M.KEFIRS) do kinds[kefir] = true end
local count = 0
for kefir in pairs(kinds) do
    count = count + 1
    check(kefir .. ": called Kefir (Fresh), (Separated), (Rotten)", names:find('"Fluid_Name_' .. kefir .. '": "Kefir (Fresh)"', 1, true)
        and names:find('"Fluid_Name_Separated' .. kefir .. '": "Kefir (Separated)"', 1, true)
        and names:find('"Fluid_Name_Rotten' .. kefir .. '": "Kefir (Rotten)"', 1, true))
end
check("two kefirs only: animal's milk (cow's food) makes the cow's", count == 2 and M.KEFIRS.AnimalMilk == "CowKefir"
    and M.MILK_FOOD.AnimalMilk.calories == M.MILK_FOOD.CowMilk.calories and not fluids.AnimalKefir)
check("scalded milk makes its milk's kefir", M.KEFIRS.ScaldedSheepMilk == "SheepKefir" and M.KEFIRS.ScaldedAnimalMilk == "CowKefir")

H.done()
