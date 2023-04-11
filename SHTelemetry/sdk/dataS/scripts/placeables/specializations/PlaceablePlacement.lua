---Specialization for placeables













---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PlaceablePlacement.prerequisitesPresent(specializations)
    return true
end


---
function PlaceablePlacement.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "loadTestArea", PlaceablePlacement.loadTestArea)
    SpecializationUtil.registerFunction(placeableType, "startPlacementCheck", PlaceablePlacement.startPlacementCheck)
    SpecializationUtil.registerFunction(placeableType, "getPlacementRotation", PlaceablePlacement.getPlacementRotation)
    SpecializationUtil.registerFunction(placeableType, "getPlacementPosition", PlaceablePlacement.getPlacementPosition)
    SpecializationUtil.registerFunction(placeableType, "getPositionSnapSize", PlaceablePlacement.getPositionSnapSize)
    SpecializationUtil.registerFunction(placeableType, "getPositionSnapOffset", PlaceablePlacement.getPositionSnapOffset)
    SpecializationUtil.registerFunction(placeableType, "getRotationSnapAngle", PlaceablePlacement.getRotationSnapAngle)
    SpecializationUtil.registerFunction(placeableType, "getHasOverlap", PlaceablePlacement.getHasOverlap)
    SpecializationUtil.registerFunction(placeableType, "getHasOverlapWithPlaces", PlaceablePlacement.getHasOverlapWithPlaces)
    SpecializationUtil.registerFunction(placeableType, "getHasOverlapWithZones", PlaceablePlacement.getHasOverlapWithZones)
    SpecializationUtil.registerFunction(placeableType, "getTestParallelogramAtWorldPosition", PlaceablePlacement.getTestParallelogramAtWorldPosition)
    SpecializationUtil.registerFunction(placeableType, "playPlaceSound", PlaceablePlacement.playPlaceSound)
    SpecializationUtil.registerFunction(placeableType, "playDestroySound", PlaceablePlacement.playDestroySound)
end


---
function PlaceablePlacement.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceablePlacement)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceablePlacement)
    SpecializationUtil.registerEventListener(placeableType, "onPreFinalizePlacement", PlaceablePlacement)
end


---
function PlaceablePlacement.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("Placement")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".placement#pos1Node", "Position node 1 (Required if alignToWorldY is false to calculate the terrain alignment)")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".placement#pos2Node", "Position node 2 (Required if alignToWorldY is false to calculate the terrain alignment)")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".placement#pos3Node", "Position node 3 (Required if alignToWorldY is false to calculate the terrain alignment)")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".placement.testAreas.testArea(?)#startNode", "Start node of box for testing overlap")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".placement.testAreas.testArea(?)#endNode", "End node of box for testing overlap")

    schema:register(XMLValueType.BOOL, basePath .. ".placement#useRandomYRotation", "Use random Y rotation", false)
    schema:register(XMLValueType.BOOL, basePath .. ".placement#useManualYRotation", "Use manual Y rotation", false)
    schema:register(XMLValueType.BOOL, basePath .. ".placement#alignToWorldY", "Placeable is aligned to world Y instead of terrain", true)
    schema:register(XMLValueType.FLOAT, basePath .. ".placement#placementPositionSnapSize", "Position snap size", 0)
    schema:register(XMLValueType.FLOAT, basePath .. ".placement#placementPositionSnapOffset", "Position snap offset", 0)
    schema:register(XMLValueType.ANGLE, basePath .. ".placement#placementRotationSnapAngle", "Rotation snap angle", 0)

    SoundManager.registerSampleXMLPaths(schema, basePath .. ".placement.sounds", "place")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".placement.sounds", "placeLayered")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".placement.sounds", "destroy")

    schema:setXMLSpecializationType()
end


