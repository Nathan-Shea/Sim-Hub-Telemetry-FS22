---This class handles player models











local CharacterModelManager_mt = Class(CharacterModelManager)


---Creating manager
-- @return table instance instance of object
function CharacterModelManager.new(customMt)
    local self = setmetatable({}, customMt or CharacterModelManager_mt)

    self:initDataStructures()

    return self
end


---Initialize data structures
function CharacterModelManager:initDataStructures()
    self.playerModels = {}
    self.nameToPlayerModel = {}
    self.nameToIndex = {}
end


---Loads initial manager
-- @return boolean true if loading was successful else false
function CharacterModelManager:load(xmlFilename)
    local xmlFile = XMLFile.load("playerModels", xmlFilename)
    if xmlFile == nil then
        Logging.fatal("Could not load player model list at %s", xmlFilename)
    end

    xmlFile:iterate("playerModels.playerModel", function(index, key)
        local filename = xmlFile:getString(key .. "#filename")
        local name = xmlFile:getString(key .. "#name")
        local isMale = xmlFile:getBool(key .. "#isMale") or false

        if filename == nil or name == nil then
            return
        end

        self:addPlayerModel(name, filename, isMale)
    end)

    xmlFile:delete()
end


---Load data on map load
-- @return boolean true if loading was successful else false
function CharacterModelManager:loadMapData(xmlFile)
    return true
end


---Unload data on mission delete
function CharacterModelManager:unloadMapData()
end


---Adds a new player
-- @return boolean true if added successful else false
function CharacterModelManager:addPlayerModel(name, xmlFilename, isMale)
    if not ClassUtil.getIsValidIndexName(name) then
        Logging.devWarning("Warning: '%s' is not a valid name for a player. Ignoring it!", tostring(name))
        return nil
    end
    if xmlFilename == nil or xmlFilename == "" then
        Logging.devWarning("Warning: Config xmlFilename is missing for player '%s'. Ignoring it!", tostring(name))
        return nil
    end

    name = name:upper()

    if self.nameToPlayerModel[name] == nil then
        local numPlayerModels = #self.playerModels + 1
        local model = {}

        model.name = name
        model.index = numPlayerModels
        model.xmlFilename = Utils.getFilename(xmlFilename, nil)
        model.isMale = isMale

        table.insert(self.playerModels, model)

        self.nameToPlayerModel[name] = model
        self.nameToIndex[name] = numPlayerModels

        return model
    else
        Logging.devWarning("Warning: Player '%s' already exists. Ignoring it!", tostring(name))
    end

    return nil
end


---Gets a player by index
-- @param integer index the player index
-- @return table player the player object
function CharacterModelManager:getPlayerModelByIndex(index)
    if index ~= nil then
        return self.playerModels[index]
    end
    return nil
end


---Gets a player by index name
-- @param string name the player index name
-- @return table player the player object
function CharacterModelManager:getPlayerByName(name)
    if name ~= nil then
        name = name:upper()
        return self.nameToPlayerModel[name]
    end
    return nil
end


---Gets number of available player models
-- @return integer number number of models
function CharacterModelManager:getNumOfPlayerModels()
    return #self.playerModels
end
