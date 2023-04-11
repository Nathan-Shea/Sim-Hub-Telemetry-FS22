---Specialization to track seed usage






















---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedSowingMachine.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end















































---
function ExtendedSowingMachine:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_extendedSowingMachine
    spec.lastGroundUpdateDistance = spec.lastGroundUpdateDistance + self.lastMovedDistance
    if spec.lastGroundUpdateDistance > spec.groundUpdateDistance then
        spec.lastGroundUpdateDistance = 0

        local workArea = self:getWorkAreaByIndex(1)
        if workArea ~= nil then
            local x, z

            -- if the work area starts in the middle of the vehicle we use the start node, otherwise the middle between start and width
            local lx, _, _ = localToLocal(workArea.start, self.rootNode, 0, 0, 0)
            if math.abs(lx) < 0.5 then
                x, _, z =  getWorldTranslation(workArea.start)
            else
                local x1, _, z1 = getWorldTranslation(workArea.start)
                local x2, _, z2 = getWorldTranslation(workArea.width)
                x, z = (x1 + x2) * 0.5, (z1 + z2) * 0.5
            end

            local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, 0, z)
            if isOnField then
                local soilTypeIndex = spec.soilMap:getTypeIndexAtWorldPos(x, z)
                if soilTypeIndex > 0 then
                    local fruitTypeIndex = self.spec_sowingMachine.seeds[self.spec_sowingMachine.currentSeed]
                    spec.seedRateRecommendation = spec.seedRateMap:getOptimalSeedRateByFruitTypeAndSoiltype(fruitTypeIndex, soilTypeIndex)
                else
                    spec.seedRateRecommendation = nil
                end
            else
                spec.seedRateRecommendation = nil
            end
        end
    end
end


---
function ExtendedSowingMachine:onEndWorkAreaProcessing(dt, hasProcessed)
    local spec = self.spec_sowingMachine
    if self.isServer then
        if spec.workAreaParameters.lastChangedArea > 0 then
            local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(spec.workAreaParameters.seedsFruitType)
            local realHa = MathUtil.areaToHa(self.spec_extendedSowingMachine.lastRealChangedArea, g_currentMission:getFruitPixelsToSqm())
            local lastHa = MathUtil.areaToHa(spec.workAreaParameters.lastChangedArea, g_currentMission:getFruitPixelsToSqm())
            local usage = fruitDesc.seedUsagePerSqm * lastHa * 10000
            local usageRegular = fruitDesc.seedUsagePerSqm * realHa * 10000

            local damage = self:getVehicleDamage()
            if damage > 0 then
                usage = usage * (1 + damage * SowingMachine.DAMAGED_USAGE_INCREASE)
                usageRegular = usageRegular * (1 + damage * SowingMachine.DAMAGED_USAGE_INCREASE)
            end

            local farmlandStatistics, _, farmlandId = self:getPFStatisticInfo()
            if farmlandStatistics ~= nil then
                if farmlandId ~= nil then
                    farmlandStatistics:updateStatistic(farmlandId, "usedSeeds", usage)
                    farmlandStatistics:updateStatistic(farmlandId, "usedSeedsRegular", usageRegular)
                end
            end
        end
    end
end


---
function ExtendedSowingMachine:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_extendedSowingMachine
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            local _, actionEventId = self:addActionEvent(spec.actionEvents, spec.inputActionToggleAuto, self, ExtendedSowingMachine.actionEventToggleAuto, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)

            _, actionEventId = self:addActionEvent(spec.actionEvents, spec.inputActionToggleRate, self, ExtendedSowingMachine.actionEventChangeSeedRate, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
            g_inputBinding:setActionEventText(actionEventId, spec.texts.inputChangeSeedRate)

            ExtendedSowingMachine.updateActionEventState(self)
        end

        spec.attachStateChanged = true
    end
end


---
function ExtendedSowingMachine:setSeedRateAutoMode(state, noEventSend)
    local spec = self.spec_extendedSowingMachine
    if state == nil then
        state = not spec.seedRateAutoMode
    end

    if state ~= spec.seedRateAutoMode then
        spec.seedRateAutoMode = state

        if self.isClient then
            ExtendedSowingMachine.updateActionEventState(self)
        end

        ExtendedSowingMachineRateEvent.sendEvent(self, spec.seedRateAutoMode, spec.manualSeedRate, noEventSend)
    end
end


---
function ExtendedSowingMachine:setManualSeedRate(seedRate, noEventSend)
    local spec = self.spec_extendedSowingMachine
    seedRate = MathUtil.clamp(seedRate, ExtendedSowingMachine.MIN_SEED_RATE, ExtendedSowingMachine.MAX_SEED_RATE)
    if seedRate ~= spec.manualSeedRate then
        spec.manualSeedRate = seedRate

        ExtendedSowingMachineRateEvent.sendEvent(self, spec.seedRateAutoMode, spec.manualSeedRate, noEventSend)
    end
end


---
function ExtendedSowingMachine:processSowingMachineArea(superFunc, workArea, dt)
    local changedArea, totalArea = superFunc(self, workArea, dt)
    if changedArea > 0 then
        local spec = self.spec_extendedSowingMachine
        local specSowingMachine = self.spec_sowingMachine
        local workAreaParameters = specSowingMachine.workAreaParameters

        local sx, _, sz = getWorldTranslation(workArea.start)
        local wx, _, wz = getWorldTranslation(workArea.width)
        local hx, _, hz = getWorldTranslation(workArea.height)

        local fruitType = workAreaParameters.seedsFruitType

        local realUsage, realSeedRate, realSeedRateIndex = spec.seedRateMap:updateSeedArea(sx, sz, wx, wz, hx, hz, fruitType, spec.seedRateAutoMode, spec.manualSeedRate)

        if realSeedRateIndex ~= nil then
            local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitType)
            local usageOffset = realUsage / fruitDesc.seedUsagePerSqm

            spec.lastRealChangedArea = workAreaParameters.lastChangedArea
            workAreaParameters.lastChangedArea = workAreaParameters.lastChangedArea * usageOffset

            spec.lastSeedRate = realSeedRate
            spec.lastSeedRateIndex = realSeedRateIndex
        end
    end

    return changedArea, totalArea
end


---
function ExtendedSowingMachine.actionEventToggleAuto(self, actionName, inputValue, callbackState, isAnalog)
    self:setSeedRateAutoMode()
end


---
function ExtendedSowingMachine.actionEventChangeSeedRate(self, actionName, inputValue, callbackState, isAnalog, ...)
    self:setManualSeedRate(self.spec_extendedSowingMachine.manualSeedRate + MathUtil.sign(inputValue))
end


---
function ExtendedSowingMachine.updateActionEventState(self)
    local spec = self.spec_extendedSowingMachine
    local actionEventToggleAuto = spec.actionEvents[spec.inputActionToggleAuto]
    if actionEventToggleAuto ~= nil then
        g_inputBinding:setActionEventText(actionEventToggleAuto.actionEventId, spec.seedRateAutoMode and spec.texts.inputToggleAutoModeNeg or spec.texts.inputToggleAutoModePos)
    end

    local actionEventToggleRate = spec.actionEvents[spec.inputActionToggleRate]
    if actionEventToggleRate ~= nil then
        g_inputBinding:setActionEventActive(actionEventToggleRate.actionEventId, not spec.seedRateAutoMode)
    end
end
