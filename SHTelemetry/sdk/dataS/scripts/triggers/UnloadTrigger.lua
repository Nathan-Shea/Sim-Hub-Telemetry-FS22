

















local UnloadTrigger_mt = Class(UnloadTrigger, Object)





---Creates a new instance of the class
-- @param bool isServer true if we are server
-- @param bool isClient true if we are client
-- @param table customMt meta table
-- @return table self returns the instance
function UnloadTrigger.new(isServer, isClient, customMt)
    local self = Object.new(isServer, isClient, customMt or UnloadTrigger_mt)

    self.fillTypes = {}
    self.avoidFillTypes = {}
    self.acceptedToolTypes = {}
    self.fillTypeConversions = {}
    self.notAllowedWarningText = nil

    self.extraAttributes = nil

    return self
end


---Loads elements of the class
-- @param table components components
-- @param table xmlFile xml file object
-- @param string xmlNode xml key
-- @param table target target object
-- @param table extraAttributes extra attributes
-- @param table i3dMappings i3dMappings
-- @return boolean success success
function UnloadTrigger:load(components, xmlFile, xmlNode, target, extraAttributes, i3dMappings)
    local baleTriggerKey = xmlNode..".baleTrigger"
    if xmlFile:hasProperty(baleTriggerKey) then
        local className = xmlFile:getValue(baleTriggerKey .. "#class", "BaleUnloadTrigger")
        local class = ClassUtil.getClassObject(className)
        if class == nil then
            Logging.xmlError(xmlFile, "BaleTrigger class '%s' not defined", className, baleTriggerKey)
            return false
        end

        self.baleTrigger = class.new(self.isServer, self.isClient)
        if self.baleTrigger:load(components, xmlFile, baleTriggerKey, self, i3dMappings) then
            self.baleTrigger:setTarget(self)
            self.baleTrigger:register(true)
        else
            self.baleTrigger = nil
        end
    end

    local woodTriggerKey = xmlNode..".woodTrigger"
    if xmlFile:hasProperty(woodTriggerKey) then
        local className = xmlFile:getValue(woodTriggerKey .. "#class", "WoodUnloadTrigger")
        local class = ClassUtil.getClassObject(className)
        if class == nil then
            Logging.xmlError(xmlFile, "WoodTrigger class '%s' not defined", className, woodTriggerKey)
            return false
        end

        self.woodTrigger = class.new(self.isServer, self.isClient)
        if self.woodTrigger:load(components, xmlFile, woodTriggerKey, self, i3dMappings) then
            self.woodTrigger:setTarget(self)
            self.woodTrigger:register(true)
        else
            self.woodTrigger = nil
        end
    end

    self.exactFillRootNode = xmlFile:getValue(xmlNode .. "#exactFillRootNode", nil, components, i3dMappings)

    if self.exactFillRootNode ~= nil then
        if not CollisionFlag.getHasFlagSet(self.exactFillRootNode, CollisionFlag.FILLABLE) then
            Logging.xmlWarning(xmlFile, "Missing collision mask bit '%d'. Please add this bit to exact fill root node '%s' of unloadTrigger", CollisionFlag.getBit(CollisionFlag.FILLABLE), I3DUtil.getNodePath(self.exactFillRootNode))
            return false
        end

        g_currentMission:addNodeObject(self.exactFillRootNode, self)
    end

    self.aiNode = xmlFile:getValue(xmlNode .. "#aiNode", nil, components, i3dMappings)
    self.supportsAIUnloading = self.aiNode ~= nil

    local priceScale = xmlFile:getValue(xmlNode .. "#priceScale", nil)
    if priceScale ~= nil then
        self.extraAttributes = {priceScale = priceScale}
    end

    xmlFile:iterate(xmlNode .. ".fillTypeConversion", function(index, fillTypeConversionPath)
        local fillTypeIndexIncoming = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(fillTypeConversionPath .. "#incomingFillType"))
        if fillTypeIndexIncoming ~= nil then
            local fillTypeIndexOutgoing = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(fillTypeConversionPath .. "#outgoingFillType"))
            if fillTypeIndexOutgoing ~= nil then
                local ratio = MathUtil.clamp(xmlFile:getValue(fillTypeConversionPath .. "#ratio", 1), 0.01, 10000)
                self.fillTypeConversions[fillTypeIndexIncoming] = {outgoingFillType=fillTypeIndexOutgoing, ratio=ratio}
            end
        end
    end)

    if target ~= nil then
        self:setTarget(target)
    end

    self:loadFillTypes(xmlFile, xmlNode)
    self:loadAcceptedToolType(xmlFile, xmlNode)
    self:loadAvoidFillTypes(xmlFile, xmlNode)
    self.isEnabled = true

    --TODO: merge tables
    self.extraAttributes = extraAttributes or self.extraAttributes

    return true
