---This class handles all fillTypes and fillTypeCategories









































































local FillTypeManager_mt = Class(FillTypeManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function FillTypeManager.new(customMt)
    local self = AbstractManager.new(customMt or FillTypeManager_mt)
    return self
end


---Initialize data structures
function FillTypeManager:initDataStructures()
    self.fillTypes = {}
    self.nameToFillType = {}
    self.indexToFillType = {}
    self.nameToIndex = {}
    self.indexToName = {}
    self.indexToTitle = {}

    self.fillTypeConverters = {}
    self.converterNameToIndex = {}
    self.nameToConverter = {}

    self.categories = {}
    self.nameToCategoryIndex = {}
    self.categoryIndexToFillTypes = {}
    self.categoryNameToFillTypes = {}
    self.fillTypeIndexToCategories = {}

    self.fillTypeSamples = {}
    self.fillTypeToSample = {}

    self.fillTypeTextureDiffuseMap = nil
    self.fillTypeTextureNormalMap = nil
    self.fillTypeTextureSpecularMap = nil

    self.modsToLoad = {}

    FillType = self.nameToIndex
    FillTypeCategory = self.categories
end


---
function FillTypeManager:loadDefaultTypes()
    local xmlFile = loadXMLFile("fillTypes", "data/maps/maps_fillTypes.xml")
    self:loadFillTypes(xmlFile, nil, true, nil)
    delete(xmlFile)
end


---Load data on map load
-- @return boolean true if loading was successful else false
function FillTypeManager:loadMapData(xmlFile, missionInfo, baseDirectory)
    FillTypeManager:superClass().loadMapData(self)

    self:loadDefaultTypes()

    if XMLUtil.loadDataFromMapXML(xmlFile, "fillTypes", baseDirectory, self, self.loadFillTypes, baseDirectory, false, missionInfo.customEnvironment) then
        -- Load additional fill types from mods
        for _, data in ipairs(self.modsToLoad) do
            local fillTypesXmlFile = XMLFile.load("fillTypes", data[1], FillTypeManager.xmlSchema)
            g_fillTypeManager:loadFillTypes(fillTypesXmlFile, data[2], false, data[3])
            fillTypesXmlFile:delete()
        end

        self:constructFillTypeTextureArrays()
        return true
    end

    return false
end






---
function FillTypeManager:unloadMapData()
    for _, sample in pairs(self.fillTypeSamples) do
        g_soundManager:deleteSample(sample.sample)
    end

    self:deleteFillTypeTextureArrays()
    self:deleteDensityMapHeightTextureArrays()

    FillTypeManager:superClass().unloadMapData(self)
end


---Loads fillTypes
-- @param table self target
-- @param table xmlFile xml file handle
-- @param string baseDirectory For sourcing textures and sounds
-- @param boolean isBaseType Is basegame type
-- @param string customEnv Custom environment
-- @return boolean success success
function FillTypeManager:loadFillTypes(xmlFile, baseDirectory, isBaseType, customEnv)
    if type(xmlFile) ~= "table" then
        xmlFile = XMLFile.wrap(xmlFile, FillTypeManager.xmlSchema)
    end

    if isBaseType then
        self:addFillType("UNKNOWN", "Unknown", false, 0, 0, 0, "", baseDirectory, nil, nil, nil, nil, {}, nil, nil, nil, nil, nil, nil, nil, nil, isBaseType)
    end

    xmlFile:iterate("map.fillTypes.fillType", function(_, key)
        local name = xmlFile:getValue(key.."#name")
        local title = xmlFile:getValue(key.."#title")
        local achievementName = xmlFile:getValue(key.."#achievementName")
        local showOnPriceTable = xmlFile:getValue(key.."#showOnPriceTable")
        local fillPlaneColors =  xmlFile:getValue(key.."#fillPlaneColors", "1.0 1.0 1.0", true)
        local unitShort =  xmlFile:getValue(key.."#unitShort", "")

        local kgPerLiter = xmlFile:getValue(key..".physics#massPerLiter")
        local massPerLiter = kgPerLiter and kgPerLiter / 1000
        local maxPhysicalSurfaceAngle = xmlFile:getValue(key..".physics#maxPhysicalSurfaceAngle")

        local hudFilename = xmlFile:getValue(key..".image#hud")

        local palletFilename = xmlFile:getValue(key..".pallet#filename")

        local pricePerLiter = xmlFile:getValue(key..".economy#pricePerLiter")
        local economicCurve = {}

        xmlFile:iterate(key .. ".economy.factors.factor", function(_, factorKey)
            local period = xmlFile:getValue(factorKey .. "#period")
            local factor = xmlFile:getValue(factorKey .. "#value")

            if period ~= nil and factor ~= nil then
                economicCurve[period] = factor
            end
        end)

        local diffuseMapFilename = xmlFile:getValue(key .. ".textures#diffuse")
        local normalMapFilename = xmlFile:getValue(key .. ".textures#normal")
        local specularMapFilename = xmlFile:getValue(key .. ".textures#specular")
        local distanceFilename = xmlFile:getValue(key .. ".textures#distance")

        local prioritizedEffectType = xmlFile:getValue(key..".effects#prioritizedEffectType") or "ShaderPlaneEffect"
        local fillSmokeColor = xmlFile:getValue(key..".effects#fillSmokeColor", nil, true)
        local fruitSmokeColor = xmlFile:getValue(key..".effects#fruitSmokeColor", nil, true)

        self:addFillType(name, title, showOnPriceTable, pricePerLiter, massPerLiter, maxPhysicalSurfaceAngle, hudFilename, baseDirectory, customEnv, fillPlaneColors, unitShort, palletFilename, economicCurve, diffuseMapFilename, normalMapFilename, specularMapFilename, distanceFilename, prioritizedEffectType, fillSmokeColor, fruitSmokeColor, achievementName, isBaseType or false)
    end)

    xmlFile:iterate("map.fillTypeCategories.fillTypeCategory", function(_, key)
        local name = xmlFile:getValue(key.."#name")
        local fillTypesStr = xmlFile:getValue(key) or ""
        local fillTypeCategoryIndex = self:addFillTypeCategory(name, isBaseType)
        if fillTypeCategoryIndex ~= nil then
            local fillTypeNames = fillTypesStr:split(" ")
            for _, fillTypeName in ipairs(fillTypeNames) do
                local fillType = self:getFillTypeByName(fillTypeName)
                if fillType ~= nil then
                    if not self:addFillTypeToCategory(fillType.index, fillTypeCategoryIndex) then
                        Logging.warning("Could not add fillType '"..tostring(fillTypeName).."' to fillTypeCategory '"..tostring(name).."'!")
                    end
                else
                    Logging.warning("Unknown FillType '"..tostring(fillTypeName).."' in fillTypeCategory '"..tostring(name).."'!")
                end
            end
        end
    end)

    xmlFile:iterate("map.fillTypeConverters.fillTypeConverter", function(_, key)
        local name = xmlFile:getValue(key.."#name")
        local converter = self:addFillTypeConverter(name, isBaseType)
        if converter ~= nil then
            xmlFile:iterate(key .. ".converter", function(_, converterKey)
                local from = xmlFile:getValue(converterKey.."#from")
                local to = xmlFile:getValue(converterKey.."#to")
                local factor = xmlFile:getValue(converterKey.."#factor")

                local sourceFillType = g_fillTypeManager:getFillTypeByName(from)
                local targetFillType = g_fillTypeManager:getFillTypeByName(to)

                if sourceFillType ~= nil and targetFillType ~= nil and factor ~= nil then
                    self:addFillTypeConversion(converter, sourceFillType.index, targetFillType.index, factor)
                end
            end)
        end
    end)

    xmlFile:iterate("map.fillTypeSounds.fillTypeSound", function(_, key)
        local sample = g_soundManager:loadSampleFromXML(xmlFile, key, "sound", baseDirectory, getRootNode(), 0, AudioGroup.VEHICLE, nil, nil)
        if sample ~= nil then
            local entry = {}
            entry.sample = sample

            entry.fillTypes = {}
            local fillTypesStr = xmlFile:getValue(key.."#fillTypes") or ""
            if fillTypesStr ~= nil then
                local fillTypeNames = fillTypesStr:split(" ")

                for _, fillTypeName in ipairs(fillTypeNames) do
                    local fillType = self:getFillTypeIndexByName(fillTypeName)
                    if fillType ~= nil then
                        table.insert(entry.fillTypes, fillType)
                        self.fillTypeToSample[fillType] = sample
                    else
                        Logging.warning("Unable to load fill type '%s' for fillTypeSound '%s'", fillTypeName, key)
                    end
                end
            end

            if xmlFile:getValue(key.."#isDefault") then
                for fillType, _ in ipairs(self.fillTypes) do
                    if self.fillTypeToSample[fillType] == nil then
                        self.fillTypeToSample[fillType] = sample
                    end
                end
            end

            table.insert(self.fillTypeSamples, entry)
        end
    end)

    return true
end


---Adds a new fillType
-- @param string name fillType index name
-- @param string title fillType full name
-- @param boolean showOnPriceTable show on price table
-- @param float pricePerLiter price per liter
-- @param float massPerLiter mass per liter
-- @param float maxPhysicalSurfaceAngle max surface angle
-- @param string hudOverlayFilename hud icon
-- @param string hudOverlayFilenameSmall hud icon small
-- @param string customEnv custom environment
-- @param table<int:float> economicCurve List of values with key being period and value being factor. Any missing periods are filled with 1.0.
-- @return table fillType fillType object
function FillTypeManager:addFillType(name, title, showOnPriceTable, pricePerLiter, massPerLiter, maxPhysicalSurfaceAngle, hudOverlayFilename, baseDirectory, customEnv, fillPlaneColors, unitShort, palletFilename, economicCurve, diffuseMapFilename, normalMapFilename, specularMapFilename, distanceFilename, prioritizedEffectType, fillSmokeColor, fruitSmokeColor, achievementName, isBaseType)
    if not ClassUtil.getIsValidIndexName(name) then
        Logging.warning("'%s' is not a valid name for a fillType. Ignoring fillType!", tostring(name))
        return nil
    end

    name = name:upper()

    if isBaseType and self.nameToFillType[name] ~= nil then
        Logging.warning("FillType '%s' already exists. Ignoring fillType!", name)
        return nil
    end

    local fillType = self.nameToFillType[name]
    if fillType == nil then
        local maxNumFillTypes = 2^FillTypeManager.SEND_NUM_BITS-1
        if #self.fillTypes >= maxNumFillTypes then
            Logging.error("FillTypeManager.addFillType too many fill types. Only %d fill types are supported", maxNumFillTypes)
            return
        end

        fillType = {}
        fillType.name = name
        fillType.index = #self.fillTypes + 1
        fillType.title = g_i18n:convertText(title, customEnv)

        if unitShort ~= nil then
            unitShort = g_i18n:convertText(unitShort, customEnv)
        end
        fillType.unitShort = unitShort

        self.nameToFillType[name] = fillType
        self.nameToIndex[name] = fillType.index
        self.indexToName[fillType.index] = name
        self.indexToTitle[fillType.index] = fillType.title
        self.indexToFillType[fillType.index] = fillType
        table.insert(self.fillTypes, fillType)
    end

    fillType.achievementName = achievementName or fillType.achievementName
    fillType.showOnPriceTable = Utils.getNoNil(showOnPriceTable, Utils.getNoNil(fillType.showOnPriceTable, false))
    fillType.pricePerLiter = Utils.getNoNil(pricePerLiter, Utils.getNoNil(fillType.pricePerLiter, 0))
    fillType.massPerLiter = Utils.getNoNil(massPerLiter, Utils.getNoNil(fillType.massPerLiter, 0.0001)) * FillTypeManager.MASS_SCALE
    fillType.maxPhysicalSurfaceAngle = Utils.getNoNilRad(maxPhysicalSurfaceAngle, Utils.getNoNil(fillType.maxPhysicalSurfaceAngle, math.rad(30)))
    fillType.hudOverlayFilename = hudOverlayFilename and Utils.getFilename(hudOverlayFilename, baseDirectory) or fillType.hudOverlayFilename

    if diffuseMapFilename ~= nil then
        fillType.diffuseMapFilename = Utils.getFilename(diffuseMapFilename, baseDirectory) or fillType.diffuseMapFilename
    end
    if normalMapFilename ~= nil then
        fillType.normalMapFilename = Utils.getFilename(normalMapFilename, baseDirectory) or fillType.normalMapFilename
    end
    if specularMapFilename ~= nil then
        fillType.specularMapFilename = Utils.getFilename(specularMapFilename, baseDirectory) or fillType.specularMapFilename
    end
    if distanceFilename ~= nil then
        fillType.distanceFilename = Utils.getFilename(distanceFilename, baseDirectory) or fillType.distanceFilename
    end

    if fillType.index ~= FillType.UNKNOWN then
        if fillType.hudOverlayFilename == nil or fillType.hudOverlayFilename == "" then
            Logging.warning("FillType '%s' has no valid image assigned!", name)
        end
    end

    if palletFilename ~= nil then
        palletFilename = Utils.getFilename(palletFilename, baseDirectory) or fillType.palletFilename
        if fileExists(palletFilename) then
            fillType.palletFilename = palletFilename
        else
            Logging.error("Pallet xml '%s' in fillType '%s' does not exist", palletFilename, fillType.name)
        end
    end
    fillType.previousHourPrice = fillType.pricePerLiter
    fillType.startPricePerLiter = fillType.pricePerLiter
    fillType.totalAmount = 0

    fillType.fillPlaneColors = {}
    if fillPlaneColors ~= nil then
        fillType.fillPlaneColors[1] = fillPlaneColors[1] or fillType.fillPlaneColors[1]
        fillType.fillPlaneColors[2] = fillPlaneColors[2] or fillType.fillPlaneColors[2]
        fillType.fillPlaneColors[3] = fillPlaneColors[3] or fillType.fillPlaneColors[3]
    else
        fillType.fillPlaneColors[1] = fillType.fillPlaneColors[1] or 1.0
        fillType.fillPlaneColors[2] = fillType.fillPlaneColors[2] or 1.0
        fillType.fillPlaneColors[3] = fillType.fillPlaneColors[3] or 1.0
    end

    fillType.economy = fillType.economy or { factors = {}, history = {} }
    for period = Environment.PERIOD.EARLY_SPRING, Environment.PERIOD.LATE_WINTER do
        fillType.economy.factors[period] = economicCurve[period] or fillType.economy.factors[period] or 1.0
        fillType.economy.history[period] = fillType.economy.factors[period] * fillType.pricePerLiter
    end

    fillType.prioritizedEffectType = prioritizedEffectType or fillType.prioritizedEffectType

    if fillSmokeColor ~= nil and #fillSmokeColor == 4 then
        fillType.fillSmokeColor = fillSmokeColor
    end
    if fruitSmokeColor ~= nil and #fruitSmokeColor == 4 then
        fillType.fruitSmokeColor = fruitSmokeColor
    end

    return fillType
end


---Constructs fill types texture array
function FillTypeManager:constructFillTypeTextureArrays()
    self:deleteFillTypeTextureArrays()

    local diffuseMapConstr = TextureArrayConstructor.new()
    local normalMapConstr = TextureArrayConstructor.new()
    local specularMapConstr = TextureArrayConstructor.new()

    self.fillTypeTextureArraySize = 0
    for i=1, #self.fillTypes do
        local fillType = self.fillTypes[i]

        if fillType.diffuseMapFilename ~= nil and fillType.normalMapFilename ~= nil and fillType.specularMapFilename ~= nil then
            diffuseMapConstr:addLayerFilename(fillType.diffuseMapFilename)
            normalMapConstr:addLayerFilename(fillType.normalMapFilename)
            specularMapConstr:addLayerFilename(fillType.specularMapFilename)
            self.fillTypeTextureArraySize = self.fillTypeTextureArraySize + 1

            fillType.textureArrayIndex = self.fillTypeTextureArraySize
        end
    end

    self.fillTypeTextureDiffuseMap = diffuseMapConstr:finalize(true, true, true)
    self.fillTypeTextureNormalMap = normalMapConstr:finalize(true, false, true)
    self.fillTypeTextureSpecularMap = specularMapConstr:finalize(true, false, true)
end


---Returns fill types texture array
-- @return integer fillTypeTextureDiffuseMap id of diffuse map
-- @return integer fillTypeTextureNormalMap id of normal map
-- @return integer fillTypeTextureSpecularMap id of specular map
-- @return integer fillTypeTextureArraySize size of array
function FillTypeManager:getFillTypeTextureArrays()
    return self.fillTypeTextureDiffuseMap, self.fillTypeTextureNormalMap, self.fillTypeTextureSpecularMap, self.fillTypeTextureArraySize
end


---Returns fill types texture array
-- @return integer fillTypeTextureArraySize size of array
function FillTypeManager:getFillTypeTextureArraySize()
    return self.fillTypeTextureArraySize
end


---Assignes fill type array textures to given node id
-- @param integer nodeId node id
-- @param bool diffuse apply diffuse map (default is true)
-- @param bool normal apply normal map (default is true)
-- @param bool specular apply specular map (default is true)
function FillTypeManager:assignFillTypeTextureArrays(nodeId, diffuse, normal, specular)
    local material = getMaterial(nodeId, 0)

    if self.fillTypeTextureDiffuseMap ~= nil and self.fillTypeTextureDiffuseMap ~= 0 and diffuse ~= false then
        material = setMaterialDiffuseMap(material, self.fillTypeTextureDiffuseMap, false)
    end

    if self.fillTypeTextureNormalMap ~= nil and self.fillTypeTextureNormalMap ~= 0 and normal ~= false then
        material = setMaterialNormalMap(material, self.fillTypeTextureNormalMap, false)
    end

    if self.fillTypeTextureSpecularMap ~= nil and self.fillTypeTextureSpecularMap ~= 0 and specular ~= false then
        material = setMaterialGlossMap(material, self.fillTypeTextureSpecularMap, false)
    end

    setMaterial(nodeId, material, 0)
end


---Constructs density map height type array textures to given node id
-- @param table heightTypes table of density height map types
function FillTypeManager:constructDensityMapHeightTextureArrays(heightTypes)
    self:deleteDensityMapHeightTextureArrays()

    local diffuseMapConstr = TextureArrayConstructor.new()
    local normalMapConstr = TextureArrayConstructor.new()
    local specularMapConstr = TextureArrayConstructor.new()

    for i=1, #heightTypes do
        local heightType = heightTypes[i]

        local fillType = self.fillTypes[heightType.fillTypeIndex]
        if fillType ~= nil then
            if fillType.diffuseMapFilename ~= nil and fillType.normalMapFilename ~= nil and fillType.specularMapFilename ~= nil then
                diffuseMapConstr:addLayerFilename(fillType.diffuseMapFilename)
                normalMapConstr:addLayerFilename(fillType.normalMapFilename)
                specularMapConstr:addLayerFilename(fillType.specularMapFilename)
            else
                Logging.error("Failed to create density height map texture array. Fill type '%s' does not have textures defined!", heightType.fillTypeName)
                return false
            end
        end
    end

    self.densityMapHeightDiffuseMap = diffuseMapConstr:finalize(true, true, true)
    self.densityMapHeightNormalMap = normalMapConstr:finalize(true, false, true)
    self.densityMapHeightSpecularMap = specularMapConstr:finalize(true, false, true)
end


---Delete density map height texture arrays
function FillTypeManager:deleteDensityMapHeightTextureArrays()
    if self.densityMapHeightDiffuseMap ~= nil then
        delete(self.densityMapHeightDiffuseMap)
        self.densityMapHeightDiffuseMap = nil
    end

    if self.densityMapHeightNormalMap ~= nil then
        delete(self.densityMapHeightNormalMap)
        self.densityMapHeightNormalMap = nil
    end

    if self.densityMapHeightSpecularMap ~= nil then
        delete(self.densityMapHeightSpecularMap)
        self.densityMapHeightSpecularMap = nil
    end
end


---Assignes density map height type array textures to given node id
-- @param integer nodeId node id
function FillTypeManager:assignDensityMapHeightTextureArrays(nodeId)
    if self.densityMapHeightDiffuseMap ~= nil and self.densityMapHeightNormalMap ~= nil and self.densityMapHeightSpecularMap ~= nil then
        local material = getMaterial(nodeId, 0)
        material = setMaterialDiffuseMap(material, self.densityMapHeightDiffuseMap, false)
        material = setMaterialNormalMap(material, self.densityMapHeightNormalMap, false)
        material = setMaterialGlossMap(material, self.densityMapHeightSpecularMap, false)
        setMaterial(nodeId, material, 0)
    end
end


---Removes fill types texture array
function FillTypeManager:deleteFillTypeTextureArrays()
    if self.fillTypeTextureDiffuseMap ~= nil then
        delete(self.fillTypeTextureDiffuseMap)
        self.fillTypeTextureDiffuseMap = nil
    end

    if self.fillTypeTextureNormalMap ~= nil then
        delete(self.fillTypeTextureNormalMap)
        self.fillTypeTextureNormalMap = nil
    end

    if self.fillTypeTextureSpecularMap ~= nil then
        delete(self.fillTypeTextureSpecularMap)
        self.fillTypeTextureSpecularMap = nil
    end
end


---Constructs fill types texture distance array
-- @param integer terrainDetailHeightId id of terrain detail height node
-- @param integer typeFirstChannel first type channel
-- @param integer typeFirstChannel num type channels
function FillTypeManager:constructFillTypeDistanceTextureArray(terrainDetailHeightId, typeFirstChannel, typeNumChannels, heightTypes)
    local distanceConstr = TerrainDetailDistanceConstructor.new(typeFirstChannel, typeNumChannels)

    for i=1, #heightTypes do
        local heightType = heightTypes[i]

        local fillType = self.fillTypes[heightType.fillTypeIndex]
        if fillType ~= nil then
            if fillType.distanceFilename ~= nil and fillType.distanceFilename:len() > 0 then
                distanceConstr:addTexture(i - 1, fillType.distanceFilename, 3)
            else
                Logging.error("Failed to create density height map distance texture array. Fill type '%s' does not have distance texture defined!", heightType.fillTypeName)
                return false
            end
        end
    end

    distanceConstr:finalize(terrainDetailHeightId)
end


---Returns texture array by fill type index (returns nil if not in texture array)
-- @param integer index the fillType index
-- @return integer textureArrayIndex index in texture array
function FillTypeManager:getTextureArrayIndexByFillTypeIndex(index)
    local fillType = self.fillTypes[index]
    return fillType and fillType.textureArrayIndex
end


---Returns the prioritized effect type by given fill type index
-- @param integer index the fillType index
-- @return string class name of effect type
function FillTypeManager:getPrioritizedEffectTypeByFillTypeIndex(index)
    local fillType = self.fillTypes[index]
    return fillType and fillType.prioritizedEffectType
end


---Returns the smoke color by fill type index
-- @param integer index the fillType index
-- @param bool fruitColor use fruit color of defined
-- @return table color smoke color
function FillTypeManager:getSmokeColorByFillTypeIndex(index, fruitColor)
    local fillType = self.fillTypes[index]
    if fillType ~= nil then
        if not fruitColor then
            return fillType.fillSmokeColor
        else
            return fillType.fruitSmokeColor or fillType.fillSmokeColor
        end
    end

    return nil
end


---Gets a fillType by index
-- @param integer index the fillType index
-- @return table fillType the fillType object
function FillTypeManager:getFillTypeByIndex(index)
    return self.fillTypes[index]
end


---Gets a fillTypeName by index
-- @param integer index the fillType index
-- @return string fillTypeName the fillType name
function FillTypeManager:getFillTypeNameByIndex(index)
    return self.indexToName[index]
end


---Gets a fillType title by index
-- @param integer index the fillType index
-- @return string fillTypeTitle the localized fillType title
function FillTypeManager:getFillTypeTitleByIndex(index)
    return self.indexToTitle[index]
end


---Gets an array of fillType names from an array of fillType indices
-- @param table indices array of fillType indices
-- @return table array of fillType names
function FillTypeManager:getFillTypeNamesByIndices(indices)
    local names = {}
    for fillTypeIndex in pairs(indices) do
        table.insert(names, self.indexToName[fillTypeIndex])
    end
    return names
end



---Gets a fillType index by name
-- @param string name the fillType index name
-- @return integer fillTypeIndex the fillType index
function FillTypeManager:getFillTypeIndexByName(name)
    return self.nameToIndex[name and name:upper()]
end


---Gets a fillType by index name
-- @param string name the fillType index name
-- @return table fillType the fillType object
function FillTypeManager:getFillTypeByName(name)
    if ClassUtil.getIsValidIndexName(name) then
        return self.nameToFillType[name:upper()]
    end
    return nil
end


---Gets a list of fillTypes
-- @return table fillTypes list of fillTypes
function FillTypeManager:getFillTypes()
    return self.fillTypes
end


---Adds a new fillType category
-- @param string name fillType category index name
-- @return table fillTypeCategory fillType category object
function FillTypeManager:addFillTypeCategory(name, isBaseType)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is not a valid name for a fillTypeCategory. Ignoring fillTypeCategory!")
        return nil
    end

    name = name:upper()

    if isBaseType and self.nameToCategoryIndex[name] ~= nil then
        print("Warning: FillTypeCategory '"..tostring(name).."' already exists. Ignoring fillTypeCategory!")
        return nil
    end

    local index = self.nameToCategoryIndex[name]
    if index == nil then
        local categoryFillTypes = {}
        index = #self.categories + 1
        table.insert(self.categories, name)
        self.categoryNameToFillTypes[name] = categoryFillTypes
        self.categoryIndexToFillTypes[index] = categoryFillTypes
        self.nameToCategoryIndex[name] = index
    end

    return index
end


---Add fillType to category
-- @param Integer fillTypeIndex index of fillType
-- @param Integer categoryIndex index of category
-- @return table success true if added else false
function FillTypeManager:addFillTypeToCategory(fillTypeIndex, categoryIndex)
    if categoryIndex ~= nil and fillTypeIndex ~= nil then
        if self.categoryIndexToFillTypes[categoryIndex] ~= nil then
            -- category -> fillType
            self.categoryIndexToFillTypes[categoryIndex][fillTypeIndex] = true

            -- fillType -> categories
            if self.fillTypeIndexToCategories[fillTypeIndex] == nil then
                self.fillTypeIndexToCategories[fillTypeIndex] = {}
            end
            self.fillTypeIndexToCategories[fillTypeIndex][categoryIndex] = true

            return true
        end
    end
    return false
end


---Gets a list of fillTypes of the given category names
-- @param string name fillType category index names
-- @param string warning a warning text shown if a category is not found
-- @return table fillTypes list of fillTypes
function FillTypeManager:getFillTypesByCategoryNames(names, warning, fillTypes)
    fillTypes = fillTypes or {}
    local alreadyAdded = {}
    local categories = string.split(names, " ")
    for _, categoryName in pairs(categories) do
        categoryName = categoryName:upper()
        local categoryFillTypes = self.categoryNameToFillTypes[categoryName]
        if categoryFillTypes ~= nil then
            for fillType, _ in pairs(categoryFillTypes) do
                if alreadyAdded[fillType] == nil then
                    table.insert(fillTypes, fillType)
                    alreadyAdded[fillType] = true
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


---Gets if filltype is part of a category
-- @param string fillTypeIndex fillType index
-- @param string warning warning if fill type not found
-- @return boolean true if fillType is part of category
function FillTypeManager:getIsFillTypeInCategory(fillTypeIndex, categoryName)
    local catgegoy = self.nameToCategoryIndex[categoryName]
    if catgegoy ~= nil and self.fillTypeIndexToCategories[fillTypeIndex] then
        return self.fillTypeIndexToCategories[fillTypeIndex][catgegoy] ~= nil
    end
    return false
end



---Gets list of fillTypes from string with fill type names
-- @param string fillTypes fill types
-- @param string warning warning if fill type not found
-- @return table fillTypes fill types
function FillTypeManager:getFillTypesByNames(names, warning, fillTypes)
    fillTypes = fillTypes or {}
    local alreadyAdded = {}
    local fillTypeNames = string.split(names, " ")
    for _, name in pairs(fillTypeNames) do
        name = name:upper()
        local fillTypeIndex = self.nameToIndex[name]
        if fillTypeIndex ~= nil then
            if fillTypeIndex ~= FillType.UNKNOWN then
                if alreadyAdded[fillTypeIndex] == nil then
                    table.insert(fillTypes, fillTypeIndex)
                    alreadyAdded[fillTypeIndex] = true
                end
            end
        else
            if warning ~= nil then
                print(string.format(warning, name))
            end
        end
    end

    return fillTypes
end


---
function FillTypeManager:getFillTypesFromXML(xmlFile, categoryKey, namesKey, requiresFillTypes)
    local fillTypes = {}
    local fillTypeCategories = xmlFile:getValue(categoryKey)
    local fillTypeNames = xmlFile:getValue(namesKey)
    if fillTypeCategories ~= nil and fillTypeNames == nil then
        fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategories, "Warning: '"..xmlFile:getFilename().. "' has invalid fillTypeCategory '%s'.")
    elseif fillTypeCategories == nil and fillTypeNames ~= nil then
        fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeNames, "Warning: '"..xmlFile:getFilename().. "' has invalid fillType '%s'.")
    elseif fillTypeCategories ~= nil and fillTypeNames ~= nil then
        Logging.xmlWarning(xmlFile, "fillTypeCategories and fillTypeNames are both set, only one of the two allowed")
    elseif requiresFillTypes ~= nil and requiresFillTypes then
        Logging.xmlWarning(xmlFile, "either the '%s' or '%s' attribute has to be set", categoryKey, namesKey)
    end
    return fillTypes
