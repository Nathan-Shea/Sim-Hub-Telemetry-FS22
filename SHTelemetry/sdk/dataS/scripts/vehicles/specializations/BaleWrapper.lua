---Specialization for all BaleWrappers (round, square) providing picking up, wrapping and dropping functionality







































---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function BaleWrapper.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations)
end


---
function BaleWrapper.initSpecialization()
    g_configurationManager:addConfigurationType("wrappingColor", g_i18n:getText("configuration_wrappingColor"), nil, nil, ConfigurationUtil.getConfigColorSingleItemLoad, ConfigurationUtil.getConfigColorPostLoad, ConfigurationUtil.SELECTOR_COLOR)
    g_configurationManager:addConfigurationType("wrappingAnimation", g_i18n:getText("configuration_wrappingAnimation"), "baleWrapper", nil, nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION)

    g_storeManager:addSpecType("baleWrapperBaleSizeRound", "shopListAttributeIconBaleWrapperBaleSizeRound", BaleWrapper.loadSpecValueBaleSizeRound, BaleWrapper.getSpecValueBaleSizeRound, "vehicle")
    g_storeManager:addSpecType("baleWrapperBaleSizeSquare", "shopListAttributeIconBaleWrapperBaleSizeSquare", BaleWrapper.loadSpecValueBaleSizeSquare, BaleWrapper.getSpecValueBaleSizeSquare, "vehicle")

    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("BaleWrapper")
    ConfigurationUtil.registerColorConfigurationXMLPaths(schema, "wrappingColor")
    BaseMaterial.registerBaseMaterialConfigurationsXMLPaths(schema, "wrappingColor")

    schema:register(XMLValueType.FLOAT, "vehicle.baleWrapper#foldMinLimit", "Fold min limit (Allow grabbing if folding is between these values)", 0)
    schema:register(XMLValueType.FLOAT, "vehicle.baleWrapper#foldMaxLimit", "Fold max limit (Allow grabbing if folding is between these values)", 1)
    schema:register(XMLValueType.NODE_INDEX, "vehicle.baleWrapper.grabber#node", "Grabber node")
    schema:register(XMLValueType.NODE_INDEX, "vehicle.baleWrapper.grabber#triggerNode", "Grabber trigger node")
    schema:register(XMLValueType.FLOAT, "vehicle.baleWrapper.grabber#nearestDistance", "Distance to bale to grab it", 3.0)

    schema:register(XMLValueType.BOOL, "vehicle.baleWrapper.automaticDrop#enabled", "Automatic drop", "true on mobile")
    schema:register(XMLValueType.BOOL, "vehicle.baleWrapper.automaticDrop#toggleable", "Automatic bale drop can be toggled", "false on mobile")
    schema:register(XMLValueType.L10N_STRING, "vehicle.baleWrapper.automaticDrop#textPos", "Positive toggle automatic drop text", "action_toggleAutomaticBaleDropPos")
    schema:register(XMLValueType.L10N_STRING, "vehicle.baleWrapper.automaticDrop#textNeg", "Negative toggle automatic drop text", "action_toggleAutomaticBaleDropNeg")

    BaleWrapper.registerWrapperXMLPaths(schema, "vehicle.baleWrapper.roundBaleWrapper")
    BaleWrapper.registerWrapperXMLPaths(schema, "vehicle.baleWrapper.squareBaleWrapper")

    local configKey = "vehicle.baleWrapper.wrappingAnimationConfigurations.wrappingAnimationConfiguration(?)"
    for i=1, #BaleWrapper.ANIMATION_NAMES do
        BaleWrapper.registerWrapperAnimationXMLPaths(schema, configKey .. ".roundBaleWrapper", BaleWrapper.ANIMATION_NAMES[i])
        BaleWrapper.registerWrapperAnimationXMLPaths(schema, configKey .. ".roundBaleWrapper.baleTypes.baleType(?)", BaleWrapper.ANIMATION_NAMES[i])
        BaleWrapper.registerWrapperAnimationXMLPaths(schema, configKey .. ".squareBaleWrapper", BaleWrapper.ANIMATION_NAMES[i])
        BaleWrapper.registerWrapperAnimationXMLPaths(schema, configKey .. ".squareBaleWrapper.baleTypes.baleType(?)", BaleWrapper.ANIMATION_NAMES[i])
    end

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, configKey)

    schema:setXMLSpecializationType()

    local schemaSavegame = Vehicle.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.FLOAT, "vehicles.vehicle(?).baleWrapper#wrapperTime", "Bale wrapping time", 0)
    Bale.registerSavegameXMLPaths(schemaSavegame, "vehicles.vehicle(?).baleWrapper.bale")
end


---
function BaleWrapper.registerWrapperXMLPaths(schema, basePath)
    for i=1, #BaleWrapper.ANIMATION_NAMES do
        BaleWrapper.registerWrapperAnimationXMLPaths(schema, basePath, BaleWrapper.ANIMATION_NAMES[i])
        BaleWrapper.registerWrapperAnimationXMLPaths(schema, basePath .. ".baleTypes.baleType(?)", BaleWrapper.ANIMATION_NAMES[i])
    end

    schema:register(XMLValueType.STRING, basePath .. ".baleTypes.baleType(?)#fillType", "Fill type name")
    schema:register(XMLValueType.FLOAT, basePath .. ".baleTypes.baleType(?)#diameter", "Bale diameter", 0)
    schema:register(XMLValueType.FLOAT, basePath .. ".baleTypes.baleType(?)#width", "Bale width", 0)
    schema:register(XMLValueType.FLOAT, basePath .. ".baleTypes.baleType(?)#height", "Bale height", 0)
    schema:register(XMLValueType.FLOAT, basePath .. ".baleTypes.baleType(?)#length", "Bale length", 0)
    schema:register(XMLValueType.STRING, basePath .. ".baleTypes.baleType(?).textures#diffuse", "Path to wrap diffuse map")
    schema:register(XMLValueType.STRING, basePath .. ".baleTypes.baleType(?).textures#normal", "Path to wrap normal map")
    schema:register(XMLValueType.BOOL, basePath .. ".baleTypes.baleType(?)#skipWrapping", "Bale is picked up, but not wrapped", false)
    schema:register(XMLValueType.BOOL, basePath .. ".baleTypes.baleType(?)#forceWhileFolding", "Force this bale type while wrapper is folded", false)

    schema:register(XMLValueType.FLOAT, basePath .. ".baleTypes.baleType(?).wrappingState.key(?)#time", "Time of wrapping (0-1)")
    schema:register(XMLValueType.FLOAT, basePath .. ".baleTypes.baleType(?).wrappingState.key(?)#wrappingState", "Wrapping state for shader")

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, basePath .. ".baleTypes.baleType(?)")
    BaleWrapper.registerWrapperFoilAnimationXMLPaths(schema, basePath .. ".baleTypes.baleType(?)")

    schema:register(XMLValueType.NODE_INDEX, basePath .. "#baleNode", "Bale Node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. "#wrapperNode", "Wrapper Node")
    schema:register(XMLValueType.INT, basePath .. "#wrapperRotAxis", "Wrapper rotation axis", 2)

    schema:register(XMLValueType.FLOAT, basePath .. ".wrapperAnimation.key(?)#time", "Key time")
    schema:register(XMLValueType.VECTOR_ROT, basePath .. ".wrapperAnimation.key(?)#baleRot", "Bale rotation")
    schema:register(XMLValueType.VECTOR_ROT, basePath .. ".wrapperAnimation.key(?)#wrapperRot", "Wrapper rotation", "0 0 0")

    schema:register(XMLValueType.FLOAT, basePath .. "#wrappingTime", "Wrapping duration", 5)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrapAnimNodes.wrapAnimNode(?)#node", "Wrap node")
    schema:register(XMLValueType.BOOL, basePath .. ".wrapAnimNodes.wrapAnimNode(?)#repeatWrapperRot", "Repeat wrapper rotation, so wrapper rotation is always between 0 and 360", false)
    schema:register(XMLValueType.INT, basePath .. ".wrapAnimNodes.wrapAnimNode(?)#normalizeRotationOnBaleDrop", "Normalize rotation on bale drop", 0)

    schema:register(XMLValueType.FLOAT, basePath .. ".wrapAnimNodes.wrapAnimNode(?).key(?)#wrapperRot", "Wrapper rotation")
    schema:register(XMLValueType.FLOAT, basePath .. ".wrapAnimNodes.wrapAnimNode(?).key(?)#wrapperTime", "Wrapper time")
    schema:register(XMLValueType.VECTOR_TRANS, basePath .. ".wrapAnimNodes.wrapAnimNode(?).key(?)#trans", "Trans", "0 0 0")
    schema:register(XMLValueType.VECTOR_ROT, basePath .. ".wrapAnimNodes.wrapAnimNode(?).key(?)#rot", "Rotation", "0 0 0")
    schema:register(XMLValueType.VECTOR_SCALE, basePath .. ".wrapAnimNodes.wrapAnimNode(?).key(?)#scale", "Scale", "1 1 1")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrapNodes.wrapNode(?)#node", "Wrap node")
    schema:register(XMLValueType.BOOL, basePath .. ".wrapNodes.wrapNode(?)#wrapVisibility", "Visibility while wrapping", false)
    schema:register(XMLValueType.BOOL, basePath .. ".wrapNodes.wrapNode(?)#emptyVisibility", "Visibility while empty", false)
    schema:register(XMLValueType.FLOAT, basePath .. ".wrapNodes.wrapNode(?)#maxWrapperRot", "Max. wrapper rotation")

    schema:register(XMLValueType.FLOAT, basePath .. ".wrappingState.key(?)#time", "Time of wrapping (0-1)")
    schema:register(XMLValueType.FLOAT, basePath .. ".wrappingState.key(?)#wrappingState", "Wrapping state for shader")


    schema:register(XMLValueType.FLOAT, basePath .. ".wrappingAnimationNodes#maxTime", "Max. time of animation nodes", "Wrapper anim time")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrappingAnimationNodes.key(?)#node", "Animation node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrappingAnimationNodes.key(?)#rootNode", "Reference node for rotation")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrappingAnimationNodes.key(?)#linkNode", "Node will be linked to this node while key is activated")
    schema:register(XMLValueType.FLOAT, basePath .. ".wrappingAnimationNodes.key(?)#time", "Time to activate key")
    schema:register(XMLValueType.VECTOR_TRANS, basePath .. ".wrappingAnimationNodes.key(?)#translation", "Translation of key")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrappingAnimationNodes#referenceNode", "Reference node")
    schema:register(XMLValueType.INT, basePath .. ".wrappingAnimationNodes#referenceAxis", "Reference axis", 1)
    schema:register(XMLValueType.ANGLE, basePath .. ".wrappingAnimationNodes#minRot", "Min. rotation", 0)
    schema:register(XMLValueType.ANGLE, basePath .. ".wrappingAnimationNodes#maxRot", "Max. rotation", 0)

    BaleWrapper.registerWrapperFoilAnimationXMLPaths(schema, basePath)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrappingCollisions.collision(?)#node", "Collision node")
    schema:register(XMLValueType.INT, basePath .. ".wrappingCollisions.collision(?)#activeCollisionMask", "Collision mask active")
    schema:register(XMLValueType.INT, basePath .. ".wrappingCollisions.collision(?)#inActiveCollisionMask", "Collision mask in active")

    schema:register(XMLValueType.L10N_STRING, basePath .. "#unloadBaleText", "Unload bale text", "'action_unloadRoundBale' for round bales and 'action_unloadSquareBale' for square bales")
    schema:register(XMLValueType.BOOL, basePath .. "#skipUnsupportedBales", "Skip unsupported bales (pick them up and drop them instantly)")

    SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "wrap(?)")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "start(?)")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "stop(?)")
    schema:register(XMLValueType.FLOAT, basePath .. ".sounds#wrappingEndTime", "Wrapping time to play end wrapping sound", 1)