---Called on loading
-- @param table savegame savegame
function PlaceablePlacement:onLoad(savegame)
    local spec = self.spec_placement
    local xmlFile = self.xmlFile

    spec.testAreas = {}
    xmlFile:iterate("placeable.placement.testAreas.testArea", function(_, key)
        local testArea = {}
        if self:loadTestArea(xmlFile, key, testArea) then
            table.insert(spec.testAreas, testArea)
        end
    end)

    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#sizeX") -- FS19 to FS22
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#sizeZ") -- FS19 to FS22
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#sizeOffsetX") -- FS19 to FS22
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#sizeOffsetZ") -- FS19 to FS22
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#testSizeX", "placeable.placement.testAreas.testArea") -- FS19 to FS22
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#testSizeZ", "placeable.placement.testAreas.testArea") -- FS19 to FS22
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#testSizeOffsetX", "placeable.placement.testAreas.testArea") -- FS19 to FS22
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "placeable.placement#testSizeOffsetZ", "placeable.placement.testAreas.testArea") -- FS19 to FS22

    -- fallback to legacy xmls
    -- TODO: remove
    local testSizeX = xmlFile:getFloat("placeable.placement#testSizeX")
    local testSizeZ = xmlFile:getFloat("placeable.placement#testSizeZ")
    if testSizeX ~= nil and testSizeZ ~= nil then
        local testSizeOffsetX = xmlFile:getFloat("placeable.placement#testSizeOffsetX", 0)
        local testSizeOffsetZ = xmlFile:getFloat("placeable.placement#testSizeOffsetZ", 0)

        local startNode = createTransformGroup("legacyTestAreaStartNode")
        local endNode = createTransformGroup("legacyTestAreaEndNode")
        link(self.rootNode, startNode)
        link(startNode, endNode)

        setTranslation(startNode, -testSizeX * 0.5 + testSizeOffsetX, 0, -testSizeZ * 0.5 + testSizeOffsetZ)
        setTranslation(endNode, testSizeX, 2, testSizeZ)

        local testArea = {}
        testArea.startNode = startNode
        testArea.endNode = endNode

        testArea.size = {}
        testArea.size.x = math.abs(testSizeX)
        testArea.size.y = 2
        testArea.size.z = math.abs(testSizeZ)

        testArea.center = {}
        testArea.center.x = testSizeOffsetX
        testArea.center.y = testArea.size.y * 0.5
        testArea.center.z = testSizeOffsetZ

        testArea.debugTestBox = DebugCube.new()
        testArea.debugStartNode = DebugGizmo.new()
        testArea.debugEndNode = DebugGizmo.new()
        testArea.debugArea = Debug2DArea.new(true, false, {1, 0, 0, 0.3})

        testArea.rotYOffset = 0
        table.insert(spec.testAreas, testArea)
    end

    spec.useRandomYRotation = xmlFile:getValue("placeable.placement#useRandomYRotation", spec.useRandomYRotation)
    spec.useManualYRotation = xmlFile:getValue("placeable.placement#useManualYRotation", spec.useManualYRotation)
    spec.positionSnapSize = math.abs(xmlFile:getValue("placeable.placement#placementPositionSnapSize", 0.0))
    spec.positionSnapOffset = math.abs(xmlFile:getValue("placeable.placement#placementPositionSnapOffset", 0.0))
    spec.rotationSnapAngle = math.abs(xmlFile:getValue("placeable.placement#placementRotationSnapAngle", 0.0))

    spec.alignToWorldY = xmlFile:getValue("placeable.placement#alignToWorldY", true)
    if not spec.alignToWorldY then
        spec.pos1Node = xmlFile:getValue("placeable.placement#pos1Node", nil, self.components, self.i3dMappings)
        spec.pos2Node = xmlFile:getValue("placeable.placement#pos2Node", nil, self.components, self.i3dMappings)
        spec.pos3Node = xmlFile:getValue("placeable.placement#pos3Node", nil, self.components, self.i3dMappings)
        if spec.pos1Node == nil or spec.pos2Node == nil or spec.pos3Node == nil then
            spec.alignToWorldY = true
            Logging.xmlWarning(xmlFile, "pos1Node, pos2Node and pos3Node has to be set when alignToWorldY is false!")
        end
    end

    if self.isClient then
        spec.samples = {}
        spec.samples.place = g_soundManager:loadSample2DFromXML(xmlFile.handle, "placeable.placement.sounds", "place", self.baseDirectory, 1, AudioGroup.GUI)
        spec.samples.placeLayered = g_soundManager:loadSample2DFromXML(xmlFile.handle, "placeable.placement.sounds", "placeLayered", self.baseDirectory, 1, AudioGroup.GUI)
        spec.samples.destroy = g_soundManager:loadSample2DFromXML(xmlFile.handle, "placeable.placement.sounds", "destroy", self.baseDirectory, 1, AudioGroup.GUI)
    end
