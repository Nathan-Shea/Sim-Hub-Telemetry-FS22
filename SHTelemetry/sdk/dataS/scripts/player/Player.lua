---class.














































local Player_mt = Class(Player, Object)
























---Creating player and initializing member variables
-- @param boolean isServer is server
-- @param boolean isClient is client
-- @return table instance Instance of object
function Player.new(isServer, isClient)
    local self = Object.new(isServer, isClient, Player_mt)

    self.isControlled = false
    self.isOwner = false
    self.isEntered = false
    self.debugFlightModeWalkingSpeed = 0.016
    self.debugFlightModeRunningFactor = 1

    self.model = PlayerModel.new()
    self.model:loadEmpty()

    self.cctMovementCollisionMask = CollisionMask.PLAYER_MOVEMENT

    self.networkInformation = {}
    self.networkInformation.creatorConnection = nil
    self.networkInformation.history = {}
    self.networkInformation.index = 0
    if self.isServer then
        self.networkInformation.sendIndex = 0
    end
    self.networkInformation.interpolationTime = InterpolationTime.new(1.2)
    self.networkInformation.interpolatorPosition = InterpolatorPosition.new(0.0, 0.0, 0.0)
    self.networkInformation.interpolatorQuaternion = InterpolatorQuaternion.new(0.0, 0.0, 0.0, 1.0) -- only used on server side for rotation of camera
    self.networkInformation.interpolatorOnGround = InterpolatorValue.new(0.0)
    self.networkInformation.tickTranslation = {0.0, 0.0, 0.0}
    self.networkInformation.dirtyFlag = self:getNextDirtyFlag()
    self.networkInformation.updateTargetTranslationPhysicsIndex = -1
    self.networkInformation.rotateObject = false
    self.networkInformation.rotateObjectInputV = 0.0
    self.networkInformation.rotateObjectInputH = 0.0

    self.motionInformation = {}
    self.motionInformation.damping = 0.8
    self.motionInformation.mass = 80.0                                -- in kg
    self.motionInformation.maxAcceleration = 50.0                     -- m/s^2
    self.motionInformation.maxDeceleration = 50.0                     -- m/s^2
    self.motionInformation.gravity = -9.8

    -- if getUserName() == "jkuijpers" then
    -- -- real walking speed: 1.4, real running speed: 6.5, real swimming speed: 0.9
    -- self.motionInformation.maxIdleSpeed = 0.1                         -- in m/s
    -- self.motionInformation.maxWalkingSpeed = 1.4                      -- in m/s 4
    -- self.motionInformation.maxRunningSpeed = 9.0                      -- in m/s
    -- self.motionInformation.maxSwimmingSpeed = 3.0                     -- in m/s
    -- self.motionInformation.maxCrouchingSpeed = 2.0                    -- in m/s
    -- self.motionInformation.maxFallingSpeed = 1.4                      -- in m/s
    -- self.motionInformation.maxCheatRunningSpeed = 9.0                -- in m/s
    -- self.motionInformation.maxPresentationRunningSpeed = 9.0        -- in m/s
    -- self.motionInformation.maxSpeedDelay = 0.1                      -- in s (how long before max speed is reached)
    -- self.motionInformation.brakeDelay = 0.001                           -- in s (how long before velocity is null)
    -- self.motionInformation.brakeForce = {0.0, 0.0, 0.0}               -- in N (force to apply to stop the player gradually)
    -- else

    self.motionInformation.maxIdleSpeed = 0.1                         -- in m/s
    self.motionInformation.maxWalkingSpeed = 4.0                      -- in m/s
    self.motionInformation.maxRunningSpeed = 9.0                      -- in m/s
    self.motionInformation.maxSwimmingSpeed = 3.0                     -- in m/s
    self.motionInformation.maxCrouchingSpeed = 2.0                    -- in m/s
    self.motionInformation.maxFallingSpeed = 6.0                      -- in m/s
    self.motionInformation.maxCheatRunningSpeed = 34.0                -- in m/s
    self.motionInformation.maxPresentationRunningSpeed = 128.0        -- in m/s
    self.motionInformation.maxSpeedDelay = 0.1                      -- in s (how long before max speed is reached)
    self.motionInformation.brakeDelay = 0.001                           -- in s (how long before velocity is null)
    self.motionInformation.brakeForce = {0.0, 0.0, 0.0}               -- in N (force to apply to stop the player gradually)
    -- end
    self.motionInformation.currentGroundSpeed = 0.0                   -- in m/s
    self.motionInformation.minimumFallingSpeed = -0.00001             -- in m/s
    self.motionInformation.coveredGroundDistance = 0.0                -- in m
    self.motionInformation.currentCoveredGroundDistance = 0.0
    self.motionInformation.justMoved = false                          --
    self.motionInformation.isBraking = false
    self.motionInformation.lastSpeed = 0.0
    self.motionInformation.currentSpeed = 0.0
    self.motionInformation.currentSpeedY = 0.0
    self.motionInformation.isReverse = false
    self.motionInformation.desiredSpeed = 0.0
    self.motionInformation.jumpHeight = 1                         -- in m
    self.motionInformation.currentWorldDirX = 0.0
    self.motionInformation.currentWorldDirZ = 1.0
    self.motionInformation.currentSpeedX = 0.0
    self.motionInformation.currentSpeedZ = 0.0

    self.baseInformation = {}
    self.baseInformation.lastPositionX = 0.0
    self.baseInformation.lastPositionZ = 0.0
    self.baseInformation.isOnGround = true
    self.baseInformation.isOnGroundPhysics = true
    self.baseInformation.isCloseToGround = true
    self.baseInformation.isInWater = false
    self.baseInformation.waterDepth = 0
    self.baseInformation.wasInWater = false
    self.baseInformation.waterLevel = -1.4
    self.baseInformation.waterCameraOffset = 0.3
    self.baseInformation.currentWaterCameraOffset = 0.0
    self.baseInformation.plungedInWater = false
    self.baseInformation.plungedYVelocityThreshold = -2.0
    self.baseInformation.isInDebug = false
    self.baseInformation.tagOffset = {0.0, 1.9, 0.0}
    self.baseInformation.translationAlphaDifference = 0.0
    self.baseInformation.animDt = 0.0
    self.baseInformation.isCrouched = false
    self.baseInformation.isUsingChainsawHorizontal = false
    self.baseInformation.isUsingChainsawVertical = false
    self.baseInformation.currentHandtool = nil
    self.baseInformation.headBobTime = 0.0
    self.baseInformation.lastCameraAmplitudeScale = 0.0
    self.lastEstimatedForwardVelocity = 0.0

    self.inputInformation = {}
    self.inputInformation.moveForward = 0.0
    self.inputInformation.moveRight = 0.0
    self.inputInformation.moveUp = 0.0 -- for debug flight mode
    self.inputInformation.pitchCamera = 0.0
    self.inputInformation.yawCamera = 0.0
    self.inputInformation.runAxis = 0.0
    self.inputInformation.crouchState = Player.BUTTONSTATES.RELEASED
    self.inputInformation.interactState = Player.BUTTONSTATES.RELEASED

    -- These are the parameters for the input registration and the eventId
    self.inputInformation.registrationList = {}
    self.inputInformation.registrationList[InputAction.AXIS_MOVE_SIDE_PLAYER] = { eventId="", callback=self.onInputMoveSide, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.AXIS_MOVE_FORWARD_PLAYER] = { eventId="", callback=self.onInputMoveForward, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.AXIS_LOOK_LEFTRIGHT_PLAYER] = { eventId="", callback=self.onInputLookLeftRight, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.AXIS_LOOK_UPDOWN_PLAYER] = { eventId="", callback=self.onInputLookUpDown, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.AXIS_RUN] = { eventId="", callback=self.onInputRun, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.JUMP] = { eventId="", callback=self.onInputJump, triggerUp=false, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=GS_IS_CONSOLE_VERSION }
    -- TODO: read from game settings? also needs to be applied to PlayerStateCrouch.toggleMode. triggerAlways = not crouchToggleMode
    self.inputInformation.registrationList[InputAction.CROUCH] = { eventId="", callback=self.onInputCrouch, triggerUp=false, triggerDown=true, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=GS_IS_CONSOLE_VERSION }
    self.inputInformation.registrationList[InputAction.ANIMAL_PET] = { eventId="", callback=self.onInputActivateObject, triggerUp=false, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT, callbackState=nil, text="", textVisibility=true }
    self.inputInformation.registrationList[InputAction.ROTATE_OBJECT_LEFT_RIGHT] = { eventId="", callback=self.onInputRotateObjectHorizontally, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_CARRYING, callbackState=nil, text=g_i18n:getText("action_rotateObjectHorizontally"), textVisibility=true }
    self.inputInformation.registrationList[InputAction.ROTATE_OBJECT_UP_DOWN] = { eventId="", callback=self.onInputRotateObjectVertically, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_CARRYING, callbackState=nil, text=g_i18n:getText("action_rotateObjectVertically"), textVisibility=true }
    self.inputInformation.registrationList[InputAction.ENTER] = { eventId="", callback=self.onInputEnter, triggerUp=false, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.STARTS_ENABLED, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.TOGGLE_LIGHTS_FPS] = { eventId="", callback=self.onInputToggleLight, triggerUp=false, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.STARTS_ENABLED, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.THROW_OBJECT] = { eventId="", callback=self.onInputThrowObject, triggerUp=false, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.STARTS_DISABLED, callbackState=nil, text=g_i18n:getText("input_THROW_OBJECT"), textVisibility=true }
    self.inputInformation.registrationList[InputAction.INTERACT] = { eventId="", callback=self.onInputInteract, triggerUp=true, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.STARTS_DISABLED, callbackState=nil, text="", textVisibility=true }
    self.inputInformation.registrationList[InputAction.SWITCH_HANDTOOL] = { eventId="", callback=self.onInputCycleHandTool, triggerUp=false, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.STARTS_DISABLED, callbackState=nil, text=g_i18n:getText("input_SWITCH_HANDTOOL"), textVisibility=false }
    self.inputInformation.registrationList[InputAction.DEBUG_PLAYER_ENABLE] = { eventId="", callback=self.onInputDebugFlyToggle, triggerUp=false, triggerDown=true, triggerAlways=false, activeType=Player.INPUT_ACTIVE_TYPE.IS_DEBUG, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.DEBUG_PLAYER_UP_DOWN] = { eventId="", callback=self.onInputDebugFlyUpDown, triggerUp=false, triggerDown=false, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.IS_DEBUG, callbackState=nil, text="", textVisibility=false }
    self.inputInformation.registrationList[InputAction.ACTIVATE_HANDTOOL] = { eventId="", callback=self.onInputActivateHandtool, triggerUp=false, triggerDown=true, triggerAlways=true, activeType=Player.INPUT_ACTIVE_TYPE.STARTS_DISABLED, callbackState=nil, text=g_i18n:getText("input_ACTIVATE_HANDTOOL"), textVisibility=false }

    -- Player movement lock flag
    self.walkingIsLocked = false

    self.canRideAnimal = false
    self.canEnterVehicle = false

    self.isTorchActive = false

    self.rotX = 0
    self.rotY = 0
    self.cameraRotY = 0

    self.oldYaw = 0.0               -- in rad
    self.newYaw = 0.0               -- in rad
    self.estimatedYawVelocity = 0.0 -- in rad/s

    self.graphicsRotY = 0
    self.targetGraphicsRotY = 0

    self.thirdPersonViewActive = false

    self.camera = 0

    self.time = 0

    self.clipDistance = 500
    self.waterY = -2000

    self.lastAnimPosX = 0
    self.lastAnimPosY = 0
    self.lastAnimPosZ = 0

    self.maxPickableMass = Player.MAX_PICKABLE_OBJECT_MASS

    self.walkDistance = 0
    self.animUpdateTime = 0

    self.allowPlayerPickUp = Platform.allowPlayerPickUp

    self.debugFlightMode = false
    self.debugFlightCoolDown = 0

    self.requestedFieldData = false

    self.playerStateMachine = PlayerStateMachine.new(self)
    self.hudUpdater = PlayerHUDUpdater.new()

    self.farmId = FarmManager.SPECTATOR_FARM_ID

    self.cameraBobbingEnabled = g_gameSettings:getValue(GameSettings.SETTING.CAMERA_BOBBING)

    self.playerHotspot = PlayerHotspot.new()
    self.playerHotspot:setPlayer(self)

    return self
end


---Loading player information
-- @param string xmlFilename XML filename containing player information
-- @param table creatorConnection 
-- @param bool isOwner true is current player is owner
function Player:load(creatorConnection, isOwner)
    self.networkInformation.creatorConnection = creatorConnection
    self.isOwner = isOwner

    -- Root node based on physics. CCT is attached here
    self.rootNode = createTransformGroup("PlayerCCT")
    link(getRootNode(), self.rootNode)
    -- Root node that decides client position (directly controlled by player for smoothness)
    self.graphicsRootNode = createTransformGroup("player_graphicsRootNode")
    link(getRootNode(), self.graphicsRootNode)

    -- Create the player camera. We'll move this camera between targets such as the 1p target or the 3p target.
    self.cameraNode = createCamera("player_camera", math.rad(70), 0.15, 6000)
    self.fovY = calculateFovY(self.cameraNode)
    setFovY(self.cameraNode, self.fovY)

    self.thirdPersonLookatNode = createTransformGroup("thirdPersonLookatNode")
    link(self.graphicsRootNode, self.thirdPersonLookatNode)
    --local radius, height = self.model:getCapsuleSize()
    --local headHeight = height + radius
    setTranslation(self.thirdPersonLookatNode, 0, 0, 0)
    --setTranslation(self.thirdPersonLookatNode, 0, headHeight, 0)

    self.thirdPersonLookfromNode = createTransformGroup("thirdPersonLookfromNode")
    link(self.thirdPersonLookatNode, self.thirdPersonLookfromNode)
    --setTranslation(self.thirdPersonLookfromNode, 0, 0, -5) -- 5m camera distance
    setTranslation(self.thirdPersonLookfromNode, 0, 0, -2) -- 5m camera distance

    self:updateCameraModelTarget()

    self.foliageBendingNode = createTransformGroup("player_foliageBendingNode")
    link(self.graphicsRootNode, self.foliageBendingNode)

    self.playerStateMachine:load()

    self.isObjectInRange = false
    self.isCarryingObject = false
    self.pickedUpObject = nil

    local uiScale = g_gameSettings:getValue("uiScale")

    local pickupWidth, pickupHeight = getNormalizedScreenValues(80 * uiScale, 80 * uiScale)
    self.pickedUpObjectOverlay = Overlay.new(g_baseHUDFilename, 0.5, 0.5, pickupWidth, pickupHeight)
    self.pickedUpObjectOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
    self.pickedUpObjectOverlay:setUVs(GuiUtils.getUVs{0, 138, 80, 80})
    self.pickedUpObjectOverlay:setColor(1, 1, 1, 0.3)

    local aimWidth, aimHeight = getNormalizedScreenValues(20 * uiScale, 20 * uiScale)
    self.aimOverlay = Overlay.new(g_baseHUDFilename, 0.5, 0.5, aimWidth, aimHeight)
    self.aimOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
    self.aimOverlay:setUVs(GuiUtils.getUVs{0, 48, 48, 48})
    self.aimOverlay:setColor(1, 1, 1, 0.3)

    local brushWidth, brushHeight = getNormalizedScreenValues(75 * uiScale, 75 * uiScale)
    self.brushOverlay = Overlay.new(g_baseHUDFilename, 0.5, 0.5, brushWidth, brushHeight)
    self.brushOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
    self.brushOverlay:setUVs(GuiUtils.getUVs{307, 494, 75, 75})
    self.brushOverlay:setColor(1, 1, 1, 0.3)

    local petWidth, petHeight = getNormalizedScreenValues(75 * uiScale, 75 * uiScale)
    self.petOverlay = Overlay.new(g_baseHUDFilename, 0.5, 0.5, petWidth, petHeight)
    self.petOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
    self.petOverlay:setUVs(GuiUtils.getUVs{307, 419, 75, 75})
    self.petOverlay:setColor(1, 1, 1, 0.3)


    self:moveToAbsoluteInternal(0, -200, 0)

    self:rebuildCCT()

    self.lockedInput = false

    if self.isOwner then
        addConsoleCommand("gsPlayerFlightMode", "Enables/disables the flight mode toggle (key J). Use keys Q and E to change altitude", "consoleCommandToggleFlightMode", self)
        addConsoleCommand("gsWoodCuttingMarkerVisiblity", "Enables/disables chainsaw woodcutting marker", "Player.consoleCommandToggleWoodCuttingMaker", nil)
        addConsoleCommand("gsPlayerDebug", "Enables/disables player debug information", "consoleCommandTogglePlayerDebug", self)
        addConsoleCommand("gsPlayerNoClip", "Enables/disables player no clip/collision mode. Use 'gsPlayerNoClip true' to also turn of terrain collision", "consoleCommandToggleNoClipMode", self)
        if g_addTestCommands then
            addConsoleCommand("gsTip", "Tips a fillType into a trigger", "consoleCommandTip", self)
            addConsoleCommand("gsPlayerIKChainsReload", "Reloads player IKChains", "Player.consoleCommandReloadIKChains", nil)
            addConsoleCommand("gsPlayerSuperStrength", "Enables/disables player super strength", "consoleCommandToggleSuperStrongMode", self)
