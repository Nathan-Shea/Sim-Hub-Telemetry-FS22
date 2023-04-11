---Crows Wildlife class







local CrowsWildlife_mt = Class(CrowsWildlife, LightWildlife)


























---Creating instance
-- @param table customMt custom meta table
-- @return table instance Instance of object
function CrowsWildlife.new(customMt)
    local self = CrowsWildlife:superClass().new(customMt or CrowsWildlife_mt)

    self.animalStates = {}
    for _, stateEntry in pairs(CrowsWildlife.CROW_STATES) do
        table.insert(self.animalStates, stateEntry)
    end

    self.tree = nil
    self.soundFSM = FSMUtil.create()
    self.soundFSM:addState(CrowsWildlife.CROW_SOUND_STATES.NONE,        CrowSoundStateDefault.new(CrowsWildlife.CROW_SOUND_STATES.NONE, self, self.soundFSM))
    self.soundFSM:addState(CrowsWildlife.CROW_SOUND_STATES.CALM_GROUND, CrowSoundStateCalmGround.new(CrowsWildlife.CROW_SOUND_STATES.CALM_GROUND, self, self.soundFSM))
    self.soundFSM:addState(CrowsWildlife.CROW_SOUND_STATES.CALM_AIR,    CrowSoundStateCalmAir.new(CrowsWildlife.CROW_SOUND_STATES.CALM_AIR, self, self.soundFSM))
    self.soundFSM:addState(CrowsWildlife.CROW_SOUND_STATES.BUSY,        CrowSoundStateBusy.new(CrowsWildlife.CROW_SOUND_STATES.BUSY, self, self.soundFSM))
    self.soundFSM:addState(CrowsWildlife.CROW_SOUND_STATES.TAKEOFF,     CrowSoundStateTakeOff.new(CrowsWildlife.CROW_SOUND_STATES.TAKEOFF, self, self.soundFSM))
    self.soundFSM:changeState(CrowsWildlife.CROW_SOUND_STATES.NONE)

    return self
end


---Delete instance
function CrowsWildlife:delete()
    g_soundManager:deleteSamples(self.samples.flyAway)
    g_soundManager:deleteSamples(self.samples.calmGround)
    g_soundManager:deleteSample(self.samples.busy)
    g_soundManager:deleteSample(self.samples.calmAir)

    CrowsWildlife:superClass().delete(self)
end


---Load xml file
-- @param string xmlFilename xml filename to load
-- @return bool true if load is successful
function CrowsWildlife:load(xmlFilename)
    CrowsWildlife:superClass().load(self, xmlFilename)

    local xmlFile = loadXMLFile("TempXML", self.xmlFilename)
    if xmlFile == 0 then
        self.xmlFilename = nil
        return false
    end

    self.samples = {}
    self.samples.flyAway = {}
    local i = 0
    while true do
        local sampleFlyAway = g_soundManager:loadSampleFromXML(xmlFile, "wildlifeAnimal.sounds.flyAways", string.format("flyAway(%d)", i), self.baseDirectory, self.soundsNode, 1, AudioGroup.ENVIRONMENT, nil, nil)
        if sampleFlyAway == nil then
            break
        end
        table.insert(self.samples.flyAway, sampleFlyAway)
        i = i + 1
    end
    self.samples.flyAwayCount = i
    self.samples.calmGround = {}
    local j = 0
    while true do
        local sampleCalmGround = g_soundManager:loadSampleFromXML(xmlFile, "wildlifeAnimal.sounds.calmGrounds", string.format("calmGround(%d)", j), self.baseDirectory, self.soundsNode, 1, AudioGroup.ENVIRONMENT, nil, nil)
        if sampleCalmGround == nil then
            break
        end
        table.insert(self.samples.calmGround, sampleCalmGround)
        j = j + 1
    end
    self.samples.calmCount = j
    self.samples.busy = g_soundManager:loadSampleFromXML(xmlFile, "wildlifeAnimal.sounds", "busy", self.baseDirectory, self.soundsNode, 0, AudioGroup.ENVIRONMENT, nil, nil)
    self.samples.calmAir = g_soundManager:loadSampleFromXML(xmlFile, "wildlifeAnimal.sounds", "calmAir", self.baseDirectory, self.soundsNode, 0, AudioGroup.ENVIRONMENT, nil, nil)
    delete(xmlFile)

    return true
end


---Create animals
-- @param string name name of animals to spawn
-- @param float spawnPosX world x position
-- @param float spawnPosY world y position
-- @param float spawnPosZ world z position
-- @param integer nbAnimals amount of animals to spawn
-- @return integer id of the animal group
function CrowsWildlife:createAnimals(name, spawnPosX, spawnPosY, spawnPosZ, nbAnimals)
    if #self.animals == 0 then
        self.soundFSM:changeState(CrowsWildlife.CROW_SOUND_STATES.CALM_GROUND)
    end
    local id = CrowsWildlife:superClass().createAnimals(self, name, spawnPosX, spawnPosY, spawnPosZ, nbAnimals)
    return id
end


---update
function CrowsWildlife:update(dt)
    CrowsWildlife:superClass().update(self, dt)

    if #self.animals > 0 then
        self.soundFSM:update(dt)
    elseif self.soundFSM.currentState.id ~= CrowsWildlife.CROW_SOUND_STATES.NONE then
        self.soundFSM:changeState(CrowsWildlife.CROW_SOUND_STATES.NONE)
    end
end


---Search tree around a radius
-- @param float x x world position from which areas are checked
-- @param float y y world position from which areas are checked
-- @param float z z world position from which areas are checked
-- @param radius radius of the test in m
-- @return integer number of trees found
function CrowsWildlife:searchTree(x, y, z, radius)
    overlapSphere(x, y, z, radius, "treeSearchCallback", self, CollisionFlag.TREE, false, true, false)
end


---Tree count callback
-- @param integer transformId - transformId of the element detected in the overlap test
-- @return bool true to continue counting trees
function CrowsWildlife:treeSearchCallback(transformId)
    self.tree = nil
    if transformId ~= 0 and getHasClassId(transformId, ClassIds.SHAPE) then
        local object = getParent(transformId)
        if object ~= nil and getSplitType(transformId) ~= 0 then
            self.tree = object
        end
    end
    return true
end


---Get average location of all idle animals
function CrowsWildlife:getAverageLocationOfIdleAnimals()
    local nbIdleAnimals = 0
    local accPosX, accPosZ = 0.0, 0.0
    for _, animal in pairs(self.animals) do
        local currentState = animal.stateMachine.currentState.id
        if currentState == "idle_walk" or currentState == "idle_eat" or currentState == "idle_attention" then
            local posX, _, posZ = getWorldTranslation(animal.i3dNodeId)
            accPosX, accPosZ = accPosX + posX, accPosZ + posZ
            nbIdleAnimals = nbIdleAnimals + 1
        end
    end
    if nbIdleAnimals > 0 then
        accPosX, accPosZ = accPosX / nbIdleAnimals, accPosZ / nbIdleAnimals
        local terrainHeight = self:getTerrainHeightWithProps(accPosX, accPosZ)
        return true, accPosX, terrainHeight, accPosZ
    end
    return false, 0.0, 0.0, 0.0
end
