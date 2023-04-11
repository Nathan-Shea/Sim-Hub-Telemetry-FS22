---Vehicle Speed Slider for Mobile Version









local SpeedSliderDisplay_mt = Class(SpeedSliderDisplay, HUDDisplayElement)





















---Creates a new SpeedSliderDisplay instance.
-- @param string hudAtlasPath Path to the HUD texture atlas.
function SpeedSliderDisplay.new(hud, hudAtlasPath)
    local backgroundOverlay = SpeedSliderDisplay.createBackground()
    local self = SpeedSliderDisplay:superClass().new(backgroundOverlay, nil, SpeedSliderDisplay_mt)

    self.hud = hud
    self.uiScale = 1.0
    self.hudAtlasPath = hudAtlasPath

    self.vehicle = nil -- currently controlled vehicle
    self.player = nil
    self.isRideable = false

    self.sliderPosition = 0
    self.restPosition = 0.25

    self.hudElements = {}

    self.lastInputHelpMode = GS_INPUT_HELP_MODE_KEYBOARD

    self.sliderState = nil

    self:createComponents()

    g_messageCenter:subscribe(MessageType.GUI_DIALOG_OPENED, self.onDialogOpened, self)

    return self
end


---
function SpeedSliderDisplay:delete()
    g_messageCenter:unsubscribeAll(self)
    SpeedSliderDisplay:superClass().delete(self)
end



