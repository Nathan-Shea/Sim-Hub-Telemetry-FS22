---Util for interacting with store items











---Returns if a store item is a vehicle
-- @param table storeItem a storeitem object
-- @return boolean true if storeitem is a vehicle, else false
function StoreItemUtil.getIsVehicle(storeItem)
    return storeItem ~= nil and (storeItem.species == nil or storeItem.species == "" or storeItem.species == "vehicle")
end


---Returns if a store item is an animal
-- @param table storeItem a storeitem object
-- @return boolean true if storeitem is an animal, else false
function StoreItemUtil.getIsAnimal(storeItem)
    return storeItem ~= nil and storeItem.species ~= nil and storeItem.species ~= "" and storeItem.species ~= "placeable" and storeItem.species ~= "object" and storeItem.species ~= "handTool" and storeItem.species ~= "vehicle"
end


---Returns if a store item is a placeable
-- @param table storeItem a storeitem object
-- @return boolean true if storeitem is a placeable, else false
function StoreItemUtil.getIsPlaceable(storeItem)
    return storeItem ~= nil and storeItem.species == "placeable"
end


---Returns if a store item is an object
-- @param table storeItem a storeitem object
-- @return boolean true if storeitem is an object, else false
function StoreItemUtil.getIsObject(storeItem)
    return storeItem ~= nil and storeItem.species == "object"
end


---Returns if a store item is a handtool
-- @param table storeItem a storeitem object
-- @return boolean true if storeitem is a handtool, else false
function StoreItemUtil.getIsHandTool(storeItem)
    return storeItem ~= nil and storeItem.species == "handTool"
end


---Returns if a store item is configurable.
Checks if there are any configurations and also if any of the configurations has more than just one option.
-- @param table storeItem a storeitem object
-- @return boolean true if storeitem is configurable, else false
function StoreItemUtil.getIsConfigurable(storeItem)
    local hasConfigurations = storeItem ~= nil and storeItem.configurations ~= nil
    local hasMoreThanOneOption = false
    if hasConfigurations then
        for _, configItems in pairs(storeItem.configurations) do
            local selectableItems = 0
            for i=1, #configItems do
                if configItems[i].isSelectable ~= false then
                    selectableItems = selectableItems + 1

                    if selectableItems > 1 then
                        hasMoreThanOneOption = true
                        break
                    end
                end
            end

            if hasMoreThanOneOption then
                break
            end
        end
    end

    return hasConfigurations and hasMoreThanOneOption
end


---Returns if a store item is leaseable
-- @param table storeItem a storeitem object
-- @return boolean true if storeitem is leaseable, else false
function StoreItemUtil.getIsLeasable(storeItem)
    return storeItem ~= nil and storeItem.runningLeasingFactor ~= nil and not StoreItemUtil.getIsPlaceable(storeItem)
end


---Get the default config id
-- @param table storeItem a storeitem object
-- @param string configurationName name of the configuration
-- @return integer configId the default config id
function StoreItemUtil.getDefaultConfigId(storeItem, configurationName)
    return StoreItemUtil.getDefaultConfigIdFromItems(storeItem.configurations[configurationName])
end


---Get the default config id
-- @param table storeItem a storeitem object
-- @param string configurationName name of the configuration
-- @return integer configId the default config id
function StoreItemUtil.getDefaultConfigIdFromItems(configItems)
    if configItems ~= nil then
        for k, item in pairs(configItems) do
            if item.isDefault then
                if item.isSelectable ~= false then
                    return k
                end
            end
        end

        for k, item in pairs(configItems) do
            if item.isSelectable ~= false then
                return k
            end
        end
    end

    return 1
end


---Get the default price
-- @param table storeItem a storeitem object
-- @param table configurations list of configurations
-- @return integer the default price
function StoreItemUtil.getDefaultPrice(storeItem, configurations)
    return StoreItemUtil.getCosts(storeItem, configurations, "price")
end


---Get the daily upkeep
-- @param table storeItem a storeitem object
-- @param table configurations list of configurations
-- @return integer the daily upkeep
function StoreItemUtil.getDailyUpkeep(storeItem, configurations)
    return StoreItemUtil.getCosts(storeItem, configurations, "dailyUpkeep")
end