end


---
function BaleWrapper.registerWrapperAnimationXMLPaths(schema, basePath, name)
    schema:register(XMLValueType.STRING, basePath .. ".animations." .. name .. "#animName", "Animation name", 1)
    schema:register(XMLValueType.FLOAT, basePath .. ".animations." .. name .. "#animSpeed", "Animation speed", 1)
    schema:register(XMLValueType.BOOL, basePath .. ".animations." .. name .. "#reverseAfterMove", "Reverse animation after playing", true)
    schema:register(XMLValueType.BOOL, basePath .. ".animations." .. name .. "#resetOnStart", "Reset animation on start", false)
end


---
function BaleWrapper.registerWrapperFoilAnimationXMLPaths(schema, basePath)
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrappingFoilAnimation#referenceNode", "Time reference node")
    schema:register(XMLValueType.INT, basePath .. ".wrappingFoilAnimation#referenceAxis", "Rotation axis")
    schema:register(XMLValueType.ANGLE, basePath .. ".wrappingFoilAnimation#minRot", "Min. reference rotation")
    schema:register(XMLValueType.ANGLE, basePath .. ".wrappingFoilAnimation#maxRot", "Max. reference rotation")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".wrappingFoilAnimation#clipNode", "Node which has clip assigned")
    schema:register(XMLValueType.STRING, basePath .. ".wrappingFoilAnimation#clipName", "Name of the clip to control")
end


---
function BaleWrapper.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperFromXML",               BaleWrapper.loadWrapperFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperAnimationsFromXML",     BaleWrapper.loadWrapperAnimationsFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperAnimCurveFromXML",      BaleWrapper.loadWrapperAnimCurveFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperAnimNodesFromXML",      BaleWrapper.loadWrapperAnimNodesFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperWrapNodesFromXML",      BaleWrapper.loadWrapperWrapNodesFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperStateCurveFromXML",     BaleWrapper.loadWrapperStateCurveFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperAnimationNodesFromXML", BaleWrapper.loadWrapperAnimationNodesFromXML)
    SpecializationUtil.registerFunction(vehicleType, "loadWrapperFoilAnimationFromXML",  BaleWrapper.loadWrapperFoilAnimationFromXML)

    SpecializationUtil.registerFunction(vehicleType, "baleGrabberTriggerCallback",  BaleWrapper.baleGrabberTriggerCallback)
    SpecializationUtil.registerFunction(vehicleType, "allowsGrabbingBale",          BaleWrapper.allowsGrabbingBale)
    SpecializationUtil.registerFunction(vehicleType, "pickupWrapperBale",           BaleWrapper.pickupWrapperBale)
    SpecializationUtil.registerFunction(vehicleType, "getIsBaleWrappable",          BaleWrapper.getIsBaleWrappable)
    SpecializationUtil.registerFunction(vehicleType, "getIsBaleDropAllowed",        BaleWrapper.getIsBaleDropAllowed)
    SpecializationUtil.registerFunction(vehicleType, "getIsBaleWrappingAllowed",    BaleWrapper.getIsBaleWrappingAllowed)
    SpecializationUtil.registerFunction(vehicleType, "updateWrappingState",         BaleWrapper.updateWrappingState)
    SpecializationUtil.registerFunction(vehicleType, "doStateChange",               BaleWrapper.doStateChange)
    SpecializationUtil.registerFunction(vehicleType, "updateWrapNodes",             BaleWrapper.updateWrapNodes)
    SpecializationUtil.registerFunction(vehicleType, "playMoveToWrapper",           BaleWrapper.playMoveToWrapper)
    SpecializationUtil.registerFunction(vehicleType, "setBaleWrapperType",          BaleWrapper.setBaleWrapperType)
    SpecializationUtil.registerFunction(vehicleType, "getMatchingBaleTypeIndex",    BaleWrapper.getMatchingBaleTypeIndex)
    SpecializationUtil.registerFunction(vehicleType, "setBaleWrapperAutomaticDrop", BaleWrapper.setBaleWrapperAutomaticDrop)
end


---
function BaleWrapper.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsFoldAllowed",     BaleWrapper.getIsFoldAllowed)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSelected",     BaleWrapper.getCanBeSelected)
end


---
function BaleWrapper.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onDeactivate", BaleWrapper)
    SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", BaleWrapper)
end


---Called on loading
-- @param table savegame savegame
function BaleWrapper:onLoad(savegame)
    local spec = self.spec_baleWrapper

    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.wrapper", "vehicle.baleWrapper") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.baleGrabber", "vehicle.baleWrapper.grabber") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.baleWrapper.grabber#index", "vehicle.baleWrapper.grabber#node") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.baleWrapper.grabber#index", "vehicle.baleWrapper.grabber#node") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.baleWrapper.roundBaleWrapper#baleIndex", "vehicle.baleWrapper.roundBaleWrapper#baleNode") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.baleWrapper.roundBaleWrapper#wrapperIndex", "vehicle.baleWrapper.roundBaleWrapper#wrapperNode") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.baleWrapper.squareBaleWrapper#baleIndex", "vehicle.baleWrapper.squareBaleWrapper#baleNode") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.baleWrapper.squareBaleWrapper#wrapperIndex", "vehicle.baleWrapper.squareBaleWrapper#wrapperNode") --FS17 to FS19

    local baseKey = "vehicle.baleWrapper"

    spec.roundBaleWrapper = {}
    self:loadWrapperFromXML(spec.roundBaleWrapper, self.xmlFile, baseKey, "roundBaleWrapper")

    spec.squareBaleWrapper = {}
    self:loadWrapperFromXML(spec.squareBaleWrapper, self.xmlFile, baseKey, "squareBaleWrapper")

    spec.currentWrapper = {}
    spec.currentWrapperFoldMinLimit = self.xmlFile:getValue(baseKey.."#foldMinLimit", 0)
    spec.currentWrapperFoldMaxLimit = self.xmlFile:getValue(baseKey.."#foldMaxLimit", 1)

    spec.currentWrapper = spec.roundBaleWrapper
    self:updateWrapNodes(false, true, 0)
    spec.currentWrapper = spec.squareBaleWrapper
    self:updateWrapNodes(false, true, 0)

    spec.currentBaleTypeIndex = 1

    if spec.roundBaleWrapper.baleNode ~= nil then
        self:setBaleWrapperType(true, 1)
    elseif spec.squareBaleWrapper.baleNode ~= nil then
        self:setBaleWrapperType(false, 1)
    end

    spec.baleGrabber = {}
    spec.baleGrabber.grabNode = self.xmlFile:getValue(baseKey..".grabber#node", nil, self.components, self.i3dMappings)
    spec.baleGrabber.triggerNode = self.xmlFile:getValue(baseKey..".grabber#triggerNode", nil, self.components, self.i3dMappings)
    if spec.baleGrabber.triggerNode == nil then
        Logging.xmlWarning(self.xmlFile, "Missing bale grab trigger node '%s'. This is required for all bale wrappers.", baseKey..".grabber#triggerNode")
    else
        addTrigger(spec.baleGrabber.triggerNode, "baleGrabberTriggerCallback", self)
    end

    spec.baleGrabber.nearestDistance = self.xmlFile:getValue(baseKey..".grabber#nearestDistance", 3.0)
    spec.baleGrabber.balesInTrigger = {}

    spec.baleToLoad = nil
    spec.baleToMount = nil
    spec.baleWrapperState = BaleWrapper.STATE_NONE
    spec.grabberIsMoving = false
    spec.hasBaleWrapper = true
    spec.showInvalidBaleWarning = false

    spec.automaticDrop = self.xmlFile:getValue("vehicle.baleWrapper.automaticDrop#enabled", Platform.gameplay.automaticBaleDrop)
    spec.toggleableAutomaticDrop = self.xmlFile:getValue("vehicle.baleWrapper.automaticDrop#toggleable", not Platform.gameplay.automaticBaleDrop)
    spec.toggleAutomaticDropTextPos = self.xmlFile:getValue("vehicle.baleWrapper.automaticDrop#textPos", "action_toggleAutomaticBaleDropPos", self.customEnvironment)
    spec.toggleAutomaticDropTextNeg = self.xmlFile:getValue("vehicle.baleWrapper.automaticDrop#textNeg", "action_toggleAutomaticBaleDropNeg", self.customEnvironment)

    spec.texts = {}
    spec.texts.warningFoldingWrapping = g_i18n:getText("warning_foldingNotWhileWrapping")
    spec.texts.warningBaleNotSupported = g_i18n:getText("warning_baleNotSupported")

    ObjectChangeUtil.updateObjectChanges(self.xmlFile, baseKey .. ".wrappingAnimationConfigurations.wrappingAnimationConfiguration", self.configurations["wrappingAnimation"] or 1, self.components, self)
end


---
function BaleWrapper:onPostLoad(savegame)
    local spec = self.spec_baleWrapper

    if savegame ~= nil and not savegame.resetVehicles then
        local filename = savegame.xmlFile:getValue(savegame.key..".baleWrapper.bale#filename")
        if filename ~= nil then
            local baleToLoad = {}
            baleToLoad.filename = NetworkUtil.convertFromNetworkFilename(filename)
            baleToLoad.wrapperTime = savegame.xmlFile:getValue(savegame.key..".baleWrapper#wrapperTime", 0)
            baleToLoad.translation = {0, 0, 0}
            baleToLoad.rotation = {0, 0, 0}
            baleToLoad.attributes = {}
            Bale.loadBaleAttributesFromXMLFile(baleToLoad.attributes, savegame.xmlFile, savegame.key..".baleWrapper.bale", savegame.resetVehicles)

            spec.baleToLoad = baleToLoad
        end
    end

    if self.configurations["wrappingColor"] ~= nil then
        self:applyBaseMaterialConfiguration(self.xmlFile, "wrappingColor", self.configurations["wrappingColor"])
    end
