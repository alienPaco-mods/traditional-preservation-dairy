-- Traditional Preservation (Dairy): wrapping. A vanilla pot, jar or bucket wrapped in a Sheet and Twine keeps milk hot
-- as the Wrapped Yogurt Pot does; this file renames, marks and dresses it, and burns the wrap in a hot cooking
-- container. Required by TraditionalPreservationDairy.lua, whose M it adds to.
local Action = require "TraditionalPreservationCore/Action"
TraditionalPreservationDairy = TraditionalPreservationDairy or {}
local M = TraditionalPreservationDairy

M.WRAPPED_POT = "TraditionalPreservationDairy.WrappedYoghurtPot"

-- Wrapping: a vanilla pot, jar or bucket, empty, wrapped in a Sheet tied with Twine, keeps milk hot as the Wrapped
-- Yogurt Pot does, and keeps its own capacity. The mark is the fluid container's own name, which the game saves and
-- the inventory shows ("Pot" becomes "TPDWrappedPot", "Wrapped Pot"); the old name and rain factor are kept in
-- modData WRAP_KEY. A wrapped item seen in a hot cooking container burns its wrap (World).
M.WRAP_KEY = "tpdWrapped"     -- { name, rain }
M.WRAPPABLE = {
    ["Base.Pot"] = true, ["Base.PotForged"] = true,
    ["Base.EmptyJar"] = true, ["Base.JarCrafted"] = true, ["Base.ClayJar"] = true, ["Base.ClayJarGlazed"] = true,
    ["Base.Bucket"] = true, ["Base.BucketEmpty"] = true, ["Base.BucketCarved"] = true,
}
M.WRAPPED_NAMES = { Pot = "TPDWrappedPot", Jar = "TPDWrappedJar", Bucket = "TPDWrappedBucket" }
-- What a wrapped one looks like: its own icon bundled in towels (tools/build_tileset.py) and, on the ground, the towel
-- bundle sized to it (tools/build_model.py, the TowelBundle_* models). Both go on the item's modData, which the engine
-- reads first and saves: customInventoryIcon and worldStaticModel.
M.WRAPPED_LOOKS = {
    ["Base.Pot"] = "Pot", ["Base.PotForged"] = "PotForged",
    -- The glazed jar is the ceramic one's shape: the same bundle.
    ["Base.EmptyJar"] = "Jar", ["Base.JarCrafted"] = "Jar", ["Base.ClayJar"] = "ClayJar", ["Base.ClayJarGlazed"] = "ClayJar",
    ["Base.Bucket"] = "Bucket", ["Base.BucketEmpty"] = "Bucket", ["Base.BucketCarved"] = "BucketCarved",
}

local function setLook(item, look)
    local modData = item:getModData()
    modData.customInventoryIcon = look and ("media/textures/Item_Wrapped" .. look .. ".png") or nil
    modData.worldStaticModel = look and ("TraditionalPreservationDairy.TowelBundle_" .. look) or nil
end

function M.isWrapped(item)
    return item:getFullType() == M.WRAPPED_POT or item:getModData()[M.WRAP_KEY] ~= nil
end

-- Gives an item's fluid container another name, in place: the game saves it, so it shows from the next load. Vanilla
-- caches the shown name and nothing Lua can call clears it (reset() is protected, add/removeComponent package-private:
-- ENGINE_NOTES), so to show it now the item is swapped a tick later for a new one of its type (M.refreshName). The
-- wait matters: a recipe still holds its kept item while OnCreate runs.
local function rename(item, name, rain)
    local container = item:getFluidContainer()
    container:setContainerName(name)
    container:setRainCatcher(rain)
    M.refreshName(item)
end

local renamed = {}

-- A new item of the same type, given the old one's fluid container name, fluids, rain, ModData, heat, condition and
-- favourite before its name is ever shown, in the old one's place. Items on the floor keep theirs (shown after a
-- load). Returns the new item, or nil.
function M.swapForFresh(item)
    local container = item:getContainer()
    if not container or item:getWorldItem() or not container:contains(item) then return nil end
    local new = instanceItem(item:getFullType())
    local old, fresh = item:getFluidContainer(), new and new:getFluidContainer()
    if not old or not fresh then return nil end
    fresh:setContainerName(old:getContainerName())
    fresh:setRainCatcher(old:getRainCatcher())
    fresh:copyFluidsFrom(old)
    local modData = new:getModData()
    for key, field in pairs(item:getModData()) do modData[key] = field end
    new:setItemHeat(item:getItemHeat())
    new:setCondition(item:getCondition())
    new:setFavorite(item:isFavorite())
    Action.removeItem(item)
    container:AddItem(new)
    return new
end

function M.refreshName(item)
    table.insert(renamed, item)
end

local function onTick()
    if #renamed == 0 then return end
    local toSwap = renamed
    renamed = {}
    for _, item in ipairs(toSwap) do M.swapForFresh(item) end
end

Events.OnTick.Add(onTick)

-- Wraps a pot, jar or bucket: it no longer catches rain under its cloth.
function M.wrap(item)
    local container = item:getFluidContainer()
    if not container or not M.WRAPPABLE[item:getFullType()] or M.isWrapped(item) then return false end
    local name, rain = container:getContainerName(), container:getRainCatcher()
    -- Marked only once renamed, so a rename that fails leaves a plain item.
    setLook(item, M.WRAPPED_LOOKS[item:getFullType()])
    rename(item, M.WRAPPED_NAMES[name] or "TPDWrappedPot", 0)
    item:getModData()[M.WRAP_KEY] = { name = name, rain = rain }
    return true
end

function M.unwrap(item)
    local modData = item:getModData()
    local was = modData[M.WRAP_KEY]
    local container = item:getFluidContainer()
    if not was or not container then return false end
    setLook(item, nil)
    rename(item, was.name, was.rain or 0)
    modData[M.WRAP_KEY] = nil
    return true
end

-- Recipes: the wrap goes on a pot, jar or bucket not yet wrapped, and comes off a wrapped one (both only when empty,
-- by the recipe's flag). Other inputs (the Sheet, the Twine) pass.
function M.canWrap(item)
    return not M.WRAPPABLE[item:getFullType()] or not M.isWrapped(item)
end

function M.canUnwrap(item)
    return not M.WRAPPABLE[item:getFullType()] or M.isWrapped(item)
end

local function keptCarrier(craftRecipeData)
    local items = craftRecipeData:getAllKeepInputItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if M.WRAPPABLE[item:getFullType()] then return item end
    end
end

function M.onWrapped(craftRecipeData)
    local item = keptCarrier(craftRecipeData)
    if item then M.wrap(item) end
end

function M.onUnwrapped(craftRecipeData)
    local item = keptCarrier(craftRecipeData)
    if item then M.unwrap(item) end
end

-- Burnt in a hot cooking container: the Sheet and the Twine are gone. A wrapped pot, jar or bucket is itself again;
-- the Wrapped Yogurt Pot is a bare Yogurt Pot, which holds no fluid (its milk is lost). Returns the item now there.
M.BURN_HEAT = 1.3             -- a container this hot burns a wrap (vanilla: 1.0 cold; the lowest stove setting about 1.5)

function M.burnWrap(item)
    if item:getFullType() ~= M.WRAPPED_POT then
        M.unwrap(item)
        return item
    end
    local container = item:getContainer()
    if not container then return item end
    local bare = container:AddItem("TraditionalPreservationDairy.YoghurtPot")
    Action.removeItem(item)
    return bare
end
