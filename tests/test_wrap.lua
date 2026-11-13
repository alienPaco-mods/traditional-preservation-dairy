-- Checks wrapping a pot, jar or bucket in a Sheet and Twine (it keeps milk hot, keeps its capacity, and its name
-- says so), unwrapping it, the recipes' tests, and a wrap burning on the heat. Run from the mod folder:
-- luajit tests/test_wrap.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(10)
H.installModData()
H.installEvents()

-- A fluid container as the engine keeps it: the shown name is cached once read and nothing Lua can call clears it
-- (reset() is protected, add/removeComponent package-private), so only a new item shows a new name at once.
local function fluidContainer(name, capacity, rain)
    local c = { name = name, capacity = capacity, rain = rain, fluids = {} }
    function c:getContainerName() return self.name end
    function c:setContainerName(n) self.name = n end
    function c:getTranslatedContainerName()
        self.shown = self.shown or self.name
        return self.shown
    end
    function c:getCapacity() return self.capacity end
    function c:getRainCatcher() return self.rain end
    function c:setRainCatcher(v) self.rain = v end
    function c:copyFluidsFrom(other)
        self.fluids = {}
        for k, v in pairs(other.fluids) do self.fluids[k] = v end
    end
    return c
end

-- Each type as its script makes it.
local SCRIPT = { ["Base.Pot"] = { "Pot", 1.5, 0.8 }, ["Base.ClayJar"] = { "Jar", 2.5, 0.2 },
    ["Base.BucketCarved"] = { "Bucket", 10, 0.5 }, ["Base.WaterBottle"] = { "Bottle", 1, 0 },
    ["TraditionalPreservationDairy.WrappedYoghurtPot"] = { "WrappedYoghurtPot", 5, 0 } }

local function item(fullType)
    local script = SCRIPT[fullType]
    local it = { fullType = fullType, data = {}, heat = 1, condition = 10, favorite = false,
        fluid = script and fluidContainer(script[1], script[2], script[3]) }
    function it:getFullType() return self.fullType end
    function it:getModData() return self.data end
    function it:getFluidContainer() return self.fluid end
    function it:getContainer() return self.container end
    function it:getWorldItem() return self.worldItem end
    function it:getItemHeat() return self.heat end
    function it:setItemHeat(v) self.heat = v end
    function it:getCondition() return self.condition end
    function it:setCondition(v) self.condition = v end
    function it:isFavorite() return self.favorite end
    function it:setFavorite(v) self.favorite = v end
    return it
end
instanceItem = item

-- The player's inventory.
local bag = { items = {} }
function bag:AddItem(thing)
    if type(thing) == "string" then thing = item(thing) end
    thing.container = self
    table.insert(self.items, thing)
    return thing
end
function bag:contains(thing)
    for _, it in ipairs(self.items) do if it == thing then return true end end
    return false
end
function bag:DoRemoveItem(thing)
    for i, it in ipairs(self.items) do if it == thing then table.remove(self.items, i) thing.container = nil return end end
end
-- The item of a type in the bag now (a swap replaces it).
local function find(fullType)
    for _, it in ipairs(bag.items) do if it.fullType == fullType then return it end end
end
local function shown(it) return it.fluid:getTranslatedContainerName() end

dofile("42/media/lua/shared/TraditionalPreservationDairy.lua")
local M = TraditionalPreservationDairy

-- Wrapping
local pot = bag:AddItem("Base.Pot")
shown(pot) -- the inventory has read its name
check("a pot isn't wrapped to start with", not M.isWrapped(pot) and M.canWrap(pot) and not M.canUnwrap(pot))
check("it wraps", M.wrap(pot) and M.isWrapped(pot))
check("its name is changed in place, so it is saved", pot.fluid.name == "TPDWrappedPot")
H.fire("OnTick")
local wrapped = find("Base.Pot")
check("a tick later it is a new pot, so the new name shows at once", wrapped ~= pot and #bag.items == 1
    and shown(wrapped) == "TPDWrappedPot")
pot = wrapped
check("it shows as a pot bundled in towels, in the inventory and on the ground, after the swap too",
    pot.data.customInventoryIcon == "media/textures/Item_WrappedPot.png"
    and pot.data.worldStaticModel == "TraditionalPreservationDairy.TowelBundle_Pot")