--#debug             addConsoleCommand("gsPlayerRaycastDebug", "Enables/disables player pickup raycast debug information", "consoleCommandTogglePickupRaycastDebug", self)
            addConsoleCommand("gsPlayerThirdPerson", "Enables/disables player third person view", "consoleCommandThirdPersonView", self)
        end
    end
end


---Gets the parent node
-- @param table node this parameter is unused in this function
-- @return table returns the graphics root node
function Player:getParentComponent(node)
    return self.graphicsRootNode
end


---Delete
function Player:delete()
    self.isDeleting = true

    if self.isOwner then -- only remove action events if this Player instance was controller by the current user
        g_messageCenter:unsubscribeAll(self)
        self:removeActionEvents()
    end

    if self.isCarryingObject then
        if g_server ~= nil then
            self:pickUpObject(false)
        end
    end

    g_currentMission:removeMapHotspot(self.playerHotspot)
    self.playerHotspot:delete()

    if self.pickedUpObjectOverlay ~= nil then
        self.pickedUpObjectOverlay:delete()
        self.aimOverlay:delete()
        self.brushOverlay:delete()
        self.petOverlay:delete()
    end

    if self:hasHandtoolEquipped() then
        self.baseInformation.currentHandtool:onDeactivate()
        self.baseInformation.currentHandtool:delete()
        self.baseInformation.currentHandtool = nil
    end

    self.model:delete()

    removeCCT(self.controllerIndex)
    delete(self.rootNode)
    delete(self.graphicsRootNode)

    self.playerStateMachine:delete()
    self.hudUpdater:delete()
    self:deleteStartleAnimalData()

    if self.foliageBendingId ~= nil then
        g_currentMission.foliageBendingSystem:destroyObject(self.foliageBendingId)
        self.foliageBendingId = nil
    end

    self.foliageBendingNode = nil

    if self.isOwner then
        removeConsoleCommand("gsPlayerFlightMode")
        removeConsoleCommand("gsWoodCuttingMarkerVisiblity")
        removeConsoleCommand("gsPlayerDebug")
        removeConsoleCommand("gsPlayerNoClip")
        removeConsoleCommand("gsPlayerThirdPerson")
        removeConsoleCommand("gsPlayerIKChainsReload")
        removeConsoleCommand("gsTip")
        removeConsoleCommand("gsPlayerSuperStrength")
--#debug         removeConsoleCommand("gsPlayerRaycastDebug")
    end

    Player:superClass().delete(self)
end


---Set cutting animation
-- @param bool isCutting true if player is cutting
-- @param bool isHorizontalCut true if player is cutting horizontaly
function Player:setCuttingAnim(isCutting, isHorizontalCut)
    if not isCutting and (self.baseInformation.isUsingChainsawHorizontal or self.baseInformation.isUsingChainsawVertical) then
        self.baseInformation.isUsingChainsawHorizontal = false
        self.baseInformation.isUsingChainsawVertical = false
    elseif isCutting then
        if isHorizontalCut then
            self.baseInformation.isUsingChainsawHorizontal = true
            self.baseInformation.isUsingChainsawVertical = false
        else
            self.baseInformation.isUsingChainsawHorizontal = false
            self.baseInformation.isUsingChainsawVertical = true
        end
    end
end


---Reads from network stream
-- @param integer streamId id of the stream to read
-- @param table connection connection information
function Player:readStream(streamId, connection, objectId)
    Player:superClass().readStream(self, streamId, connection)

    local isOwner = streamReadBool(streamId)

    local x = streamReadFloat32(streamId)
    local y = streamReadFloat32(streamId)
    local z = streamReadFloat32(streamId)

    local isControlled = streamReadBool(streamId)

    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.userId = NetworkUtil.readNodeObjectId(streamId)

    self:load(connection, isOwner)

    self:moveToAbsoluteInternal(x, y, z)
    self:setLightIsActive(streamReadBool(streamId), true)

    if isControlled ~= self.isControlled then
        if isControlled then
            self:onEnter(false)
        else
            self:onLeave()
        end
    end

    local hasHandtool = streamReadBool(streamId)
    if hasHandtool then
        local handtoolFilename = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId))
        self:equipHandtool(handtoolFilename, true, true)
    end

    -- The object has been received. Request any style info from the server
    g_client:getServerConnection():sendEvent(PlayerRequestStyleEvent.new(objectId))
end



---Writes in network stream
-- @param integer streamId id of the stream to read
-- @param table connection connection information
function Player:writeStream(streamId, connection)
    Player:superClass().writeStream(self, streamId, connection)
    streamWriteBool(streamId, connection == self.networkInformation.creatorConnection)

    local x, y, z = getTranslation(self.rootNode)
    streamWriteFloat32(streamId, x)
    streamWriteFloat32(streamId, y)
    streamWriteFloat32(streamId, z)

    streamWriteBool(streamId, self.isControlled)

    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    NetworkUtil.writeNodeObjectId(streamId, self.userId)

    streamWriteBool(streamId, self.isTorchActive)

    local hasHandtool = self:hasHandtoolEquipped()
    streamWriteBool(streamId, hasHandtool)
    if hasHandtool then
        streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(self.baseInformation.currentHandtool.configFileName))
    end
end


---Reads from network stream via update
-- @param integer streamId id of the stream to read
-- @param integer timestamp timestamp of the packet
-- @param table connection connection information
function Player:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        -- client code (read data from server)
        -- TODO look into Vehicle:readUpdateStream NetworkUtil.readCompressedWorldPosition and NetworkUtil.readCompressedAngle
        local x = streamReadFloat32(streamId)
        local y = streamReadFloat32(streamId)
        local z = streamReadFloat32(streamId)
        local alpha = streamReadFloat32(streamId)
        self.cameraRotY = alpha

        self.isObjectInRange = streamReadBool(streamId)
        if self.isObjectInRange then
            -- TODO: compress
            self.lastFoundObjectMass = streamReadFloat32(streamId)
        else
            self.lastFoundObjectMass = nil
        end
        self.isCarryingObject = streamReadBool(streamId)
        local isOnGround = streamReadBool(streamId)

        if self.isOwner then
            local index = streamReadInt32(streamId)
            --print("CLIENT ( "..tostring(self).." ): x/y/z = "..tostring(x).." / "..tostring(y).." / "..tostring(z))
            -- remove history entries before the one sent by the server
            while self.networkInformation.history[1] ~= nil and self.networkInformation.history[1].index <= index do
                table.remove(self.networkInformation.history, 1)
            end
            -- set position sent by server
            setCCTPosition(self.controllerIndex, x, y, z)
            -- move cct from the rest of the history queue
            -- Accumulate moves from multiple history entries so that we never apply more than 5 moveCCT's
            local history = self.networkInformation.history
            local numHistory = #history
            if numHistory <= 5 then
                for i=1,numHistory do
                    moveCCT(self.controllerIndex, history[i].movementX, history[i].movementY, history[i].movementZ, self.cctMovementCollisionMask)
                end
            else
                -- Accumulate moves with different amounts so that we achieve exactly the correct historty
                -- Some will use floored, some will use floored + 1
                -- Use the smaller amount for the older moves as errors for older moves potentially leads to larger errors now than for more recent ones
                local accumSizeSmall = math.floor(numHistory / 5)
                local numSmall = 5 - numHistory + accumSizeSmall * 5
                local startI = 1
                for i=1,5 do
                    local endI
                    if i <= numSmall then
                        endI = startI+accumSizeSmall-1
                    else
                        endI = startI+accumSizeSmall
                    end
                    local movementX, movementY, movementZ = 0,0,0
                    for j=startI,endI do
                        movementX = movementX + history[j].movementX
                        movementY = movementY + history[j].movementY
                        movementZ = movementZ + history[j].movementZ
                    end
                    moveCCT(self.controllerIndex, movementX, movementY, movementZ, self.cctMovementCollisionMask)
                    startI = endI+1
                end
            end
            -- set target physics index to current index
            self.networkInformation.updateTargetTranslationPhysicsIndex = getPhysicsUpdateIndex() -- update until the current physics index is simulated
            -- [animation]
            self.baseInformation.isCrouched = streamReadBool(streamId)
            --
        else
            local isControlled = streamReadBool(streamId)
            if isControlled ~= self.isControlled then
                self:moveToAbsoluteInternal(x, y, z)
                if isControlled then
                    self:onEnter(false)
                else
                    self:onLeave()
                end
            else
                -- other clients: set position, refrain from using target index and start new network interpolation phase
                setTranslation(self.rootNode, x, y, z)
                self.networkInformation.interpolatorPosition:setTargetPosition(x, y, z)
                if isOnGround then
                    self.networkInformation.interpolatorOnGround:setTargetValue(1.0)
                else
                    self.networkInformation.interpolatorOnGround:setTargetValue(0.0)
                end
                self.networkInformation.updateTargetTranslationPhysicsIndex = -1
                self.networkInformation.interpolationTime:startNewPhaseNetwork()
                -- force update
                self:raiseActive()
            end
            -- [animation]
            self.baseInformation.isCrouched = streamReadBool(streamId)
            --
        end
    else
        -- server code (read data from client)
        if connection == self.networkInformation.creatorConnection then
            -- we received translation information from client and we ask the physics to move the avatar; we insert the current physics index in the history queue and force an update()
            local movementX=streamReadFloat32(streamId)
            local movementY=streamReadFloat32(streamId)
            local movementZ=streamReadFloat32(streamId)

            local qx = streamReadFloat32(streamId)
            local qy = streamReadFloat32(streamId)
            local qz = streamReadFloat32(streamId)
            local qw = streamReadFloat32(streamId)

            local index = streamReadInt32(streamId)
            local isControlled = streamReadBool(streamId)

            moveCCT(self.controllerIndex, movementX, movementY, movementZ, self.cctMovementCollisionMask)

            self.networkInformation.interpolationTime:startNewPhaseNetwork()
            self.networkInformation.interpolatorQuaternion:setTargetQuaternion(qx, qy, qz, qw)
            local physicsIndex = getPhysicsUpdateIndex()
            table.insert(self.networkInformation.history, {index=index, physicsIndex = physicsIndex})

            self.networkInformation.updateTargetTranslationPhysicsIndex = physicsIndex -- update until the current physics index is simulated

            self:raiseActive()
            if isControlled ~= self.isControlled then
                if isControlled then
                    self:onEnter(false)
                else
                    self:onLeave()
                end
            end
            -- [animation]
            self.baseInformation.isCrouched = streamReadBool(streamId)
            --
            if self.isCarryingObject then
                self.networkInformation.rotateObject = streamReadBool(streamId)
                if self.networkInformation.rotateObject then
                    self.networkInformation.rotateObjectInputH = streamReadFloat32(streamId)
                    self.networkInformation.rotateObjectInputV = streamReadFloat32(streamId)
                end
            end
        end
    end
end


---Writes to network stream via update
-- @param integer streamId id of the stream to read
-- @param integer timestamp timestamp of the packet
-- @param table connection connection information
function Player:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        -- server code (send data to client)
        local x, y, z = getTranslation(self.rootNode)
        --print("SERVER ( "..tostring(self).."/"..tostring(self.controllerName).."/"..tostring(self.networkInformation.creatorConnection).." ): x/y/z="..tostring(x).." / "..tostring(y).." / "..tostring(z).."   self.sendIndex="..tostring(self.networkInformation.sendIndex))
        streamWriteFloat32(streamId, x)
        streamWriteFloat32(streamId, y)
        streamWriteFloat32(streamId, z)

        local dx, _, dz = localDirectionToLocal(self.cameraNode, getParent(self.cameraNode), 0, 0, 1)
        local alpha = math.atan2(dx, dz)
        streamWriteFloat32(streamId, alpha)

        streamWriteBool(streamId, self.isObjectInRange)
        if self.isObjectInRange then
            streamWriteFloat32(streamId, self.lastFoundObjectMass)
        end
        streamWriteBool(streamId, self.isCarryingObject)
        streamWriteBool(streamId, self.baseInformation.isOnGroundPhysics)
        local isOwner = connection == self.networkInformation.creatorConnection
        if isOwner then
            streamWriteInt32(streamId, self.networkInformation.sendIndex)
            -- [animation]
            local isCrouching = self.baseInformation.isCrouched
            streamWriteBool(streamId, isCrouching)
            --
        else
            streamWriteBool(streamId, self.isControlled)
            -- [animation]
            local isCrouching = self.baseInformation.isCrouched or self.playerStateMachine:isActive("crouch")
            streamWriteBool(streamId, isCrouching)
            --
        end
    else
        -- client code (send data to server)
        if self.isOwner then
            -- sending translation information to the server and reset the translations accumulated over the update() calls
            streamWriteFloat32(streamId, self.networkInformation.tickTranslation[1])
            streamWriteFloat32(streamId, self.networkInformation.tickTranslation[2])
            streamWriteFloat32(streamId, self.networkInformation.tickTranslation[3])
            self.networkInformation.tickTranslation[1] = 0.0
            self.networkInformation.tickTranslation[2] = 0.0
            self.networkInformation.tickTranslation[3] = 0.0
            local x, y, z, w = getQuaternion(self.cameraNode)
            streamWriteFloat32(streamId, x)                    -- ? ToDo: Utils.writeCompressedQuaternion()
            streamWriteFloat32(streamId, y)
            streamWriteFloat32(streamId, z)
            streamWriteFloat32(streamId, w)

            streamWriteInt32(streamId, self.networkInformation.index)
            streamWriteBool(streamId, self.isControlled)
            -- [animation]
            local isCrouching = self.playerStateMachine:isActive("crouch")
            streamWriteBool(streamId, isCrouching)
            --
            if self.isCarryingObject then
                streamWriteBool(streamId, self.networkInformation.rotateObject)
                if self.networkInformation.rotateObject then
                    streamWriteFloat32(streamId, self.networkInformation.rotateObjectInputH)
                    streamWriteFloat32(streamId, self.networkInformation.rotateObjectInputV)
                end
            end
        end
    end
