---Specialization for placeable object storages which can store bales and pallets
























---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PlaceableObjectStorage.prerequisitesPresent(specializations)
    return true
end


---
function PlaceableObjectStorage.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "canBeSold", PlaceableObjectStorage.canBeSold)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableObjectStorage.updateInfo)
end


---
function PlaceableObjectStorage.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "getObjectStorageSupportsFillType", PlaceableObjectStorage.getObjectStorageSupportsFillType)
    SpecializationUtil.registerFunction(placeableType, "getObjectStorageSupportsObject", PlaceableObjectStorage.getObjectStorageSupportsObject)
    SpecializationUtil.registerFunction(placeableType, "getObjectStorageCanStoreObject", PlaceableObjectStorage.getObjectStorageCanStoreObject)
    SpecializationUtil.registerFunction(placeableType, "getIsBaleSupportedByUnloadTrigger", PlaceableObjectStorage.getIsBaleSupportedByUnloadTrigger)
    SpecializationUtil.registerFunction(placeableType, "addObjectToObjectStorage", PlaceableObjectStorage.addObjectToObjectStorage)
    SpecializationUtil.registerFunction(placeableType, "addAbstactObjectToObjectStorage", PlaceableObjectStorage.addAbstactObjectToObjectStorage)
    SpecializationUtil.registerFunction(placeableType, "removeAbstractObjectsFromStorage", PlaceableObjectStorage.removeAbstractObjectsFromStorage)
    SpecializationUtil.registerFunction(placeableType, "spawnNextObjectStorageObject", PlaceableObjectStorage.spawnNextObjectStorageObject)
    SpecializationUtil.registerFunction(placeableType, "removeAbstractObjectFromStorage", PlaceableObjectStorage.removeAbstractObjectFromStorage)
    SpecializationUtil.registerFunction(placeableType, "setObjectStorageObjectInfosDirty", PlaceableObjectStorage.setObjectStorageObjectInfosDirty)
    SpecializationUtil.registerFunction(placeableType, "updateDirtyObjectStorageObjectInfos", PlaceableObjectStorage.updateDirtyObjectStorageObjectInfos)
    SpecializationUtil.registerFunction(placeableType, "updateObjectStorageObjectInfos", PlaceableObjectStorage.updateObjectStorageObjectInfos)
    SpecializationUtil.registerFunction(placeableType, "getObjectStorageObjectInfos", PlaceableObjectStorage.getObjectStorageObjectInfos)
    SpecializationUtil.registerFunction(placeableType, "updateObjectStorageVisualAreas", PlaceableObjectStorage.updateObjectStorageVisualAreas)
    SpecializationUtil.registerFunction(placeableType, "onObjectStoragePlayerTriggerCallback", PlaceableObjectStorage.onObjectStoragePlayerTriggerCallback)
    SpecializationUtil.registerFunction(placeableType, "onObjectStorageObjectTriggerCallback", PlaceableObjectStorage.onObjectStorageObjectTriggerCallback)
    SpecializationUtil.registerFunction(placeableType, "onObjectStorageSpawnOverlapCallback", PlaceableObjectStorage.onObjectStorageSpawnOverlapCallback)
end


---
function PlaceableObjectStorage.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableObjectStorage)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableObjectStorage)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableObjectStorage)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableObjectStorage)
    SpecializationUtil.registerEventListener(placeableType, "onReadUpdateStream", PlaceableObjectStorage)
    SpecializationUtil.registerEventListener(placeableType, "onWriteUpdateStream", PlaceableObjectStorage)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", PlaceableObjectStorage)
end


