---This class handles all store categories and items









local StoreManager_mt = Class(StoreManager, AbstractManager)











---Creating manager
-- @return table instance instance of object
function StoreManager.new(customMt)
    local self = AbstractManager.new(customMt or StoreManager_mt)

    return self
end


---Initialize data structures
function StoreManager:initDataStructures()
    self.numOfCategories = 0
    self.numOfPacks = 0
    self.categories = {}
    self.packs = {}
    self.items = {}
    self.xmlFilenameToItem = {}
    self.modStoreItems = {}
    self.modStorePacks = {}

    self.specTypes = {}
    self.nameToSpecType = {}

    self.vramUsageFunctions = {}

    self.constructionCategoriesByName = {}
    self.constructionCategories = {}
end


---Load manager data on map load
-- @return boolean true if loading was successful else false
function StoreManager:loadMapData(xmlFile, missionInfo, baseDirectory)
    StoreManager:superClass().loadMapData(self)

    -- local all store categories
    local categoryXMLFile = XMLFile.load("storeCategoriesXML", "dataS/storeCategories.xml")
    categoryXMLFile:iterate("categories.category", function(_, key)
        self:loadCategoryFromXML(categoryXMLFile, key, "")
    end)
    categoryXMLFile:delete()

    -- load store pack definitions
    local packsXMLFile = XMLFile.load("storePacksXML", "dataS/storePacks.xml")
    packsXMLFile:iterate("storePacks.storePack", function(_, key)
        local name = packsXMLFile:getString(key .. "#name")
        local title = packsXMLFile:getString(key .. "#title")
        local imageFilename = packsXMLFile:getString(key .. "#image")

        if title ~= nil and title:sub(1, 6) == "$l10n_" then
            title = g_i18n:getText(title:sub(7))
        end

        self:addPack(name, title, imageFilename, "")
    end)
    packsXMLFile:delete()

    -- also for mods
    for _, item in ipairs(self.modStorePacks) do
        self:addPack(item.name, item.title, item.imageFilename, item.baseDir)
    end

    -- Load categories for the construction system
    local constructionXMLFile = XMLFile.load("constructionXML", "dataS/constructionCategories.xml")
    if constructionXMLFile ~= nil then
        local defaultIconFilename = constructionXMLFile:getString("constructionCategories#defaultIconFilename")
        local defaultRefSize = constructionXMLFile:getVector("constructionCategories#refSize", {1024, 1024}, 2)

        constructionXMLFile:iterate("constructionCategories.category", function(_, key)
            local categoryName = constructionXMLFile:getString(key .. "#name")
            local title = g_i18n:convertText(constructionXMLFile:getString(key .. "#title"))
            local iconFilename = constructionXMLFile:getString(key .. "#iconFilename") or defaultIconFilename
            local refSize = constructionXMLFile:getVector(key .. "#refSize", defaultRefSize, 2)
            local iconUVs = GuiUtils.getUVs(constructionXMLFile:getString(key .. "#iconUVs", "0 0 1 1"), refSize)

            self:addConstructionCategory(categoryName, title, iconFilename, iconUVs, "")

            constructionXMLFile:iterate(key .. ".tab", function(_, tKey)
                local tabName = constructionXMLFile:getString(tKey .. "#name")
                local tabTitle = g_i18n:convertText(constructionXMLFile:getString(tKey .. "#title"))
                local tabIconFilename = constructionXMLFile:getString(tKey .. "#iconFilename") or defaultIconFilename
                local tabRefSize = constructionXMLFile:getVector(tKey .. "#refSize", defaultRefSize, 2)
                local tabIconUVs = GuiUtils.getUVs(constructionXMLFile:getString(tKey .. "#iconUVs", "0 0 1 1"), tabRefSize)

                self:addConstructionTab(categoryName, tabName, tabTitle, tabIconFilename, tabIconUVs, "")
            end)
        end)
        constructionXMLFile:delete()
    end

    -- now load all storeitems

    local storeItemsFilename = self:getDefaultStoreItemsFilename()
    self:loadItemsFromXML(storeItemsFilename, "", nil)

    if xmlFile ~= nil then
        local mapStoreItemsFilename = getXMLString(xmlFile, "map.storeItems#filename")
        if mapStoreItemsFilename ~= nil then
            mapStoreItemsFilename = Utils.getFilename(mapStoreItemsFilename, baseDirectory)
            self:loadItemsFromXML(mapStoreItemsFilename, baseDirectory, missionInfo.customEnvironment)
        end
    end

    for _, item in ipairs(self.modStoreItems) do
        g_asyncTaskManager:addSubtask(function()
            self:loadItem(item.xmlFilename, item.baseDir, item.customEnvironment, item.isMod, item.isBundleItem, item.dlcTitle, item.extraContentId)
        end)
    end

    addConsoleCommand("gsStoreItemsReload", "Reloads storeItem data", "consoleCommandReloadStoreItems", self)

    return true
end


---Unload data on mission delete
function StoreManager:unloadMapData()
    StoreManager:superClass().unloadMapData(self)

    removeConsoleCommand("gsStoreItemsReload")
end






---
function StoreManager:loadItemsFromXML(filename, baseDirectory, customEnvironment)
    local xmlFile = XMLFile.load("storeItemsXML", filename)

    xmlFile:iterate("storeItems.storeItem", function(_, key)
        local xmlFilename = xmlFile:getString(key.."#xmlFilename")
        local extraContentId = xmlFile:getString(key.."#extraContentId")
        g_asyncTaskManager:addSubtask(function()
            local isMod = false
            local dlcTitle = ""

            local absFilename = Utils.getFilename(xmlFilename, baseDirectory)
            local modName, _ = Utils.getModNameAndBaseDirectory(absFilename)
            if modName ~= nil then
                local modItem = g_modManager:getModByName(modName)
                if modItem ~= nil then
                    dlcTitle = modItem.title
                end
                isMod = not modItem.isDLC
            end

            self:loadItem(xmlFilename, baseDirectory, customEnvironment, isMod, false, dlcTitle, extraContentId)
        end)
    end)

    xmlFile:delete()