end


---Function called when mouse is moved (call from BaseMission).
-- @param float posX position of the mouse
-- @param float posY position of the mouse
-- @param bool isDown 
-- @param bool isUp 
-- @param button  
function Player:mouseEvent(posX, posY, isDown, isUp, button)
end


---A function to check if input is allowed. Player is entered and is a client as well as the gui is visible.
-- @return bool true if input is allowed.
function Player:getIsInputAllowed()
    return self.isEntered and self.isClient and not g_gui:getIsGuiVisible()
end


---Updates the parameters that will drive the animation
-- @param float dt delta time in ms
function Player:updateAnimationParameters(dt)
    local ni = self.networkInformation
    --local dx = (ni.interpolatorPosition.targetPositionX - ni.interpolatorPosition.lastPositionX)
    local dy = (ni.interpolatorPosition.targetPositionY - ni.interpolatorPosition.lastPositionY)
    --local dz = (ni.interpolatorPosition.targetPositionZ - ni.interpolatorPosition.lastPositionZ)
    --local vx = dx / (ni.interpolationTime.interpolationDuration * 0.001)
    local vy = dy / (ni.interpolationTime.interpolationDuration * 0.001)
    --local vz = dz / (ni.interpolationTime.interpolationDuration * 0.001)
    --local dirX, dirZ = math.sin(self.graphicsRotY), math.cos(self.graphicsRotY)
    --local estimatedForwardVelocity = vx * dirX + vz * dirZ
    -- @see using calculation in Player:updateRotation() for a less unstable speed
    -- self.lastEstimatedForwardVelocity = self.lastEstimatedForwardVelocity * 0.5 + estimatedForwardVelocity * 0.5

    if not self.isEntered and self.baseInformation.animDt ~= nil and self.baseInformation.animDt ~= 0 then
        self.oldYaw = self.newYaw
        self.newYaw = self.cameraRotY
        self.estimatedYawVelocity = MathUtil.getAngleDifference(self.newYaw, self.oldYaw) / (self.baseInformation.animDt * 0.001)
        self.baseInformation.animDt = 0
    end

    local bi = self.baseInformation
    self.model:setAnimationParameters(bi.isOnGround, bi.isInWater, bi.isCrouched, bi.isCloseToGround, self.lastEstimatedForwardVelocity, vy, self.estimatedYawVelocity)
end


---Updates information related to the player and the water level. It is used for particle effects when plunging and checking if the player is in water.
function Player:updateWaterParams()
    local x, y, z = getWorldTranslation(self.rootNode)

    g_currentMission.environmentAreaSystem:getWaterYAtWorldPositionAsync(x, y, z, function(_, waterY)
        self.waterY = waterY or -2000
    end, nil, nil)

    local playerY = y - self.model.capsuleTotalHeight * 0.5
    local deltaWater = playerY - self.waterY

    local waterLevel = self.baseInformation.waterLevel
    local velocityY

    if deltaWater < -50 then
        return
    end

    if not self.isEntered then
        velocityY = self.model.animationInformation.parameters.verticalVelocity.value
    else
        velocityY = self.motionInformation.currentSpeedY
    end

    self.baseInformation.wasInWater = self.baseInformation.isInWater
    self.baseInformation.isInWater = deltaWater <= waterLevel
    self.baseInformation.waterDepth = math.max(0, self.waterY - playerY)

    if not self.baseInformation.wasInWater and self.baseInformation.isInWater and velocityY < self.baseInformation.plungedYVelocityThreshold then
        self.baseInformation.plungedInWater = true
    else
        self.baseInformation.plungedInWater = false
    end
end


---Main update function for the player. Taking care of: fx, water parms, sound, player states, motion, debug, action events, hand tools, animation, object picking, IK
-- @param float dt delta time in ms
function Player:update(dt)
    self.time = self.time + dt

    -- print(string.format("-- [Player:update][%s] isEntered(%s) isServer(%s) isClient(%s) isControlled(%s)", tostring(self), tostring(self.isEntered), tostring(self.isServer), tostring(self.isClient), tostring(self.isControlled)))
    if not self.isEntered and self.isClient and self.isControlled then
        self:updateFX()
    end

    -- check if the player is on ground
    if self.isServer or self.isEntered then
        local _, _, isOnGround = getCCTCollisionFlags(self.controllerIndex)
        self.baseInformation.isOnGroundPhysics = isOnGround
    end

    if self.isClient and self.isControlled then
        self:updateWaterParams()
        if Platform.hasPlayer then
            self:updateSound()
        end
    end

    if self.isEntered and self.isClient and not g_gui:getIsGuiVisible() then
        if not g_currentMission.isPlayerFrozen then
            self:updatePlayerStates()
            self.playerStateMachine:update(dt)
            self:recordPositionInformation()

            local bobDelta = 0
            if self.cameraBobbingEnabled and not self.thirdPersonViewActive then
                bobDelta = self:cameraBob(dt)
            end
            self:updateCameraTranslation(bobDelta)

            self:debugDraw()
            self.playerStateMachine:debugDraw(dt)

            if not self.walkingIsLocked then
                self.rotX = self.rotX - self.inputInformation.pitchCamera * g_gameSettings:getValue(GameSettings.SETTING.CAMERA_SENSITIVITY)
                self.rotY = self.rotY - self.inputInformation.yawCamera * g_gameSettings:getValue(GameSettings.SETTING.CAMERA_SENSITIVITY)

                if self.thirdPersonViewActive then
                    self.rotX = math.min(0, math.max(-1, self.rotX))

                    -- Rotate camera target around player
                    setRotation(self.thirdPersonLookatNode, -self.rotX, self.rotY, 0)

                    -- DebugUtil.drawDebugNode(self.thirdPersonLookatNode, "thirdPersonLookatNode", false)
                    -- DebugUtil.drawDebugNode(self.thirdPersonLookfromNode, "thirdPersonLookfromNode", false)
                else
                    self.rotX = math.min(1.2, math.max(-1.5, self.rotX))
                    setRotation(self.cameraNode, self.rotX, self.rotY, 0)
                    setRotation(self.foliageBendingNode, 0, self.rotY, 0)
                end
            end
            self:updateActionEvents()

            local x, y, z = getWorldTranslation(self.cameraNode)
            g_currentMission.activatableObjectsSystem:setPosition(x, y, z)
        end
    end

    if self:hasHandtoolEquipped() then
        self.baseInformation.currentHandtool:update(dt, self:getIsInputAllowed())

        if self.playerStateMachine:isActive("swim") then
            self:unequipHandtool()
        end
    end

    self:updateInterpolation()

    local isModelVisible = (self.isClient and self.isControlled) or self.thirdPersonViewActive

    if isModelVisible then
        self:updateRotation(dt)
    end

    -- animation
    if self.isClient and self.isControlled and (not self.isEntered or isModelVisible) then
        self:updateAnimationParameters(dt)
        self.model:updateAnimations(dt)

        -- Animation Debug
        --local a,b,c = getWorldTranslation(self.rootNode)
        --b = b + 1.0
        --conditionalAnimationDebugDraw(self.model.animationInformation.player, a,b,c)
    end

    -- objects in front of player: server needs to update controlled clients, clients only themselves
    if self.allowPlayerPickUp and self.isControlled and (self.isServer or self.isEntered) then
        self:checkObjectInRange()
    end

    -- if self.isEntered or (self.isControlled and self.networkInformation.interpolationTime.isDirty) then
    if self.isEntered or self.networkInformation.interpolationTime.isDirty then
        self:raiseActive()
    end

    if self.isClient and self.isControlled and not self.isEntered and self.networkInformation.rotateObject  then
        self:rotateObject(self.networkInformation.rotateObjectInputV, 1.0, 0.0, 0.0)
        self:rotateObject(self.networkInformation.rotateObjectInputH, 0.0, 1.0, 0.0)
    end
    self:resetCameraInputsInformation()

    if self.isEntered then
        self.hudUpdater:update(dt, self:getPositionData())
    end
end


---Update function called when network ticks. Takes care of movements/position, player state machine, interpolation phase, physics, handtools. Inputs are reset here.
-- @param float dt delta time in ms
function Player:updateTick(dt)
    if self.isEntered and not g_gui:getIsGuiVisible() and not g_currentMission.isPlayerFrozen then
        self:updateKinematic(dt)
    end

    self.playerStateMachine:updateTick(dt)

    if self:hasHandtoolEquipped() then
        self.baseInformation.currentHandtool:updateTick(dt, self:getIsInputAllowed())
    end
    self:updateNetworkMovementHistory()
    self:updateInterpolationTick()

    self:resetInputsInformation()


    -- -------------------------
    -- @todo: check and add again
    -- -------------------------
    --     local xt, yt, zt = getTranslation(self.rootNode)
    --     --[[
    --     if GS_PLATFORM_PLAYSTATION or GS_PLATFORM_XBOX then
    --         xt = xt + self.movementX
    --         zt = zt + self.movementZ
    --         yt = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, xt, 300, zt) + self.height
    --         setTranslation(self.rootNode, xt, yt, zt)
    --     end
    --     --]]
    -- -------------------------
    if self.isServer and self.isControlled then
        if not GS_PLATFORM_PC then
            local x, y, z = getTranslation(self.rootNode)
            local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
            if not NetworkUtil.getIsWorldPositionInCompressionRange(x, paramsXZ) or
               not NetworkUtil.getIsWorldPositionInCompressionRange(z, paramsXZ) or
               getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z) > y + 20
            then
                self:moveTo(g_currentMission.playerStartX, g_currentMission.playerStartY, g_currentMission.playerStartZ, g_currentMission.playerStartIsAbsolute, false)
                return
            end
        end
    end
    -- -------------------------

    -- Prevent player from getting stuck in a high level of snow
    if self.isControlled and not self.noClipEnabled then  -- disable if noClip mode is enabled to allow moving below the terrain
        local px, py, pz = getTranslation(self.rootNode)
        local dy = DensityMapHeightUtil.getCollisionHeightAtWorldPos(px, py, pz)

        local heightOffset =  0.5 * self.model.capsuleHeight -- for root node origin to terrain
        if py < dy + heightOffset - 0.1 then
            py = dy + heightOffset + 0.05 -- 5cm above so no clipping occurs. Gravity will fix it.
            setTranslation(self.rootNode, px, py, pz)
        end
    end
end


---Disable given input action
function Player:setInputState(inputAction, state)
--#debug     assertWithCallstack(inputAction ~= nil)
    local id = self.inputInformation.registrationList[inputAction].eventId
    g_inputBinding:setActionEventActive(id, state)
    g_inputBinding:setActionEventTextVisibility(id, state)
    self.inputInformation.registrationList[inputAction].lastState = state
end