---
function PlaceableObjectStorage.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("ObjectStorage")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".objectStorage.playerTrigger#node", "Player trigger node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".objectStorage.objectTrigger#node", "Object trigger node")


    schema:register(XMLValueType.STRING, basePath .. ".objectStorage#fillTypeCategories", "List of supported fill type categories (if no fill types defined, all are allowed)")
    schema:register(XMLValueType.STRING, basePath .. ".objectStorage#fillTypes", "List of supported fill types (if no fill types defined, all are allowed)")

    schema:register(XMLValueType.BOOL, basePath .. ".objectStorage#supportsBales", "Bales can be stored", true)
    schema:register(XMLValueType.BOOL, basePath .. ".objectStorage#supportsPallets", "Pallets can be stored", true)

    schema:register(XMLValueType.INT, basePath .. ".objectStorage#capacity", "Max. capacity", 250)
    schema:register(XMLValueType.FLOAT, basePath .. ".objectStorage#maxLength", "Max. length of objects to store", "unlimited")
    schema:register(XMLValueType.FLOAT, basePath .. ".objectStorage#maxHeight", "Max. height of objects to store", "unlimited")
    schema:register(XMLValueType.FLOAT, basePath .. ".objectStorage#maxWidth", "Max. width of objects to store", "unlimited")

    schema:register(XMLValueType.INT, basePath .. ".objectStorage#maxUnloadAmount", "Max. amount of objects that can be unloaded at a time", 25)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".objectStorage.spawnAreas.spawnArea(?)#startNode", "Start node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".objectStorage.spawnAreas.spawnArea(?)#endNode", "End node")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".objectStorage.storageAreas.storageArea(?)#startNode", "Start node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".objectStorage.storageAreas.storageArea(?)#endNode", "End node")

    schema:setXMLSpecializationType()
end


---
function PlaceableObjectStorage.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.STRING, basePath .. ".object(?)#className", "Object class name")
    for _, abstractObject in pairs(PlaceableObjectStorage.ABSTRACT_OBJECTS) do
        abstractObject.registerXMLPaths(schema, basePath .. ".object(?)")
    end
end


---Called on loading
-- @param table savegame savegame
function PlaceableObjectStorage:onLoad(savegame)
    local spec = self.spec_objectStorage

    spec.playerTriggerNode = self.xmlFile:getValue("placeable.objectStorage.playerTrigger#node", nil, self.components, self.i3dMappings)
    if spec.playerTriggerNode ~= nil then
        addTrigger(spec.playerTriggerNode, "onObjectStoragePlayerTriggerCallback", self)
    else
        Logging.xmlWarning(self.xmlFile, "Missing player trigger for object storage")
    end

    if self.isServer then
        spec.objectTriggerNode = self.xmlFile:getValue("placeable.objectStorage.objectTrigger#node", nil, self.components, self.i3dMappings)
        if spec.objectTriggerNode ~= nil then
            addTrigger(spec.objectTriggerNode, "onObjectStorageObjectTriggerCallback", self)
        else
            Logging.xmlWarning(self.xmlFile, "Missing object trigger for object storage")
        end
    end

    spec.supportedFillTypes = g_fillTypeManager:getFillTypesFromXML(self.xmlFile, "placeable.objectStorage#fillTypeCategories", "placeable.objectStorage#fillTypes", false)

    spec.supportsBales = self.xmlFile:getValue("placeable.objectStorage#supportsBales", true)
    spec.supportsPallets = self.xmlFile:getValue("placeable.objectStorage#supportsPallets", true)

    spec.capacity = self.xmlFile:getValue("placeable.objectStorage#capacity", 250)
    spec.maxLength = self.xmlFile:getValue("placeable.objectStorage#maxLength", math.huge)
    spec.maxHeight = self.xmlFile:getValue("placeable.objectStorage#maxHeight", math.huge)
    spec.maxWidth = self.xmlFile:getValue("placeable.objectStorage#maxWidth", math.huge)
    spec.maxUnloadAmount = self.xmlFile:getValue("placeable.objectStorage#maxUnloadAmount", 25)

    spec.objectSpawn = {}
    spec.objectSpawn.isActive = false
    spec.objectSpawn.connection = nil
    spec.objectSpawn.objectInfoIndex = 1
    spec.objectSpawn.numObjectsToSpawn = 0
    spec.objectSpawn.overlapIsActive = false
    spec.objectSpawn.overlapObjectCount = 0
    spec.objectSpawn.nextSpawnPosition = {0, 0, 0}
    spec.objectSpawn.spawnAreaIndex = 1
    spec.objectSpawn.spawnAreaData = {0, 0, 0, 0, 0, 1}
    spec.objectSpawn.spawnedObjects = {}

    spec.objectSpawn.area = {}
    self.xmlFile:iterate("placeable.objectStorage.spawnAreas.spawnArea", function(index, areaKey)
        local spawnArea = {}
        spawnArea.startNode = self.xmlFile:getValue(areaKey .. "#startNode", nil, self.components, self.i3dMappings)
        spawnArea.endNode = self.xmlFile:getValue(areaKey .. "#endNode", nil, self.components, self.i3dMappings)
        if spawnArea.startNode ~= nil and spawnArea.endNode ~= nil then
            local _
            spawnArea.sizeX, _, spawnArea.sizeZ = localToLocal(spawnArea.endNode, spawnArea.startNode, 0, 0, 0)
            table.insert(spec.objectSpawn.area, spawnArea)
        else
            Logging.xmlWarning(self.xmlFile, "Incomplete spawn area definition in '%s'", areaKey)
        end
    end)

    spec.storageArea = {}
    spec.storageArea.spawnNode = createTransformGroup("storageAreaSpawnNode")
    link(self.rootNode, spec.storageArea.spawnNode)
    spec.storageArea.spawnAreaIndex = 1
    spec.storageArea.spawnAreaData = {0, 0, 0, 0, 0, 1}
    spec.storageArea.area = {}
    self.xmlFile:iterate("placeable.objectStorage.storageAreas.storageArea", function(index, areaKey)
        local storageArea = {}
        storageArea.startNode = self.xmlFile:getValue(areaKey .. "#startNode", nil, self.components, self.i3dMappings)
        storageArea.endNode = self.xmlFile:getValue(areaKey .. "#endNode", nil, self.components, self.i3dMappings)
        if storageArea.startNode ~= nil and storageArea.endNode ~= nil then
            local _
            storageArea.sizeX, _, storageArea.sizeZ = localToLocal(storageArea.endNode, storageArea.startNode, 0, 0, 0)
            table.insert(spec.storageArea.area, storageArea)
        else
            Logging.xmlWarning(self.xmlFile, "Incomplete spawn area definition in '%s'", areaKey)
        end
    end)

    spec.storedObjects = {}
    spec.objectInfos = {}
    spec.pendingObjects = {}

    spec.numStoredObjects = 0

    spec.objectInfosUpdateTimer = 0
    spec.pendingVisualAreaUpdates = {}

    spec.texts = {}
    spec.texts.warningNotEmpty = g_i18n:getText("info_objectStorageNotEmpty")
    spec.texts.totalCapacity = g_i18n:getText("ui_silos_totalCapacity")
    spec.texts.otherElements = g_i18n:getText("helpLine_IconOverview_Others")

    spec.activatable = PlaceableObjectStorageActivatable.new(self)
    spec.dirtyFlag = self:getNextDirtyFlag()