---Get the costs of storeitem
-- @param table storeItem a storeitem object
-- @param table configurations list of configurations
-- @param string costType the cost type
-- @return integer cost of the storeitem
function StoreItemUtil.getCosts(storeItem, configurations, costType)
    if storeItem ~= nil then
        local costs = storeItem[costType]
        if costs == nil then
            costs = 0
        end
        if storeItem.configurations ~= nil then
            for name, value in pairs(configurations) do
                local nameConfig = storeItem.configurations[name]
                if nameConfig ~= nil then
                    local valueConfig = nameConfig[value]
                    if valueConfig ~= nil then
                        local costTypeConfig = valueConfig[costType]
                        if costTypeConfig ~= nil then
                            costs = costs + tonumber(costTypeConfig)
                        end
                    end
                end
            end
        end
        return costs
    end
    return 0
end



































---Adds a '(index)' at the back of the name if it's duplicated
-- @param table configurationItems a list of configurationItems
-- @param table configItem config item table
-- @return table config object
function StoreItemUtil.renameDuplicatedConfigurationNames(configurationItems, configItem)
    local name = configItem.name
    if name ~= nil then
        local duplicateFound = true
        local nameIndex = 2
        while duplicateFound do
            duplicateFound = false
            for i=1, #configurationItems do
                if configurationItems[i] ~= configItem then
                    if configurationItems[i].name == name then
                        local ignore = false
                        for j=1, #configItem.nameCompareParams do
                            if configurationItems[i][configItem.nameCompareParams[j]] ~= configItem[configItem.nameCompareParams[j]] then
                                ignore = true
                            end
                        end

                        if not ignore then
                            duplicateFound = true
                        end
                    end
                end
            end

            if duplicateFound then
                name = string.format("%s (%d)", configItem.name, nameIndex)
                nameIndex = nameIndex + 1
            end
        end

        configItem.name = name
    end
end


---Adds a configuration item to the given list
-- @param table configurationItems a list of configurationItems
-- @param string name name of the configuration
-- @param string desc desc of the configuration
-- @param float price price of the configuration
-- @param integer dailyUpkeep dailyUpkeep of the configuration
-- @return table config object
function StoreItemUtil.addConfigurationItem(configurationItems, name, desc, price, dailyUpkeep, isDefault, overwrittenTitle, saveId, brandIndex, isSelectable, vehicleBrand, vehicleName, vehicleIcon)
    local configItem = {}
    configItem.name = name
    configItem.desc = desc
    configItem.price = price
    configItem.dailyUpkeep = dailyUpkeep
    configItem.isDefault = isDefault
    configItem.isSelectable = isSelectable
    configItem.overwrittenTitle = overwrittenTitle
    table.insert(configurationItems, configItem)
    configItem.index = #configurationItems
    configItem.saveId = saveId or tostring(configItem.index)
    configItem.brandIndex = brandIndex
    configItem.nameCompareParams = {}

    configItem.vehicleBrand = vehicleBrand
    configItem.vehicleName = vehicleName
    configItem.vehicleIcon = vehicleIcon

    return configItem
end


---Gets the storeitem functions from xml
-- @param integer xmlFile the xml handle
-- @param string storeDataXMLName name of the parent xml element
-- @param string customEnvironment a custom environment
-- @return table functions list of storeitem functions
function StoreItemUtil.getFunctionsFromXML(xmlFile, storeDataXMLName, customEnvironment)
    local i=0
    local functions = {}
    while true do
        local functionKey = string.format(storeDataXMLName..".functions.function(%d)", i)
         if not xmlFile:hasProperty(functionKey) then
            break
        end
        local functionName = xmlFile:getValue(functionKey, nil, customEnvironment, true)
        if functionName ~= nil then
            table.insert(functions, functionName)
        end
        i = i + 1
    end
    return functions
end


---Loads the storeitem specs values from xml into the item
is only run if specs were not loaded before already
function StoreItemUtil.loadSpecsFromXML(item)
    if item.specs == nil then
        local storeItemXmlFile = XMLFile.load("storeItemXML", item.xmlFilename, item.xmlSchema)
        item.specs = StoreItemUtil.getSpecsFromXML(g_storeManager:getSpecTypes(), item.species, storeItemXmlFile, item.customEnvironment, item.baseDir)
        storeItemXmlFile:delete()
    end

    if item.bundleInfo ~= nil then
        local bundleItems = item.bundleInfo.bundleItems
        for i=1, #bundleItems do
            StoreItemUtil.loadSpecsFromXML(bundleItems[i].item)
        end
    end
end


