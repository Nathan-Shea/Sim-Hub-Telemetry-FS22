---Specialization to track ai helper costs














---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedAIVehicle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end












---
function ExtendedAIVehicle:updateAIFieldWorkerLowFrequency(superFunc, dt)
    if self:getIsAIActive() then
        local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier;
        local price = -dt * difficultyMultiplier * AIJobFieldWork.getPricePerMs(nil)

        local farmlandStatistics, _, farmlandId = self:getPFStatisticInfo()
        if farmlandStatistics ~= nil then
            if farmlandId ~= nil then
                farmlandStatistics:updateStatistic(farmlandId, "helperCosts", -price)
            end
        end
    end

    superFunc(self, dt)
end
