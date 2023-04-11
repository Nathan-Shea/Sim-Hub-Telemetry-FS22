

















---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedReceivingHopper.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Dischargeable, specializations) and SpecializationUtil.hasSpecialization(ReceivingHopper, specializations)
end










---
function ExtendedReceivingHopper.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getCanSpawnNextBoxExt", ExtendedReceivingHopper.getCanSpawnNextBoxExt)
    SpecializationUtil.registerFunction(vehicleType, "createBoxExt", ExtendedReceivingHopper.createBoxExt)
end



---
function ExtendedReceivingHopper.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanSpawnNextBox", ExtendedReceivingHopper.getCanSpawnNextBox)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "createBox", ExtendedReceivingHopper.createBox)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadDischargeNode", ExtendedReceivingHopper.loadDischargeNode)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "handleDischarge", ExtendedReceivingHopper.handleDischarge)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "setDischargeEffectActive", ExtendedReceivingHopper.setDischargeEffectActive)
end


---
function ExtendedReceivingHopper.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedReceivingHopper)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ExtendedReceivingHopper)
    SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", ExtendedReceivingHopper)
end


---Called on loading
-- @param table savegame savegame
function ExtendedReceivingHopper:onLoad(savegame)
    self.spec_extendedReceivingHopper = self["spec_" .. modName .. ".extendedReceivingHopper"]

    local spec = self.spec_extendedReceivingHopper

    spec.spawnPlaces = {}

    local i = 0
    while true do
        local baseKey = string.format("vehicle.receivingHopper.additionalSpawnPlace(%d)", i)
        if not self.xmlFile:hasProperty(baseKey) then
            break
        end

        local spawnPlace = {}
        spawnPlace.node = self.xmlFile:getValue(baseKey .. "#node", "0>", self.components, self.i3dMappings)

        if spawnPlace.node ~= nil then
            table.insert(spec.spawnPlaces, spawnPlace)
        end

        i = i + 1
    end

    spec.activeSpawnNode = 0
    spec.numSpawnNodes = #spec.spawnPlaces

    local spec = self.spec_receivingHopper
    spec.lastDischargeTime = 0

    local spec = self.spec_attachable
    spec.requiresExternalPower = false
end











































---
function ExtendedReceivingHopper:getCanSpawnNextBox(superFunc)
    local spec = self.spec_extendedReceivingHopper
    local specReceivingHopper = self.spec_receivingHopper
    
    if specReceivingHopper.creatingBox then
        return false
    end

    if spec.activeSpawnNode == 0 then
        -- overwrite vanilla function to fix issue with overlap box not using exact test
        local fillType = self:getFillUnitFillType(specReceivingHopper.fillUnitIndex)
        if specReceivingHopper.boxes[fillType] ~= nil then
            if specReceivingHopper.lastBox ~= nil then
                if specReceivingHopper.lastBox:getFillUnitFreeCapacity(1) > 0 then
                    return false
                end
            end

            local xmlFilename = Utils.getFilename(specReceivingHopper.boxes[fillType], self.baseDirectory)
            local size = StoreItemUtil.getSizeValues(xmlFilename, "vehicle", 0, {})
            local height = 1

            local x,y,z = getWorldTranslation(specReceivingHopper.spawnPlace)
            local rx,ry,rz = getWorldRotation(specReceivingHopper.spawnPlace)

            specReceivingHopper.foundObjectAtSpawnPlace = false
            overlapBox(x, y + (height * 0.5), z, rx, ry, rz, size.width*0.5, height * 0.5, size.length*0.5, "collisionTestCallback", self, 5468288, true, true, true)

            return not specReceivingHopper.foundObjectAtSpawnPlace
        end
    end

    return false
end


---
function ExtendedReceivingHopper:createBox(superFunc)
    local spec = self.spec_extendedReceivingHopper
    spec.activeSpawnNode = spec.activeSpawnNode + 1

    superFunc(self)
end