end


---
function BaleWrapper:loadWrapperFromXML(wrapper, xmlFile, baseKey, wrapperName)
    local spec = self.spec_baleWrapper
    local isRoundBaleWrapper = wrapper == spec.roundBaleWrapper

    local wrappingAnimationConfig = Utils.getNoNil(self.configurations["wrappingAnimation"], 1)
    local configKey = string.format("vehicle.baleWrapper.wrappingAnimationConfigurations.wrappingAnimationConfiguration(%d)", wrappingAnimationConfig - 1)

    self:loadWrapperAnimationsFromXML(wrapper, xmlFile, baseKey, configKey, "." .. wrapperName .. ".animations")

    wrapper.defaultAnimations = wrapper.animations

    baseKey = baseKey .. "." .. wrapperName

    wrapper.baleNode = xmlFile:getValue(baseKey .. "#baleNode", nil, self.components, self.i3dMappings)
    wrapper.wrapperNode = xmlFile:getValue(baseKey .. "#wrapperNode", nil, self.components, self.i3dMappings)
    wrapper.wrapperRotAxis = xmlFile:getValue(baseKey.."#wrapperRotAxis", 2)

    wrapper.animTime = xmlFile:getValue(baseKey .. "#wrappingTime", 5) * 1000
    wrapper.currentTime = 0
    wrapper.currentBale = nil

    wrapper.allowedBaleTypes = {}
    xmlFile:iterate(baseKey .. ".baleTypes.baleType", function(index, key)
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#fillType") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#wrapperBaleFilename") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#minBaleDiameter", key.."#diameter") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#maxBaleDiameter", key.."#diameter") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#minBaleWidth", key.."#width") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#maxBaleWidth", key.."#width") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#minBaleHeight", key.."#height") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#maxBaleHeight", key.."#height") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#minBaleLength", key.."#length") --FS19 to FS22
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#maxBaleLength", key.."#length") --FS19 to FS22

        local baleType = {}
        baleType.diameter = MathUtil.round(xmlFile:getValue(key.."#diameter", 0), 2)
        baleType.width = MathUtil.round(xmlFile:getValue(key.."#width", 0), 2)
        baleType.height = MathUtil.round(xmlFile:getValue(key.."#height", 0), 2)
        baleType.length = MathUtil.round(xmlFile:getValue(key.."#length", 0), 2)

        baleType.wrapDiffuse = xmlFile:getValue(key..".textures#diffuse")
        if baleType.wrapDiffuse ~= nil then
            baleType.wrapDiffuse = Utils.getFilename(baleType.wrapDiffuse, self.baseDirectory)
        end

        baleType.wrapNormal = xmlFile:getValue(key..".textures#normal")
        if baleType.wrapNormal ~= nil then
            baleType.wrapNormal = Utils.getFilename(baleType.wrapNormal, self.baseDirectory)
        end

        self:loadWrapperAnimationsFromXML(baleType, xmlFile, key, string.format("%s.%s.baleTypes.baleType(%d)", configKey, wrapperName, index - 1), ".animations", wrapper.animations)
        self:loadWrapperFoilAnimationFromXML(baleType, xmlFile, key)

        baleType.changeObjects = {}
        ObjectChangeUtil.loadObjectChangeFromXML(self.xmlFile, key, baleType.changeObjects, self.components, self)

        baleType.skipWrapping = xmlFile:getValue(key.."#skipWrapping", false)

        baleType.forceWhileFolding = xmlFile:getValue(key.."#forceWhileFolding", false)
        if baleType.forceWhileFolding then
            spec.foldedBaleType = {isRoundBaleWrapper=isRoundBaleWrapper, baleTypeIndex=index}
        end

        self:loadWrapperStateCurveFromXML(baleType, xmlFile, key)

        table.insert(wrapper.allowedBaleTypes, baleType)
    end)

    self:loadWrapperAnimCurveFromXML(wrapper, xmlFile, baseKey)
    self:loadWrapperAnimNodesFromXML(wrapper, xmlFile, baseKey)

    self:loadWrapperWrapNodesFromXML(wrapper, xmlFile, baseKey)
    self:loadWrapperStateCurveFromXML(wrapper, xmlFile, baseKey)
    self:loadWrapperAnimationNodesFromXML(wrapper, xmlFile, baseKey, wrapper.animTime)
    self:loadWrapperFoilAnimationFromXML(wrapper, xmlFile, baseKey, true)
    wrapper.wrappingFoilAnimationDefault = wrapper.wrappingFoilAnimation

    local defaultText = (isRoundBaleWrapper and "action_unloadRoundBale") or "action_unloadSquareBale"
    wrapper.unloadBaleText = xmlFile:getValue(baseKey .. "#unloadBaleText", defaultText, self.customEnvironment)

    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, baseKey.."#skipWrappingFillTypes", baseKey.."#skipUnsupportedBales") --FS19 to FS22
    wrapper.skipUnsupportedBales = self.xmlFile:getValue(baseKey.."#skipUnsupportedBales", false)

    if self.isClient then
        wrapper.samples = {}
        wrapper.samples.wrap   = g_soundManager:loadSamplesFromXML(self.xmlFile, baseKey..".sounds", "wrap", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
        wrapper.samples.start  = g_soundManager:loadSamplesFromXML(self.xmlFile, baseKey..".sounds", "start", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        wrapper.samples.stop   = g_soundManager:loadSamplesFromXML(self.xmlFile, baseKey..".sounds", "stop", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        wrapper.wrappingSoundEndTime = xmlFile:getValue(baseKey .. ".sounds#wrappingEndTime", 1)
    end
end


---
function BaleWrapper:loadWrapperAnimationsFromXML(target, xmlFile, baseKey, configKey, animationsKey, parentAnimations)
    target.animations = {}
    if parentAnimations ~= nil then
        setmetatable(target.animations, {__index = parentAnimations})
    end

    for i=1, #BaleWrapper.ANIMATION_NAMES do
        local animType = BaleWrapper.ANIMATION_NAMES[i]

        local key = baseKey .. animationsKey .. "." .. animType
        local configTypeKey = configKey .. animationsKey .. "." .. animType
        if xmlFile:hasProperty(configTypeKey) then
            key = configTypeKey
        end

        local anim = {}
        anim.animName = xmlFile:getValue(key .. "#animName")
        anim.animSpeed = xmlFile:getValue(key .. "#animSpeed", 1)
        anim.reverseAfterMove = xmlFile:getValue(key .. "#reverseAfterMove", true)

        if xmlFile:getValue(key .. "#resetOnStart", false) then
            self:playAnimation(anim.animName, -1, 0.1, true)
            AnimatedVehicle.updateAnimationByName(self, anim.animName, 9999999, true)
        end

        if parentAnimations == nil or anim.animName ~= nil then
            target.animations[animType] = anim
        end
    end
end


---
function BaleWrapper:loadWrapperAnimCurveFromXML(target, xmlFile, baseKey)
    target.animCurve = AnimCurve.new(linearInterpolatorN)
    xmlFile:iterate(baseKey .. "wrapperAnimation.key", function(index, key)
        local t = xmlFile:getValue(key.."#time")
        local baleX, baleY, baleZ = xmlFile:getValue(key.."#baleRot")
        if baleX == nil or baleY == nil or baleZ == nil then
            return false
        end

        local wrapperX, wrapperY, wrapperZ = xmlFile:getValue(key.."#wrapperRot", "0 0 0")
        target.animCurve:addKeyframe({baleX, baleY, baleZ, wrapperX, wrapperY, wrapperZ, time = t})
    end)
end


---
function BaleWrapper:loadWrapperAnimNodesFromXML(target, xmlFile, baseKey)
    target.wrapAnimNodes = {}
    xmlFile:iterate(baseKey .. ".wrapAnimNodes.wrapAnimNode", function(index, key)
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#index", key.."#node") --FS19 to FS22

        local wrapAnimNode = {}
        wrapAnimNode.nodeId = xmlFile:getValue(key.."#node", nil, self.components, self.i3dMappings)
        if wrapAnimNode.nodeId ~= nil then
            wrapAnimNode.useWrapperRot = false
            wrapAnimNode.animCurve = AnimCurve.new(linearInterpolatorN)

            local numKeyframes = 0
            xmlFile:iterate(key..".key", function(_, nodeKey)
                local wrapperRot = xmlFile:getValue(nodeKey.."#wrapperRot")
                local wrapperTime = xmlFile:getValue(nodeKey.."#wrapperTime")
                if wrapperRot == nil and wrapperTime == nil then
                    return false
                end
                wrapAnimNode.useWrapperRot = wrapperRot ~= nil

                local x, y, z = xmlFile:getValue(nodeKey.."#trans", "0 0 0")
                local rx, ry, rz = xmlFile:getValue(nodeKey.."#rot", "0 0 0")
                local sx, sy, sz = xmlFile:getValue(nodeKey.."#scale", "1 1 1")

                if wrapperRot ~= nil then
                    wrapAnimNode.animCurve:addKeyframe({x, y, z, rx, ry, rz, sx,sy,sz, time = math.rad(wrapperRot)})
                else
                    wrapAnimNode.animCurve:addKeyframe({x, y, z, rx, ry, rz, sx,sy,sz, time = wrapperTime})
                end

                numKeyframes = numKeyframes + 1
            end)

            if numKeyframes > 0 then
                wrapAnimNode.repeatWrapperRot = xmlFile:getValue(key.."#repeatWrapperRot", false)
                wrapAnimNode.normalizeRotationOnBaleDrop = xmlFile:getValue(key.."#normalizeRotationOnBaleDrop", 0)
                table.insert(target.wrapAnimNodes, wrapAnimNode)
            end
        end
    end)
end


---
function BaleWrapper:loadWrapperWrapNodesFromXML(target, xmlFile, baseKey)
    target.wrapNodes = {}
    xmlFile:iterate(baseKey .. ".wrapNodes.wrapNode", function(index, key)
        XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key.."#index", key.."#node") --FS19 to FS21

        local wrapNode = {}
        wrapNode.nodeId = xmlFile:getValue(key.."#node", nil, self.components, self.i3dMappings)
        wrapNode.wrapVisibility = xmlFile:getValue(key.."#wrapVisibility", false)
        wrapNode.emptyVisibility = xmlFile:getValue(key.."#emptyVisibility", false)
        if wrapNode.nodeId ~= nil and (wrapNode.wrapVisibility or wrapNode.emptyVisibility) then
            wrapNode.maxWrapperRot = xmlFile:getValue(key.."#maxWrapperRot", math.huge)
            table.insert(target.wrapNodes, wrapNode)
        end
    end)
end


---
function BaleWrapper:loadWrapperStateCurveFromXML(target, xmlFile, baseKey)
    target.wrappingStateCurve = AnimCurve.new(linearInterpolator1)
    xmlFile:iterate(baseKey .. ".wrappingState.key", function(index, key)
        local t = xmlFile:getValue(key.."#time")
        local wrappingState = xmlFile:getValue(key.."#wrappingState")

        target.wrappingStateCurve:addKeyframe({wrappingState, time = t})
    end)

    if #target.wrappingStateCurve.keyframes == 0 then
        target.wrappingStateCurve = nil
    end
end


---
function BaleWrapper:loadWrapperAnimationNodesFromXML(target, xmlFile, baseKey, animTime)
    local maxTime = xmlFile:getValue(baseKey .. ".wrappingAnimationNodes#maxTime", animTime / 1000)

    target.wrappingAnimationNodes = {}
    target.wrappingAnimationNodes.nodes = {}
    target.wrappingAnimationNodes.nodeToRootNode = {}

    xmlFile:iterate(baseKey ..".wrappingAnimationNodes.key", function(index, wrappingAnimationNodeKey)
        local time = xmlFile:getValue(wrappingAnimationNodeKey.."#time")
        local nodeId = xmlFile:getValue(wrappingAnimationNodeKey.."#node", nil, self.components, self.i3dMappings)
        local rootNode = xmlFile:getValue(wrappingAnimationNodeKey.."#rootNode", nil, self.components, self.i3dMappings)
        local linkNode = xmlFile:getValue(wrappingAnimationNodeKey.."#linkNode", nil, self.components, self.i3dMappings)

        if time ~= nil and nodeId ~= nil then
            local entry = {}
            entry.time = time / maxTime
            entry.nodeId = nodeId
            entry.linkNode = linkNode
            entry.parent = getParent(nodeId)

            entry.translation = xmlFile:getValue(wrappingAnimationNodeKey.."#translation", nil, true)

            if rootNode ~= nil then
                target.wrappingAnimationNodes.nodeToRootNode[nodeId] = rootNode
            end

            table.insert(target.wrappingAnimationNodes.nodes, entry)
        end
    end)

    -- set start translations in a second loop since we link some of the nodes and this would break the index paths
    for j = 1, #target.wrappingAnimationNodes.nodes do
        local wrappingAnimationNode = target.wrappingAnimationNodes.nodes[j]
        if wrappingAnimationNode.time == 0 then
            setTranslation(wrappingAnimationNode.nodeId, unpack(wrappingAnimationNode.translation))

            if wrappingAnimationNode.linkNode ~= nil then
                local x, y, z = localToWorld(wrappingAnimationNode.parent, unpack(wrappingAnimationNode.translation))
                link(wrappingAnimationNode.linkNode, wrappingAnimationNode.nodeId)
                setWorldTranslation(wrappingAnimationNode.nodeId, x, y, z)
            end
        end
    end

    target.wrappingAnimationNodes.referenceNode = xmlFile:getValue(baseKey .. ".wrappingAnimationNodes#referenceNode", nil, self.components, self.i3dMappings)
    target.wrappingAnimationNodes.referenceAxis = xmlFile:getValue(baseKey .. ".wrappingAnimationNodes#referenceAxis", 2)
    target.wrappingAnimationNodes.referenceMinRot = xmlFile:getValue(baseKey .. ".wrappingAnimationNodes#minRot", 0)
    target.wrappingAnimationNodes.referenceMaxRot = xmlFile:getValue(baseKey .. ".wrappingAnimationNodes#maxRot", 0)
    if target.wrappingAnimationNodes.referenceNode ~= nil then
        target.wrappingAnimationNodes.referenceNodeRotation = {getRotation(target.wrappingAnimationNodes.referenceNode)}
    end
    target.wrappingAnimationNodes.lastTime = -1

    target.wrappingAnimationNodes.currentIndex = 0
end


---
function BaleWrapper:loadWrapperFoilAnimationFromXML(target, xmlFile, baseKey, isDefault)
    local wrappingFoilAnimation = {}
    wrappingFoilAnimation.referenceNode = xmlFile:getValue(baseKey .. ".wrappingFoilAnimation#referenceNode", nil, self.components, self.i3dMappings)
    if wrappingFoilAnimation.referenceNode ~= nil then
        wrappingFoilAnimation.referenceAxis = xmlFile:getValue(baseKey .. ".wrappingFoilAnimation#referenceAxis", 2)
        wrappingFoilAnimation.referenceMinRot = xmlFile:getValue(baseKey .. ".wrappingFoilAnimation#minRot", 0)
        wrappingFoilAnimation.referenceMaxRot = xmlFile:getValue(baseKey .. ".wrappingFoilAnimation#maxRot", 0)
        wrappingFoilAnimation.referenceNodeRotation = {0, 0, 0}

        wrappingFoilAnimation.clipNode = xmlFile:getValue(baseKey .. ".wrappingFoilAnimation#clipNode", nil, self.components, self.i3dMappings)
        if wrappingFoilAnimation.clipNode ~= nil then
            wrappingFoilAnimation.animationClip = xmlFile:getValue(baseKey .. ".wrappingFoilAnimation#clipName")
            if wrappingFoilAnimation.animationClip ~= nil then
                wrappingFoilAnimation.animationCharSet = getAnimCharacterSet(wrappingFoilAnimation.clipNode)
                wrappingFoilAnimation.animationClipIndex = getAnimClipIndex(wrappingFoilAnimation.animationCharSet, wrappingFoilAnimation.animationClip)
                if wrappingFoilAnimation.animationClipIndex >= 0 then
                    wrappingFoilAnimation.animationClipDuration = getAnimClipDuration(wrappingFoilAnimation.animationCharSet, wrappingFoilAnimation.animationClipIndex)

                    if isDefault then
                        clearAnimTrackClip(wrappingFoilAnimation.animationCharSet, 0)
                        assignAnimTrackClip(wrappingFoilAnimation.animationCharSet, 0, wrappingFoilAnimation.animationClipIndex)

                        enableAnimTrack(wrappingFoilAnimation.animationCharSet, 0)
                        setAnimTrackTime(wrappingFoilAnimation.animationCharSet, 0, 0, true)
                        disableAnimTrack(wrappingFoilAnimation.animationCharSet, 0)
                    end

                    wrappingFoilAnimation.lastTime = 0

                    target.wrappingFoilAnimation = wrappingFoilAnimation
                else
                    Logging.xmlWarning(self.xmlFile, "Unable to find animation clip '%s' on node '%s' in '%s'", wrappingFoilAnimation.animationClip, getName(wrappingFoilAnimation.clipNode), baseKey..".wrappingFoilAnimation")
                end
            else
                Logging.xmlWarning(self.xmlFile, "Missing clipName for foil animation '%s'", baseKey..".wrappingFoilAnimation")
            end
        else
            Logging.xmlWarning(self.xmlFile, "Missing clipNode for foil animation '%s'", baseKey..".wrappingFoilAnimation")
        end
    end
end


---Called after vehicle was added to phyiscs
-- @param table savegame savegame
function BaleWrapper:onLoadFinished(savegame)
    local spec = self.spec_baleWrapper

    if spec.baleToLoad ~= nil then
        local v = spec.baleToLoad
        spec.baleToLoad = nil

        local baleObject = Bale.new(self.isServer, self.isClient)
        local x, y, z = unpack(v.translation)
        local rx, ry, rz = unpack(v.rotation)
        if baleObject:loadFromConfigXML(v.filename, x, y, z, rx, ry, rz) then
            baleObject:applyBaleAttributes(v.attributes)
            baleObject:register()

            if baleObject.nodeId ~= nil and baleObject.nodeId ~= 0 then
                self:doStateChange(BaleWrapper.CHANGE_GRAB_BALE, NetworkUtil.getObjectId(baleObject))
                self:doStateChange(BaleWrapper.CHANGE_DROP_BALE_AT_GRABBER)

                self:doStateChange(BaleWrapper.CHANGE_WRAPPING_START)
                spec.currentWrapper.currentTime = v.wrapperTime

                local wrapperState = math.min(v.wrapperTime / spec.currentWrapper.animTime, 1)
                baleObject:setWrappingState(wrapperState)

                local wrapAnimation = spec.currentWrapper.animations["wrapBale"]
                local wrappingTime = spec.currentWrapper.currentTime / spec.currentWrapper.animTime
                self:updateWrappingState(wrappingTime)

                AnimatedVehicle.updateAnimations(self, 99999999, true)

                if wrappingTime < 1 then
                    self:setAnimationTime(wrapAnimation.animName, wrappingTime, true)
                    self:playAnimation(wrapAnimation.animName, wrapAnimation.animSpeed, wrappingTime, true)
                else
                    self:doStateChange(BaleWrapper.CHANGE_WRAPPING_BALE_FINSIHED)
                    self:setAnimationTime(wrapAnimation.animName, wrappingTime, true)
                    spec.setWrappingStateFinished = false
                end
            end
        end
    end
end


---Called on deleting
function BaleWrapper:onDelete()
    local spec = self.spec_baleWrapper

    local baleId
    if spec.currentWrapper ~= nil and spec.currentWrapper.currentBale ~= nil then
        baleId = spec.currentWrapper.currentBale
    end
    if spec.baleGrabber ~= nil and spec.baleGrabber.currentBale ~= nil then
        baleId = spec.baleGrabber.currentBale
    end
    if baleId ~= nil then
        local bale = NetworkUtil.getObject(baleId)
        if bale ~= nil then
            if self.isServer then
                if self.isReconfigurating == nil or not self.isReconfigurating then
                    -- unmount bale if wrapper is sold
                    bale:unmountKinematic()
                    bale:setCanBeSold(true)
                else
                    -- delete bale if reloaded since a new bale is spawned on load
                    bale:delete()
                end
            else
                -- on client side just unmount so the baleId is not delete before the bale object is deleted
                bale:unmountKinematic()
                bale:setCanBeSold(true)
            end
        end
    end

    if spec.baleGrabber ~= nil and spec.baleGrabber.triggerNode ~= nil then
        removeTrigger(spec.baleGrabber.triggerNode)
    end

    if spec.roundBaleWrapper ~= nil then
        g_soundManager:deleteSamples(spec.roundBaleWrapper.samples.wrap)
        g_soundManager:deleteSamples(spec.roundBaleWrapper.samples.start)
        g_soundManager:deleteSamples(spec.roundBaleWrapper.samples.stop)
    end
    if spec.squareBaleWrapper ~= nil then
        g_soundManager:deleteSamples(spec.squareBaleWrapper.samples.wrap)
        g_soundManager:deleteSamples(spec.squareBaleWrapper.samples.start)
        g_soundManager:deleteSamples(spec.squareBaleWrapper.samples.stop)
    end
end


---
function BaleWrapper:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_baleWrapper

    local baleServerId = spec.baleGrabber.currentBale
    if baleServerId == nil then
        baleServerId = spec.currentWrapper.currentBale
    end

    xmlFile:setValue(key .. "#wrapperTime", spec.currentWrapper.currentTime)

    if baleServerId ~= nil then
        local bale = NetworkUtil.getObject(baleServerId)
        if bale ~= nil then
            bale:saveToXMLFile(xmlFile, key .. ".bale")
        end
    end
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function BaleWrapper:onReadStream(streamId, connection)
    if connection:getIsServer() then
        local spec = self.spec_baleWrapper

        local isRoundBaleWrapper = streamReadBool(streamId)
        local baleTypeIndex = streamReadUIntN(streamId, 8)

        self:setBaleWrapperType(isRoundBaleWrapper, baleTypeIndex)

        local wrapperState = streamReadUIntN(streamId, BaleWrapper.STATE_NUM_BITS)
        if wrapperState >= BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER then
            local baleServerId
            if wrapperState ~= BaleWrapper.STATE_WRAPPER_RESETTING_PLATFORM then
                baleServerId = NetworkUtil.readNodeObjectId(streamId)
            end

            if wrapperState == BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER then
                self:doStateChange(BaleWrapper.CHANGE_GRAB_BALE, baleServerId)
                AnimatedVehicle.updateAnimations(self, 99999999, true)
            elseif wrapperState == BaleWrapper.STATE_MOVING_GRABBER_TO_WORK then
                self.baleGrabber.currentBale = baleServerId

                self:doStateChange(BaleWrapper.CHANGE_DROP_BALE_AT_GRABBER)
                AnimatedVehicle.updateAnimations(self, 99999999, true)

            elseif wrapperState ~= BaleWrapper.STATE_WRAPPER_RESETTING_PLATFORM then
                self:doStateChange(BaleWrapper.CHANGE_GRAB_BALE, baleServerId)
                AnimatedVehicle.updateAnimations(self, 99999999, true)

                spec.currentWrapper.currentBale = baleServerId
                self:doStateChange(BaleWrapper.CHANGE_DROP_BALE_AT_GRABBER)
                AnimatedVehicle.updateAnimations(self, 99999999, true)

                self:updateWrapNodes(true, false, 0)

                if wrapperState == BaleWrapper.STATE_WRAPPER_WRAPPING_BALE then
                    self:doStateChange(BaleWrapper.CHANGE_WRAPPING_START)

                    local wrapperTime = streamReadFloat32(streamId)
                    spec.currentWrapper.currentTime = wrapperTime

                    local wrapAnimation = spec.currentWrapper.animations["wrapBale"]
                    local wrappingTime = spec.currentWrapper.currentTime / spec.currentWrapper.animTime
                    self:setAnimationStopTime(wrapAnimation.animName, wrappingTime)
                    AnimatedVehicle.updateAnimationByName(self, wrapAnimation.animName, 9999999, true)
                    self:updateWrappingState(wrappingTime, true)

                    if wrappingTime < 1 then
                        self:playAnimation(wrapAnimation.animName, wrapAnimation.animSpeed, self:getAnimationTime(wrapAnimation.animName), true, false)
                    end
                else
                    local wrapAnimation = spec.currentWrapper.animations["wrapBale"]
                    if wrapAnimation.animName ~= nil then
                        self:playAnimation(wrapAnimation.animName, wrapAnimation.animSpeed, nil, true)
                        AnimatedVehicle.updateAnimationByName(self, wrapAnimation.animName, 9999999, true)
                    end

                    spec.currentWrapper.currentTime = spec.currentWrapper.animTime
                    self:updateWrappingState(1, true)

                    self:doStateChange(BaleWrapper.CHANGE_WRAPPING_BALE_FINSIHED)
                    AnimatedVehicle.updateAnimations(self, 99999999, true)
                    if wrapperState >= BaleWrapper.STATE_WRAPPER_DROPPING_BALE then
                        self:doStateChange(BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE)
                        AnimatedVehicle.updateAnimations(self, 99999999, true)
                    end
                end
            else
                -- simply set the state but do nothing else
                spec.baleWrapperState = BaleWrapper.STATE_WRAPPER_RESETTING_PLATFORM
            end
        end
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function BaleWrapper:onWriteStream(streamId, connection)
    if not connection:getIsServer() then
        local spec = self.spec_baleWrapper

        streamWriteBool(streamId, spec.currentWrapper == spec.roundBaleWrapper)
        streamWriteUIntN(streamId, spec.currentBaleTypeIndex, 8)

        local wrapperState = spec.baleWrapperState
        streamWriteUIntN(streamId, wrapperState, BaleWrapper.STATE_NUM_BITS)

        if wrapperState >= BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER and wrapperState ~= BaleWrapper.STATE_WRAPPER_RESETTING_PLATFORM then
            if wrapperState == BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER then
                NetworkUtil.writeNodeObjectId(streamId, spec.baleGrabber.currentBale)
            else
                NetworkUtil.writeNodeObjectId(streamId, spec.currentWrapper.currentBale)
            end
        end
        if wrapperState == BaleWrapper.STATE_WRAPPER_WRAPPING_BALE then
            streamWriteFloat32(streamId, spec.currentWrapper.currentTime)
        end
    end
end


---Called on update
-- @param float dt time since last call in ms
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function BaleWrapper:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_baleWrapper

    if spec.baleToMount ~= nil then
        local bale = NetworkUtil.getObject(spec.baleToMount.serverId)
        if bale ~= nil then
            local x,y,z = unpack(spec.baleToMount.trans)
            local rx,ry,rz = unpack(spec.baleToMount.rot)
            bale:mountKinematic(self, spec.baleToMount.linkNode, x,y,z, rx,ry,rz)
            bale:setCanBeSold(false)
            spec.baleToMount = nil

            if spec.baleWrapperState == BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER then
                self:playMoveToWrapper(bale)
            end
        end
    end

    if spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_WRAPPING_BALE then
        local wrapper = spec.currentWrapper

        wrapper.currentTime = math.min(wrapper.currentTime + dt, spec.currentWrapper.animTime)
        local wrappingTime = wrapper.currentTime / wrapper.animTime
        self:updateWrappingState(wrappingTime)
        self:raiseActive()

        if self.isClient then
            if wrapper.wrappingSoundEndTime <= wrappingTime then
                if g_soundManager:getIsSamplePlaying(wrapper.samples.wrap[1]) then
                    g_soundManager:stopSamples(wrapper.samples.wrap)
                    g_soundManager:playSamples(wrapper.samples.stop)
                end
            else
                if not g_soundManager:getIsSamplePlaying(wrapper.samples.wrap[1]) then
                    g_soundManager:playSamples(wrapper.samples.wrap)
                end
            end
        end
    end
end


---Called on update tick
-- @param float dt time since last call in ms
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function BaleWrapper:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_baleWrapper

    spec.showInvalidBaleWarning = false

    if self:allowsGrabbingBale() then
        if spec.baleGrabber.grabNode ~= nil and spec.baleGrabber.currentBale == nil then
            -- find nearest bale
            local nearestBaleWrappable, nearestBale, nearestBaleTypeIndex = BaleWrapper.getBaleInRange(self, spec.baleGrabber.grabNode, spec.baleGrabber.nearestDistance)
            if nearestBale then
                if nearestBaleWrappable ~= nil or (nearestBale.isRoundbale and spec.roundBaleWrapper.skipUnsupportedBales or spec.squareBaleWrapper.skipUnsupportedBales) then
                    if self.isServer then
                        self:pickupWrapperBale(nearestBaleWrappable or nearestBale, nearestBaleTypeIndex)
                    end
                else
                    if self.isClient then
                        if nearestBale and spec.lastDroppedBale ~= nearestBale then
                            spec.showInvalidBaleWarning = true
                        end
                    end
                end
            end
        end
    end
    if self.isServer then
        if spec.baleWrapperState ~= BaleWrapper.STATE_NONE then
            if spec.baleWrapperState == BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER then
                if not self:getIsAnimationPlaying(spec.currentWrapper.animations["moveToWrapper"].animName) then
                    g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_DROP_BALE_AT_GRABBER), true, nil, self)
                end
            elseif spec.baleWrapperState == BaleWrapper.STATE_MOVING_GRABBER_TO_WORK then
                if not self:getIsAnimationPlaying(spec.currentWrapper.animations["moveToWrapper"].animName) then
                    local bale = NetworkUtil.getObject(spec.currentWrapper.currentBale)
                    if bale ~= nil and not bale.supportsWrapping then
                        g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE), true, nil, self)
                    else
                        if self:getIsBaleWrappingAllowed() then
                            g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPING_START), true, nil, self)
                        end
                    end
                end
            elseif spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_DROPPING_BALE then
                if not self:getIsAnimationPlaying(spec.currentWrapper.animations["dropFromWrapper"].animName) then
                    g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPER_BALE_DROPPED), true, nil, self)
                end
            elseif spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_RESETTING_PLATFORM then
                if not self:getIsAnimationPlaying(spec.currentWrapper.animations["resetAfterDrop"].animName) then
                    g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPER_PLATFORM_RESET), true, nil, self)
                end
            end
        end
    end

    if spec.automaticDrop or self:getIsAIActive() then
        local isPowered, _ = self:getIsPowered()
        if isPowered then
            if spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
                local dropIsAllowed, warning = self:getIsBaleDropAllowed()
                if dropIsAllowed then
                    if self.isServer then
                        self:doStateChange(BaleWrapper.CHANGE_BUTTON_EMPTY)
                    end
                elseif warning ~= nil and isActiveForInputIgnoreSelection then
                    if self.isClient then
                        g_currentMission:showBlinkingWarning(warning, 2000)
                    end
                end
            end
        end
    end

    BaleWrapper.updateActionEvents(self)

    if spec.setWrappingStateFinished then
        g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPING_BALE_FINSIHED), true, nil, self)
        spec.setWrappingStateFinished = false
    end
