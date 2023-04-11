---A player model with sounds and animations









local PlayerModel_mt = Class(PlayerModel)


---Creating manager
-- @return table instance instance of object
function PlayerModel.new(customMt)
    local self = setmetatable({}, customMt or PlayerModel_mt)

    self.xmlFile = nil
    self.isLoaded = false
    self.sharedLoadRequestIds = {}
    self.modelParts = {}

    self.capsuleHeight = 0.8
    self.capsuleRadius = 0.4
    self.capsuleTotalHeight = self.capsuleHeight + (self.capsuleRadius * 2)

    self.style = nil

    self.ikChains = {}

    -- SOUND
    self.soundInformation = {
        samples = {
            swim = {},
            plunge = {},
            horseBrush = {}
        },
        distancePerFootstep = {
            crouch = 0.5,
            walk = 0.75,
            run = 1.5
        },
        distanceSinceLastFootstep = 0.0
    }

    -- PARTICLES
    self.particleSystemsInformation = {
        systems = {
            swim = {},
            plunge = {}
        },
        swimNode = nil,
        plungeNode = nil
    }

    -- ANIMATION
    self.animationInformation = {}
    self.animationInformation.player = 0
    self.animationInformation.parameters = {
        forwardVelocity            = {id=1, value=0.0, type=1},
        verticalVelocity           = {id=2, value=0.0, type=1},
        yawVelocity                = {id=3, value=0.0, type=1},
        absYawVelocity             = {id=4, value=0.0, type=1},
        onGround                   = {id=5, value=false, type=0},
        inWater                    = {id=6, value=false, type=0},
        isCrouched                 = {id=7, value=false, type=0},
        absForwardVelocity         = {id=8, value=0.0, type=1},
        isCloseToGround            = {id=9, value=false, type=0},
        isUsingChainsawHorizontal  = {id=10, value=false, type=0},
        isUsingChainsawVertical    = {id=11, value=false, type=0}
    }

    return self
end






























































































