---Vehicle configuration util class















---Add bought configuration
-- @param string name of bought configuration type
-- @param Integer id id of bought configuration
function ConfigurationUtil.addBoughtConfiguration(object, name, id)
    if g_configurationManager:getConfigurationIndexByName(name) ~= nil then
        if object.boughtConfigurations[name] == nil then
            object.boughtConfigurations[name] = {}
        end
        object.boughtConfigurations[name][id] = true
    end
end


---Returns true if configuration has been bought
-- @param string name of bought configuration type
-- @param Integer id id of bought configuration
-- @return boolean configurationHasBeenBought configuration has been bought
function ConfigurationUtil.hasBoughtConfiguration(object, name, id)
    if object.boughtConfigurations[name] ~= nil and object.boughtConfigurations[name][id] then
        return true
    end
    return false
end


---Set configuration value
-- @param string name name of configuration type
-- @param Integer id id of configuration value
function ConfigurationUtil.setConfiguration(object, name, id)
    object.configurations[name] = id
end



---Returns color of config id
-- @param string configName name if config
-- @param Integer configId id of config to get color
-- @return table color color and material(r, g, b, mat)
function ConfigurationUtil.getColorByConfigId(object, configName, configId)
    if configId ~= nil then
        local item = g_storeManager:getItemByXMLFilename(object.configFileName)
        if item.configurations ~= nil then
            local config = item.configurations[configName][configId]
            if config ~= nil then
                local r, g, b = unpack(config.color)
                return {r, g, b, config.material}
            end
        end
    end

    return nil
end


---Returns save identifier from given config id
-- @param table object object
-- @param string configName name if config
-- @param Integer configId id of config to get color
-- @return string saveId save identifier
function ConfigurationUtil.getSaveIdByConfigId(configFileName, configName, configId)
    local item = g_storeManager:getItemByXMLFilename(configFileName)
    if item.configurations ~= nil then
        local configs = item.configurations[configName]
        if configs ~= nil then
            local config = configs[configId]
            if config ~= nil then
                return config.saveId
            end
        end
    end

    return nil
end


---Returns config id from given save identifier
-- @param table object object
-- @param string configName name if config
-- @param string saveId save identifier
-- @return integer configId config id
function ConfigurationUtil.getConfigIdBySaveId(configFileName, configName, configId)
    local item = g_storeManager:getItemByXMLFilename(configFileName)
    if item.configurations ~= nil then
        local configs = item.configurations[configName]
        if configs ~= nil then
            for j=1, #configs do
                if configs[j].saveId == configId then
                    return configs[j].index
                end
            end
        end
    end

    return 1
end


---Returns material of config id
-- @param string configName name if config
-- @param Integer configId id of config to get color
-- @return integer material material
function ConfigurationUtil.getMaterialByConfigId(object, configName, configId)
    if configId ~= nil then
        local item = g_storeManager:getItemByXMLFilename(object.configFileName)
        if item.configurations ~= nil then
            local config = item.configurations[configName][configId]
            if config ~= nil then
                return config.material
            end
        end
    end

    return nil
end


---Apply materials defined in the given config
-- @param table object object (vehicle)
-- @param table xmlFile xml file object
-- @param string configName name of config
-- @param integer configId id of config to apply
function ConfigurationUtil.applyConfigMaterials(object, xmlFile, configName, configId)
    local configuration = g_configurationManager:getConfigurationDescByName(configName)
    local xmlKey = configuration.xmlKey
    if xmlKey ~= nil then
        xmlKey = "."..xmlKey
    else
        xmlKey = ""
    end

    local configKey = string.format("vehicle%s.%sConfigurations.%sConfiguration(%d)", xmlKey, configName, configName, configId-1)
    if xmlFile:hasProperty(configKey) then
        xmlFile:iterate(configKey .. ".material", function(_, key)
            local baseMaterialNode = xmlFile:getValue(key.."#node", nil, object.components, object.i3dMappings)
            local refMaterialNode = xmlFile:getValue(key.."#refNode", nil, object.components, object.i3dMappings)
            if baseMaterialNode ~= nil and refMaterialNode ~= nil then
                local oldMaterial = getMaterial(baseMaterialNode, 0)
                local newMaterial = getMaterial(refMaterialNode, 0)
                for _, component in pairs(object.components) do
                    ConfigurationUtil.replaceMaterialRec(object, component.node, oldMaterial, newMaterial)
                end
            end

            local materialName = xmlFile:getValue(key .. "#name")
            if materialName ~= nil then
                local shaderParameterName = xmlFile:getValue(key .. "#shaderParameter")
                if shaderParameterName ~= nil then
                    local color = xmlFile:getValue(key.."#color", nil, true)
                    if color ~= nil then
                        local materialId = xmlFile:getValue(key.."#materialId")
                        if object.setBaseMaterialColor ~= nil then
                            object:setBaseMaterialColor(materialName, shaderParameterName, color, materialId)
                        end
                    end
                end
            end
        end)
    end