end


---Called on draw
function BaleWrapper:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isClient then
        local spec = self.spec_baleWrapper
        if spec.showInvalidBaleWarning then
            g_currentMission:showBlinkingWarning(spec.texts.warningBaleNotSupported, 500)
        end
    end
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherActorId id of other actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
-- @param integer otherShapeId id of other shape
function BaleWrapper:baleGrabberTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if otherId ~= 0 and getRigidBodyType(otherId) == RigidBodyType.DYNAMIC then
        local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil then
            if object:isa(Bale) then
                local spec = self.spec_baleWrapper
                if onEnter then
                    spec.baleGrabber.balesInTrigger[object] = Utils.getNoNil(spec.baleGrabber.balesInTrigger[object], 0) + 1
                elseif onLeave then
                    if spec.baleGrabber.balesInTrigger[object] ~= nil then
                        spec.baleGrabber.balesInTrigger[object] = math.max(0, spec.baleGrabber.balesInTrigger[object] - 1)
                        if spec.baleGrabber.balesInTrigger[object] == 0 then
                            spec.baleGrabber.balesInTrigger[object] = nil
                        end
                    end
                end
            end
        end
    end
end


---Returns if allows bale grabbing
-- @return boolean allows allows bale grabbing
function BaleWrapper:allowsGrabbingBale()
    local spec = self.spec_baleWrapper
    local specFoldable = self.spec_foldable
    if specFoldable ~= nil then
        if specFoldable.foldAnimTime ~= nil and (specFoldable.foldAnimTime > spec.currentWrapperFoldMaxLimit or specFoldable.foldAnimTime < spec.currentWrapperFoldMinLimit) then
            return false
        end
    end

    if spec.baleToLoad ~= nil then
        return false
    end

    return spec.baleWrapperState == BaleWrapper.STATE_NONE
