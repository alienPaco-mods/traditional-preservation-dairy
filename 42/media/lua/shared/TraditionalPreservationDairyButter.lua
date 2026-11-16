-- Traditional Preservation (Dairy): butter that keeps. Vanilla's Butter never spoils; here it goes rancid by place on
-- TP Core's PlaceKeeping, as Potted Meat does: its days (30 fresh, 45 to rotten) are a 15 C cellar's, a fridge's
-- 4 C counts 0.4 of a day (about 75 / 110), a 20 C room 1.5 (about 20 / 30), 25 C and up 2 (about 15 / 22), frozen
-- nothing. Salted Butter, a salt worked in, keeps three times as long (90 / 120). Clarified Butter, melted in a pot,
-- a saucepan or the cauldron and strained off its milk solids, never spoils, as Lard. Required by
-- TraditionalPreservationDairy.lua, whose M it adds to.
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy
local PlaceKeeping = require "TraditionalPreservationCore/PlaceKeeping"
local Recipes = require "TraditionalPreservationCore/Recipes"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local ItemFluid = require "TraditionalPreservationCore/ItemFluid"

M.BUTTER = "Base.Butter"
M.SALTED_BUTTER = "TraditionalPreservationDairy.SaltedButter"
M.CLARIFIED_BUTTER = "TraditionalPreservationDairy.ClarifiedButter"

-- Days of age a day counts as at a temperature: a cellar's 15 C one, a fridge's 4 C 0.4, frozen hard nothing.
M.BUTTER_AGE_CURVE = { { -2, 0 }, { 4, 0.4 }, { 15, 1 }, { 20, 1.5 }, { 25, 2 } }
-- Fresh and rotten days in the cellar, set on each butter as it is first kept (vanilla's has none).
M.BUTTER_DAYS = {
    [M.BUTTER] = { 30, 45 },
    [M.SALTED_BUTTER] = { 90, 120 },
}
M.BUTTER_LEDGER_KEY = "TraditionalPreservationDairyButter"

-- The sandbox's "Butter keeps by place"; off, butter never spoils, as vanilla's.
function M.butterByPlace()
    local options = SandboxVars and SandboxVars.TraditionalPreservationDairy
    return not options or options.ButterByPlace ~= false
end

M.BUTTER_KEEPER = PlaceKeeping.new({
    kind = "butter", curve = M.BUTTER_AGE_CURVE, ledgerKey = M.BUTTER_LEDGER_KEY, modDataKey = "tpdKeep",
    enabled = M.butterByPlace, days = M.BUTTER_DAYS,
})

function M.keepButter(item, now, place, ledger)
    return M.BUTTER_KEEPER.keep(item, now, place, ledger)
end

-- An age carried from one food to another as vanilla's InheritFoodAge does: a share of fresh days, or past fresh a
-- share of the days to rotten. from and to are { fresh, rotten }.
function M.carryAge(age, from, to)
    if age <= from[1] then return age / from[1] * to[1] end
    return to[1] + math.min((age - from[1]) / (from[2] - from[1]), 1) * (to[2] - to[1])
end

-- OnCreate of Salt Butter: the salted butter starts as far into its days as the butter was into its own. Done here,
-- not by InheritFoodAge, as Salted Butter's script has no days for it to share.
function M.onSaltButter(craftRecipeData)
    local butter = Recipes.consumed(craftRecipeData, M.BUTTER)[1]
    if not butter or not M.butterByPlace() then return end
    M.keepButter(butter)
    local share = M.carryAge(butter:getAge(), M.BUTTER_DAYS[M.BUTTER], M.BUTTER_DAYS[M.SALTED_BUTTER])
    for _, salted in ipairs(Recipes.created(craftRecipeData, M.SALTED_BUTTER)) do
        local days = M.BUTTER_DAYS[M.SALTED_BUTTER]
        salted:setOffAge(days[1])
        salted:setOffAgeMax(days[2])
        salted:setAge(share)
        M.keepButter(salted)
    end
end

-- Clarifying: a pot or saucepan (TP Core's ItemFluid) and the Stone Hearth's cauldron are one route at two sizes.
-- Each butter goes in as BUTTER_PIECE_ML of MeltingButter (a Clarified Butter's worth); kept steaming
-- BUTTER_CLARIFY_HOURS its water is gone and it is MeltedClarifiedButter, strained (Strain Clarified Butter). Raw it
-- goes rancid when its oldest butter would have. In a pot or saucepan, held steaming BUTTER_BURN_HOURS more it burns:
-- the vessel is swapped for its burnt butter item (BURNT_BUTTER), which Scrape Out Burnt Butter gives back. The
-- cauldron never burns. Never rename the fluids once the mod is out: saves hold the names.
M.BUTTER_PIECE_ML = 250
M.BUTTER_CLARIFY_HOURS = 1
M.BUTTER_BURN_HOURS = 1
M.MELTING_BUTTER = "MeltingButter"
M.MELTED_CLARIFIED = "MeltedClarifiedButter"
M.RANCID_BUTTER = "RancidButter"
M.CAULDRON_BUTTERS = { [M.BUTTER] = true, [M.SALTED_BUTTER] = true }
-- Each vanilla pot and saucepan, and what it becomes burnt (no kettle).
M.BURNT_BUTTER = {
    ["Base.Pot"] = "TraditionalPreservationDairy.PotOfBurntButter",
    ["Base.PotForged"] = "TraditionalPreservationDairy.PotForgedBurntButter",
    ["Base.Saucepan"] = "TraditionalPreservationDairy.SaucepanBurntButter",
    ["Base.SaucepanCopper"] = "TraditionalPreservationDairy.SaucepanCopperBurntButter",
}
M.BUTTER_VESSELS = {}
for vessel in pairs(M.BURNT_BUTTER) do M.BUTTER_VESSELS[vessel] = true end
M.BUTTER_SKILL = 2               -- Cooking, for every step of salting and clarifying
CauldronFluid.turnsHot(M.MELTING_BUTTER, M.MELTED_CLARIFIED, M.BUTTER_CLARIFY_HOURS)
CauldronFluid.goesOff(M.MELTING_BUTTER, M.RANCID_BUTTER)
CauldronFluid.staysIn(M.MELTING_BUTTER)
CauldronFluid.staysIn(M.RANCID_BUTTER)
ItemFluid.turnsHot(M.MELTING_BUTTER, M.MELTED_CLARIFIED, M.BUTTER_CLARIFY_HOURS)
ItemFluid.goesOff(M.MELTING_BUTTER, M.RANCID_BUTTER)
ItemFluid.burns(M.MELTED_CLARIFIED, M.BUTTER_BURN_HOURS, M.BURNT_BUTTER)
ItemFluid.staysIn(M.MELTING_BUTTER)

-- Hours until a butter is rotten, brought up to now first. Its age runs at vanilla's Food Spoilage speed, so the
-- days it has left are that many days only at Normal.
function M.butterHoursLeft(item)
    M.keepButter(item)
    return (item:getOffAgeMax() - item:getAge()) * 24 / FluidAgeing.foodRotSpeed()
end