end






---Load shop category from XML file
-- @param table xmlFile xml file object
-- @param string key key
-- @param string baseDir base directory
function StoreManager:loadCategoryFromXML(xmlFile, key, baseDir, customEnv)
    local name = xmlFile:getString(key .. "#name")
    local title = xmlFile:getString(key .. "#title")
    local imageFilename = xmlFile:getString(key .. "#image")
    local type = xmlFile:getString(key .. "#type")
    local orderId = xmlFile:getInt(key .. "#orderId")

    if title ~= nil and title:sub(1, 6) == "$l10n_" then
        title = g_i18n:getText(title:sub(7), customEnv)
    end

    self:addCategory(name, title, imageFilename, type, baseDir, orderId)
end


---Adds a new store category
-- @param string name category index name
-- @param string title category title
-- @param string imageFilename image
-- @param string baseDir base directory
-- @return boolean true if adding was successful else false
function StoreManager:addCategory(name, title, imageFilename, type, baseDir, orderId)
    if name == nil or name == "" then
        print("Warning: Could not register store category. Name is missing or empty!")
        return false
    end
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is no valid name for a category!")
        return false
    end
    if title == nil or title == "" then
        print("Warning: Could not register store category. Title is missing or empty!")
        return false
    end
    if imageFilename == nil or imageFilename == "" then
        print("Warning: Could not register store category. Image is missing or empty!")
        return false
    end
    if baseDir == nil then
        print("Warning: Could not register store category. Basedirectory not defined!")
        return false
    end

    name = name:upper()

    if GS_PLATFORM_SWITCH and name == "COINS" then
        return false
    end

    if self.categories[name] == nil then
        self.numOfCategories = self.numOfCategories + 1

        self.categories[name] = {
            name = name,
            title = title,
            image = Utils.getFilename(imageFilename, baseDir),
            type = StoreManager.CATEGORY_TYPE[type] ~= nil and type or StoreManager.CATEGORY_TYPE.NONE,
            orderId = orderId or self.numOfCategories
        }

        return true
    end

    return false
end


---Removes a store category
-- @param string name category index name
function StoreManager:removeCategory(name)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is no valid name for a category!")
        return
    end

    name = name:upper()

    for _, item in pairs(self.items) do
        if item.category == name then
            item.category = "MISC"
        end
    end
    self.categories[name] = nil
end


---Gets a store category by name
-- @param string name category index name
-- @return table category the category object
function StoreManager:getCategoryByName(name)
    if name ~= nil then
        return self.categories[name:upper()]
    end
    return nil
end






---Add a new construction category.
function StoreManager:addConstructionCategory(name, title, iconFilename, iconUVs, baseDir)
    name = name:upper()

    if self.constructionCategoriesByName[name] ~= nil then
        Logging.warning("Construction category '%s' already exists.", name)
        return
    end

    local category = {
        name = name,
        title = title,
        iconFilename = Utils.getFilename(iconFilename, baseDir),
        iconUVs = iconUVs,
        tabs = {},
        index = #self.constructionCategories + 1
    }

    table.insert(self.constructionCategories, category)
    self.constructionCategoriesByName[name] = category
end


---Get construction category by name
function StoreManager:getConstructionCategoryByName(name)
    if name ~= nil then
        return self.constructionCategoriesByName[name:upper()]
    end
    return nil
end


---Add a new construction tab
function StoreManager:addConstructionTab(categoryName, name, title, iconFilename, iconUVs, baseDir)
    local category = self:getConstructionCategoryByName(categoryName)
    if category == nil then
        return
    end

    table.insert(category.tabs, {
        name = name:upper(),
        title = title,
        iconFilename = Utils.getFilename(iconFilename, baseDir),
        iconUVs = iconUVs,
        index = #category.tabs + 1
    })
end


---Get a construction tab using its name and category name
function StoreManager:getConstructionTabByName(name, categoryName)
    local category = self:getConstructionCategoryByName(categoryName)
    if category == nil or name == nil then
        return nil
    end

    name = name:upper()

    for i, tab in ipairs(category.tabs) do
        if tab.name == name then
            return tab
        end
    end

    return nil
end


---Get categories for construction screen
function StoreManager:getConstructionCategories()
    return self.constructionCategories
end










---Adds a new spec type
-- @param string name spec type index name
-- @param string profile spec type gui profile
-- @param function loadFunc the loading function pointer
-- @param function getValueFunc the get value function pointer
function StoreManager:addSpecType(name, profile, loadFunc, getValueFunc, species, relatedConfigurations, configDataFunc)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is no valid name for a spec type!")
        return
    end

    name = name

    if self.nameToSpecType == nil then
        printCallstack()
    end

    if self.nameToSpecType[name] ~= nil then
        print("Error: spec type name '" ..name.. "' is already in use!")
        return
    end

    local specType = {}
    specType.name = name
    specType.profile = profile
    specType.loadFunc = loadFunc
    specType.getValueFunc = getValueFunc
    specType.species = species or "vehicle"
    specType.relatedConfigurations = relatedConfigurations or {}
    specType.configDataFunc = configDataFunc

    self.nameToSpecType[name] = specType
    table.insert(self.specTypes, specType)
end


---Gets all spec types
-- @return table specTypes a list of spec types
function StoreManager:getSpecTypes()
   return self.specTypes
end


---Gets a spec type by name
-- @param string name spec type index name
-- @return table specType the corresponding spectype
function StoreManager:getSpecTypeByName(name)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is no valid name for a spec type!")
        return
    end

    return self.nameToSpecType[name]
end