end



---
function PlaceableObjectStorage:loadFromXMLFile(xmlFile, key)
    xmlFile:iterate(key .. ".object", function(index, objectKey)
        local className = xmlFile:getValue(objectKey .. "#className")
        if className ~= nil then
            local abstractObjectClass = PlaceableObjectStorage.ABSTRACT_OBJECTS_BY_CLASS_NAME[className]
            if abstractObjectClass ~= nil then
                abstractObjectClass.loadFromXMLFile(self, xmlFile, objectKey)
            end
        else
            Logging.xmlWarning(xmlFile, "Unable to find object class '%s' for stored object in '%s'", className, objectKey)
        end
    end)

    self:setObjectStorageObjectInfosDirty()
end


---
function PlaceableObjectStorage:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_objectStorage

    for i=1, #spec.storedObjects do
        local object = spec.storedObjects[i]

        local objectKey = string.format("%s.object(%d)", key, i-1)
        xmlFile:setValue(objectKey .. "#className", object.REFERENCE_CLASS_NAME)

        object:saveToXMLFile(self, xmlFile, objectKey)
    end
end


---
function PlaceableObjectStorage:onDelete()
    local spec = self.spec_objectStorage
    if spec.playerTriggerNode ~= nil then
        removeTrigger(spec.playerTriggerNode)
    end

    if spec.objectTriggerNode ~= nil then
        removeTrigger(spec.objectTriggerNode)
    end

    for i=#spec.storedObjects, 1, -1 do
        spec.storedObjects[i]:delete()
        spec.storedObjects[i] = nil
    end

    spec.numStoredObjects = 0

    for object, _ in pairs(spec.pendingObjects) do
        object:removeDeleteListener(self, PlaceableObjectStorage.onPendingObjectDelete)
        spec.pendingObjects[object] = nil
    end

    g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
end


