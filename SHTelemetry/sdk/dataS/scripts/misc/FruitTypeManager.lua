---This class handles all fruitTypes and fruitTypeCategories
















































































































local FruitTypeManager_mt = Class(FruitTypeManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function FruitTypeManager.new(customMt)
    local self = AbstractManager.new(customMt or FruitTypeManager_mt)
    return self
end


---Initialize data structures
function FruitTypeManager:initDataStructures()
    self.fruitTypes = {}
    self.indexToFruitType = {}
    self.nameToIndex = {}
    self.nameToFruitType = {}
    self.fruitTypeIndexToFillType = {}
    self.fillTypeIndexToFruitTypeIndex = {}

    self.fruitTypeConverters = {}
    self.converterNameToIndex = {}
    self.nameToConverter = {}

    self.windrowFillTypes = {}
    self.fruitTypeIndexToWindrowFillTypeIndex = {}

    self.numCategories = 0
    self.categories = {}
    self.indexToCategory = {}
    self.categoryToFruitTypes = {}

    FruitType = self.nameToIndex
    FruitType.UNKNOWN = 0
    FruitTypeCategory = self.categories
    FruitTypeConverter = self.converterNameToIndex
end


---
function FruitTypeManager:loadDefaultTypes()
    local xmlFile = loadXMLFile("fuitTypes", "data/maps/maps_fruitTypes.xml")
    self:loadFruitTypes(xmlFile, nil, true)
    delete(xmlFile)
end


---Load data on map load
-- @return boolean true if loading was successful else false
function FruitTypeManager:loadMapData(xmlFile, missionInfo, baseDirectory)
    FruitTypeManager:superClass().loadMapData(self)

    self:loadDefaultTypes()
    return XMLUtil.loadDataFromMapXML(xmlFile, "fruitTypes", baseDirectory, self, self.loadFruitTypes, missionInfo)
end


---Loads fruitTypes
-- @param table self target
-- @param integer xmlFile xml file handle
-- @return boolean success success
function FruitTypeManager:loadFruitTypes(xmlFile, missionInfo, isBaseType)

    local i = 0
    while true do
        local key = string.format("map.fruitTypes.fruitType(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key.."#name")
        local shownOnMap = getXMLBool(xmlFile, key.."#shownOnMap")
        local useForFieldJob = getXMLBool(xmlFile, key.."#useForFieldJob")
        local missionMultiplier = getXMLFloat(xmlFile, key.."#missionMultiplier")

        local fruitType = self:addFruitType(name, shownOnMap, useForFieldJob, missionMultiplier, isBaseType)
        if fruitType ~= nil then
            local success = true
            success = success and self:loadFruitTypeGeneral(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeWindrow(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeGrowth(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeHarvest(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeCultivation(fruitType, xmlFile, key)
            success = success and self:loadFruitTypePreparing(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeCropCare(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeOptions(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeMapColors(fruitType, xmlFile, key)
            success = success and self:loadFruitTypeDestruction(fruitType, xmlFile, key)

            if success and self.indexToFruitType[fruitType.index] == nil then
                local maxNumFruitTypes = 2^FruitTypeManager.SEND_NUM_BITS-1
                if #self.fruitTypes >= maxNumFruitTypes then
                    Logging.error("FruitTypeManager.loadFruitTypes too many fruit types. Only %d fruit types are supported", maxNumFruitTypes)
                    return
                end

                table.insert(self.fruitTypes, fruitType)
                self.nameToFruitType[fruitType.name] = fruitType
                self.nameToIndex[fruitType.name] = fruitType.index
                self.indexToFruitType[fruitType.index] = fruitType

                self.fillTypeIndexToFruitTypeIndex[fruitType.fillType.index] = fruitType.index
                self.fruitTypeIndexToFillType[fruitType.index] = fruitType.fillType
            end
        end

        i = i + 1
    end

    i = 0
    while true do
        local key = string.format("map.fruitTypeCategories.fruitTypeCategory(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key.."#name")
        local fruitTypesStr = getXMLString(xmlFile, key)

        local fruitTypeCategoryIndex = self:addFruitTypeCategory(name, isBaseType)
        if fruitTypeCategoryIndex ~= nil then
            local fruitTypeNames = string.split(fruitTypesStr, " ")
            for _, fruitTypeName in ipairs(fruitTypeNames) do
                local fruitType = self:getFruitTypeByName(fruitTypeName)
                if fruitType ~= nil then
                    if not self:addFruitTypeToCategory(fruitType.index, fruitTypeCategoryIndex) then
                        print("Warning: Could not add fruitType '"..tostring(fruitTypeName).."' to fruitTypeCategory '"..tostring(name).."'!")
                    end
                else
                    print("Warning: FruitType '"..tostring(fruitTypeName).."' referenced in fruitTypeCategory '"..tostring(name).."' is not defined!")
                end
            end
        end

        i = i + 1
    end

    i = 0
    while true do
        local key = string.format("map.fruitTypeConverters.fruitTypeConverter(%d)", i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key.."#name")
        local converter = self:addFruitTypeConverter(name, isBaseType)
        if converter ~= nil then
            local j = 0
            while true do
                local converterKey = string.format("%s.converter(%d)", key, j)
                if not hasXMLProperty(xmlFile, converterKey) then
                    break
                end

                local from = getXMLString(xmlFile, converterKey.."#from")
                local to = getXMLString(xmlFile, converterKey.."#to")
                local factor = getXMLFloat(xmlFile, converterKey.."#factor")
                local windrowFactor = getXMLFloat(xmlFile, converterKey.."#windrowFactor")

                local fruitType = self:getFruitTypeByName(from)
                local fillType = g_fillTypeManager:getFillTypeByName(to)

                if fruitType ~= nil and fillType ~= nil and factor ~= nil then
                    self:addFruitTypeConversion(converter, fruitType.index, fillType.index, factor, windrowFactor)
                end

                j = j + 1
            end
        end

        i = i + 1
    end

    return true
end


---Adds a new fruitType
-- @param string name fruit index name
-- @param boolean shownOnMap show on map
-- @param boolean useForFieldJob use for field job
-- @return table fruitType fruitType type object
function FruitTypeManager:addFruitType(name, shownOnMap, useForFieldJob, missionMultiplier, isBaseType)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is not a valid name for a fruitType. Ignoring fruitType!")
        return nil
    end

    local upperName = name:upper()

    local fillType = g_fillTypeManager:getFillTypeByName(upperName)
    if fillType == nil then
        print("Warning: Missing fillType '"..tostring(name).."' for fruitType definition. Ignoring fruitType!")
        return nil
    end

    if isBaseType and self.nameToFruitType[upperName] ~= nil then
        print("Warning: FillType '"..tostring(name).."' already exists. Ignoring fillType!")
        return nil
    end

    local fruitType = self.nameToFruitType[upperName]
    if fruitType == nil then
        fruitType = {}
        fruitType.layerName = name
        fruitType.name = upperName
        fruitType.index = #self.fruitTypes + 1
        fruitType.fillType = fillType

        fruitType.defaultMapColor = {1, 1, 1, 1}
        fruitType.colorBlindMapColor = {1, 1, 1, 1}
    end

    fruitType.shownOnMap = Utils.getNoNil(shownOnMap, Utils.getNoNil(fruitType.shownOnMap, true))
    fruitType.useForFieldJob = Utils.getNoNil(useForFieldJob, Utils.getNoNil(fruitType.useForFieldJob, true))
    fruitType.missionMultiplier = Utils.getNoNil(missionMultiplier, Utils.getNoNil(fruitType.missionMultiplier, 1.0))

    return fruitType
end











---Loads fruitType windrow data
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeWindrow(fruitType, xmlFile, key)
    if fruitType ~= nil then
        local windrowName = getXMLString(xmlFile, key..".windrow#name")
        local windrowLitersPerSqm = getXMLFloat(xmlFile, key..".windrow#litersPerSqm")

        if windrowName == nil or windrowLitersPerSqm == nil then
            return true
        end

        local windrowFillType = g_fillTypeManager:getFillTypeByName(windrowName)
        if windrowFillType == nil then
            print("Warning: Mission fillType '"..tostring(windrowName).."' for windrow definition. Ignoring windrow!")
            return false
        end

        fruitType.hasWindrow = true
        fruitType.windrowName = windrowFillType.name
        fruitType.windrowLiterPerSqm = windrowLitersPerSqm

        self.windrowFillTypes[windrowFillType.index] = true
        self.fruitTypeIndexToWindrowFillTypeIndex[fruitType.index] = windrowFillType.index
        self.fillTypeIndexToFruitTypeIndex[windrowFillType.index] = fruitType.index
    end

    return true
end


---Loads fruitType growth data
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeGrowth(fruitType, xmlFile, key)
    if fruitType ~= nil then
        fruitType.isGrowing = Utils.getNoNil(getXMLBool(xmlFile, key..".growth#isGrowing"), Utils.getNoNil(fruitType.isGrowing, true))
        if fruitType.isGrowing then
            fruitType.numGrowthStates = Utils.getNoNil(getXMLInt(xmlFile, key..".growth#numGrowthStates"), Utils.getNoNil(fruitType.numGrowthStates, 0))
            -- fruitType.growthStateTime = Utils.getNoNil(getXMLInt(xmlFile, key..".growth#growthStateTime"), Utils.getNoNil(fruitType.growthStateTime, 0))
            fruitType.resetsSpray = Utils.getNoNil(getXMLBool(xmlFile, key..".growth#resetsSpray"), Utils.getNoNil(fruitType.resetsSpray, true))
            fruitType.growthRequiresLime = Utils.getNoNil(getXMLInt(xmlFile, key..".growth#requiresLime"), Utils.getNoNil(fruitType.growthRequiresLime, true))

            fruitType.witheredState = getXMLInt(xmlFile, key..".growth#witheredState") or fruitType.witheredState

            fruitType.groundTypeChangeGrowthState = Utils.getNoNil(getXMLInt(xmlFile, key..".growthGroundTypeChange#state"), Utils.getNoNil(fruitType.groundTypeChangeGrowthState, -1))
            local groundTypeStr = getXMLString(xmlFile, key..".growthGroundTypeChange#groundType")
            if groundTypeStr ~= nil then
                local groundType = FieldGroundType.getByName(groundTypeStr)
                if groundType == nil then
                    Logging.warning("Invalid groundTypeChanged name '%s'. Ignoring growth data!", groundTypeStr)
                    return false
                end
                fruitType.groundTypeChangeType = groundType
            end

            fruitType.groundTypeChangeMaskTypes = {}
            local groundTypeChangeMaskString = getXMLString(xmlFile, key..".growthGroundTypeChange#groundTypeMask")
            if groundTypeChangeMaskString ~= nil then
                local groundTypeChangeMaskList = groundTypeChangeMaskString:split(" ")
                for _, v in ipairs(groundTypeChangeMaskList) do
                    local groundType = FieldGroundType.getByName(v)
                    if groundType ~= nil then
                        table.insert(fruitType.groundTypeChangeMaskTypes, groundType)
                    else
                        Logging.warning("Invalid groundTypeChangeMask name '%s'. Ignoring growth data!", v)
                        return false
                    end
                end
            end

            fruitType.regrows = Utils.getNoNil(getXMLBool(xmlFile, key .. ".growth#regrows"), Utils.getNoNil(fruitType.regrows, false))
            if fruitType.regrows then
                fruitType.firstRegrowthState = Utils.getNoNil(getXMLInt(xmlFile, key .. ".growth#firstRegrowthState"), Utils.getNoNil(fruitType.firstRegrowthState, 1))
            end
        end

        return true
    end

    return false
end


---Loads fruitType harvest data
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeHarvest(fruitType, xmlFile, key)
    if fruitType ~= nil then
        fruitType.minHarvestingGrowthState = Utils.getNoNil(getXMLInt(xmlFile, key..".harvest#minHarvestingGrowthState"), Utils.getNoNil(fruitType.minHarvestingGrowthState, 0))
        fruitType.maxHarvestingGrowthState = Utils.getNoNil(getXMLInt(xmlFile, key..".harvest#maxHarvestingGrowthState"), Utils.getNoNil(fruitType.maxHarvestingGrowthState, 0))
        fruitType.minForageGrowthState = Utils.getNoNil(getXMLInt(xmlFile, key..".harvest#minForageGrowthState"), Utils.getNoNil(fruitType.minForageGrowthState, fruitType.minHarvestingGrowthState))
        fruitType.cutState = Utils.getNoNil(getXMLInt(xmlFile, key..".harvest#cutState"), Utils.getNoNil(fruitType.cutState, 0))
        fruitType.allowsPartialGrowthState = Utils.getNoNil(getXMLBool(xmlFile, key..".harvest#allowsPartialGrowthState"), Utils.getNoNil(fruitType.allowsPartialGrowthState, false))
        fruitType.literPerSqm = Utils.getNoNil(getXMLFloat(xmlFile, key..".harvest#literPerSqm"), Utils.getNoNil(fruitType.literPerSqm, 0))
        fruitType.cutHeight = Utils.getNoNil(getXMLFloat(xmlFile, key..".harvest#cutHeight"), fruitType.cutHeight)
        fruitType.forageCutHeight = Utils.getNoNil(getXMLFloat(xmlFile, key..".harvest#forageCutHeight"), fruitType.forageCutHeight or fruitType.cutHeight)
        fruitType.beeYieldBonusPercentage = getXMLFloat(xmlFile, key..".harvest#beeYieldBonusPercentage") or 0
        local harvestGroundTypeChange = getXMLString(xmlFile, key..".harvestGroundTypeChange#groundType")
        if harvestGroundTypeChange ~= nil then
            local groundType = FieldGroundType.getByName(harvestGroundTypeChange)
            if groundType ~= nil then
                fruitType.harvestGroundTypeChange = groundType
            end
        end

        local chopperTypeName = getXMLString(xmlFile, key..".harvest#chopperTypeName") or nil
        if chopperTypeName ~= nil then
            fruitType.chopperTypeIndex = g_currentMission.fieldGroundSystem:getChopperTypeIndexByName(chopperTypeName)
            if fruitType.chopperTypeIndex == nil then
                Logging.warning("Invalid chopperTypeName name '%s' for '%s'.", chopperTypeName, key..".harvest")
            end
        end

        local transitions
        local i = 0
        while true do
            local transitionKey = string.format("%s.harvest.transition(%d)", key, i)
            if not hasXMLProperty(xmlFile, transitionKey) then
                break
            end

            local srcState = getXMLInt(xmlFile, transitionKey .. "#srcState")
            local targetState = getXMLInt(xmlFile, transitionKey .. "#targetState")

            if srcState ~= nil and targetState ~= nil then
                if transitions == nil then
                    transitions = {}
                end

                transitions[srcState] = targetState
            end

            i = i + 1
        end

        fruitType.harvestTransitions = transitions

        fruitType.harvestWeedState = Utils.getNoNil(getXMLInt(xmlFile, key..".harvest#weedState"), Utils.getNoNil(fruitType.harvestWeedState, nil))

        return true
    end

    return false
end


---Loads fruitType cultivation data
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeCultivation(fruitType, xmlFile, key)
    if fruitType ~= nil then
        fruitType.needsSeeding = Utils.getNoNil(getXMLBool(xmlFile, key..".cultivation#needsSeeding"), Utils.getNoNil(fruitType.needsSeeding, true))
        fruitType.allowsSeeding = Utils.getNoNil(getXMLBool(xmlFile, key..".cultivation#allowsSeeding"), Utils.getNoNil(fruitType.allowsSeeding, true))
        fruitType.directionSnapAngle = Utils.getNoNilRad(getXMLFloat(xmlFile, key..".cultivation#directionSnapAngle"), Utils.getNoNil(fruitType.directionSnapAngle, 0))
        fruitType.alignsToSun = Utils.getNoNil(getXMLBool(xmlFile, key..".cultivation#alignsToSun"), Utils.getNoNil(fruitType.alignsToSun, false))
        fruitType.seedUsagePerSqm = Utils.getNoNil(getXMLFloat(xmlFile, key..".cultivation#seedUsagePerSqm"), Utils.getNoNil(fruitType.seedUsagePerSqm, 0.1))
        fruitType.plantsWeed = Utils.getNoNil(getXMLBool(xmlFile, key..".cultivation#plantsWeed"), Utils.getNoNil(fruitType.plantsWeed, true))
        fruitType.needsRolling = Utils.getNoNil(getXMLBool(xmlFile, key..".cultivation#needsRolling"), Utils.getNoNil(fruitType.needsRolling, true))

        local cultivationStates
        local i = 0
        while true do
            local cultivationKey = string.format("%s.cultivation.state(%d)", key, i)
            if not hasXMLProperty(xmlFile, cultivationKey) then
                break
            end

            local state = getXMLInt(xmlFile, cultivationKey .. "#state")

            if state ~= nil then
                if cultivationStates == nil then
                    cultivationStates = {}
                end

                table.insert(cultivationStates, state)
            end

            i = i + 1
        end

        fruitType.cultivationStates = cultivationStates


        return true
    end

    return false
end


---Loads fruitType preparing data
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypePreparing(fruitType, xmlFile, key)
    if fruitType ~= nil then
        fruitType.preparingOutputName = Utils.getNoNil(getXMLString(xmlFile, key..".preparing#outputName"), fruitType.preparingOutputName)
        fruitType.minPreparingGrowthState = Utils.getNoNil(getXMLInt(xmlFile, key..".preparing#minGrowthState"), Utils.getNoNil(fruitType.minPreparingGrowthState, -1))
        fruitType.maxPreparingGrowthState = Utils.getNoNil(getXMLInt(xmlFile, key..".preparing#maxGrowthState"), Utils.getNoNil(fruitType.maxPreparingGrowthState, -1))
        fruitType.preparedGrowthState = Utils.getNoNil(getXMLInt(xmlFile, key..".preparing#preparedGrowthState"), Utils.getNoNil(fruitType.preparedGrowthState, -1))

        return true
    end

    return false
end


---Loads fruitType cropcare data
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeCropCare(fruitType, xmlFile, key)
    if fruitType ~= nil then
        fruitType.maxWeederState = getXMLInt(xmlFile, key..".cropCare#maxWeederState") or fruitType.maxWeederState or 2
        fruitType.maxWeederHoeState = getXMLInt(xmlFile, key..".cropCare#maxWeederHoeState") or fruitType.maxWeederHoeState or fruitType.maxWeederState

        return true
    end

    return false
end


---Loads fruitType option data
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeOptions(fruitType, xmlFile, key)
    if fruitType ~= nil then
        fruitType.increasesSoilDensity = Utils.getNoNil(getXMLBool(xmlFile, key..".options#increasesSoilDensity"), Utils.getNoNil(fruitType.increasesSoilDensity, false))
        fruitType.lowSoilDensityRequired = Utils.getNoNil(getXMLBool(xmlFile, key..".options#lowSoilDensityRequired"), Utils.getNoNil(fruitType.lowSoilDensityRequired, true))
        fruitType.consumesLime = Utils.getNoNil(getXMLBool(xmlFile, key..".options#consumesLime"), Utils.getNoNil(fruitType.consumesLime, true))
        fruitType.startSprayState = math.max(Utils.getNoNil(getXMLInt(xmlFile, key..".options#startSprayState"), Utils.getNoNil(fruitType.startSprayState, 0)), 0)

        return true
    end

    return false
end


---Load fruit type map overlay color data.
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeMapColors(fruitType, xmlFile, key)
    if fruitType ~= nil then
        local defaultColorString = getXMLString(xmlFile, key .. ".mapColors#default") or "1 1 1 1" -- default white
        local defaultColorBlindString = getXMLString(xmlFile, key .. ".mapColors#colorBlind") or "1 1 1 1"

        fruitType.defaultMapColor = GuiUtils.getColorArray(defaultColorString) or fruitType.defaultMapColor
        fruitType.colorBlindMapColor = GuiUtils.getColorArray(defaultColorBlindString) or fruitType.colorBlindMapColor

        return true
    end

    return false
end


---Load fruit type map overlay color data.
-- @param table fruitType fruit type object
-- @param integer xmlFile xml file handle
-- @param string key xml key
function FruitTypeManager:loadFruitTypeDestruction(fruitType, xmlFile, key)
    if fruitType ~= nil then
        fruitType.destruction = fruitType.destruction or {}
        if hasXMLProperty(xmlFile, key..".destruction") then
            local destruction = fruitType.destruction

            destruction.onlyOnField = Utils.getNoNil(getXMLBool(xmlFile, key..".destruction#onlyOnField"), Utils.getNoNil(destruction.onlyOnField, true))
            destruction.filterStart = getXMLInt(xmlFile, key..".destruction#filterStart", destruction.filterStart)
            destruction.filterEnd = getXMLInt(xmlFile, key..".destruction#filterEnd", destruction.filterEnd)
            destruction.state = getXMLInt(xmlFile, key..".destruction#state") or destruction.state or fruitType.cutState

            destruction.canBeDestroyed = Utils.getNoNil(getXMLBool(xmlFile, key..".destruction#canBeDestroyed"), Utils.getNoNil(destruction.canBeDestroyed, true))
        end

        fruitType.mulcher = fruitType.mulcher or {}
        fruitType.mulcher.state = Utils.getNoNil(getXMLInt(xmlFile, key..".mulcher#state"), fruitType.mulcher.state or (2^fruitType.numStateChannels-1))

        fruitType.mulcher.hasChopperGroundLayer = Utils.getNoNil(getXMLBool(xmlFile, key..".mulcher#hasChopperGroundLayer"), Utils.getNoNil(fruitType.mulcher.hasChopperGroundLayer, true))
        local chopperTypeName = getXMLString(xmlFile, key..".harvest#chopperTypeName") or "CHOPPER_STRAW"
        if chopperTypeName ~= nil then
            fruitType.mulcher.chopperTypeIndex = g_currentMission.fieldGroundSystem:getChopperTypeIndexByName(chopperTypeName)
        end

        local defaultColorString = getXMLString(xmlFile, key .. ".mapColors#default") or "1 1 1 1" -- default white
        local defaultColorBlindString = getXMLString(xmlFile, key .. ".mapColors#colorBlind") or "1 1 1 1"

        fruitType.defaultMapColor = GuiUtils.getColorArray(defaultColorString) or fruitType.defaultMapColor
        fruitType.colorBlindMapColor = GuiUtils.getColorArray(defaultColorBlindString) or fruitType.colorBlindMapColor

        return true
    end

    return false
end


---Gets a fruitType by index
-- @param integer index the fruit index
-- @return table fruit the fruit object
function FruitTypeManager:getFruitTypeByIndex(index)
    return self.indexToFruitType[index]
end


---
function FruitTypeManager:getFruitTypeNameByIndex(index)
    if self.indexToFruitType[index] ~= nil then
        return self.indexToFruitType[index].name
    end
    return nil
end


---Gets a fruitType by index name
-- @param string name the fruit index name
-- @return table fruit the fruit object
function FruitTypeManager:getFruitTypeByName(name)
    return self.nameToFruitType[name and string.upper(name)]
end


---Gets a list of fruitTypes
-- @return table fruitTypes a list of fruitTypes
function FruitTypeManager:getFruitTypes()
    return self.fruitTypes
end


---
function FruitTypeManager:getFruitTypeIndexByFillTypeIndex(index)
    return self.fillTypeIndexToFruitTypeIndex[index]
end


---
function FruitTypeManager:getFruitTypeByFillTypeIndex(index)
    return self.fruitTypes[self.fillTypeIndexToFruitTypeIndex[index]]
end


---Checks that the given growth state is within the growing state of the fruit with the given index.
-- @param integer index The index of the fruit.
-- @param integer growthState The current growth state of the fruit.
-- @return boolean isGrowing Is true if the fruit's growth state is growing; otherwise false.
function FruitTypeManager:getIsFruitGrowing(index, growthState)

    -- Get the fruit type from the index.
    local fruitType = self:getFruitTypeByIndex(index)

    -- Get the highest growth state that counts as growing.
    local maxGrowingState = fruitType.minHarvestingGrowthState - 1
    if fruitType.minPreparingGrowthState >= 0 then
        maxGrowingState = math.min(maxGrowingState, fruitType.minPreparingGrowthState - 1)
    end

    -- The fruit is growing as long as its state is above 0 and under the maximum growing state.
    return fruitType and growthState > 0 and growthState <= maxGrowingState
end


---Checks that the given growth state is within the harvest preparation state of the fruit with the given index.
-- @param integer index The index of the fruit.
-- @param integer growthState The current growth state of the fruit.
-- @return boolean isPreparableForHarvest Is true if the fruit's growth state is preparable for harvest; otherwise false.
function FruitTypeManager:getIsFruitPreparableForHarvest(index, growthState)

    -- Get the fruit type from the index.
    local fruitType = self:getFruitTypeByIndex(index)

    -- The fruit is preparable for harvest if the fruit requires preparation, and the growth state is within that range.
    return fruitType and fruitType.minPreparingGrowthState >= 0 and growthState >= fruitType.minPreparingGrowthState and growthState <= fruitType.maxPreparingGrowthState
end


---Checks that the given growth state is within the harvestable state of the fruit with the given index.
-- @param integer index The index of the fruit.
-- @param integer growthState The current growth state of the fruit.
-- @return boolean isHarvestable Is true if the fruit's growth state is harvestable; otherwise false.
function FruitTypeManager:getIsFruitHarvestable(index, growthState)

    -- Get the fruit type from the index.
    local fruitType = self:getFruitTypeByIndex(index)

    -- The fruit is ready for harvest as long as it's done growing but not withered.
    return fruitType and growthState >= fruitType.minHarvestingGrowthState and growthState <= fruitType.maxHarvestingGrowthState
end


---Checks that the given growth state is equal to the withered state of the fruit with the given index.
-- @param integer index The index of the fruit.
-- @param integer growthState The current growth state of the fruit.
-- @return boolean isWithered Is true if the fruit's growth state is withered; otherwise false.
function FruitTypeManager:getIsFruitWithered(index, growthState)

    -- Get the fruit type from the index.
    local fruitType = self:getFruitTypeByIndex(index)

    -- Calculate the withered state of the fruit.
    local witheredState = fruitType.maxHarvestingGrowthState + 1
    if fruitType.maxPreparingGrowthState >= 0 then
        witheredState = fruitType.maxPreparingGrowthState + 1
    end

    -- The fruit is withered if it is past harvest state.
    return fruitType and growthState == witheredState
end


---Checks that the given growth state is equal to the cut state of the fruit with the given index.
-- @param integer index The index of the fruit.
-- @param integer growthState The current growth state of the fruit.
-- @return boolean isCut Is true if the fruit's growth state is cut; otherwise false.
function FruitTypeManager:getIsFruitCut(index, growthState)

    -- Get the fruit type from the index.
    local fruitType = self:getFruitTypeByIndex(index)

    -- The fruit is cut if the growth state matches the cut state.
    return fruitType and growthState == fruitType.cutState
end


---
function FruitTypeManager:getFillTypeIndexByFruitTypeIndex(index)
    local fillType = self.fruitTypeIndexToFillType[index]
    if fillType ~= nil then
        return fillType.index
    end
    return nil
end


---
function FruitTypeManager:getFillTypeByFruitTypeIndex(index)
    return self.fruitTypeIndexToFillType[index]
end


---
function FruitTypeManager:getCutHeightByFruitTypeIndex(index, isForageCutter)
    local fruitType = self.indexToFruitType[index]
    if isForageCutter then
        return (fruitType and (fruitType.forageCutHeight or fruitType.cutHeight)) or 0.15
    end

    return (fruitType and fruitType.cutHeight) or 0.15
end


---Adds a new fruitType category
-- @param string name fruit category index name
-- @return table fruitTypeCategory fruitType category object
function FruitTypeManager:addFruitTypeCategory(name, isBaseType)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is not a valid name for a fruitTypeCategory. Ignoring fruitTypeCategory!")
        return nil
    end

    name = name:upper()

    if isBaseType and self.categories[name] ~= nil then
        print("Warning: FruitTypeCategory '"..tostring(name).."' already exists. Ignoring fruitTypeCategory!")
        return nil
    end

    local index = self.categories[name]

    if index == nil then
        self.numCategories = self.numCategories + 1
        self.categories[name] = self.numCategories
        self.indexToCategory[self.numCategories] = name
        self.categoryToFruitTypes[self.numCategories] = {}
        index = self.numCategories
    end

    return index
end


---Add fruitType to category
-- @param Integer fruitTypeIndex index of fruit type
-- @param Integer categoryIndex index of category
-- @return table success true if added else false
function FruitTypeManager:addFruitTypeToCategory(fruitTypeIndex, categoryIndex)
    if categoryIndex ~= nil and fruitTypeIndex ~= nil then
        table.insert(self.categoryToFruitTypes[categoryIndex], fruitTypeIndex)
        return true
    end
    return false
end



---Gets a list of fruitTypes of the given category names
-- @param string name fruitType category index names
-- @param string warning a warning text shown if a category is not found
-- @return table fruitTypes list of fruitTypes
function FruitTypeManager:getFruitTypesByCategoryNames(names, warning)
    local fruitTypes = {}
    local alreadyAdded = {}
    local categories = string.split(names, " ")
    for _, categoryName in pairs(categories) do
        categoryName = categoryName:upper()
        local categoryIndex = self.categories[categoryName]
        local categoryFruitTypes = self.categoryToFruitTypes[categoryIndex]
        if categoryFruitTypes ~= nil then
            for _, fruitType in ipairs(categoryFruitTypes) do
                if alreadyAdded[fruitType] == nil then
                    table.insert(fruitTypes, fruitType)
                    alreadyAdded[fruitType] = true
                end
            end
        else
            if warning ~= nil then
                print(string.format(warning, categoryName))
            end
        end
    end
    return fruitTypes
end


---Gets list of fruitTypes from string with fruit type names
-- @param string fruitTypes fruit types
-- @param string warning warning if fruit type not found
-- @return table fruitTypes fruit types
function FruitTypeManager:getFruitTypesByNames(names, warning)
    local fruitTypes = {}
    local alreadyAdded = {}
    local fruitTypeNames = string.split(names, " ")
    for _, name in pairs(fruitTypeNames) do
        name = name:upper()
        local fruitTypeIndex = self.nameToIndex[name]
        if fruitTypeIndex ~= nil then
            if alreadyAdded[fruitTypeIndex] == nil then
                table.insert(fruitTypes, fruitTypeIndex)
                alreadyAdded[fruitTypeIndex] = true
            end
        else
            if warning ~= nil then
                print(string.format(warning, name))
            end
        end
    end

    return fruitTypes
end


---Gets a list if fillType from string with fruit type names
-- @param string names fruit type names
-- @param string warning warning if fill type not found
-- @return table fillTypes fill types
function FruitTypeManager:getFillTypesByFruitTypeNames(names, warning)
    local fillTypes = {}
    local alreadyAdded = {}
    local fruitTypeNames = string.split(names, " ")
    for _, name in pairs(fruitTypeNames) do
        local fillType = nil
        local fruitType = self:getFruitTypeByName(name)
        if fruitType ~= nil then
            fillType = self:getFillTypeByFruitTypeIndex(fruitType.index)
        end
        if fillType ~= nil then
            if alreadyAdded[fillType.index] == nil then
                table.insert(fillTypes, fillType.index)
                alreadyAdded[fillType.index] = true
            end
        else
            if warning ~= nil then
                print(string.format(warning, name))
            end
        end
    end

    return fillTypes
end


---Gets a list of fillTypes from string with fruit type category names
-- @param string fruitTypeCategories fruit type categories
-- @param string warning warning if category not found
-- @return table fillTypes fill types
function FruitTypeManager:getFillTypesByFruitTypeCategoryName(fruitTypeCategories, warning)
    local fillTypes = {}
    local alreadyAdded = {}
    local categories = string.split(fruitTypeCategories, " ")
    for _, categoryName in pairs(categories) do
        categoryName = categoryName:upper()
        local category = self.categories[categoryName]
        if category ~= nil then
            for _, fruitTypeIndex in ipairs(self.categoryToFruitTypes[category]) do
                local fillType = self:getFillTypeByFruitTypeIndex(fruitTypeIndex)
                if fillType ~= nil then
                    if alreadyAdded[fillType.index] == nil then
                        table.insert(fillTypes, fillType.index)
                        alreadyAdded[fillType.index] = true
                    end
                end
            end
        else
            if warning ~= nil then
                print(string.format(warning, categoryName))
            end
        end
    end
    return fillTypes
end


---
function FruitTypeManager:isFillTypeWindrow(index)
    if index ~= nil then
        return self.windrowFillTypes[index] == true
    end
    return false
end


---
function FruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(index)
    return self.fruitTypeIndexToWindrowFillTypeIndex[index]
end



---Get fill type liter per sqm
-- @param integer fillType fill type
-- @param float defaultValue default value if fill type not found
-- @return float literPerSqm liter per sqm
function FruitTypeManager:getFillTypeLiterPerSqm(fillType, defaultValue)
    local fruitType = self.fruitTypes[self:getFruitTypeIndexByFillTypeIndex(fillType)]
    if fruitType ~= nil then
        if fruitType.hasWindrow then
            return fruitType.windrowLiterPerSqm
        else
            return fruitType.literPerSqm
        end
    end
    return defaultValue
end


---Adds a new  fruit type converter
-- @param string name name
-- @return integer converterIndex index of converterIndex
function FruitTypeManager:addFruitTypeConverter(name, isBaseType)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is not a valid name for a fruitTypeConverter. Ignoring fruitTypeConverter!")
        return nil
    end

    name = name:upper()

    if isBaseType and self.converterNameToIndex[name] ~= nil then
        print("Warning: FruitTypeConverter '"..tostring(name).."' already exists. Ignoring fruitTypeConverter!")
        return nil
    end

    local index = self.converterNameToIndex[name]
    if index == nil then
        local converter = {}
        table.insert(self.fruitTypeConverters, converter)
        self.converterNameToIndex[name] = #self.fruitTypeConverters
        self.nameToConverter[name] = converter
        index = #self.fruitTypeConverters
    end

    return index
end


---Add fruit type to fill type conversion
-- @param integer converter index of converter
-- @param integer fruitTypeIndex fruit type index
-- @param integer fillTypeIndex fill type index
-- @param float conversionFactor factor of conversion
-- @param float windrowConversionFactor factor of windrow conversion
function FruitTypeManager:addFruitTypeConversion(converter, fruitTypeIndex, fillTypeIndex, conversionFactor, windrowConversionFactor)
    if converter ~= nil and self.fruitTypeConverters[converter] ~= nil and fruitTypeIndex ~= nil and fillTypeIndex ~= nil then
        self.fruitTypeConverters[converter][fruitTypeIndex] = {fillTypeIndex=fillTypeIndex, conversionFactor=conversionFactor, windrowConversionFactor=windrowConversionFactor}
    end
end


---Returns converter data by given name
-- @param string converterName name of converter
-- @return table converterData converter data
function FruitTypeManager:getConverterDataByName(converterName)
    return self.nameToConverter[converterName and converterName:upper()]
end