---Adds a new store item
-- @param table storeItem the storeitem object
-- @return boolean wasSuccessfull true if added else false
function StoreManager:addItem(storeItem)
    local otherItem = self.xmlFilenameToItem[storeItem.xmlFilenameLower]
    if otherItem ~= nil then
        -- in case we have added a item already as bundle item, but then afterwards want to add it as regular item as well
        -- so we copy isBundleItem and showInStore from the regular item
        if otherItem.isBundleItem and not storeItem.isBundleItem then
            otherItem.isBundleItem = storeItem.isBundleItem
            otherItem.showInStore = storeItem.showInStore
        end

       return false
    end

    table.insert(self.items, storeItem)
    storeItem.id = #self.items
    self.xmlFilenameToItem[storeItem.xmlFilenameLower] = storeItem
    return true
end


---Removes a storeitem by index
-- @param integer index storeitem index
function StoreManager:removeItemByIndex(index)
    local item = self.items[index]
    if item ~= nil then
        self.xmlFilenameToItem[item.xmlFilenameLower] = nil

        -- item.id must always match the index in the arry, thus swap the last to the removed position and reduce size
        local numItems = table.getn(self.items)
        if index < numItems then
            self.items[index] = self.items[numItems]
            self.items[index].id = index
        end
        table.remove(self.items, numItems)
    end
end


---Gets all storeitems
-- @return table items a list of all store items
function StoreManager:getItems()
    return self.items
end


---Gets a store item by index
-- @param integer index store item index
-- @return table storeItem the storeitem oject
function StoreManager:getItemByIndex(index)
    if index ~= nil then
        return self.items[index]
    end
    return nil
end


---Gets a store item xml filename
-- @param string xmlFilename storeitem xml filename
-- @return table storeItem the storeitem object
function StoreManager:getItemByXMLFilename(xmlFilename)
    if xmlFilename ~= nil then
        return self.xmlFilenameToItem[xmlFilename:lower()]
    end
end


---Returns if store item is unlocked
-- @param table storeItem the storeitem oject
-- @return boolean isUnlocked is unlocked
function StoreManager:getIsItemUnlocked(storeItem)
    if storeItem ~= nil and (storeItem.extraContentId == nil or g_extraContentSystem:getIsItemIdUnlocked(storeItem.extraContentId)) then
        return true
    end

    return false
end


---Returns store items that match the given combination data
-- @param table combinationData combination data
-- @return table storeItems table with store items
function StoreManager:getItemsByCombinationData(combinationData)
    local items = {}
    if combinationData.xmlFilename ~= nil then
        local storeItem = self.xmlFilenameToItem[combinationData.customXMLFilename:lower()]
        if storeItem == nil then
            storeItem = self.xmlFilenameToItem[combinationData.xmlFilename:lower()]
            if storeItem == nil then
                Logging.warning("Could not find combination vehicle '%s'", combinationData.xmlFilename)
            end
        end

        if self:getIsItemUnlocked(storeItem) then
            table.insert(items, {storeItem=storeItem})
        end
    else
        for _, storeItem in ipairs(self.items) do
            if self:getIsItemUnlocked(storeItem) then
                local categoryAllowed = true
                if combinationData.filterCategories ~= nil then
                    categoryAllowed = false
                    for j=1, #combinationData.filterCategories do
                        if combinationData.filterCategories[j]:upper() == storeItem.categoryName then
                            categoryAllowed = true
                            break
                        end
                    end
                end

                if categoryAllowed then
                    if combinationData.filterSpec == nil then
                        table.insert(items, {storeItem=storeItem})
                    else
                        local desc = self:getSpecTypeByName(combinationData.filterSpec)
                        if desc ~= nil then
                            if desc.species == storeItem.species then
                                StoreItemUtil.loadSpecsFromXML(storeItem)

                                local value, maxValue = desc.getValueFunc(storeItem, nil, nil, nil, true, true)
                                if value ~= nil then
                                    local specMin = combinationData.filterSpecMin
                                    local specMax = combinationData.filterSpecMax
                                    -- special case weight -> in the xml we defined it as kg, but in code we handle it always as tons
                                    if combinationData.filterSpec == "weight" then
                                        specMin = specMin / 1000
                                        specMax = specMax / 1000
                                    end

                                    if value >= specMin and value <= specMax then
                                        table.insert(items, {storeItem=storeItem})
                                    else
                                        if desc.configDataFunc ~= nil then
                                            local configDatas = desc.configDataFunc(storeItem)
                                            if configDatas ~= nil then
                                                for i=1, #configDatas do
                                                    local configData = configDatas[i]
                                                    if configData.value >= specMin and configData.value <= specMax then
                                                        table.insert(items, {storeItem=storeItem, configData={[configData.name] = configData.index}})
                                                    end
                                                end
                                            end
                                        else
                                            if #desc.relatedConfigurations > 0 and storeItem.configurations ~= nil then
                                                for i=1, #desc.relatedConfigurations do
                                                    local configurationName = desc.relatedConfigurations[i]
                                                    if storeItem.configurations[configurationName] ~= nil then
                                                        local configItems = storeItem.configurations[configurationName]
                                                        for configIndex=1, #configItems do
                                                            local configData = {[configurationName] = configIndex}
                                                            value = desc.getValueFunc(storeItem, nil, configData, nil, true, true)
                                                            if value >= specMin and value <= specMax then
                                                                table.insert(items, {storeItem=storeItem, configData=configData})
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return items
end


---Gets a store item xml filename
-- @param string xmlFilename storeitem xml filename
-- @return table storeItem the storeitem object
function StoreManager:getItemByCustomEnvironment(customEnvironment)
    local items = {}
    for _, item in ipairs(self.items) do
        if item.customEnvironment == customEnvironment then
            table.insert(items, item)
        end
    end

    return items
end