---
function SpeedSliderDisplay:createComponents()
    local baseX, baseY = self:getPosition()

    for _, element in ipairs(self.hudElements) do
        element:delete()
    end
    self.hudElements = {}

    --background
    local bgSizeX, bgSizeY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.BACKGROUND))
    local backgroundOverlay = Overlay.new(self.hudAtlasPath, baseX, baseY, bgSizeX, bgSizeY)
    backgroundOverlay:setUVs(GuiUtils.getUVs(SpeedSliderDisplay.UV.BACKGROUND))
    self.backgroundHudElement = HUDElement.new(backgroundOverlay)
    table.insert(self.hudElements, self.backgroundHudElement)

    self.snapSteps = {}
    self.snapSteps[1] = self:createHUDElement(SpeedSliderDisplay.POSITION.SNAP1, SpeedSliderDisplay.SIZE.SNAP, SpeedSliderDisplay.UV.SNAP)
    self.snapSteps[2] = self:createHUDElement(SpeedSliderDisplay.POSITION.SNAP2, SpeedSliderDisplay.SIZE.SNAP, SpeedSliderDisplay.UV.SNAP)
    self.snapSteps[3] = self:createHUDElement(SpeedSliderDisplay.POSITION.SNAP3, SpeedSliderDisplay.SIZE.SNAP, SpeedSliderDisplay.UV.SNAP)

    for i=1, 3 do
        table.insert(self.hudElements, self.snapSteps[i])
        self.snapSteps[i]:setVisible(false)
    end

    --positive bar
    self.positiveBarHudElement = self:createBar(SpeedSliderDisplay.POSITION.POSITIVE_BAR, SpeedSliderDisplay.SIZE.POSITIVE_BAR, SpeedSliderDisplay.COLOR.POSITIVE_BAR)
    table.insert(self.hudElements, self.positiveBarHudElement)

    --positive bar
    self.negativeBarHudElement = self:createBar(SpeedSliderDisplay.POSITION.NEGATIVE_BAR, SpeedSliderDisplay.SIZE.NEGATIVE_BAR, SpeedSliderDisplay.COLOR.NEGATIVE_BAR)
    table.insert(self.hudElements, self.negativeBarHudElement)
    self.negativeBarPosX, self.negativeBarPosY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.NEGATIVE_BAR))
    local _, negativeBarSizeY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.NEGATIVE_BAR))
    self.negativeBarSizeY = negativeBarSizeY

    --gamepad background
    local gpbgPosX, gpbgPosY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.GAMEPAD_BACKGROUND))
    local gpbgSizeX, gpbgSizeY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.GAMEPAD_BACKGROUND))
    local gamepadBackgroundOverlay = Overlay.new(self.hudAtlasPath, baseX + gpbgPosX, baseY + gpbgPosY, gpbgSizeX, gpbgSizeY)
    gamepadBackgroundOverlay:setUVs(GuiUtils.getUVs(SpeedSliderDisplay.UV.GAMEPAD_BACKGROUND))
    self.gamepadBackgroundHudElement = HUDElement.new(gamepadBackgroundOverlay)
    table.insert(self.hudElements, self.gamepadBackgroundHudElement)

    -- lower border of gamepad background
    local gpbgbPosX, gpbgbPosY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.GAMEPAD_BACKGROUND))
    local gpbgbSizeX, gpbgbSizeY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.GAMEPAD_BACKGROUND_BORDER))
    local gamepadBackgroundBorderOverlay = Overlay.new(self.hudAtlasPath, baseX + gpbgbPosX, baseY + gpbgbPosY, gpbgbSizeX, gpbgbSizeY)
    gamepadBackgroundBorderOverlay:setUVs(GuiUtils.getUVs(SpeedSliderDisplay.UV.GAMEPAD_BACKGROUND_BORDER))
    self.gamepadBackgroundHudElement:addChild(HUDElement.new(gamepadBackgroundBorderOverlay))

    -- player jump background
    local pljbgPosX, pljbgPosY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.PLAYER_JUMP_BACKGROUND))
    local pljbgSizeX, pljbgSizeY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.PLAYER_JUMP_BACKGROUND))
    self.playerJumpBackgroundHudElement = HUDFrameElement.new(self.hudAtlasPath, baseX + pljbgPosX, baseY + pljbgPosY, pljbgSizeX, pljbgSizeY, nil, false, 2)
    self.playerJumpBackgroundHudElement:setColor(unpack(SpeedSliderDisplay.COLOR.PLAYER_JUMP_BACKGROUND))
    self.playerJumpBackgroundHudElement:setFrameColor(unpack(SpeedSliderDisplay.COLOR.PLAYER_JUMP_BACKGROUND_FRAME))
    table.insert(self.hudElements, self.playerJumpBackgroundHudElement)

    -- text
    self.textPosX, self.textPosY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.SPEED_TEXT))
    local _, textSize = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.SPEED_TEXT))
    self.textSize = textSize

    -- slider
    local slOffX, slOffY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.SLIDER_OFFSET))
    local slSizeX, slSizeY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.SLIDER_SIZE))
    local sliderOverlay = Overlay.new(self.hudAtlasPath, baseX+slOffX, baseY+slOffY, slSizeX, slSizeY)
    sliderOverlay:setUVs(GuiUtils.getUVs(SpeedSliderDisplay.UV.SLIDER))

    self.sliderPosX = slOffX
    self.sliderPosY = slOffY
    self.backgroundSizeY = bgSizeY - slOffY * 2

    local _, slAreaY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.SLIDER_AREA))
    self.sliderAreaY = slAreaY

    local _, slCenterY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.SLIDER_CENTER))
    self.restPosition = slCenterY / slAreaY

    local sliderMin = self.sliderPosY
    local sliderMax = sliderMin + self.sliderAreaY
    local sliderCenter = sliderMin + self.sliderAreaY * self.restPosition
    self.sliderHudElement = HUDSliderElement.new(sliderOverlay, backgroundOverlay, 2.5, 0.4, 4, 2, sliderMin, sliderCenter, sliderMax, sliderMax)
    self.sliderHudElement:setCallback(self.onSliderPositionChanged, self)
    table.insert(self.hudElements, self.sliderHudElement)

    for _, element in ipairs(self.hudElements) do
        self:addChild(element)
    end

    self.sliderHudElement:setAxisPosition(sliderCenter)
end


---Set silder state
function SpeedSliderDisplay:setSliderState(state)
    if self.sliderState ~= state then
        if state then
            self:showSlider()
        else
            self:hideSlider()
        end
    end
