---HUD game pause display element.
--
--Displays a customizable message when the game is paused.









local GamePausedDisplay_mt = Class(GamePausedDisplay, HUDDisplayElement)


---Create a new GamePausedDisplay.
-- @param string hudAtlasPath Path to the HUD atlas texture.
-- @return table GamePausedDisplay instance
function GamePausedDisplay.new(hudAtlasPath)
    local backgroundOverlay = GamePausedDisplay.createBackground(hudAtlasPath)
    local self = GamePausedDisplay:superClass().new(backgroundOverlay, nil, GamePausedDisplay_mt)

    self.pauseText = ""
    self.isMenuVisible = false

    self.syncBackgroundElement = nil

    self.textSize = 0
    self.textOffsetX, self.textOffsetY = 0, 0

    self:storeOriginalPosition()
    self:storeScaledValues()
    self:createComponents(hudAtlasPath)

    return self
end


---Set a custom text to display.
function GamePausedDisplay:setPauseText(text)
    self.pauseText = text
end


---Handle menu visibility state change.
function GamePausedDisplay:onMenuVisibilityChange(isMenuVisible, isOverlayMenu)
    -- When a menu was visible we show an opaque background to prevent too much layering
    local showFullscreen = isMenuVisible and not isOverlayMenu
    self.syncBackgroundElement:setVisible(showFullscreen)
end






---
function GamePausedDisplay:draw()
    if self:getVisible() then
        GamePausedDisplay:superClass().draw(self)

        local textHeight = getTextHeight(self.textSize, self.pauseText)
        local baseX, baseY = self:getPosition()
        local posX = baseX + self:getWidth() * 0.5 + self.textOffsetX
        local posY = baseY + (self:getHeight() - textHeight) * 0.5 + self.textOffsetY

        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(GamePausedDisplay.COLOR.TEXT))
        renderText(posX, posY, self.textSize, self.pauseText)
    end
end






---Set uniform UI scale.
function GamePausedDisplay:setScale(uiScale)
    GamePausedDisplay:superClass().setScale(self, 1) -- ignore UI scale, this element must only scale with resolution
end


---Store scaled positioning, size and offset values.
function GamePausedDisplay:storeScaledValues()
    self.textSize = self:scalePixelToScreenHeight(GamePausedDisplay.TEXT_SIZE.PAUSE_TEXT)
    self.textOffsetX, self.textOffsetY = self:scalePixelToScreenVector(GamePausedDisplay.POSITION.PAUSE_TEXT)
end






---Get this element's base background position.
function GamePausedDisplay.createBackground(hudAtlasPath)
    local _, height = getNormalizedScreenValues(unpack(GamePausedDisplay.SIZE.SELF))
    local overlay = Overlay.new(hudAtlasPath, 0, (1 - height) * 0.5, 1, height) -- span horizontally, middle vertical

    overlay:setUVs(GuiUtils.getUVs(GamePausedDisplay.UV.BACKGROUND))
    overlay:setColor(unpack(GamePausedDisplay.COLOR.BACKGROUND))

    return overlay
end


---Create required display components.
function GamePausedDisplay:createComponents(hudAtlasPath)
    local syncOverlay = Overlay.new(GamePausedDisplay.SYNC_SPLASH_PATH, 0, 0, 1, g_screenWidth / g_screenHeight)
    self.syncBackgroundElement = HUDElement.new(syncOverlay)
    self:addChild(self.syncBackgroundElement)
end