---
function StoreManager:addModStoreItem(xmlFilename, baseDir, customEnvironment, isMod, isBundleItem, dlcTitle)
    table.insert(self.modStoreItems, {xmlFilename=xmlFilename, baseDir=baseDir, customEnvironment=customEnvironment, isMod=isMod, isBundleItem=isBundleItem, dlcTitle=dlcTitle})
end


---Loads a storeitem from xml file
-- @param string xmlFilename the storeitem xml filename
-- @param string baseDir the base directory
-- @param string customEnvironment a custom environment
-- @param boolean isMod true if item is a mod, else false
-- @param boolean isBundleItem true if item is bundleItem, else false
-- @param string dlcTitle optional dlc title
-- @return table storeItem the storeitem object
function StoreManager:loadItem(rawXMLFilename, baseDir, customEnvironment, isMod, isBundleItem, dlcTitle, extraContentId, ignoreAdd)
    local xmlFilename = Utils.getFilename(rawXMLFilename, baseDir)
    local xmlFile = loadXMLFile("storeItemXML", xmlFilename)
    if xmlFile == 0 then
        return nil
    end

    local baseXMLName = getXMLRootName(xmlFile)
    local storeDataXMLKey = baseXMLName..".storeData"

    -- just load the species the old way to categorize the file
    local species = getXMLString(xmlFile, storeDataXMLKey..".species") or "vehicle"
    local xmlSchema
    if species == "vehicle" then
        xmlSchema = Vehicle.xmlSchema
    elseif species == "handTool" then
        xmlSchema = HandTool.xmlSchema
    elseif species == "placeable" then
        xmlSchema = Placeable.xmlSchema
    end

    if xmlSchema ~= nil then
        delete(xmlFile)
        xmlFile = XMLFile.load("storeManagerLoadItemXml", xmlFilename, xmlSchema)
    else
        Logging.xmlError(xmlFile, "Unable to get xml schema for species '%s' in '%s'", species, xmlFilename)
        return nil
    end

    -- check if file name matches naming convention
    local xmlName = Utils.getFilenameInfo(xmlFilename, true)
    if xmlName:sub(1, 1) ~= xmlName:sub(1, 1):lower() then
        Logging.xmlDevWarning(xmlFile, "Filename is starting with upper case character. Please follow the lower camel case naming convention.")
    end
    if tonumber(xmlName:sub(1, 1)) ~= nil then
        Logging.xmlDevWarning(xmlFile, "Filename is starting with a number. Please start always with a character.")
    end
    local xmlPathPaths = xmlFilename:split("/")
    local numParts = #xmlPathPaths
    if numParts >= 4 then
        if xmlPathPaths[numParts-3] == "vehicles" then
            if string.startsWith(xmlPathPaths[numParts]:lower(), xmlPathPaths[numParts-2]:lower()) then
                Logging.xmlDevWarning(xmlFile, "Vehicle filename '%s' starts with brand name '%s'.", xmlName, xmlPathPaths[numParts-2])
            end
        end
    end

    if not xmlFile:hasProperty(storeDataXMLKey) then
        Logging.xmlError(xmlFile, "No storeData found. StoreItem will be ignored!")
        xmlFile:delete()
        return nil
    end

    local isValid = true
    local name = xmlFile:getValue(storeDataXMLKey..".name", nil, customEnvironment, true)
    if name == nil then
        Logging.xmlWarning(xmlFile, "Name missing for storeitem. Ignoring store item!")
        isValid = false
    end

    if name ~= nil then
        local params = xmlFile:getValue(storeDataXMLKey..".name#params")
        if params ~= nil then
            params = params:split("|")

            for i=1, #params do
                params[i] = g_i18n:convertText(params[i], customEnvironment)
            end

            name = string.format(name, unpack(params))
        end
    end

    local imageFilename = xmlFile:getValue(storeDataXMLKey..".image", "")
    if imageFilename == "" then
        imageFilename = nil
    end
    if imageFilename == nil and xmlFile:getValue(storeDataXMLKey..".showInStore", true) then
        Logging.xmlWarning(xmlFile, "Image icon is missing for storeitem. Ignoring store item!")
        isValid = false
    end

    if not isValid then
        xmlFile:delete()
        return nil
    end

    local storeItem = {}
    storeItem.name = name
    storeItem.extraContentId = extraContentId
    storeItem.rawXMLFilename = rawXMLFilename
    storeItem.baseDir = baseDir
    storeItem.xmlSchema = xmlSchema
    storeItem.xmlFilename = xmlFilename
    storeItem.xmlFilenameLower = xmlFilename:lower()
    storeItem.imageFilename = imageFilename and Utils.getFilename(imageFilename, baseDir)
    storeItem.species = species
    storeItem.functions = StoreItemUtil.getFunctionsFromXML(xmlFile, storeDataXMLKey, customEnvironment)
    storeItem.specs = nil
    storeItem.brandIndex = StoreItemUtil.getBrandIndexFromXML(xmlFile, storeDataXMLKey)
    storeItem.brandNameRaw = xmlFile:getValue(storeDataXMLKey..".brand", "")
    storeItem.customBrandIcon = xmlFile:getValue(storeDataXMLKey..".brand#customIcon")
    storeItem.customBrandIconOffset = xmlFile:getValue(storeDataXMLKey..".brand#imageOffset")
    if storeItem.customBrandIcon ~= nil then
        storeItem.customBrandIcon = Utils.getFilename(storeItem.customBrandIcon, baseDir)
    end
    storeItem.canBeSold = xmlFile:getValue(storeDataXMLKey..".canBeSold", true)
    storeItem.showInStore = xmlFile:getValue(storeDataXMLKey..".showInStore", not isBundleItem)
    storeItem.isBundleItem = isBundleItem
    storeItem.allowLeasing = xmlFile:getValue(storeDataXMLKey..".allowLeasing", true)
    storeItem.maxItemCount = xmlFile:getValue(storeDataXMLKey..".maxItemCount")
    storeItem.rotation = xmlFile:getValue(storeDataXMLKey..".rotation", 0)
    storeItem.shopDynamicTitle = xmlFile:getValue(storeDataXMLKey..".shopDynamicTitle", false)
    storeItem.shopTranslationOffset = xmlFile:getValue(storeDataXMLKey..".shopTranslationOffset", nil, true)
    storeItem.shopRotationOffset = xmlFile:getValue(storeDataXMLKey..".shopRotationOffset", nil, true)
    storeItem.shopIgnoreLastComponentPositions = xmlFile:getValue(storeDataXMLKey..".shopIgnoreLastComponentPositions", false)
    storeItem.shopInitialLoadingDelay = xmlFile:getValue(storeDataXMLKey..".shopLoadingDelay#initial")
    storeItem.shopConfigLoadingDelay = xmlFile:getValue(storeDataXMLKey..".shopLoadingDelay#config")
    storeItem.shopHeight = xmlFile:getValue(storeDataXMLKey..".shopHeight", 0)
    storeItem.financeCategory = xmlFile:getValue(storeDataXMLKey..".financeCategory")
    storeItem.shopFoldingState = xmlFile:getValue(storeDataXMLKey..".shopFoldingState", 0)
    storeItem.shopFoldingTime = xmlFile:getValue(storeDataXMLKey..".shopFoldingTime")

    local sharedVramUsage, perInstanceVramUsage, ignoreVramUsage = StoreItemUtil.getVRamUsageFromXML(xmlFile, storeDataXMLKey)
    for _, func in ipairs(self.vramUsageFunctions) do
        local customSharedVramUsage, customPerInstanceVramUsage = func(xmlFile)

        sharedVramUsage = sharedVramUsage + customSharedVramUsage
        perInstanceVramUsage = perInstanceVramUsage + customPerInstanceVramUsage
    end

    storeItem.sharedVramUsage, storeItem.perInstanceVramUsage, storeItem.ignoreVramUsage = sharedVramUsage, perInstanceVramUsage, ignoreVramUsage

    storeItem.dlcTitle = dlcTitle
    storeItem.isMod = isMod
    storeItem.customEnvironment = customEnvironment

    local categoryName = xmlFile:getValue(storeDataXMLKey..".category")
    local category = self:getCategoryByName(categoryName)
    if category == nil then
        Logging.xmlWarning(xmlFile, "Invalid category '%s' in store data! Using 'misc' instead!", tostring(categoryName))
        category = self:getCategoryByName("misc")
    end
    storeItem.categoryName = category.name

    if species == "vehicle" then
        storeItem.configurations, storeItem.defaultConfigurationIds = StoreItemUtil.getConfigurationsFromXML(xmlFile, baseXMLName, baseDir, customEnvironment, isMod, storeItem)
        storeItem.subConfigurations = StoreItemUtil.getSubConfigurationsFromXML(storeItem.configurations)
        storeItem.configurationSets = StoreItemUtil.getConfigurationSetsFromXML(storeItem, xmlFile, baseXMLName, baseDir, customEnvironment, isMod)

        storeItem.hasLicensePlates = xmlFile:hasProperty("vehicle.licensePlates.licensePlate(0)")
    end
    storeItem.price = xmlFile:getValue(storeDataXMLKey..".price", 0)
    if storeItem.price < 0 then
        Logging.xmlWarning(xmlFile, "Price has to be greater than 0. Using default 10.000 instead!")
        storeItem.price = 10000
    end
    storeItem.dailyUpkeep = xmlFile:getValue(storeDataXMLKey..".dailyUpkeep", 0)
    storeItem.runningLeasingFactor = xmlFile:getValue(storeDataXMLKey..".runningLeasingFactor", EconomyManager.DEFAULT_RUNNING_LEASING_FACTOR)
    storeItem.lifetime = xmlFile:getValue(storeDataXMLKey..".lifetime", 600)

    xmlFile:iterate("handTool.storeData.storePacks.storePack", function(_, key)
        local packName = xmlFile:getValue(key)
        self:addPackItem(packName, xmlFilename)
    end)

    xmlFile:iterate("vehicle.storeData.storePacks.storePack", function(_, key)
        local packName = xmlFile:getValue(key)
        self:addPackItem(packName, xmlFilename)
    end)

    local bundleItemsToAdd = {}
    if xmlFile:hasProperty(storeDataXMLKey..".bundleElements") then
        local bundleInfo = {bundleItems={}, attacherInfo={}}
        local price = 0
        local lifetime = math.huge
        local dailyUpkeep = 0
        local runningLeasingFactor = 0
        local i = 0
        while true do
            local bundleKey = string.format(storeDataXMLKey..".bundleElements.bundleElement(%d)", i)
            if not xmlFile:hasProperty(bundleKey) then
                break
            end
            local bundleXmlFile = xmlFile:getValue(bundleKey..".xmlFilename")
            local offset = xmlFile:getValue(bundleKey..".offset", "0 0 0", true)
            local rotationOffset = xmlFile:getValue(bundleKey..".rotationOffset", "0 0 0", true)
            local rotation = xmlFile:getValue(bundleKey..".yRotation", 0)
            rotationOffset[2] = rotationOffset[2] + rotation
            if bundleXmlFile ~= nil then
                local completePath = Utils.getFilename(bundleXmlFile, baseDir)
                local item = self:getItemByXMLFilename(completePath)
                if item == nil then
                    item = self:loadItem(bundleXmlFile, baseDir, customEnvironment, isMod, true, dlcTitle, nil, true)
                    table.insert(bundleItemsToAdd, item)
                end
                if item ~= nil then
                    price = price + item.price
                    dailyUpkeep = dailyUpkeep + item.dailyUpkeep
                    runningLeasingFactor = runningLeasingFactor + item.runningLeasingFactor
                    lifetime = math.min(lifetime, item.lifetime)

                    if item.configurations ~= nil then
                        storeItem.configurations = storeItem.configurations or {}

                        for configName, configOptions in pairs(item.configurations) do
                            if storeItem.configurations[configName] ~= nil then
                                -- sum the prices of the configurations on multiple items
                                local itemConfigOptions = storeItem.configurations[configName]
                                for j=1, #configOptions do
                                    if itemConfigOptions[j] == nil then
                                        itemConfigOptions[j] = configOptions[j]
                                    else
                                        itemConfigOptions[j].price = itemConfigOptions[j].price + configOptions[j].price
                                    end
                                end
                            else
                                storeItem.configurations[configName] = table.copy(configOptions, math.huge)
                            end
                        end
                    end

                    if item.defaultConfigurationIds ~= nil then
                        storeItem.defaultConfigurationIds = storeItem.defaultConfigurationIds or {}
                    end

                    if item.subConfigurations ~= nil then
                        storeItem.subConfigurations = storeItem.subConfigurations or {}
                        for configName, configOptions in pairs(item.subConfigurations) do
                            storeItem.subConfigurations[configName] = configOptions
                        end
                    end

                    if item.configurationSets ~= nil then
                        storeItem.configurationSets = storeItem.configurationSets or {}
                        for configName, configOptions in pairs(item.configurationSets) do
                            storeItem.configurationSets[configName] = configOptions
                        end
                    end

                    local preSelectedConfigurations = {}
                    xmlFile:iterate(bundleKey .. ".configurations.configuration", function(_, configKey)
                        local configName = xmlFile:getValue(configKey.."#name")
                        local configValue = xmlFile:getValue(configKey.."#value")
                        if configName ~= nil and configValue ~= nil then
                            local allowChange = xmlFile:getValue(configKey.."#allowChange", false)
                            local hideOption = xmlFile:getValue(configKey.."#hideOption", false)
                            local disableOption = xmlFile:getValue(configKey.."#disableOption", false)
                            if not disableOption then
                                preSelectedConfigurations[configName] = {configValue=configValue, allowChange=allowChange, hideOption=hideOption}
                            else
                                local configElements = storeItem.configurations[configName]
                                if configElements ~= nil then
                                    for j=1, #configElements do
                                        if j == configValue then
                                            configElements[j].isSelectable = not configElements[j].isSelectable
                                        end
                                    end
                                end
                            end
                        end
                    end)

                    storeItem.hasLicensePlates = storeItem.hasLicensePlates or item.hasLicensePlates

                    table.insert(bundleInfo.bundleItems, {item=item, xmlFilename=item.xmlFilename, offset=offset, rotationOffset=rotationOffset, rotation=0, price=item.price, preSelectedConfigurations=preSelectedConfigurations})
                end
            end
            i = i + 1
        end

        i = 0
        while true do
            local attachKey = string.format(storeDataXMLKey..".attacherInfo.attach(%d)", i)
            if not xmlFile:hasProperty(attachKey) then
                break
            end
            local bundleElement0 = xmlFile:getValue(attachKey.."#bundleElement0")
            local bundleElement1 = xmlFile:getValue(attachKey.."#bundleElement1")
            local attacherJointIndex = xmlFile:getValue(attachKey.."#attacherJointIndex")
            local inputAttacherJointIndex = xmlFile:getValue(attachKey.."#inputAttacherJointIndex")
            if bundleElement0 ~= nil and bundleElement1 ~= nil and attacherJointIndex ~= nil and inputAttacherJointIndex ~= nil then
                table.insert(bundleInfo.attacherInfo, {bundleElement0=bundleElement0, bundleElement1=bundleElement1, attacherJointIndex=attacherJointIndex, inputAttacherJointIndex=inputAttacherJointIndex})
            end
            i = i + 1
        end

        storeItem.price = price
        storeItem.dailyUpkeep = dailyUpkeep
        storeItem.runningLeasingFactor = runningLeasingFactor
        storeItem.lifetime = lifetime
        storeItem.bundleInfo = bundleInfo
    end

    -- Construction brush
    if xmlFile:hasProperty(storeDataXMLKey..".brush") and storeItem.showInStore then
        local brushType = xmlFile:getValue(storeDataXMLKey..".brush.type")

        if brushType ~= nil and brushType ~= "none" then
            local parameters = {}
            xmlFile:iterate(storeDataXMLKey..".brush.parameters.parameter", function(index, key)
                local value = xmlFile:getValue(key)
                if xmlFile:getValue(key .. "#isFilename", false) then
                    value = Utils.getFilename(value, baseDir)
                end

                parameters[index] = value
            end)

            local brushCategory = self:getConstructionCategoryByName(xmlFile:getValue(storeDataXMLKey..".brush.category"))
            if brushCategory ~= nil then
                local tab = self:getConstructionTabByName(xmlFile:getValue(storeDataXMLKey..".brush.tab"), brushCategory.name)
                if tab ~= nil then
                    storeItem.brush = {
                        type = brushType,
                        parameters = parameters,
                        category = brushCategory,
                        tab = tab,
                    }
                else
                    Logging.xmlWarning(xmlFile, "Missing brush tab")
                end
            else
                Logging.xmlWarning(xmlFile, "Missing brush category")
            end
        end

    -- Placeables without brush just get the default placeable brush
    elseif storeItem.species == "placeable" and storeItem.showInStore then
        storeItem.brush = {
            type = "placeable",
            parameters = {},
            category = self.constructionCategories[1],
            tab = self.constructionCategories[1].tabs[1],
        }
    end

    if not ignoreAdd then
        self:addItem(storeItem)

        for i=1, #bundleItemsToAdd do
            self:addItem(bundleItemsToAdd[i])
        end
    end

    xmlFile:delete()

    return storeItem