---Load player model, async.
-- @param string xmlFilename XML filename
-- @param bool isRealPlayer false if player is in a vehicle
-- @param bool isOwner true if this is a client that owns the player
-- @param bool isAnimated true if animations should be loaded
-- @param function asyncCallbackFunction function to call after loading success of failure. Arguments: object, result true/false, arguments
-- @param table asyncCallbackObject call receiver
-- @param table asyncCallbackArguments Arguments passed to the callback
function PlayerModel:load(xmlFilename, isRealPlayer, isOwner, isAnimated, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
    self.xmlFilename = xmlFilename
    self.customEnvironment, self.baseDirectory = Utils.getModNameAndBaseDirectory(xmlFilename)

    local xmlFile = loadXMLFile("playerXML", xmlFilename)
    if xmlFile == 0 then
        asyncCallbackFunction(asyncCallbackObject, false, asyncCallbackArguments)
        return
    end

    -- Find the filename of the player
    local filename = getXMLString(xmlFile, "player.filename")
    self.filename = Utils.getFilename(filename, self.baseDirectory)
    self.xmlFile = xmlFile

    self.isRealPlayer = isRealPlayer

    -- Load the player i3d
    self.asyncLoadCallbackFunction, self.asyncLoadCallbackObject, self.asyncLoadCallbackArguments = asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments
    self.sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(self.filename, false, false, self.loadFileFinished, self, {isRealPlayer, isOwner, isAnimated})
end


---Async result of i3d loading
function PlayerModel:loadFileFinished(rootNode, failedReason, arguments)

    local xmlFile = self.xmlFile
    self.xmlFile = nil

    if failedReason == LoadI3DFailedReason.FILE_NOT_FOUND then
        Logging.error("Player model file '%s' does not exist!", self.filename)
        delete(xmlFile)
        return self.asyncLoadCallbackFunction(self.asyncLoadCallbackObject, false, self.asyncLoadCallbackArguments)
    end

    if failedReason == LoadI3DFailedReason.UNKNOWN or rootNode == nil or rootNode == 0 then
        Logging.error("Failed to load player model %s", self.filename, failedReason)
        delete(xmlFile)
        return self.asyncLoadCallbackFunction(self.asyncLoadCallbackObject, false, self.asyncLoadCallbackArguments)
    end

    local isRealPlayer = arguments[1]
    local isOwner = arguments[2]
    local isAnimated = arguments[3]

    self.rootNode = rootNode

    -- Find nodes references in the XML first, before re-linking other nodes that change the hierarchy
    if isRealPlayer then
        local cNode = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.camera#index"))
        if cNode == nil then
            Logging.devError("Error: Failed to find player camera position in '%s'", self.filename)
        end

        local x, y, z = localToLocal(cNode, rootNode, 0, 0, 0)

        local target = createTransformGroup("1p_camera_target")
        link(rootNode, target)
        setTranslation(target, x, y, z)

        self.firstPersonCameraTarget = target
    end

    if isRealPlayer then
        self.animRootThirdPerson = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#animRootNode"))
        if self.animRootThirdPerson == nil then
            Logging.devError("Error: Failed to find animation root node in '%s'", self.filename)
            delete(xmlFile)
            return self.asyncLoadCallbackFunction(self.asyncLoadCallbackObject, false, self.asyncLoadCallbackArguments)
        end

        -- Capsule information
        self.capsuleHeight = getXMLFloat(xmlFile, "player.character#physicsCapsuleHeight")
        self.capsuleRadius = getXMLFloat(xmlFile, "player.character#physicsCapsuleRadius")
        self.capsuleTotalHeight = self.capsuleHeight + self.capsuleRadius * 2
    end

    -- Avator customization
    self.style = PlayerStyle.new()
    -- self.style:loadConfigurationXML(self.xmlFilename)

    self.skeleton = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#skeleton"))
    if self.skeleton == nil then
        Logging.devError("Error: Failed to find skeleton root node in '%s'", self.filename)
    end

    self.mesh = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#mesh"))
    if self.mesh == nil then
        Logging.devError("Error: Failed to find player mesh in '%s'", self.filename)
    end

    -- Used for linking elements (handtools, lights)
    self.thirdPersonSpineNode       = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#spine"))
    self.thirdPersonSuspensionNode  = Utils.getNoNil(I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#suspension")), self.thirdPersonSpineNode)
    self.thirdPersonRightHandNode   = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#rightHandNode"))
    self.thirdPersonLeftHandNode    = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#leftHandNode"))
    self.thirdPersonHeadNode        = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.character.thirdPerson#headNode"))

    -- Torchlight
    self.lightNode = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.light#index"))
    if self.lightNode ~= nil then
        setVisibility(self.lightNode, false)
    end

    -- Relink only after the lights and cameras are loaded: indexing changes
    if self.mesh ~= nil then
        -- link(self.rootNode, self.mesh)
        setClipDistance(self.mesh, 200)
    end

    local pickUpKinematicHelperNode = I3DUtil.indexToObject(rootNode, getXMLString(xmlFile, "player.pickUpKinematicHelper#index"))
    if pickUpKinematicHelperNode ~= nil then
        if getRigidBodyType(pickUpKinematicHelperNode) == RigidBodyType.KINEMATIC then
            self.pickUpKinematicHelperNode = pickUpKinematicHelperNode
            self.pickUpKinematicHelperNodeChild = createTransformGroup("pickUpKinematicHelperNodeChild")
            link(self.pickUpKinematicHelperNode, self.pickUpKinematicHelperNodeChild)

            addToPhysics(self.pickUpKinematicHelperNode)
        else
            Logging.xmlWarning(xmlFile, "Given pickUpKinematicHelper '%s' is not a kinematic object", getName(pickUpKinematicHelperNode))
        end
    end

    -- IK Chains
    self:loadIKChains(xmlFile, rootNode, isRealPlayer)

    if isAnimated then
        if self.skeleton ~= nil and getNumOfChildren(self.skeleton) > 0 then
            local animNode = g_animCache:getNode(AnimationCache.CHARACTER)
            cloneAnimCharacterSet(animNode, getParent(self.skeleton))
            local animCharsetId = getAnimCharacterSet(getChildAt(self.skeleton, 0))
            self.animationInformation.player = createConditionalAnimation()

            for key, parameter in pairs(self.animationInformation.parameters) do
                conditionalAnimationRegisterParameter(self.animationInformation.player, parameter.id, parameter.type, key)
            end
            initConditionalAnimation(self.animationInformation.player, animCharsetId, self.xmlFilename, "player.conditionalAnimation")
            setConditionalAnimationSpecificParameterIds(self.animationInformation.player, self.animationInformation.parameters.absForwardVelocity.id, self.animationInformation.parameters.yawVelocity.id)
        end
    end

    if isRealPlayer then
        self.skeletonRootNode = createTransformGroup("player_skeletonRootNode")

        link(getRootNode(), self.rootNode)
        link(self.rootNode, self.skeletonRootNode)

        if self.animRootThirdPerson ~= nil then
            link(self.skeletonRootNode, self.animRootThirdPerson)
            if self.skeleton ~= nil then
                link(self.animRootThirdPerson, self.skeleton)
            end
        end

        self.leftArmToolNode = createTransformGroup("leftArmToolNode")
        self.rightArmToolNode = createTransformGroup("rightArmToolNode")

        if isOwner then
            local toolRotation = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.character.toolNode#firstPersonRotation"), "0 0 0"), 3)
            local rotX, rotY, rotZ = unpack(toolRotation)
            setRotation(self.rightArmToolNode, math.rad(rotX), math.rad(rotY), math.rad(rotZ))
            local toolTranslate = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.character.toolNode#firstPersonTranslation"), "0 0 0"), 3)
            local transX, transY, transZ = unpack(toolTranslate)
            setTranslation(self.rightArmToolNode, transX, transY, transZ)
        else
            -- right hand tool
            local toolRotationR = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.character.toolNode#thirdPersonRightNodeRotation"), "0 0 0"), 3)
            local rotRX, rotRY, rotRZ = unpack(toolRotationR)
            setRotation(self.rightArmToolNode, math.rad(rotRX), math.rad(rotRY), math.rad(rotRZ))
            local toolTranslateR = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.character.toolNode#thirdPersonRightNodeTranslation"), "0 0 0"), 3)
            local transRX, transRY, transRZ = unpack(toolTranslateR)
            setTranslation(self.rightArmToolNode, transRX, transRY, transRZ)
            link(self.thirdPersonRightHandNode, self.rightArmToolNode)

            -- left hand tool
            local toolRotationL = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.character.toolNode#thirdPersonLeftNodeRotation"), "0 0 0"), 3)
            local rotLX, rotLY, rotLZ = unpack(toolRotationL)
            setRotation(self.leftArmToolNode, math.rad(rotLX), math.rad(rotLY), math.rad(rotLZ))
            local toolTranslateL = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.character.toolNode#thirdPersonLeftNodeTranslation"), "0 0 0"), 3)
            local transLX, transLY, transLZ = unpack(toolTranslateL)
            setTranslation(self.leftArmToolNode, transLX, transLY, transLZ)
            link(self.thirdPersonLeftHandNode, self.leftArmToolNode)

            -- light: attached to the head
            link(self.thirdPersonHeadNode, self.lightNode)
            local lightRotation = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.light#thirdPersonRotation"), "0 0 0"), 3)
            local lightRotX, lightRotY, lightRotZ = unpack(lightRotation)
            local lightTranslate = string.getVectorN(Utils.getNoNil(getXMLString(xmlFile, "player.light#thirdPersonTranslation"), "0 0 0"), 3)
            local lightTransX, lightTransY, lightTransZ = unpack(lightTranslate)
            setRotation(self.lightNode, math.rad(lightRotX), math.rad(lightRotY), math.rad(lightRotZ))
            setTranslation(self.lightNode, lightTransX, lightTransY, lightTransZ)
        end

        -- Fx
        self.particleSystemsInformation.swimNode   = createTransformGroup("swimFXNode")
        link(getRootNode(), self.particleSystemsInformation.swimNode)
        self.particleSystemsInformation.plungeNode = createTransformGroup("plungeFXNode")
        link(getRootNode(), self.particleSystemsInformation.plungeNode)

        ParticleUtil.loadParticleSystem(xmlFile, self.particleSystemsInformation.systems.swim, "player.particleSystems.swim", self.particleSystemsInformation.swimNode, false, nil, self.baseDirectory)
        ParticleUtil.loadParticleSystem(xmlFile, self.particleSystemsInformation.systems.plunge, "player.particleSystems.plunge", self.particleSystemsInformation.plungeNode, false, nil, self.baseDirectory)
    else
        -- Will be re-linked in linkTo:
        if not isAnimated then
            local linkNode = createTransformGroup("characterLinkNode")
            link(self.rootNode, linkNode)
            link(linkNode, self.skeleton)

            local x, y, z = localToLocal(self.thirdPersonSpineNode, self.skeleton, 0, 0, 0)
            setTranslation(linkNode, -x, -y, -z)
        else
            link(self.rootNode, self.skeleton)
        end

        if self.pickUpKinematicHelperNode ~= nil then
            delete(self.pickUpKinematicHelperNode)
            self.pickUpKinematicHelperNode = nil
        end
        if self.lightNode ~= nil then
            delete(self.lightNode)
            self.lightNode = nil
        end
        -- if self.cameraNode ~= nil then
        --     delete(self.cameraNode)
        --     self.cameraNode = nil
        -- end

        -- self.visualInformation:applySelection()
        -- self.visualInformation:setVisibility(true)
    end

    -- Sound
    if isRealPlayer and Platform.hasPlayer then
        self:loadSounds(xmlFile, isOwner)
    end

    delete(xmlFile)

    self.isLoaded = true

    return self.asyncLoadCallbackFunction(self.asyncLoadCallbackObject, true, self.asyncLoadCallbackArguments)
end
































































































---Reads from network stream
-- @param integer streamId id of the stream to read
-- @param table connection connection information
function PlayerModel:readStream(streamId, connection)
end


---Writes in network stream
-- @param integer streamId id of the stream to read
-- @param table connection connection information
function PlayerModel:writeStream(streamId, connection)
end
