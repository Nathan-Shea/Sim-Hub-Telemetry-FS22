











local PalletUnloadTrigger_mt = Class(PalletUnloadTrigger, Object)




---
function PalletUnloadTrigger.registerXMLPaths(schema, basePath)
    schema:register(XMLValueType.NODE_INDEX, basePath .. "#triggerNode", "Trigger node")
end


---Creates a new instance of the class
-- @param bool isServer true if we are server
-- @param bool isClient true if we are client
-- @param table customMt meta table
-- @return table self returns the instance
function PalletUnloadTrigger.new(isServer, isClient, customMt)
    local self = Object.new(isServer, isClient, customMt or PalletUnloadTrigger_mt)

    self.triggerNode = nil

    self.extraAttributes = {price = 1}

    return self
end


---Loads elements of the class
-- @param table components components
-- @param table xmlFile xml file object
-- @param string xmlNode xml key
-- @param table target target object
-- @param table i3dMappings i3dMappings
-- @param integer rootNode rootNode
-- @return boolean success success
function PalletUnloadTrigger:load(components, xmlFile, xmlNode, target, i3dMappings, rootNode)
    local triggerNodeKey = xmlNode .. "#triggerNode"
    self.triggerNode = xmlFile:getValue(triggerNodeKey, nil, components, i3dMappings)
    if self.triggerNode ~= nil then
        local colMask = getCollisionMask(self.triggerNode)
        if bitAND(CollisionFlag.VEHICLE, colMask) == 0 then
            Logging.xmlWarning(xmlFile, "Invalid collision mask for pallet trigger '%s'. Bit 13 needs to be set!", triggerNodeKey)
            return false
        end

        addTrigger(self.triggerNode, "palletTriggerCallback", self)
    else
        return false
    end

    if target ~= nil then
        self:setTarget(target)
    end

    return true
end


---Delete instance
function PalletUnloadTrigger:delete()
    if self.triggerNode ~= nil and self.triggerNode ~= 0 then
        removeTrigger(self.triggerNode)
        self.triggerNode = 0
    end

    PalletUnloadTrigger:superClass().delete(self)
end


---Connects object using the trigger to the trigger
-- @param table object target on which the unload trigger is attached
function PalletUnloadTrigger:setTarget(object)
    assert(object.getIsFillTypeAllowed ~= nil)
    assert(object.getIsToolTypeAllowed ~= nil)
    assert(object.addFillUnitFillLevel ~= nil)

    self.target = object
end


---
function PalletUnloadTrigger:getTarget()
    return self.target
end


---Callback method for the wood trigger
-- @param integer triggerId 
-- @param integer otherId 
-- @param bool onEnter 
-- @param bool onLeave 
-- @param bool onStay 
-- @param integer otherShapeId 
function PalletUnloadTrigger:palletTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if otherId ~= 0 then
        local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil then
            if object:isa(Vehicle) then
                if object.isPallet and object.getFillUnits ~= nil then
                    local fillUnits = object:getFillUnits()
                    for fillUnitIndex, _ in pairs(fillUnits) do
                        local fillTypeIndex = object:getFillUnitFillType(fillUnitIndex)
                        if fillTypeIndex ~= FillType.UNKNOWN then
                            if self.target:getIsFillTypeSupported(fillTypeIndex) then
                                if object:getFillUnitFillLevel(fillUnitIndex) > 0 then
                                    -- unmount pallet from vehicle so we have full access on it
                                    if object.getMountObject ~= nil and object:getMountObject() ~= nil then
                                        object:unmountDynamic()

                                        local mountObject = object:getMountObject()
                                        if mountObject.setAllTensionBeltsActive ~= nil then
                                            mountObject:setAllTensionBeltsActive(false)
                                        end
                                    end

                                    if object.getPalletUnloadTriggerExtraSellPrice ~= nil then
                                        if self.target ~= nil and self.target.target ~= nil and self.target.target.moneyChangeType ~= nil then
                                            g_currentMission:addMoney(object:getPalletUnloadTriggerExtraSellPrice(), object:getOwnerFarmId(), self.target.target.moneyChangeType, true)
                                        end
                                    end

                                    local fillLevelDelta = object:addFillUnitFillLevel(object:getOwnerFarmId(), fillUnitIndex, -math.huge, fillTypeIndex, ToolType.UNDEFINED)
                                    self.target:addFillUnitFillLevel(object:getOwnerFarmId(), fillUnitIndex, -fillLevelDelta, fillTypeIndex, ToolType.UNDEFINED)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