end






---Adds a new store pack
-- @param string name pack name
-- @param string title pack title
-- @param string imageFilename image
-- @param string baseDir base directory
-- @return boolean true if adding was successful else false
function StoreManager:addPack(name, title, imageFilename, baseDir)
    if name == nil or name == "" then
        print("Warning: Could not register store pack. Name is missing or empty!")
        return false
    end
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is no valid name for a store pack!")
        return false
    end
    if title == nil or title == "" then
        print("Warning: Could not register store pack. Title is missing or empty!")
        return false
    end
    if imageFilename == nil or imageFilename == "" then
        print("Warning: Could not register store pack. Image is missing or empty!")
        return false
    end
    if baseDir == nil then
        print("Warning: Could not register store pack. Basedirectory not defined!")
        return false
    end

    name = name:upper()

    if self.packs[name] == nil then
        self.numOfPacks = self.numOfPacks + 1

        self.packs[name] = {
            name = name,
            title = title,
            image = Utils.getFilename(imageFilename, baseDir),
            baseDir = baseDir,
            orderId = self.numOfPacks,
            items = {}
        }

        return true
    end

    return false
end


---
function StoreManager:addModStorePack(name, title, imageFilename, baseDir)
    table.insert(self.modStorePacks, {
        name=name,
        title=title,
        imageFilename=imageFilename,
        baseDir=baseDir}
    )