---
function PlaceableObjectStorage:onReadStream(streamId, connection)
    if connection:getIsServer() then
        local spec = self.spec_objectStorage
        spec.objectInfos = {}

        local numObjectInfos = streamReadUIntN(streamId, PlaceableObjectStorage.NUM_BITS_OBJECT_INFO)
        for i=1, numObjectInfos do
            local objectInfo = {}
            objectInfo.numObjects = streamReadUIntN(streamId, PlaceableObjectStorage.NUM_BITS_AMOUNT)
            local abstractObjectId = streamReadUIntN(streamId, 2)

            local abstractObjectClass = PlaceableObjectStorage.ABSTRACT_OBJECTS_BY_ID[abstractObjectId]
            objectInfo.objects = {abstractObjectClass.readStream(streamId, connection)}

            table.insert(spec.objectInfos, objectInfo)
        end

        spec.numStoredObjects = 0
        for i=1, #spec.objectInfos do
            spec.numStoredObjects = spec.numStoredObjects + spec.objectInfos[i].numObjects
        end

        self:updateObjectStorageVisualAreas()
    end
end


---
function PlaceableObjectStorage:onWriteStream(streamId, connection)
    if not connection:getIsServer() then
        local spec = self.spec_objectStorage

        local objectInfos = spec.objectInfos
        streamWriteUIntN(streamId, #objectInfos, PlaceableObjectStorage.NUM_BITS_OBJECT_INFO)

        for i=1, #objectInfos do
            local objectInfo = objectInfos[i]
            streamWriteUIntN(streamId, objectInfo.numObjects, PlaceableObjectStorage.NUM_BITS_AMOUNT)
            streamWriteUIntN(streamId, objectInfo.objects[1].ABSTRACT_OBJECT_ID, 2)
            objectInfo.objects[1]:writeStream(streamId, connection)
        end
    end
end


---
function PlaceableObjectStorage:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        if streamReadBool(streamId) then
            PlaceableObjectStorage.onReadStream(self, streamId, connection)
        end
    end
end


---
function PlaceableObjectStorage:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.spec_objectStorage.dirtyFlag) ~= 0) then
            PlaceableObjectStorage.onWriteStream(self, streamId, connection)
        end
    end
end


---
function PlaceableObjectStorage:onUpdate(dt)
    local spec = self.spec_objectStorage
    if self.isServer then
        if spec.objectSpawn.isActive then
            if not spec.objectSpawn.overlapIsActive then
                if spec.objectSpawn.overlapObjectCount == 0 then
                    local spawnArea = spec.objectSpawn.area[spec.objectSpawn.spawnAreaIndex]
                    local objectInfo = spec.objectInfos[spec.objectSpawn.objectInfoIndex]
                    local objectToSpawn = objectInfo.objects[1]

                    local ox, oy, oz, _, _, _, _ = objectToSpawn:getSpawnInfo()
                    local cx, cy, cz = localToWorld(spawnArea.startNode, spec.objectSpawn.nextSpawnPosition[1] + ox, spec.objectSpawn.nextSpawnPosition[2] + oy, spec.objectSpawn.nextSpawnPosition[3] + oz)
                    local rx, ry, rz = getWorldRotation(spawnArea.startNode)

                    if objectToSpawn ~= nil then
                        self:removeAbstractObjectFromStorage(objectToSpawn, cx, cy, cz, rx, ry, rz)
                        table.remove(objectInfo.objects, 1)
                    end

                    spec.objectSpawn.numObjectsToSpawn = spec.objectSpawn.numObjectsToSpawn - 1
                end

                self:spawnNextObjectStorageObject(spec.objectSpawn.overlapObjectCount == 0)
            end

            self:raiseActive()
        end

        for object, _ in pairs(spec.pendingObjects) do
            local canStoreObject, _ = self:getObjectStorageCanStoreObject(object) -- here we ignore the potential errorId provided - we only show it once entering the trigger
            if canStoreObject then
                self:addObjectToObjectStorage(object)
                self:setObjectStorageObjectInfosDirty()

                spec.pendingObjects[object] = nil
                object:removeDeleteListener(self, PlaceableObjectStorage.onPendingObjectDelete)
            else
                self:raiseActive()
            end
        end
    end

    if spec.objectInfosUpdateTimer > 0 then
        spec.objectInfosUpdateTimer = spec.objectInfosUpdateTimer - dt
        if spec.objectInfosUpdateTimer <= 0 then
            self:updateObjectStorageObjectInfos()
            self:updateObjectStorageVisualAreas()
            self:raiseDirtyFlags(spec.dirtyFlag)

            spec.objectInfosUpdateTimer = 0
        end
        self:raiseActive()
    end

    for i=#spec.pendingVisualAreaUpdates, 1, -1 do
        local pendingVisualAreaUpdate = spec.pendingVisualAreaUpdates[i]
        if not pendingVisualAreaUpdate.spawnNextObjectInfo() then
            table.remove(spec.pendingVisualAreaUpdates, i)
        else
            self:raiseActive()
        end
    end