---Gets the storeitem specs from xml
-- @param table specTypes list of spec types
-- @param integer xmlFile the xml handle
-- @param string customEnvironment a custom environment
-- @return table specs list of storeitem specs
function StoreItemUtil.getSpecsFromXML(specTypes, species, xmlFile, customEnvironment, baseDirectory)
    local specs = {}
    for _, specType in pairs(specTypes) do
        if specType.species == species then
            if specType.loadFunc ~= nil then
                specs[specType.name] = specType.loadFunc(xmlFile, customEnvironment, baseDirectory)
            end
        end
    end
    return specs
end


---Gets the storeitem brand index from xml
-- @param integer xmlFile the xml handle
-- @param string storeDataXMLKey path of the parent xml element
-- @return integer brandIndex the brandindex
function StoreItemUtil.getBrandIndexFromXML(xmlFile, storeDataXMLKey)
    local brandName = xmlFile:getValue(storeDataXMLKey..".brand", "")
    return g_brandManager:getBrandIndexByName(brandName)
end


---Gets the storeitem vram usage from xml
-- @param integer xmlFile the xml handle
-- @param string storeDataXMLName name of the parent xml element
-- @return integer sharedVramUsage the shared vram usage
-- @return integer perInstanceVramUsage the per instance vram usage
-- @return boolean ignoreVramUsage true if vram usage should be ignored else false
function StoreItemUtil.getVRamUsageFromXML(xmlFile, storeDataXMLName)
    local vertexBufferMemoryUsage = xmlFile:getValue(storeDataXMLName..".vertexBufferMemoryUsage", 0)
    local indexBufferMemoryUsage = xmlFile:getValue(storeDataXMLName..".indexBufferMemoryUsage", 0)
    local textureMemoryUsage = xmlFile:getValue(storeDataXMLName..".textureMemoryUsage", 0)
    local instanceVertexBufferMemoryUsage = xmlFile:getValue(storeDataXMLName..".instanceVertexBufferMemoryUsage", 0)
    local instanceIndexBufferMemoryUsage = xmlFile:getValue(storeDataXMLName..".instanceIndexBufferMemoryUsage", 0)
    local ignoreVramUsage = xmlFile:getValue(storeDataXMLName..".ignoreVramUsage", false)

    local perInstanceVramUsage = instanceVertexBufferMemoryUsage + instanceIndexBufferMemoryUsage
    local sharedVramUsage = vertexBufferMemoryUsage + indexBufferMemoryUsage + textureMemoryUsage

    return sharedVramUsage, perInstanceVramUsage, ignoreVramUsage
end