---Update action event states and input hint display.
function Player:updateActionEvents()
    -- light
    local isDark = not g_currentMission.environment.isSunOn
    local eventIdToggleLight = self.inputInformation.registrationList[InputAction.TOGGLE_LIGHTS_FPS].eventId
    if self.playerStateMachine:isAvailable("useLight") and isDark then
        g_inputBinding:setActionEventTextVisibility(eventIdToggleLight, isDark and self.model:getHasTorch())
    end

    local stateSwitchHandTool = false
    local stateActivateHandTool = false
    local stateInteract = false
    local stateAnimalPet = false
    local stateEnter = false
    local stateThrowObject = false
    local stateObjectLeftRight = false
    local stateObjectUpDown = false

    -- tools
    if self.playerStateMachine:isAvailable("cycleHandtool") then
        stateSwitchHandTool = true
    end

    if self:hasHandtoolEquipped() then
        stateActivateHandTool = true
        self.playerStateMachine:isAvailable("activateObject")
    else
        if self.playerStateMachine:isAvailable("throw") then
            stateThrowObject = true
        end

        if self.isCarryingObject then
            stateObjectLeftRight = true
            stateObjectUpDown = true
        end

        if self.playerStateMachine:isAvailable("animalPet") then
            local eventIdActivateObject = self.inputInformation.registrationList[InputAction.ANIMAL_PET].eventId
            stateAnimalPet = true
            g_inputBinding:setActionEventText(eventIdActivateObject, g_i18n:getText("action_petAnimal"))
        end

        local eventIdInteract = self.inputInformation.registrationList[InputAction.INTERACT].eventId
        if self.playerStateMachine:isAvailable("drop") then
            g_inputBinding:setActionEventText(eventIdInteract, g_i18n:getText("action_dropObject"))
            stateInteract = true
        elseif self.playerStateMachine:isAvailable("pickup") then
            g_inputBinding:setActionEventText(eventIdInteract, g_i18n:getText("action_pickUpObject"))
            stateInteract = true
        elseif self.playerStateMachine:isAvailable("animalInteract") or self.playerStateMachine:isActive("animalInteract") then
            local animalInteractState = self.playerStateMachine:getState("animalInteract")
            local animalInteractText = string.format(g_i18n:getText("action_interactAnimal"), animalInteractState.interactText)
            g_inputBinding:setActionEventText(eventIdInteract, animalInteractText)
            stateInteract = true
        end
    end

    -- enter vehicle or ride animal
    self.canRideAnimal = self.playerStateMachine:isAvailable("animalRide")
    self.canEnterVehicle = g_currentMission.interactiveVehicleInRange and g_currentMission.interactiveVehicleInRange:getIsEnterable()
    local vehicleIsRideable = self.canEnterVehicle and SpecializationUtil.hasSpecialization(Rideable, g_currentMission.interactiveVehicleInRange.specializations)
    local eventIdEnter = self.inputInformation.registrationList[InputAction.ENTER].eventId
    if self.canEnterVehicle and not vehicleIsRideable then
        g_inputBinding:setActionEventText(eventIdEnter, g_i18n:getText("button_enterVehicle"))
        stateEnter = true
    elseif self.canRideAnimal or vehicleIsRideable then
        local rideableName = ""
        if self.canRideAnimal then
            local rideState = self.playerStateMachine:getState("animalRide")
            rideableName = rideState:getRideableName()
        elseif vehicleIsRideable then
            rideableName = g_currentMission.interactiveVehicleInRange:getFullName()
        end
        g_inputBinding:setActionEventText(eventIdEnter, string.format(g_i18n:getText("action_rideAnimal"), rideableName))
        stateEnter = true
    end

    -- first disable all inactive inputs to avoid conflicts if not active in this frame
    self:disableInput(InputAction.SWITCH_HANDTOOL, stateSwitchHandTool)
    self:disableInput(InputAction.ACTIVATE_HANDTOOL, stateActivateHandTool)
    self:disableInput(InputAction.INTERACT, stateInteract)
    self:disableInput(InputAction.ANIMAL_PET, stateAnimalPet)
    self:disableInput(InputAction.ENTER, stateEnter)
    self:disableInput(InputAction.THROW_OBJECT, stateThrowObject)
    self:disableInput(InputAction.ROTATE_OBJECT_LEFT_RIGHT, stateObjectLeftRight)
    self:disableInput(InputAction.ROTATE_OBJECT_UP_DOWN, stateObjectUpDown)

    self:setInputState(InputAction.SWITCH_HANDTOOL, stateSwitchHandTool)
    self:setInputState(InputAction.ACTIVATE_HANDTOOL, stateActivateHandTool)
    self:setInputState(InputAction.INTERACT, stateInteract)
    self:setInputState(InputAction.ANIMAL_PET, stateAnimalPet)
    self:setInputState(InputAction.ENTER, stateEnter)
    self:setInputState(InputAction.THROW_OBJECT, stateThrowObject)
    self:setInputState(InputAction.ROTATE_OBJECT_LEFT_RIGHT, stateObjectLeftRight)
    self:setInputState(InputAction.ROTATE_OBJECT_UP_DOWN, stateObjectUpDown)


    -- debug movements
    local eventIdDebugFlyToggle = self.inputInformation.registrationList[InputAction.DEBUG_PLAYER_ENABLE].eventId
    g_inputBinding:setActionEventActive(eventIdDebugFlyToggle, g_flightModeEnabled)
    local eventIdDebugFlyUpDown = self.inputInformation.registrationList[InputAction.DEBUG_PLAYER_UP_DOWN].eventId
    g_inputBinding:setActionEventActive(eventIdDebugFlyUpDown, g_flightModeEnabled)
end


---Updates interpolations for physics, camera and position
function Player:updateInterpolationTick()
    if self.isEntered then
        local xt, yt, zt = getTranslation(self.rootNode)

        -- Reuse the existing target position if the change is very small to avoid jitter
        local interpPos = self.networkInformation.interpolatorPosition
        if math.abs(xt-interpPos.targetPositionX) < 0.001 and math.abs(yt-interpPos.targetPositionY) < 0.001 and math.abs(zt-interpPos.targetPositionZ) < 0.001 then
            xt, yt, zt = interpPos.targetPositionX, interpPos.targetPositionY, interpPos.targetPositionZ
        end
        self.networkInformation.interpolatorPosition:setTargetPosition(xt, yt, zt)

        if self.baseInformation.isOnGroundPhysics then
            self.networkInformation.interpolatorOnGround:setTargetValue(1.0)
        else
            self.networkInformation.interpolatorOnGround:setTargetValue(0.0)
        end
        self.networkInformation.interpolationTime:startNewPhase(75)
    elseif self.networkInformation.updateTargetTranslationPhysicsIndex >= 0 then
        local xt, yt, zt = getTranslation(self.rootNode)
        if getIsPhysicsUpdateIndexSimulated(self.networkInformation.updateTargetTranslationPhysicsIndex) then
            self.networkInformation.updateTargetTranslationPhysicsIndex = -1
        else
            -- Reuse the existing target position if the change is very small to avoid jitter
            local interpPos = self.networkInformation.interpolatorPosition
            if math.abs(xt-interpPos.targetPositionX) < 0.001 and math.abs(yt-interpPos.targetPositionY) < 0.001 and math.abs(zt-interpPos.targetPositionZ) < 0.001 then
                xt, yt, zt = interpPos.targetPositionX, interpPos.targetPositionY, interpPos.targetPositionZ
            end
        end
        self.networkInformation.interpolatorPosition:setTargetPosition(xt, yt, zt)
        if self.baseInformation.isOnGroundPhysics then
            self.networkInformation.interpolatorOnGround:setTargetValue(1.0)
        else
            self.networkInformation.interpolatorOnGround:setTargetValue(0.0)
        end
        self.networkInformation.interpolatorQuaternion:setTargetQuaternion(self.networkInformation.interpolatorQuaternion.targetQuaternionX, self.networkInformation.interpolatorQuaternion.targetQuaternionY, self.networkInformation.interpolatorQuaternion.targetQuaternionZ, self.networkInformation.interpolatorQuaternion.targetQuaternionW)
        self.networkInformation.interpolationTime:startNewPhase(75)
    end
end


---Updates interpolations for physics, camera and position
function Player:updateInterpolation()
    if self.isControlled then
        local needsCameraInterp = self.isServer and not self.isEntered
        local needsPositionInterp = self.isClient

        if needsCameraInterp or needsPositionInterp then
            if self.networkInformation.interpolationTime.isDirty then
                self.networkInformation.interpolationTime:update(g_physicsDtUnclamped)
                if needsCameraInterp then
                    local qx, qy, qz, qw = self.networkInformation.interpolatorQuaternion:getInterpolatedValues(self.networkInformation.interpolationTime.interpolationAlpha)

                    setQuaternion(self.cameraNode, qx, qy, qz, qw)
                end
                if needsPositionInterp then
                    local x, y, z = self.networkInformation.interpolatorPosition:getInterpolatedValues(self.networkInformation.interpolationTime.interpolationAlpha)

                    -- xyz is center of the CCT capsule. We subtract a radius and half the height to get to ground level
                    local radius, height = self.model:getCapsuleSize()
                    setTranslation(self.graphicsRootNode, x, y - radius - height / 2, z)

                    local isOnGroundFloat = self.networkInformation.interpolatorOnGround:getInterpolatedValue(self.networkInformation.interpolationTime.interpolationAlpha)
                    self.baseInformation.isOnGround = isOnGroundFloat > 0.99
                    self.baseInformation.isCloseToGround = isOnGroundFloat > 0.01
                end
            end
        end
    end
end


---
function Player:updateNetworkMovementHistory()
    if self.isEntered and self.isClient then
        self:raiseDirtyFlags(self.networkInformation.dirtyFlag)
    elseif self.isServer and not self.isEntered and self.isControlled then
        -- find the latest index, which is already simulated now
        local latestSimulatedIndex = -1
        while self.networkInformation.history[1] ~= nil and getIsPhysicsUpdateIndexSimulated(self.networkInformation.history[1].physicsIndex) do
            latestSimulatedIndex = self.networkInformation.history[1].index
            table.remove(self.networkInformation.history, 1)
        end
        if latestSimulatedIndex >= 0 then
            self.networkInformation.sendIndex = latestSimulatedIndex
            self:raiseDirtyFlags(self.networkInformation.dirtyFlag)
        end
    end
end


---Updates rotation of player avatar over the network
-- @param float dt delta time in ms
function Player:updateRotation(dt)
    if not self.isEntered then
        local animDt = 60
        self.animUpdateTime = self.animUpdateTime + dt
        if self.animUpdateTime > animDt then
            if self.isServer then
                local x, _, z = localDirectionToLocal(self.cameraNode, getParent(self.cameraNode), 0, 0, 1)
                local alpha = math.atan2(x, z)
                self.cameraRotY = alpha
            end

            local x, y, z = getTranslation(self.graphicsRootNode)
            local dx, _, dz = x - self.lastAnimPosX, y - self.lastAnimPosY, z - self.lastAnimPosZ
            local dirX, dirZ = -math.sin(self.cameraRotY), -math.cos(self.cameraRotY)
            local movementDist = dx * dirX + dz * dirZ -- Note: |dir| = 1

            if (dx * dx + dz * dz) < 0.001 then
                self.targetGraphicsRotY = self.cameraRotY + math.rad(180.0)
            else
                if movementDist > -0.001 then
                    self.targetGraphicsRotY = math.atan2(dx, dz)
                else
                    self.targetGraphicsRotY = math.atan2(-dx, -dz)
                end
            end

            dirX, dirZ = -math.sin(self.targetGraphicsRotY), -math.cos(self.targetGraphicsRotY)
            movementDist = dx * dirX + dz * dirZ -- Note: |dir| = 1
            movementDist = self.walkDistance * 0.2 + movementDist * 0.8
            self.walkDistance = movementDist
            self.lastEstimatedForwardVelocity = -movementDist / (self.animUpdateTime * 0.001)

            self.lastAnimPosX = x
            self.lastAnimPosY = y
            self.lastAnimPosZ = z

            self.baseInformation.animDt = self.animUpdateTime
            self.animUpdateTime = 0
        end

        self.targetGraphicsRotY = MathUtil.normalizeRotationForShortestPath(self.targetGraphicsRotY, self.graphicsRotY)
        local maxDeltaRotY = math.rad(0.5) * dt
        self.graphicsRotY = math.min(math.max(self.targetGraphicsRotY, self.graphicsRotY - maxDeltaRotY), self.graphicsRotY + maxDeltaRotY)

        self.model:setSkeletonRotation(self.graphicsRotY)
    elseif self.thirdPersonViewActive then
        local x, y, z = getTranslation(self.graphicsRootNode)
        local dx, _, dz = x - self.lastAnimPosX, y - self.lastAnimPosY, z - self.lastAnimPosZ

        local horizontalSpeed = math.sqrt(dx * dx + dz * dz)
        self.horizontalSpeed = horizontalSpeed
        self.lastEstimatedForwardVelocity = horizontalSpeed / (dt * 0.001)

        -- At speed 0, dirY is also 0 so it always resets to a base rotation.
        if horizontalSpeed > 0.0001 then
            local dirY = MathUtil.getYRotationFromDirection(dx, dz)
            local newY = self.graphicsRotY

            local diff = (dirY - newY) / (dt * 0.05)
            diff = MathUtil.clamp(diff, -0.1, 0.1)

            newY = newY + diff

            self.graphicsRotY = newY
            self.model:setSkeletonRotation(newY)
            self.cameraRotY = newY
        end

        self.oldYaw = self.newYaw
        self.newYaw = self.cameraRotY

        -- Used for player rotation in animation
        self.estimatedYawVelocity = MathUtil.getAngleDifference(self.newYaw, self.oldYaw) / dt * math.min(self.horizontalSpeed * 50, 10)

        self.lastAnimPosX = x
        self.lastAnimPosY = y
        self.lastAnimPosZ = z

        self.baseInformation.animDt = dt
    end
end


---Let position information of the root node of the player
-- @return float posX x position of player
-- @return float posY y position of player
-- @return float posZ z position of player
-- @return float graphicsRotY rotation of the player
function Player:getPositionData()
    local posX, posY, posZ = getTranslation(self.rootNode)
    if self.isClient and self.isControlled and self.isEntered then
        return posX, posY, posZ, self.rotY
    else
        return posX, posY, posZ, self.graphicsRotY + math.pi
    end
end


---Sets all ik chain node to dirty so that they are recalculated
function Player:setIKDirty()
    self.model:setIKDirty()
end


---Locks player input
-- @param bool locked if true, will lock input
function Player:lockInput(locked)
    self.lockedInput = locked
end


---Vehicle can be entered
-- @return bool canBeEntered vehicle is in range to be entered
function Player:getCanEnterVehicle()
    return self.canEnterVehicle and not self:getCanEnterRideable()
end


---Vehicle can be entered
-- @return bool canBeEntered vehicle is in range to be entered
function Player:getCanEnterRideable()
    if self.canEnterVehicle then
        local vehicle = g_currentMission.interactiveVehicleInRange
        if vehicle ~= nil then
            if SpecializationUtil.hasSpecialization(Rideable, vehicle.specializations) then
                return true
            end
        end
    end

    return false
end


---Moves the player to the given position, with the given y offset to the terrain
-- @param float x new x position
-- @param float y new y position
-- @param float z new z position
-- @param bool isAbsolute if true, Y coordinate is in absolute, not calculated from terrain height
-- @param bool isRootNode if true, coordinates are expected to be at the bottom of the player capsule, otherweise half capsule height will be added to y
function Player:moveTo(x, y, z, isAbsolute, isRootNode)
    self:unequipHandtool()

    if not self.isServer and self.isOwner then
        g_client:getServerConnection():sendEvent(PlayerTeleportEvent.new(x, y, z, isAbsolute, isRootNode))
    end
    if not isAbsolute then
        local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)
        y = terrainHeight + y
    end
    if not isRootNode then
        y = y + self.model.capsuleTotalHeight * 0.5
    end
    self:moveToAbsoluteInternal(x, y, z)
end


---Moves the player root node to the given position, such that the feet are at x, y, z
-- @param float x new x position
-- @param float y new y position
-- @param float z new z position
function Player:moveToAbsolute(x, y, z)
    self:moveTo(x, y, z, true, false)
end


---Moves the player to the given position, such that the root node is at x, y, z
-- @param float x new x position
-- @param float y new y position
-- @param float z new z position
function Player:moveRootNodeToAbsolute(x, y, z)
    self:moveTo(x, y, z, true, true)
end


---Moves player to vehicle exit node
-- @param table exitVehicle vehicle class that will be used to get the exit node to place the player
function Player:moveToExitPoint(exitVehicle)
    if exitVehicle.getExitNode == nil then
        return
    end

    local exitPoint = exitVehicle:getExitNode()
    local x, y, z = getWorldTranslation(exitPoint)
    local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)

    y = math.max(terrainHeight + 0.1, y + 0.9)
    self:moveToAbsolute(x, y, z)
    local dx, _, dz = localDirectionToWorld(exitPoint, 0, 0, -1)
    self.rotY = MathUtil.getYRotationFromDirection(dx, dz)

    --self.targetGraphicsRotY = self.rotY
    --self.graphicsRotY = self.rotY
    --(I) setRotation(self.graphicsRootNode, 0, self.graphicsRotY, 0)
    setRotation(self.cameraNode, self.rotX, self.rotY, 0)
end


