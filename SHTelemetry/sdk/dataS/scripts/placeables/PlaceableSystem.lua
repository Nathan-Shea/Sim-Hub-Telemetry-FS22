









local PlaceableSystem_mt = Class(PlaceableSystem)


---
function PlaceableSystem.new(mission, customMt)
    local self = setmetatable({}, customMt or PlaceableSystem_mt)

    self.mission = mission
    self.placeables = {}
    self.savegameIdToPlaceable = {}

    self.weatherStations = {}
    self.farmhouses = {}
    self.bunkerSilos = {}

    self.version = 1

    self.isReloadRunning = false

    if self.mission:getIsServer() then
        if g_addTestCommands then
            addConsoleCommand("gsPlaceablesDeleteAll", "Deletes all placeables", "consoleCommandDeleteAllPlaceables", self)
            addConsoleCommand("gsPlaceablesReloadAll", "Reloads all placeables", "consoleCommandReloadAllPlaceables", self)
            addConsoleCommand("gsPlaceablesLoadAll", "Loads all placeables", "consoleCommandLoadAllPlaceables", self)
            addConsoleCommand("gsPlaceablesShowTestAreas", "Show test areas of all placeables", "consoleCommandPlaceableTestAreas", self)
        end
    end

    return self
end


---
function PlaceableSystem:delete()
    for i=#self.placeables, 1, -1 do
        local placeable = self.placeables[i]
        placeable:delete()
    end

    self.mission = nil
    self.placeables = {}
    self.savegameIdToPlaceable = {}
    self.weatherStations = {}
    self.farmhouses = {}
    self.bunkerSilos = {}

    removeConsoleCommand("gsPlaceablesDeleteAll")
    removeConsoleCommand("gsPlaceablesReloadAll")
    removeConsoleCommand("gsPlaceablesLoadAll")
    removeConsoleCommand("gsPlaceablesShowTestAreas")
end


---
function PlaceableSystem:deleteAll()

    local numDeleted = #self.placeables

    for i=#self.placeables, 1, -1 do
        local placeable = self.placeables[i]
        placeable:delete()
    end

    return numDeleted
end


---
function PlaceableSystem:addPlaceable(placeable)
    if placeable == nil or placeable:isa(Placeable) == nil then
        Logging.error("Given object is not a placeable")
        return
    end

    table.addElement(self.placeables, placeable)
end


---
function PlaceableSystem:removePlaceable(placeable)
    if placeable.currentSavegameId ~= nil then
        self.savegameIdToPlaceable[placeable.currentSavegameId] = nil
    end
    table.removeElement(self.placeables, placeable)
end


---
function PlaceableSystem:getPlaceableBySavegameId(savegameId)
    return self.savegameIdToPlaceable[savegameId]
end


---
function PlaceableSystem:addWeatherStation(weatherStation)
    table.addElement(self.weatherStations, weatherStation)
end


---
function PlaceableSystem:removeWeatherStation(weatherStation)
    table.removeElement(self.weatherStations, weatherStation)
end


---
function PlaceableSystem:addBunkerSilo(bunkerSilo)
    table.addElement(self.bunkerSilos, bunkerSilo)
end


---
function PlaceableSystem:removeBunkerSilo(bunkerSilo)
    table.removeElement(self.bunkerSilos, bunkerSilo)
end


---
function PlaceableSystem:getBunkerSilos()
    return self.bunkerSilos
end


---
function PlaceableSystem:getHasWeatherStation(farmId)
    for _, weatherStation in ipairs(self.weatherStations) do
        if farmId == nil or weatherStation:getOwnerFarmId() == farmId then
            return true
        end
    end

    return false
end


---
function PlaceableSystem:addFarmhouse(farmhouse)
    table.addElement(self.farmhouses, farmhouse)
end


---
function PlaceableSystem:removeFarmhouse(farmhouse)
    table.removeElement(self.farmhouses, farmhouse)
end


---
function PlaceableSystem:getFarmhouse(farmId)
    for _, farmhouse in ipairs(self.farmhouses) do
        if farmId == nil or farmhouse:getOwnerFarmId() == farmId then
            return farmhouse
        end
    end

    return nil
end


---
function PlaceableSystem:save(xmlFilename, usedModNames)
    local xmlFile = XMLFile.create("placeablesXML", xmlFilename, "placeables", Placeable.xmlSchemaSavegame)
    if xmlFile ~= nil then
        self:saveToXML(xmlFile, usedModNames)
        xmlFile:delete()
    end
end


---
function PlaceableSystem:setSaveIds()
    local curId = 1
    for i, placeable in ipairs(self.placeables) do
        if placeable:getNeedsSaving() then
            placeable.currentSavegameId = curId
            curId = curId + 1
        end
    end
