---Top-down camera used for UI.
--Provides a birds-eye view for players when they need to interact with the world from the UI (e.g. placing objects,
--modifying terrain).









local GuiTopDownCamera_mt = Class(GuiTopDownCamera)




































































































---Create scene graph camera nodes.
-- @return int Camera node ID (view point, child of camera base node)
-- @return int Camera base node ID (view target, parent of camera node)
function GuiTopDownCamera:createCameraNodes()
    local camera = createCamera("TopDownCamera", math.rad(60), 1, 4000) -- camera view point node
    local cameraBaseNode = createTransformGroup("topDownCameraBaseNode")-- camera base node, look-at target

    link(cameraBaseNode, camera)
    setRotation(camera, 0, math.rad(180) , 0)
    setTranslation(camera, 0, 0, -5)
    setRotation(cameraBaseNode, 0, 0 , 0)
    setTranslation(cameraBaseNode, 0, 110, 0)
    setFastShadowUpdate(camera, true)

    return camera, cameraBaseNode
end


---
function GuiTopDownCamera:delete()
    if self.isActive then
        self:deactivate()
    end

    delete(self.cameraBaseNode) -- base node holds the camera as a child, this call deletes both
    self.camera, self.cameraBaseNode = nil, nil
    self:reset()
end


---
function GuiTopDownCamera:reset()
    self.cameraTransformInitialized = false
    self.controlledPlayer = nil
    self.controlledVehicle = nil
    self.terrainRootNode = nil
    self.waterLevelHeight = 0
    self.terrainSize = 0
    self.previousCamera = nil
    self.isCatchingCursor = false
end


---Set the current game's terrain's root node reference for terrain state queries and raycasts.
function GuiTopDownCamera:setTerrainRootNode(terrainRootNode)
    self.terrainRootNode = terrainRootNode
    self.terrainSize = getTerrainSize(self.terrainRootNode)
end


---Set the water level height as defined in the current map's environment.
function GuiTopDownCamera:setWaterLevelHeight(waterLevelHeight)
    self.waterLevelHeight = waterLevelHeight
end


---Set the reference to the currently controlled Player instance.
Clears the controlled vehicle reference if any has been set.
function GuiTopDownCamera:setControlledPlayer(player)
    self.controlledPlayer = player
    self.controlledVehicle = nil
end


---Set the reference to the currently controlled Vehicle instance.
Clears the controlled player reference if any has been set.
function GuiTopDownCamera:setControlledVehicle(vehicle)
    if vehicle ~= nil then
        self.controlledVehicle = vehicle
        self.controlledPlayer = nil
    end
end


---Activate the camera and change the game's viewpoint to it.
function GuiTopDownCamera:activate()
    self.inputManager:setShowMouseCursor(true)
    self:onInputModeChanged({self.inputManager:getLastInputMode()})

    self:updatePosition()

    self.previousCamera = getCamera()
    setCamera(self.camera)

    -- Leave the player so it is not visible and use player position as initial focus.
    if self.controlledPlayer ~= nil then
        local x, y, z = getTranslation(self.controlledPlayer.rootNode)
        self.lastPlayerPos[1], self.lastPlayerPos[2], self.lastPlayerPos[3] = x, y, z
        self.lastPlayerTerrainHeight = getTerrainHeightAtWorldPos(self.terrainRootNode, x, 0, z)

        -- self.controlledPlayer:onLeave()
        self.controlledPlayer:setVisibility(true)
    end

    self:resetToPlayer()

    self:registerActionEvents()
    self.messageCenter:subscribe(MessageType.INPUT_MODE_CHANGED, self.onInputModeChanged, self)

    self.isActive = true
end