---Set player rotation
-- @param float rotX set rotation x parameter; vertical X rotation is clamped
-- @param float rotY set rotation y parameter (graphics node, target graphics and camera)
function Player:setRotation(rotX, rotY)
    self.rotX = math.min(1.2, math.max(-1.5, rotX))
    self.rotY = rotY

    self.graphicsRotY = rotY
    self.cameraRotY = rotY
    self.targetGraphicsRotY = rotY
end


---Move player root node and graphics node to a specific position. Updates interpolation parameters
-- @param float x new x position
-- @param float y new y position
-- @param float z new z position
function Player:moveToAbsoluteInternal(x, y, z)
    setTranslation(self.rootNode, x, y, z)
    setTranslation(self.graphicsRootNode, x, y, z)

    self.networkInformation.interpolationTime:reset()
    self.networkInformation.interpolatorPosition:setPosition(x,y,z)
    self.networkInformation.updateTargetTranslationPhysicsIndex = -1

    self.lastAnimPosX = x
    self.lastAnimPosY = y
    self.lastAnimPosZ = z
    self.walkDistance = 0

    local _
    self.baseInformation.lastPositionX, _, self.baseInformation.lastPositionZ = getTranslation(self.graphicsRootNode)
    -- reset stats to avoid wrong behaviour after teleporting
    self.baseInformation.isInWater = false
    self.baseInformation.waterDepth = 0
    self.baseInformation.wasInWater = false
    self.waterY = -2000
end


---Renders UI information for the player
function Player:drawUIInfo()
    if self.isClient and self.isControlled and not self.isEntered then
        if not g_gui:getIsGuiVisible() and not g_noHudModeEnabled and g_gameSettings:getValue(GameSettings.SETTING.SHOW_MULTIPLAYER_NAMES) then
            local x, y, z = getTranslation(self.graphicsRootNode)
            local x1, y1, z1 = getWorldTranslation(getCamera())
            local diffX = x - x1
            local diffY = y - y1
            local diffZ = z - z1
            local dist = MathUtil.vector3LengthSq(diffX, diffY, diffZ)
            if dist <= 100 * 100 then
                y = y + self.baseInformation.tagOffset[2]

                local user = g_currentMission.userManager:getUserByUserId(self.userId)
                if user ~= nil then
                    Utils.renderTextAtWorldPosition(x, y, z, user:getNickname(), getCorrectTextSize(0.02), 0)
                end
            end
        end
    end
end


---Draws overlay information
function Player:draw()
    if self:getIsInputAllowed() then
        if self:hasHandtoolEquipped() then
            self.baseInformation.currentHandtool:draw()
        else
            if not g_noHudModeEnabled then
                if self.playerStateMachine:isAvailable("animalPet") then
                    self.petOverlay:render()
                elseif self.playerStateMachine:isAvailable("animalInteract") and self.playerStateMachine:getState("animalInteract"):getCanClean() then
                    self.brushOverlay:render()
                elseif not self.isCarryingObject and self.isObjectInRange then
                    self.pickedUpObjectOverlay:render()
                else
                    self.aimOverlay:render()
                end
            end
        end
    end
end











---Called when player enters mission. Sets player mesh visibility. Update traffic system with player info. Register player action events.
-- @param bool isControlling true if controlled
function Player:onEnter(isControlling)
    self:raiseActive()
    if self.foliageBendingNode ~= nil and self.foliageBendingId == nil and g_currentMission.foliageBendingSystem then
        -- foliage bending
        self.foliageBendingId = g_currentMission.foliageBendingSystem:createRectangle(-0.5, 0.5, -0.5, 0.5, 0.4, self.foliageBendingNode)
    end

    if self.isServer then
        self:setOwner(self.networkInformation.creatorConnection)
    end
    if isControlling or self.isServer then
        self:raiseDirtyFlags(self.networkInformation.dirtyFlag)
    end

    self.isControlled = true
    if isControlling then
        g_messageCenter:subscribe(MessageType.INPUT_BINDINGS_CHANGED, self.onInputBindingsChanged, self)
        g_messageCenter:publish(MessageType.OWN_PLAYER_ENTERED)
        g_currentMission:addPauseListeners(self, Player.onPauseGame)
        setRotation(self.cameraNode, 0, 0, 0)
        setCamera(self.cameraNode)
        self.isEntered = true
        self:setVisibility(false)
        self:registerActionEvents()
        g_currentMission.environmentAreaSystem:setReferenceNode(self.cameraNode)
    else
        self:setVisibility(true)
    end

    self.playerHotspot:setOwnerFarmId(self.farmId)
    g_currentMission:addMapHotspot(self.playerHotspot)

    if self.isServer and not self.isEntered and g_currentMission.trafficSystem ~= nil and g_currentMission.trafficSystem.trafficSystemId ~= 0 then
        addTrafficSystemPlayer(g_currentMission.trafficSystem.trafficSystemId, self.graphicsRootNode)
    end
    self.isTorchActive = false
end


---Called when player leaves vehicle
function Player:onLeaveVehicle()
    self.playerStateMachine:deactivateState("animalRide")
    self.playerStateMachine:deactivateState("jump")
end


---Called when player Leaves mission. Update traffic system to ignore this player. Clear position history, visibility. Removes tools. Deregister from companion animal system. Moves to (0, -200, 0)
function Player:onLeave()
    if self.isControlled then
        g_messageCenter:publish(MessageType.OWN_PLAYER_LEFT)
        g_messageCenter:unsubscribe(MessageType.INPUT_BINDINGS_CHANGED, self)
    end

    g_currentMission:removeMapHotspot(self.playerHotspot)

    -- stop swim sound
    g_soundManager:stopSamples(self.model.soundInformation.samples)

    self:removeActionEvents()

    if self.foliageBendingId ~= nil then
        g_currentMission.foliageBendingSystem:destroyObject(self.foliageBendingId)
        self.foliageBendingId = nil
    end

    if self.isServer then
        self:setOwner(nil)
    end
    if self.isEntered or self.isServer then
        self:raiseDirtyFlags(self.networkInformation.dirtyFlag)
    end
    if self.isServer and not self.isEntered and g_currentMission.trafficSystem ~= nil and g_currentMission.trafficSystem.trafficSystemId ~= 0 then
        removeTrafficSystemPlayer(g_currentMission.trafficSystem.trafficSystemId, self.graphicsRootNode)
    end

    g_currentMission:addPauseListeners(self)

    --clear history
    self.networkInformation.history = {}
    self.isControlled = false
    self.isEntered = false
    self:setVisibility(false)

    if self:hasHandtoolEquipped() then
        self.baseInformation.currentHandtool:onDeactivate()
        self.baseInformation.currentHandtool:delete()
        self.baseInformation.currentHandtool = nil
    end
    local dogHouse = g_currentMission:getDoghouse(self.farmId)
    if dogHouse ~= nil and dogHouse.dog ~= nil then
        dogHouse.dog:onPlayerLeave(self)
    end

    self.model:enableTorch(false)
    self:moveToAbsoluteInternal(0, -200, 0)
end


---Sets third person mesh visibility
-- @param bool visibility if true will update visibility accordingly.
function Player:setVisibility(visibility)
    self.model:setVisibility(visibility)
end


---Check if a position is within clip distance
-- @param float x world x position
-- @param float y world y position
-- @param float z world z position
-- @param float coeff parameter is unused
-- @return bool returns true if distance to player root node is lower than clip distance
function Player:testScope(x, y, z, coeff)
    local x1, y1, z1 = getTranslation(self.rootNode)
    local dist = MathUtil.vector3Length(x1 - x, y1 - y, z1 - z)
    local clipDist = self.clipDistance
    if dist < clipDist * clipDist then
        return true
    else
        return false
    end
end


---Deletes player
function Player:onGhostRemove()
    self:delete()
end


---Empty function
function Player:onGhostAdd()
end


---Calculate a priority value from the position of the root node and the clpi distance
-- @param float skipCount 
-- @param float x world x position
-- @param float y world y position
-- @param float z world z position
-- @param float coeff parameter is unused
-- @param table connection structure containing connection information
-- @return float returns calculated priority
function Player:getUpdatePriority(skipCount, x, y, z, coeff, connection, isGuiVisible)
    if self.owner == connection then
        return 50
    end
    local x1, y1, z1 = getTranslation(self.rootNode)
    local dist = MathUtil.vector3Length(x1 - x, y1 - y, z1 - z)
    local clipDist = self.clipDistance
    return (1 - dist / clipDist) * 0.8 + 0.5 * skipCount * 0.2
end


---Toggle flight mode
-- @return string that will be displayed on console
function Player:consoleCommandToggleFlightMode()
    local usage = "Use key J to en-/disable flight mode, keys Q and E change the altitude. No Hud Mode was moved to gsHudVisibility"
    g_flightModeEnabled = not g_flightModeEnabled
    if not g_flightModeEnabled then
        self.debugFlightMode = false -- force reset flight mode
    end

    if GS_IS_MOBILE_VERSION then
        g_currentMission:onLeaveVehicle()
    end
    if g_flightModeEnabled then
        print(usage)
    end
    return "PlayerFlightMode = " .. tostring(g_flightModeEnabled)
end


---Toggle player CCT no clip mode
function Player:consoleCommandToggleNoClipMode(disableTerrainCollision)
    local usage = "Usage: gsPlayerNoClip [disableTerrainCollision]"
    local ret
    disableTerrainCollision = Utils.stringToBoolean(disableTerrainCollision)

    self.noClipEnabled = not self.noClipEnabled
    if self.noClipEnabled then
        self.cctMovementCollisionMaskBackup = self.cctMovementCollisionMask
        self.cctMovementCollisionMask = (disableTerrainCollision and 0) or CollisionFlag.TERRAIN
        ret = string.format("Enabled player noClip mode (%s)", (disableTerrainCollision and "including terrain") or "excluding terrain")
    else
        self.cctMovementCollisionMask = self.cctMovementCollisionMaskBackup
        self.cctMovementCollisionMaskBackup = nil
        ret = "Disabled player noClip mode"
    end

    return string.format("%s\n%s", ret, usage)
end


---Toggle wood cutting marker
-- @param table unusedSelf unused parameter
-- @return string that will be displayed on console
function Player.consoleCommandToggleWoodCuttingMaker(unusedSelf)
    g_woodCuttingMarkerEnabled = not g_woodCuttingMarkerEnabled
    return "WoodCuttingMarker = " .. tostring(g_woodCuttingMarkerEnabled)
end


---Toggle super-strength mode
function Player:consoleCommandToggleSuperStrongMode()
    if self.superStrengthEnabled then
        self.superStrengthEnabled = false
        self.maxPickableMass = self.superStrengthPickupMassBackup
        self.superStrengthPickupMassBackup = nil
        Player.MAX_PICKABLE_OBJECT_DISTANCE = self.superStrengthPickupDistanceBackup

        return "Player now has normal strength"
    else
        self.superStrengthEnabled = true
        self.superStrengthPickupMassBackup = self.maxPickableMass
        self.maxPickableMass = 50
        self.superStrengthPickupDistanceBackup = Player.MAX_PICKABLE_OBJECT_DISTANCE
        Player.MAX_PICKABLE_OBJECT_DISTANCE = 6.0

        return "Player now has super-strength and increased range"
    end
end



---Toggle player pickup raycast debug: displays nodeId, node name, colMask and triggerProperty of hit nodes
function Player:consoleCommandTogglePickupRaycastDebug()
    self.pickupRaycastDebugEnabled = not self.pickupRaycastDebugEnabled
    return "pickupRaycastDebugEnabled=" .. tostring(self.pickupRaycastDebugEnabled)
end


---Remove animal sound timer and sound itself (deprecated?)
function Player:deleteStartleAnimalData()
    if (self.startleAnimalSoundTimerId) then
        removeTimer(self.startleAnimalSoundTimerId)
        self.startleAnimalSoundTimerId = nil
    end
    self:deleteStartleAnimalSound()
end


---Remove animal sound(deprecated?)
function Player:deleteStartleAnimalSound()
    if (self.startleAnimalSoundNode) then
        delete(self.startleAnimalSoundNode)
        self.startleAnimalSoundNode = nil
    end
    self.startleAnimalSoundTimerId = nil
end


---Reloads IK chains. Used when modifying IK chains in the player configuration file.
-- @param table unusedSelf unused parameter
-- @return string that will be displayed on console
function Player.consoleCommandReloadIKChains(unusedSelf)
    local player = g_currentMission.player
    local style = player.model.style

    local newModel = PlayerModel.new()
    newModel:load(player.model.style.xmlFilename, true, player.isOwner, true, function(_, success, _)
        if success then
            player:setModel(newModel)
            player:setStyle(style, false)

            g_messageCenter:publish(MessageType.PLAYER_STYLE_CHANGED, style, player.userId)

            log("Finished reload")
        end
    end, nil, nil)
end


---Set torch state. This is called by the player state machine
function Player:setLightIsActive(isActive, noEventSend)
    if isActive ~= self.isTorchActive then
        self.isTorchActive = isActive
        PlayerToggleLightEvent.sendEvent(self, isActive, noEventSend)

        self.model:enableTorch(isActive, true)
    end
end

































































































---Sets a custom work style preset
function Player:setCustomWorkStylePreset(presetName)
    if self.isDeleting then
        return
    end

    self.model:applyCustomWorkStyle(presetName)
end













































---Loading hand tools for the player
-- @param string xmlFilename XML filename
-- @return table returns the handtool
function Player:loadHandTool(xmlFilename, asyncCallbackFunction, asyncCallbackArguments)
    if GS_IS_CONSOLE_VERSION and not fileExists(xmlFilename) then
        return nil
    end
    local dataStoreItem = g_storeManager:getItemByXMLFilename(xmlFilename)
    if dataStoreItem ~= nil then
        local storeItemXmlFilename = dataStoreItem.xmlFilename
        local xmlFile = loadXMLFile("TempXML", storeItemXmlFilename)
        local handToolType = getXMLString(xmlFile, "handTool.handToolType")
        delete(xmlFile)

        if handToolType ~= nil then
            local classObject = HandTool.handToolTypes[handToolType]
            if classObject == nil then
                local modName, _ = Utils.getModNameAndBaseDirectory(storeItemXmlFilename)
                if modName ~= nil then
                    handToolType = modName.."."..handToolType
                    classObject = HandTool.handToolTypes[handToolType]
                end
            end
            local handTool = nil
            if classObject ~= nil then
                handTool = classObject.new(self.isServer, self.isClient)
            else
                Logging.devError("Error: Invalid handtool type '%s'", handToolType)
            end
            if handTool ~= nil then
                if not handTool:load(storeItemXmlFilename, self, asyncCallbackFunction, asyncCallbackArguments) then
                    Logging.devError("Error: Failed to load handtool '%s'", storeItemXmlFilename)
                    handTool:delete()
                    handTool = nil
                end
            end

            return handTool
        end
    end
    return nil
end


