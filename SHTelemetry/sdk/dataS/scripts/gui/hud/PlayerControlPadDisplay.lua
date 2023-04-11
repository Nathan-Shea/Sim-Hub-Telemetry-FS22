---Vehicle Steering Slider for Mobile Version









local PlayerControlPadDisplay_mt = Class(PlayerControlPadDisplay, HUDDisplayElement)


---Creates a new PlayerControlPadDisplay instance.
-- @param string hudAtlasPath Path to the HUD texture atlas.
function PlayerControlPadDisplay.new(hud, hudAtlasPath)
    local backgroundOverlay = PlayerControlPadDisplay.createBackground()
    local self = PlayerControlPadDisplay:superClass().new(backgroundOverlay, nil, PlayerControlPadDisplay_mt)

    self.hud = hud
    self.uiScale = 1.0
    self.hudAtlasPath = hudAtlasPath

    self.player = nil

    self.joystickPosX = 0.5
    self.joystickPosY = 0.5

    self.lastInputHelpMode = GS_INPUT_HELP_MODE_KEYBOARD

    self:createComponents()

    return self
end


---Set the reference to the current player.
function PlayerControlPadDisplay:setPlayer(player)
    self.player = player

    local state = self.player ~= nil and self.lastInputHelpMode ~= GS_INPUT_HELP_MODE_GAMEPAD
    if state ~= self.animationState then
        self:setVisible(state, true)
        self.joystickXHudElement:setTouchIsActive(state)
        self.joystickYHudElement:setTouchIsActive(state)
    end
end


---
function PlayerControlPadDisplay:createComponents()
    local baseX, baseY = self:getPosition()

    --background
    local bgSizeX, bgSizeY = getNormalizedScreenValues(unpack(PlayerControlPadDisplay.SIZE.BACKGROUND))
    local backgroundOverlay = Overlay.new(self.hudAtlasPath, baseX, baseY, bgSizeX, bgSizeY)
    backgroundOverlay:setUVs(GuiUtils.getUVs(PlayerControlPadDisplay.UV.BACKGROUND))
    self.backgroundHudElement = HUDElement.new(backgroundOverlay)

    self:addChild(self.backgroundHudElement)

    -- joystick
    local joySizeX, joySizeY = getNormalizedScreenValues(unpack(PlayerControlPadDisplay.SIZE.JOYSTICK))
    local joystickOverlay = Overlay.new(self.hudAtlasPath, baseX + joySizeX / 2, baseY + joySizeY / 2, joySizeX, joySizeY)
    joystickOverlay:setUVs(GuiUtils.getUVs(PlayerControlPadDisplay.UV.JOYSTICK))

    self.joystickXHudElement = HUDSliderElement.new(joystickOverlay, backgroundOverlay, 1, 1, 2.5, 1, - joySizeX / 2, bgSizeX / 2 - joySizeX / 2, bgSizeX - joySizeX / 2)
    self.joystickXHudElement:setCallback(self.onSliderPositionChangedX, self)

    self.joystickYHudElement = HUDSliderElement.new(joystickOverlay, backgroundOverlay, 1, 1, 2.5, 2, - joySizeY / 2, bgSizeY / 2 - joySizeY / 2, bgSizeY - joySizeY / 2)
    self.joystickYHudElement:setCallback(self.onSliderPositionChangedY, self)

    self.joystickXHudElement.radius = bgSizeX / 2
    self.joystickYHudElement.radius = bgSizeY / 2

    self:addChild(self.joystickXHudElement)
    self:addChild(self.joystickYHudElement)
    self.joystickXHudElement:setAxisPosition(self.joystickXHudElement.centerTrans)
    self.joystickYHudElement:setAxisPosition(self.joystickYHudElement.centerTrans)
end


---Set this element's visibility with optional animation.
-- @param bool isVisible True is visible, false is not.
-- @param bool animate If true, the element will play an animation before applying the visibility change.
function PlayerControlPadDisplay:setVisible(isVisible, animate)
    if not isVisible or g_inputBinding:getInputHelpMode() ~= GS_INPUT_HELP_MODE_GAMEPAD then
        PlayerControlPadDisplay:superClass().setVisible(self, isVisible, animate)
    end
end