end


---Add a new pack item.
-- @param string name Name of the pack
-- @param string itemFilename XML filename of the vehicle in the pack
function StoreManager:addPackItem(name, itemFilename)
    if name == nil or name == "" then
        Logging.warning("Could not add pack item. Name is missing or empty.")
        return
    end
    if self.packs[name] == nil then
        Logging.warning("Could not add pack item. Pack '%s' does not exist.", name)
        return
    end
    if itemFilename == nil or itemFilename == "" then
        Logging.warning("Could not add pack item to '%s'. Item filename is missing.", name)
        return
    end

    table.insert(self.packs[name].items, itemFilename)
end


---Get a list of all packs
function StoreManager:getPacks()
    return self.packs
end


---Get the items in the pack.
-- @param string name name of the pack.
function StoreManager:getPackItems(name)
    local pack = self.packs[name]
    if pack == nil then
        return nil
    else
        return pack.items
    end
end


---
function StoreManager:consoleCommandReloadStoreItems()
    for i, item in ipairs(self.items) do
        self.items[i] = self:loadItem(item.rawXMLFilename, item.baseDir, item.customEnvironment, item.isMod, item.isBundleItem, item.dlcTitle, item.extraContentId, true)
        if self.items[i] ~= nil then
            self.xmlFilenameToItem[self.items[i].xmlFilenameLower] = self.items[i]
        end
    end

    g_messageCenter:publish(MessageType.STORE_ITEMS_RELOADED)