---
function Player:equipHandtool(handtoolFilename, force, noEventSend, equippedCallbackFunction, equippedCallbackTarget)
    if self.isOwner then -- make sure we only change depth of field for locally controlled player instances
        if handtoolFilename == nil or handtoolFilename == "" then
            g_depthOfFieldManager:reset()
        else
            g_depthOfFieldManager:setManipulatedParams(0.8, 0.6, nil, nil, nil)
        end
    end

    if handtoolFilename ~= nil and handtoolFilename ~= "" and not fileExists(handtoolFilename) then
        Logging.error("Unable to equip handTool '%s'. Config file does not exist!", handtoolFilename)
    end

    PlayerSetHandToolEvent.sendEvent(self, handtoolFilename, force, noEventSend)

    local arguments = {
        equippedCallbackFunction = equippedCallbackFunction,
        equippedCallbackTarget = equippedCallbackTarget
    }

    if self:hasHandtoolEquipped() then
        if self.baseInformation.currentHandtool.configFileName:lower() ~= handtoolFilename:lower() or handtoolFilename == "" or force then
            self.baseInformation.currentHandtool:onDeactivate()
            self.baseInformation.currentHandtool:delete()
            self.baseInformation.currentHandtool = nil
        end
        if handtoolFilename ~= "" then
            self:loadHandTool(handtoolFilename, self.handToolLoaded, arguments)
        end
    else
        if handtoolFilename ~= "" then
            self:loadHandTool(handtoolFilename, self.handToolLoaded, arguments)
        end
    end
end


---Called when hand tool was fully loaded
-- @param table handTool hand tool
function Player:handToolLoaded(handTool, arguments)
    if self.baseInformation.currentHandtool ~= nil then
        self.baseInformation.currentHandtool:onDeactivate()
        self.baseInformation.currentHandtool:delete()
        self.baseInformation.currentHandtool = nil
    end

    self.baseInformation.currentHandtool = handTool

    handTool:setHandNode(self.model.rightArmToolNode)
    handTool:onActivate(self:getIsInputAllowed())

    if handTool.targets ~= nil then
        local ikChains = self.model:getIKChains()
        for ikChainId, target in pairs(handTool.targets) do
            IKUtil.setTarget(ikChains, ikChainId, target)
        end
        self:setIKDirty()
    end

    local equippedCallbackFunction = arguments.equippedCallbackFunction
    local equippedCallbackTarget = arguments.equippedCallbackTarget

    if equippedCallbackFunction ~= nil then
        equippedCallbackFunction(equippedCallbackTarget, handTool)
    end
end


---
function Player:unequipHandtool()
    self:equipHandtool("", true)
end


---
function Player:hasHandtoolEquipped()
    return self.baseInformation.currentHandtool ~= nil
end


---Get the configuration filename of a currently equipped hand tool.
-- @return string Filename of currently equipped hand tool or empty string if no hand tool is equipped
function Player:getEquippedHandtoolFilename()
    return self.baseInformation.currentHandtool ~= nil and self.baseInformation.currentHandtool.configFileName or ""
end





---
function Player:onEnterFarmhouse()
    if self.isServer then
        local dogHouse = g_currentMission:getDoghouse(self.farmId)
        if dogHouse ~= nil and dogHouse.dog ~= nil and dogHouse.dog.entityFollow == self.rootNode then
            dogHouse.dog:teleportToSpawn()
        end
    end
end





---
function Player:checkObjectInRange()
    -- handle picking up of objects
    if self.isServer then
        if not self.isCarryingObject then
            local x,y,z = localToWorld(self.cameraNode, 0,0,1.0)
            local dx,dy,dz = localDirectionToWorld(self.cameraNode, 0,0,-1)
            self.lastFoundObject = nil
            self.lastFoundObjectHitPoint = nil
            self.lastFoundAnyObject = nil
            raycastAll(x,y,z, dx,dy,dz, "pickUpObjectRaycastCallback", Player.MAX_PICKABLE_OBJECT_DISTANCE, self)
            self.isObjectInRange = self.lastFoundObject ~= nil
--#debug             self.raycastCallbackIndex = 0

            self.hudUpdater:setCurrentRaycastTarget(self.lastFoundAnyObject)
        else
            -- check if object still exists
            if self.pickedUpObject ~= nil then
                if not entityExists(self.pickedUpObject) then
                    Player.PICKED_UP_OBJECTS[self.pickedUpObject] = false
                    self.pickedUpObject = nil
                    self.pickedUpObjectJointId = nil
                    self.isCarryingObject = false
                end
            end
        end
    else
        -- Update HUD on client too
        if not self.isCarryingObject then
            local x,y,z = localToWorld(self.cameraNode, 0,0,1.0)
            local dx,dy,dz = localDirectionToWorld(self.cameraNode, 0,0,-1)

            self.lastFoundAnyObject = nil
            raycastAll(x,y,z, dx,dy,dz, "pickUpObjectRaycastCallback", Player.MAX_PICKABLE_OBJECT_DISTANCE, self)
--#debug             self.raycastCallbackIndex = 0

            self.hudUpdater:setCurrentRaycastTarget(self.lastFoundAnyObject)
        end
    end
end


---Callback used when raycast hists an object. Updates player information so it can be used to pickup the object.
-- @param integer hitObjectId scenegraph object id
-- @param float x world x hit position
-- @param float y world y hit position
-- @param float z world z hit position
-- @param float distance distance at which the cast hit the object
-- @return bool returns true object that was hit is valid
function Player:pickUpObjectRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId ~= g_currentMission.terrainRootNode and hitObjectId ~= self.rootNode and Player.PICKED_UP_OBJECTS[hitObjectId] ~= true then

--#debug         if self.pickupRaycastDebugEnabled then
--#debug             renderText(0.010, 0.55, 0.02, "Player raycast callback")
--#debug             local colMaskDec = getCollisionMask(hitObjectId)
--#debug             local text = string.format("nodeId=%s (%s), maskHex=%x, maskDec=%s, hasTrigger=%s", hitObjectId, getName(hitObjectId), colMaskDec, colMaskDec, getHasTrigger(hitObjectId))
--#debug             renderText(0.010, 0.53 - self.raycastCallbackIndex * 0.02, 0.016, text)
--#debug             self.raycastCallbackIndex = self.raycastCallbackIndex + 1
--#debug         end

        -- Store any object we hit, even it if cannot be picked up.
        -- This is used for the info HUD
        self.lastFoundAnyObject = hitObjectId

        if not self.isServer then
            -- only consider first potentially valid object
            return false
        end

        if self.isServer and getRigidBodyType(hitObjectId) == RigidBodyType.DYNAMIC then
            -- check if mounted:
            local canBePickedUp = true
            local object = g_currentMission:getNodeObject(hitObjectId)
            if object ~= nil then
                if object.dynamicMountObject ~= nil or object.tensionMountObject ~= nil then
                    canBePickedUp = false
                end
                if object.getCanBePickedUp ~= nil then
                    if not object:getCanBePickedUp(self) and not self.superStrengthEnabled then
                        canBePickedUp = false
                    end
                end
            end

            if canBePickedUp then
                local mass
                if object ~= nil and object.getTotalMass ~= nil then
                    mass = object:getTotalMass()
                else
                    mass = getMass(hitObjectId)
                end

                self.lastFoundObject = hitObjectId
                self.lastFoundObjectMass = mass
                self.lastFoundObjectHitPoint = {x, y, z}
            end

            -- only consider first potentially valid object
            return false
        end
    end

    return true
end


---Picks up an object and links it via a spring mechanism.
-- @param bool state if true will join the object, else the joint is removed
-- @param bool noEventSend unused parameter
function Player:pickUpObject(state, noEventSend)
    PlayerPickUpObjectEvent.sendEvent(self, state, noEventSend)

    if self.isServer then
        if state and (self.isObjectInRange and self.lastFoundObject ~= nil and entityExists(self.lastFoundObject)) and not self.isCarryingObject then
            local constr = JointConstructor.new()

            -- disable collision with CCT
            self.pickedUpObjectCollisionMask = getCollisionMask(self.lastFoundObject)
            local newPickedUpObjectCollisionFlag = bitXOR(bitAND(self.pickedUpObjectCollisionMask, self.cctMovementCollisionMask), self.pickedUpObjectCollisionMask)
            setCollisionMask(self.lastFoundObject, newPickedUpObjectCollisionFlag)

            local kinematicHelperNode, kinematicHelperNodeChild = self.model:getKinematicHelpers()
            constr:setActors(kinematicHelperNode, self.lastFoundObject)

            for i=0, 2 do
                constr:setRotationLimit(i, 0, 0)
                constr:setTranslationLimit(i, true, 0, 0)
            end

            -- set position of joint to center of the object
            local mx, my, mz = getCenterOfMass(self.lastFoundObject)
            local wx, wy, wz = localToWorld(self.lastFoundObject, mx, my, mz)
            constr:setJointWorldPositions(wx, wy, wz, wx, wy, wz)

            local nx, ny, nz = localDirectionToWorld(self.lastFoundObject, 1, 0, 0)
            constr:setJointWorldAxes(nx, ny, nz, nx, ny, nz)

            local yx, yy, yz = localDirectionToWorld(self.lastFoundObject, 0, 1, 0)
            constr:setJointWorldNormals(yx, yy, yz, yx, yy, yz)
            constr:setEnableCollision(false)

            -- Update child, used for object rotation by player
            setWorldTranslation(kinematicHelperNodeChild, wx, wy, wz)
            setWorldRotation(kinematicHelperNodeChild, getWorldRotation(self.lastFoundObject))

            -- set spring/damper ?!
            local dampingRatio = 1.0
            local mass = getMass(self.lastFoundObject)

            local rotationLimitSpring = {}
            local rotationLimitDamper = {}
            for i=1, 3 do
                rotationLimitSpring[i] = mass * 60
                rotationLimitDamper[i] = dampingRatio * 2 * math.sqrt( mass * rotationLimitSpring[i] )
                --print("   rotSpring/Damper = "..tostring(rotationLimitSpring[i]).." / "..tostring(rotationLimitDamper[i]))
            end
            constr:setRotationLimitSpring(rotationLimitSpring[1], rotationLimitDamper[1], rotationLimitSpring[2], rotationLimitDamper[2], rotationLimitSpring[3], rotationLimitDamper[3])

            local translationLimitSpring = {}
            local translationLimitDamper = {}
            for i=1, 3 do
                translationLimitSpring[i] = mass * 60
                translationLimitDamper[i] = dampingRatio * 2 * math.sqrt( mass * translationLimitSpring[i] )
                --print("   transSpring/Damper = "..tostring(translationLimitSpring[i]).." / "..tostring(translationLimitDamper[i]))
            end
            constr:setTranslationLimitSpring(translationLimitSpring[1], translationLimitDamper[1], translationLimitSpring[2], translationLimitDamper[2], translationLimitSpring[3], translationLimitDamper[3])

            if not self.superStrengthEnabled then
                local forceAcceleration = 4
                local forceLimit = forceAcceleration * mass * 40.0
                constr:setBreakable(forceLimit, forceLimit)
            end

            self.pickedUpObjectJointId = constr:finalize()

            addJointBreakReport(self.pickedUpObjectJointId, "onPickedUpObjectJointBreak", self)

            self.pickedUpObject = self.lastFoundObject
            self.isCarryingObject = true
            Player.PICKED_UP_OBJECTS[self.pickedUpObject] = true

            local object = g_currentMission:getNodeObject(self.pickedUpObject)
            if object ~= nil then
                object.thrownFromPosition = nil
            end
        else
            if self.pickedUpObjectJointId ~= nil then
                removeJoint(self.pickedUpObjectJointId)
                self.pickedUpObjectJointId = nil
                self.isCarryingObject = false
                Player.PICKED_UP_OBJECTS[self.pickedUpObject] = false

                if entityExists(self.pickedUpObject) then
                    local vx, vy, vz = getLinearVelocity(self.pickedUpObject)
                    if vx ~= nil then -- in case the object has switched from dynamic to kinematic
                        vx = MathUtil.clamp(vx, -5, 5)
                        vy = MathUtil.clamp(vy, -5, 5)
                        vz = MathUtil.clamp(vz, -5, 5)
                        setLinearVelocity(self.pickedUpObject, vx, vy, vz)
                    end
                    -- setAngularVelocity(self.pickedUpObject, vx, vy, vz)
                    setCollisionMask(self.pickedUpObject, self.pickedUpObjectCollisionMask)
                    self.pickedUpObjectCollisionMask = 0
                end

                local object = g_currentMission:getNodeObject(self.pickedUpObject)
                if object ~= nil then
                    object.thrownFromPosition = nil
                end
                self.pickedUpObject = nil
            end
        end
    end
end


---Throws an object. Activates dog to fetch a ball if conditions are met.
function Player:throwObject(noEventSend)
    PlayerThrowObjectEvent.sendEvent(self, noEventSend)
    if self.pickedUpObject ~= nil and self.pickedUpObjectJointId ~= nil then
        local pickedUpObject = self.pickedUpObject
        self:pickUpObject(false)

        local mass = getMass(pickedUpObject)

        local v = 8 * (1.1-mass/self.maxPickableMass) -- speed between 0.8 and 8.8 based on mass of current object
        local vx, vy, vz = localDirectionToWorld(self.cameraNode, 0, 0, -v)
        setLinearVelocity(pickedUpObject, vx, vy, vz)

        local object = g_currentMission:getNodeObject(pickedUpObject)
        if object ~= nil then
            object.thrownFromPosition = {getWorldTranslation(self.rootNode)}

            if object:isa(DogBall) then
                local dogHouse = g_currentMission:getDoghouse(self.farmId)
                if dogHouse ~= nil then
                    local dog = dogHouse:getDog()
                    if dog ~= nil then
                        local px,py,pz = getWorldTranslation(self.rootNode)
                        local distance, _ = getCompanionClosestDistance(dog.dogInstance, px, py, pz)
                        if distance < 10.0 then
                            dog:fetchItem(self, object)
                        end
                    end
                end
            end
        end
    elseif (self.isObjectInRange and self.lastFoundObject ~= nil) and not self.isCarryingObject then
        if entityExists(self.lastFoundObject) then
            local mass = getMass(self.lastFoundObject)

            if mass <= self.maxPickableMass then
                local v = 8 * (1.1 - mass / self.maxPickableMass) -- speed between 0.8 and 8.8 based on mass of current object
                local halfSqrt = 0.707106781
                -- Add the impulse in 45deg towards the y axis of the camera
                local vx,vy,vz = localDirectionToWorld(self.cameraNode, 0.0, halfSqrt * v, -halfSqrt * v)
                setLinearVelocity(self.lastFoundObject, vx, vy, vz)
            end
        end
    end
end


---Callback when picked-up object's joint is broken
-- @param integer jointIndex index of the joint
-- @param float breakingImpulse 
-- @return always returns false
function Player:onPickedUpObjectJointBreak(jointIndex, breakingImpulse)
    if jointIndex == self.pickedUpObjectJointId then
        self:pickUpObject(false)
    end
    -- Do not delete the joint internally, we already deleted it
    return false
