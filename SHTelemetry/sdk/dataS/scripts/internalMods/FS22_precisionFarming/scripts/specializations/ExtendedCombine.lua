---Specialization to toggle minimap zoom while on field













---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedCombine.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Combine, specializations)
       and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end













---
function ExtendedCombine:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isClient then
        if self:getIsActiveForInput(true, true) then
            ExtendedCombine.updateMinimapActiveState(self)
        end
    end
end


---
function ExtendedCombine:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        if isActiveForInputIgnoreSelection then
            ExtendedCombine.updateMinimapActiveState(self)
        else
            ExtendedCombine.updateMinimapActiveState(self, false)
        end
    end
end


---
function ExtendedCombine.updateMinimapActiveState(self, forcedState)
    local yieldMap = self:getPFYieldMap()
    if yieldMap ~= nil then

        local isActive = forcedState
        if isActive == nil then
            local _, _, _, isOnField, mission = self:getPFStatisticInfo()
            isActive = isOnField and self.spec_combine.numAttachedCutters > 0 and mission == nil
        end

        yieldMap:setRequireMinimapDisplay(isActive, self, self:getIsSelected())
    end
end