end


---
function PlaceableSystem:saveToXML(xmlFile, usedModNames)
    if xmlFile ~= nil then
        xmlFile:setValue("placeables#version", self.version)

        local xmlIndex = 0
        for i, placeable in ipairs(self.placeables) do
            if placeable:getNeedsSaving() then
                self:savePlaceableToXML(placeable, xmlFile, xmlIndex, i, usedModNames)

                xmlIndex = xmlIndex + 1
            end
        end

        xmlFile:save()
    end
end


---
function PlaceableSystem:savePlaceableToXML(placeable, xmlFile, index, i, usedModNames)
    local placeableKey = string.format("placeables.placeable(%d)", index)

    local modName = placeable.customEnvironment
    if modName ~= nil then
        if usedModNames ~= nil then
            usedModNames[modName] = modName
        end
        xmlFile:setValue(placeableKey.."#modName", modName)
    end

    xmlFile:setValue(placeableKey.."#filename", HTMLUtil.encodeToHTML(NetworkUtil.convertToNetworkFilename(placeable.configFileName)))

    placeable:saveToXMLFile(xmlFile, placeableKey, usedModNames)
end


---
function PlaceableSystem:load(xmlFilename, defaultXMLFilename, missionInfo, missionDynamicInfo, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
    local xmlFile = XMLFile.load("placeablesXML", xmlFilename, Placeable.xmlSchemaSavegame)

    -- Savegame version is used by the default list to determine if an upgrade has to be made
    self.version = xmlFile:getValue("placeables#version", 1)

    local loadingData = {}
    loadingData.xmlFile = xmlFile
    loadingData.xmlFilename = xmlFilename

    if xmlFilename ~= defaultXMLFilename then
        -- Upgrading
        loadingData.defaultXMLFilename = defaultXMLFilename
    end

    loadingData.missionInfo = missionInfo
    loadingData.missionDynamicInfo = missionDynamicInfo
    loadingData.placeablesById = {}
    loadingData.index = 0
    loadingData.asyncCallbackFunction = asyncCallbackFunction
    loadingData.asyncCallbackObject = asyncCallbackObject
    loadingData.asyncCallbackArguments = asyncCallbackArguments

    if not self:loadNextPlaceableFromXML(loadingData) then
        self:loadFinished(loadingData)
    end
end


---
function PlaceableSystem:loadNextPlaceableFromXML(loadingData)
    if g_currentMission.cancelLoading then
        return false
    end

    local xmlFile = loadingData.xmlFile
    local missionInfo = loadingData.missionInfo
    local missionDynamicInfo = loadingData.missionDynamicInfo
    local defaultItemsToSPFarm = xmlFile:getValue("placeables#loadAnyFarmInSingleplayer", false)

    -- loop until we can load a placeable or we are at the end of the file
    while true do
        local index = loadingData.index
        loadingData.index = loadingData.index + 1

        local key = string.format("placeables.placeable(%d)", index)
        if not xmlFile:hasProperty(key) then
            return false
        end

        local shouldLoad = true
        if loadingData.upgradeOnly then
            local sinceVersion = xmlFile:getValue(key .. "#sinceVersion")

            -- Only upgrade with an item that appeared newly since the last save of the savegame
            shouldLoad = sinceVersion ~= nil and sinceVersion >= self.version
        end

        if shouldLoad then
            if self:loadPlaceableFromXML(xmlFile, key, missionInfo, missionDynamicInfo, defaultItemsToSPFarm, self.loadNextPlaceableFromXMLFinished, self, loadingData) then
                return true
            end
        end
    end
end


---
function PlaceableSystem:loadNextPlaceableFromXMLFinished(placeable, loadingState, loadingData)
    if g_currentMission.cancelLoading then
        self:loadFinished(loadingData)
        return
    end

    if placeable ~= nil then
        if loadingState == Placeable.LOADING_STATE_ERROR then
            Logging.warning("Corrupt savegame, placeable '%s' could not be loaded", placeable.configFileName)
            g_currentMission.placeableSystem:removePlaceable(placeable)
            placeable:delete()
        else
            if placeable.currentSavegameId ~= nil then
                self.savegameIdToPlaceable[placeable.currentSavegameId] = placeable
            end
            placeable:register()
        end
    end

    if not self:loadNextPlaceableFromXML(loadingData) then
        self:loadFinished(loadingData)
    end
end


---
function PlaceableSystem:loadFinished(loadingData)
    -- Do a second pass over the base-data to load any placeable upgrades
    if loadingData.defaultXMLFilename ~= nil then
        loadingData.xmlFile:delete()

        loadingData.xmlFile = XMLFile.load("placeablesXML", loadingData.defaultXMLFilename, Placeable.xmlSchemaSavegame)
        loadingData.defaultXMLFilename = nil
        loadingData.upgradeOnly = true
        loadingData.index = 0

        local savegameVersion = self.version
        self.version = loadingData.xmlFile:getValue("placeables#version", 1)

        -- No version change so no upgrades needed
        if self.version <= savegameVersion then
            return self:loadFinished(loadingData)
        end

        if not self:loadNextPlaceableFromXML(loadingData) then
            self:loadFinished(loadingData)
        end
    else
        g_asyncTaskManager:addTask(function()
            loadingData.xmlFile:delete()
            if loadingData.asyncCallbackFunction ~= nil then
                loadingData.asyncCallbackFunction(loadingData.asyncCallbackObject, loadingData.asyncCallbackArguments)
            end
        end)
    end
end


---
function PlaceableSystem:loadPlaceableFromXML(xmlFile, key, missionInfo, missionDynamicInfo, defaultItemsToSPFarm, callback, target, args)
    local filename = xmlFile:getValue(key.."#filename")
    local defaultProperty = xmlFile:getValue(key .. "#defaultFarmProperty", false)
    local farmId = xmlFile:getValue(key .. "#farmId")

    -- Always load all placeables from a savegame. Load any non-farm placeables from the default game. Only load non-farm placeables
    -- when that option is set.
    local loadForCompetitive = defaultProperty and missionInfo.isCompetitiveMultiplayer and g_farmManager:getFarmById(farmId) ~= nil
    local loadDefaultProperty = defaultProperty and (missionInfo.loadDefaultFarm and not missionDynamicInfo.isMultiplayer) and (farmId == FarmManager.SINGLEPLAYER_FARM_ID or defaultItemsToSPFarm)
    local allowedToLoad = missionInfo.isValid or not defaultProperty or loadDefaultProperty or loadForCompetitive

    if allowedToLoad then
        filename = NetworkUtil.convertFromNetworkFilename(filename)
        local savegame = {xmlFile=xmlFile, key=key, ignoreFarmId=false}

        if loadDefaultProperty and defaultItemsToSPFarm and farmId ~= FarmManager.SINGLEPLAYER_FARM_ID then
            farmId = FarmManager.SINGLEPLAYER_FARM_ID
            savegame.ignoreFarmId = true
        end

        local posX, posY, posZ = xmlFile:getValue(key .. "#position")
        local rotX, rotY, rotZ = xmlFile:getValue(key .. "#rotation")

        local position = {x=posX, y=posY, z=posZ}
        local rotation = {x=rotX, y=rotY, z=rotZ}

        PlaceableUtil.loadPlaceable(filename, position, rotation, farmId, savegame, callback, target, args)
        return true
    else
        Logging.xmlInfo(xmlFile, "Placeable '%s' is not allowed to be loaded", filename)
    end
end


---
function PlaceableSystem:consoleCommandDeleteAllPlaceables(includePreplaced)
    local usage = "Usage: gsPlaceablesDeleteAll [includePreplaced]"
    local numDeleted = 0

    for i=#self.placeables, 1, -1 do
        local placeable = self.placeables[i]
        if not placeable:isMapBound() or includePreplaced then
            placeable:delete()
            numDeleted = numDeleted + 1
        end
    end

    if includePreplaced then
        return string.format("Deleted all %i placeables! Included preplaced ones!", numDeleted)
    end

    return string.format("Deleted %i placeables! Excluded preplaced ones.\n%s", numDeleted, usage)
end


---
function PlaceableSystem:consoleCommandReloadAllPlaceables()
    if self.isReloadRunning then
        return "Cannot start reloading. Another reloading is currently running"
    end
    if g_currentMission:getIsServer() and not g_currentMission.missionDynamicInfo.isMultiplayer then
        g_i3DManager:clearEntireSharedI3DFileCache(false)

        local placeablesToReload = {}
        for _, placeable in ipairs(self.placeables) do
            table.insert(placeablesToReload, placeable)
        end
        self:setSaveIds()

        if #placeablesToReload > 0 then
            self.isReloadRunning = true
            Logging.info("Start reloading placeables...")
            local callback = function(_, placeable, loadingState, args)
                local oldPlaceable = args.placeable
                local xmlFile = args.xmlFile

                xmlFile:delete()

                table.removeElement(placeablesToReload, oldPlaceable)

                if loadingState == Placeable.LOADING_STATE_ERROR then
                    if placeable ~= nil then
                        placeable:delete()
                    end
                    Logging.error("Could not reload placeable '%s'. (%d left)", (placeable and placeable.configFileName) or "unknown", #placeablesToReload)
                else
                    Logging.info("Reloaded placeable '%s'. (%d left)", placeable.configFileName, #placeablesToReload)
                    oldPlaceable.isReloading = true  -- flag to skip actions in onDelete() such as resetting of indoor areas (old placeable is deleted after new one was loaded)
                    oldPlaceable:delete()
                    placeable:register()
                end

                if #placeablesToReload == 0 then
                    Logging.info("Finished reloading placeables")
                    self.isReloadRunning = false
                end
            end

            for k, placeable in ipairs(placeablesToReload) do
                local usedModNames = {}
                local xmlFile = XMLFile.create("placeableXMLFile", "", "placeables", Placeable.xmlSchemaSavegame)
                self:savePlaceableToXML(placeable, xmlFile, 0, 1, usedModNames)

                local key = "placeables.placeable(0)"
                local missionInfo = g_currentMission.missionInfo
                local missionDynamicInfo = g_currentMission.missionDynamicInfo

                local arguments = {
                    placeable = placeable,
                    xmlFile = xmlFile
                }
                self:loadPlaceableFromXML(xmlFile, key, missionInfo, missionDynamicInfo, false, callback, nil, arguments)
            end
        else
            Logging.info("No placeables found")
        end
    end
end


---
function PlaceableSystem:consoleCommandLoadAllPlaceables()
    if self.isLoadAllRunning then
        return "Cannot start loading all placeables. Another loading is currently running"
    end
    if g_currentMission:getIsServer() and not g_currentMission.missionDynamicInfo.isMultiplayer then
        g_i3DManager:clearEntireSharedI3DFileCache(false)

        local placeablesToLoad = {}
        for _, storeItem in ipairs(g_storeManager:getItems()) do
            if storeItem.brush ~= nil and storeItem.brush.type ~= "" then
                -- handle fences
                if storeItem.brush.type == "fence" then
                    local singletonFilename = storeItem.brush.parameters[1]
                    if singletonFilename ~= nil then
                        table.insert(placeablesToLoad, singletonFilename)
                    else
                        Logging.error("No fence singleton filename found for '%s'", storeItem.xmlFilename)
                    end
                else
                    table.insert(placeablesToLoad, storeItem.xmlFilename)
                end
            end
        end

        if #placeablesToLoad > 0 then
            self.isLoadAllRunning = true
            Logging.info("Start loading all placeables...")

            local x, z = 0, 0
            local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
            local position = {x=x, y=y, z=z}
            local rotation = {x=0, y=0, z=0}


            local callback
            callback = function(_, placeable, loadingState, args)

                if loadingState == Placeable.LOADING_STATE_ERROR then
                    Logging.error("Could not load placeable '%s'", placeablesToLoad[1])
                else
                    Logging.info("Loaded placeable '%s'", placeable.configFileName)
                    placeable:finalizePlacement()
                end

                if placeable ~= nil then
                    placeable:delete()
                end
                table.remove(placeablesToLoad, 1)

                if #placeablesToLoad == 0 then
                    Logging.info("Finished loading placeables")
                    self.isLoadAllRunning = false
                else
                    PlaceableUtil.loadPlaceable(placeablesToLoad[1], position, rotation, AccessHandler.EVERYONE, nil, callback, nil, {})
                end
            end

            PlaceableUtil.loadPlaceable(placeablesToLoad[1], position, rotation, AccessHandler.EVERYONE, nil, callback, nil, {})
        else
            Logging.info("No placeables found")
        end
    end
end


---
function PlaceableSystem:consoleCommandPlaceableTestAreas()
    self.isTestAreaRenderingActive = not self.isTestAreaRenderingActive

    for _, placeable in ipairs(self.placeables) do
        local spec = placeable.spec_placement
        if spec ~= nil then
            for _, area in ipairs(spec.testAreas) do
                if self.isTestAreaRenderingActive then
                    area.debugTestBox:createWithStartEnd(area.startNode, area.endNode)
                    area.debugStartNode:createWithNode(area.startNode, getName(area.startNode), false, nil)
                    area.debugEndNode:createWithNode(area.endNode, getName(area.endNode), false, nil)
                    area.debugArea:createWithStartEnd(area.startNode, area.endNode)

                    g_debugManager:addPermanentElement(area.debugTestBox)
                    g_debugManager:addPermanentElement(area.debugStartNode)
                    g_debugManager:addPermanentElement(area.debugEndNode)
                    g_debugManager:addPermanentElement(area.debugArea)
                else
                    g_debugManager:removePermanentElement(area.debugTestBox)
                    g_debugManager:removePermanentElement(area.debugStartNode)
                    g_debugManager:removePermanentElement(area.debugEndNode)
                    g_debugManager:removePermanentElement(area.debugArea)
                end
            end
        end
    end
end
