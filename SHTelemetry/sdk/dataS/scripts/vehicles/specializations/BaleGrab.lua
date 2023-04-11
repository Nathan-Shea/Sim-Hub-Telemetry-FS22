---Specialization for a balegrab tool adding soft attaching of bales












---
function BaleGrab.prerequisitesPresent(specializations)
    return true
end


---
function BaleGrab.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("BaleGrab")

    schema:register(XMLValueType.NODE_INDEX, "vehicle.baleGrab#triggerNode", "Trigger node")
    schema:register(XMLValueType.NODE_INDEX, "vehicle.baleGrab#rootNode", "Root node")
    schema:register(XMLValueType.NODE_INDEX, "vehicle.baleGrab#jointNode", "Joint node")
    schema:register(XMLValueType.STRING, "vehicle.baleGrab#jointType", "Joint type", "TYPE_AUTO_ATTACH_XYZ")
    schema:register(XMLValueType.FLOAT, "vehicle.baleGrab#forceAcceleration", "Force acceleration", 20)
    schema:register(XMLValueType.INT, "vehicle.baleGrab#grabRefComponentJointIndex1", "Component joint index of grab 1")
    schema:register(XMLValueType.INT, "vehicle.baleGrab#grabRefComponentJointIndex2", "Component joint index of grab 2")
    schema:register(XMLValueType.ANGLE, "vehicle.baleGrab#rotDiffThreshold1", "Rotation difference between component and joint to mount bale", 2)
    schema:register(XMLValueType.ANGLE, "vehicle.baleGrab#rotDiffThreshold2", "Rotation difference between component and joint to mount bale", 2)

    schema:setXMLSpecializationType()
end


---
function BaleGrab.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "baleGrabTriggerCallback",      BaleGrab.baleGrabTriggerCallback)
    SpecializationUtil.registerFunction(vehicleType, "addDynamicMountedObject",      BaleGrab.addDynamicMountedObject)
    SpecializationUtil.registerFunction(vehicleType, "removeDynamicMountedObject",   BaleGrab.removeDynamicMountedObject)
    SpecializationUtil.registerFunction(vehicleType, "isComponentJointOutsideLimit", BaleGrab.isComponentJointOutsideLimit)
    SpecializationUtil.registerFunction(vehicleType, "mountBaleGrabObject",            BaleGrab.mountBaleGrabObject)
    SpecializationUtil.registerFunction(vehicleType, "unmountBaleGrabObject",          BaleGrab.unmountBaleGrabObject)
end


---
function BaleGrab.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addNodeObjectMapping",    BaleGrab.addNodeObjectMapping)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "removeNodeObjectMapping", BaleGrab.removeNodeObjectMapping)
end


---
function BaleGrab.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", BaleGrab)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", BaleGrab)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", BaleGrab)
end


