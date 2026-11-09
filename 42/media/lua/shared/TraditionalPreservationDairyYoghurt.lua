-- Traditional Preservation (Dairy): every vanilla Yoghurt leaves an Empty Yoghurt Container, and a Jar of Yoghurt
-- names the cups it has left. ReplaceOnUse covers eating and the evolved Oatmeal (both go
-- through Use()); no vanilla craft takes a Yoghurt, so Salt's ISHandcraftAction wrap isn't needed here.
require "TraditionalPreservationDairy"
local M = TraditionalPreservationDairy

local YOGHURT = "Base.Yoghurt"

function M.applyYoghurtReplacement()
    local yoghurt = ScriptManager.instance:getItem(YOGHURT)
    if yoghurt then yoghurt:DoParam("ReplaceOnUse = " .. M.EMPTY_CUP) end
end

Events.OnInitGlobalModData.Add(M.applyYoghurtReplacement)

-- A Jar of Yoghurt says how many cups are left and weighs the empty jar plus what's still in it.
function M.labelJar(jar)
    local left = M.cupsLeft(jar:getModData())
    local base = getItemNameFromFullType(M.YOGHURT_JAR)
    jar:setName(left == 1 and getText("IGUI_TraditionalPreservationDairy_JarOneCup", base) or getText("IGUI_TraditionalPreservationDairy_JarCups", base, tostring(left)))
    jar:setCustomName(true)
    local empty = ScriptManager.instance:getItem(jar:getModData().tpdJar or "Base.ClayJar")
    jar:setActualWeight((empty and empty:getActualWeight() or 0) + left * M.CUP_KG)
end