end


---
function PlaceableObjectStorage:getObjectStorageSupportsFillType(fillTypeIndex)
    local spec = self.spec_objectStorage
    if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN then
        return #spec.supportedFillTypes == 0
    else
        local found = #spec.supportedFillTypes == 0
        for i=1, #spec.supportedFillTypes do
            if fillTypeIndex == spec.supportedFillTypes[i] then
                found = true
            end
        end

        if not found then
            return false
        end
    end

    return true
end


---Returns if the object is supported at all
function PlaceableObjectStorage:getObjectStorageSupportsObject(object)
    local spec = self.spec_objectStorage
    local abstractObjectClass = PlaceableObjectStorage.ABSTRACT_OBJECTS_BY_CLASS_NAME[ClassUtil.getClassNameByObject(object)]
    if abstractObjectClass ~= nil then
        if not abstractObjectClass.isObjectSupported(self, object) then
            return false
        end
    end

    for i=1, #spec.storedObjects do
        if object == spec.storedObjects[i]:getRealObject() then
            return false
        end
    end

    return true
end


---Returns if the object can currently be stored (this may change during the time the object is in the trigger)
function PlaceableObjectStorage:getObjectStorageCanStoreObject(object)
    local spec = self.spec_objectStorage

    if spec.objectSpawn.isActive then
        return false
    end

    if #spec.storedObjects >= spec.capacity then
        return false, PlaceableObjectStorageErrorEvent.ERROR_STORAGE_IS_FULL
    end

    local abstractObjectClass = PlaceableObjectStorage.ABSTRACT_OBJECTS_BY_CLASS_NAME[ClassUtil.getClassNameByObject(object)]
    if abstractObjectClass ~= nil then
        if not abstractObjectClass.canStoreObject(self, object) then
            return false
        end
    end

    return true
end


---Function used by the bale loader to know if the bale is supported
function PlaceableObjectStorage:getIsBaleSupportedByUnloadTrigger(bale)
    return self:getObjectStorageSupportsObject(bale)
end


---
function PlaceableObjectStorage:addObjectToObjectStorage(object, loadedFromSavegame)
    local abstractObjectClass = PlaceableObjectStorage.ABSTRACT_OBJECTS_BY_CLASS_NAME[ClassUtil.getClassNameByObject(object)]
    if abstractObjectClass ~= nil then
        local abstractObject = abstractObjectClass.new()
        abstractObject:addToStorage(self, object, loadedFromSavegame)
        self:addAbstactObjectToObjectStorage(abstractObject)
    end
end


---
function PlaceableObjectStorage:addAbstactObjectToObjectStorage(abstractObject)
    local spec = self.spec_objectStorage
    table.insert(spec.storedObjects, abstractObject)
    spec.numStoredObjects = #spec.storedObjects
end


---
function PlaceableObjectStorage:removeAbstractObjectsFromStorage(objectInfoIndex, amount, connection)
    local spec = self.spec_objectStorage
    if not spec.objectSpawn.isActive then
        -- do not allow spawning of new objects until the object infos are up to date
        if spec.objectInfosUpdateTimer ~= 0 then
            return
        end

        -- in case the client is sending outdated data
        if spec.objectInfos[objectInfoIndex] == nil or amount > spec.objectInfos[objectInfoIndex].numObjects then
            return
        end

        spec.objectSpawn.isActive = true
        spec.objectSpawn.connection = connection
        spec.objectSpawn.objectInfoIndex = objectInfoIndex
        spec.objectSpawn.numObjectsToSpawn = amount
        spec.objectSpawn.overlapIsActive = false
        spec.objectSpawn.overlapObjectCount = 0
        spec.objectSpawn.spawnAreaIndex = 1
        spec.objectSpawn.spawnAreaData[1], spec.objectSpawn.spawnAreaData[2], spec.objectSpawn.spawnAreaData[3], spec.objectSpawn.spawnAreaData[4], spec.objectSpawn.spawnAreaData[5], spec.objectSpawn.spawnAreaData[6] = 0, 0, 0, 0, 0, math.huge

        for i=#spec.objectSpawn.spawnedObjects, 1, -1 do
            spec.objectSpawn.spawnedObjects[i] = nil
        end

        self:spawnNextObjectStorageObject()
    end