end


---
function PlaceablePlacement:onDelete()
    if self.isClient then
        local spec = self.spec_placement
        if spec.samples ~= nil then
            g_soundManager:deleteSample(spec.samples.place)
            g_soundManager:deleteSample(spec.samples.placeLayered)
            g_soundManager:deleteSample(spec.samples.destroy)
        end
    end
end


---
function PlaceablePlacement:loadTestArea(xmlFile, key, area)
    local startNode = xmlFile:getValue(key .. "#startNode", nil, self.components, self.i3dMappings)
    local endNode = xmlFile:getValue(key .. "#endNode", nil, self.components, self.i3dMappings)

    if startNode == nil then
        Logging.xmlWarning(xmlFile, "Missing test area start node for '%s'", key)
        return false
    end

    if endNode == nil then
        Logging.xmlWarning(xmlFile, "Missing test area end node for '%s'", key)
        return false
    end

    if getParent(endNode) ~= startNode then
        Logging.xmlWarning(xmlFile, "Test area end node is not a direct child of startNode for '%s'", key)
        return false
    end

    area.startNode = startNode
    area.endNode = endNode

    local ySafetyOffset = 0.05  -- shift all test areas down by 5cm to avoid stacking of placables with testArea start at y=0
    local offsetX, offsetY, offsetZ = localToLocal(endNode, startNode, 0, -ySafetyOffset, 0)
    local centerX, centerY, centerZ = localToLocal(startNode, self.rootNode, offsetX*0.5, offsetY*0.5, offsetZ*0.5)
    local sizeX, sizeY, sizeZ = math.abs(offsetX), math.abs(offsetY+ySafetyOffset), math.abs(offsetZ)

    if offsetY < 0.01 then
        Logging.xmlDevWarning(xmlFile, "TestArea '%s 'has no height (endNode has same y as startNode)", key)
    end

    area.size = {}
    area.size.x = math.abs(sizeX)
    area.size.y = math.abs(sizeY)
    area.size.z = math.abs(sizeZ)

    area.center = {}
    area.center.x = centerX
    area.center.y = centerY
    area.center.z = centerZ

    local dirX, _, dirZ = localDirectionToLocal(startNode, self.rootNode, 0, 0, 1)
    local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ)
    area.rotYOffset = rotY

    area.debugTestBox = DebugCube.new()
    area.debugStartNode = DebugGizmo.new()
    area.debugEndNode = DebugGizmo.new()
    area.debugArea = Debug2DArea.new(true, false, {1, 0, 0, 0.3})

    return true
end


---
function PlaceablePlacement:getPlacementRotation(x, y, z)
    local spec = self.spec_placement
    if spec.rotationSnapAngle ~= 0 then
        local degAngle = MathUtil.snapValue(math.deg(y), math.deg(spec.rotationSnapAngle))
        y = math.rad(degAngle)
    end

    return x, y, z
end


---
function PlaceablePlacement:getPlacementPosition(x, y, z)
    local spec = self.spec_placement
    local snapSize = spec.positionSnapSize
    if snapSize ~= 0 then
        snapSize = 1 / snapSize

        x = math.floor(x * snapSize) / snapSize + spec.positionSnapOffset
        z = math.floor(z * snapSize) / snapSize + spec.positionSnapOffset
    end

    return x, y, z