end


---Hide slider and only show speed display
function SpeedSliderDisplay:hideSlider()
    local _, yOffset = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.GAMEPAD_BACKGROUND))
    local startX, startY = self:getPosition()

    local sequence = TweenSequence.new(self)
    sequence:insertTween(MultiValueTween.new(self.setPosition, {startX, startY}, {self.origX, self.origY - yOffset}, HUDDisplayElement.MOVE_ANIMATION_DURATION), 0)
    sequence:start()

    self.animation = sequence

    self.sliderState = false
    self.sliderHudElement:setTouchIsActive(false)

    self:updateElementsVisibility()
end


---Show slider and speed display
function SpeedSliderDisplay:showSlider()
    local startX, startY = self:getPosition()

    local sequence = TweenSequence.new(self)
    sequence:insertTween(MultiValueTween.new(self.setPosition, {startX, startY}, {self.origX, self.origY}, HUDDisplayElement.MOVE_ANIMATION_DURATION), 0)
    sequence:addCallback(self.onSliderVisibilityChangeFinished, true)
    sequence:start()

    self.animation = sequence

    self.sliderState = true

    self.sliderHudElement:resetSlider()
    self.sliderHudElement:setTouchIsActive(true)
end


---Hide slider and only show speed display
function SpeedSliderDisplay:updateElementsVisibility()
    for _, element in ipairs(self.hudElements) do
        if not self.sliderState then
            if self.player ~= nil then
                element:setVisible(element == self.playerJumpBackgroundHudElement)
            else
                element:setVisible(element == self.gamepadBackgroundHudElement)
            end
        else
            element:setVisible(element ~= self.playerJumpBackgroundHudElement and element ~= self.gamepadBackgroundHudElement)
        end
    end
end



---Called when the sliders visibility changed
function SpeedSliderDisplay:onSliderVisibilityChangeFinished(visibility)
    if visibility then
        self:updateElementsVisibility()

        for i=1, 3 do
            self.snapSteps[i]:setVisible(self.isRideable)
        end
    end
end


---Set the currently controlled vehicle which provides display data.
-- @param table vehicle Currently controlled vehicle
function SpeedSliderDisplay:setVehicle(vehicle)
    self.vehicle = vehicle

    if vehicle ~= nil then
        self.isRideable = SpecializationUtil.hasSpecialization(Rideable, vehicle.specializations)

        if self.player ~= nil then
            self:setPlayer(nil)
        end

        self:removeJumpButton()
        self.sliderHudElement:resetSlider()
        self.sliderHudElement:clearSnapPositions()
        if self.isRideable then
            for i=1, #SpeedSliderDisplay.RIDEABLE_SNAP_POSITIONS do
                self.sliderHudElement:addSnapPosition(self.sliderPosY + self.sliderAreaY * SpeedSliderDisplay.RIDEABLE_SNAP_POSITIONS[i])
            end

            self:addJumpButton()
        end

        for i=1, 3 do
            self.snapSteps[i]:setVisible(self.isRideable)
        end
    end

    self:updateElementsVisibility()
end


---Set the reference to the current player.
function SpeedSliderDisplay:setPlayer(player)
    self.player = player

    if player ~= nil then
        if self.vehicle ~= nil then
            self:setVehicle(nil)
        end

        self:removeJumpButton()
        self:addJumpButton()
        self:setJumpButtonActive(true)

        self.sliderHudElement:resetSlider()
        self.sliderHudElement:clearSnapPositions()
        for i=1, #SpeedSliderDisplay.PLAYER_SNAP_POSITIONS do
            self.sliderHudElement:addSnapPosition(self.sliderPosY + self.sliderAreaY * SpeedSliderDisplay.PLAYER_SNAP_POSITIONS[i])
        end
    end

    self:updateVisibilityState()
    self:updateElementsVisibility()
end




















































































