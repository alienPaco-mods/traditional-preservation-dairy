-- Traditional Preservation (Dairy): butter that keeps. Vanilla's Butter never spoils; here it goes rancid by place on
-- TP Core's PlaceKeeping, as Potted Meat does: its days (30 fresh, 45 to rotten) are a 15 C cellar's, a fridge's
-- 4 C counts 0.4 of a day (about 75 / 110), a 20 C room 1.5 (about 20 / 30), 25 C and up 2 (about 15 / 22), frozen
-- nothing. Salted Butter, a salt worked in, keeps three times as long (90 / 120). Clarified Butter, cooked in a pot
-- and poured off its milk solids, never spoils, as Lard. Required by TraditionalPreservationDairy.lua, whose M it
-- adds to.
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy
local PlaceKeeping = require "TraditionalPreservationCore/PlaceKeeping"
local Recipes = require "TraditionalPreservationCore/Recipes"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

M.BUTTER = "Base.Butter"
M.SALTED_BUTTER = "TraditionalPreservationDairy.SaltedButter"
M.CLARIFIED_BUTTER = "TraditionalPreservationDairy.ClarifiedButter"
M.BUTTER_POTS = {
    ["TraditionalPreservationDairy.PotOfButter"] = true,
    ["TraditionalPreservationDairy.PotForgedButter"] = true,
}
M.BUTTER_POT_MAX = 2
M.BUTTER_POT_KEY = "tpdButter"            -- the pot's count of butter
M.BUTTER_WEIGHT = 0.3

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

-- The pot's butter

function M.butterInPot(pot)
    return pot:getModData()[M.BUTTER_POT_KEY] or 1
end

local function setButterInPot(pot, count)
    pot:getModData()[M.BUTTER_POT_KEY] = count
    pot:setActualWeight(pot:getScriptItem():getActualWeight() + (count - 1) * M.BUTTER_WEIGHT)
    pot:setCustomWeight(true)
end

-- OnCreate of Put Butter in a Pot: one butter in.
function M.onPutButterInPot(craftRecipeData)
    for _, pot in ipairs(Recipes.created(craftRecipeData, M.BUTTER_POTS)) do setButterInPot(pot, 1) end
end

-- OnTest of Add Butter to the Pot: an uncooked pot with room for another.
function M.canAddButter(item)
    if not M.BUTTER_POTS[item:getFullType()] then return true end
    return M.butterInPot(item) < M.BUTTER_POT_MAX and not item:isCooked() and not item:isBurnt()
end

-- OnCreate of Add Butter to the Pot: the pot comes back as itself (sameItem) with one more.
function M.onAddButter(craftRecipeData)
    local pot = Recipes.consumed(craftRecipeData, M.BUTTER_POTS)[1]
    if not pot then return end
    for _, made in ipairs(Recipes.created(craftRecipeData, M.BUTTER_POTS)) do
        made:setAge(pot:getAge())
        made:setCondition(pot:getCondition())
        setButterInPot(made, M.butterInPot(pot) + 1)
    end
end

-- OnTest of Pour Off Clarified Butter: the recipe's cooked-food flag lets burnt food through, and burnt butter
-- gives nothing.
function M.canPourOffClarified(item)
    if not M.BUTTER_POTS[item:getFullType()] then return true end
    return not item:isBurnt()
end

-- OnCreate of Pour Off Clarified Butter: the recipe gives one; a pot of two gives the second to the cook.
function M.onPourOffClarified(craftRecipeData, character)
    character = character or craftRecipeData:getCharacter()
    local pot = Recipes.consumed(craftRecipeData, M.BUTTER_POTS)[1]
    if not pot or not character then return end
    for _ = 2, M.butterInPot(pot) do character:getInventory():AddItem(M.CLARIFIED_BUTTER) end
end

-- OnTest of Scrape Out Burnt Butter: only a burnt pot.
function M.canScrapeButter(item)
    if not M.BUTTER_POTS[item:getFullType()] then return true end
    return item:isBurnt()
end

-- The Stone Hearth's cauldron clarifies many at once. Each butter goes in as BUTTER_PIECE_ML of MeltingButter (a
-- Clarified Butter's worth); kept steaming BUTTER_CLARIFY_HOURS its water is gone and it is MeltedClarifiedButter,
-- ladled out and strained (Strain Clarified Butter). Raw it stays in the cauldron and goes rancid when its oldest
-- butter would have. Never rename the fluids once the mod is out: saves hold the names.
M.BUTTER_PIECE_ML = 250
M.BUTTER_CLARIFY_HOURS = 1
M.MELTING_BUTTER = "MeltingButter"
M.MELTED_CLARIFIED = "MeltedClarifiedButter"
M.RANCID_BUTTER = "RancidButter"
M.CAULDRON_BUTTERS = { [M.BUTTER] = true, [M.SALTED_BUTTER] = true }
M.BUTTER_SKILL = 2               -- Cooking, for every step of salting and clarifying
CauldronFluid.turnsHot(M.MELTING_BUTTER, M.MELTED_CLARIFIED, M.BUTTER_CLARIFY_HOURS)
CauldronFluid.goesOff(M.MELTING_BUTTER, M.RANCID_BUTTER)
CauldronFluid.staysIn(M.MELTING_BUTTER)
CauldronFluid.staysIn(M.RANCID_BUTTER)

-- Hours until a butter is rotten, brought up to now first. Its age runs at vanilla's Food Spoilage speed, so the
-- days it has left are that many days only at Normal.
function M.butterHoursLeft(item)
    M.keepButter(item)
    return (item:getOffAgeMax() - item:getAge()) * 24 / FluidAgeing.foodRotSpeed()
end