---Gets the storeitem configurations from xml
-- @param integer xmlFile the xml handle
-- @param string key the name of the base xml element
-- @param string baseDir the base directory
-- @param string customEnvironment a custom environment
-- @param boolean isMod true if the storeitem is a mod, else false
-- @return table configurations a list of configurations
function StoreItemUtil.getConfigurationsFromXML(xmlFile, key, baseDir, customEnvironment, isMod, storeItem)

    local configurations = {}
    local defaultConfigurationIds = {}
    local numConfigs = 0
    -- try to load default configuration values (title (shown in shop), name, desc, price) - additional parameters can be loaded with loadFunc
    local configurationTypes = g_configurationManager:getSortedConfigurationTypes()
    for _, name in pairs(configurationTypes) do
        local configuration = g_configurationManager:getConfigurationDescByName(name)
        local configurationItems = {}
        local i = 0
        local xmlKey = configuration.xmlKey
        if xmlKey ~= nil then
            xmlKey = "."..xmlKey
        else
            xmlKey = ""
        end
        local baseKey = key..xmlKey.."."..name.."Configurations"

        if configuration.preLoadFunc ~= nil then
            configuration.preLoadFunc(xmlFile, baseKey, baseDir, customEnvironment, isMod, configurationItems)
        end

        local overwrittenTitle = xmlFile:getValue(baseKey.."#title", nil, customEnvironment, false)

        local loadedSaveIds = {}

        while true do
            if i > 2 ^ ConfigurationUtil.SEND_NUM_BITS then
                Logging.xmlWarning(xmlFile, "Maximum number of configurations are reached for %s. Only %d configurations per type are allowed!", name, 2 ^ ConfigurationUtil.SEND_NUM_BITS)
            end
            local configKey = string.format(baseKey.."."..name.."Configuration(%d)", i)
            if not xmlFile:hasProperty(configKey) then
                break
            end

            local configName = ConfigurationUtil.loadConfigurationNameFromXML(xmlFile, configKey, customEnvironment)

            local desc = xmlFile:getValue(configKey.."#desc", nil, customEnvironment, false)
            local price = xmlFile:getValue(configKey.."#price", 0)
            local dailyUpkeep = xmlFile:getValue(configKey.."#dailyUpkeep", 0)
            local isDefault = xmlFile:getValue(configKey.."#isDefault", false)
            local isSelectable = xmlFile:getValue(configKey.."#isSelectable", true)
            local saveId = xmlFile:getValue(configKey.."#saveId")

            local vehicleBrandName = xmlFile:getValue(configKey.."#vehicleBrand")
            local vehicleBrand = g_brandManager:getBrandIndexByName(vehicleBrandName)

            local vehicleName = xmlFile:getValue(configKey.."#vehicleName")
            local vehicleIcon = xmlFile:getValue(configKey.."#vehicleIcon")
            if vehicleIcon ~= nil then
                vehicleIcon = Utils.getFilename(vehicleIcon, baseDir)
            end

            local brandName = xmlFile:getValue(configKey.."#displayBrand")
            local brandIndex = g_brandManager:getBrandIndexByName(brandName)

            local configItem = StoreItemUtil.addConfigurationItem(configurationItems, configName, desc, price, dailyUpkeep, isDefault, overwrittenTitle, saveId, brandIndex, isSelectable, vehicleBrand, vehicleName, vehicleIcon)

            if saveId ~= nil then
                if loadedSaveIds[saveId] == true then
                    Logging.xmlWarning(xmlFile, "Duplicated saveId '%s' in '%s' configurations", saveId, name)
                else
                    loadedSaveIds[saveId] = true
                end
            end

            if configuration.singleItemLoadFunc ~= nil then
                configuration.singleItemLoadFunc(xmlFile, configKey, baseDir, customEnvironment, isMod, configItem)
            end

            StoreItemUtil.renameDuplicatedConfigurationNames(configurationItems, configItem)

            i = i + 1
        end

        if configuration.postLoadFunc ~= nil then
            configuration.postLoadFunc(xmlFile, baseKey, baseDir, customEnvironment, isMod, configurationItems, storeItem)
        end

        if #configurationItems > 0 then
            defaultConfigurationIds[name] = StoreItemUtil.getDefaultConfigIdFromItems(configurationItems)

            configurations[name] = configurationItems
            numConfigs = numConfigs + 1
        end
    end
    if numConfigs == 0 then
        configurations = nil
        defaultConfigurationIds = nil
    end

    return configurations, defaultConfigurationIds
end


---Gets predefined configuration sets
-- @param table storeItem a storeItem
-- @param integer xmlFile the xml handle
-- @param string key the key of the base xml element
-- @param string baseDir the base directory
-- @param string customEnvironment a custom environment
-- @param boolean isMod true if the storeitem is a mod, else false
-- @return table configuration sets
function StoreItemUtil.getConfigurationSetsFromXML(storeItem, xmlFile, key, baseDir, customEnvironment, isMod)
    local configurationSetsKey = string.format("%s.configurationSets", key)
    local overwrittenTitle = xmlFile:getValue(configurationSetsKey.."#title", nil, customEnvironment, false)

    local configurationsSets = {}
    local i = 0
    while true do
        local key = string.format("%s.configurationSet(%d)", configurationSetsKey, i)
        if not xmlFile:hasProperty(key) then
            break
        end

        local configSet = {}
        configSet.name = xmlFile:getValue(key.."#name", nil, customEnvironment, false)

        local params = xmlFile:getValue(key.."#params")
        if params ~= nil then
            params = params:split("|")
            for j=1, #params do
                params[j] = g_i18n:convertText(params[j], customEnvironment)
            end

            configSet.name = string.format(configSet.name, unpack(params))
        end

        configSet.isDefault = xmlFile:getValue(key.."#isDefault", false)

        configSet.overwrittenTitle = overwrittenTitle
        configSet.configurations = {}

        local j = 0
        while true do
            local configKey = string.format("%s.configuration(%d)", key, j)
            if not xmlFile:hasProperty(configKey) then
                break
            end

            local name = xmlFile:getValue(configKey.."#name")
            if name ~= nil then
                if storeItem.configurations[name] ~= nil then
                    local index = xmlFile:getValue(configKey.."#index")
                    if index ~= nil then
                        if storeItem.configurations[name][index] ~= nil then
                            configSet.configurations[name] = index
                        else
                            Logging.xmlWarning(xmlFile, "Index '"..index.."' not defined for configuration '"..name.."'!")
                        end
                    end
                else
                    Logging.xmlWarning(xmlFile, "Configuration name '"..name.."' is not defined!")
                end
            else
                Logging.xmlWarning(xmlFile, "Missing name for configuration set item '"..key.."'!")
            end

            j = j + 1
        end

        table.insert(configurationsSets, configSet)

        i = i + 1
    end

    return configurationsSets
