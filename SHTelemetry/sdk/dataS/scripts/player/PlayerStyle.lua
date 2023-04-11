---This class handles player avatar customization









local PlayerStyle_mt = Class(PlayerStyle)









































---Creating manager
-- @return table instance instance of object
function PlayerStyle.new(customMt)
    local self = setmetatable({}, customMt or PlayerStyle_mt)

    local function createConfig(name, setter, listMappingGetter, colorSetter)
        self[name] = {
            items = {},
            selection = 0,
            setter = setter,
            listMappingGetter = listMappingGetter,
            color = 1,
            colorSetter = colorSetter,
        }
    end

    createConfig("beardConfig", self.setBeard, self.getPossibleBeards, self.setHairItemColor)
    createConfig("bottomConfig", self.setBottom, self.getPossibleBottoms, self.setItemColor)
    createConfig("faceConfig", self.setFace, self.getPossibleFaces, self.setItemColor)
    createConfig("footwearConfig", self.setFootwear, self.getPossibleFootwear, self.setItemColor)
    createConfig("glassesConfig", self.setGlasses, self.getPossibleGlasses, self.setItemColor)
    createConfig("glovesConfig", self.setGloves, self.getPossibleGloves, self.setItemColor)
    createConfig("hairStyleConfig", self.setHairStyle, self.getPossibleHairStyles, self.setHairItemColor)
    createConfig("headgearConfig", self.setHeadgear, self.getPossibleHeadgear, self.setItemColor)
    createConfig("mustacheConfig", self.setMustache, self.getPossibleMustaches, self.setHairItemColor)
    createConfig("onepieceConfig", self.setOnepiece, self.getPossibleOnepieces, self.setItemColor)
    createConfig("topConfig", self.setTop, self.getPossibleTops, self.setItemColor)
    createConfig("facegearConfig", self.setFacegear)

    -- Unify hair colors
    self.beardConfig.color = self.hairStyleConfig.color
    self.mustacheConfig.color = self.hairStyleConfig.color

    self.faceConfig.selection = 1
    self.hairStyleConfig.selection = 2

    self.disabledOptionsForSelection = {}

    self.presets = {}

    self.isConfigurationLoaded = false

    return self
end



























































