end


---
function PlaceablePlacement:getPositionSnapSize()
    return self.spec_placement.positionSnapSize
end


---
function PlaceablePlacement:getPositionSnapOffset()
    return self.spec_placement.positionSnapOffset
end


---
function PlaceablePlacement:getRotationSnapAngle()
    return self.spec_placement.rotationSnapAngle
end


---
function PlaceablePlacement:onPreFinalizePlacement()
    local spec = self.spec_placement
    -- only (re-)align if the property is set and we're on the server, clients will get the correct transform in sync.
    -- This also avoids wrong positioning of placeables on modified terrain.
    if not spec.alignToWorldY and self.isServer then
        local x1,y1,z1 = getWorldTranslation(self.rootNode)
        y1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1,y1,z1)
        setTranslation(self.rootNode, x1,y1,z1)
        local x2,y2,z2 = getWorldTranslation(spec.pos1Node)
        y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2,y2,z2)
        local x3,y3,z3 = getWorldTranslation(spec.pos2Node)
        y3 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x3,y3,z3)
        local x4,y4,z4 = getWorldTranslation(spec.pos3Node)
        y4 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x4,y4,z4)
        local dirX = x2 - x1
        local dirY = y2 - y1
        local dirZ = z2 - z1
        local dir2X = x3 - x4
        local dir2Y = y3 - y4
        local dir2Z = z3 - z4
        local upX,upY,upZ = MathUtil.crossProduct(dir2X, dir2Y, dir2Z, dirX, dirY, dirZ)
        setDirection(self.rootNode, dirX, dirY, dirZ, upX,upY,upZ)
    end
end


---
function PlaceablePlacement:getIsAreaOwned(farmId)
    local spec = self.spec_placement
    local halfX = spec.testSizeX * 0.5
    local halfZ = spec.testSizeZ * 0.5
    local offsetX = spec.testSizeOffsetX
    local offsetZ = spec.testSizeOffsetZ

    local x1, _, z1 = localToWorld(self.rootNode, -halfX + offsetX, 0, -halfZ + offsetZ)
    local x2, _, z2 = localToWorld(self.rootNode,  halfX + offsetX, 0, -halfZ + offsetZ)
    local x3, _, z3 = localToWorld(self.rootNode, -halfX + offsetX, 0,  halfZ + offsetZ)
    local x4, _, z4 = localToWorld(self.rootNode,  halfX + offsetX, 0,  halfZ + offsetZ)

    return g_farmlandManager:getIsOwnedByFarmAtWorldPosition(farmId, x1, z1) and
           g_farmlandManager:getIsOwnedByFarmAtWorldPosition(farmId, x2, z2) and
           g_farmlandManager:getIsOwnedByFarmAtWorldPosition(farmId, x3, z3) and
           g_farmlandManager:getIsOwnedByFarmAtWorldPosition(farmId, x4, z4)
end


---
function PlaceablePlacement:startPlacementCheck(x, y, z, rotY)
end