---Called on loading
-- @param table savegame savegame
function BaleGrab:onLoad(savegame)
    local spec = self.spec_baleGrab

    if self.isServer then
        local dynamicMountAttacherTrigger = {}
        dynamicMountAttacherTrigger.triggerNode = self.xmlFile:getValue("vehicle.baleGrab#triggerNode", nil, self.components, self.i3dMappings)
        dynamicMountAttacherTrigger.rootNode = self.xmlFile:getValue("vehicle.baleGrab#rootNode", nil, self.components, self.i3dMappings)
        dynamicMountAttacherTrigger.jointNode = self.xmlFile:getValue("vehicle.baleGrab#jointNode", nil, self.components, self.i3dMappings)

        local attacherJointTypeString = self.xmlFile:getValue("vehicle.baleGrab#jointType", "TYPE_AUTO_ATTACH_XYZ")
        dynamicMountAttacherTrigger.attacherJointType = DynamicMountUtil.TYPE_AUTO_ATTACH_XYZ
        if DynamicMountUtil[attacherJointTypeString] ~= nil then
            dynamicMountAttacherTrigger.attacherJointType = DynamicMountUtil[attacherJointTypeString]
        end

        if dynamicMountAttacherTrigger.triggerNode ~= nil and dynamicMountAttacherTrigger.rootNode ~= nil and dynamicMountAttacherTrigger.jointNode ~= nil then
            dynamicMountAttacherTrigger.forceAcceleration = self.xmlFile:getValue("vehicle.baleGrab#forceAcceleration", 20)
            addTrigger(dynamicMountAttacherTrigger.triggerNode, "baleGrabTriggerCallback", self)

            local grabRefComponentJointIndex1 = self.xmlFile:getValue("vehicle.baleGrab#grabRefComponentJointIndex1")
            local grabRefComponentJointIndex2 = self.xmlFile:getValue("vehicle.baleGrab#grabRefComponentJointIndex2")
            if grabRefComponentJointIndex1 ~= nil then
                dynamicMountAttacherTrigger.componentJoint1 = self.componentJoints[grabRefComponentJointIndex1+1]
            end
            if grabRefComponentJointIndex2 ~= nil then
                dynamicMountAttacherTrigger.componentJoint2 = self.componentJoints[grabRefComponentJointIndex2+1]
            end

            dynamicMountAttacherTrigger.rotDiffThreshold1 = self.xmlFile:getValue("vehicle.baleGrab#rotDiffThreshold1", 2)
            dynamicMountAttacherTrigger.rotDiffThreshold2 = self.xmlFile:getValue("vehicle.baleGrab#rotDiffThreshold2", 2)

            dynamicMountAttacherTrigger.cosRotDiffThreshold1 = math.cos(dynamicMountAttacherTrigger.rotDiffThreshold1)
            dynamicMountAttacherTrigger.cosRotDiffThreshold2 = math.cos(dynamicMountAttacherTrigger.rotDiffThreshold2)

            spec.dynamicMountAttacherTrigger = dynamicMountAttacherTrigger
        end

        spec.dynamicMountedObjects = {}
        spec.pendingDynamicMountObjects = {}
    else
        SpecializationUtil.removeEventListener(self, "onUpdateTick", BaleGrab)
    end
end


---Called on deleting
function BaleGrab:onDelete()
    local spec = self.spec_baleGrab
    if self.isServer and spec.dynamicMountedObjects ~= nil then
        for object,_ in pairs(spec.dynamicMountedObjects) do
            self:unmountBaleGrabObject(object)
        end
    end
    if spec.dynamicMountAttacherTrigger ~= nil then
        removeTrigger(spec.dynamicMountAttacherTrigger.triggerNode)
    end
end


---Called on update tick
-- @param float dt time since last call in ms
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function BaleGrab:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isServer then
        local spec = self.spec_baleGrab
        local attachTrigger = spec.dynamicMountAttacherTrigger

        local isClosed = true
        if attachTrigger.componentJoint1 ~= nil then
            isClosed = self:isComponentJointOutsideLimit(attachTrigger.componentJoint1, attachTrigger.rotDiffThreshold1, attachTrigger.cosRotDiffThreshold1)
        end
        if isClosed and attachTrigger.componentJoint2 ~= nil then
            isClosed = self:isComponentJointOutsideLimit(attachTrigger.componentJoint2, attachTrigger.rotDiffThreshold2, attachTrigger.cosRotDiffThreshold2)
        end
        if isClosed then
            for object,_ in pairs(spec.pendingDynamicMountObjects) do
                if spec.dynamicMountedObjects[object] == nil then
                    self:unmountBaleGrabObject(object)
                    self:mountBaleGrabObject(object)
                end
            end
        else
            for object,_ in pairs(spec.dynamicMountedObjects) do
                self:unmountBaleGrabObject(object)
            end
        end
    end
end


---Add dynamic mount object
-- @param table object object
function BaleGrab:addDynamicMountedObject(object)
    local spec = self.spec_baleGrab
    spec.dynamicMountedObjects[object] = object
end


---Remove dynamic mount object
-- @param table object object
-- @param boolean isDeleting is deleting
function BaleGrab:removeDynamicMountedObject(object, isDeleting)
    local spec = self.spec_baleGrab
    spec.dynamicMountedObjects[object] = nil
    if isDeleting then
        spec.pendingDynamicMountObjects[object] = nil
    end
end


---
function BaleGrab.onPendingObjectDelete(self, object)
    local spec = self.spec_baleGrab
    if spec.pendingDynamicMountObjects[object] ~= nil or spec.dynamicMountedObjects[object] ~= nil then
        self:removeDynamicMountedObject(object, true)
    end
end


