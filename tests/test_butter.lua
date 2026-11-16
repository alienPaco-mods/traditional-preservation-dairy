-- Checks butter that keeps (TraditionalPreservationDairyButter.lua): rancid by place, salted, clarified in a pot or
-- the cauldron. Run from the
-- mod folder: luajit tests/test_butter.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(0)
H.installModData()
H.installEvents()

dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy
local keeper = M.BUTTER_KEEPER

local function food(fullType, offAge, offAgeMax, age)
    local self = { fullType = fullType, offAge = offAge or 1e9, offAgeMax = offAgeMax or 1e9, age = age or 0, modData = {},
        weight = 1.3, condition = 10 }
    function self:getFullType() return self.fullType end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:setOffAge(x) self.offAge = x end
    function self:setOffAgeMax(x) self.offAgeMax = x end
    function self:getAge() return self.age end
    function self:setAge(x) self.age = x end
    function self:getModData() return self.modData end
    function self:getOutermostContainer() return nil end
    function self:getWorldItem() return nil end
    function self:getDisplayName() return self.fullType end
    function self:getScriptItem() return { getActualWeight = function() return 1.3 end } end
    function self:setActualWeight(x) self.weight = x end
    function self:setCustomWeight(x) self.custom = x end
    function self:getCondition() return self.condition end
    function self:setCondition(x) self.condition = x end
    function self:isCooked() return self.cooked == true end
    function self:isBurnt() return self.burnt == true end
    return self
end

local function jlist(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end
local function craft(consumed, created, character)
    return { getAllConsumedItems = function() return jlist(consumed) end,
        getAllCreatedItems = function() return jlist(created) end,
        getCharacter = function() return character end }
end

-- Keeping by place
local ledger = keeper.ledger()
ledger.seasonTemperature, ledger.groundTemperature, ledger.temperature = 25, 23.125, 15
check("a cellar day is a day", keeper.ageRate(15) == 1)
check("plain butter: 30 days fresh in a cellar, about 75 in a fridge", near(30 / keeper.rate("Fridge", ledger), 75))
check("about 20 at 20 C, 15 at 25 C and over", near(30 / keeper.ageRate(20), 20) and near(30 / keeper.ageRate(30), 15))
check("frozen hard, or a powered freezer, nothing", keeper.ageRate(-5) == 0 and keeper.rate("Freezer", ledger) == 0)
check("a summer basement (about 15 C) keeps it about a month", near(30 / keeper.rate("Basement", ledger), 28, 2))

local butter = food(M.BUTTER, 1e9, 1e9, 0)
M.keepButter(butter, 0, "Basement", ledger)
check("vanilla's butter, never spoiling, gets its days on the first look", butter.offAge == 30 and butter.offAgeMax == 45)
local salted = food(M.SALTED_BUTTER)
M.keepButter(salted, 0, "Basement", ledger)
check("salted butter three times as long", salted.offAge == 90 and salted.offAgeMax == 120)
check("clarified butter is not kept: it never spoils", M.BUTTER_DAYS[M.CLARIFIED_BUTTER] == nil)

-- Salting carries the age as a share of the days
check("a butter half through its fresh days salts half through the salted ones", near(M.carryAge(15, { 30, 45 }, { 90, 120 }), 45))
check("a stale one as far through the stale days", near(M.carryAge(40, { 30, 45 }, { 90, 120 }), 110))
check("a rotten one stays rotten", near(M.carryAge(60, { 30, 45 }, { 90, 120 }), 120))
local old = food(M.BUTTER, 30, 45, 10)
local made = food(M.SALTED_BUTTER)
M.onSaltButter(craft({ old }, { made }))
check("Salt Butter: its days and a third of them gone, as the butter's", made.offAge == 90 and made.offAgeMax == 120
    and near(made.age, 30) and made.modData.tpdKeep ~= nil)

-- A pot or saucepan (TP Core's ItemFluid): the cauldron's route at a smaller size, and it can burn
local ItemFluid = require "TraditionalPreservationCore/ItemFluid"
check("a pot takes 6 butter, a saucepan 2", ItemFluid.pieceRoom(1.5, 0, false, M.BUTTER_PIECE_ML) == 6
    and ItemFluid.pieceRoom(0.6, 0, false, M.BUTTER_PIECE_ML) == 2)
local potRecord = {}
ItemFluid.putPieces(potRecord, { 45 * 24, 20 * 24 }, 0)
check("in a pot it goes rancid when the older butter would have", near(potRecord.offAt, 20 * 24))
local potFluid, potBurnt = M.MELTING_BUTTER, false
for minute = 0, 62 do potFluid = ItemFluid.advance(potRecord, potFluid, minute / 60, true, "Base.Saucepan") end
check("steamed an hour it is clarified", potFluid == M.MELTED_CLARIFIED)
for minute = 63, 125 do
    potFluid, potBurnt = ItemFluid.advance(potRecord, potFluid, minute / 60, true, "Base.Saucepan")
    if potBurnt then break end
end
check("an hour more and it burns", potBurnt)
local vessels = 0
for vessel, burnt in pairs(M.BURNT_BUTTER) do
    vessels = vessels + 1
    check(vessel .. " burns to a Dairy item", ItemFluid.burntItem(M.MELTED_CLARIFIED, vessel) == burnt
        and M.BUTTER_VESSELS[vessel] and burnt:match("^TraditionalPreservationDairy%."))
end
check("both pots and both saucepans, no kettle", vessels == 4 and not M.BUTTER_VESSELS["Base.Kettle"])
check("the cauldron's butter never burns", ItemFluid.burntItem(M.MELTED_CLARIFIED, "Base.Bucket") == nil)

-- The cauldron: a butter a quarter litre, raw it stays in and goes rancid by its oldest butter
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local cauldron = {}
local fresh, older = food(M.BUTTER, 30, 45, 0), food(M.SALTED_BUTTER, 90, 120, 100)
local left = { M.butterHoursLeft(fresh), M.butterHoursLeft(older) }
check("a fresh butter has 45 days to rotten, a salted one at 100 days 20", near(left[1], 45 * 24) and near(left[2], 20 * 24))
check("two butter go in as half a litre of melting butter", CauldronFluid.putPieces(cauldron, M.MELTING_BUTTER, M.BUTTER_PIECE_ML, left, 0) == 2
    and cauldron.ml == 500 and cauldron.fluid == M.MELTING_BUTTER)
check("it goes rancid when the older would have", near(cauldron.offAt, 20 * 24))
check("melting butter can't be ladled out", not CauldronFluid.poursOut(cauldron))
check("and takes no fat", CauldronFluid.pieceRoom(cauldron, "RawPorkFat", 250) == 0)

-- Keeping by place off: butter never spoils, as vanilla's
SandboxVars = { TraditionalPreservationDairy = { ButterByPlace = false } }
local plain = food(M.BUTTER, 1e9, 1e9, 4)
check("off, butter gets no clock and no days", M.keepButter(plain, 10, "Sheltered", ledger) == nil and plain.offAge == 1e9)
local plainSalted = food(M.SALTED_BUTTER)
M.onSaltButter(craft({ plain }, { plainSalted }))
check("and salting leaves the salted butter never spoiling", plainSalted.offAge == 1e9 and plainSalted.age == 0)
SandboxVars = nil

H.done()