---Load player style options and configuration info from a player XML
function PlayerStyle:loadConfigurationXML(xmlFilename)
    local xmlFile = XMLFile.load("player", xmlFilename)
    if xmlFile == nil then
        Logging.error("Player config does not exist at %s. Loading default instead", xmlFilename)

        xmlFilename = "dataS/character/humans/player/player01.xml"
        xmlFile = XMLFile.load("player", xmlFilename)
        if xmlFile == nil then
            Logging.fatal("Default player config does not exist at %s", xmlFilename)
        end
    end

    -- Used for moving from 1 config to another
    local restoreSelection = nil

    self.xmlFilename = xmlFilename
    local rootKey = "player.character.playerStyle"

    self.filename = xmlFile:getString("player.filename")
    self.atlasFilename = xmlFile:getString("player.character.playerStyle#atlas")

    self.skeletonRootIndex = xmlFile:getInt("player.character.thirdPerson#skeleton") or 0

    -- Attach points
    self.attachPoints = {}
    xmlFile:iterate(rootKey .. ".attachPoints.attachPoint", function(_, key)
        local name = xmlFile:getString(key .. "#name")
        local node = self:parseIndex(xmlFile:getString(key .. "#node"))
        self.attachPoints[name] = node
    end)

    -- Faces
    if self.faceConfig.selection ~= 0 and self.faceConfig.items[self.faceConfig.selection] ~= nil then
        restoreSelection = self.faceConfig.items[self.faceConfig.selection].name
    end
    self.faceConfig.items = {}
    self.facesByName = {}
    xmlFile:iterate(rootKey .. ".faces.face", function(_, key)
        local index = xmlFile:getString(key .. "#node")
        local name = xmlFile:getString(key .. "#name")
        local skinColor = string.getVectorN(xmlFile:getString(key .. "#skinColor"), 3)
        local uvSlot = xmlFile:getInt(key .. "#uvSlot")
        local filename = xmlFile:getString(key .. "#filename")

        local attachPoint = xmlFile:getString(key .. "#attachPoint") or ""
        local attachNode = self.attachPoints[attachPoint]
        if attachNode == nil then
            Logging.xmlError(xmlFile, "Attach point with name '%s' does not exist for %s", attachPoint, name)
            return
        end

        table.insert(self.faceConfig.items, {
            index = index,
            name = name,
            skinColor = skinColor,
            uvSlot = uvSlot,
            numColors = 0,
            filename = filename,
            attachNode = attachNode,
        })

        if self.facesByName[name] ~= nil then
            Logging.devError("Wardrobe face name '%s' already used", name)
        end

        self.facesByName[name] = #self.faceConfig.items

        if name == restoreSelection then
            self.faceConfig.selection = #self.faceConfig.items
        end
    end)

    self.faceNeutralDiffuseColor = string.getVectorN(xmlFile:getString(rootKey .. ".faces#neutralDiffuse"), 3)

    -- Nude body parts
    self.bodyParts = {}
    self.bodyPartIndexByName = {}
    xmlFile:iterate(rootKey .. ".bodyParts.bodyPart", function(_, key)
        local index = self:parseIndex(xmlFile:getString(key .. "#node"))
        local name = xmlFile:getString(key .. "#name")

        table.insert(self.bodyParts, {index = index, name = name})

        if self.bodyPartIndexByName[name] ~= nil then
            Logging.devError("Wardrobe body part name '%s' already used", name)
        end
        self.bodyPartIndexByName[name] = #self.bodyParts
    end)

    self:loadColors(xmlFile, rootKey .. ".colors.hair.color", "hairColors")
    self:loadColors(xmlFile, rootKey .. ".colors.clothing.color", "defaultClothingColors")

    local topsByName = self:loadClothing(xmlFile, rootKey .. ".tops", "top", "topConfig", true)
    local bottomsByName = self:loadClothing(xmlFile, rootKey .. ".bottoms", "bottom", "bottomConfig", true)
    local footwearByName = self:loadClothing(xmlFile, rootKey .. ".footwear", "footwear", "footwearConfig", true)
    local glovesByName = self:loadClothing(xmlFile, rootKey .. ".gloves", "glove", "glovesConfig", true)
    local glassesByName = self:loadClothing(xmlFile, rootKey .. ".glasses", "glasses", "glassesConfig")
    local onepiecesByName = self:loadClothing(xmlFile, rootKey .. ".onepieces", "onepiece", "onepieceConfig", true)
    local facegearByName = self:loadClothing(xmlFile, rootKey .. ".facegear", "facegear", "facegearConfig", true, false, true)
    local headgearByName = self:loadClothing(xmlFile, rootKey .. ".headgear", "headgear", "headgearConfig", true, false, false, true)
    self:loadClothing(xmlFile, rootKey .. ".hairStyles", "hairStyle", "hairStyleConfig", true, true, nil, nil, true)
    self:loadClothing(xmlFile, rootKey .. ".beards", "beard", "beardConfig", true, true, true)
    self:loadClothing(xmlFile, rootKey .. ".mustaches", "mustache", "mustacheConfig", true, true, true)

    -- Presets
    self.presets = {}
    local presetByName = {}
    xmlFile:iterate(rootKey .. ".presets.preset", function(index, key)
        local text = xmlFile:getString(key .. "#text")
        local name = xmlFile:getString(key .. "#name")
        local brand
        local brandName = xmlFile:getString(key .. "#brand")
        if brandName ~= nil then
            if g_brandManager ~= nil then
                brand = g_brandManager:getBrandByName(brandName)
                if brand ~= nil then
                    brandName = nil
                end
            end
        end

        if presetByName[name] ~= nil then
            Logging.devError("Wardrobe preset name '%s' already used", name)
        end

        local preset = {
            name = name,
            text = text,
            uvSlot = xmlFile:getInt(key .. "#uvSlot"),
            brand = brand,
            brandName = brandName,
            extraContentId = xmlFile:getString(key .. "#extraContentId"),
            isSelectable = xmlFile:getBool(key .. "#isSelectable", true)
        }
        presetByName[name] = preset

        local function getOrNul(list, itemKey)
            if itemKey == nil then
                return nil
            end
            if list[itemKey] ~= nil then
                return list[itemKey]
            end

            for _, face in ipairs(self.faceConfig.items) do
                local item = list[itemKey .. "_" .. face.name]
                if item ~= nil then
                    return item
                end
            end

            return 0
        end

        local faceName = xmlFile:getString(key .. ".face#name")
        if faceName ~= nil then
            preset.face = self.facesByName[faceName]
        end

        preset.top = getOrNul(topsByName, xmlFile:getString(key .. ".top#name"))
        preset.bottom = getOrNul(bottomsByName, xmlFile:getString(key .. ".bottom#name"))
        preset.onepiece = getOrNul(onepiecesByName, xmlFile:getString(key .. ".onepiece#name"))
        preset.glasses = getOrNul(glassesByName, xmlFile:getString(key .. ".glasses#name"))
        preset.gloves = getOrNul(glovesByName, xmlFile:getString(key .. ".gloves#name"))
        preset.headgear = getOrNul(headgearByName, xmlFile:getString(key .. ".headgear#name"))
        preset.footwear = getOrNul(footwearByName, xmlFile:getString(key .. ".footwear#name"))
        preset.facegear = getOrNul(facegearByName, xmlFile:getString(key .. ".facegear#name"))

        table.insert(self.presets, preset)
    end)

    self.isConfigurationLoaded = true

    xmlFile:delete()
end



















































































































































































































































































































































---Reads from network stream
-- @param integer streamId id of the stream to read
-- @param table connection connection information
function PlayerStyle:readStream(streamId, connection)
    self.xmlFilename = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId))

    local function readConfig(configName)
        local selection = streamReadUIntN(streamId, PlayerStyle.SEND_NUM_BITS)
        self[configName].selection = selection

        self[configName].color = self:readStreamColor(streamId)
    end

    readConfig("beardConfig")
    readConfig("bottomConfig")
    readConfig("faceConfig")
    readConfig("footwearConfig")
    readConfig("glassesConfig")
    readConfig("glovesConfig")
    readConfig("hairStyleConfig")
    readConfig("headgearConfig")
    readConfig("mustacheConfig")
    readConfig("onepieceConfig")
    readConfig("topConfig")
    readConfig("facegearConfig")
end


---Writes in network stream
-- @param integer streamId id of the stream to read
-- @param table connection connection information
function PlayerStyle:writeStream(streamId, connection)
    streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(self.xmlFilename))

    local function writeConfig(configName)
        local selection = self[configName].selection
        streamWriteUIntN(streamId, selection, PlayerStyle.SEND_NUM_BITS)

        self:writeStreamColor(streamId, self[configName].color)
    end

    writeConfig("beardConfig")
    writeConfig("bottomConfig")
    writeConfig("faceConfig")
    writeConfig("footwearConfig")
    writeConfig("glassesConfig")
    writeConfig("glovesConfig")
    writeConfig("hairStyleConfig")
    writeConfig("headgearConfig")
    writeConfig("mustacheConfig")
    writeConfig("onepieceConfig")
    writeConfig("topConfig")
    writeConfig("facegearConfig")
end
