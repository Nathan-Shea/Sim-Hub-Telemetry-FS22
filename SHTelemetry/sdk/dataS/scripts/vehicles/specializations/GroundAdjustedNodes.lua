---Specialization for adjusting nodes to the ground/terrain height (e.g. liquid manure spreaders with hoses)














---
function GroundAdjustedNodes.prerequisitesPresent(specializations)
    return true
end


---Called on specialization initializing
function GroundAdjustedNodes.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("GroundAdjustedNodes")

    local basePath = GroundAdjustedNodes.GROUND_ADJUSTED_NODE_XML_KEY

    schema:register(XMLValueType.NODE_INDEX, basePath .. "#node", "Ground adjusted node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".raycastNode(?)#node", "Ground adjusted raycast node")
    schema:register(XMLValueType.FLOAT, basePath .. ".raycastNode(?)#distance", "Ground adjusted raycast distance", 4)
    schema:register(XMLValueType.INT, basePath .. ".raycastNode(?)#updateFrame", "Defines the frame delay between two raycasts", "Number of raycasts")

    schema:register(XMLValueType.FLOAT, basePath .. "#minY", "Min. Y translation", "translation in i3d - 1")
    schema:register(XMLValueType.FLOAT, basePath .. "#maxY", "Max. Y translation", "minY + 1")
    schema:register(XMLValueType.FLOAT, basePath .. "#yOffset", "Y translation offset", 0)
    schema:register(XMLValueType.FLOAT, basePath .. "#moveSpeed", "Move speed", 1)
    schema:register(XMLValueType.BOOL, basePath .. "#resetIfNotActive", "Reset node to start translation if not active", true)
    schema:register(XMLValueType.FLOAT, basePath .. "#activationTime", "In this time after the activation of the node the #moveSpeedStateChange will be used", 0)
    schema:register(XMLValueType.FLOAT, basePath .. "#moveSpeedStateChange", "Move speed while node is inactive or active an in range of #activationTime", "#moveSpeed")
    schema:register(XMLValueType.FLOAT, basePath .. "#updateThreshold", "Position of node will be updated if change is greater than this value", 0.002)
    schema:register(XMLValueType.BOOL, basePath .. "#averageInActivePosY", "While nodes are turned off the average Y position will be used as target for all nodes", false)

    schema:setXMLSpecializationType()
end


---
function GroundAdjustedNodes.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "loadGroundAdjustedNodeFromXML",        GroundAdjustedNodes.loadGroundAdjustedNodeFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadGroundAdjustedRaycastNodeFromXML", GroundAdjustedNodes.loadGroundAdjustedRaycastNodeFromXML)
    SpecializationUtil.registerFunction(vehicleType, "getIsGroundAdjustedNodeActive",        GroundAdjustedNodes.getIsGroundAdjustedNodeActive)
    SpecializationUtil.registerFunction(vehicleType, "updateGroundAdjustedNode",             GroundAdjustedNodes.updateGroundAdjustedNode)
    SpecializationUtil.registerFunction(vehicleType, "groundAdjustRaycastCallback",          GroundAdjustedNodes.groundAdjustRaycastCallback)
end


---
function GroundAdjustedNodes.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", GroundAdjustedNodes)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", GroundAdjustedNodes)
end


---
function GroundAdjustedNodes:onLoad(savegame)
    local spec = self.spec_groundAdjustedNodes

    self.raycastMask = CollisionFlag.TERRAIN + CollisionFlag.STATIC_OBJECT

    spec.groundAdjustedNodes = {}
    local i = 0
    while true do
        local key = string.format("vehicle.groundAdjustedNodes.groundAdjustedNode(%d)", i)
        if not self.xmlFile:hasProperty(key) then
            break
        end

        local node = {}
        if self:loadGroundAdjustedNodeFromXML(self.xmlFile, key, node) then
            table.insert(spec.groundAdjustedNodes, node)
        end

        i = i + 1
    end

    for j=1, #spec.groundAdjustedNodes do
        local adjustedNode = spec.groundAdjustedNodes[j]
        for l=1, #adjustedNode.raycastNodes do
            local raycastNode = adjustedNode.raycastNodes[l]
            if raycastNode.updateFrame < 0 then
                raycastNode.updateFrame = #spec.groundAdjustedNodes
            end
            raycastNode.frameCount = j % raycastNode.updateFrame + 1
        end
    end

    self.lastRaycastDistance = 0
    self.lastRaycastGroundPos = {0, 0, 0}

    if #spec.groundAdjustedNodes == 0 then
        SpecializationUtil.removeEventListener(self, "onUpdate", GroundAdjustedNodes)
    end
end