---
function SpeedSliderDisplay:createHUDElement(position, size, uvs, color)
    local baseX, baseY = self:getPosition()
    local posX, posY = getNormalizedScreenValues(unpack(position))
    local sizeX, sizeY = getNormalizedScreenValues(unpack(size))
    local overlay = Overlay.new(self.hudAtlasPath, baseX + posX, baseY + posY, sizeX, sizeY)
    overlay:setUVs(GuiUtils.getUVs(uvs))
    if color ~= nil then
        overlay:setColor(unpack(color))
    end

    return HUDElement.new(overlay)
end


---
function SpeedSliderDisplay:createBar(position, size, color)
    local baseX, baseY = self:getPosition()

    local posX, posY = getNormalizedScreenValues(unpack(position))
    local sizeX, sizeY = getNormalizedScreenValues(unpack(size))
    local barOverlay = Overlay.new(self.hudAtlasPath, baseX + posX, baseY + posY, sizeX, sizeY)
    barOverlay:setUVs(GuiUtils.getUVs(HUDElement.UV.FILL))
    barOverlay:setColor(unpack(color))

    return HUDElement.new(barOverlay)
end

---
function SpeedSliderDisplay:onSliderPositionChanged(position)
    self.sliderPosition = MathUtil.clamp(position, 0, 1)
    local selfX, selfY = self:getPosition()

    local acc, brake = self:getAccelerateAndBrakeValue()

    self.positiveBarHudElement:setScale(1, acc)
    self.positiveBarHudElement:setColor(unpack(self.cruiseControlIsActive and SpeedSliderDisplay.COLOR.CRUISE_CONTROL or SpeedSliderDisplay.COLOR.POSITIVE_BAR))

    self.negativeBarHudElement:setPosition(selfX + self.negativeBarPosX, selfY + self.negativeBarPosY + self.negativeBarSizeY * (1-brake))
    self.negativeBarHudElement:setScale(1, brake)

    if self.vehicle ~= nil then
        if self.isRideable then
            for gait=1, #SpeedSliderDisplay.RIDEABLE_SNAP_POSITIONS do
                if math.abs(position - SpeedSliderDisplay.RIDEABLE_SNAP_POSITIONS[gait]) < 0.01 then
                    self.vehicle:setCurrentGait(gait)

                    self.lastGait = gait
                    self.lastGaitTime = g_time
                    break
                end
            end

            self:setJumpButtonActive(self.vehicle:getIsRideableJumpAllowed(true))
        end
    end
end


---
function SpeedSliderDisplay:getAccelerateAndBrakeValue()
    return MathUtil.clamp((self.sliderPosition - self.restPosition) / (1-self.restPosition), 0, 1), 1 - MathUtil.clamp(self.sliderPosition / self.restPosition, 0, 1)
end


---
function SpeedSliderDisplay:onJumpEventCallback()
    if self.vehicle ~= nil then
        if self.isRideable then
            if self.vehicle:getIsRideableJumpAllowed() then
                self.vehicle:jump()
            end
        end
    end

    if self.player ~= nil then
        self.player:onInputJump(nil, 1)
    end
end






---Update the fill levels state.
function SpeedSliderDisplay:update(dt)
    SpeedSliderDisplay:superClass().update(self, dt)

    if self.sliderHudElement ~= nil then
        self.sliderHudElement:update(dt)
    end

    if self.vehicle ~= nil then
        if self.vehicle.setAccelerationPedalInput ~= nil then
            local acceleration, brake = self:getAccelerateAndBrakeValue()

            local direction = acceleration > 0 and 1 or (brake > 0 and -1 or 0)
            self.vehicle:setTargetSpeedAndDirection(math.abs(acceleration + brake), direction)
        end

        -- reset slider if the gait was changed from rideable due to collisions or user input on pc
        if self.isRideable then
            local currentGait = self.vehicle:getCurrentGait()
            if currentGait ~= self.lastGait then
                if self.lastGaitTime < g_time - 250 then
                    if SpeedSliderDisplay.RIDEABLE_SNAP_POSITIONS[currentGait] ~= nil then
                        self.sliderHudElement:setAxisPosition(self.sliderPosY + self.sliderAreaY * SpeedSliderDisplay.RIDEABLE_SNAP_POSITIONS[currentGait])
                        self.lastGait = currentGait
                    end
                end
            end
        end
    end

    if self.player ~= nil then
        local acceleration, brake = self:getAccelerateAndBrakeValue()
        self.player:onInputMoveForward(nil, -(acceleration - brake))

        if acceleration > 0.75 then
            self.player:onInputRun(nil, 1)
        end
    end

    -- debug enable mouse
    if self.vehicle ~= nil or self.player ~= nil then
        if not g_gui:getIsGuiVisible() then
            local show = Utils.getNoNil(Input.isKeyPressed(Input.KEY_lctrl), false)
            g_inputBinding:setShowMouseCursor(show, false)
        end
    end
