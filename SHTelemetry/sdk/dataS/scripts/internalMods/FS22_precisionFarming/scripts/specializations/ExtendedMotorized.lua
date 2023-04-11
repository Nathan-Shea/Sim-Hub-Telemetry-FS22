---Specialization to track fuel usage when vehicle is on a field














---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedMotorized.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end























---
function ExtendedMotorized:updateConsumers(superFunc, dt, accInput)
    superFunc(self, dt, accInput)

    local farmlandStatistics, isOnField, farmlandId = self:getPFStatisticInfo()
    if farmlandStatistics ~= nil and farmlandId ~= nil and isOnField then
        local spec = self.spec_motorized
        for _,consumer in pairs(spec.consumers) do
            if consumer.permanentConsumption and consumer.usage > 0 then
                local fillUnit = self:getFillUnitByIndex(consumer.fillUnitIndex)
                if fillUnit ~= nil and fillUnit.lastValidFillType == FillType.DIESEL then
                    farmlandStatistics:updateStatistic(farmlandId, "usedFuel", spec.lastFuelUsage / 60 / 60 / 1000 * dt)
                end
            end
        end
    end

end