---
function PlaceablePlacement:getHasOverlap(x, y, z, rotY, checkFunc)
    local spec = self.spec_placement

    local callbackTarget = {hasOverlap = false}
    callbackTarget.overlapCallback = function(target, hitObjectId, hitX, hitY, hitZ, distance)
        if checkFunc ~= nil then
            if checkFunc(hitObjectId) then
                callbackTarget.hasOverlap = true
                callbackTarget.node = hitObjectId
                return false
            end
        else
            if hitObjectId ~= g_currentMission.terrainRootNode then
                callbackTarget.hasOverlap = true
                callbackTarget.node = hitObjectId
                return false
            end
        end

        return true
    end

    for _, area in ipairs(spec.testAreas) do
        local size = area.size
        local center = area.center

        local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
        local normX, _, normZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

        local posX = x + dirX * center.z + normX * center.x
        local posY = y + center.y
        local posZ = z + dirZ * center.z + normZ * center.x

        local sizeXHalf, sizeZHalf = size.x*0.5, size.z*0.5
        local frontLeftX, frontLeftZ = posX + dirX*sizeZHalf - normX*sizeXHalf, posZ + dirZ*sizeZHalf - normZ*sizeXHalf
        local frontRightX, frontRightZ = posX + dirX*sizeZHalf + normX*sizeXHalf, posZ + dirZ*sizeZHalf + normZ*sizeXHalf
        local backLeftX, backLeftZ = posX - dirX*sizeZHalf - normX*sizeXHalf, posZ - dirZ*sizeZHalf - normZ*sizeXHalf
        local backRightX, backRightZ = posX - dirX*sizeZHalf + normX*sizeXHalf, posZ - dirZ*sizeZHalf + normZ*sizeXHalf

        local frontLeftY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, frontLeftX, 0, frontLeftZ)
        local frontRightY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, frontRightX, 0, frontRightZ)
        local backLeftY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, backLeftX, 0, backLeftZ)
        local backRightY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, backRightX, 0, backRightZ)
        local centerY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, posX, 0, posZ)

        local terrainBasedCenterY = math.min(frontLeftY, frontRightY, backLeftY, backRightY, centerY) + size.y*0.5 - 0.5 -- we want to check 0.5m below terrain
        posY = math.max(terrainBasedCenterY, posY)

        overlapBox(posX, posY, posZ, 0, rotY + area.rotYOffset, 0, size.x*0.5, size.y*0.5, size.z*0.5, "overlapCallback", callbackTarget, nil, true, true, true, false)

        --#debug DebugUtil.drawDebugGizmoAtWorldPos(frontLeftX, frontLeftY, frontLeftZ, dirX*5, 0, dirZ*5, 0, 1, 0, "frontLeft", false, {1, 1, 1, 1})
        --#debug DebugUtil.drawDebugGizmoAtWorldPos(frontRightX, frontRightY, frontRightZ, dirX, 0, dirZ, 0, 1, 0, "frontLeft", false, {1, 1, 1, 1})
        --#debug DebugUtil.drawDebugGizmoAtWorldPos(backLeftX, backLeftY, backLeftZ, dirX, 0, dirZ, 0, 1, 0, "frontLeft", false, {1, 1, 1, 1})
        --#debug DebugUtil.drawDebugGizmoAtWorldPos(backRightX, backRightY, backRightZ, dirX, 0, dirZ, 0, 1, 0, "frontLeft", false, {1, 1, 1, 1})
        --#debug DebugUtil.drawOverlapBox(posX, posY, posZ, 0, rotY + area.rotYOffset, 0, size.x*0.5, size.y*0.5, size.z*0.5, 1, 0, 0)

        --#debug if area.debugTestBox then
        --#debug    area.debugTestBox:createWithStartEnd(area.startNode, area.endNode)
        --#debug    g_debugManager:addFrameElement(area.debugTestBox)
        --#debug    area.debugStartNode:createWithNode(area.startNode, getName(area.startNode), false, nil)
        --#debug    g_debugManager:addFrameElement(area.debugStartNode)
        --#debug    area.debugEndNode:createWithNode(area.endNode, getName(area.endNode), false, nil)
        --#debug    g_debugManager:addFrameElement(area.debugEndNode)
        --#debug end

        if callbackTarget.hasOverlap then
            return true, callbackTarget.node
        end

        local startX,startZ, widthX,widthZ, heightX,heightZ = self:getTestParallelogramAtWorldPosition(area, x, z, rotY)

        --#debug    area.debugArea:createWithStartEnd(area.startNode, area.endNode)
        --#debug    g_debugManager:addFrameElement(area.debugArea)

        local density = DensityMapHeightUtil.getValueAtArea(startX, startZ, widthX, widthZ, heightX, heightZ, true)
        if density > 0 then
            return true, nil
        end
    end

    return false, nil
end