end


---Searches in all configurations for defined materials with the given search name and returns the color and material
-- @param table object object (vehicle)
-- @param table xmlFile xml file object
-- @param table targetTable target table with names as indices
-- @return table color color
-- @return integer materialId material id
function ConfigurationUtil.getOverwrittenMaterialColors(object, xmlFile, targetTable)
    for configName, configId in pairs(object.configurations) do
        local configuration = g_configurationManager:getConfigurationDescByName(configName)
        local xmlKey = configuration.xmlKey
        if xmlKey ~= nil then
            xmlKey = "."..xmlKey
        else
            xmlKey = ""
        end

        local configKey = string.format("vehicle%s.%sConfigurations.%sConfiguration(%d)", xmlKey, configName, configName, configId-1)
        if xmlFile:hasProperty(configKey) then
            xmlFile:iterate(configKey .. ".material", function(_, key)
                local materialName = xmlFile:getValue(key .. "#name")
                if materialName ~= nil then
                    for name, _ in pairs(targetTable) do
                        if materialName == name then
                            local color = xmlFile:getValue(key.."#color", nil, true)
                            if color ~= nil and #color > 0 then
                                local materialId = xmlFile:getValue(key.."#materialId")

                                targetTable[name][1] = color[1]
                                targetTable[name][2] = color[2]
                                targetTable[name][3] = color[3]
                                targetTable[name][4] = materialId
                            end
                        end
                    end
                end
            end)
        end
    end
end


---Replace material of node
-- @param Integer node id of node
-- @param Integer oldMaterial id of old material
-- @param Integer newMaterial id of new material
function ConfigurationUtil.replaceMaterialRec(object, node, oldMaterial, newMaterial)
    if getHasClassId(node, ClassIds.SHAPE) then
        local nodeMaterial = getMaterial(node, 0)
        if nodeMaterial == oldMaterial then
            setMaterial(node, newMaterial, 0)
        end
    end

    local numChildren = getNumOfChildren(node)
    if numChildren > 0 then
        for i=0, numChildren-1 do
            ConfigurationUtil.replaceMaterialRec(object, getChildAt(node, i), oldMaterial, newMaterial)
        end
    end
end


---Sets color of vehicle
-- @param integer xmlFile id of xml object
-- @param string configName name of config
-- @param Integer configColorId id of config color to use
function ConfigurationUtil.setColor(object, xmlFile, configName, configColorId)
    local color = ConfigurationUtil.getColorByConfigId(object, configName, configColorId)
    if color ~= nil then
        local r,g,b,mat = unpack(color)
        local i = 0
        while true do
            local colorKey = string.format("vehicle.%sConfigurations.colorNode(%d)", configName, i)
            if not xmlFile:hasProperty(colorKey) then
                break
            end

            local node = xmlFile:getValue(colorKey .. "#node", nil, object.components, object.i3dMappings)
            if node ~= nil then
                if getHasClassId(node, ClassIds.SHAPE) then
                    if mat == nil then
                        _,_,_,mat = getShaderParameter(node, "colorScale")
                    end
                    if xmlFile:getValue(colorKey .. "#recursive", false) then
                        I3DUtil.setShaderParameterRec(node, "colorScale", r, g, b, mat)
                    else
                        setShaderParameter(node, "colorScale", r, g, b, mat, false)
                    end
                else
                    print("Warning: Could not set vehicle color to '"..getName(node).."' because node is not a shape!")
                end
            end
            i = i + 1
        end
    end
end