end


---
function StoreItemUtil.getSubConfigurationsFromXML(configurations)
    local subConfigurations = nil

    if configurations ~= nil then
        subConfigurations = {}

        for name, items in pairs(configurations) do
            local config = g_configurationManager:getConfigurationDescByName(name)
            if config.hasSubselection then
                local subConfigValues = config.getSubConfigurationValuesFunc(items)
                if #subConfigValues > 1 then
                    local subConfigItemMapping = {}
                    subConfigurations[name] = {subConfigValues=subConfigValues, subConfigItemMapping=subConfigItemMapping}

                    for k, value in ipairs(subConfigValues) do
                        subConfigItemMapping[value] = config.getItemsBySubConfigurationIdentifierFunc(items, value)
                    end
                end
            end
        end
    end

    return subConfigurations
end


---
function StoreItemUtil.getSubConfigurationIndex(storeItem, configName, configIndex)
    local subConfigurations = storeItem.subConfigurations[configName]
    local subConfigValues = subConfigurations.subConfigValues

    for k, identifier in ipairs(subConfigValues) do
        local items = subConfigurations.subConfigItemMapping[identifier]
        for _, item in ipairs(items) do
            if item.index == configIndex then
                return k
            end
        end
    end

    return nil
end


---
function StoreItemUtil.getFilteredConfigurationIndex(storeItem, configName, configIndex)
    local subConfigurations = storeItem.subConfigurations[configName]
    if subConfigurations ~= nil then
        local subConfigValues = subConfigurations.subConfigValues
        for _, identifier in ipairs(subConfigValues) do
            local items = subConfigurations.subConfigItemMapping[identifier]
            for k, item in ipairs(items) do
                if item.index == configIndex then
                    return k
                end
            end
        end
    end

    return configIndex
end


---
function StoreItemUtil.getSubConfigurationItems(storeItem, configName, state)
    local subConfigurations = storeItem.subConfigurations[configName]
    local subConfigValues = subConfigurations.subConfigValues
    local identifier = subConfigValues[state]
    return subConfigurations.subConfigItemMapping[identifier]
end


---
function StoreItemUtil.getConfigurationsMatchConfigSets(configurations, configSets)
    for _, configSet in pairs(configSets) do
        local isMatch = true
        for configName, index in pairs(configSet.configurations) do
            if configurations[configName] ~= index then
                isMatch = false
                break
            end
        end

        if isMatch then
            return true
        end
    end

    return false
end


---
function StoreItemUtil.getClosestConfigurationSet(configurations, configSets)
    local closestSet = nil
    local closestSetMatches = 0
    for _, configSet in pairs(configSets) do
        local numMatches = 0
        for configName, index in pairs(configSet.configurations) do
            if configurations[configName] == index then
                numMatches = numMatches + 1
            end
        end
        if numMatches > closestSetMatches then
            closestSet = configSet
            closestSetMatches = numMatches
        end
    end

    return closestSet, closestSetMatches
end


---
function StoreItemUtil.getSizeValues(xmlFilename, baseName, rotationOffset, configurations)
    local xmlFile = XMLFile.load("storeItemGetSizeXml", xmlFilename, Vehicle.xmlSchema)
    local size = {
        width = Vehicle.defaultWidth,
        length = Vehicle.defaultLength,
        height = Vehicle.defaultHeight,
        widthOffset = 0,
        lengthOffset = 0,
        heightOffset = 0
    }
    if xmlFile ~= nil then
        size = StoreItemUtil.getSizeValuesFromXML(xmlFile, baseName, rotationOffset, configurations)
        xmlFile:delete()
    end

    return size
end


---
function StoreItemUtil.getSizeValuesFromXML(xmlFile, baseName, rotationOffset, configurations)
    return StoreItemUtil.getSizeValuesFromXMLByKey(xmlFile, baseName, "base", "size", "size", rotationOffset, configurations, Vehicle.DEFAULT_SIZE)
end


