












local BaleUnloadTrigger_mt = Class(BaleUnloadTrigger, Object)





---Creates a new instance of the class
-- @param bool isServer true if we are server
-- @param bool isClient true if we are client
-- @param table customMt meta table
-- @return table self returns the instance
function BaleUnloadTrigger.new(isServer, isClient, customMt)
    local self = Object.new(isServer, isClient, customMt or BaleUnloadTrigger_mt)

    self.triggerNode = nil
    self.balesInTrigger = {}

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
function BaleUnloadTrigger:load(components, xmlFile, xmlNode, target, i3dMappings, rootNode)
    self.triggerNode = xmlFile:getValue(xmlNode .. "#triggerNode", nil, components, i3dMappings)
    if self.triggerNode ~= nil then
        if not CollisionFlag.getHasFlagSet(self.triggerNode, CollisionFlag.TRIGGER_DYNAMIC_OBJECT) then
            Logging.xmlError(xmlFile, "Bale trigger '%s' does not have Bit '%d' (%s) set", xmlNode .. "#triggerNode", CollisionFlag.getBit(CollisionFlag.TRIGGER_DYNAMIC_OBJECT), "TRIGGER_DYNAMIC_OBJECT")
            return false
        end
        addTrigger(self.triggerNode, "baleTriggerCallback", self)
    else
        return false
    end

    self.deleteLitersPerMS = xmlFile:getValue(xmlNode .. "#deleteLitersPerSecond", 4000) / 1000

    if target ~= nil then
        self:setTarget(target)
    end

    self.isEnabled = true

    return true
end


---Delete instance
function BaleUnloadTrigger:delete()
    if self.triggerNode ~= nil and self.triggerNode ~= 0 then
        removeTrigger(self.triggerNode)
        self.triggerNode = 0
    end
    self.balesInTrigger = nil

    BaleUnloadTrigger:superClass().delete(self)
end


---Connects object using the trigger to the trigger
-- @param table object target on which the unload trigger is attached
function BaleUnloadTrigger:setTarget(object)
    assert(object.getIsFillTypeAllowed ~= nil)
    assert(object.getIsToolTypeAllowed ~= nil)
    assert(object.addFillUnitFillLevel ~= nil)

    self.target = object
end


















---Update method
-- @param float dt delta time
function BaleUnloadTrigger:update(dt)
    BaleUnloadTrigger:superClass().update(self, dt)
    if self.isServer then
        for index, bale in ipairs(self.balesInTrigger) do
            if bale ~= nil and bale.nodeId ~= 0 then
                if bale:getCanBeSold() then  -- keep currently mounted bales in list, so they are handled once free
                    if bale.dynamicMountType == MountableObject.MOUNT_TYPE_NONE then
                        local fillType = bale:getFillType()
                        local fillLevel = bale:getFillLevel()
                        local fillInfo = nil

                        local delta = bale:getFillLevel()
                        if self.deleteLitersPerMS ~= nil then
                            delta = self.deleteLitersPerMS * dt
                        end

                        if delta > 0 then
                            delta = self.target:addFillUnitFillLevel(bale:getOwnerFarmId(), 1, delta, fillType, ToolType.BALE, fillInfo)
                            bale:setFillLevel(fillLevel - delta)
                            local newFillLevel = bale:getFillLevel()
                            if newFillLevel < 0.01 then
                                if fillType == FillType.COTTON then
                                    local total = g_currentMission:farmStats(self:getOwnerFarmId()):updateStats("soldCottonBales", 1)
                                    g_achievementManager:tryUnlock("CottonBales", total)
                                end

                                bale:delete()
                                table.remove(self.balesInTrigger, index)
                                break
                            end
                        end
                    end
                end
            else
                table.remove(self.balesInTrigger, index)
            end
        end

        if #self.balesInTrigger > 0 then
            self:raiseActive()
        end
    end
end


---Callback method for the bale trigger
-- @param integer triggerId 
-- @param integer otherId 
-- @param bool onEnter 
-- @param bool onLeave 
-- @param bool onStay 
-- @param integer otherShapeId 
function BaleUnloadTrigger:baleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if self.isEnabled then
        local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil then
            if object:isa(Bale) then
                if onEnter then
                    if self:getIsBaleSupportedByUnloadTrigger(object) then
                        self:raiseActive()
                        table.addElement(self.balesInTrigger, object)
                    end
                elseif onLeave then
                    for index, bale in ipairs(self.balesInTrigger) do
                        if bale == object then
                            table.remove(self.balesInTrigger, index)
                            break
                        end
                    end
                end
            else
                if object:isa(Vehicle) and SpecializationUtil.hasSpecialization(BaleLoader, object.specializations) then
                    if onEnter then
                        object:addBaleUnloadTrigger(self)
                    elseif onLeave then
                        object:removeBaleUnloadTrigger(self)
                    end
                end
            end
        end
    end
end


---
function BaleUnloadTrigger.registerXMLPaths(schema, basePath)
    schema:register(XMLValueType.NODE_INDEX, basePath .. "#triggerNode", "Trigger node")
    schema:register(XMLValueType.FLOAT, basePath .. "#deleteLitersPerSecond", "Delete liters per second", 4000)
end