---Get value of configuration
-- @param integer xmlFile id of xml object
-- @param string key key
-- @param string subKey sub key
-- @param string param parameter
-- @param any_type defaultValue default value
-- @param string fallbackConfigKey fallback config key
-- @param string fallbackOldgKey fallback old key
-- @return any_type value value of config
function ConfigurationUtil.getConfigurationValue(xmlFile, key, subKey, param, defaultValue, fallbackConfigKey, fallbackOldKey)
    if type(subKey) == "table" then
        printCallstack()
    end
    local value = nil
    if key ~= nil then
        value = xmlFile:getValue(key..subKey..param)
    end

    if value == nil and fallbackConfigKey ~= nil then
        value = xmlFile:getValue(fallbackConfigKey..subKey..param) -- Check for default configuration (xml index 0)
    end
    if value == nil and fallbackOldKey ~= nil then
        value = xmlFile:getValue(fallbackOldKey..subKey..param) -- Fallback to old xml setup
    end
    return Utils.getNoNil(value, defaultValue) -- using default value
end


---Get xml configuration key
-- @param integer xmlFile id of xml object
-- @param Integer index index
-- @param string key key
-- @param string defaultKey default key
-- @param string configurationKey configuration key
-- @return string configKey key of configuration
-- @return Integer configIndex index of configuration
function ConfigurationUtil.getXMLConfigurationKey(xmlFile, index, key, defaultKey, configurationKey)
    local configIndex = Utils.getNoNil(index, 1)
    local configKey = string.format(key.."(%d)", configIndex-1)
    if index ~= nil and not xmlFile:hasProperty(configKey) then
        print("Warning: Invalid "..configurationKey.." index '"..tostring(index).."' in '"..key.."'. Using default "..configurationKey.." settings instead!")
    end

    if not xmlFile:hasProperty(configKey) then
        configKey = key.."(0)"
    end
    if not xmlFile:hasProperty(configKey) then
        configKey = defaultKey
    end

    return configKey, configIndex
end


---Get config color single item load
-- @param integer xmlFile id of xml object
-- @param string baseXMLName base xml name
-- @param string baseDir base directory
-- @param string customEnvironment custom environment
-- @param boolean isMod is mod
-- @param table configItem config item
function ConfigurationUtil.getConfigColorSingleItemLoad(xmlFile, baseXMLName, baseDir, customEnvironment, isMod, configItem)
    configItem.color = xmlFile:getValue(baseXMLName.."#color", "1 1 1", true)
    configItem.uiColor = xmlFile:getValue(baseXMLName.."#uiColor", configItem.color, true)
    configItem.material = xmlFile:getValue(baseXMLName.."#material")

    configItem.name = ConfigurationUtil.loadConfigurationNameFromXML(xmlFile, baseXMLName, customEnvironment)
end


---Get config color post load
-- @param integer xmlFile id of xml object
-- @param string baseKey base key
-- @param string baseDir base directory
-- @param string customEnvironment custom environment
-- @param boolean isMod is mod
-- @param table configurationItems config items
function ConfigurationUtil.getConfigColorPostLoad(xmlFile, baseKey, baseDir, customEnvironment, isMod, configurationItems, storeItem)
    local defaultColorIndex = xmlFile:getValue(baseKey.."#defaultColorIndex")

    if xmlFile:getValue(baseKey.."#useDefaultColors", false) then
        local price = xmlFile:getValue(baseKey.."#price", 1000)

        for i, color in pairs(g_vehicleColors) do
            local configItem = StoreItemUtil.addConfigurationItem(configurationItems, "", "", price, 0, false)
            if color.r ~= nil and color.g ~= nil and color.b ~= nil then
                configItem.color = {color.r, color.g, color.b, 1}
            elseif color.brandColor ~= nil then
                configItem.color = g_brandColorManager:getBrandColorByName(color.brandColor)

                if configItem.color == nil then
                    configItem.color = {1, 1, 1, 1}
                    Logging.warning("Unable to find brandColor '%s' in g_vehicleColors", color.brandColor)
                end
            end

            configItem.name = g_i18n:convertText(color.name)

            if i == defaultColorIndex then
                configItem.isDefault = true
                configItem.price = 0
            end
        end
    end

    if defaultColorIndex == nil then
        local defaultIsDefined = false
        for _, item in ipairs(configurationItems) do
            if item.isDefault ~= nil and item.isDefault then
                defaultIsDefined = true
            end
        end

        if not defaultIsDefined then
            if #configurationItems > 0 then
                configurationItems[1].isDefault = true
                configurationItems[1].price = 0
            end
        end
    end