end


---
function UnloadTrigger:delete()
    if self.baleTrigger ~= nil then
        self.baleTrigger:delete()
    end

    if self.woodTrigger ~= nil then
        self.woodTrigger:delete()
    end

    if self.exactFillRootNode ~= nil then
        g_currentMission:removeNodeObject(self.exactFillRootNode)
    end

    UnloadTrigger:superClass().delete(self)
end




---Called on client side on join
-- @param integer streamId stream ID
-- @param table connection connection
function UnloadTrigger:readStream(streamId, connection)
    UnloadTrigger:superClass().readStream(self, streamId, connection)
    if connection:getIsServer() then
        if self.baleTrigger ~= nil then
            local baleTriggerId = NetworkUtil.readNodeObjectId(streamId)
            self.baleTrigger:readStream(streamId, connection)
            g_client:finishRegisterObject(self.baleTrigger, baleTriggerId)
        end
        if self.woodTrigger ~= nil then
            local woodTriggerId = NetworkUtil.readNodeObjectId(streamId)
            self.woodTrigger:readStream(streamId, connection)
            g_client:finishRegisterObject(self.woodTrigger, woodTriggerId)
        end
    end
end


---Called on server side on join
-- @param integer streamId stream ID
-- @param table connection connection
function UnloadTrigger:writeStream(streamId, connection)
    UnloadTrigger:superClass().writeStream(self, streamId, connection)
    if not connection:getIsServer() then
        if self.baleTrigger ~= nil then
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.baleTrigger))
            self.baleTrigger:writeStream(streamId, connection)
            g_server:registerObjectInStream(connection, self.baleTrigger)
        end
        if self.woodTrigger ~= nil then
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.woodTrigger))
            self.woodTrigger:writeStream(streamId, connection)
            g_server:registerObjectInStream(connection, self.woodTrigger)
        end
    end
end


---Loads accepted tool type
-- @param table rootNode of the object
-- @param string xmlFile file to read
-- @param string xmlNode xmlNode to read from
function UnloadTrigger:loadAcceptedToolType(xmlFile, xmlNode)
    local acceptedToolTypeNames = xmlFile:getValue(xmlNode .. "#acceptedToolTypes")
    local acceptedToolTypes = string.getVector(acceptedToolTypeNames)

    if acceptedToolTypes ~= nil then
        for _,acceptedToolType in pairs(acceptedToolTypes) do
            local toolTypeInt = g_toolTypeManager:getToolTypeIndexByName(acceptedToolType)
            self.acceptedToolTypes[toolTypeInt] = true
        end
    else
        self.acceptedToolTypes = nil
    end
end


