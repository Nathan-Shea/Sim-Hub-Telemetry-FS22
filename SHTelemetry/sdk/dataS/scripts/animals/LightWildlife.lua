
































local LightWildlife_mt = Class(LightWildlife)




---new
function LightWildlife.new(customMt)
    local self = setmetatable({}, customMt or LightWildlife_mt)

    self.type = ""
    self.i3dFilename = nil
    self.sharedLoadRequestId = nil
    self.animals = {}
    self.animalStates = {}
    local defaultState = {id="default", classObject=LightWildlifeStateDefault}
    table.insert(self.animalStates, defaultState)
    self.soundsNode = createTransformGroup("lightWildlifeSounds")
    link(getRootNode(), self.soundsNode)

    return self
end


---load
function LightWildlife:load(xmlFilename)
    self.xmlFilename = Utils.getFilename(xmlFilename, self.baseDirectory)
    local xmlFile = loadXMLFile("TempXML", self.xmlFilename)
    if xmlFile == 0 then
        self.xmlFilename = nil
        return false
    end

    local key = "wildlifeAnimal"
    if hasXMLProperty(xmlFile, key) then
        self.type = getXMLString(xmlFile, key .. "#type")
        self.randomSpawnRadius = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#randomSpawnRadius"), 0.0)
        local i3dFilename = getXMLString(xmlFile, key .. ".asset#filename")
        self.shaderNodeString = getXMLString(xmlFile, key .. ".animations#shaderNode")
        self.shaderParmId = getXMLString(xmlFile, key .. ".animations#shaderParameterId")
        self.shaderParmOpcode = getXMLString(xmlFile, key .. ".animations#shaderParameterOpcode")
        self.shaderParmSpeed = getXMLString(xmlFile, key .. ".animations#shaderParameterSpeed")
        self.animations = {}
        self.animations["default"] = {name="default", opcode=0, speed=0.0, transitionTimer=0.0}

        local i = 0
        while true do
            local animkey = string.format(key .. ".animations.animation(%d)", i)
            if not hasXMLProperty(xmlFile, animkey) then
                break
            end
            local state = Utils.getNoNil(getXMLString(xmlFile, animkey.."#conditionState"), "")
            local animation = {}
            animation.opcode = Utils.getNoNil(getXMLInt(xmlFile, animkey.."#opcode"), 0)
            animation.speed = Utils.getNoNil(getXMLFloat(xmlFile, animkey.."#speed"), 0.0)
            animation.transitionTimer = Utils.getNoNil(getXMLFloat(xmlFile, animkey.."#transitionTimer"), 1.0) * 1000.0
            self.animations[state] = animation
            i = i + 1
        end
        if self.type ~= nil and i3dFilename ~= nil then
            self.i3dFilename = Utils.getFilename(i3dFilename, self.baseDirectory)
            local node, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(self.i3dFilename, false, false)
            if node ~= 0 then
                delete(node)
                self.cacheLoadRequestId = sharedLoadRequestId
            end
            delete(xmlFile)
            return true
        end
    end

    delete(xmlFile)
    return false
end


---createAnimals
function LightWildlife:createAnimals(name, spawnPosX, spawnPosY, spawnPosZ, nbAnimals)
    if #self.animals == 0 then
        for i = 1, nbAnimals do
            local node, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(self.i3dFilename, false, false)
            if node ~= nil then
                link(getRootNode(), node)

                local shaderNode = I3DUtil.indexToObject(node, self.shaderNodeString)
                local animal = LightWildlifeAnimal.new(self, i, node, shaderNode)

                animal:init(spawnPosX, spawnPosZ, self.randomSpawnRadius, self.animalStates)
                animal.sharedLoadRequestId = sharedLoadRequestId
                table.insert(self.animals, animal)
            end
        end

        setWorldTranslation(self.soundsNode, spawnPosX, spawnPosY, spawnPosZ)

        return 1
    end
    return 0
end


