---This is the activable class for smartAttach













---
function SmartAttach.prerequisitesPresent(specializations)
    return true
end


---
function SmartAttach.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("SmartAttach")

    schema:register(XMLValueType.STRING, "vehicle.smartAttach#jointType", "Joint type name")
    schema:register(XMLValueType.NODE_INDEX, "vehicle.smartAttach#trigger", "Trigger node")

    schema:setXMLSpecializationType()
end


---
function SmartAttach.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "smartAttachCallback",   SmartAttach.smartAttachCallback)
    SpecializationUtil.registerFunction(vehicleType, "getCanBeSmartAttached", SmartAttach.getCanBeSmartAttached)
    SpecializationUtil.registerFunction(vehicleType, "doSmartAttach",         SmartAttach.doSmartAttach)
end


---
function SmartAttach.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", SmartAttach)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", SmartAttach)
    SpecializationUtil.registerEventListener(vehicleType, "onPreAttach", SmartAttach)
end


---
function SmartAttach:onLoad(savegame)
    local spec = self.spec_smartAttach

    spec.inputJointDescIndex = nil
    local jointTypeStr = self.xmlFile:getValue("vehicle.smartAttach#jointType")
    if jointTypeStr ~= nil then
        local jointType = AttacherJoints.jointTypeNameToInt[jointTypeStr]
        if jointType ~= nil then
            for inputJointDescIndex, inputAttacherJoint in pairs(self:getInputAttacherJoints()) do
                if inputAttacherJoint.jointType == jointType then
                    spec.inputJointDescIndex = inputJointDescIndex
                    break
                end
            end
            spec.jointType = jointType

            if spec.inputJointDescIndex == nil then
                print("Warning: SmartAttach jointType not defined in '"..self.configFileName.."'!")
            end
        else
            print("Warning: invalid jointType " .. jointTypeStr)
        end
    end

    local triggerNode = self.xmlFile:getValue("vehicle.smartAttach#trigger", nil, self.components, self.i3dMappings)
    if triggerNode ~= nil then
        spec.trigger = triggerNode
        addTrigger(spec.trigger, "smartAttachCallback", self)
    end

    spec.targetVehicle = nil
    spec.targetVehicleCount = 0
    spec.jointDescIndex = nil
    spec.activatable = SmartAttachActivatable.new(self)
end


---
function SmartAttach:onDelete()
    local spec = self.spec_smartAttach

    if spec.activatable ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
        spec.activatable = nil
    end

    if spec.trigger ~= nil then
        removeTrigger(spec.trigger)
        spec.trigger = nil
    end
end


---
function SmartAttach:doSmartAttach(targetVehicle, inputJointDescIndex, jointDescIndex, noEventSend)
    SmartAttachEvent.sendEvent(self, targetVehicle, inputJointDescIndex, jointDescIndex, noEventSend)

    if self.isServer then
        local attacherVehicle = self:getAttacherVehicle()
        if attacherVehicle ~= nil then
            attacherVehicle:detachImplementByObject(self)
        end

        targetVehicle:attachImplement(self, inputJointDescIndex, jointDescIndex, false)
    end
end


---
function SmartAttach:getCanBeSmartAttached()
    local spec = self.spec_smartAttach

    local targetVehicle = spec.targetVehicle
    if targetVehicle == nil then
        return false
    end

    local activeForInput = self:getIsActiveForInput(true) or spec.targetVehicle:getIsActiveForInput(true)
    if not activeForInput then
       return false
    end

    local attacherJoint = targetVehicle:getAttacherJoints()[spec.jointDescIndex].jointTransform
    local inputAttacherJoint = self:getInputAttacherJoints()[spec.inputJointDescIndex].node
    local x1, _, z1 = getWorldTranslation(attacherJoint)
    local x2, _, z2 = getWorldTranslation(inputAttacherJoint)

    local distance = MathUtil.vector2Length(x1-x2, z1-z2)
    local yRot = Utils.getYRotationBetweenNodes(attacherJoint, inputAttacherJoint)

    return distance < SmartAttach.DISTANCE_THRESHOLD and math.abs(yRot) < SmartAttach.ABS_ANGLE_THRESHOLD
end


---
function SmartAttach:onPreAttach()
    local spec = self.spec_smartAttach

    spec.targetVehicle = nil
    spec.targetVehicleCount = 0
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherActorId id of other actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
-- @param integer otherShapeId id of other shape
function SmartAttach:smartAttachCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    local spec = self.spec_smartAttach

    if onEnter then
        local vehicle = g_currentMission.nodeToObject[otherActorId]
        if vehicle ~= nil then
            if spec.targetVehicle == nil then
                if vehicle ~= nil and vehicle ~= self and vehicle.getAttacherJoints ~= nil then
                    for i, jointDesc in ipairs(vehicle:getAttacherJoints()) do
                        if jointDesc.jointIndex == 0 and jointDesc.jointType == spec.jointType then
                            spec.targetVehicle = vehicle
                            spec.jointDescIndex = i
                            spec.targetVehicleCount = 0

                            local name = Utils.getNoNil(self.typeDesc, "")
                            local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName:lower())
                            if storeItem ~= nil then
                                name = storeItem.name
                            end

                            if self:getAttacherVehicle() == nil then
                                spec.activatable.activateText = string.format(g_i18n:getText("action_doSmartAttachGround", self.customEnvironment), name)
                            else
                                spec.activatable.activateText = string.format(g_i18n:getText("action_doSmartAttachTransform", self.customEnvironment), name)
                            end

                            g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
                            break
                        end
                    end
                end
            end

            if vehicle == spec.targetVehicle then
                spec.targetVehicleCount = spec.targetVehicleCount + 1
            end
        end
    elseif onLeave then
        if spec.targetVehicle ~= nil then
            local object = g_currentMission.nodeToObject[otherActorId]
            if object ~= nil and object == spec.targetVehicle then
                spec.targetVehicleCount = spec.targetVehicleCount - 1
                if spec.targetVehicleCount <= 0 then
                    spec.targetVehicle = nil
                    g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
                    spec.targetVehicleCount = 0
                end
            end
        end
    end
end