---Disable this camera.
function GuiTopDownCamera:deactivate()
    self.isActive = false

    self.messageCenter:unsubscribeAll(self)
    self:removeActionEvents()

    -- local showCursor = self.controlledPlayer == nil and self.controlledVehicle == nil
    self.inputManager:setShowMouseCursor(false)

    -- restore player position and previous camera
    if self.controlledPlayer ~= nil then
        local x,y,z = unpack(self.lastPlayerPos)
        local currentPlayerTerrainHeight = getTerrainHeightAtWorldPos(self.terrainRootNode, x,0,z)
        local deltaTerrainHeight = currentPlayerTerrainHeight - self.lastPlayerTerrainHeight
        if deltaTerrainHeight > 0 then
            y = y + deltaTerrainHeight
        end

        self.controlledPlayer:moveRootNodeToAbsolute(x, y, z)
        -- self.controlledPlayer:onEnter(true)
        self.controlledPlayer:setVisibility(false)
    end

    if self.previousCamera ~= nil then
        setCamera(self.previousCamera)
        self.previousCamera = nil
    end
end


---Check if this camera is active.
function GuiTopDownCamera:getIsActive()
    return self.isActive
end


---Set the camera target position on the map.
-- @param float mapX Map X position
-- @param float mapZ Map Z position
function GuiTopDownCamera:setMapPosition(mapX, mapZ)
    self.cameraX, self.cameraZ = mapX, mapZ
    self.targetCameraX, self.targetCameraZ = mapX, mapZ
    self:updatePosition()
end


---Reset the camera target position to the player's location.
function GuiTopDownCamera:resetToPlayer()
    local playerX, playerZ = 0, 0

    if self.controlledPlayer ~= nil then
        playerX, playerZ = self.lastPlayerPos[1], self.lastPlayerPos[3]
    elseif self.controlledVehicle ~= nil then
        local _
        playerX, _, playerZ = getTranslation(self.controlledVehicle.rootNode)
    end

    self:setMapPosition(playerX, playerZ)
end


---Determine the current camera position and orientation.
-- @return Camera X world space position
-- @return 0  
-- @return Camera Z world space position
-- @return Camera Y rotation in radians
function GuiTopDownCamera:determineMapPosition()
    return self.cameraX, 0, self.cameraZ, self.cameraRotY - math.rad(180), 0
end


---Get a picking ray for the current camera orientation and cursor position.
function GuiTopDownCamera:getPickRay()
    if self.isCatchingCursor then
        return nil
    end

    return RaycastUtil.getCameraPickingRay(self.mousePosX, self.mousePosY, self.camera)
end


---Update the camera position and orientation based on terrain and zoom state.
function GuiTopDownCamera:updatePosition()
    local samplingGridStep = 2 -- terrain sampling step distance in meters
    local cameraTargetHeight = self.waterLevelHeight

    -- sample the terrain height around the camera
    for x = -samplingGridStep, samplingGridStep, samplingGridStep do
        for z = -samplingGridStep, samplingGridStep, samplingGridStep do
            local sampleTerrainHeight = getTerrainHeightAtWorldPos(self.terrainRootNode, self.cameraX + x, 0, self.cameraZ + z)
            cameraTargetHeight = math.max(cameraTargetHeight, sampleTerrainHeight)
        end
    end

    cameraTargetHeight = cameraTargetHeight + GuiTopDownCamera.CAMERA_TERRAIN_OFFSET

    -- Tilt factor decides position between min and max. Min and max depend on zoom level
    local rotMin = math.rad(GuiTopDownCamera.ROTATION_MIN_X_NEAR + (GuiTopDownCamera.ROTATION_MIN_X_FAR - GuiTopDownCamera.ROTATION_MIN_X_NEAR) * self.zoomFactor)
    local rotMax = math.rad(GuiTopDownCamera.ROTATION_MAX_X_NEAR + (GuiTopDownCamera.ROTATION_MAX_X_FAR - GuiTopDownCamera.ROTATION_MAX_X_NEAR) * self.zoomFactor)
    local rotationX = rotMin + (rotMax - rotMin) * self.tiltFactor

    -- Distance to target depends fully on zoom level
    local cameraZ = GuiTopDownCamera.DISTANCE_MIN_Z + self.zoomFactor * GuiTopDownCamera.DISTANCE_RANGE_Z

    setTranslation(self.camera, 0, 0, cameraZ)
    setRotation(self.cameraBaseNode, rotationX, self.cameraRotY, 0)
    setTranslation(self.cameraBaseNode, self.cameraX, cameraTargetHeight, self.cameraZ)

    -- check if new camera position is close to or even under terrain and lift it if needed
    local cameraX, cameraY
    cameraX, cameraY, cameraZ = getWorldTranslation(self.camera)
    local terrainHeight = self.waterLevelHeight
    for x = -samplingGridStep, samplingGridStep, samplingGridStep do
        for z = -samplingGridStep, samplingGridStep, samplingGridStep do
            local y = getTerrainHeightAtWorldPos(self.terrainRootNode, cameraX + x, 0, cameraZ + z)

            local hit, _, hitY, _ = RaycastUtil.raycastClosest(cameraX + x, y + 100, cameraZ + z, 0, -1, 0, 100, CollisionMask.ALL - CollisionMask.TRIGGERS)
            if hit then
                y = hitY
            end

            terrainHeight = math.max(terrainHeight, y)
        end
    end

    -- TODO instead we should tilt the camera up to clear the terrain...
    if cameraY < terrainHeight + GuiTopDownCamera.GROUND_DISTANCE_MIN_Y then
        cameraTargetHeight = cameraTargetHeight + (terrainHeight - cameraY + GuiTopDownCamera.GROUND_DISTANCE_MIN_Y)
        setTranslation(self.cameraBaseNode, self.cameraX, cameraTargetHeight, self.cameraZ)
    end