---
function GroundAdjustedNodes:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_groundAdjustedNodes

    for _, adjustedNode in pairs(spec.groundAdjustedNodes) do
        self:updateGroundAdjustedNode(adjustedNode, dt)

        if adjustedNode.targetY ~= adjustedNode.curY then
            local stateChangeActive = not adjustedNode.isActive or adjustedNode.activationTimer > 0
            local moveSpeed = stateChangeActive and adjustedNode.moveSpeedStateChange or adjustedNode.moveSpeed

            if adjustedNode.targetY > adjustedNode.curY then
                adjustedNode.curY = math.min(adjustedNode.curY + moveSpeed*dt, adjustedNode.targetY)
            else
                adjustedNode.curY = math.max(adjustedNode.curY - moveSpeed*dt, adjustedNode.targetY)
            end

            if math.abs(adjustedNode.lastY - adjustedNode.curY) > adjustedNode.updateThreshold then
                setTranslation(adjustedNode.node, adjustedNode.x, adjustedNode.curY, adjustedNode.z)
                adjustedNode.lastY = adjustedNode.curY

                if self.setMovingToolDirty ~= nil then
                    self:setMovingToolDirty(adjustedNode.node)
                end
            end
        end
    end
end


---
function GroundAdjustedNodes:loadGroundAdjustedNodeFromXML(xmlFile, key, adjustedNode)

    XMLUtil.checkDeprecatedXMLElements(xmlFile, self.configFileName, key.."#index", key.."#node") --FS17 to FS19

    local node = xmlFile:getValue(key.."#node", nil, self.components, self.i3dMappings)
    if node == nil then
        Logging.xmlWarning(self.xmlFile, "Missing 'node' for groundAdjustedNode '%s'!", key)
        return false
    end

    local x, y, z = getTranslation(node)
    adjustedNode.node = node
    adjustedNode.x = x
    adjustedNode.y = y
    adjustedNode.z = z
    adjustedNode.raycastNodes = {}

    local j = 0
    while true do
        local raycastKey = string.format("%s.raycastNode(%d)", key, j)
        if not self.xmlFile:hasProperty(raycastKey) then
            break
        end

        local raycastNode = {}
        if self:loadGroundAdjustedRaycastNodeFromXML(xmlFile, raycastKey, adjustedNode, raycastNode) then
            table.insert(adjustedNode.raycastNodes, raycastNode)
        end

        j = j + 1
    end

    if #adjustedNode.raycastNodes > 0 then
        adjustedNode.minY = self.xmlFile:getValue(key.."#minY", y - 1)
        adjustedNode.maxY = self.xmlFile:getValue(key.."#maxY", adjustedNode.minY + 1)
        adjustedNode.yOffset = self.xmlFile:getValue(key.."#yOffset", 0)
        adjustedNode.moveSpeed = (self.xmlFile:getValue(key.."#moveSpeed", 1)) / 1000
        adjustedNode.moveSpeedStateChange = (self.xmlFile:getValue(key.."#moveSpeedStateChange", 1)) / 1000
        adjustedNode.activationTime = self.xmlFile:getValue(key.."#activationTime", 0) * 1000
        adjustedNode.activationTimer = 0
        adjustedNode.resetIfNotActive = self.xmlFile:getValue(key.."#resetIfNotActive", true)
        adjustedNode.updateThreshold = self.xmlFile:getValue(key.."#updateThreshold", 0.002)

        adjustedNode.inActiveY = y
        adjustedNode.averageInActivePosY = self.xmlFile:getValue(key.."#averageInActivePosY", false)

        adjustedNode.targetY = y
        adjustedNode.curY = y
        adjustedNode.lastY = y
        adjustedNode.isActive = false
    else
        Logging.xmlWarning(self.xmlFile, "No raycastNodes defined for groundAdjustedNode '%s'!", key)
        return false
    end

    return true
end


---
function GroundAdjustedNodes:loadGroundAdjustedRaycastNodeFromXML(xmlFile, key, groundAdjustedNode, raycastNode)
    XMLUtil.checkDeprecatedXMLElements(xmlFile, self.configFileName, key.."#index", key.."#node") --FS17 to FS19

    local node = self.xmlFile:getValue(key.."#node", nil, self.components, self.i3dMappings)
    if node == nil then
        Logging.xmlWarning(self.xmlFile, "Missing 'node' for groundAdjustedNodes raycast '%s'!", key)
        return false
    end

    if getParent(groundAdjustedNode.node) ~= getParent(node) then
        Logging.xmlWarning(self.xmlFile, "Raycast node is not on the same hierarchy level as the groundAdjustedNode (%s)!", key)
        return false
    end

    local _,y1,_ = getTranslation(node)
    raycastNode.node = node
    raycastNode.yDiff = y1 - groundAdjustedNode.y
    raycastNode.distance = self.xmlFile:getValue(key.."#distance", 4)

    raycastNode.history = {}
    for i=1, 2 do
        raycastNode.history[i] = {0, 0, 0, 0}
    end
    raycastNode.lastRaycastPos = {0, 0, 0, 0}

    raycastNode.updateFrame = self.xmlFile:getValue(key.."#updateFrame", -1)
    raycastNode.frameCount = 1

    return true
end