end


---
function StoreManager.registerStoreDataXMLPaths(schema, basePath)
    schema:register(XMLValueType.L10N_STRING, basePath .. ".storeData.name", "Name of store item", nil, true)
    schema:register(XMLValueType.STRING, basePath .. ".storeData.name#params", "Parameters to add to name")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.species", "Store species", "vehicle")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.image", "Path to store icon", nil, true)
    schema:register(XMLValueType.STRING, basePath .. ".storeData.brand", "Brand identifier", "LIZARD")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.brand#customIcon", "Custom brand icon to display in the shop config screen")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.brand#imageOffset", "Offset of custom brand icon")

    schema:register(XMLValueType.BOOL, basePath .. ".storeData.canBeSold", "Defines of the vehicle can be sold", true)
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.showInStore", "Defines of the vehicle is shown in shop", true)
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.allowLeasing", "Defines of the vehicle can be leased", true)
    schema:register(XMLValueType.INT, basePath .. ".storeData.maxItemCount", "Defines the max. amount vehicle of this type")
    schema:register(XMLValueType.ANGLE, basePath .. ".storeData.rotation", "Y rotation of the vehicle", 0)

    schema:register(XMLValueType.STRING, basePath .. ".storeData.category", "Store category", "misc")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.storePacks.storePack(?)", "Store pack")
    schema:register(XMLValueType.FLOAT, basePath .. ".storeData.price", "Store price", 10000)
    schema:register(XMLValueType.FLOAT, basePath .. ".storeData.dailyUpkeep", "Daily up keep", 0)
    schema:register(XMLValueType.FLOAT, basePath .. ".storeData.runningLeasingFactor", "Running leasing factor", EconomyManager.DEFAULT_RUNNING_LEASING_FACTOR)
    schema:register(XMLValueType.FLOAT, basePath .. ".storeData.lifetime", "Lifetime of vehicle used to calculate price drop, in months", 600)

    schema:register(XMLValueType.BOOL, basePath .. ".storeData.shopDynamicTitle", "Vehicle brand icon and vehicle name is dynamically updated based on the selected configuration in the shop", false)
    schema:register(XMLValueType.VECTOR_TRANS, basePath .. ".storeData.shopTranslationOffset", "Translation offset for shop spawning and store icon", 0)
    schema:register(XMLValueType.VECTOR_ROT, basePath .. ".storeData.shopRotationOffset", "Rotation offset for shop spawning and store icon", 0)
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.shopIgnoreLastComponentPositions", "If set to true the component positions from last spawning are now reused", false)
    schema:register(XMLValueType.TIME, basePath .. ".storeData.shopLoadingDelay#initial", "Delay of initial shop loading until the vehicle is displayed. (Used e.g. to hide vehicle while components still moving)")
    schema:register(XMLValueType.TIME, basePath .. ".storeData.shopLoadingDelay#config", "Delay of shop loading after config change until the vehicle is displayed. (Used e.g. to hide vehicle while components still moving)")

    schema:register(XMLValueType.FLOAT, basePath .. ".storeData.shopHeight", "Height of vehicle for shop placement", 0)
    schema:register(XMLValueType.STRING, basePath .. ".storeData.financeCategory", "Finance category name")
    schema:register(XMLValueType.INT, basePath .. ".storeData.shopFoldingState", "Inverts the shop folding state if set to '1'", 0)
    schema:register(XMLValueType.FLOAT, basePath .. ".storeData.shopFoldingTime", "Defines a custom folding time for the shop")

    schema:register(XMLValueType.INT, basePath .. ".storeData.vertexBufferMemoryUsage", "Vertex buffer memory usage", 0)
    schema:register(XMLValueType.INT, basePath .. ".storeData.indexBufferMemoryUsage", "Index buffer memory usage", 0)
    schema:register(XMLValueType.INT, basePath .. ".storeData.textureMemoryUsage", "Texture memory usage", 0)
    schema:register(XMLValueType.INT, basePath .. ".storeData.instanceVertexBufferMemoryUsage", "Instance vertex buffer memory usage", 0)
    schema:register(XMLValueType.INT, basePath .. ".storeData.instanceIndexBufferMemoryUsage", "Instance index buffer memory usage", 0)
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.ignoreVramUsage", "Ignore VRAM usage", false)
    schema:register(XMLValueType.INT, basePath .. ".storeData.audioMemoryUsage", "Audio memory usage", 0)

    schema:register(XMLValueType.STRING, basePath .. ".storeData.bundleElements.bundleElement(?).xmlFilename", "XML filename")
    schema:register(XMLValueType.VECTOR_TRANS, basePath .. ".storeData.bundleElements.bundleElement(?).offset", "Translation offset of vehicle")
    schema:register(XMLValueType.VECTOR_ROT, basePath .. ".storeData.bundleElements.bundleElement(?).rotationOffset", "Rotation offset of vehicle")
    schema:register(XMLValueType.ANGLE, basePath .. ".storeData.bundleElements.bundleElement(?).yRotation", "Y rotation of vehicle")

    schema:register(XMLValueType.STRING, basePath .. ".storeData.bundleElements.bundleElement(?).configurations.configuration(?)#name", "Name of configuration")
    schema:register(XMLValueType.INT, basePath .. ".storeData.bundleElements.bundleElement(?).configurations.configuration(?)#value", "Configuration index that is forced for this config")
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.bundleElements.bundleElement(?).configurations.configuration(?)#allowChange", "Allow change of option", false)
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.bundleElements.bundleElement(?).configurations.configuration(?)#hideOption", "Hide the option completely", false)
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.bundleElements.bundleElement(?).configurations.configuration(?)#disableOption", "Disabled this particular config option", false)

    schema:register(XMLValueType.INT, basePath .. ".storeData.attacherInfo.attach(?)#bundleElement0", "First bundle element")
    schema:register(XMLValueType.INT, basePath .. ".storeData.attacherInfo.attach(?)#bundleElement1", "Second bundle element")
    schema:register(XMLValueType.INT, basePath .. ".storeData.attacherInfo.attach(?)#attacherJointIndex", "Attacher joint index")
    schema:register(XMLValueType.INT, basePath .. ".storeData.attacherInfo.attach(?)#inputAttacherJointIndex", "Input attacher joint index")

    schema:register(XMLValueType.L10N_STRING, basePath .. ".storeData.functions.function(?)", "Function description text")

    schema:register(XMLValueType.STRING, basePath .. ".storeData.brush.type", "Brush type")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.brush.category", "Brush category")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.brush.tab", "Brush tab")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.brush.parameters.parameter(?)", "Brush parameter value")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.brush.parameters.parameter(?)#isFilename", "Whether the parameter is a filename")

    -- Store Icon Generator - Not used in the game
    schema:register(XMLValueType.ANGLE, basePath .. ".storeData.storeIconRendering.settings#cameraYRot", "Y Rot of camera", "Setting from Icon Generator")
    schema:register(XMLValueType.ANGLE, basePath .. ".storeData.storeIconRendering.settings#cameraXRot", "X Rot of camera", "Setting from Icon Generator")
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.storeIconRendering.settings#advancedBoundingBox", "Advanced BB is used for icon placement", "Setting from Icon Generator")
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.storeIconRendering.settings#centerIcon", "Center item on icon", "Setting from Icon Generator")
    schema:register(XMLValueType.FLOAT, basePath .. ".storeData.storeIconRendering.settings#lightIntensity", "Intensity of light sources", "Setting from Icon Generator")
    schema:register(XMLValueType.BOOL, basePath .. ".storeData.storeIconRendering.settings#showTriggerMarkers", "Show trigger markers on icon (for placeables)", false)

    schema:register(XMLValueType.BOOL, basePath .. ".storeData.storeIconRendering.objectBundle#useClipPlane", "Clip plane is used")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.storeIconRendering.objectBundle.object(?)#filename", "Path to i3d file")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".storeData.storeIconRendering.objectBundle.object(?).node(?)#node", "Index Path of node to load")
    schema:register(XMLValueType.VECTOR_TRANS, basePath .. ".storeData.storeIconRendering.objectBundle.object(?).node(?)#translation", "Translation", "0 0 0")
    schema:register(XMLValueType.VECTOR_ROT, basePath .. ".storeData.storeIconRendering.objectBundle.object(?).node(?)#rotation", "Rotation", "0 0 0")
    schema:register(XMLValueType.VECTOR_SCALE, basePath .. ".storeData.storeIconRendering.objectBundle.object(?).node(?)#scale", "Scale", "1 1 1")

    schema:register(XMLValueType.STRING, basePath .. ".storeData.storeIconRendering.shaderParameter(?)#name", "Name if shader parameter")
    schema:register(XMLValueType.STRING, basePath .. ".storeData.storeIconRendering.shaderParameter(?)#values", "Values of shader parameter")

end