end


---Update bale wrap nodes
-- @param boolean isWrapping is wrapping
-- @param boolean isEmpty is empty
-- @param float t animation time
-- @param float wrapperRot rotation of wrapper
function BaleWrapper:updateWrapNodes(isWrapping, isEmpty, t, wrapperRot)
    local spec = self.spec_baleWrapper

    if wrapperRot == nil then
        wrapperRot = 0
    end

    for _, wrapNode in pairs(spec.currentWrapper.wrapNodes) do
        local doShow = true
        if wrapNode.maxWrapperRot ~= nil then
            doShow = wrapperRot < wrapNode.maxWrapperRot
        end
        setVisibility(wrapNode.nodeId, doShow and ((isWrapping and wrapNode.wrapVisibility) or (isEmpty and wrapNode.emptyVisibility)))
    end

    if isWrapping then
        local wrapperRotRepeat = MathUtil.sign(wrapperRot) * (wrapperRot % math.pi)
        if wrapperRotRepeat < 0 then
            wrapperRotRepeat = wrapperRotRepeat + math.pi
        end

        for _,wrapAnimNode in pairs(spec.currentWrapper.wrapAnimNodes) do
            local v
            if wrapAnimNode.useWrapperRot then
                local rot = wrapperRot
                if wrapAnimNode.repeatWrapperRot then
                    rot = wrapperRotRepeat
                end
                v = wrapAnimNode.animCurve:get(rot)
            else
                v = wrapAnimNode.animCurve:get(t)
            end
            if v ~= nil then
                setTranslation(wrapAnimNode.nodeId, v[1], v[2], v[3])
                setRotation(wrapAnimNode.nodeId, v[4], v[5], v[6])
                setScale(wrapAnimNode.nodeId, v[7], v[8], v[9])
            end
        end
    else
        if not isEmpty then
            for _,wrapAnimNode in pairs(spec.currentWrapper.wrapAnimNodes) do
                if wrapAnimNode.normalizeRotationOnBaleDrop ~= 0 then
                    local rot = { getRotation(wrapAnimNode.nodeId) }
                    for i=1,3 do
                        rot[i] = wrapAnimNode.normalizeRotationOnBaleDrop * MathUtil.sign(rot[i]) * ( rot[i] % (2*math.pi) )
                    end
                    setRotation(wrapAnimNode.nodeId, rot[1],rot[2],rot[3])
                end
            end
        end
    end