end










































---
function PlaceableObjectStorage:spawnNextObjectStorageObject(lastSuccess)
    local spec = self.spec_objectStorage
    local spawnErrorId

    if spec.objectSpawn.numObjectsToSpawn > 0 then
        local objectInfo = spec.objectInfos[spec.objectSpawn.objectInfoIndex]
        local objectToSpawn = objectInfo.objects[1]

        local limitedObjectId, errorId = objectToSpawn:getLimitedObjectId()
        if limitedObjectId == nil or g_currentMission.slotSystem:getCanAddLimitedObjects(limitedObjectId, 1) then
            local _, _, _, width, height, length, maxStackHeight = objectToSpawn:getSpawnInfo()
            local areaIndex, spawnX, spawnY, spawnZ, offsetX, offsetY, offsetZ, nextOffsetX, nextOffsetZ, stackIndex = PlaceableObjectStorage.getNextSpawnAreaAndOffset(spec.objectSpawn.area, spec.objectSpawn.spawnAreaIndex, spec.objectSpawn.spawnAreaData[1], spec.objectSpawn.spawnAreaData[2], spec.objectSpawn.spawnAreaData[3], spec.objectSpawn.spawnAreaData[4], spec.objectSpawn.spawnAreaData[5], width, height, length, maxStackHeight, spec.objectSpawn.spawnAreaData[6], lastSuccess)
            if areaIndex ~= nil then
                spec.objectSpawn.spawnAreaIndex, spec.objectSpawn.spawnAreaData[1], spec.objectSpawn.spawnAreaData[2], spec.objectSpawn.spawnAreaData[3], spec.objectSpawn.spawnAreaData[4], spec.objectSpawn.spawnAreaData[5], spec.objectSpawn.spawnAreaData[6] = areaIndex, offsetX, offsetY, offsetZ, nextOffsetX, nextOffsetZ, stackIndex
                local spawnArea = spec.objectSpawn.area[spec.objectSpawn.spawnAreaIndex]
                local cx, cy, cz = localToWorld(spawnArea.startNode, spawnX, spawnY + height * 0.5, spawnZ)
                local rx, ry, rz = getWorldRotation(spawnArea.startNode)

                spec.objectSpawn.nextSpawnPosition[1], spec.objectSpawn.nextSpawnPosition[2], spec.objectSpawn.nextSpawnPosition[3] = spawnX, spawnY, spawnZ

                spec.objectSpawn.overlapIsActive = true
                spec.objectSpawn.overlapObjectCount = 0
                overlapBox(cx, cy, cz, rx, ry, rz, width * 0.5, height * 0.5, length * 0.5, "onObjectStorageSpawnOverlapCallback", self, PlaceableObjectStorage.COLLISION_MASK, true, false, true, true)

                self:raiseActive()
                return
            end
        else
            spawnErrorId = errorId
        end
    end

    if spec.objectSpawn.isActive then
        if spec.objectSpawn.numObjectsToSpawn > 0 then
            if spec.objectSpawn.connection ~= nil then
                if g_server ~= nil then
                    spec.objectSpawn.connection:sendEvent(PlaceableObjectStorageErrorEvent.new(self, spawnErrorId or PlaceableObjectStorageErrorEvent.ERROR_NOT_ENOUGH_SPACE))
                end
            end
        end

        spec.objectSpawn.isActive = false
        spec.objectSpawn.connection = nil
        spec.objectSpawn.objectInfoIndex = 1
        spec.objectSpawn.numObjectsToSpawn = 0

        for i=#spec.objectSpawn.spawnedObjects, 1, -1 do
            spec.objectSpawn.spawnedObjects[i] = nil
        end

        self:setObjectStorageObjectInfosDirty()
    end
end


