-- Traditional Preservation (Dairy): every vanilla Yoghurt leaves an Empty Yoghurt Container, and a Jar of Yoghurt
-- portions into cups that keep the yoghurt's age. ReplaceOnUse covers eating and the evolved Oatmeal (both go
-- through Use()); no vanilla craft takes a Yoghurt, so Salt's ISHandcraftAction wrap isn't needed here.
require "TraditionalPreservationDairy"
local M = TraditionalPreservationDairy

local YOGHURT = "Base.Yoghurt"

function M.applyYoghurtReplacement()
    local yoghurt = ScriptManager.instance:getItem(YOGHURT)
    if yoghurt then yoghurt:DoParam("ReplaceOnUse = " .. M.EMPTY_CUP) end
end

Events.OnInitGlobalModData.Add(M.applyYoghurtReplacement)

-- Cups a part-full jar couldn't fill. They are only in the inventory once the craft is over, so they go on the
-- next tick, and each gives its empty container back.
local surplus = {}

local function takeSurplus()
    Events.OnTick.Remove(takeSurplus)
    for _, entry in ipairs(surplus) do
        local container = entry.item:getContainer()
        if container then
            container:DoRemoveItem(entry.item)
            Actions.addOrDropItem(entry.character, instanceItem(M.EMPTY_CUP))
        end
    end
    surplus = {}
end

-- PortionYoghurt: the jar comes back as the type it went in as, and every cup is as old as the yoghurt.
function M.onPortioned(craftRecipeData, character)
    local consumed = craftRecipeData:getAllConsumedItems()
    local jar
    for i = 0, consumed:size() - 1 do
        if consumed:get(i):getFullType() == M.YOGHURT_JAR then jar = consumed:get(i) end
    end
    if not jar then return end
    local data = jar:getModData()
    local cups = M.cupsFor(data.tpdMl or M.JAR_ML)
    Actions.addOrDropItem(character, instanceItem(data.tpdJar or "Base.ClayJar"))
    local created = craftRecipeData:getAllCreatedItems()
    for i = 0, created:size() - 1 do
        local cup = created:get(i)
        cup:setAge(jar:getAge())
        if i >= cups then table.insert(surplus, { item = cup, character = character }) end
    end
    if #surplus > 0 then Events.OnTick.Add(takeSurplus) end
end