---delete
function LightWildlife:delete()
    delete(self.soundsNode)
    self:removeAllAnimals()

    if self.cacheLoadRequestId ~= nil then
        g_i3DManager:releaseSharedI3DFile(self.cacheLoadRequestId)
        self.cacheLoadRequestId = nil
    end
end


---delete
function LightWildlife:removeAllAnimals()
    for _, animal in pairs(self.animals) do
        if animal.sharedLoadRequestId ~= nil then
            g_i3DManager:releaseSharedI3DFile(animal.sharedLoadRequestId)
            animal.sharedLoadRequestId = nil
        end
        if animal.i3dNodeId ~= nil then
            delete(animal.i3dNodeId)
        end
    end
    self.animals = {}
end


---update
function LightWildlife:update(dt)
    for _, animal in pairs(self.animals) do
        animal:update(dt)
        animal:updateAnimation(dt)
    end
end


---removeFarAwayAnimals
function LightWildlife:removeFarAwayAnimals(maxDistance, refPosX, refPosY, refPosZ)
    local removeCount = 0

    for i=#self.animals, 1, -1 do
        local deleteAnimal = false
        local animal = self.animals[i]
        if entityExists(self.animals[i].i3dNodeId) then
            local x, y, z = getWorldTranslation(self.animals[i].i3dNodeId)
            local deltaX = refPosX - x
            local deltaY = refPosY - y
            local deltaZ = refPosZ - z
            local distSq = deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ

            if distSq > (maxDistance * maxDistance) then
                delete(self.animals[i].i3dNodeId)
                deleteAnimal = true
            end
        else
            deleteAnimal = true
        end

        if deleteAnimal then
            table.remove(self.animals, i)
            removeCount = removeCount + 1

            if animal.sharedLoadRequestId ~= nil then
                g_i3DManager:releaseSharedI3DFile(animal.sharedLoadRequestId)
                animal.sharedLoadRequestId = nil
            end
        end
    end
    return removeCount
end


---getClosestDistance
-- @param float refPosX reference x world position
-- @param float refPosY reference x world position
-- @param float refPosZ reference x world position
-- @return float closest distance squared in m
function LightWildlife:getClosestDistance(refPosX, refPosY, refPosZ)
    local closestDistSq = nil

    for _, animal in pairs(self.animals) do
        if entityExists(animal.i3dNodeId) then
            local x, y, z = getWorldTranslation(animal.i3dNodeId)
            local deltaX = refPosX - x
            local deltaY = refPosY - y
            local deltaZ = refPosZ - z
            local distSq = deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ

            if closestDistSq == nil or (closestDistSq ~= nil and distSq < closestDistSq) then
                closestDistSq = distSq
            end
        end
    end
    if closestDistSq == nil then
        closestDistSq = 0.0
    end
    return closestDistSq
end


---CountSpawned
-- @return integer returns number of animals
function LightWildlife:countSpawned()
    return #self.animals
end


---Check if position is in water
-- @param float x x world position from which areas are checked
-- @param float y y world position from which areas are checked
-- @param float z z world position from which areas are checked
-- @return bool returns true if there is water
function LightWildlife:getIsInWater(x, y, z)
    local waterY = g_currentMission.environmentAreaSystem:getWaterYAtWorldPosition(x, y, z) or -2000
    return waterY > y
end


---
function LightWildlife:getTerrainHeightWithProps(x, z)
    local terrainY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
    local offset = 5.0
    local collisionMask = 63

    self.groundY = -1.0
    raycastClosest(x, terrainY + offset, z, 0.0, -1.0, 0.0, "groundRaycastCallback", 5.0, self, collisionMask)
    return math.max(terrainY, self.groundY)
end


---
function LightWildlife:groundRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId ~= nil then
        local objectType = getRigidBodyType(hitObjectId)
        if objectType ~= RigidBodyType.DYNAMIC and objectType ~= RigidBodyType.KINEMATIC then
            self.groundY = y
            return false
        end
    end

    return true
end