end


---Apply a movement to the camera (and view).
function GuiTopDownCamera:applyMovement(dt)
    -- Smooth updates of camera
    -- This lerps towards the target. Due to a constant alpha it will automatically
    -- change faster if target is further away.

    local xChange = (self.targetCameraX - self.cameraX) / dt * 5
    if xChange < 0.0001 and xChange > -0.0001 then
        self.cameraX = self.targetCameraX
    else
        self.cameraX = self.cameraX + xChange
    end

    local zChange = (self.targetCameraZ - self.cameraZ) / dt * 5
    if zChange < 0.0001 and zChange > -0.0001 then
        self.cameraZ = self.targetCameraZ
    else
        self.cameraZ = self.cameraZ + zChange
    end

    local zoomChange = (self.targetZoomFactor - self.zoomFactor) / dt * 2
    if zoomChange < 0.0001 and zoomChange > -0.0001 then
        self.zoomFactor = self.targetZoomFactor
    else
        self.zoomFactor = MathUtil.clamp(self.zoomFactor + zoomChange, 0, 1)
    end


    local tiltChange = (self.targetTiltFactor - self.tiltFactor) / dt * 5
    if tiltChange < 0.0001 and tiltChange > -0.0001 then
        self.tiltFactor = self.targetTiltFactor
    else
        self.tiltFactor = MathUtil.clamp(self.tiltFactor + tiltChange, 0, 1)
    end

    local rotateChange = (self.targetRotation - self.cameraRotY) / dt * 5
    if rotateChange < 0.0001 and rotateChange > -0.0001 then
        self.cameraRotY = self.targetRotation
    else
        self.cameraRotY = self.cameraRotY + rotateChange
    end
end


---Enable or disable the mouse edge scrolling.
function GuiTopDownCamera:setMouseEdgeScrollingActive(isActive)
    self.isMouseEdgeScrollingActive = isActive
end