---Loads avoid fill Types
-- @param table rootNode of the object
-- @param string xmlFile file to read
-- @param string xmlNode xmlNode to read from
function UnloadTrigger:loadAvoidFillTypes(xmlFile, xmlNode)
    local avoidFillTypeCategories = xmlFile:getValue(xmlNode .. "#avoidFillTypeCategories")
    local avoidFillTypeNames = xmlFile:getValue(xmlNode .. "#avoidFillTypes")
    local avoidFillTypes = nil

    if avoidFillTypeCategories ~= nil and avoidFillTypeNames == nil then
        avoidFillTypes = g_fillTypeManager:getFillTypesByCategoryNames(avoidFillTypeCategories, "Warning: UnloadTrigger has invalid avoidFillTypeCategory '%s'.")
    elseif avoidFillTypeCategories == nil and avoidFillTypeNames ~= nil then
        avoidFillTypes = g_fillTypeManager:getFillTypesByNames(avoidFillTypeNames, "Warning: UnloadTrigger has invalid avoidFillType '%s'.")
    end
    if avoidFillTypes ~= nil then
        for _,fillType in pairs(avoidFillTypes) do
            self.avoidFillTypes[fillType] = true
        end
    else
        self.avoidFillTypes = nil
    end
end


---Loads fill Types
-- @param table rootNode of the object
-- @param string xmlFile file to read
-- @param string xmlNode xmlNode to read from
function UnloadTrigger:loadFillTypes(xmlFile, xmlNode)
    local fillTypeCategories = xmlFile:getValue(xmlNode .. "#fillTypeCategories")
    local fillTypeNames = xmlFile:getValue(xmlNode .. "#fillTypes")
    local fillTypes = nil

    if fillTypeCategories ~= nil and fillTypeNames == nil then
        fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategories, "Warning: UnloadTrigger has invalid fillTypeCategory '%s'.")
    elseif fillTypeNames ~= nil then
        fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeNames, "Warning: UnloadTrigger has invalid fillType '%s'.")
    end
    if fillTypes ~= nil then
        for _, fillType in pairs(fillTypes) do
            self.fillTypes[fillType] = true
        end
    else
        self.fillTypes = nil
    end
end


---Connects object using the trigger to the trigger
-- @param table object target on which the unload trigger is attached
function UnloadTrigger:setTarget(object)
    assert(object.getIsFillTypeAllowed ~= nil, "Missing 'getIsFillTypeAllowed' method for given target")
    assert(object.getIsToolTypeAllowed ~= nil, "Missing 'getIsToolTypeAllowed' method for given target")
    assert(object.addFillLevelFromTool ~= nil, "Missing 'addFillLevelFromTool' method for given target")
    assert(object.getFreeCapacity ~= nil, "Missing 'getFreeCapacity' method for given target")

    self.target = object
end






---Returns default value '1'
-- @param integer node scenegraph node
function UnloadTrigger:getFillUnitIndexFromNode(node)
    return 1
end


---Returns exactFillRootNode
-- @param integer fillUnitIndex index of fillunit
function UnloadTrigger:getFillUnitExactFillRootNode(fillUnitIndex)
    return self.exactFillRootNode
end


---Increase fill level
-- @param integer fillUnitIndex 
-- @param float fillLevelDelta 
-- @param integer fillTypeIndex 
-- @param table toolType 
-- @param table fillPositionData 
-- @return bool  
function UnloadTrigger:addFillUnitFillLevel(farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, extraAttributes)
    -- TODO: merge tables
    local fillTypeConverison = self.fillTypeConversions[fillTypeIndex]
    if fillTypeConverison ~= nil then
        local convertedFillType, ratio = fillTypeConverison.outgoingFillType, fillTypeConverison.ratio
        local applied = self.target:addFillLevelFromTool(farmId, fillLevelDelta*ratio, convertedFillType, fillPositionData, toolType, extraAttributes or self.extraAttributes)
        return applied / ratio
    end
    local applied = self.target:addFillLevelFromTool(farmId, fillLevelDelta, fillTypeIndex, fillPositionData, toolType, extraAttributes or self.extraAttributes)
    return applied
end











---Checks if fill type is allowed
-- @param integer fillUnitIndex 
-- @param integer fillType 
-- @return bool true if allowed
function UnloadTrigger:getFillUnitAllowsFillType(fillUnitIndex, fillType)
    return self:getIsFillTypeAllowed(fillType)
end


---Checks if fillType is allowed
-- @param integer fillType 
-- @return boolean isAllowed true if fillType is supported else false
function UnloadTrigger:getIsFillTypeAllowed(fillType)
    return self:getIsFillTypeSupported(fillType)
