---This class handles all basic functionality for land ownership












local FarmlandManager_mt = Class(FarmlandManager, AbstractManager)



---Creating manager
-- @return table instance instance of object
function FarmlandManager.new(customMt)
    local self = AbstractManager.new(customMt or FarmlandManager_mt)
    return self
end


---Initialize data structures
function FarmlandManager:initDataStructures()
    self.farmlands = {}
    self.sortedFarmlandIds = {}
    -- mapping table farmland id to farm id
    self.farmlandMapping = {}
    self.localMap = nil
    self.localMapWidth = 0
    self.localMapHeight = 0
    self.numberOfBits = 8
    self.stateChangeListener = {}
end



---Load data on map load
-- @return boolean true if loading was successful else false
function FarmlandManager:loadMapData(xmlFile)
    FarmlandManager:superClass().loadMapData(self)
    return XMLUtil.loadDataFromMapXML(xmlFile, "farmlands", g_currentMission.baseDirectory, self, self.loadFarmlandData)
end


---Load data on map load
-- @return boolean true if loading was successful else false
function FarmlandManager:loadFarmlandData(xmlFile)
    local filename = Utils.getFilename(getXMLString(xmlFile, "map.farmlands#densityMapFilename"), g_currentMission.baseDirectory)

    -- number of channels for farmland bit vector
    self.numberOfBits = Utils.getNoNil(getXMLInt(xmlFile, "map.farmlands#numChannels"), 8)
    self.pricePerHa = Utils.getNoNil(getXMLFloat(xmlFile, "map.farmlands#pricePerHa"), 60000)

    FarmlandManager.NOT_BUYABLE_FARM_ID = 2^self.numberOfBits-1

    -- load a bitvector
    self.localMap = createBitVectorMap("FarmlandMap")
    local success = loadBitVectorMapFromFile(self.localMap, filename, self.numberOfBits)
    if not success then
        Logging.xmlWarning(xmlFile, "Loading farmland file '%s' failed!", filename)
        return false
    end

    self.localMapWidth, self.localMapHeight = getBitVectorMapSize(self.localMap)

    local farmlandSizeMapping = {}
    local farmlandCenterData = {}
    local numOfFarmlands = 0
    local maxFarmlandId = 0
    local missingFarmlandDefinitions = false

    for x = 0, self.localMapWidth - 1 do
        for y = 0, self.localMapHeight - 1 do
            local value = getBitVectorMapPoint(self.localMap, x, y, 0, self.numberOfBits)

            if value > 0 then
                if self.farmlandMapping[value] == nil then
                    farmlandSizeMapping[value] = 0
                    farmlandCenterData[value] = {sumPosX=0, sumPosZ=0}
                    self.farmlandMapping[value] = FarmlandManager.NO_OWNER_FARM_ID
                    numOfFarmlands = numOfFarmlands + 1
                    maxFarmlandId = math.max(value, maxFarmlandId)
                end

                farmlandSizeMapping[value] = farmlandSizeMapping[value] + 1
                farmlandCenterData[value].sumPosX = farmlandCenterData[value].sumPosX + (x-0.5)
                farmlandCenterData[value].sumPosZ = farmlandCenterData[value].sumPosZ + (y-0.5)
            else
                missingFarmlandDefinitions = true
            end
        end
    end

    if missingFarmlandDefinitions then
        Logging.xmlWarning(xmlFile, "Farmland-Id was not set for all pixels in farmland-infoLayer!")
    end

    local isNewSavegame = not g_currentMission.missionInfo.isValid

    local i = 0
    while true do
        local key = string.format("map.farmlands.farmland(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local farmland = Farmland.new()
        if farmland:load(xmlFile, key) and self.farmlands[farmland.id] == nil and self.farmlandMapping[farmland.id] ~= nil then
            self.farmlands[farmland.id] = farmland
            table.insert(self.sortedFarmlandIds, farmland.id)

            -- If default should be owned...
            local shouldAddDefaults = isNewSavegame and g_currentMission.missionInfo.hasInitiallyOwnedFarmlands and not g_currentMission.missionDynamicInfo.isMultiplayer
            -- ... then set only default farmlands to owned
            if shouldAddDefaults and g_currentMission:getIsServer() and farmland.defaultFarmProperty then
                self:setLandOwnership(farmland.id, FarmManager.SINGLEPLAYER_FARM_ID)
            end
        else
            if self.farmlandMapping[farmland.id] == nil then
                Logging.xmlError(xmlFile, "Farmland-Id " .. tostring(farmland.id) .. " not defined in farmland ownage file '"..filename.."'. Skipping farmland definition!")
            end
            if self.farmlands[farmland.id] ~= nil then
                Logging.xmlError(xmlFile, "Farmland-id '"..tostring(farmland.id).."' already exists! Ignore it!")
            end
            farmland:delete()
        end

        i = i + 1
    end

    for index, _ in pairs(self.farmlandMapping) do
        if index ~= FarmlandManager.NOT_BUYABLE_FARM_ID and self.farmlands[index] == nil then
            Logging.xmlError(xmlFile, "Farmland-Id " .. tostring(index) .. " not defined in farmland xml file!")
        end
    end

    local transformFactor = g_currentMission.terrainSize / self.localMapWidth
    local pixelToSqm = transformFactor*transformFactor

    for id, farmland in pairs(self.farmlands) do
        local ha = MathUtil.areaToHa(farmlandSizeMapping[id], pixelToSqm)
        farmland:setArea(ha)

        local posX = ((farmlandCenterData[id].sumPosX / farmlandSizeMapping[id]) - self.localMapWidth*0.5) * transformFactor
        local posZ = ((farmlandCenterData[id].sumPosZ / farmlandSizeMapping[id]) - self.localMapHeight*0.5) * transformFactor
        self.farmlands[id]:setFarmlandIndicatorPosition(posX, posZ)
    end

    g_messageCenter:subscribe(MessageType.FARM_DELETED, self.farmDestroyed, self)

    if g_currentMission:getIsServer() then
        if g_addCheatCommands then
            -- master user only cheats (will be added in setMasterUserLocal too)
            addConsoleCommand("gsFarmlandBuy", "Buys farmland with given id", "consoleCommandBuyFarmland", self)
            addConsoleCommand("gsFarmlandBuyAll", "Buys all farmlands", "consoleCommandBuyAllFarmlands", self)
            addConsoleCommand("gsFarmlandSell", "Sells farmland with given id", "consoleCommandSellFarmland", self)
            addConsoleCommand("gsFarmlandSellAll", "Sells all farmlands", "consoleCommandSellAllFarmlands", self)
            addConsoleCommand("gsFarmlandShow", "Show farmlands", "consoleCommandShowFarmlands", self)
        end
    end

    return true
end


---Unload data on mission delete
function FarmlandManager:unloadMapData()
    removeConsoleCommand("gsFarmlandBuy")
    removeConsoleCommand("gsFarmlandBuyAll")
    removeConsoleCommand("gsFarmlandSell")
    removeConsoleCommand("gsFarmlandSellAll")
    removeConsoleCommand("gsFarmlandShow")

    g_messageCenter:unsubscribeAll(self)

    if self.localMap ~= nil then
        delete(self.localMap)
        self.localMap = nil
    end
    if (self.farmlands ~= nil) then
        for _, farmland in pairs(self.farmlands) do
            farmland:delete()
        end
    end

    FarmlandManager:superClass().unloadMapData(self)
end


---Write farmland ownage data to savegame file
-- @param string xmlFilename file path
-- @return boolean true if loading was successful else false
function FarmlandManager:saveToXMLFile(xmlFilename)
    -- save farmland to xml
    local xmlFile = createXMLFile("farmlandsXML", xmlFilename, "farmlands")
    if xmlFile ~= nil then
        local index = 0
        for farmlandId, farmId in pairs(self.farmlandMapping) do
            local farmlandKey = string.format("farmlands.farmland(%d)", index)
            setXMLInt(xmlFile, farmlandKey.."#id", farmlandId)
            setXMLInt(xmlFile, farmlandKey.."#farmId", Utils.getNoNil(farmId, FarmlandManager.NO_OWNER_FARM_ID))
            index = index + 1
        end

        saveXMLFile(xmlFile)
        delete(xmlFile)

        return true
    end

    return false
end


---Load farmland ownage data from xml savegame file
-- @param string filename xml filename
function FarmlandManager:loadFromXMLFile(xmlFilename)
    if xmlFilename == nil then
        return false
    end

    local xmlFile = loadXMLFile("farmlandXML", xmlFilename)
    if xmlFile == 0 then
        return false
    end

    local farmlandCounter = 0
    while true do
        local key = string.format("farmlands.farmland(%d)", farmlandCounter)
        local farmlandId = getXMLInt(xmlFile, key .. "#id")
        if farmlandId == nil then
            break
        end
        local farmId = getXMLInt(xmlFile, key .. "#farmId")
        if farmId > FarmlandManager.NO_OWNER_FARM_ID then
            self:setLandOwnership(farmlandId, farmId)
        end

        farmlandCounter = farmlandCounter + 1
    end

    delete(xmlFile)

    g_farmManager:mergeFarmlandsForSingleplayer()

    return true
end


---Deletes farm land manager
function FarmlandManager:delete()
end


---Gets farmland bit vector handle
-- @return integer mapHandle id of bitvector
function FarmlandManager:getLocalMap()
    return self.localMap
end


---Checks if farm owns given world position
-- @param integer farmId farm id
-- @param float worldPosX world position x
-- @param float worldPosZ world position z
-- @return boolean isOwned true if farm owns world position point, else false
function FarmlandManager:getIsOwnedByFarmAtWorldPosition(farmId, worldPosX, worldPosZ)
    if farmId == FarmlandManager.NO_OWNER_FARM_ID or farmId == nil then
        return false
    end
    local farmlandId = self:getFarmlandIdAtWorldPosition(worldPosX, worldPosZ)
    return self.farmlandMapping[farmlandId] == farmId
end


---Checks if farm can access the given world position
-- @param integer farmId farm id
-- @param float worldPosX world position x
-- @param float worldPosZ world position z
-- @return boolean canAccess true if farm can access the land
function FarmlandManager:getCanAccessLandAtWorldPosition(farmId, worldPosX, worldPosZ)
    if farmId == FarmlandManager.NO_OWNER_FARM_ID or farmId == nil then
        return false
    end

    local farmlandId = self:getFarmlandIdAtWorldPosition(worldPosX, worldPosZ)
    local ownerFarmId = self.farmlandMapping[farmlandId]
    if ownerFarmId == farmId then
        return true
    end

    return g_currentMission.accessHandler:canFarmAccessOtherId(farmId, ownerFarmId)
end


---Gets farmland owner
-- @param integer farmlandId farmland id
-- @return integer farmId id of farm. Returns 0 if land is not owned by anyone
function FarmlandManager:getFarmlandOwner(farmlandId)
--#debug     assert(type(farmlandId ~= "table"))  -- ensure farmland id and not farmland itself it given
    if farmlandId == nil or self.farmlandMapping[farmlandId] == nil then
        return FarmlandManager.NO_OWNER_FARM_ID
    end

    return self.farmlandMapping[farmlandId]
end


---Gets farmland id at given world position
-- @param float worldPosX world position x
-- @param float worldPosZ world position z
-- @return integer farmlandId farmland id. if 0, world position is no valid/buyable farmland
function FarmlandManager:getFarmlandIdAtWorldPosition(worldPosX, worldPosZ)
    local localPosX, localPosZ = self:convertWorldToLocalPosition(worldPosX, worldPosZ)
    return getBitVectorMapPoint(self.localMap, localPosX, localPosZ, 0, self.numberOfBits)
end


---
function FarmlandManager:getFarmlandAtWorldPosition(worldPosX, worldPosZ)
    local farmlandId = self:getFarmlandIdAtWorldPosition(worldPosX, worldPosZ)
    return self.farmlands[farmlandId]
end


---
function FarmlandManager:getOwnerIdAtWorldPosition(worldPosX, worldPosZ)
    local farmlandId = self:getFarmlandIdAtWorldPosition(worldPosX, worldPosZ)
    return self:getFarmlandOwner(farmlandId)
end


---Checks if given farmland-id is valid
-- @param integer farmlandId farmland id
-- @return boolean isValid true if id is valid, else false
function FarmlandManager:getIsValidFarmlandId(farmlandId)
    if farmlandId == nil or farmlandId == 0 or farmlandId < 0 then
        return false
    end
    if self:getFarmlandById(farmlandId) == nil then
        return false
    end
    return true
end


---Sets farm land ownership
-- @param integer farmlandId farm land id
-- @param integer farmId farm id. set farmid to 0 to sell farm land
function FarmlandManager:setLandOwnership(farmlandId, farmId)
    if not self:getIsValidFarmlandId(farmlandId) then
        return false
    end
    if farmId == nil or farmId < FarmlandManager.NO_OWNER_FARM_ID or farmId == FarmlandManager.NOT_BUYABLE_FARM_ID then
        return false
    end

    local farmland = self:getFarmlandById(farmlandId)
    if farmland == nil then
        Logging.warning("Farmland id %d not defined in map!", farmlandId)
        return false
    end

    self.farmlandMapping[farmlandId] = farmId
    farmland.isOwned = farmId ~= FarmlandManager.NO_OWNER_FARM_ID

    for _, listener in pairs(self.stateChangeListener) do
        listener:onFarmlandStateChanged(farmlandId, farmId)
    end

    return true
end


---Gets farmland by id
-- @param integer farmlandId farmland id
-- @return table farmland farmland object
function FarmlandManager:getFarmlandById(farmlandId)
    return self.farmlands[farmlandId]
end


---Gets all farmlands
-- @return table farmlands all available farmlands
function FarmlandManager:getFarmlands()
    return self.farmlands
end


---
function FarmlandManager:getPricePerHa()
    return self.pricePerHa
end


---Gets list of owned farmland ids for given farm
-- @param integer farmId farm id
-- @return farmlandIds table list of farmland ids owned by given farm id
function FarmlandManager:getOwnedFarmlandIdsByFarmId(id)
    local farmlandIds = {}
    for farmlandId, farmId in pairs(self.farmlandMapping) do
        if farmId == id then
            table.insert(farmlandIds, farmlandId)
        end
    end
    return farmlandIds
end


---Converts world to local position
-- @param float worldPosX world position x
-- @param float worldPosZ world position z
-- @return float localPosX local position x
-- @return float localPosZ local position z
function FarmlandManager:convertWorldToLocalPosition(worldPosX, worldPosZ)
    local terrainSize = g_currentMission.terrainSize
    return math.floor(self.localMapWidth * (worldPosX+terrainSize*0.5) / terrainSize),
           math.floor(self.localMapHeight * (worldPosZ+terrainSize*0.5) / terrainSize)
end


---
function FarmlandManager:farmDestroyed(farmId)
    for _, farmland in pairs(self:getFarmlands()) do
        if self:getFarmlandOwner(farmland.id) == farmId then
            self:setLandOwnership(farmland.id, FarmlandManager.NO_OWNER_FARM_ID)
        end
    end
end


---Adds a farmland state change listener
-- @param table listener state listener
function FarmlandManager:addStateChangeListener(listener)
    if listener ~= nil and listener.onFarmlandStateChanged ~= nil then
        self.stateChangeListener[listener] = listener
    end
end


---Removes a farmland state change listener
-- @param table listener state listener
function FarmlandManager:removeStateChangeListener(listener)
    if listener ~= nil then
        self.stateChangeListener[listener] = nil
    end
end


---
function FarmlandManager:consoleCommandBuyFarmland(farmlandId)
    if (g_currentMission:getIsServer() or g_currentMission.isMasterUser) and g_currentMission:getIsClient() then
        farmlandId = tonumber(farmlandId)
        if farmlandId == nil then
            return "Invalid farmland id. Use gsFarmlandBuy <farmlandId>"
        end

        local farmId = g_currentMission.player.farmId

        -- send buy request
        g_client:getServerConnection():sendEvent(FarmlandStateEvent.new(farmlandId, farmId, 0))

        return "Bought farmland "..farmlandId
    else
        return "Command not allowed"
    end
end


---
function FarmlandManager:consoleCommandBuyAllFarmlands()
    if (g_currentMission:getIsServer() or g_currentMission.isMasterUser) and g_currentMission:getIsClient() then
        local farmId = g_currentMission.player.farmId

        for k, _ in pairs(g_farmlandManager:getFarmlands()) do
            g_client:getServerConnection():sendEvent(FarmlandStateEvent.new(k, farmId, 0))
        end
        return "Bought all farmlands"
    else
        return "Command not allowed"
    end
end


---
function FarmlandManager:consoleCommandSellFarmland(farmlandId)
    if (g_currentMission:getIsServer() or g_currentMission.isMasterUser) and g_currentMission:getIsClient() then
        farmlandId = tonumber(farmlandId)
        if farmlandId == nil then
            return "Invalid farmland id. Use gsFarmlandSell <farmlandId>"
        end

        -- send sell request
        g_client:getServerConnection():sendEvent(FarmlandStateEvent.new(farmlandId, FarmlandManager.NO_OWNER_FARM_ID, 0))

        return "Sold farmland "..farmlandId
    else
        return "Command not allowed"
    end
end


---
function FarmlandManager:consoleCommandSellAllFarmlands()
    if (g_currentMission:getIsServer() or g_currentMission.isMasterUser) and g_currentMission:getIsClient() then
        for k, _ in pairs(g_farmlandManager:getFarmlands()) do
            g_client:getServerConnection():sendEvent(FarmlandStateEvent.new(k, FarmlandManager.NO_OWNER_FARM_ID, 0))
        end
        return "Sold all farmlands"
    else
        return "Command not allowed"
    end
end


---
function FarmlandManager:consoleCommandShowFarmlands()
    if not g_currentMission:getHasDrawable(self) then
        g_currentMission:addDrawable(self)
        return "showFarmlands = true\nUse F5 to enter debug mode for enabling overlay"
    else
        g_currentMission:removeDrawable(self)
        return "showFarmlands = false"
    end
end