---Get camera movement for mouse edge scrolling.
-- @return X direction movement [-1, 1]
-- @return Z direction movement [-1, 1]
function GuiTopDownCamera:getMouseEdgeScrollingMovement()
    local moveMarginStartX = 0.015 + 0.005
    local moveMarginEndX = 0.015
    local moveMarginStartY = 0.015 + 0.005
    local moveMarginEndY = 0.015

    local moveX, moveZ = 0, 0

    if self.mousePosX >= 1 - moveMarginStartX then
        moveX = math.min((moveMarginStartX - (1 - self.mousePosX)) / (moveMarginStartX - moveMarginEndX), 1)
    elseif self.mousePosX <= moveMarginStartX then
        moveX = -math.min((moveMarginStartX - self.mousePosX) / (moveMarginStartX - moveMarginEndX), 1)
    end

    if self.mousePosY >= 1 - moveMarginStartY then
        moveZ = math.min((moveMarginStartY - (1 - self.mousePosY)) / (moveMarginStartY - moveMarginEndY), 1)
    elseif self.mousePosY <= moveMarginStartY then
        moveZ = -math.min((moveMarginStartY - self.mousePosY) / (moveMarginStartY - moveMarginEndY), 1)
    end

    return moveX, moveZ
end






---Update camera state.
function GuiTopDownCamera:update(dt)
    if self.isActive then
        if self.isMouseMode or not self.movementDisabledForGamepad then
            self:updateMovement(dt)
            self:resetInputState()
        end
    end
end


---Update camera position and orientation based on player input.
-- @param dt Delta time in milliseconds
-- @param movementMultiplier Speed factor for movement
function GuiTopDownCamera:updateMovement(dt)
    self.targetZoomFactor = MathUtil.clamp(self.targetZoomFactor - self.inputZoom * 0.2, 0, 1)
    self.targetRotation = self.targetRotation + dt * self.inputRotate * GuiTopDownCamera.ROTATION_SPEED
    self.targetTiltFactor = MathUtil.clamp(self.targetTiltFactor + self.inputTilt * dt * GuiTopDownCamera.ROTATION_SPEED, 0, 1)

    local moveX = self.inputMoveSide * dt
    local moveZ = -self.inputMoveForward * dt -- inverted to make it consistent

    -- When touching the edge with mouse cursor, move
    if moveX == 0 and moveZ == 0 and self.isMouseEdgeScrollingActive then
        moveX, moveZ = self:getMouseEdgeScrollingMovement()
    end

    -- make movement faster when zoomed out
    local zoomMovementSpeedFactor = GuiTopDownCamera.MOVE_SPEED_FACTOR_NEAR  + self.zoomFactor * (GuiTopDownCamera.MOVE_SPEED_FACTOR_FAR - GuiTopDownCamera.MOVE_SPEED_FACTOR_NEAR)
    moveX = moveX * zoomMovementSpeedFactor
    moveZ = moveZ * zoomMovementSpeedFactor

    -- note: we use the actual current camera rotation to define the direction, instead of the target location
    local dirX = math.sin(self.cameraRotY) * moveZ + math.cos(self.cameraRotY) * -moveX
    local dirZ = math.cos(self.cameraRotY) * moveZ - math.sin(self.cameraRotY) * -moveX

    local limit = self.terrainSize * 0.5 - GuiTopDownCamera.TERRAIN_BORDER
    local moveFactor = dt * GuiTopDownCamera.MOVE_SPEED
    self.targetCameraX = MathUtil.clamp(self.targetCameraX + dirX * moveFactor, -limit, limit)
    self.targetCameraZ = MathUtil.clamp(self.targetCameraZ + dirZ * moveFactor, -limit, limit)

    self:applyMovement(dt)
    self:updatePosition()
end









---Handle mouse moves that are not caught by actions.
function GuiTopDownCamera:mouseEvent(posX, posY, isDown, isUp, button)
    if self.lastActionFrame >= g_time or self.cursorLocked then
        return
    end

    -- Mouse move only happens when other actions did not
    if self.isCatchingCursor then
        self.isCatchingCursor = false
        self.inputManager:setShowMouseCursor(true)

        -- force warp to get rid of invisible position
        wrapMousePosition(0.5, 0.5)

        self.mousePosX = 0.5
        self.mousePosY = 0.5
    else
        if self.isMouseMode then
            self.mousePosX = posX
            self.mousePosY = posY
        end
    end
end


---Reset event input state.
function GuiTopDownCamera:resetInputState()
    self.inputZoom = 0
    self.inputMoveSide = 0
    self.inputMoveForward = 0
    self.inputTilt = 0
    self.inputRotate = 0