end


---Checks if fillType is supported
-- @param integer fillType 
-- @return boolean isSupported true if fillType is supported else false
function UnloadTrigger:getIsFillTypeSupported(fillType)
    if self.fillTypes ~= nil then
        if not self.fillTypes[fillType] then
            return false
        end
    end

    if self.avoidFillTypes ~= nil then
        if self.avoidFillTypes[fillType] then
            return false
        end
    end

    if self.target ~= nil then
        local conversion = self.fillTypeConversions[fillType]
        if conversion ~= nil then
            fillType = conversion.outgoingFillType
        end
        if not self.target:getIsFillTypeAllowed(fillType, self.extraAttributes) then
            return false
        end
    end

    return true
end










---Returns the free capacity
-- @param integer fillUnitIndex fill unit index
-- @param integer fillTypeIndex fill type index
-- @return float freeCapacity free capacity
function UnloadTrigger:getFillUnitFreeCapacity(fillUnitIndex, fillTypeIndex, farmId)
    if self.target.getFreeCapacity ~= nil then
        local conversion = self.fillTypeConversions[fillTypeIndex]
        if conversion ~= nil then
            return self.target:getFreeCapacity(conversion.outgoingFillType, farmId, self.extraAttributes) / conversion.ratio
        end
        return self.target:getFreeCapacity(fillTypeIndex, farmId, self.extraAttributes)
    end
    return 0
end


---Checks if toolType is allowed
-- @param integer toolType 
-- @return boolean isAllowed true if toolType is allowed else false
function UnloadTrigger:getIsToolTypeAllowed(toolType)
    local accepted = true

    if self.acceptedToolTypes ~= nil then
        if self.acceptedToolTypes[toolType] ~= true then
            accepted = false
        end
    end

    if accepted then
        return self.target:getIsToolTypeAllowed(toolType)
    else
        return false
    end
end


---
function UnloadTrigger:getCustomDischargeNotAllowedWarning()
    return self.notAllowedWarningText
end























---
function UnloadTrigger.registerXMLPaths(schema, basePath)
    BaleUnloadTrigger.registerXMLPaths(schema, basePath .. ".baleTrigger")
    schema:register(XMLValueType.STRING,        basePath .. ".baleTrigger#class", "Name of bale trigger class")

    WoodUnloadTrigger.registerXMLPaths(schema, basePath .. ".woodTrigger")
    schema:register(XMLValueType.STRING,        basePath .. ".woodTrigger#class", "Name of wood trigger class")
    schema:register(XMLValueType.NODE_INDEX,    basePath .. "#exactFillRootNode", "Exact fill root node")
    schema:register(XMLValueType.FLOAT,         basePath .. "#priceScale", "Price scale added for sold goods")
    schema:register(XMLValueType.STRING,        basePath .. "#acceptedToolTypes", "List of accepted tool types")
    schema:register(XMLValueType.STRING,        basePath .. "#avoidFillTypeCategories", "Avoided fill type categories (Even if target would allow the fill type)")
    schema:register(XMLValueType.STRING,        basePath .. "#avoidFillTypes", "Avoided fill types (Even if target would allow the fill type)")
    schema:register(XMLValueType.STRING,        basePath .. "#fillTypeCategories", "Supported fill type categories")
    schema:register(XMLValueType.STRING,        basePath .. "#fillTypes", "Supported fill types")
    schema:register(XMLValueType.NODE_INDEX,    basePath .. "#aiNode", "AI target node, required for the station to support AI. AI drives to the node in positive Z direction. Height is not relevant.")
    schema:register(XMLValueType.STRING,        basePath .. ".fillTypeConversion(?)#incomingFillType", "Filltype to be converted")
    schema:register(XMLValueType.STRING,        basePath .. ".fillTypeConversion(?)#outgoingFillType", "Filltype to be converted to")
    schema:register(XMLValueType.FLOAT,         basePath .. ".fillTypeConversion(?)#ratio", "Conversion ratio between input- and output amount", 1)
end