end


---Update wrapping state
-- @param float t animation time
-- @param boolean noEventSend no event send
function BaleWrapper:updateWrappingState(wrappingTime, noEventSend)
    local spec = self.spec_baleWrapper
    local wrapper = spec.currentWrapper

    local foilTime = 0
    if wrapper.wrappingFoilAnimation ~= nil then
        local wrappingFoilAnimation = wrapper.wrappingFoilAnimation

        wrappingFoilAnimation.referenceNodeRotation[1], wrappingFoilAnimation.referenceNodeRotation[2], wrappingFoilAnimation.referenceNodeRotation[3] = getRotation(wrappingFoilAnimation.referenceNode)
        local rotation = wrappingFoilAnimation.referenceNodeRotation[wrappingFoilAnimation.referenceAxis]
        foilTime = (rotation - wrappingFoilAnimation.referenceMinRot) / (wrappingFoilAnimation.referenceMaxRot - wrappingFoilAnimation.referenceMinRot)
        if foilTime > 0 and foilTime < 1 then
            if foilTime ~= wrappingFoilAnimation.lastTime then
                local oldClipIndex = getAnimTrackAssignedClip(wrappingFoilAnimation.animationCharSet, 0)
                if oldClipIndex ~= wrappingFoilAnimation.animationClipIndex then
                    clearAnimTrackClip(wrappingFoilAnimation.animationCharSet, 0)
                    assignAnimTrackClip(wrappingFoilAnimation.animationCharSet, 0, wrappingFoilAnimation.animationClipIndex)
                end

                enableAnimTrack(wrappingFoilAnimation.animationCharSet, 0)
                setAnimTrackTime(wrappingFoilAnimation.animationCharSet, 0, foilTime * wrappingFoilAnimation.animationClipDuration, true)
                disableAnimTrack(wrappingFoilAnimation.animationCharSet, 0)

                wrappingFoilAnimation.lastTime = foilTime
            end
        end
    end

    local nodesTime = 0
    if wrapper.wrappingAnimationNodes.referenceNode ~= nil then
        wrapper.wrappingAnimationNodes.referenceNodeRotation[1], wrapper.wrappingAnimationNodes.referenceNodeRotation[2], wrapper.wrappingAnimationNodes.referenceNodeRotation[3] = getRotation(wrapper.wrappingAnimationNodes.referenceNode)
        local rotation = wrapper.wrappingAnimationNodes.referenceNodeRotation[wrapper.wrappingAnimationNodes.referenceAxis]
        nodesTime = MathUtil.clamp((rotation - wrapper.wrappingAnimationNodes.referenceMinRot) / (wrapper.wrappingAnimationNodes.referenceMaxRot - wrapper.wrappingAnimationNodes.referenceMinRot), 0, 1)
        nodesTime = MathUtil.round(nodesTime, 5)
    end

    if nodesTime > wrapper.wrappingAnimationNodes.lastTime then
        local nodes = wrapper.wrappingAnimationNodes.nodes
        for i = wrapper.wrappingAnimationNodes.currentIndex + 1, #nodes do
            local wrappingAnimationNode = nodes[i]
            if wrappingAnimationNode.time <= nodesTime then
                if wrappingAnimationNode.linkNode ~= nil then
                    local x, y, z = localToWorld(wrappingAnimationNode.parent, unpack(wrappingAnimationNode.translation))
                    if getParent(wrappingAnimationNode.nodeId) ~= wrappingAnimationNode.linkNode then
                        link(wrappingAnimationNode.linkNode, wrappingAnimationNode.nodeId)
                    end
                    setWorldTranslation(wrappingAnimationNode.nodeId, x, y, z)
                else
                    if getParent(wrappingAnimationNode.nodeId) ~= wrappingAnimationNode.parent then
                        link(wrappingAnimationNode.parent, wrappingAnimationNode.nodeId)
                    end
                    setTranslation(wrappingAnimationNode.nodeId, unpack(wrappingAnimationNode.translation))
                end

                wrapper.wrappingAnimationNodes.currentIndex = i
            else
                break
            end
        end
    elseif nodesTime < wrapper.wrappingAnimationNodes.lastTime then
        wrapper.wrappingAnimationNodes.currentIndex = 0
    end
    wrapper.wrappingAnimationNodes.lastTime = nodesTime

    for animationNode, rootNode in pairs(wrapper.wrappingAnimationNodes.nodeToRootNode) do
        local rx, ry, rz = localRotationToLocal(rootNode, getParent(animationNode), 0, 0, 0)
        setRotation(animationNode, rx, ry, rz)
    end

    local wrappingState = math.min(wrappingTime, 1)
    local wrapperRot = 0
    if wrapper.animCurve ~= nil then
        local v = wrapper.animCurve:get(wrappingTime)
        if v ~= nil then
            setRotation(wrapper.baleNode, v[1]%(math.pi*2), v[2]%(math.pi*2), v[3]%(math.pi*2))
            setRotation(wrapper.wrapperNode, v[4]%(math.pi*2), v[5]%(math.pi*2), v[6]%(math.pi*2))
            wrapperRot = v[3 + wrapper.wrapperRotAxis]
        elseif wrapper.animations["wrapBale"].animName ~= nil then
            wrappingTime = self:getAnimationTime(wrapper.animations["wrapBale"].animName)
        end

        if wrapper.wrappingAnimationNodes.referenceNode ~= nil then
            wrappingState = nodesTime
        end

        if wrapper.wrappingFoilAnimation ~= nil then
            wrappingState = foilTime
        end

        if wrapper.currentBale ~= nil then
            local bale = NetworkUtil.getObject(wrapper.currentBale)
            if bale ~= nil then
                local baleType = spec.currentWrapper.allowedBaleTypes[spec.currentBaleTypeIndex]
                if bale:getSupportsWrapping() and not baleType.skipWrapping and bale.wrappingState < 1 then
                    local wrappingStateCurve = baleType.wrappingStateCurve or wrapper.wrappingStateCurve
                    if wrappingStateCurve ~= nil then
                        wrappingState = wrappingStateCurve:get(wrappingState)
                    end

                    bale:setWrappingState(wrappingState, true)

                    if bale.setColor ~= nil then
                        local color = ConfigurationUtil.getColorByConfigId(self, "wrappingColor", self.configurations["wrappingColor"])
                        if color ~= nil then
                            local r, g, b, a = unpack(color)
                            bale:setColor(r, g, b, a)
                        end
                    end
                end
            end
        end
    end

    self:updateWrapNodes(wrappingTime > 0, false, wrappingTime, wrapperRot)
    if wrappingTime > 0.99999 then
        if self.isServer and spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_WRAPPING_BALE and not noEventSend then
            g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPING_BALE_FINSIHED), true, nil, self)
        end
    end
end