---
function StoreItemUtil.getSizeValuesFromXMLByKey(xmlFile, baseName, baseKey, elementKey, configKey, rotationOffset, configurations, defaults)
    local baseSizeKey = string.format("%s.%s.%s", baseName, baseKey, elementKey)

    local size = {
        width = xmlFile:getValue(baseSizeKey .. "#width", defaults.width),
        length = xmlFile:getValue(baseSizeKey .. "#length", defaults.length),
        height = xmlFile:getValue(baseSizeKey .. "#height", defaults.height),
        widthOffset = xmlFile:getValue(baseSizeKey .. "#widthOffset", defaults.widthOffset),
        lengthOffset = xmlFile:getValue(baseSizeKey .. "#lengthOffset", defaults.lengthOffset),
        heightOffset = xmlFile:getValue(baseSizeKey .. "#heightOffset", defaults.heightOffset)
    }

    -- check configurations for changed size values
    if configurations ~= nil then
        for name, id in pairs(configurations) do
            local specializationKey = g_configurationManager:getConfigurationAttribute(name, "xmlKey")
            if specializationKey ~= nil then
                specializationKey = "." .. specializationKey
            else
                specializationKey = ""
            end
            local key = string.format("%s%s.%sConfigurations.%sConfiguration(%d).%s", baseName, specializationKey, name, name , id - 1, configKey)
            local tempWidth = xmlFile:getValue(key .. "#width")
            local tempLength = xmlFile:getValue(key .. "#length")
            local tempHeight = xmlFile:getValue(key .. "#height")
            local tempWidthOffset = xmlFile:getValue(key .. "#widthOffset")
            local tempLengthOffset = xmlFile:getValue(key .. "#lengthOffset")
            local tempHeightOffset = xmlFile:getValue(key .. "#heightOffset")

            if tempWidth ~= nil then
                size.width = math.max(size.width, tempWidth)
            end
            if tempLength ~= nil then
                size.length = math.max(size.length, tempLength)
            end
            if tempHeight ~= nil then
                size.height = math.max(size.height, tempHeight)
            end

            if tempWidthOffset ~= nil then
                if size.widthOffset < 0 then
                    size.widthOffset = math.min(size.widthOffset, tempWidthOffset)
                else
                    size.widthOffset = math.max(size.widthOffset, tempWidthOffset)
                end
            end
            if tempLengthOffset ~= nil then
                if size.lengthOffset < 0 then
                    size.lengthOffset = math.min(size.lengthOffset, tempLengthOffset)
                else
                    size.lengthOffset = math.max(size.lengthOffset, tempLengthOffset)
                end
            end
            if tempHeightOffset ~= nil then
                if size.heightOffset < 0 then
                    size.heightOffset = math.min(size.heightOffset, tempHeightOffset)
                else
                    size.heightOffset = math.max(size.heightOffset, tempHeightOffset)
                end
            end
        end
    end

    -- limit rotation to 90 deg steps
    rotationOffset = math.floor(rotationOffset / math.rad(90) + 0.5) * math.rad(90)
    rotationOffset = rotationOffset % (2*math.pi)
    if rotationOffset < 0 then
        rotationOffset = rotationOffset + 2*math.pi
    end
    -- switch/invert width/length if rotated
    local rotationIndex = math.floor(rotationOffset / math.rad(90) + 0.5)
    if rotationIndex == 1 then -- 90 deg
        size.width, size.length = size.length, size.width
        size.widthOffset,size.lengthOffset = size.lengthOffset, -size.widthOffset
    elseif rotationIndex == 2 then
        size.widthOffset, size.lengthOffset = -size.widthOffset, -size.lengthOffset
    elseif rotationIndex == 3 then -- 270 def
        size.width, size.length = size.length, size.width
        size.widthOffset, size.lengthOffset = -size.lengthOffset, size.widthOffset
    end

    return size
end



---Register configuration set paths
function StoreItemUtil.registerConfigurationSetXMLPaths(schema, baseKey)
    baseKey = baseKey .. ".configurationSets"
    schema:register(XMLValueType.L10N_STRING, baseKey .. "#title", "Title to display in config screen")

    local setKey = baseKey .. ".configurationSet(?)"
    schema:register(XMLValueType.L10N_STRING, setKey .. "#name", "Set name")
    schema:register(XMLValueType.STRING, setKey .. "#params", "Parameters to insert into name")
    schema:register(XMLValueType.BOOL, setKey .. "#isDefault", "Is default set")
    schema:register(XMLValueType.STRING, setKey .. ".configuration(?)#name", "Configuration name")
    schema:register(XMLValueType.INT, setKey .. ".configuration(?)#index", "Selected index")
end