end





---Update sound for the player: steps (when crouch, walk, run), swim, plunge
function Player:updateSound()
    local isCrouching, isWalking, isRunning, isSwimming
    local forwardVel

    isCrouching = self.playerStateMachine:isActive("crouch")
    isSwimming = self.playerStateMachine:isActive("swim")

    if not self.isEntered then
        forwardVel = self.model:getLastForwardVelocity()

        if isCrouching then
        elseif math.abs(forwardVel) <= self.motionInformation.maxWalkingSpeed then
            isWalking = true
        elseif math.abs(forwardVel) > self.motionInformation.maxWalkingSpeed then
            isRunning = true
        end
    else
        forwardVel = math.abs(self.motionInformation.currentSpeed)
        isWalking = self.playerStateMachine:isActive("walk")
        isRunning = self.playerStateMachine:isActive("run")
    end

    -- Detect when we start jumping or when we dropped to the ground for one-shot sound effects
    local didJump = false
    local isJumping = self.playerStateMachine:isActive("jump")
    if self.wasJumping ~= isJumping then
        self.wasJumping = isJumping

        didJump = isJumping
    end

    local isDropping = self.playerStateMachine:isActive("fall")
    local didTouchGround = false
    if self.wasDropping ~= isDropping then
        self.wasDropping = isDropping

        didTouchGround = not isDropping
    end

    self.model:setSoundParameters(forwardVel, isCrouching, isWalking, isRunning, isSwimming, self.baseInformation.plungedInWater, self.baseInformation.isInWater, self.motionInformation.coveredGroundDistance, self.motionInformation.maxSwimmingSpeed, self.baseInformation.waterLevel, didJump, didTouchGround, self.waterY)
end


---Update particle FX.
function Player:updateFX()
    if self.model.isLoaded then
        local x, y, z = getWorldTranslation(self.rootNode)

        self.model:updateFX(x, y, z, self.baseInformation.isInWater, self.baseInformation.plungedInWater, self.waterY)
    end
end


---
function Player:movePlayer(dt, movementX, movementY, movementZ)
    self.debugFlightCoolDown = self.debugFlightCoolDown - 1
    if self.debugFlightMode then
        movementY = self.inputInformation.moveUp * dt
    end

    self.networkInformation.tickTranslation[1] = self.networkInformation.tickTranslation[1] + movementX
    self.networkInformation.tickTranslation[2] = self.networkInformation.tickTranslation[2] + movementY
    self.networkInformation.tickTranslation[3] = self.networkInformation.tickTranslation[3] + movementZ
    moveCCT(self.controllerIndex, movementX, movementY, movementZ, self.cctMovementCollisionMask)

    self.networkInformation.index = self.networkInformation.index + 1
    if not self.isServer then
        -- remove old history (above 100 entries)
        while table.getn(self.networkInformation.history) > 100 do
            table.remove(self.networkInformation.history, 1)
        end
        table.insert(self.networkInformation.history, {index=self.networkInformation.index, movementX=movementX, movementY=movementY, movementZ=movementZ})
    end
end


---Apply bobbing to the camera to imitate waves or footsteps.
function Player:cameraBob(dt)
    local amplitude = 0.0
    local isSwimming = self.playerStateMachine:isActive("swim")
    local isWalking = self.playerStateMachine:isActive("walk")
    local isCrouching = self.playerStateMachine:isActive("crouch")
    local isRunning = self.playerStateMachine:isActive("run")
    local targetCameraOffset = 0.0
    local dtInSec = dt * 0.001

    if isSwimming then
        amplitude = 0.045
        targetCameraOffset = self.baseInformation.waterCameraOffset
    elseif isCrouching then
        amplitude = 0.045
    elseif isWalking or isRunning then
        amplitude = 0.025
    end

    if self.baseInformation.currentWaterCameraOffset ~= targetCameraOffset then
        local deltaOffset = targetCameraOffset - self.baseInformation.currentWaterCameraOffset
        if math.abs(deltaOffset) > 0.001 then
            self.baseInformation.currentWaterCameraOffset = self.baseInformation.currentWaterCameraOffset + deltaOffset * dtInSec / 0.75
        else
            self.baseInformation.currentWaterCameraOffset = self.baseInformation.currentWaterCameraOffset + deltaOffset
        end
        if math.abs(targetCameraOffset) > 0.001 then
            self.baseInformation.currentWaterCameraOffset = MathUtil.clamp(self.baseInformation.currentWaterCameraOffset, 0, targetCameraOffset)
        else
            self.baseInformation.currentWaterCameraOffset = math.max(self.baseInformation.currentWaterCameraOffset, 0)
        end
    end

    local delta
    if amplitude ~= 0.0 then
        local actualSpeed = self.motionInformation.currentCoveredGroundDistance / dtInSec
        local dtInSecClamped = math.min(dtInSec, 0.06)
        local timeOffset, amplitudeScale

        if isSwimming then
            timeOffset = math.min(math.max(self.motionInformation.currentCoveredGroundDistance * 1.0, 0.6 * dtInSecClamped), 3.0 * dtInSecClamped * 1.0)
            amplitudeScale = math.min(math.max(actualSpeed / 3.0, 0.5), 1.0)
        else
            timeOffset = math.min(self.motionInformation.currentCoveredGroundDistance, 3.0 * dtInSecClamped) * 3.0
            amplitudeScale = math.min(actualSpeed / 3.0, 1.0)
        end

        self.baseInformation.headBobTime = self.baseInformation.headBobTime + timeOffset
        amplitudeScale = (self.baseInformation.lastCameraAmplitudeScale + amplitudeScale) * 0.5
        delta = amplitudeScale * amplitude * math.sin(self.baseInformation.headBobTime) + self.baseInformation.currentWaterCameraOffset
        self.baseInformation.lastCameraAmplitudeScale = amplitudeScale
    else
        delta = self.baseInformation.currentWaterCameraOffset
    end

    return delta
end
















---Reset input information inbetween frames. Input is accumulated by events until read, processed and reset. Reset for input managed in updateTick() method
function Player:resetInputsInformation()
    self.inputInformation.moveRight = 0
    self.inputInformation.moveForward = 0
    self.inputInformation.moveUp = 0
    self.inputInformation.runAxis = 0
end


---Reset for input managed in update() method
function Player:resetCameraInputsInformation()
    self.inputInformation.pitchCamera = 0
    self.inputInformation.yawCamera = 0
    self.inputInformation.crouchState = Player.BUTTONSTATES.RELEASED
end


---Prints player debug information regarding motion and input.
function Player:debugDraw()
    if (self.baseInformation.isInDebug) then
        setTextColor(1, 0, 0, 1)
        local line = 0.96
        renderText(0.05, line, 0.02, "[motion]"); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("isOnGround(%s) ", tostring(self.baseInformation.isOnGround))); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("lastPosition(%3.4f, %3.4f)", self.baseInformation.lastPositionX, self.baseInformation.lastPositionZ)); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("distanceCovered(%.2f)", self.motionInformation.coveredGroundDistance)); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("inWater(%s)", tostring(self.baseInformation.isInWater))); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("currentSpeed(%.3f) speedY(%.3f)", self.motionInformation.currentSpeed, self.motionInformation.currentSpeedY)); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("rotY(%.3f)", self.graphicsRotY)); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("estimatedYaw(%.3f)", self.estimatedYawVelocity)); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("cameraRotY(%.3f)", self.cameraRotY)); line = line - 0.02


        setTextColor(0, 1, 0, 1)
        line = line - 0.02
        renderText(0.05, line, 0.02, "[input]"); line = line - 0.02
        renderText(0.05, line, 0.02, string.format("right(%3.4f)", self.inputInformation.moveRight))
        line = line - 0.02
        renderText(0.05, line, 0.02, string.format("forward(%3.4f)", self.inputInformation.moveForward))
        line = line - 0.02
        renderText(0.05, line, 0.02, string.format("pitch(%3.4f)", self.inputInformation.pitchCamera))
        line = line - 0.02
        renderText(0.05, line, 0.02, string.format("yaw(%3.4f)", self.inputInformation.yawCamera))
        line = line - 0.02
        renderText(0.05, line, 0.02, string.format("runAxis(%3.4f)", self.inputInformation.runAxis))
        line = line - 0.02
        renderText(0.05, line, 0.02, string.format("crouchState(%s)", tostring(self.inputInformation.crouchState)))
        line = line - 0.02
        renderText(0.05, line, 0.02, string.format("interactState(%s)", tostring(self.inputInformation.interactState)))
    end
end


---
function Player:getDesiredSpeed()
    local inputRight = self.inputInformation.moveRight
    local inputForward = self.inputInformation.moveForward

    if ((inputForward ~= 0.0) or (inputRight ~= 0.0)) then
        local isSwimming = self.playerStateMachine:isActive("swim")
        local isCrouching = self.playerStateMachine:isActive("crouch")
        local isFalling = self.playerStateMachine:isActive("fall")
        local isUsingHandtool = self:hasHandtoolEquipped()
        local maxSpeed = self.motionInformation.maxWalkingSpeed
        if isFalling then
            maxSpeed = self.motionInformation.maxFallingSpeed
        elseif isSwimming then
            maxSpeed = self.motionInformation.maxSwimmingSpeed
        elseif isCrouching then
            maxSpeed = self.motionInformation.maxCrouchingSpeed
        end
        local inputRun = self.inputInformation.runAxis

        if inputRun > 0.0 and not (isSwimming or isCrouching or isUsingHandtool) then -- check if we are running
            local runningSpeed = self.motionInformation.maxRunningSpeed

            if g_addTestCommands then
                runningSpeed = self.motionInformation.maxPresentationRunningSpeed
            elseif g_addCheatCommands and (g_currentMission.isMasterUser or g_currentMission:getIsServer()) then
                runningSpeed = self.motionInformation.maxCheatRunningSpeed
            end
            maxSpeed = math.max(maxSpeed + (runningSpeed - maxSpeed) * math.min(inputRun, 1.0), maxSpeed)
        end

        local magnitude = math.sqrt(inputRight * inputRight + inputForward * inputForward)
        local desiredSpeed = MathUtil.clamp(magnitude, 0.0, 1.0) * maxSpeed
        return desiredSpeed
    end
    return 0.0
end


---
function Player:recordPositionInformation()
    local currentPositionX, _, currentPositionZ = getTranslation(self.graphicsRootNode)
    local deltaPosX = currentPositionX - self.baseInformation.lastPositionX
    local deltaPosZ = currentPositionZ - self.baseInformation.lastPositionZ
    self.baseInformation.lastPositionX = currentPositionX
    self.baseInformation.lastPositionZ = currentPositionZ

    local groundDistanceCovered = MathUtil.vector2Length(deltaPosX, deltaPosZ)
    self.motionInformation.justMoved = groundDistanceCovered > 0.0

    if self.baseInformation.isOnGround then
        self.motionInformation.currentCoveredGroundDistance = groundDistanceCovered
        self.motionInformation.coveredGroundDistance = self.motionInformation.coveredGroundDistance + groundDistanceCovered
    end
end


---
function Player:calculate2DDotProductAgainstVelocity(velocity, currentSpeed, vector)
    local normalizedVelX = velocity[1] / currentSpeed
    local normalizedVelZ = velocity[3] / currentSpeed
    local vectorMagnitude = math.sqrt(vector[1] * vector[1] + vector[3] * vector[3])
    local normalizedVectorX = vector[1] / vectorMagnitude
    local normalizedVectorZ = vector[3] / vectorMagnitude
    local dot = normalizedVelX * normalizedVectorX + normalizedVelZ * normalizedVectorZ

    return dot
end


---
function Player:resetBrake()
    self:setVelocityToMotion(0.0, 0.0, 0.0)
    self:setAccelerationToMotion(0.0, 0.0, 0.0)
    self.motionInformation.brakeForce = {0.0, 0.0, 0.0}
    self.motionInformation.isBraking = false
end


---Updates player movement depending on inputs (run, crouch, swim) and apply gravity
function Player:updateKinematic(dt)
    local dtInSec = dt * 0.001
    local inputX = self.inputInformation.moveRight
    local inputZ = self.inputInformation.moveForward
    if inputX ~= 0.0 or inputZ ~= 0.0 then
        local normInputX, normInputZ = MathUtil.vector2Normalize(inputX, inputZ)
        local _
        self.motionInformation.currentWorldDirX, _, self.motionInformation.currentWorldDirZ = localDirectionToWorld(self.cameraNode, normInputX, 0.0, normInputZ)
        self.motionInformation.currentWorldDirX, self.motionInformation.currentWorldDirZ = MathUtil.vector2Normalize(self.motionInformation.currentWorldDirX, self.motionInformation.currentWorldDirZ)
    end
    local desiredSpeed = self:getDesiredSpeed()
    local desiredSpeedX = self.motionInformation.currentWorldDirX * desiredSpeed
    local desiredSpeedZ = self.motionInformation.currentWorldDirZ * desiredSpeed

    local speedChangeX = (desiredSpeedX - self.motionInformation.currentSpeedX)
    local speedChangeZ = (desiredSpeedZ - self.motionInformation.currentSpeedZ)

    if not self.baseInformation.isOnGround then
        -- reduce acceleration when in the air
        speedChangeX = speedChangeX * 0.2
        speedChangeZ = speedChangeZ * 0.2
    end

    self.motionInformation.currentSpeedX = self.motionInformation.currentSpeedX + speedChangeX
    self.motionInformation.currentSpeedZ = self.motionInformation.currentSpeedZ + speedChangeZ
    self.motionInformation.currentSpeed = math.sqrt(self.motionInformation.currentSpeedX * self.motionInformation.currentSpeedX + self.motionInformation.currentSpeedZ * self.motionInformation.currentSpeedZ)

    local movementX = self.motionInformation.currentSpeedX * dtInSec
    local movementY = 0.0
    local movementZ = self.motionInformation.currentSpeedZ * dtInSec

    -- Swim adjustment
    local _, y, _ = getWorldTranslation(self.rootNode)
    local deltaWater = y - self.waterY - self.model.capsuleTotalHeight * 0.5
    local waterLevel = self.baseInformation.waterLevel

    local distToWaterLevel = deltaWater - waterLevel

    if distToWaterLevel > 0.001 then
        -- Update gravity / vertical movement
        local gravityFactor = 3.0 -- for falling faster
        local gravitySpeedChange = gravityFactor * self.motionInformation.gravity * dtInSec
        self.motionInformation.currentSpeedY = math.max(self.motionInformation.currentSpeedY + gravitySpeedChange, self.motionInformation.gravity * 7.0) --  clamp after 7s of falling
        if distToWaterLevel < self.model.capsuleTotalHeight * 0.5 then
            -- hack to reduce unsteability in low framerate
            movementY = math.max(self.motionInformation.currentSpeedY * dtInSec, -distToWaterLevel * 0.5)
        else
            movementY = math.max(self.motionInformation.currentSpeedY * dtInSec, -distToWaterLevel)
        end
        self.motionInformation.currentSpeedY = movementY / math.max(dtInSec, 0.000001) -- calc actual speed with clamped movement
    elseif distToWaterLevel < -0.01 then
        local buoyancySpeed = -self.motionInformation.gravity
        movementY = math.min(buoyancySpeed * dtInSec, -distToWaterLevel)
        self.motionInformation.currentSpeedY = movementY / math.max(dtInSec, 0.000001) -- calc actual speed with clamped movement
    else
        self.motionInformation.currentSpeedY = 0.0
    end

    self:movePlayer(dt, movementX, movementY, movementZ)