---
function PlayerControlPadDisplay:onSliderPositionChangedX(position)
    self.joystickPosX = position * 2 - 1

    local posX, _ = self:updateJoystickPosition()
    if posX ~= nil then
        return posX
    end
end


---
function PlayerControlPadDisplay:onSliderPositionChangedY(position)
    self.joystickPosY = position * 2 - 1

    local _, posY = self:updateJoystickPosition()
    if posY ~= nil then
        return posY
    end
end


---
function PlayerControlPadDisplay:updateJoystickPosition()
    local distance = math.sqrt(self.joystickPosX ^ 2 + self.joystickPosY ^ 2)
    if distance > 1 then
        self.joystickPosX = self.joystickPosX / distance
        local posX = self.joystickXHudElement.minTrans + (self.joystickXHudElement.maxTrans - self.joystickXHudElement.minTrans) * (self.joystickPosX / 2 + 0.5)
        self.joystickXHudElement:setAxisPosition(posX, true)

        self.joystickPosY = self.joystickPosY / distance
        local posY = self.joystickYHudElement.minTrans + (self.joystickYHudElement.maxTrans - self.joystickYHudElement.minTrans) * (self.joystickPosY / 2 + 0.5)
        self.joystickYHudElement:setAxisPosition(posY, true)

        return posX, posY
    end
end


---
function PlayerControlPadDisplay:onInputHelpModeChange(inputHelpMode)
    self.lastInputHelpMode = inputHelpMode

    local state = self.player ~= nil and inputHelpMode ~= GS_INPUT_HELP_MODE_GAMEPAD
    if state ~= self.animationState then
        self:setVisible(state, true)
    end
end







---Update the fill levels state.
function PlayerControlPadDisplay:update(dt)
    PlayerControlPadDisplay:superClass().update(self, dt)

    if self.player ~= nil then
        if self.joystickXHudElement ~= nil and self.joystickYHudElement ~= nil then
            self.joystickXHudElement:update(dt)
            self.joystickYHudElement:update(dt)
        end

        self.player:onInputMoveSide(nil, self.joystickPosX, nil, nil, false)
        self.player:onInputMoveForward(nil, -self.joystickPosY, nil, nil, false)

        -- debug enable mouse
        if not g_gui:getIsGuiVisible() then
            local show = Utils.getNoNil(Input.isKeyPressed(Input.KEY_lctrl), false)
            g_inputBinding:setShowMouseCursor(show, false)
        end
    end
end


---
function PlayerControlPadDisplay:onAnimateVisibilityFinished(isVisible)
    PlayerControlPadDisplay:superClass().onAnimateVisibilityFinished(self, isVisible)

    if isVisible then
        self.joystickXHudElement:resetSlider()
        self.joystickYHudElement:resetSlider()
    end
end






---Set this element's scale.
function PlayerControlPadDisplay:setScale(uiScale)
    PlayerControlPadDisplay:superClass().setScale(self, uiScale, uiScale)

    local currentVisibility = self:getVisible()
    self:setVisible(true, false)

    self.uiScale = uiScale
    local posX, posY = PlayerControlPadDisplay.getBackgroundPosition(uiScale, self:getWidth())
    self:setPosition(posX, posY)

    self:storeOriginalPosition()
    self:setVisible(currentVisibility, false)
end


---Get the position of the background element, which provides this element's absolute position.
-- @param scale Current UI scale
-- @param float width Scaled background width in pixels
-- @return float X position in screen space
-- @return float Y position in screen space
function PlayerControlPadDisplay.getBackgroundPosition(scale, width)
    local offX, offY = getNormalizedScreenValues(unpack(PlayerControlPadDisplay.POSITION.BACKGROUND))
    return g_safeFrameOffsetX + offX * scale, g_safeFrameOffsetY - offY * scale
end






---Create an empty background overlay as a base frame for this element.
function PlayerControlPadDisplay.createBackground()
    local width, height = getNormalizedScreenValues(unpack(PlayerControlPadDisplay.SIZE.BACKGROUND))
    local posX, posY = PlayerControlPadDisplay.getBackgroundPosition(1, width)

    return Overlay.new(nil, posX, posY, width, height) -- empty overlay, only used as a positioning frame
end
