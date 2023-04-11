---This class handles all functionality for AI fields and the NPCs handling them.


































local FieldManager_mt = Class(FieldManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function FieldManager.new(customMt)
    local self = AbstractManager.new(customMt or FieldManager_mt)

    return self
end


---Initialize data structures
function FieldManager:initDataStructures()
    self.fields = {}
    self.farmlandIdFieldMapping = {}
    self.fieldStatusParametersToSet = nil
    self.currentFieldPartitionIndex = nil
    self.nextCheckTime = 0
    self.nextUpdateTime = 0
    self.nextFieldCheckIndex = 0
end


---Load data on map load
-- @return boolean true if loading was successful else false
function FieldManager:loadMapData(xmlFile)
    FieldManager:superClass().loadMapData(self)

    local mission = g_currentMission
    self.mission = mission

    mission:addUpdateable(self)

    local terrainNode = mission.terrainRootNode
    local fieldGroundSystem = mission.fieldGroundSystem
    local sprayLevelMapId, sprayLevelFirstChannel, sprayLevelNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_LEVEL)
    local sprayLevelMaxValue = fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_LEVEL)
    local plowLevelMapId, plowLevelFirstChannel, plowLevelNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.PLOW_LEVEL)
    local plowLevelMaxValue = fieldGroundSystem:getMaxValue(FieldDensityMap.PLOW_LEVEL)

    self.limeLevelMaxValue = 0
    self.plowLevelMaxValue = plowLevelMaxValue
    self.sprayLevelMaxValue = sprayLevelMaxValue
    self.fruitModifiers = {}

    self.sprayLevelModifier = DensityMapModifier.new(sprayLevelMapId, sprayLevelFirstChannel, sprayLevelNumChannels, terrainNode)
    self.plowLevelModifier = DensityMapModifier.new(plowLevelMapId, plowLevelFirstChannel, plowLevelNumChannels, terrainNode)


    if Platform.gameplay.useLimeCounter then
        local limeLevelMapId, limeLevelFirstChannel, limeLevelNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.LIME_LEVEL)
        self.limeLevelMaxValue = fieldGroundSystem:getMaxValue(FieldDensityMap.LIME_LEVEL)
        self.limeLevelModifier = DensityMapModifier.new(limeLevelMapId, limeLevelFirstChannel, limeLevelNumChannels, terrainNode)
    end

    if Platform.gameplay.useStubbleShred then
        local stubbleShredLevelMapId, stubbleShredLevelFirstChannel, stubbleShredLevelNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.STUBBLE_SHRED)
        self.stubbleShredModifier = DensityMapModifier.new(stubbleShredLevelMapId, stubbleShredLevelFirstChannel, stubbleShredLevelNumChannels, terrainNode)
    end

    local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
    self.groundTypeModifier = DensityMapModifier.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels, terrainNode)

    local groundAngleMapId, groundAngleFirstChannel, groundAngleNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_ANGLE)
    self.angleModifier = DensityMapModifier.new(groundAngleMapId, groundAngleFirstChannel, groundAngleNumChannels, terrainNode)

    local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
    self.sprayTypeModifier = DensityMapModifier.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels, terrainNode)

    self.fieldFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
    self.fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

    if mission.weedSystem:getMapHasWeed() then
        local weedMapId, weedFirstChannel, weedNumChannels = mission.weedSystem:getDensityMapData()
        self.weedModifier = DensityMapModifier.new(weedMapId, weedFirstChannel, weedNumChannels, terrainNode)
    end

    self.fieldGroundSystem = fieldGroundSystem

    local terrainDetailHeightId = mission.terrainDetailHeightId
    self.terrainHeightTypeModifier = DensityMapModifier.new(terrainDetailHeightId, g_densityMapHeightManager.heightTypeFirstChannel, g_densityMapHeightManager.heightTypeNumChannels)
    self.terrainHeightModifier = DensityMapModifier.new(terrainDetailHeightId, getDensityMapHeightFirstChannel(terrainDetailHeightId), getDensityMapHeightNumChannels(terrainDetailHeightId))

    self.groundTypeSown = fieldGroundSystem:getFieldGroundValue(FieldGroundType.SOWN)
    self.sprayTypeFertilizer = fieldGroundSystem:getFieldSprayValue(FieldSprayType.FERTILIZER)
    self.sprayTypeLime = fieldGroundSystem:getFieldSprayValue(FieldSprayType.LIME)

    -- create list of valid/available fruit types
    self.availableFruitTypeIndices = {}
    for _, fruitType in ipairs(g_fruitTypeManager:getFruitTypes()) do
        if fruitType.useForFieldJob and fruitType.allowsSeeding and fruitType.needsSeeding then
            table.insert(self.availableFruitTypeIndices, fruitType.index)
        end
    end
    self.fruitTypesCount = #self.availableFruitTypeIndices

    self.fieldIndexToCheck = 1

    -- Connect farmlands to fields first. We need the farmlands to skip overriding owned fields (in order to have working starter fields)
    g_asyncTaskManager:addSubtask(function()
        for i, field in ipairs(self.fields) do
            local posX, posZ = field:getCenterOfFieldWorldPosition()
            local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
            if farmland ~= nil then
                field:setFarmland(farmland)

                if self.farmlandIdFieldMapping[farmland.id] == nil then
                    self.farmlandIdFieldMapping[farmland.id] = {}
                end

                table.insert(self.farmlandIdFieldMapping[farmland.id], field)
            else
                Logging.error("Failed to find farmland in center of field '%s'", i)
            end
        end
    end)

    -- New save game
    if not mission.missionInfo.isValid and g_server ~= nil then
        g_asyncTaskManager:addSubtask(function()
            local index = 1

            for _, field in pairs(self.fields) do
                if field:getIsAIActive() and field.fieldMissionAllowed and field.farmland ~= nil and not field.farmland.isOwned then
                    -- Plan a random fruit for the NPC
                    local fruitIndex = self.availableFruitTypeIndices[math.random(1, #self.availableFruitTypeIndices)]

                    if field.fieldGrassMission then
                        fruitIndex = FruitType.GRASS
                    end
                    field.plannedFruit = fruitIndex

                    -- Assume the crop is growing
                    local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
                    local fieldState = FieldManager.FIELDSTATE_GROWING

                    local plowState
                    if not mission.missionInfo.plowingRequiredEnabled then
                        plowState = self.plowLevelMaxValue
                    else
                        plowState = math.random(0, self.plowLevelMaxValue)
                    end

                    local sprayLevel = math.random(0, self.sprayLevelMaxValue)
                    local limeState = math.random(0, self.limeLevelMaxValue)

                    local weedValue = 0

                    -- Growth state is defined by the growth system which gives us a random
                    -- state that is possible on a new save.
                    local growthState = g_currentMission.growthSystem:getRandomInitialState(fruitIndex)

                    if growthState == nil and fruitIndex == FruitType.GRASS then
                        -- Force grass
                        growthState = 2
                    end

                    -- growth state is nil when there is no initial state because it is not possible
                    if growthState ~= nil then
                        if fruitDesc.plantsWeed then
                            -- Add some randomness: older plants have higher chance of older weeds
                            if growthState > 4 then
                                weedValue = math.random(3, 9)
                            else
                                weedValue = math.random(1, 7)
                            end
                        end

                        if growthState == fruitDesc.cutState then
                            fieldState = FieldManager.FIELDSTATE_HARVESTED
                        end
                    else
                        fieldState = math.random() < 0.5 and FieldManager.FIELDSTATE_CULTIVATED or FieldManager.FIELDSTATE_PLOWED

                        if fieldState == FieldManager.FIELDSTATE_PLOWED then
                            plowState = self.plowLevelMaxValue
                        end

                        fruitIndex = 0
                    end

                    for i = 1, table.getn(field.maxFieldStatusPartitions) do
                        self:setFieldPartitionStatus(field, field.maxFieldStatusPartitions, i, fruitIndex, fieldState, growthState, sprayLevel, false, plowState, weedValue, limeState)
                    end

                    index = index + 1
                end
            end
        end)
    elseif g_server ~= nil then
        -- get current state of fields
        for _, field in pairs(self.fields) do
            g_asyncTaskManager:addSubtask(function()
                self:findFieldFruit(field)
            end)
        end
    end

    g_asyncTaskManager:addSubtask(function()
        self:findFieldSizes()
    end)

    g_asyncTaskManager:addSubtask(function()
        g_farmlandManager:addStateChangeListener(self)

        if mission:getIsServer() then
            if g_addCheatCommands then
                addConsoleCommand("gsFieldSetFruit", "Sets a given fruit to field", "consoleCommandSetFieldFruit", self)
                addConsoleCommand("gsFieldSetFruitAll", "Sets a given fruit to all fields", "consoleCommandSetFieldFruitAll", self)
                addConsoleCommand("gsFieldSetGround", "Sets a given fruit to field", "consoleCommandSetFieldGround", self)
                addConsoleCommand("gsFieldSetGroundAll", "Sets a given fruit to allfield", "consoleCommandSetFieldGroundAll", self)
            end
        end

        if g_addCheatCommands then
            addConsoleCommand("gsFieldToggleStatus", "Shows field status", "consoleCommandToggleDebugFieldStatus", self)
        end
    end)

    -- On clients, force all fields to have some value so map at least shows them
    g_asyncTaskManager:addSubtask(function()
        if not mission:getIsServer() then
            for _, field in pairs(self.fields) do
                self:setFieldGround(field, FieldGroundType.CULTIVATED, field.fieldAngle, 0, 0, 0, 0, 0, 0, false, false)
            end
        end
    end)

    g_messageCenter:subscribe(MessageType.FARM_PROPERTY_CHANGED, self.onFarmPropertyChanged, self)
    g_messageCenter:subscribe(MessageType.YEAR_CHANGED, self.onYearChanged, self)
    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)
end


---Unload data on mission delete
function FieldManager:unloadMapData()
    if self.mission ~= nil then
        self.mission:removeUpdateable(self)
    end

    g_farmlandManager:removeStateChangeListener(self)

    for _, field in pairs(self.fields) do
        field:delete()
    end
    self.fields = {}
    self.fieldsToCheck = nil
    self.fieldsToUpdate = nil

    self.fieldGroundSystem = nil
    self.sprayLevelModifier = nil
    self.plowLevelModifier = nil
    self.limeLevelModifier = nil
    self.stubbleShredModifier = nil
    self.fruitModifiers = nil
    self.sprayTypeModifier = nil
    self.angleModifier = nil
    self.groundTypeModifier = nil
    self.fieldFilter = nil
    self.weedModifier = nil
    self.terrainHeightTypeModifier = nil
    self.terrainHeightModifier = nil
    self.mission = nil

    g_messageCenter:unsubscribeAll(self)

    removeConsoleCommand("gsFieldSetFruit")
    removeConsoleCommand("gsFieldSetFruitAll")
    removeConsoleCommand("gsFieldSetGround")
    removeConsoleCommand("gsFieldSetGroundAll")
    removeConsoleCommand("gsFieldToggleStatus")

    FieldManager:superClass().unloadMapData(self)
end


---Deletes field manager
function FieldManager:delete()
end


---Load field savegame data
-- @param string filename xml filename
function FieldManager:loadFromXMLFile(xmlFilename)
    local xmlFile = XMLFile.load("fields", xmlFilename)
    if xmlFile == nil then
        return
    end

    xmlFile:iterate("fields.field", function (_, key)
        local fieldId = xmlFile:getInt(key .. "#id")
        local fruitName = xmlFile:getString(key .. "#plannedFruit")
        local fruitDesc = g_fruitTypeManager:getFruitTypeByName(fruitName)

        if fieldId ~= nil then
            local field = self:getFieldByIndex(fieldId)
            if field ~= nil then
                if fruitName == "FALLOW" then
                    field.plannedFruit = 0
                elseif fruitDesc ~= nil then
                    field.plannedFruit = fruitDesc.index
                end
            end
        end
    end)

    xmlFile:delete()
end


---Write field data
-- @param string xmlFilename file path
-- @return boolean true if loading was successful else false
function FieldManager:saveToXMLFile(xmlFilename)
    local xmlFile = XMLFile.create("fields", xmlFilename, "fields")

    for i = 1, #self.fields do
        local field = self.fields[i]

        local key = string.format("fields.field(%d)", i - 1)

        xmlFile:setInt(key .. "#id", field.fieldId)

        if field.plannedFruit == 0 then
            xmlFile:setString(key .. "#plannedFruit", "FALLOW")
        else
            xmlFile:setString(key .. "#plannedFruit", g_fruitTypeManager:getFruitTypeByIndex(field.plannedFruit).name)
        end
    end

    xmlFile:save()
    xmlFile:delete()
end
