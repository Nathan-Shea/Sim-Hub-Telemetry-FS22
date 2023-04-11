---Util for field jobs







































































































































































































































































































































































---Returns amount of fruit to work is in given area
-- @param float startWorldX start world x
-- @param float startWorldZ start world z
-- @param float widthWorldX width world x
-- @param float widthWorldZ width world z
-- @param float heightWorldX height world x
-- @param float heightWorldZ height world z
-- @param table terrainDetailRequiredValueRanges terrain detail required value ranges
-- @param table terrainDetailProhibitValueRanges terrain detail prohibit value ranges
-- @param integer requiredfruittype required fruit type
-- @param integer requiredMinGrowthState required min growth state
-- @param integer requiredMaxGrowthState required max growth state
-- @param integer prohibitedFruitType prohibited fruit type
-- @param integer prohibitedMinGrowthState prohibited min growth state
-- @param integer prohibitedMaxGrowthState prohibited max growth state
-- @param boolean useWindrowed use windrow
-- @return float area area found
-- @return float totalArea total area checked
function FieldUtil.getFruitArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, terrainDetailRequiredValueRanges, terrainDetailProhibitValueRanges, requiredFruitType, requiredMinGrowthState, requiredMaxGrowthState, prohibitedFruitType, prohibitedMinGrowthState, prohibitedMaxGrowthState, useWindrowed)
    local query = g_currentMission.fieldCropsQuery

    local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)

    if requiredFruitType ~= FruitType.UNKNOWN then
        local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(requiredFruitType)
        if fruitTypeDesc ~= nil and fruitTypeDesc.terrainDataPlaneId ~= nil then
            if useWindrowed then
                return 0, 1
            end

            query:addRequiredCropType(fruitTypeDesc.terrainDataPlaneId, requiredMinGrowthState, requiredMaxGrowthState, fruitTypeDesc.startStateChannel, fruitTypeDesc.numStateChannels, 0, 0)--groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels) -- needs engine fix so we can use different mapId
        end
    end

    if prohibitedFruitType ~= FruitType.UNKNOWN then
        local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(prohibitedFruitType)
        if fruitTypeDesc ~= nil and fruitTypeDesc.terrainDataPlaneId ~= nil then
            query:addProhibitedCropType(fruitTypeDesc.terrainDataPlaneId, prohibitedMinGrowthState, prohibitedMaxGrowthState, fruitTypeDesc.startStateChannel, fruitTypeDesc.numStateChannels, groundTypeFirstChannel, groundTypeNumChannels)
        end
    end

    for _,valueRange in pairs(terrainDetailRequiredValueRanges) do
        query:addRequiredGroundValue(valueRange[1], valueRange[2], valueRange[3], valueRange[4])
    end
    for _,valueRange in pairs(terrainDetailProhibitValueRanges) do
        query:addProhibitedGroundValue(valueRange[1], valueRange[2], valueRange[3], valueRange[4])
    end

    local x,z, widthX,widthZ, heightX,heightZ = MathUtil.getXZWidthAndHeight(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    return query:getParallelogram(x,z, widthX,widthZ, heightX,heightZ, true)
end
