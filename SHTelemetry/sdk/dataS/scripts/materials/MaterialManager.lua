---This class handles all materials




















local MaterialManager_mt = Class(MaterialManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function MaterialManager.new(customMt)
    local self = AbstractManager.new(customMt or MaterialManager_mt)

    MaterialManager.fontMaterialXMLSchema = XMLSchema.new("fontMaterials")
    MaterialManager.registerXMLPaths(MaterialManager.fontMaterialXMLSchema)

    return self
end


---Initialize data structures
function MaterialManager:initDataStructures()
    self.nameToIndex = {}
    self.materialTypes = {}
    self.materials = {}
    self.particleMaterials = {}
    self.modMaterialHoldersToLoad = {}
    self.fontMaterials = {}
    self.fontMaterialsByName = {}

    self.baseMaterials = {}
    self.baseMaterialsByName = {}

    self.loadedMaterialHolderNodes = {}
end


---Load data on map load
-- @return boolean true if loading was successful else false
function MaterialManager:loadMapData(xmlFile, missionInfo, baseDirectory, finishedLoadingCallback, callbackTarget)
    MaterialManager:superClass().loadMapData(self)

    self:addMaterialType("fillplane")
    self:addMaterialType("icon")
    self:addMaterialType("unloading")
    self:addMaterialType("smoke")
    self:addMaterialType("straw")
    self:addMaterialType("chopper")
    self:addMaterialType("soil")
    self:addMaterialType("sprayer")
    self:addMaterialType("spreader")
    self:addMaterialType("pipe")
    self:addMaterialType("mower")
    self:addMaterialType("belt")
    self:addMaterialType("belt_cropDirt")
    self:addMaterialType("belt_cropClean")
    self:addMaterialType("leveler")
    self:addMaterialType("washer")
    self:addMaterialType("pickup")

    MaterialType = self.nameToIndex

    -- called after last font material was loaded
    self.finishedLoadingCallback = finishedLoadingCallback
    self.callbackTarget = callbackTarget

    self:loadFontMaterialsXML(MaterialManager.DEFAULT_FONT_MATERIAL_XML, nil, self.baseDirectory)

    return true
end


---
function MaterialManager:unloadMapData()
    for _, node in ipairs(self.loadedMaterialHolderNodes) do
        delete(node)
    end

    for _, font in ipairs(self.fontMaterials) do
        delete(font.materialNode)
        if font.materialNodeNoNormal ~= nil then
            delete(font.materialNodeNoNormal)
        end
        if font.characterShape ~= nil then
            delete(font.characterShape)
        end
        if font.sharedLoadRequestId ~= nil then
            g_i3DManager:releaseSharedI3DFile(font.sharedLoadRequestId)
        end
    end

    MaterialManager:superClass().unloadMapData(self)
end


---Adds a new material type
-- @param string name name
function MaterialManager:addMaterialType(name)
    if not ClassUtil.getIsValidIndexName(name) then
        print("Warning: '"..tostring(name).."' is not a valid name for a materialType. Ignoring it!")
        return nil
    end

    name = name:upper()

    if self.nameToIndex[name] == nil then
        table.insert(self.materialTypes, name)
        self.nameToIndex[name] = #self.materialTypes
    end
end


---Returns a materialType by name
-- @param string name name of material type
-- @return string materialType the real material name, nil if not defined
function MaterialManager:getMaterialTypeByName(name)
    if name ~= nil then
        name = name:upper()

        -- atm we just return the uppercase name because a material type is only defined as a base string
        if self.nameToIndex[name] ~= nil then
            return name
        end
    end

    return nil
end


---Adds a new base material
-- @param string materialName materialName
-- @param integer materialId internal material id
function MaterialManager:addBaseMaterial(materialName, materialId)
    self.baseMaterialsByName[materialName:upper()] = materialId
    table.insert(self.baseMaterials, materialId)
end


---Returns base material by given name
-- @param string materialName materialName
-- @return integer materialId internal material id
function MaterialManager:getBaseMaterialByName(materialName)
    if materialName ~= nil then
        return self.baseMaterialsByName[materialName:upper()]
    end

    return nil
end


---Adds a new material type
-- @param integer fillTypeIndex filltype index
-- @param string materialType materialType
-- @param integer materialIndex material index
-- @param integer materialId internal material id
function MaterialManager:addMaterial(fillTypeIndex, materialType, materialIndex, materialId)
    self:addMaterialToTarget(self.materials, fillTypeIndex, materialType, materialIndex, materialId)
end


---Adds a new particle material type
-- @param integer fillTypeIndex filltype index
-- @param string materialType materialType
-- @param integer materialIndex material index
-- @param integer materialId internal material id
function MaterialManager:addParticleMaterial(fillTypeIndex, materialType, materialIndex, materialId)
    self:addMaterialToTarget(self.particleMaterials, fillTypeIndex, materialType, materialIndex, materialId)
end


---Adds a new material type to given target table
-- @param table target target table
-- @param integer fillTypeIndex filltype index
-- @param string materialType materialType
-- @param integer materialIndex material index
-- @param integer materialId internal material id
function MaterialManager:addMaterialToTarget(target, fillTypeIndex, materialType, materialIndex, materialId)
    if fillTypeIndex == nil or materialType == nil or materialIndex == nil or materialId == nil then
        return nil
    end

    if target[fillTypeIndex] == nil then
        target[fillTypeIndex] = {}
    end
    local fillTypeMaterials = target[fillTypeIndex]

    if fillTypeMaterials[materialType] == nil then
        fillTypeMaterials[materialType] = {}
    end
    local materialTypes = fillTypeMaterials[materialType]

    if g_showDevelopmentWarnings and materialTypes[materialIndex] ~= nil then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        Logging.devWarning("Material type '%s' already exists for fillType '%s'. It will be overwritten!", tostring(materialType), tostring(fillType.name))
    end

    materialTypes[materialIndex] = materialId
end


---Returns material for given properties
-- @param integer fillType fill type
-- @param string materialTypeName name of material type
-- @param integer materialIndex index of material
-- @return integer materialId id of material
function MaterialManager:getMaterial(fillType, materialTypeName, materialIndex)
    return self:getMaterialFromTarget(self.materials, fillType, materialTypeName, materialIndex)
end


---Returns material for given properties
-- @param integer fillType fill type
-- @param string materialTypeName name of material type
-- @param integer materialIndex index of material
-- @return integer materialId id of material
function MaterialManager:getParticleMaterial(fillType, materialTypeName, materialIndex)
    return self:getMaterialFromTarget(self.particleMaterials, fillType, materialTypeName, materialIndex)
end


---Returns material for given properties
-- @param integer fillType fill type
-- @param string materialTypeName name of material type
-- @param integer materialIndex index of material
-- @return integer materialId id of material
function MaterialManager:getMaterialFromTarget(target, fillType, materialTypeName, materialIndex)
    if fillType == nil or materialTypeName == nil or materialIndex == nil then
        return nil
    end

    local materialType = self:getMaterialTypeByName(materialTypeName)
    if materialType == nil then
        return nil
    end

    local fillTypeMaterials = target[fillType]
    if fillTypeMaterials == nil then
        --#debug log("Warning: missing fillType materials for fillType", g_fillTypeManager:getFillTypeNameByIndex(fillType), materialTypeName, materialIndex)
        return nil
    end

    local materials = fillTypeMaterials[materialType]
    if materials == nil then
        --#debug log("Warning: missing fillType materials for materialType", materialType)
        return nil
    end

    return materials[materialIndex]
end


---Returns material for given properties
function MaterialManager:addModMaterialHolder(filename)
    self.modMaterialHoldersToLoad[filename] = filename
end


---
function MaterialManager:loadModMaterialHolders()
    for filename, _ in pairs(self.modMaterialHoldersToLoad) do
        g_i3DManager:loadI3DFileAsync(filename, true, true, MaterialManager.materialHolderLoaded, self, nil)
    end
end


---
function MaterialManager:materialHolderLoaded(i3dNode, failedReason, args)
    for i=getNumOfChildren(i3dNode)-1, 0, -1 do
        local child = getChildAt(i3dNode, i)
        unlink(child)
        table.insert(self.loadedMaterialHolderNodes, child)
    end

    delete(i3dNode)
end


---
function MaterialManager:getFontMaterial(materialName, customEnvironment)
    if customEnvironment ~= nil and customEnvironment ~= "" then
        local customMaterialName = customEnvironment .. "." .. materialName
        if self.fontMaterialsByName[customMaterialName] ~= nil then
            return self.fontMaterialsByName[customMaterialName]
        end
    end

    return self.fontMaterialsByName[materialName]
end


---
function MaterialManager:loadFontMaterialsXML(xmlFilename, customEnvironment, baseDirectory)
    local xmlFile = XMLFile.load("TempFonts", xmlFilename, MaterialManager.fontMaterialXMLSchema)
    if xmlFile ~= nil then
        xmlFile.references = 0

        xmlFile:iterate("fonts.font", function(index, key)
            local name = xmlFile:getValue(key .. "#name")
            local filename = xmlFile:getValue(key .. "#filename")
            local node = xmlFile:getValue(key .. "#node")
            local noNormalNode = xmlFile:getValue(key .. "#noNormalNode")
            local characterShapePath = xmlFile:getValue(key .. "#characterShape")
            if name ~= nil and filename ~= nil and node ~= nil then
                if customEnvironment ~= nil and customEnvironment ~= "" then
                    name = customEnvironment .. "." .. name
                end

                local font = {}
                font.name = name
                font.node = node
                font.noNormalNode = noNormalNode
                font.characterShapePath = characterShapePath

                xmlFile.references = xmlFile.references + 1

                filename = Utils.getFilename(filename, baseDirectory)

                local arguments = {
                    xmlFile = xmlFile,
                    key = key,
                    font = font
                }
                font.sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(filename, false, false, self.fontMaterialLoaded, self, arguments)
            end
        end)
    end
end


---
function MaterialManager:fontMaterialLoaded(i3dNode, failedReason, arguments, loadingId)
    local xmlFile = arguments.xmlFile
    local key = arguments.key
    local font = arguments.font

    if i3dNode ~= 0 then
        local materialNode = I3DUtil.indexToObject(i3dNode, font.node)
        if materialNode ~= nil then
            font.materialId = getMaterial(materialNode, 0)
            font.materialNode = materialNode

            if font.noNormalNode ~= nil then
                font.materialNodeNoNormal = I3DUtil.indexToObject(i3dNode, font.noNormalNode)
                font.materialIdNoNormal = getMaterial(font.materialNodeNoNormal, 0)
            end

            if font.characterShapePath ~= nil then
                font.characterShape = I3DUtil.indexToObject(i3dNode, font.characterShapePath)
            end

            unlink(font.materialNodeNoNormal)
            unlink(font.characterShape)
            unlink(materialNode)

            font.spacingX = xmlFile:getValue(key .. ".spacing#x", 0)
            font.spacingY = xmlFile:getValue(key .. ".spacing#y", 0)

            font.charToCharSpace = xmlFile:getValue(key .. ".spacing#charToChar", 0.05)

            font.characters = {}

            font.charactersByType = {}
            font.charactersByType[MaterialManager.FONT_CHARACTER_TYPE.NUMERICAL] = {}
            font.charactersByType[MaterialManager.FONT_CHARACTER_TYPE.ALPHABETICAL] = {}
            font.charactersByType[MaterialManager.FONT_CHARACTER_TYPE.SPECIAL] = {}

            xmlFile:iterate(key .. ".character", function(index, charKey)
                local character = {}
                character.uvIndex = xmlFile:getValue(charKey .. "#uvIndex", 0)
                character.value = xmlFile:getValue(charKey .. "#value")
                local typeStr = xmlFile:getValue(charKey .. "#type", "alphabetical")
                character.type = MaterialManager.FONT_CHARACTER_TYPE[typeStr:upper()] or MaterialManager.FONT_CHARACTER_TYPE.ALPHABETICAL

                character.spacingX = math.max(xmlFile:getValue(charKey .. "#spacingX", font.spacingX), 0.0001)
                character.spacingY = math.max(xmlFile:getValue(charKey .. "#spacingY", font.spacingY), 0.0001)
                character.offsetX = xmlFile:getValue(charKey .. "#offsetX", 0)
                character.offsetY = xmlFile:getValue(charKey .. "#offsetY", 0)
                character.realSpacingX = math.max(xmlFile:getValue(charKey .. "#realSpacingX", character.spacingX), 0.0001)

                if character.value ~= nil then
                    table.insert(font.characters, character)
                    table.insert(font.charactersByType[character.type], character)
                end
            end)

            font.getCharacterIndexByCharacter = function(_, char)
                for i=1, #font.characters do
                    if font.characters[i].value:lower() == char:lower() then
                        return i
                    end
                end

                return 1
            end

            font.getCharacterByCharacterIndex = function(_, index)
                local char = font.characters[index]
                if char ~= nil then
                    return char.value
                end

                return "0"
            end

            font.assignFontMaterialToNode = function(_, node, hasNormal)
                if node ~= nil then
                    local materialId = font.materialId
                    if hasNormal == false then
                        materialId = font.materialIdNoNormal or materialId
                    end

                    setMaterial(node, materialId, 0)
                    setShaderParameter(node, "spacing", font.spacingX, font.spacingY, 0, 0, false)
                end
            end

            font.setFontCharacter = function(_, node, targetCharacter, color, hiddenColor)
                if node ~= nil then
                    if hiddenColor ~= nil then
                        if targetCharacter == " " then
                            targetCharacter = "0"
                            font:setFontCharacterColor(node, hiddenColor[1], hiddenColor[2], hiddenColor[3])
                        else
                            font:setFontCharacterColor(node, color[1], color[2], color[3])
                        end
                    end

                    -- try first if we have a character with matching case
                    local foundCharacter = nil
                    for i=1, #font.characters do
                        local character = font.characters[i]
                        if character.value == targetCharacter then
                            foundCharacter = character
                            break
                        end
                    end

                    -- if not we use any character independent of the case
                    if foundCharacter == nil then
                        for i=1, #font.characters do
                            local character = font.characters[i]
                            if character.value:lower() == targetCharacter:lower() then
                                foundCharacter = character
                                break
                            end
                        end
                    end

                    if foundCharacter ~= nil then
                        setVisibility(node, true)
                        setShaderParameter(node, "index", foundCharacter.uvIndex, 0, 0, 0, false)
                        setShaderParameter(node, "spacing", foundCharacter.spacingX or font.spacingX, foundCharacter.spacingY or font.spacingY, 0, 0, false)
                    else
                        setVisibility(node, false)
                    end

                    return foundCharacter
                end
            end

            font.setFontCharacterColor = function(_, node, r, g, b, a, emissive)
                if node ~= nil then
                    local oldR, oldG, oldB, oldA = getShaderParameter(node, "colorScale")
                    setShaderParameter(node, "colorScale", r or oldR, g or oldG, b or oldB, a or oldA, false)

                    if emissive ~= nil then
                        local lightControl, _, _, _ = getShaderParameter(node, "lightControl")
                        setShaderParameter(node, "lightControl", emissive or lightControl, 0, 0, 0, false)
                    end
                end
            end

            font.createCharacterLine = function(_, linkNode, numChars, textSize, textColor, hiddenColor, textEmissiveScale, scaleX, scaleY, textAlignment, hiddenAlpha, fontThickness)
                if font.characterShape ~= nil then
                    local characterLine = {}
                    characterLine.characters = {}
                    characterLine.textSize = textSize or 1
                    characterLine.scaleX = scaleX or 1
                    characterLine.scaleY = scaleY or 1
                    characterLine.textAlignment = textAlignment or RenderText.ALIGN_RIGHT
                    characterLine.fontThickness = ((fontThickness or 1) - 1) / 8 + 1
                    characterLine.textColor = textColor
                    characterLine.hiddenColor = hiddenColor
                    characterLine.textEmissiveScale = textEmissiveScale or 0
                    characterLine.hiddenAlpha = hiddenAlpha or 0
                    characterLine.rootNode = createTransformGroup("characterLine")
                    link(linkNode, characterLine.rootNode)

                    for i=1, numChars do
                        local char = clone(font.characterShape, false, false, false)
                        link(characterLine.rootNode, char)
                        font:assignFontMaterialToNode(char)

                        setShaderParameter(char, "alphaErosion", 1-characterLine.fontThickness, 0, 0, 0, false)

                        local r, g, b
                        if characterLine.textColor ~= nil then
                            r, g, b = characterLine.textColor[1], characterLine.textColor[2], characterLine.textColor[3]
                        end
                        font:setFontCharacterColor(char, r, g, b, 1, characterLine.textEmissiveScale)

                        table.insert(characterLine.characters, char)
                    end

                    font:updateCharacterLine(characterLine, "")

                    return characterLine
                else
                    Logging.error("Could not create characters from font '%s'. No source character mesh found!", font.name)
                end
            end

            font.updateCharacterLine = function(_, characterLine, text)
                if characterLine ~= nil then
                    local realWidth = 0
                    local xPos = 0
                    local textLength = text:len()
                    for i=1, #characterLine.characters do
                        local charNode = characterLine.characters[i]
                        local targetCharacter = text:sub(textLength - (i-1), textLength - (i-1)) or " "
                        local characterData = font:setFontCharacter(charNode, targetCharacter, characterLine.textColor, characterLine.hiddenColor)

                        local offsetX, offsetY = 0, 0
                        local spacingX, spacingY, realSpacingX = font.spacingX, font.spacingY, font.spacingX
                        if characterData ~= nil then
                            spacingX = characterData.spacingX or spacingX
                            spacingY = characterData.spacingY or spacingY
                            realSpacingX = characterData.realSpacingX or spacingY
                            offsetX, offsetY = characterData.offsetX, characterData.offsetY
                        end

                        local ratio = (1 - (spacingX * 2)) / (1 - (spacingY * 2))
                        local scaleX = (characterLine.textSize * ratio) * characterLine.scaleX
                        local scaleY = characterLine.textSize * characterLine.scaleY

                        setScale(charNode, scaleX, scaleY, 1)

                        local charWidth = scaleX + (characterLine.textSize * font.charToCharSpace) * (spacingX / realSpacingX)
                        setTranslation(charNode, xPos - charWidth * 0.5 + (charWidth * offsetX), scaleY * 0.5 + (scaleY * offsetY), 0)

                        xPos = xPos - charWidth

                        if targetCharacter ~= " " and targetCharacter ~= "" then
                            realWidth = xPos
                        end
                    end

                    if characterLine.textAlignment == RenderText.ALIGN_LEFT then
                        setTranslation(characterLine.rootNode, -realWidth, 0, 0)
                    elseif characterLine.textAlignment == RenderText.ALIGN_CENTER then
                        setTranslation(characterLine.rootNode, -realWidth * 0.5, 0, 0)
                    else
                        setTranslation(characterLine.rootNode, 0, 0, 0)
                    end
                end
            end

            font.createSingleCharacter = function(_, linkNode, textSize, textColor, hiddenColor, textEmissiveScale, scaleX, scaleY, hiddenAlpha)
                if font.characterShape ~= nil then
                    local singleCharacter = {}
                    singleCharacter.textSize = textSize or 1
                    singleCharacter.scaleX = scaleX or 1
                    singleCharacter.scaleY = scaleY or 1
                    singleCharacter.textColor = textColor
                    singleCharacter.hiddenColor = hiddenColor
                    singleCharacter.textEmissiveScale = textEmissiveScale or 0
                    singleCharacter.hiddenAlpha = hiddenAlpha or 0

                    singleCharacter.charNode = clone(font.characterShape, false, false, false)
                    link(linkNode, singleCharacter.charNode)
                    setTranslation(singleCharacter.charNode, 0, 0, 0)
                    setRotation(singleCharacter.charNode, 0, 0, 0)
                    font:assignFontMaterialToNode(singleCharacter.charNode)

                    local r, g, b
                    if singleCharacter.textColor ~= nil then
                        r, g, b = singleCharacter.textColor[1], singleCharacter.textColor[2], singleCharacter.textColor[3]
                    end
                    font:setFontCharacterColor(singleCharacter.charNode, r, g, b, 1, singleCharacter.textEmissiveScale)

                    font:updateSingleCharacter(singleCharacter, "")

                    return singleCharacter
                else
                    Logging.error("Could not create characters from font '%s'. No source character mesh found!", font.name)
                end
            end

            font.updateSingleCharacter = function(_, singleCharacter, targetCharacter)
                if singleCharacter ~= nil then
                    local characterData = font:setFontCharacter(singleCharacter.charNode, targetCharacter, singleCharacter.textColor, singleCharacter.hiddenColor)

                    local offsetX, offsetY = 0, 0
                    local spacingX, spacingY = font.spacingX, font.spacingY
                    if characterData ~= nil then
                        spacingX = characterData.spacingX or spacingX
                        spacingY = characterData.spacingY or spacingY
                        offsetX = characterData.offsetX or offsetX
                        offsetY = characterData.offsetY or offsetY
                    end

                    local ratio = (1 - (spacingX * 2)) / (1 - (spacingY * 2))
                    local scaleX = (singleCharacter.textSize * ratio) * singleCharacter.scaleX
                    local scaleY = singleCharacter.textSize * singleCharacter.scaleY

                    setScale(singleCharacter.charNode, scaleX, scaleY, 1)
                    setTranslation(singleCharacter.charNode, scaleY * offsetX, scaleY * offsetY, 0)
                end
            end

            font.getFontMaxWidthRatio = function(_, alphabetical, numerical, special)
                local maxRatio = 0
                for i=1, #font.characters do
                    local character = font.characters[i]

                    if character.type == MaterialManager.FONT_CHARACTER_TYPE.ALPHABETICAL and alphabetical ~= false
                    or character.type == MaterialManager.FONT_CHARACTER_TYPE.NUMERICAL and numerical ~= false
                    or character.type == MaterialManager.FONT_CHARACTER_TYPE.SPECIAL and special ~= false then
                        local spacingX, spacingY = character.spacingX or font.spacingX, character.spacingY or font.spacingY
                        local ratio = (1 - (spacingX * 2)) / (1 - (spacingY * 2))
                        maxRatio = math.max(ratio, maxRatio)
                    end
                end

                return maxRatio
            end

            table.insert(self.fontMaterials, font)
            self.fontMaterialsByName[font.name] = font
        end

        delete(i3dNode)
    end

    xmlFile.references = xmlFile.references - 1
    if xmlFile.references == 0 then
        xmlFile:delete()

        if self.finishedLoadingCallback ~= nil then
            self.finishedLoadingCallback(self.callbackTarget)
            self.finishedLoadingCallback = nil
            self.callbackTarget = nil
        end
    end
end


---
function MaterialManager.registerXMLPaths(schema)
    schema:register(XMLValueType.STRING, "fonts.font(?)#name", "Name if font")
    schema:register(XMLValueType.STRING, "fonts.font(?)#filename", "Path to i3d file")
    schema:register(XMLValueType.STRING, "fonts.font(?)#node", "Path to material node")
    schema:register(XMLValueType.STRING, "fonts.font(?)#characterShape", "Path to character mesh")
    schema:register(XMLValueType.STRING, "fonts.font(?)#noNormalNode", "Path to material node without normal map")

    schema:register(XMLValueType.FLOAT, "fonts.font(?).spacing#x", "X Spacing", 0)
    schema:register(XMLValueType.FLOAT, "fonts.font(?).spacing#y", "Y Spacing", 0)
    schema:register(XMLValueType.FLOAT, "fonts.font(?).spacing#charToChar", "Spacing from character to character in percentage", 0.1)

    schema:register(XMLValueType.INT, "fonts.font(?).character(?)#uvIndex", "Index on uv map", 0)
    schema:register(XMLValueType.STRING, "fonts.font(?).character(?)#value", "Character value")
    schema:register(XMLValueType.STRING, "fonts.font(?).character(?)#type", "Character type", "alphabetical")
    schema:register(XMLValueType.FLOAT, "fonts.font(?).character(?)#spacingX", "Custom spacing X")
    schema:register(XMLValueType.FLOAT, "fonts.font(?).character(?)#spacingY", "Custom spacing Y")
    schema:register(XMLValueType.FLOAT, "fonts.font(?).character(?)#offsetX", "Custom X offset for created char lines (percentage)", 0)
    schema:register(XMLValueType.FLOAT, "fonts.font(?).character(?)#offsetY", "Custom Y offset for created char lines (percentage)", 0)
    schema:register(XMLValueType.FLOAT, "fonts.font(?).character(?)#realSpacingX", "Real spacing from border to visual beginning")
end
