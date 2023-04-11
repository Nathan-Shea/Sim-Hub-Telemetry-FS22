---This class handles all npcs









local NPCManager_mt = Class(NPCManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function NPCManager.new(customMt)
    local self = AbstractManager.new(customMt or NPCManager_mt)
    return self
end


---Initialize data structures
function NPCManager:initDataStructures()
    self.numNpcs = 0
    self.npcs = {}
    self.nameToIndex = {}
    self.indexToNpc = {}
end


---
function NPCManager:loadDefaultTypes(missionInfo, baseDirectory)
    local xmlFile = loadXMLFile("npc", "data/maps/maps_npcs.xml")
    if xmlFile ~= 0 then
        self:loadNPCs(xmlFile, missionInfo, baseDirectory, true)
        delete(xmlFile)
    end
end


---Load data on map load
-- @return boolean true if loading was successful else false
function NPCManager:loadMapData(xmlFile, missionInfo, baseDirectory)
    NPCManager:superClass().loadMapData(self)

    self:loadDefaultTypes(missionInfo, baseDirectory)
    return XMLUtil.loadDataFromMapXML(xmlFile, "npcs", baseDirectory, self, self.loadNPCs, missionInfo, baseDirectory)
end


---Load data on map load
-- @return boolean true if loading was successful else false
function NPCManager:loadNPCs(xmlFile, missionInfo, baseDirectory, isBaseType)

    local i = 0
    while true do
        local key = string.format("map.npcs.npc(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key.."#name")
        local title = getXMLString(xmlFile, key.."#title")
        local imageFilename = getXMLString(xmlFile, key.."#imageFilename")

        self:addNPC(name, title, imageFilename, baseDirectory, isBaseType)

        i = i + 1
    end

    return true
end


---Write data to savegame file
-- @param string xmlFilename file path
-- @return boolean true if loading was successful else false
function NPCManager:saveToXMLFile(xmlFilename)
    -- save npcs to xml
    local xmlFile = createXMLFile("npcsXML", xmlFilename, "npcs")
    if xmlFile ~= nil then
        for k, npc in ipairs(self.indexToNpc) do
            local npcKey = string.format("npcs.npc(%d)", k-1)
            setXMLString(xmlFile, npcKey.."#name", npc.name)
            setXMLInt(xmlFile, npcKey.."#finishedMissions", npc.finishedMissions)
        end

        saveXMLFile(xmlFile)
        delete(xmlFile)

        return true
    end

    return false
end


---Load data from xml savegame file
-- @param string filename xml filename
function NPCManager:loadFromXMLFile(xmlFilename)
    if xmlFilename == nil then
        return false
    end

    local xmlFile = loadXMLFile("npcXML", xmlFilename)

    if xmlFile == 0 then
        return false
    end

    local i = 0
    while true do
        local key = string.format("npcs.npc(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key.."#name")
        local npc = self:getNPCByName(name)
        if npc ~= nil then
            npc.finishedMissions = Utils.getNoNil(getXMLInt(xmlFile, key.."#finishedMissions"), 0)
        else
            print("Warning: Npc '"..tostring(name).."' not found!")
        end
        i = i + 1
    end

    delete(xmlFile)

    return true
end


---Adds a new npc
-- @param string name npc index name
-- @param string title npc real name
-- @param string imageFilename npc image filename
-- @param string baseDir the base directory
-- @return boolean true if added successful else false
function NPCManager:addNPC(name, title, imageFilename, baseDir, isBaseType)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is not a valid name for a npc. Ignoring npc!")
        return nil
    end

    name = name:upper()

    if isBaseType and self.nameToIndex[name] ~= nil then
        print("Warning: NPC '"..tostring(name).."' already exists. Ignoring npc!")
        return nil
    end

    local npc = self.npcs[name]
    if npc == nil then
        if title == nil or title == "" then
            print("Warning: '"..tostring(title).."' is not a valid title for a npc. Ignoring npc!")
            return nil
        end
        if imageFilename == nil or imageFilename == "" then
            print("Warning: Missing npc image file for npc '"..tostring(name).."'. Ignoring npc!")
            return nil
        end

        self.numNpcs = self.numNpcs + 1
        npc = {}
        npc.name = name
        npc.title = g_i18n:convertText(title)
        npc.index = self.numNpcs
        npc.imageFilename = Utils.getFilename(imageFilename, baseDir)
        npc.finishedMissions = 0

        self.npcs[name] = npc
        self.nameToIndex[name] = self.numNpcs
        self.indexToNpc[self.numNpcs] = npc
    else
        if title ~= nil and title ~= "" then
            npc.title = g_i18n:convertText(title)
        end
        if imageFilename ~= nil and imageFilename ~= "" then
            npc.imageFilename = Utils.getFilename(imageFilename, baseDir)
        end
    end

    return npc
end


---Gets a random npc
-- @return table npc a random npc object
function NPCManager:getRandomNPC()
    return self.indexToNpc[self:getRandomIndex()]
end


---Gets a random npc index
-- @return integer npcIndex a random npc index
function NPCManager:getRandomIndex()
    return math.random(1, self.numNpcs)
end


---Gets a npc by index
-- @param integer index the npc index
-- @return table npc the npc object
function NPCManager:getNPCByIndex(index)
    if index ~= nil then
        return self.indexToNpc[index]
    end
    return nil
end


---Gets a npc by index name
-- @param string name the npc index name
-- @return table npc the npc object
function NPCManager:getNPCByName(name)
    if name ~= nil then
        name = name:upper()
        return self.npcs[name]
    end
    return nil
end