---
function ExtendedReceivingHopper:loadDischargeNode(superFunc, xmlFile, key, entry)
    if not superFunc(self, xmlFile, key, entry) then
        return false
    end

    if self.isClient then
        entry.animationNodes = g_animationManager:loadAnimations(self.xmlFile, key .. ".animationNodes", self.components, self, self.i3dMappings)
    end

    return true
end


---
function ExtendedReceivingHopper:handleDischarge(superFunc, dischargeNode, dischargedLiters, minDropReached, hasMinDropFillLevel)
    if dischargedLiters ~= 0 then
        local spec = self.spec_receivingHopper
        spec.lastDischargeTime = g_time
    end

    superFunc(self, dischargeNode, dischargedLiters, minDropReached, hasMinDropFillLevel)
end


---
function ExtendedReceivingHopper:setDischargeEffectActive(superFunc, dischargeNode, isActive, force)
    if isActive then
        g_animationManager:startAnimations(dischargeNode.animationNodes)
    else
        g_animationManager:stopAnimations(dischargeNode.animationNodes)
    end

    superFunc(self, dischargeNode, isActive, force)
end


---
function ExtendedReceivingHopper:getCanSpawnNextBoxExt()
    local spec = self.spec_extendedReceivingHopper
    local specReceivingHopper = self.spec_receivingHopper

    if specReceivingHopper.creatingBox then
        return false
    end

    if spec.activeSpawnNode > 0 then
        local spawnPlace = spec.spawnPlaces[spec.activeSpawnNode]
        if spawnPlace ~= nil then
            local fillType = self:getFillUnitFillType(specReceivingHopper.fillUnitIndex)
            if specReceivingHopper.boxes[fillType] ~= nil then
                if specReceivingHopper.lastBox ~= nil then
                    if specReceivingHopper.lastBox:getFillUnitFreeCapacity(1) > 0 then
                        return false
                    end
                end

                local xmlFilename = Utils.getFilename(specReceivingHopper.boxes[fillType], self.baseDirectory)
                local size = StoreItemUtil.getSizeValues(xmlFilename, "vehicle", 0, {})
                local height = 1

                local x,y,z = getWorldTranslation(spawnPlace.node)
                local rx,ry,rz = getWorldRotation(spawnPlace.node)

                specReceivingHopper.foundObjectAtSpawnPlace = false
                overlapBox(x, y + (height * 0.5), z, rx, ry, rz, size.width*0.5, height * 0.5, size.length*0.5, "collisionTestCallback", self, 5468288, true, true, true)

                return not specReceivingHopper.foundObjectAtSpawnPlace
            end
        end
    end

    return false
end


---Create box
function ExtendedReceivingHopper:createBoxExt()
    local spec = self.spec_extendedReceivingHopper
    local specReceivingHopper = self.spec_receivingHopper

    if self.isServer then
        if specReceivingHopper.createBoxes then
            local spawnPlace = spec.spawnPlaces[spec.activeSpawnNode]
            if spawnPlace ~= nil then
                local fillType = self:getFillUnitFillType(specReceivingHopper.fillUnitIndex)
                if specReceivingHopper.boxes[fillType] ~= nil then
                    local x, _, z = getWorldTranslation(spawnPlace.node)
                    local dirX, _, dirZ = localDirectionToWorld(spawnPlace.node, 0, 0, 1)
                    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ);
                    local xmlFilename = Utils.getFilename(specReceivingHopper.boxes[fillType], self.baseDirectory)
                    local location = {x = x, z = z, yRot = yRot}

                    specReceivingHopper.creatingBox = true
                    VehicleLoadingUtil.loadVehicle(xmlFilename, location, true, 0, Vehicle.PROPERTY_STATE_OWNED, self:getOwnerFarmId(), nil, nil, self.onCreateBoxFinished, self)
                end
            end
        end
    end

    spec.activeSpawnNode = spec.activeSpawnNode + 1
    if spec.activeSpawnNode > spec.numSpawnNodes then
        spec.activeSpawnNode = 0
    end
end
