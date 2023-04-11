---Specialization to track vehicle wear costs














---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedWearable.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Wearable, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end





















---
function ExtendedWearable:onPostUpdateTick(dt, isActive, isActiveForInput, isSelected)
    local spec = self.spec_extendedWearable

    local damage = self.spec_wearable.damage
    if spec.lastDamage > 0 then
        local price = self:getPrice()
        local lastRepairPrice = Wearable.calculateRepairPrice(price, spec.lastDamage)
        local repairPrice = Wearable.calculateRepairPrice(price, damage)
        local repairCosts = repairPrice - lastRepairPrice
        if repairCosts > 0 then
            local farmlandStatistics, isOnField, farmlandId = self:getPFStatisticInfo()
            if isOnField then
                if farmlandStatistics ~= nil then
                    if farmlandId ~= nil then
                        farmlandStatistics:updateStatistic(farmlandId, "vehicleCosts", repairCosts)
                    end
                end
            end
        end
    end

    spec.lastDamage = damage
end