check("it keeps its capacity and no longer catches rain", pot.fluid.capacity == 1.5 and pot.fluid.rain == 0)
check("it can't be wrapped twice, and can be unwrapped", not M.canWrap(pot) and M.canUnwrap(pot) and not M.wrap(pot))
check("a sheet or twine passes either recipe's test", M.canWrap(item("Base.Sheet")) and M.canUnwrap(item("Base.Twine")))
local jar, bucket = item("Base.ClayJar"), item("Base.BucketCarved")
M.wrap(jar)
M.wrap(bucket)
check("jars and buckets wrap under their own names, with their own capacity", jar.fluid.name == "TPDWrappedJar"
    and jar.fluid.capacity == 2.5 and bucket.fluid.name == "TPDWrappedBucket" and bucket.fluid.capacity == 10)
check("each wraps to its own look", jar.data.customInventoryIcon == "media/textures/Item_WrappedClayJar.png"
    and bucket.data.worldStaticModel == "TraditionalPreservationDairy.TowelBundle_BucketCarved")
check("anything else isn't wrapped", not M.wrap(item("Base.WaterBottle")))
H.fire("OnTick")
check("an item in no container keeps its own (its new name shows after a load)", jar.fluid.name == "TPDWrappedJar")

-- What it holds goes over with the swap
pot.fluid.fluids.ScaldedCowMilk = 1.2
pot.data.tpdCarry = { ml = 1200, c = 80 }
pot.heat, pot.favorite = 1.6, true
check("unwrapped, it is a plain pot again: name and rain back", M.unwrap(pot) and not M.isWrapped(pot)
    and pot.fluid.name == "Pot" and pot.fluid.rain == 0.8
    and pot.data.customInventoryIcon == nil and pot.data.worldStaticModel == nil)
H.fire("OnTick")
local plain = find("Base.Pot")
check("the new pot shows its name and holds the same milk, record, heat and favourite", plain ~= pot
    and shown(plain) == "Pot" and plain.fluid.fluids.ScaldedCowMilk == 1.2 and plain.data.tpdCarry.c == 80
    and plain.heat == 1.6 and plain.favorite == true and plain.fluid.rain == 0.8)
check("unwrapping a bare pot does nothing", not M.unwrap(plain))
pot = plain

-- The recipes find the kept pot, jar or bucket
local function recipe(...)
    local list = { ... }
    return { getAllKeepInputItems = function() return H.list(list) end }
end
M.onWrapped(recipe(item("Base.Sheet"), pot))
check("Wrap marks the kept pot", M.isWrapped(pot))
H.fire("OnTick")
pot = find("Base.Pot")
M.onUnwrapped(recipe(pot))
check("Unwrap takes the mark off", not M.isWrapped(pot))
H.fire("OnTick")
pot = find("Base.Pot")

-- Burning
M.wrap(pot)
H.fire("OnTick")
pot = find("Base.Pot")
pot.fluid.fluids.ScaldedCowMilk = 1.0
M.burnWrap(pot)
H.fire("OnTick")
local burnt = find("Base.Pot")
check("burnt, the wrap is gone and the milk stays", not M.isWrapped(burnt) and shown(burnt) == "Pot"
    and burnt.fluid.fluids.ScaldedCowMilk == 1.0)
local old = bag:AddItem(M.WRAPPED_POT)
local bare = M.burnWrap(old)
check("a Wrapped Yogurt Pot burns down to a bare Yogurt Pot", bare.fullType == "TraditionalPreservationDairy.YoghurtPot"
    and not bag:contains(old) and bag:contains(bare))
check("the Wrapped Yogurt Pot still counts as wrapped", M.isWrapped(item(M.WRAPPED_POT)))
check("a cold stove doesn't burn a wrap, the lowest setting does", M.BURN_HEAT > 1.0 and M.BURN_HEAT < 1.5)

-- Every wrapped look has its icon and its ground model
local script = io.open("42/media/scripts/TraditionalPreservationDairy_items.txt"):read("*a")
local looks = {}
for _, look in pairs(M.WRAPPED_LOOKS) do looks[look] = true end
for look in pairs(looks) do
    local icon = io.open("42/media/textures/Item_Wrapped" .. look .. ".png")
    check(look .. ": its icon is painted and its model declared", icon ~= nil
        and script:find("model TowelBundle_" .. look .. "\n", 1, true) ~= nil)
    if icon then icon:close() end
end
check("every wrappable container has a look", (function()
    for fullType in pairs(M.WRAPPABLE) do
        if not M.WRAPPED_LOOKS[fullType] then return false end
    end
    return true
end)())
check("the Wrapped Yogurt Pot lies as the bundle too", script:find("WorldStaticModel = TraditionalPreservationDairy.TowelBundle_ClayJar", 1, true) ~= nil)
io.open("42/media/Models_X/TowelBundle.glb"):close()
io.open("42/media/Models_X/TowelBundleTall.glb"):close()

H.done()