---
function PlaceableObjectStorage:removeAbstractObjectFromStorage(abstractObject, x, y, z, rx, ry, rz)
    local spec = self.spec_objectStorage

    for i=1, #spec.storedObjects do
        if spec.storedObjects[i] == abstractObject then
            table.remove(spec.storedObjects, i)
            abstractObject:removeFromStorage(self, x, y, z, rx, ry, rz, PlaceableObjectStorage.onObjectFromStorageSpawned)
        end
    end

    spec.numStoredObjects = #spec.storedObjects
end


---
function PlaceableObjectStorage.onObjectFromStorageSpawned(self, spawnedObject)
    local spec = self.spec_objectStorage
    if spec.objectSpawn.isActive then
        table.insert(spec.objectSpawn.spawnedObjects, spawnedObject)
    end
end


---
function PlaceableObjectStorage:setObjectStorageObjectInfosDirty()
    local spec = self.spec_objectStorage
    spec.objectInfosUpdateTimer = 1000
    self:raiseActive()
end


---Update infos if they are dirty
function PlaceableObjectStorage:updateDirtyObjectStorageObjectInfos()
    local spec = self.spec_objectStorage
    if spec.objectInfosUpdateTimer > 0 then -- still keep timer running for visual update and sync
        self:updateObjectStorageObjectInfos()
    end
end


---
function PlaceableObjectStorage:updateObjectStorageObjectInfos()
    local spec = self.spec_objectStorage

    local objectInfos = {}

    for i=1, #spec.storedObjects do
        local object = spec.storedObjects[i]

        local foundInfo = false
        for j=1, #objectInfos do
            local objectInfo = objectInfos[j]
            if object:getIsIdentical(objectInfo.objects[1]) then
                table.insert(objectInfo.objects, object)
                objectInfo.numObjects = #objectInfo.objects
                foundInfo = true
            end
        end

        if not foundInfo then
            local objectInfo = {}
            objectInfo.objects = {object}
            objectInfo.numObjects = 1
            table.insert(objectInfos, objectInfo)
        end
    end

    table.sort(objectInfos, function(a, b)
        local _, _, _, widthA, _, _, _ = a.objects[1]:getSpawnInfo()
        local _, _, _, widthB, _, _, _ = b.objects[1]:getSpawnInfo()
        return widthA < widthB
    end)

    spec.objectInfos = objectInfos
end


---
function PlaceableObjectStorage:getObjectStorageObjectInfos()
    return self.spec_objectStorage.objectInfos
end