---
function GroundAdjustedNodes:updateGroundAdjustedNode(adjustedNode, dt)
    local wasActive = adjustedNode.isActive
    adjustedNode.isActive = self:getIsGroundAdjustedNodeActive(adjustedNode)
    if adjustedNode.isActive then
        adjustedNode.activationTimer = math.max(adjustedNode.activationTimer - dt, 0)

        for i=1, #adjustedNode.raycastNodes do
            local raycastNode = adjustedNode.raycastNodes[i]

            local distance
            local rx, ry, rz
            if raycastNode.frameCount == raycastNode.updateFrame then
                local x,y,z = localToWorld(raycastNode.node, 0, adjustedNode.yOffset, 0)
                local dx,dy,dz = localDirectionToWorld(raycastNode.node, 0, -1, 0)

                self.lastRaycastDistance = 0
                raycastAll(x, y, z, dx, dy, dz, "groundAdjustRaycastCallback", raycastNode.distance, self, self.raycastMask)
                distance = self.lastRaycastDistance

                --#debug drawDebugLine(x, y, z, 0, 1, 0, x+dx*raycastNode.distance, y+dy*raycastNode.distance, z+dz*raycastNode.distance, 1, 0, 0, true)

                if raycastNode.updateFrame > 1 and distance ~= 0 then
                    local oldData = raycastNode.history[2]
                    oldData[1], oldData[2], oldData[3], oldData[4] = self.lastRaycastGroundPos[1], self.lastRaycastGroundPos[2], self.lastRaycastGroundPos[3], self.lastRaycastDistance
                    raycastNode.history[2] = raycastNode.history[1]
                    raycastNode.history[1] = oldData

                    rx, ry, rz = oldData[1], oldData[2], oldData[3]
                end
            else
                local history1 = raycastNode.history[1]
                local history2 = raycastNode.history[2]
                local x1, y1, z1 = history1[1], history1[2], history1[3]
                local x2, y2, z2 = history2[1], history2[2], history2[3]

                if raycastNode.lastRaycastPos[1] ~= nil then
                    rx = raycastNode.lastRaycastPos[1] + (x1 - x2) / raycastNode.updateFrame
                    ry = raycastNode.lastRaycastPos[2] + (y1 - y2) / raycastNode.updateFrame
                    rz = raycastNode.lastRaycastPos[3] + (z1 - z2) / raycastNode.updateFrame

                    local x, y, z = localToWorld(raycastNode.node, 0, adjustedNode.yOffset, 0)
                    distance = MathUtil.vector3Length(x-rx, y-ry, z-rz)
                else
                    distance = 0
                end
            end

            if raycastNode.updateFrame > 1 then
                raycastNode.lastRaycastPos[1] = rx
                raycastNode.lastRaycastPos[2] = ry
                raycastNode.lastRaycastPos[3] = rz
                raycastNode.lastRaycastPos[4] = distance

                raycastNode.frameCount = raycastNode.frameCount + 1
                if raycastNode.frameCount > raycastNode.updateFrame then
                    raycastNode.frameCount = 1
                end
            end

            local newY
            if distance ~= 0 then
                newY = adjustedNode.y + adjustedNode.yOffset - distance + raycastNode.yDiff
            else
                -- if we did not hit the ground we use the last target value, since we don't know where we exceeded the limit
                newY = adjustedNode.targetY
            end

            newY = MathUtil.clamp(newY, adjustedNode.minY, adjustedNode.maxY)
            adjustedNode.targetY = newY
            local _
            _, adjustedNode.curY, _ = getTranslation(adjustedNode.node)
        end
    else
        if adjustedNode.averageInActivePosY and wasActive then
            local groundAdjustedNodes = self.spec_groundAdjustedNodes.groundAdjustedNodes
            local inActiveY, numNodes = 0, 0
            for _, _adjustedNode in pairs(groundAdjustedNodes) do
                if _adjustedNode.averageInActivePosY then
                    inActiveY = inActiveY + _adjustedNode.curY
                    numNodes = numNodes + 1
                end
            end

            if numNodes > 0 then
                adjustedNode.inActiveY = inActiveY / numNodes

                -- reapply to all since some could have already changed
                for _, _adjustedNode in pairs(groundAdjustedNodes) do
                    if _adjustedNode.averageInActivePosY then
                        _adjustedNode.inActiveY = inActiveY / numNodes
                    end
                end
            end
        end

        if adjustedNode.resetIfNotActive then
            adjustedNode.targetY = adjustedNode.inActiveY
        end

        adjustedNode.activationTimer = adjustedNode.activationTime
    end
end


---
function GroundAdjustedNodes:getIsGroundAdjustedNodeActive(groundAdjustedNode)
    return self.getAttacherVehicle == nil or self:getAttacherVehicle() ~= nil
end


---Raycast callback
-- @param integer transformId id raycasted object
-- @param float x x raycast position
-- @param float y y raycast position
-- @param float z z raycast position
-- @param float distance distance to raycast position
function GroundAdjustedNodes:groundAdjustRaycastCallback(transformId, x, y, z, distance)
    if getHasTrigger(transformId) then
        return true
    end

    self.lastRaycastDistance = distance
    self.lastRaycastGroundPos[1], self.lastRaycastGroundPos[2], self.lastRaycastGroundPos[3] = x, y, z

    --#debug DebugUtil.drawDebugGizmoAtWorldPos(x, y, z, 0, 0, 1, 0, 1, 0, "", false)

    return false
end