---
function PlaceablePlacement:getHasOverlapWithPlaces(places, x, y, z, rotY)
    local spec = self.spec_placement
    for _, area in ipairs(spec.testAreas) do
        local x1, z1, x2, z2, x3, z3, x4, z4 = self:getTestParallelogramAtWorldPosition(area, x, z, rotY)

        if PlacementUtil.isInsidePlacementPlaces(places, x1, y, z1) then
            return true
        end
        if PlacementUtil.isInsidePlacementPlaces(places, x2, y, z2) then
            return true
        end
        if PlacementUtil.isInsidePlacementPlaces(places, x3, y, z3) then
            return true
        end
        if PlacementUtil.isInsidePlacementPlaces(places, x4, y, z4) then
            return true
        end
    end

    return false
end


---
function PlaceablePlacement:getHasOverlapWithZones(zones, x, y, z, rotY)
    local spec = self.spec_placement

    for _, area in ipairs(spec.testAreas) do
        local x1, z1, x2, z2, x3, z3, x4, z4 = self:getTestParallelogramAtWorldPosition(area, x, z, rotY)

        --#debug DebugUtil.drawDebugGizmoAtWorldPos(x1, y, z1, 0, 0, 1, 0, 1, 0, "P1", true)
        --#debug DebugUtil.drawDebugGizmoAtWorldPos(x2, y, z2, 0, 0, 1, 0, 1, 0, "P2", true)
        --#debug DebugUtil.drawDebugGizmoAtWorldPos(x3, y, z3, 0, 0, 1, 0, 1, 0, "P3", true)
        --#debug DebugUtil.drawDebugGizmoAtWorldPos(x4, y, z4, 0, 0, 1, 0, 1, 0, "P4", true)

        if PlacementUtil.isInsideRestrictedZone(zones, x1, y, z1, false) then
            return true
        end
        if PlacementUtil.isInsideRestrictedZone(zones, x2, y, z2, false) then
            return true
        end
        if PlacementUtil.isInsideRestrictedZone(zones, x3, y, z3, false) then
            return true
        end
        if PlacementUtil.isInsideRestrictedZone(zones, x4, y, z4, false) then
            return true
        end

    end

    return false
end


---
function PlaceablePlacement:getTestParallelogramAtWorldPosition(testArea, x, z, rotY)
    local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
    local normX, _, normZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

    local centerXOffset = testArea.center.x
    local centerZOffset = testArea.center.z
    local centerX = x + dirX * centerZOffset + normX * centerXOffset
    local centerZ = z + dirZ * centerZOffset + normZ * centerXOffset

    dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY + testArea.rotYOffset)
    normX, _, normZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)

    local startOffsetX = testArea.size.x * 0.5
    local startOffsetZ = testArea.size.z * 0.5
    local startX = centerX - dirX * startOffsetZ - normX * startOffsetX
    local startZ = centerZ - dirZ * startOffsetZ - normZ * startOffsetX

    local widthOffset = testArea.size.x
    local widthX = startX + normX * widthOffset
    local widthZ = startZ + normZ * widthOffset

    local heightOffset = testArea.size.z
    local heightX = startX + dirX * heightOffset
    local heightZ = startZ + dirZ * heightOffset

    local heightX2 = widthX + dirX * heightOffset
    local heightZ2 = widthZ + dirZ * heightOffset

    return startX, startZ, widthX, widthZ, heightX, heightZ, heightX2, heightZ2
end


---
function PlaceablePlacement:playPlaceSound()
    if self.isClient then
        local spec = self.spec_placement
        g_soundManager:playSample(spec.samples.place)
        g_soundManager:playSample(spec.samples.placeLayered)
    end
end


---
function PlaceablePlacement:playDestroySound(onlyIfNotPlaying)
    if self.isClient then
        local spec = self.spec_placement

        if not onlyIfNotPlaying or not g_soundManager:getIsSamplePlaying(spec.samples.destroy) then
            g_soundManager:playSample(spec.samples.destroy)
        end
    end
end
