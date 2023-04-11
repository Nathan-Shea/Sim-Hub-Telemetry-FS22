---Specialization to save is on field state and current farmland id on a central spot














---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PrecisionFarmingStatistic.prerequisitesPresent(specializations)
    return true
end





































---
function PrecisionFarmingStatistic:onUpdateTick(dt, isActive, isActiveForInput, isSelected)
    local spec = self.spec_precisionFarmingStatistic

    spec.lastUpdateDistance = spec.lastUpdateDistance + self.lastMovedDistance
    if spec.lastUpdateDistance > spec.updateDistance or spec.farmlandId == 0 then
        spec.lastUpdateDistance = 0
        local x, _, z = getWorldTranslation(self.rootNode)
        spec.farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
        spec.mission = g_missionManager:getMissionAtWorldPosition(x, z)

        local isOnField = self:getIsOnField()
        if isOnField ~= spec.isOnField then
            if isOnField then
                spec.isOnFieldSmoothed = true
            else
                spec.isOnFieldLastPos[1] = x
                spec.isOnFieldLastPos[2] = z
            end
        end

        if spec.isOnFieldSmoothed ~= isOnField then
            local distance = MathUtil.vector2Length(x - spec.isOnFieldLastPos[1], z - spec.isOnFieldLastPos[2])
            if distance > 20 then
                spec.isOnFieldSmoothed = isOnField
            end
        end

        spec.isOnField = isOnField
    end
end


---
function PrecisionFarmingStatistic:getPFStatisticInfo()
    local spec = self.spec_precisionFarmingStatistic
    return spec.farmlandStatistics, spec.isOnField, spec.farmlandId, spec.isOnFieldSmoothed, spec.mission
end


---
function PrecisionFarmingStatistic:getPFYieldMap()
    local spec = self.spec_precisionFarmingStatistic
    return spec.yieldMap
end