---
function PlaceableObjectStorage:updateObjectStorageVisualAreas()
    local spec = self.spec_objectStorage

    local area = spec.storageArea

    local oldSpawnNode = area.spawnNode
    area.spawnNode = createTransformGroup("storageAreaSpawnNode")
    link(self.rootNode, area.spawnNode)
    setVisibility(area.spawnNode, false)

    local pendingVisualAreaUpdate = {}
    pendingVisualAreaUpdate.oldSpawnNode = oldSpawnNode
    pendingVisualAreaUpdate.newSpawnNode = area.spawnNode
    pendingVisualAreaUpdate.objectInfosToSpawn = {}

    pendingVisualAreaUpdate.spawnNextObjectInfo = function()
        if #pendingVisualAreaUpdate.objectInfosToSpawn > 0 then
            local objectInfo = pendingVisualAreaUpdate.objectInfosToSpawn[1]
            objectInfo.objects[1]:spawnVisualObjects(objectInfo.visualSpawnInfos)

            table.remove(pendingVisualAreaUpdate.objectInfosToSpawn, 1)

            return true
        else
            delete(pendingVisualAreaUpdate.oldSpawnNode)

            if entityExists(pendingVisualAreaUpdate.newSpawnNode) then
                setVisibility(pendingVisualAreaUpdate.newSpawnNode, true)
            end

            return false
        end
    end

    area.spawnAreaIndex, area.spawnAreaData[1], area.spawnAreaData[2], area.spawnAreaData[3], area.spawnAreaData[4], area.spawnAreaData[5], area.spawnAreaData[6] = 1, 0, 0, 0, 0, 0, math.huge

    for i=1, #spec.objectInfos do
        local objectInfo = spec.objectInfos[i]
        objectInfo.visualSpawnInfos = {}
        area.spawnAreaData[6] = math.huge

        local objectToSpawn = objectInfo.objects[1]
        local ox, oy, oz, width, height, length, maxStackHeight = objectToSpawn:getSpawnInfo()
        for j=1, objectInfo.numObjects do
            local areaIndex, spawnX, spawnY, spawnZ, offsetX, offsetY, offsetZ, nextOffsetX, nextOffsetZ, stackIndex = PlaceableObjectStorage.getNextSpawnAreaAndOffset(area.area, area.spawnAreaIndex, area.spawnAreaData[1], area.spawnAreaData[2], area.spawnAreaData[3], area.spawnAreaData[4], area.spawnAreaData[5], width, height, length, maxStackHeight, area.spawnAreaData[6], true)
            if areaIndex ~= nil then
                area.spawnAreaIndex, area.spawnAreaData[1], area.spawnAreaData[2], area.spawnAreaData[3], area.spawnAreaData[4], area.spawnAreaData[5], area.spawnAreaData[6] = areaIndex, offsetX, offsetY, offsetZ, nextOffsetX, nextOffsetZ, stackIndex

                local spawnArea = area.area[area.spawnAreaIndex]

                local cx, cy, cz = localToLocal(spawnArea.startNode, area.spawnNode, spawnX + ox, spawnY + oy, spawnZ + oz)
                local rx, ry, rz = localRotationToLocal(spawnArea.startNode, area.spawnNode, 0, 0, 0)

                table.insert(objectInfo.visualSpawnInfos, {area.spawnNode, cx, cy, cz, rx, ry, rz})
            end
        end

        if #objectInfo.visualSpawnInfos > 0 then
            table.insert(pendingVisualAreaUpdate.objectInfosToSpawn, objectInfo)
        end
    end

    if pendingVisualAreaUpdate.spawnNextObjectInfo() then
        table.insert(spec.pendingVisualAreaUpdates, pendingVisualAreaUpdate)
        self:raiseActive()
    end
end


---
function PlaceableObjectStorage:onObjectStoragePlayerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
        local spec = self.spec_objectStorage
        if onEnter then
            g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
        elseif onLeave then
            g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
        end
    end
end






















































---
function PlaceableObjectStorage:onObjectStorageSpawnOverlapCallback(objectId)
    local spec = self.spec_objectStorage
    spec.objectSpawn.overlapIsActive = false
    if objectId ~= 0 and not getHasTrigger(objectId) then
        local object = g_currentMission:getNodeObject(objectId)
        if object ~= nil then
            for i=1, #spec.objectSpawn.spawnedObjects do
                if object == spec.objectSpawn.spawnedObjects[i] then
                    return -- ignore slight collisions with just spawned objects
                end
            end
        end

        spec.objectSpawn.overlapObjectCount = spec.objectSpawn.overlapObjectCount + 1
    end
end


---
function PlaceableObjectStorage:canBeSold(superFunc)
    local spec = self.spec_objectStorage
    if #spec.objectInfos > 0 then
        return true, spec.texts.warningNotEmpty
    end

    return superFunc(self)
end


---
function PlaceableObjectStorage:updateInfo(superFunc, infoTable)
    superFunc(self, infoTable)

    local spec = self.spec_objectStorage

    table.insert(infoTable, {title=spec.texts.totalCapacity, text=string.format("%d / %d", spec.numStoredObjects, spec.capacity)})

    local numObjectInfos = #spec.objectInfos
    for i=1, math.min(numObjectInfos, PlaceableObjectStorage.MAX_HUD_INFO_ENTRIES) do
        local objectInfo = spec.objectInfos[i]
        if objectInfo.objects[1] ~= nil then
            local title = objectInfo.objects[1]:getDialogText()
            if string.len(title) > 32 then
                title = string.sub(title, 0, 32) .. "..."
            end
            table.insert(infoTable, {title=title, text=tostring(objectInfo.numObjects)})
        end
    end

    if numObjectInfos > PlaceableObjectStorage.MAX_HUD_INFO_ENTRIES then
        local sumOthers = 0
        for i=PlaceableObjectStorage.MAX_HUD_INFO_ENTRIES + 1, numObjectInfos do
            sumOthers = sumOthers + spec.objectInfos[i].numObjects
        end

        table.insert(infoTable, {title=spec.texts.otherElements, text=tostring(sumOthers)})
    end
end
