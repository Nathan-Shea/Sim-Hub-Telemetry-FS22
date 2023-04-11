---Class for high pressure washer lance






local HighPressureWasherLance_mt = Class(HighPressureWasherLance, HandTool)



















---
function HighPressureWasherLance.new(isServer, isClient, customMt)
    local self = HighPressureWasherLance:superClass().new(isServer, isClient, customMt or HighPressureWasherLance_mt)

    self.foundVehicle = nil
    self.doWashing = false
    self.washDistance = 10.0
    self.washMultiplier = 1.0
    self.pricePerSecond = 10
    self.isHPWLance = true

    return self
end


---Called after hand tool i3d file was loaded
-- @param table xmlFile xmlFile
function HighPressureWasherLance:postLoad(xmlFile)
    if not HighPressureWasherLance:superClass().postLoad(self, xmlFile) then
        return false
    end

    self.lanceNode = xmlFile:getValue("handTool.highPressureWasherLance.lance#node", nil, self.components, self.i3dMappings)
    self.lanceRaycastNode = xmlFile:getValue("handTool.highPressureWasherLance.lance#raycastNode", nil, self.components, self.i3dMappings)
    self.washDistance = xmlFile:getValue("handTool.highPressureWasherLance.lance#washDistance", 10)
    self.washMultiplier = xmlFile:getValue("handTool.highPressureWasherLance.lance#washMultiplier", 1)
    self.pricePerSecond = xmlFile:getValue("handTool.highPressureWasherLance.lance#pricePerMinute", 10) / 1000

    self.effects = g_effectManager:loadEffect(xmlFile, "handTool.highPressureWasherLance.effects", self.components, self, self.i3dMappings)
    g_effectManager:setFillType(self.effects, FillType.WATER)

    -- Sounds
    self.washingSample = g_soundManager:loadSampleFromXML(xmlFile, "handTool.highPressureWasherLance.sounds", "washing", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)

    return true
end


---Deleting
function HighPressureWasherLance:delete()
    g_effectManager:deleteEffects(self.effects)
    g_soundManager:deleteSample(self.washingSample)
    HighPressureWasherLance:superClass().delete(self)
end


---
function HighPressureWasherLance:onDeactivate()
    self:setIsWashing(false, true, true)
    HighPressureWasherLance:superClass().onDeactivate(self)
end


---
function HighPressureWasherLance:update(dt, allowInput)
    HighPressureWasherLance:superClass().update(self, dt)

    if allowInput then
        self:setIsWashing(self.activatePressed, false, false)
    end

    if self.isServer then
        if self.doWashing then
            self.foundVehicle = nil
            self:cleanVehicle(self.player.cameraNode, dt)
            if self.lanceRaycastNode ~= nil then
                self:cleanVehicle(self.lanceRaycastNode, dt)
            end
            if self.foundVehicle ~= nil then
                local farmId = self.foundVehicle:getOwnerFarmId()
                local price = self.pricePerSecond * (dt / 1000)
                local stats = g_farmManager:getFarmById(self.player.farmId).stats
                stats:updateStats("expenses", price)
                g_currentMission:addMoney(-price, farmId, MoneyType.VEHICLE_RUNNING_COSTS)
            end
        end
    end
    self.activatePressed = false
    self:raiseActive()
end


---Set is washing
-- @param boolean doWashing do washing
-- @param boolean force force
-- @param boolean noEventSend no event send
function HighPressureWasherLance:setIsWashing(doWashing, force, noEventSend)
    HPWLanceStateEvent.sendEvent(self.player, doWashing, noEventSend)
    if self.doWashing ~= doWashing then
        if doWashing then
            g_effectManager:setFillType(self.effects, FillType.WATER)
            g_effectManager:startEffects(self.effects)
            g_soundManager:playSample(self.washingSample)
        else
            if force then
                g_effectManager:resetEffects(self.effects)
            else
                g_effectManager:stopEffects(self.effects)
            end
            g_soundManager:stopSample(self.washingSample)
        end
        self.doWashing = doWashing
    end
end


---Clean vehicle
-- @param integer node node id
-- @param float dt time since last call in ms
function HighPressureWasherLance:cleanVehicle(node, dt)
    local x, y, z = getWorldTranslation(node)
    local dx, dy, dz = localDirectionToWorld(node, 0, 0, -1)
    local lastFoundVehicle = self.foundVehicle
    raycastAll(x, y, z, dx, dy, dz, "washRaycastCallback", self.washDistance, self, 32+64+128+256+4096+8194)

    if self.foundVehicle ~= nil and lastFoundVehicle ~= self.foundVehicle then
        self.foundVehicle:addDirtAmount(-self.washMultiplier * dt / self.foundVehicle:getWashDuration())
    end
end


---Wash raycast callback
-- @param integer hitActorId id of hit object actor
-- @param float x x raycast position
-- @param float y y raycast position
-- @param float z z raycast position
-- @param float distance distance to raycast position
-- @param float nx x component of hit surface normal (unused)
-- @param float ny y component of hit surface normal (unused)
-- @param float nz z component of hit surface normal (unused)
-- @param integer subShapeIndex sub shape index of hit object
-- @param integer hitShapeId id of hit object shape
function HighPressureWasherLance:washRaycastCallback(hitActorId, x, y, z, distance, nx, ny, nz, subShapeIndex, hitShapeId)
    local vehicle = g_currentMission.nodeToObject[hitActorId]
    if hitActorId ~= hitShapeId then
        -- object is a compoundChild. Try to find the compound
        local parentId = hitShapeId
        while parentId ~= 0 do
            if g_currentMission.nodeToObject[parentId] ~= nil then
                -- found valid compound
                vehicle = g_currentMission.nodeToObject[parentId]
                break
            end
            parentId = getParent(parentId)
        end
    end

    if vehicle ~= nil and vehicle.getAllowsWashingByType ~= nil and vehicle:getAllowsWashingByType(Washable.WASHTYPE_HIGH_PRESSURE_WASHER) then
        self.foundVehicle = vehicle
        return false
    end
    return true
end



---Get is active for input
-- @return boolean isActiveForInput is active for input
function HighPressureWasherLance:getIsActiveForInput()
    if self.player == g_currentMission.player and not g_gui:getIsGuiVisible() then
        return true
    end
    return false
end


---
function HighPressureWasherLance:isBeingUsed()
    return self.doWashing
end