---Play move to wrapper animation
-- @param table bale bale to move
function BaleWrapper:playMoveToWrapper(bale)
    local spec = self.spec_baleWrapper

    local baleTypeIndex = self:getMatchingBaleTypeIndex(bale.isRoundbale and spec.roundBaleWrapper.allowedBaleTypes or spec.squareBaleWrapper.allowedBaleTypes, bale)
    self:setBaleWrapperType(bale.isRoundbale, baleTypeIndex)

    if spec.currentWrapper.animations["moveToWrapper"].animName ~= nil then
        self:playAnimation(spec.currentWrapper.animations["moveToWrapper"].animName, spec.currentWrapper.animations["moveToWrapper"].animSpeed, nil, true)
    end
end


---Set current wrapper and bale type index
-- @param bool isRoundBaleWrapper is a roundbale wrapper
-- @param integer baleTypeIndex index of bale type
function BaleWrapper:setBaleWrapperType(isRoundBaleWrapper, baleTypeIndex)
    local spec = self.spec_baleWrapper
    spec.currentWrapper = isRoundBaleWrapper and spec.roundBaleWrapper or spec.squareBaleWrapper

    spec.currentBaleTypeIndex = baleTypeIndex
    local baleType = spec.currentWrapper.allowedBaleTypes[baleTypeIndex]
    if baleType ~= nil then
        spec.currentWrapper.animations = baleType.animations
        spec.currentWrapper.wrappingFoilAnimation = baleType.wrappingFoilAnimation or spec.currentWrapper.wrappingFoilAnimationDefault

        ObjectChangeUtil.setObjectChanges(baleType.changeObjects, true, self, self.setMovingToolDirty)

        if spec.currentWrapper.wrappingFoilAnimation ~= nil then
            local wrappingFoilAnimation = spec.currentWrapper.wrappingFoilAnimation
            clearAnimTrackClip(wrappingFoilAnimation.animationCharSet, 0)
            assignAnimTrackClip(wrappingFoilAnimation.animationCharSet, 0, wrappingFoilAnimation.animationClipIndex)

            enableAnimTrack(wrappingFoilAnimation.animationCharSet, 0)
            setAnimTrackTime(wrappingFoilAnimation.animationCharSet, 0, 0, true)
            disableAnimTrack(wrappingFoilAnimation.animationCharSet, 0)
        end
    end
end


---Returns the matching bale from a given list of bale types
-- @param table baleTypes list with bale types
-- @param table bale bale object
function BaleWrapper:getMatchingBaleTypeIndex(baleTypes, bale)
    for i, baleType in ipairs(baleTypes) do
        if bale:getBaleMatchesSize(baleType.diameter, baleType.width, baleType.height, baleType.length) then
            return i
        end
    end

    return 1
end


---Changed wrapper state
-- @param integer id id of new state
-- @param integer nearestBaleServerId server id of nearest bale
function BaleWrapper:doStateChange(id, nearestBaleServerId)
    local spec = self.spec_baleWrapper

    if id == BaleWrapper.CHANGE_WRAPPING_START or (spec.baleWrapperState ~= BaleWrapper.STATE_WRAPPER_FINSIHED and id == BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE) then
        local bale = NetworkUtil.getObject(spec.currentWrapper.currentBale)
        local baleType = spec.currentWrapper.allowedBaleTypes[spec.currentBaleTypeIndex]
        if not bale:getSupportsWrapping() or baleType.skipWrapping or bale.wrappingState == 1 then
            if self.isServer then
                spec.setWrappingStateFinished = true
            end

            return
        end
    end

    if id == BaleWrapper.CHANGE_GRAB_BALE then
        local bale = NetworkUtil.getObject(nearestBaleServerId)
        spec.baleGrabber.currentBale = nearestBaleServerId
        if bale ~= nil then
            local x,y,z = localToLocal(bale.nodeId, getParent(spec.baleGrabber.grabNode), 0,0,0)
            setTranslation(spec.baleGrabber.grabNode, x,y,z)
            bale:mountKinematic(self, spec.baleGrabber.grabNode, 0,0,0, 0,0,0)
            bale:setCanBeSold(false)
            spec.baleToMount = nil
            self:playMoveToWrapper(bale)
        else
            spec.baleToMount = {serverId=nearestBaleServerId, linkNode=spec.baleGrabber.grabNode, trans={0,0,0}, rot={0,0,0} }
        end
        spec.baleWrapperState = BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER

    elseif id == BaleWrapper.CHANGE_DROP_BALE_AT_GRABBER then
        -- drop bale at wrapper
        local attachNode = spec.currentWrapper.baleNode
        local bale = NetworkUtil.getObject(spec.baleGrabber.currentBale)
        if bale ~= nil then
            bale:mountKinematic(self, attachNode, 0,0,0, 0,0,0)
            bale:setCanBeSold(false)
            spec.baleToMount = nil
        else
            spec.baleToMount = {serverId=spec.baleGrabber.currentBale, linkNode=attachNode, trans={0,0,0}, rot={0,0,0} }
        end
        self:updateWrapNodes(true, false, 0)

        spec.currentWrapper.currentBale = spec.baleGrabber.currentBale
        spec.baleGrabber.currentBale = nil

        if spec.currentWrapper.animations["moveToWrapper"].animName ~= nil then
            if spec.currentWrapper.animations["moveToWrapper"].reverseAfterMove then
                self:playAnimation(spec.currentWrapper.animations["moveToWrapper"].animName, -spec.currentWrapper.animations["moveToWrapper"].animSpeed, nil, true)
            end
        end

        spec.baleWrapperState = BaleWrapper.STATE_MOVING_GRABBER_TO_WORK

    elseif id == BaleWrapper.CHANGE_WRAPPING_START then

        spec.baleWrapperState = BaleWrapper.STATE_WRAPPER_WRAPPING_BALE
        if self.isClient then
            g_soundManager:playSamples(spec.currentWrapper.samples.start)
            g_soundManager:playSamples(spec.currentWrapper.samples.wrap, 0, spec.currentWrapper.samples.start[1])
        end

        if spec.currentWrapper.animations["wrapBale"].animName ~= nil then
            self:playAnimation(spec.currentWrapper.animations["wrapBale"].animName, spec.currentWrapper.animations["wrapBale"].animSpeed, nil, true)
        end
    elseif id == BaleWrapper.CHANGE_WRAPPING_BALE_FINSIHED then

        if self.isClient then
            g_soundManager:stopSamples(spec.currentWrapper.samples.wrap)
            g_soundManager:stopSamples(spec.currentWrapper.samples.stop)
            if spec.currentWrapper.wrappingSoundEndTime == 1 then
                g_soundManager:playSamples(spec.currentWrapper.samples.stop)
            end

            -- if the start sound is still playing (e.g. on loading if the wrapping state is directly set to 1) we stop it
            g_soundManager:stopSamples(spec.currentWrapper.samples.start)
        end

        self:updateWrappingState(1, true)
        spec.baleWrapperState = BaleWrapper.STATE_WRAPPER_FINSIHED

        local bale = NetworkUtil.getObject(spec.currentWrapper.currentBale)
        local baleType = spec.currentWrapper.allowedBaleTypes[spec.currentBaleTypeIndex]
        local skippedWrapping = not bale:getSupportsWrapping() or baleType.skipWrapping
        if skippedWrapping or bale.wrappingState == 1 then
            self:updateWrappingState(0, true)
        end

        if not skippedWrapping then
            local animation = spec.currentWrapper.animations["resetWrapping"]
            if animation.animName ~= nil then
                self:playAnimation(animation.animName, animation.animSpeed, nil, true)
            end
        end
    elseif id == BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE then

        self:updateWrapNodes(false, false, 0)
        if spec.currentWrapper.animations["dropFromWrapper"].animName ~= nil then
            self:playAnimation(spec.currentWrapper.animations["dropFromWrapper"].animName, spec.currentWrapper.animations["dropFromWrapper"].animSpeed, nil, true)
        end
        spec.baleWrapperState = BaleWrapper.STATE_WRAPPER_DROPPING_BALE
    elseif id == BaleWrapper.CHANGE_WRAPPER_BALE_DROPPED then

        local bale = NetworkUtil.getObject(spec.currentWrapper.currentBale)
        if bale ~= nil then
            bale:unmountKinematic()
            bale:setCanBeSold(true)

            local baleType = spec.currentWrapper.allowedBaleTypes[spec.currentBaleTypeIndex]
            if bale:getSupportsWrapping() and not baleType.skipWrapping then

                local stats = g_currentMission:farmStats(self:getOwnerFarmId())
                local total = stats:updateStats("wrappedBales", 1)
                g_achievementManager:tryUnlock("WrappedBales", total)

                if bale.wrappingState < 1 then
                    bale:setWrappingState(1)
                end
            end
        end
        spec.lastDroppedBale = bale
        spec.currentWrapper.currentBale = nil
        spec.currentWrapper.currentTime = 0
        if spec.currentWrapper.animations["resetAfterDrop"].animName ~= nil then
            -- stop and set drop animation finished when we start the reset animation
            -- on client side it can happen that we receive the "DROPPED" state before the dropFromWrapper animation is finished on client side
            -- this can cause a overlapping of the two animation and a wrong state of certain nodes
            local dropAnimationName = spec.currentWrapper.animations["dropFromWrapper"].animName
            if self:getIsAnimationPlaying(dropAnimationName) then
                self:stopAnimation(dropAnimationName, true)
                self:setAnimationTime(dropAnimationName, 1, true, false)
            end

            self:playAnimation(spec.currentWrapper.animations["resetAfterDrop"].animName, spec.currentWrapper.animations["resetAfterDrop"].animSpeed, nil, true)
        end

        -- reapply wrapper type to reset the wrapper again to initial state
        self:setBaleWrapperType(spec.currentWrapper == spec.roundBaleWrapper, spec.currentBaleTypeIndex)

        spec.baleWrapperState = BaleWrapper.STATE_WRAPPER_RESETTING_PLATFORM

    elseif id == BaleWrapper.CHANGE_WRAPPER_PLATFORM_RESET then

        self:updateWrappingState(0)
        self:updateWrapNodes(false, true, 0)
        spec.baleWrapperState = BaleWrapper.STATE_NONE

    elseif id == BaleWrapper.CHANGE_BUTTON_EMPTY then

        -- Server only code
        assert(self.isServer)
        if spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
            g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE), true, nil, self)
        end

    end
end


---Returns type of wrapped bale
-- @param table bale unwrapped bale
-- @return table baleType wrapped bale
function BaleWrapper:getIsBaleWrappable(bale)
    local spec = self.spec_baleWrapper

    local sizeMatch = false
    local baleTypes = bale.isRoundbale and spec.roundBaleWrapper.allowedBaleTypes or spec.squareBaleWrapper.allowedBaleTypes
    if baleTypes ~= nil then
        for i, baleType in ipairs(baleTypes) do
            if bale:getBaleMatchesSize(baleType.diameter, baleType.width, baleType.height, baleType.length) then
                sizeMatch = true
                if not baleType.skipWrapping then
                    if bale:getSupportsWrapping() and bale.wrappingState < 1 then
                        return true, sizeMatch, i
                    end
                end
            end
        end
    end

    return false, sizeMatch
