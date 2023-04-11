

















---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function DischargeCounter.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Dischargeable, specializations)
end













---
function DischargeCounter.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadDischargeNode", DischargeCounter.loadDischargeNode)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "handleDischarge", DischargeCounter.handleDischarge)
end


---
function DischargeCounter.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", DischargeCounter)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", DischargeCounter)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", DischargeCounter)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", DischargeCounter)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", DischargeCounter)
end


---
function DischargeCounter:onPostLoad(savegame)
    if savegame ~= nil and not savegame.resetVehicles then
        local spec = self.spec_dischargeable
        for i, dischargeNode in ipairs(spec.dischargeNodes) do
            dischargeNode.dischargeCounter = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key.."."..fullSpecName..".dischargeNode("..(i-1)..")#dischargeCounter"), dischargeNode.dischargeCounter)
        end
    end
end


---
function DischargeCounter:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_dischargeable
    for i, dischargeNode in ipairs(spec.dischargeNodes) do
        xmlFile:setValue(key..".dischargeNode("..(i-1)..")#dischargeCounter", dischargeNode.dischargeCounter)
    end
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function DischargeCounter:onReadStream(streamId, connection)
    local spec = self.spec_dischargeable
    for _, dischargeNode in ipairs(spec.dischargeNodes) do
        dischargeNode.dischargeCounter = streamReadFloat32(streamId)
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function DischargeCounter:onWriteStream(streamId, connection)
    local spec = self.spec_dischargeable
    for _, dischargeNode in ipairs(spec.dischargeNodes) do
        streamWriteFloat32(streamId, dischargeNode.dischargeCounter or 0)
    end
end


---
function DischargeCounter:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_dischargeable

        if streamReadBool(streamId) then
            for _, dischargeNode in ipairs(spec.dischargeNodes) do
                dischargeNode.dischargeCounter = streamReadFloat32(streamId)
            end
        end
    end
end


---
function DischargeCounter:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_dischargeable

        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            for _, dischargeNode in ipairs(spec.dischargeNodes) do
                streamWriteFloat32(streamId, dischargeNode.dischargeCounter or 0)
            end
        end
    end
end


---
function DischargeCounter:loadDischargeNode(superFunc, xmlFile, key, entry)
    if not superFunc(self, xmlFile, key, entry) then
        return false
    end

    entry.dischargeCounter = 0
    entry.targetFilled = false

    entry.targetIsFilledFunc = function()
        if entry.dischargeObject ~= nil and entry.dischargeObject.getFillUnitFreeCapacity ~= nil then
            entry.targetFilled =  entry.dischargeObject:getFillUnitFreeCapacity(entry.dischargeFillUnitIndex) == 0
        end

        return entry.targetFilled
    end

    entry.targetIsFillingFunc = function()
        return not entry.targetIsFilledFunc()
    end

    if self.loadDashboardsFromXML ~= nil then
        self:loadDashboardsFromXML(self.xmlFile, key .. ".dashboards", {valueTypeToLoad = "dischargeCounter", valueObject = entry, valueFunc = "dischargeCounter"})
        self:loadDashboardsFromXML(self.xmlFile, key .. ".dashboards", {valueTypeToLoad = "targetFilled", valueObject = entry, valueFunc = "targetIsFilledFunc"})
        self:loadDashboardsFromXML(self.xmlFile, key .. ".dashboards", {valueTypeToLoad = "targetFilling", valueObject = entry, valueFunc = "targetIsFillingFunc"})
    end

    return true
end


---
function DischargeCounter:handleDischarge(superFunc, dischargeNode, dischargedLiters, minDropReached, hasMinDropFillLevel)
    superFunc(self, dischargeNode, dischargedLiters, minDropReached, hasMinDropFillLevel)

    dischargeNode.dischargeCounter = dischargeNode.dischargeCounter - dischargedLiters
    if self.spec_dashboard ~= nil then
        self:updateDashboards(self.spec_dashboard.dashboards, 9999, true)
    end

    self:raiseDirtyFlags(self.spec_dischargeable.dirtyFlag)
end