end


---Register required action events for the camera.
function GuiTopDownCamera:registerActionEvents()
    local _, eventId = self.inputManager:registerActionEvent(InputAction.AXIS_MOVE_SIDE_PLAYER, self, self.onMoveSide, false, false, true, true)
    self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
    self.inputManager:setActionEventTextVisibility(eventId, false)
    self.eventMoveSide = eventId

    _, eventId = self.inputManager:registerActionEvent(InputAction.AXIS_MOVE_FORWARD_PLAYER, self, self.onMoveForward, false, false, true, true)
    self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
    self.inputManager:setActionEventTextVisibility(eventId, false)
    self.eventMoveForward = eventId

    _, eventId = self.inputManager:registerActionEvent(InputAction.AXIS_CONSTRUCTION_CAMERA_ZOOM, self, self.onZoom, false, false, true, true)
    self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_LOW)
    _, eventId = self.inputManager:registerActionEvent(InputAction.AXIS_CONSTRUCTION_CAMERA_ROTATE, self, self.onRotate, false, false, true, true)
    self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_LOW)
    _, eventId = self.inputManager:registerActionEvent(InputAction.AXIS_CONSTRUCTION_CAMERA_TILT, self, self.onTilt, false, false, true, true)
    self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_LOW)
end


---Remove action events registered on this screen.
function GuiTopDownCamera:removeActionEvents()
    self.inputManager:removeActionEventsByTarget(self)
end






---
function GuiTopDownCamera:onZoom(_, inputValue, _, isAnalog, isMouse)
    if isMouse and self.mouseDisabled then
        return
    end

    local change = 0.2 * inputValue
    if isAnalog then
        change = change * 0.5
    elseif isMouse then -- UI mouse wheel zoom
        change = change * InputBinding.MOUSE_WHEEL_INPUT_FACTOR
    end

    self.inputZoom = change
end


---
function GuiTopDownCamera:onMoveSide(_, inputValue)
    self.inputMoveSide = inputValue * GuiTopDownCamera.INPUT_MOVE_FACTOR / g_currentDt
end


---
function GuiTopDownCamera:onMoveForward(_, inputValue)
    self.inputMoveForward = inputValue * GuiTopDownCamera.INPUT_MOVE_FACTOR / g_currentDt
end


---
function GuiTopDownCamera:onRotate(_, inputValue, _, isAnalog, isMouse)
    if isMouse and self.mouseDisabled then
        return
    end

    -- Do not show cursor and clip to center of screen so that cursor does not
    -- overlap with edge scrolling
    if isMouse and inputValue ~= 0 then
        self.lastActionFrame = g_time

        if not self.isCatchingCursor then
            self.inputManager:setShowMouseCursor(false)
            self.isCatchingCursor = true
        end
    end

    -- Analog has very small steps
    if isMouse and isAnalog then
        inputValue = inputValue * 3
    end

    self.inputRotate = -inputValue * 3 / g_currentDt * 16
end


---
function GuiTopDownCamera:onTilt(_, inputValue, _, isAnalog, isMouse)
    if isMouse and self.mouseDisabled then
        return
    end

    -- Do not show cursor and clip to center of screen so that cursor does not
    -- overlap with edge scrolling
    if isMouse and inputValue ~= 0 then
        self.lastActionFrame = g_time

        if not self.isCatchingCursor then
            self.inputManager:setShowMouseCursor(false)
            self.isCatchingCursor = true
        end
    end

    -- Analog has very small steps
    if isMouse and isAnalog then
        inputValue = inputValue * 3
    end

    self.inputTilt = inputValue * 3
end


---Called when the mouse input mode changes.
function GuiTopDownCamera:onInputModeChanged(inputMode)
    self.isMouseMode = inputMode[1] == GS_INPUT_HELP_MODE_KEYBOARD

    -- Reset to center of screen
    if not self.isMouseMode then
        self.mousePosX = 0.5
        self.mousePosY = 0.5
    end
end
