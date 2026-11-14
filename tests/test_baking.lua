-- Checks the milk lines Dairy gives vanilla baking. Run from the mod folder: luajit tests/test_baking.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
local Recipes = require "TraditionalPreservationCore/Recipes"

local ALL = "AnimalMilk;CowMilk;SheepMilk;ScaldedAnimalMilk;ScaldedCowMilk;ScaldedSheepMilk;SourAnimalMilk;SourCowMilk;SourSheepMilk"
local extra = M.bakingMilks()
check("cake batter: cow's milk only becomes every milk, fresh, scalded or soured",
    Recipes.widenLine("fluid 1.0 [CowMilk]", extra) == "fluid 1.0 [CowMilk;AnimalMilk;SheepMilk;ScaldedAnimalMilk;ScaldedCowMilk;ScaldedSheepMilk;SourAnimalMilk;SourCowMilk;SourSheepMilk]")
check("cereal: cow's and sheep's gain the rest",
    Recipes.widenLine("fluid 0.3 [CowMilk;SheepMilk]", extra) == "fluid 0.3 [CowMilk;SheepMilk;AnimalMilk;ScaldedAnimalMilk;ScaldedCowMilk;ScaldedSheepMilk;SourAnimalMilk;SourCowMilk;SourSheepMilk]")
check("a widened line is left alone", Recipes.widenLine("fluid 1.0 [" .. ALL .. "]", extra) == nil)
check("no rotten milk anywhere", not Recipes.widenLine("fluid 1.0 [CowMilk]", extra):find("Rotten"))
check("water is no milk", Recipes.widenLine("fluid 1.0 [Water]", extra) == nil)

local scalded = M.scaldedMilks()
check("butter: each milk takes its scalded twin, and no other",
    Recipes.widenLine("fluid 5.0 [CowMilk;SheepMilk] mode:mixture", scalded) == "fluid 5.0 [CowMilk;SheepMilk;ScaldedCowMilk;ScaldedSheepMilk] mode:mixture")
check("mildew cure: all three scalded, never soured",
    Recipes.widenLine("fluid 1.0 [CowMilk;SheepMilk;AnimalMilk]", scalded) == "fluid 1.0 [CowMilk;SheepMilk;AnimalMilk;ScaldedCowMilk;ScaldedSheepMilk;ScaldedAnimalMilk]")
check("scalded milk is milk to the cauldron and the pot", M.MILKS.ScaldedSheepMilk and M.MILK_FOOD.ScaldedSheepMilk == M.MILK_FOOD.SheepMilk)

H.done()