---
function BaleGrab.onPendingObjectMountStateChanged(self, object, mountState, mountObject)
    if mountState ~= MountableObject.MOUNT_TYPE_NONE and mountObject ~= self then
        local spec = self.spec_baleGrab
        if spec.pendingDynamicMountObjects[object] ~= nil or spec.dynamicMountedObjects[object] ~= nil then
            self:removeDynamicMountedObject(object, true)
        end
    end
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherActorId id of other actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
-- @param integer otherShapeId id of other shape
function BaleGrab:baleGrabTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    local spec = self.spec_baleGrab
    if onEnter then
        local object = g_currentMission:getNodeObject(otherActorId)
        if object == nil then
            object = g_currentMission.nodeToObject[otherActorId]
        end
        if object ~= nil and object ~= self and object.getSupportsMountDynamic ~= nil and object:getSupportsMountDynamic() then
            spec.pendingDynamicMountObjects[object] = (spec.pendingDynamicMountObjects[object] or 0) + 1
            if spec.pendingDynamicMountObjects[object] == 1 then
                object:addDeleteListener(self, BaleGrab.onPendingObjectDelete)

                if object.addMountStateChangeListener ~= nil then
                    object:addMountStateChangeListener(self, BaleGrab.onPendingObjectMountStateChanged)
                end
            end
        end
    elseif onLeave then
        local object = g_currentMission:getNodeObject(otherActorId)
        if object == nil then
            object = g_currentMission.nodeToObject[otherActorId]
        end
        if object ~= nil then
            spec.pendingDynamicMountObjects[object] = (spec.pendingDynamicMountObjects[object] or 0) - 1
            if spec.pendingDynamicMountObjects[object] <= 0 then
                spec.pendingDynamicMountObjects[object] = nil

                if spec.dynamicMountedObjects[object] ~= nil then
                    self:unmountBaleGrabObject(object)
                end

                object:removeDeleteListener(self, BaleGrab.onPendingObjectDelete)
                if object.removeMountStateChangeListener ~= nil then
                    object:removeMountStateChangeListener(self, BaleGrab.onPendingObjectMountStateChanged)
                end
            end
        end
    end
end


---Returns if component joint is outside the rotation limit
-- @param integer componentJoint index of component joint
-- @param float maxRot max rotation
-- @param float cosMaxRot cos max rotation
-- @return boolean isOutside is outside the rotation limit
function BaleGrab:isComponentJointOutsideLimit(componentJoint, maxRot, cosMaxRot)
    local x,_,z = localDirectionToLocal(self.components[componentJoint.componentIndices[2]].node, componentJoint.jointNode, 0,0,1)
    if (x >= 0) == (maxRot >= 0) then
        if z <= cosMaxRot*math.sqrt(x*x + z*z) then
            return true
        end
    end
    return false
end


---Mounts a dynamic object to the bale grab
-- @param table object object
-- @return boolean success success
function BaleGrab:mountBaleGrabObject(object)
    local dynamicMountData = self.spec_baleGrab.dynamicMountAttacherTrigger
    if object:mountDynamic(self, dynamicMountData.rootNode, dynamicMountData.jointNode, dynamicMountData.attacherJointType, dynamicMountData.forceAcceleration) then
        self:addDynamicMountedObject(object)
        return true
    end

    return false
end


---Unmounts a dynamic object from the bale grab
-- @param table object object
-- @return boolean success success
function BaleGrab:unmountBaleGrabObject(object)
    self:removeDynamicMountedObject(object, false)
    object:unmountDynamic()

    return true
end


---
function BaleGrab:addNodeObjectMapping(superFunc, list)
    superFunc(self, list)

    local spec = self.spec_baleGrab
    if spec.dynamicMountAttacherTrigger ~= nil and spec.dynamicMountAttacherTrigger.triggerNode ~= nil then
        list[spec.dynamicMountAttacherTrigger.triggerNode] = self
    end
end


---
function BaleGrab:removeNodeObjectMapping(superFunc, list)
    superFunc(self, list)

    local spec = self.spec_baleGrab
    if spec.dynamicMountAttacherTrigger ~= nil and spec.dynamicMountAttacherTrigger.triggerNode ~= nil then
        list[spec.dynamicMountAttacherTrigger.triggerNode] = nil
    end
end