end


---
function SpeedSliderDisplay:getIsSliderActive()
    if self.lastInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
        return false
    end

    if self.vehicle ~= nil and self.vehicle:getIsAIActive() then
        return false
    end

    if self.player ~= nil then
        return false
    end

    return true
end


---
function SpeedSliderDisplay:onInputHelpModeChange(inputHelpMode)
    self.lastInputHelpMode = inputHelpMode

    -- reset speed slider if user starts using gamepad
    if inputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
        self.sliderHudElement:setAxisPosition(self.sliderPosY + self.sliderAreaY * self.restPosition)
    end

    self:updateVisibilityState()
end


---
function SpeedSliderDisplay:onAIVehicleStateChanged(state, vehicle)
    if vehicle == self.vehicle then
        self:updateVisibilityState()
    end
end


---
function SpeedSliderDisplay:updateVisibilityState()
    local sliderState = self:getIsSliderActive()
    if sliderState ~= self.sliderState then
        self:setSliderState(sliderState, true)
    end
end


---
function SpeedSliderDisplay:draw()
    SpeedSliderDisplay:superClass().draw(self)

    if self.vehicle ~= nil and not self.isRideable then
        local speed = self.vehicle:getLastSpeed()
        local baseX, baseY = self:getPosition()

        setTextColor(1, 1, 1, 1)
        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(baseX+self.textPosX, baseY+self.textPosY, self.textSize, string.format("%02d", speed))
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
    end
end





---Set this element's scale.
function SpeedSliderDisplay:setScale(uiScale)
    SpeedSliderDisplay:superClass().setScale(self, uiScale, uiScale)

    local currentVisibility = self:getVisible()
    self:setVisible(true, false)

    self.uiScale = uiScale
    local posX, posY = SpeedSliderDisplay.getBackgroundPosition(uiScale, self:getWidth())
    self:setPosition(posX, posY)

    self:storeOriginalPosition()
    self:setVisible(currentVisibility, false)
end


---Get the position of the background element, which provides this element's absolute position.
-- @param scale Current UI scale
-- @param float width Scaled background width in pixels
-- @return float X position in screen space
-- @return float Y position in screen space
function SpeedSliderDisplay.getBackgroundPosition(scale, width)
    local offX, offY = getNormalizedScreenValues(unpack(SpeedSliderDisplay.POSITION.BACKGROUND))
    return 1 - g_safeFrameOffsetX - width - offX * scale, g_safeFrameOffsetY - offY * scale
end






---Create an empty background overlay as a base frame for this element.
function SpeedSliderDisplay.createBackground()
    local width, height = getNormalizedScreenValues(unpack(SpeedSliderDisplay.SIZE.BACKGROUND))
    local posX, posY = SpeedSliderDisplay.getBackgroundPosition(1, width)

    return Overlay.new(nil, posX, posY, width, height) -- empty overlay, only used as a positioning frame
end


---
function SpeedSliderDisplay:onDialogOpened(guiName, overlappingDialog)
    -- only reset silder if it's a direct dialog, not in a menu since the game is paused there anyway
    if not overlappingDialog then
        self.sliderHudElement:resetSlider()
    end
end