end


---Adds a new  fill type converter
-- @param string name name
-- @return integer converterIndex index of converterIndex
function FillTypeManager:addFillTypeConverter(name, isBaseType)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is not a valid name for a fillTypeConverter. Ignoring fillTypeConverter!")
        return nil
    end

    name = name:upper()

    if isBaseType and self.nameToConverter[name] ~= nil then
        print("Warning: FillTypeConverter '"..tostring(name).."' already exists. Ignoring FillTypeConverter!")
        return nil
    end

    local index = self.converterNameToIndex[name]
    if index == nil then
        local converter = {}
        table.insert(self.fillTypeConverters, converter)
        self.converterNameToIndex[name] = #self.fillTypeConverters
        self.nameToConverter[name] = converter
        index = #self.fillTypeConverters
    end

    return index
end


---Add fill type to fill type conversion
-- @param integer converter index of converter
-- @param integer sourceFillTypeIndex source fill type index
-- @param integer targetFillTypeIndex target fill type index
-- @param float conversionFactor factor of conversion
function FillTypeManager:addFillTypeConversion(converter, sourceFillTypeIndex, targetFillTypeIndex, conversionFactor)
    if converter ~= nil and self.fillTypeConverters[converter] ~= nil and sourceFillTypeIndex ~= nil and targetFillTypeIndex ~= nil then
        self.fillTypeConverters[converter][sourceFillTypeIndex] = {targetFillTypeIndex=targetFillTypeIndex, conversionFactor=conversionFactor}
    end
end


---Returns converter data by given name
-- @param string converterName name of converter
-- @return table converterData converter data
function FillTypeManager:getConverterDataByName(converterName)
    return self.nameToConverter[converterName and converterName:upper()]
end


---Returns sound sample of fill type
-- @param int fillType fill type index
-- @return table sample sample
function FillTypeManager:getSampleByFillType(fillType)
    return self.fillTypeToSample[fillType]
end