end


---Updates player state machine
function Player:updatePlayerStates()
    if self.playerStateMachine:isAvailable("fall") then
        self.playerStateMachine:activateState("fall")
    end

    if self.baseInformation.waterDepth > 0.4 then
        self.playerStateMachine:deactivateState("crouch")
    end

    if self.baseInformation.isInWater and self.playerStateMachine:isAvailable("swim") then
        self.playerStateMachine:activateState("swim")
    end

    if (self.inputInformation.moveForward ~= 0) or (self.inputInformation.moveRight ~= 0) then
        if (self.inputInformation.runAxis > 0.0) and self.playerStateMachine:isAvailable("run") then
            self.playerStateMachine:activateState("run")
        elseif self.playerStateMachine:isAvailable("walk") then
            self.playerStateMachine:activateState("walk")
        end
    else
        self.playerStateMachine:activateState("idle")
    end
end


---Lock or unlock the player's movement. Sets the Player.walkingIsLocked flag and enables/disables movement action events accordingly.
-- @param isLocked If true, the player's movement is locked. Otherwise, it is released.
function Player:setWalkingLock(isLocked)
    self.walkingIsLocked = isLocked

    for _, inputRegistration in pairs(self.inputInformation.registrationList) do
        if inputRegistration.activeType == Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT then
            g_inputBinding:setActionEventActive(inputRegistration.eventId, not isLocked)
        end
    end

    if g_touchHandler ~= nil then
        if not isLocked then
            self.touchListenerY = g_touchHandler:registerGestureListener(TouchHandler.GESTURE_AXIS_Y, Player.touchEventLookUpDown, self)
            self.touchListenerX = g_touchHandler:registerGestureListener(TouchHandler.GESTURE_AXIS_X, Player.touchEventLookLeftRight, self)
        else
            g_touchHandler:removeGestureListener(self.touchListenerY)
            g_touchHandler:removeGestureListener(self.touchListenerX)
        end
    end
end


---Enables or disables the third person view
-- @param boolean isActive third person view is active
function Player:setThirdPersonViewActive(isActive)
    self.thirdPersonViewActive = isActive

    self:updateCameraModelTarget()
end


---Toggle player debug info display
-- @return string that will be displayed on console
function Player:consoleCommandTogglePlayerDebug()
    self.baseInformation.isInDebug = not self.baseInformation.isInDebug
    return "Player Debug = " .. tostring(self.baseInformation.isInDebug)
end


---Toggle player debug info display
-- @return string that will be displayed on console
function Player:consoleCommandThirdPersonView()
    self:setThirdPersonViewActive(not self.thirdPersonViewActive)

    return "Player Third Person = " .. tostring(self.thirdPersonViewActive)
end









































































































---Register required player action events.
function Player:registerActionEvents()
    -- register action events for the player context without switching (important when this is called from within the UI context)
    g_inputBinding:beginActionEventsModification(Player.INPUT_CONTEXT_NAME)

    for actionId, inputRegisterEntry in pairs(self.inputInformation.registrationList) do
        local _
        local startActive = false

        if inputRegisterEntry.activeType == Player.INPUT_ACTIVE_TYPE.STARTS_ENABLED then
            startActive = true
        elseif inputRegisterEntry.activeType == Player.INPUT_ACTIVE_TYPE.STARTS_DISABLED then
            startActive = false
        elseif inputRegisterEntry.activeType == Player.INPUT_ACTIVE_TYPE.IS_MOVEMENT then
            startActive = not self.walkingIsLocked
        elseif inputRegisterEntry.activeType == Player.INPUT_ACTIVE_TYPE.IS_CARRYING then
            startActive = self.isCarryingObject
        elseif inputRegisterEntry.activeType == Player.INPUT_ACTIVE_TYPE.IS_DEBUG then
            startActive = self.baseInformation.isInDebug
        end

        -- register with conflict removal flag, will disable conflicting bindings of newly registered actions
        _, inputRegisterEntry.eventId = g_inputBinding:registerActionEvent(actionId, self, inputRegisterEntry.callback, inputRegisterEntry.triggerUp, inputRegisterEntry.triggerDown, inputRegisterEntry.triggerAlways, startActive, inputRegisterEntry.callbackState, true)
        if inputRegisterEntry.text ~= nil and inputRegisterEntry.text ~= "" then
            g_inputBinding:setActionEventText(inputRegisterEntry.eventId, inputRegisterEntry.text)
        end

        g_inputBinding:setActionEventTextVisibility(inputRegisterEntry.eventId, inputRegisterEntry.textVisibility)
    end

    if g_touchHandler ~= nil then
        if not self.walkingIsLocked then
            self.touchListenerY = g_touchHandler:registerGestureListener(TouchHandler.GESTURE_AXIS_Y, Player.touchEventLookUpDown, self)
            self.touchListenerX = g_touchHandler:registerGestureListener(TouchHandler.GESTURE_AXIS_X, Player.touchEventLookLeftRight, self)
        else
            g_touchHandler:removeGestureListener(self.touchListenerY)
            g_touchHandler:removeGestureListener(self.touchListenerX)
        end
    end

    -- reset registration context, update event data in input system:
    g_inputBinding:endActionEventsModification()

    if self.isEntered then
        g_currentMission.activatableObjectsSystem:activate(Player.INPUT_CONTEXT_NAME)
    end
end


---Remove all player action events.
function Player:removeActionEvents()
    -- reset previously disabled bindings' enabled state
    g_inputBinding:resetActiveActionBindings()

    -- modify action events in player context without switching (important because this can be called from within the UI)
    g_inputBinding:beginActionEventsModification(Player.INPUT_CONTEXT_NAME)
    g_inputBinding:removeActionEventsByTarget(self)
    for _, inputRegisterEntry in pairs(self.inputInformation.registrationList) do
        inputRegisterEntry.eventId = ""
    end
    g_inputBinding:endActionEventsModification()

    if self.isEntered then
        g_currentMission.activatableObjectsSystem:deactivate(Player.INPUT_CONTEXT_NAME)
    end
end


---
function Player:touchEventLookLeftRight(value)
    if self:getIsInputAllowed() then
        local factor = (g_screenWidth / g_screenHeight) * 100
        Player.onInputLookLeftRight(self, nil, value * factor, nil, nil, false)
    end
end


---Event function for player camera horizontal axis.
-- @param nil  
-- @param float inputValue 
function Player:onInputLookLeftRight(_, inputValue, _, _, isMouse)
    if not self.lockedInput then
        if isMouse then
            inputValue = inputValue * 0.001 * 16.666
        else
            inputValue = inputValue * g_currentDt *0.001
        end
        self.inputInformation.yawCamera = self.inputInformation.yawCamera + inputValue
    end
    self.inputInformation.isMouseRotation = isMouse
end


---
function Player:touchEventLookUpDown(value)
    if self:getIsInputAllowed() then
        local factor = (g_screenHeight / g_screenWidth) * -100
        Player.onInputLookUpDown(self, nil, value * factor, nil, nil, false)
    end
end


---Event function for player camera vertical axis.
-- @param nil  
-- @param float inputValue 
function Player:onInputLookUpDown(_, inputValue, _, _, isMouse)
    if not self.lockedInput then
        local pitchValue = g_gameSettings:getValue("invertYLook") and -inputValue or inputValue
        if isMouse then
            pitchValue = pitchValue * 0.001 * 16.666
        else
            pitchValue = pitchValue * g_currentDt *0.001
        end
        self.inputInformation.pitchCamera = self.inputInformation.pitchCamera + pitchValue
    end
end


---Event function for player strafe movement.
-- @param nil  
-- @param float inputValue 
function Player:onInputMoveSide(_, inputValue)
    if not self.lockedInput then
        self.inputInformation.moveRight = self.inputInformation.moveRight + inputValue
    end
end


---Event function for player forward/backward movement.
-- @param nil  
-- @param float inputValue 
function Player:onInputMoveForward(_, inputValue)
    if not self.lockedInput then
        self.inputInformation.moveForward = self.inputInformation.moveForward + inputValue
    end
end


---Event function for player running.
-- @param nil  
-- @param float inputValue 
function Player:onInputRun(_, inputValue)
    self.inputInformation.runAxis = inputValue

    if self.debugFlightMode then
        if inputValue > 0 and self.debugFlightModeRunningFactor ~= 4.0 then
            self.debugFlightModeRunningFactor = 4.0
        elseif inputValue == 0 and self.debugFlightModeRunningFactor ~= 1.0 then
            self.debugFlightModeRunningFactor = 1.0
        end
    end
end


---Event function for crouching.
function Player:onInputCrouch(_, inputValue)
    if self.playerStateMachine:isAvailable("crouch") then
        self.playerStateMachine:activateState("crouch")
    end

    self.inputInformation.crouchState = Player.BUTTONSTATES.PRESSED
end


---Event function for rotating object.
function Player:onInputRotateObjectHorizontally(_, inputValue)
    if self.pickedUpObjectJointId ~= nil and math.abs(inputValue) > 0 then
        self:rotateObject(inputValue, 0.0, 1.0, 0.0)
    elseif self.isCarryingObject and self.isClient and self.isControlled then
        if inputValue ~= 0.0 then
            self.networkInformation.rotateObject = true
        else
            self.networkInformation.rotateObject = false
        end
        self.networkInformation.rotateObjectInputH = inputValue
    end
end


---Event function for rotating object.
function Player:onInputRotateObjectVertically(_, inputValue)
    if self.pickedUpObjectJointId ~= nil and math.abs(inputValue) > 0 then
        self:rotateObject(inputValue, 1.0, 0.0, 0.0)
    elseif self.isCarryingObject and self.isClient and self.isControlled then
        if inputValue ~= 0.0 then
            self.networkInformation.rotateObject = true
        else
            self.networkInformation.rotateObject = false
        end
        self.networkInformation.rotateObjectInputV = inputValue
    end
end


---Rotates object
function Player:rotateObject(inputValue, axisX, axisY, axisZ)
    local jointIndex = self.pickedUpObjectJointId
    if jointIndex == nil then
        return
    end

    local actor = 0

    local _, objectTransform = self.model:getKinematicHelpers()
    local rotX, rotY, rotZ = localDirectionToLocal(self.cameraNode, objectTransform, axisX, axisY, axisZ)
    local dtInSec = g_physicsDt * 0.001
    local rotation = math.rad(90.0) * dtInSec * inputValue

    rotateAboutLocalAxis(objectTransform, rotation, rotX, rotY, rotZ)
    setJointFrame(jointIndex, actor, objectTransform)
end


---Event function for jumping.
function Player:onInputJump(_, inputValue)
    if self.playerStateMachine:isAvailable("jump") then
        self.playerStateMachine:activateState("jump")
    end
end


---Event function for interacting with an animal
function Player:onInputInteract(_, inputValue)
    -- Note: we need to store pressed state for animal cleaning (see PlayerStateAnimalInteract) which is a continuous
    -- action. Therefore, this event is called onUp and onDown. When the down event is received, input will be non-zero.
    if self.inputInformation.interactState ~= Player.BUTTONSTATES.PRESSED and inputValue ~= 0 then
        if self.playerStateMachine:isAvailable("drop") then
            self.playerStateMachine:activateState("drop")
        elseif self.playerStateMachine:isAvailable("pickup") then
            self.playerStateMachine:activateState("pickup")
        elseif self.playerStateMachine:isAvailable("animalInteract") then
            self.playerStateMachine:activateState("animalInteract")
        end

        self.inputInformation.interactState = Player.BUTTONSTATES.PRESSED
    else
        self.inputInformation.interactState = Player.BUTTONSTATES.RELEASED
    end
end


---Event function for interacting with an animal
function Player:onInputActivateObject(_, inputValue)
    self.playerStateMachine:activateState("animalPet")
end


---Event function for flashlight toggle.
function Player:onInputToggleLight()
    if self.playerStateMachine:isAvailable("useLight") then
        self.playerStateMachine:activateState("useLight")
    end
end


---Event function for cycling through available hand tools.
-- @param nil  
-- @param nil  
-- @param integer direction direction in which the equipment is cycled through
function Player:onInputCycleHandTool(_, direction)
    if self.playerStateMachine:isAvailable("cycleHandtool") then
        local cycleHandtoolState = self.playerStateMachine:getState("cycleHandtool")
        cycleHandtoolState.cycleDirection = direction
        self.playerStateMachine:activateState("cycleHandtool")
    end
end


---Event function for throwing an object.
function Player:onInputThrowObject(_, inputValue)
    if self.playerStateMachine:isAvailable("throw") then
        self.playerStateMachine:activateState("throw")
    end
end


---Event function for the debug flying toggle.
function Player:onInputDebugFlyToggle()
    if not self.walkingIsDisabled then
        if self.debugFlightCoolDown <= 0 then
            if g_flightModeEnabled then
                self.debugFlightMode = not self.debugFlightMode
                self.debugFlightCoolDown = 10
            end
        end
    end
end


---Event function for the debug flying vertical movement.
-- @param nil  
-- @param float inputValue 
function Player:onInputDebugFlyUpDown(_, inputValue)
    if not self.walkingIsDisabled then
        local move = inputValue * 0.25 * self.debugFlightModeWalkingSpeed * self.debugFlightModeRunningFactor
        self.inputInformation.moveUp = self.inputInformation.moveUp + move
    end
end


---Event function for enter
-- @param nil  
-- @param float inputValue 
function Player:onInputEnter(_, inputValue)
    if g_time > g_currentMission.lastInteractionTime + 200 then
        if g_currentMission.interactiveVehicleInRange and g_currentMission.accessHandler:canFarmAccess(self.farmId, g_currentMission.interactiveVehicleInRange) then
            g_currentMission.interactiveVehicleInRange:interact()
        elseif self.canRideAnimal then
            self.playerStateMachine:activateState("animalRide")
        end
    end
end


---
function Player:onInputActivateHandtool(_, inputValue)
    if self:hasHandtoolEquipped() then
        self.baseInformation.currentHandtool.activatePressed = inputValue ~= 0
    end
end


---
function Player:getIsRideStateAvailable()
    if not self.playerStateMachine:isActive("animalRide") then
        return self.playerStateMachine:isAvailable("animalRide")
    end

    return false
end


---
function Player:activateRideState()
    if not self.playerStateMachine:isActive("animalRide") then
        self.playerStateMachine:activateState("animalRide")
    end
end
