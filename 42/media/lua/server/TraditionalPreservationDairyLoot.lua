-- Traditional Preservation (Dairy): where Packets of Kefir Grains are found. Kefir grains are never made, only found:
-- a farm's storage shelves sometimes, a Gigamart's farming shelf rarely, a home fridge or kitchen cupboard very
-- rarely. Weights against vanilla's in the same lists: a farm shelf's seed packets 8, a Gigamart herb seed packet 1,
-- a home fridge's Butter 2, a kitchen's Yeast 10. Each list is one a room rolls (Distributions.lua): vanilla's
-- FridgeFarmStorage is defined but no room uses it.
require "Items/ProceduralDistributions"

local LOOT = {
    CrateFarming = 1,
    GigamartFarming = 1,
    FridgeGeneric = 0.2,
    KitchenDryFood = 0.5,
}

for distributionName, weight in pairs(LOOT) do
    local distribution = ProceduralDistributions.list[distributionName]
    if distribution and distribution.items then
        table.insert(distribution.items, "TraditionalPreservationDairy.KefirGrainsPacket")
        table.insert(distribution.items, weight)
    end
end