end


---Returns if bale drop is allowed
-- @return boolean isAllowed bale drop is allowed
-- @return string warning warning to display if not allowed
function BaleWrapper:getIsBaleDropAllowed()
    return true, nil
end


---Returns if the start of the bale wrap animation is allowed
-- @return boolean isAllowed bale wrap is allowed
function BaleWrapper:getIsBaleWrappingAllowed()
    return true
end


---Pickup bale to wrap
-- @param table bale bale to pickup
-- @param integer baleType type of bale
function BaleWrapper:pickupWrapperBale(bale, baleTypeIndex)
    local spec = self.spec_baleWrapper
    if bale:getSupportsWrapping() then
        local baleTypes = bale.isRoundbale and spec.roundBaleWrapper.allowedBaleTypes or spec.squareBaleWrapper.allowedBaleTypes
        if baleTypes ~= nil and baleTypeIndex ~= nil then
            local baleType = baleTypes[baleTypeIndex]
            if baleType ~= nil then
                if not baleType.skipWrapping and bale.wrappingState < 1 then
                    if baleType.wrapDiffuse ~= nil or baleType.wrapNormal ~= nil then
                        bale:setWrapTextures(baleType.wrapDiffuse, baleType.wrapNormal)
                    end
                end
            end
        end
    end

    spec.baleGrabber.balesInTrigger[bale] = nil

    -- found bale
    g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_GRAB_BALE, NetworkUtil.getObjectId(bale)), true, nil, self)
end


---Returns if nearest bale in range
-- @param integer refNode id of reference node
-- @param float distance max distance
-- @return table nearestBale nearest bale
-- @return integer nearestBaleType id of bale type
function BaleWrapper.getBaleInRange(self, refNode, distance)
    local nearestBale = nil
    local nearestBaleWrappable = nil
    local nearestBaleTypeIndex = nil
    local nearestDistance = distance

    local spec = self.spec_baleWrapper
    for bale, _ in pairs(spec.baleGrabber.balesInTrigger) do
        if bale.dynamicMountType == MountableObject.MOUNT_TYPE_NONE and bale.nodeId ~= 0 then
--#debug    DebugUtil.drawDebugNode(bale.nodeId, string.format("dis %.2f / %.2f", calcDistanceFrom(refNode, bale.nodeId), distance), false)
            if calcDistanceFrom(refNode, bale.nodeId) < nearestDistance then
                local isWrappable, sizeMatches, baleTypeIndex = self:getIsBaleWrappable(bale)

                nearestBale = bale
                nearestDistance = distance
                if isWrappable and sizeMatches then
                    nearestBaleWrappable = bale
                    nearestBaleTypeIndex = baleTypeIndex
                end
            end
        end
    end

    return nearestBaleWrappable, nearestBale, nearestBaleTypeIndex
end


---Sets automatic drop state
function BaleWrapper:setBaleWrapperAutomaticDrop(state, noEventSend)
    local spec = self.spec_baleWrapper
    if state == nil then
        state = not spec.automaticDrop
    end

    spec.automaticDrop = state

    -- update so we have the unloading action events
    self:requestActionEventUpdate()

    BaleWrapperAutomaticDropEvent.sendEvent(self, state, noEventSend)
end



---Returns if fold is allowed
-- @param boolean onAiTurnOn called on ai turn on
-- @return boolean allowsFold allows folding
function BaleWrapper:getIsFoldAllowed(superFunc, direction, onAiTurnOn)
    local spec = self.spec_baleWrapper
    if spec.baleWrapperState ~= BaleWrapper.STATE_NONE then
        return false, spec.texts.warningFoldingWrapping
    end

    return superFunc(self, direction, onAiTurnOn)
end


---
function BaleWrapper:getCanBeSelected(superFunc)
    return true
end


---
function BaleWrapper:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then

        local spec = self.spec_baleWrapper
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            if not spec.automaticDrop then
                local _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA3, self, BaleWrapper.actionEventEmpty, false, true, false, true, nil)
                g_inputBinding:setActionEventText(actionEventId, spec.currentWrapper.unloadBaleText)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
            end

            if spec.toggleableAutomaticDrop then
                local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA4, self, BaleWrapper.actionEventToggleAutomaticDrop, false, true, false, true, nil)
                g_inputBinding:setActionEventText(actionEventId, spec.automaticDrop and spec.toggleAutomaticDropTextNeg or spec.toggleAutomaticDropTextPos)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
            end

            BaleWrapper.updateActionEvents(self)
        end
    end
end


---Called on deactivating
function BaleWrapper:onDeactivate()
    local spec = self.spec_baleWrapper
    spec.showInvalidBaleWarning = false
    if self.isClient then
        g_soundManager:stopSamples(spec.currentWrapper.samples.wrap)
        g_soundManager:stopSamples(spec.currentWrapper.samples.start)
        g_soundManager:stopSamples(spec.currentWrapper.samples.stop)
    end
end


---Called while folding state changes
function BaleWrapper:onFoldStateChanged(direction, moveToMiddle)
    local spec = self.spec_baleWrapper
    if spec.foldedBaleType ~= nil then
        if self.spec_foldable.turnOnFoldDirection ~= direction then
            self:setBaleWrapperType(spec.foldedBaleType.isRoundBaleWrapper, spec.foldedBaleType.baleTypeIndex)
        end
    end
end


---
function BaleWrapper.actionEventEmpty(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_baleWrapper
    if spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
        local dropIsAllowed, warning = self:getIsBaleDropAllowed()
        if dropIsAllowed then
            g_client:getServerConnection():sendEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_BUTTON_EMPTY))
        elseif warning ~= nil then
            g_currentMission:showBlinkingWarning(warning, 2000)
        end
    end
end


---
function BaleWrapper.actionEventToggleAutomaticDrop(self, actionName, inputValue, callbackState, isAnalog)
    self:setBaleWrapperAutomaticDrop()
end


---
function BaleWrapper.updateActionEvents(self)
    local spec = self.spec_baleWrapper
    local actionEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA3]
    if actionEvent ~= nil then
        g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED)
        g_inputBinding:setActionEventText(actionEvent.actionEventId, spec.currentWrapper.unloadBaleText)
    end

    if spec.toggleableAutomaticDrop then
        actionEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA4]
        if actionEvent ~= nil then
            g_inputBinding:setActionEventText(actionEvent.actionEventId, spec.automaticDrop and spec.toggleAutomaticDropTextNeg or spec.toggleAutomaticDropTextPos)
        end
    end
end


---
function BaleWrapper.loadSpecValueBaleSize(xmlFile, customEnvironment, baseDir, roundBaleWrapper)
    local rootName = xmlFile:getRootName()

    local wrapperName = roundBaleWrapper and "roundBaleWrapper" or "squareBaleWrapper"

    local baleSizeAttributes = {}
    baleSizeAttributes.minDiameter, baleSizeAttributes.maxDiameter = math.huge, -math.huge
    baleSizeAttributes.minLength, baleSizeAttributes.maxLength = math.huge, -math.huge
    xmlFile:iterate(rootName .. ".baleWrapper." .. wrapperName .. ".baleTypes.baleType", function(_, key)
        if not xmlFile:getValue(key.."#skipWrapping", false) then
            local diameter = MathUtil.round(xmlFile:getValue(key.."#diameter", 0), 2)
            baleSizeAttributes.minDiameter = math.min(baleSizeAttributes.minDiameter, diameter)
            baleSizeAttributes.maxDiameter = math.max(baleSizeAttributes.maxDiameter, diameter)

            local length = MathUtil.round(xmlFile:getValue(key.."#length", 0), 2)
            baleSizeAttributes.minLength = math.min(baleSizeAttributes.minLength, length)
            baleSizeAttributes.maxLength = math.max(baleSizeAttributes.maxLength, length)
        end
    end)

    if baleSizeAttributes.minDiameter ~= math.huge or baleSizeAttributes.minLength ~= math.huge then
        return baleSizeAttributes
    end
end


---
function BaleWrapper.getSpecValueBaleSize(storeItem, realItem, configurations, saleItem, returnValues, returnRange, roundBaleWrapper)
    local baleSizeAttributes = roundBaleWrapper and storeItem.specs.baleWrapperBaleSizeRound or storeItem.specs.baleWrapperBaleSizeSquare
    if baleSizeAttributes ~= nil then
        local minValue = roundBaleWrapper and baleSizeAttributes.minDiameter or baleSizeAttributes.minLength
        local maxValue = roundBaleWrapper and baleSizeAttributes.maxDiameter or baleSizeAttributes.maxLength

        if returnValues == nil or not returnValues then
            local unit = g_i18n:getText("unit_cmShort")
            local size
            if maxValue ~= minValue then
                size = string.format("%d%s-%d%s", minValue * 100, unit, maxValue * 100, unit)
            else
                size = string.format("%d%s", minValue * 100, unit)
            end

            return size
        else
            if returnRange == true and maxValue ~= minValue then
                return minValue * 100, maxValue * 100, g_i18n:getText("unit_cmShort")
            else
                return minValue * 100, g_i18n:getText("unit_cmShort")
            end
        end
    else
        if returnValues and returnRange then
            return 0, 0, ""
        elseif returnValues then
            return 0, ""
        else
            return ""
        end
    end
end


---
function BaleWrapper.loadSpecValueBaleSizeRound(xmlFile, customEnvironment, baseDir)
    return BaleWrapper.loadSpecValueBaleSize(xmlFile, customEnvironment, baseDir, true)
end


---
function BaleWrapper.loadSpecValueBaleSizeSquare(xmlFile, customEnvironment, baseDir)
    return BaleWrapper.loadSpecValueBaleSize(xmlFile, customEnvironment, baseDir, false)
end


---
function BaleWrapper.getSpecValueBaleSizeRound(storeItem, realItem, configurations, saleItem, returnValues, returnRange)
    if storeItem.specs.baleWrapperBaleSizeRound ~= nil then
        return BaleWrapper.getSpecValueBaleSize(storeItem, realItem, configurations, saleItem, returnValues, returnRange, true)
    end
end


---
function BaleWrapper.getSpecValueBaleSizeSquare(storeItem, realItem, configurations, saleItem, returnValues, returnRange)
    if storeItem.specs.baleWrapperBaleSizeSquare ~= nil then
        return BaleWrapper.getSpecValueBaleSize(storeItem, realItem, configurations, saleItem, returnValues, returnRange, false)
    end
end