end



---
function ConfigurationUtil.getConfigMaterialSingleItemLoad(xmlFile, baseXMLName, baseDir, customEnvironment, isMod, configItem)
    configItem.color = xmlFile:getValue(baseXMLName.."#color", "1 1 1", true)
    configItem.material = xmlFile:getValue(baseXMLName.."#material")
end


---Get store additional config data
-- @param integer xmlFile id of xml object
-- @param string baseXMLName base xml name
-- @param string baseDir base directory
-- @param string customEnvironment custom environment
-- @param boolean isMod is mod
-- @param table configItem config item
function ConfigurationUtil.getStoreAdditionalConfigData(xmlFile, baseXMLName, baseDir, customEnvironment, isMod, configItem)
    configItem.vehicleType = xmlFile:getValue(baseXMLName.."#vehicleType")
end


---Get color from string
-- @param string colorString color rgba string or brand color identifier
-- @return table color color (r, g, b)
function ConfigurationUtil.getColorFromString(colorString)
    if colorString ~= nil then
        local colorVector = g_brandColorManager:getBrandColorByName(colorString) or {colorString:getVector()}

        if colorVector == nil or #colorVector < 3 or #colorVector > 4 then
            print("Error: Invalid color string '" .. colorString .. "'")
            return nil
        end
        return colorVector
    end
    return nil
end


---Returns formatted config name that is loaded from xml
-- @param integer xmlFile id of xml object
-- @param string configKey configuration key
-- @param string customEnvironment custom environment
-- @return string configName config name
function ConfigurationUtil.loadConfigurationNameFromXML(xmlFile, configKey, customEnvironment)
    local configName = xmlFile:getValue(configKey.."#name", nil, customEnvironment, false)
    local params = xmlFile:getValue(configKey.."#params")
    if params ~= nil then
        params = params:split("|")
        for i=1, #params do
            params[i] = g_i18n:convertText(params[i])
        end
        configName = string.format(configName, unpack(params))
    end

    return configName
end


---Register color configuration paths
function ConfigurationUtil.registerColorConfigurationXMLPaths(schema, configurationName)
    local baseKey = string.format("vehicle.%sConfigurations", configurationName)
    schema:register(XMLValueType.INT, baseKey .. "#defaultColorIndex", "Default color index on start")
    schema:register(XMLValueType.BOOL, baseKey .. "#useDefaultColors", "Use default colors", false)
    schema:register(XMLValueType.INT, baseKey .. "#price", "Default color price", 1000)

    schema:register(XMLValueType.NODE_INDEX, baseKey .. ".colorNode(?)#node", "Color node")
    schema:register(XMLValueType.BOOL, baseKey .. ".colorNode(?)#recursive", "Apply recursively")

    local itemKey = string.format("%s.%sConfiguration(?)", baseKey, configurationName)
    schema:register(XMLValueType.COLOR, itemKey .. "#color", "Configuration color", "1 1 1 1")
    schema:register(XMLValueType.COLOR, itemKey .. "#uiColor", "Configuration UI color", "1 1 1 1")
    schema:register(XMLValueType.INT, itemKey .. "#material", "Configuration material")
    schema:register(XMLValueType.L10N_STRING, itemKey .. "#name", "Color name")
end


---Register material configuration paths
function ConfigurationUtil.registerMaterialConfigurationXMLPaths(schema, configurationName)
    schema:register(XMLValueType.NODE_INDEX, configurationName .. ".material(?)#node", "Material node")
    schema:register(XMLValueType.NODE_INDEX, configurationName .. ".material(?)#refNode", "Material reference node")

    schema:register(XMLValueType.STRING, configurationName .. ".material(?)#name", "Material name")
    schema:register(XMLValueType.STRING, configurationName .. ".material(?)#shaderParameter", "Material shader parameter name")
    schema:register(XMLValueType.COLOR, configurationName .. ".material(?)#color", "Color")
    schema:register(XMLValueType.INT, configurationName .. ".material(?)#materialId", "Material id")
end


---Get whether a material is visualized as metallic in UI
function ConfigurationUtil.isColorMetallic(materialId)
    return materialId == 2
        or materialId == 3
        or materialId == 19
        or materialId == 30
        or materialId == 31
        or materialId == 35
end
