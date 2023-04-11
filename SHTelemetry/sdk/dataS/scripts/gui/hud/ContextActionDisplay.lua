---Player context action display element.
--
--Displays information about the current interaction context. Includes action names and current input scheme button
--glyphs.









local ContextActionDisplay_mt = Class(ContextActionDisplay, HUDDisplayElement)














---Create a new instance of ContextActionDisplay.
-- @param string hudAtlasPath Path to the HUD texture atlas
function ContextActionDisplay.new(hudAtlasPath, inputDisplayManager)
    local backgroundOverlay = ContextActionDisplay.createBackground()
    local self = ContextActionDisplay:superClass().new(backgroundOverlay, nil, ContextActionDisplay_mt)

    self.uiScale = 1.0
    self.inputDisplayManager = inputDisplayManager

    self.inputGlyphElement = nil

    self.contextIconElements = {}
    self.contextAction = ""
    self.contextIconName = ""
    self.targetText = ""
    self.actionText = ""
    self.contextPriority = -math.huge

    self.contextIconElementRightX = 0
    self.contextIconOffsetX, self.contextIconOffsetY = 0, 0
    self.contextIconSizeX = 0
    self.actionTextOffsetX, self.actionTextOffsetY = 0, 0
    self.actionTextSize = 0
    self.targetTextOffsetX, self.targetTextOffsetY = 0, 0
    self.targetTextSize = 0
    self.borderOffsetX = 0

    self.displayTime = 0

    self:createComponents(hudAtlasPath, inputDisplayManager)

    return self
end


---Sets the current action context.
This must be called each frame when a given context is active. The highest priority context is displayed or the one
which was set the latest if two or more contexts have the same priority.
-- @param string contextAction Input action name of the context action
-- @param string contextIconName Name of the icon to display for the action context, use one of ContextActionDisplay.CONTEXT_ICON
-- @param string targetText Display text which describes the context action target
-- @param int priority [optional, default=0] Context priority, a higher number has higher priority.
-- @param string actionText [optional] Context action description, if different from context action description
function ContextActionDisplay:setContext(contextAction, contextIconName, targetText, priority, actionText)
    if priority == nil then
        priority = 0
    end

    if priority >= self.contextPriority and self.contextIconElements[contextIconName] ~= nil then
        self.contextAction = contextAction
        self.contextIconName = contextIconName
        self.targetText = targetText
        self.contextPriority = priority

        local eventHelpElement = self.inputDisplayManager:getEventHelpElementForAction(self.contextAction)
        self.contextEventHelpElement = eventHelpElement

        if eventHelpElement ~= nil then
            self.inputGlyphElement:setAction(contextAction)
            self.actionText = utf8ToUpper(actionText or eventHelpElement.textRight or eventHelpElement.textLeft)


            -- Position directly left of the target text. We center this text so we use the position
            -- to determine icon position
            local targetTextWidth = getTextWidth(self.targetTextSize, self.targetText)
            self.rightSideX = 0.5 - targetTextWidth * 0.5


            local contextIconWidth = 0

            local posX = self.rightSideX + self.contextIconOffsetX
            for name, element in pairs(self.contextIconElements) do
                element:setPosition(posX - element:getWidth(), nil) -- no change to Y position

                if name == self.contextIconName then
                    contextIconWidth = element:getWidth()
                end
            end

            posX = posX - self.inputGlyphElement:getWidth() + self.inputIconOffsetX - contextIconWidth
            self.inputGlyphElement:setPosition(posX, nil)
        end

        if not self:getVisible() then
            self:setVisible(true, true)
        end
    end

    for name, element in pairs(self.contextIconElements) do
        element:setVisible(name == self.contextIconName)
    end

    -- always refresh display time:
    self.displayTime = ContextActionDisplay.MIN_DISPLAY_DURATION
end






---Update the context action display state.
function ContextActionDisplay:update(dt)
    ContextActionDisplay:superClass().update(self, dt)

    self.displayTime = self.displayTime - dt
    local isVisible = self:getVisible()

    if self.displayTime <= 0 and isVisible and self.animation:getFinished() then
        self:setVisible(false, true)
    end

    if not self.animation:getFinished() then
        self:storeScaledValues()
    elseif self.contextAction ~= "" and not isVisible then
        self:resetContext() -- reset context data when move-out animation has finished
    end
end


---Reset context state after drawing.
The context must be set anew on each frame.
function ContextActionDisplay:resetContext()
    self.contextAction = ""
    self.contextIconName = ""
    self.targetText = ""
    self.actionText = ""
    self.contextPriority = -math.huge
end






---Draw the context action display.
function ContextActionDisplay:draw()
    if self.contextAction ~= "" and self.contextEventHelpElement ~= nil then
        self.inputGlyphElement:setAction(self.contextAction) -- updates input mode and glyphs if necessary

        ContextActionDisplay:superClass().draw(self)
        local _, baseY = self:getPosition()

        setTextColor(unpack(ContextActionDisplay.COLOR.ACTION_TEXT))
        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_LEFT)

        local height = self:getHeight()

        local posX, posY = self.rightSideX, baseY + height * 0.5 + self.targetTextSize * 0.5 + self.actionTextOffsetY
        renderText(posX, posY, self.actionTextSize, self.actionText)

        posY = baseY + height * 0.5

        setTextColor(unpack(ContextActionDisplay.COLOR.TARGET_TEXT))
        setTextBold(false)

        local width = self:getWidth()
        local textWrapWidth = width - self.targetTextOffsetX - self.contextIconSizeX - self.inputGlyphElement:getWidth() * 2 - self.contextIconOffsetX

        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(0.5, posY, self.targetTextSize, self.targetText)

        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)

        if g_uiDebugEnabled then
            local yPixel = 1 / g_screenHeight
            setOverlayColor(GuiElement.debugOverlay, 0, 1, 1, 1)
            renderOverlay(GuiElement.debugOverlay, posX, posY, textWrapWidth, yPixel)
        end
    end
end










---Set the scale of this element.
function ContextActionDisplay:setScale(uiScale)
    ContextActionDisplay:superClass().setScale(self, uiScale, uiScale)

    local currentVisibility = self:getVisible()
    self:setVisible(true, false)

    self.uiScale = uiScale
    local posX, posY = ContextActionDisplay.getBackgroundPosition(uiScale, self:getWidth())
    self:setPosition(posX, posY)

    self:storeOriginalPosition()
    self:setVisible(currentVisibility, false)

    self:storeScaledValues()

    -- Special case because this display needs to cover the whole width at all times
    self.fadeBackgroundElement:setDimension(1)
    self.fadeBackgroundElement:setPosition(0, 0)
end


---Store scaled positioning, size and offset values.
function ContextActionDisplay:storeScaledValues()
    self.contextIconOffsetX, self.contextIconOffsetY = self:scalePixelToScreenVector(ContextActionDisplay.POSITION.CONTEXT_ICON)
    self.contextIconSizeX = self:scalePixelToScreenWidth(ContextActionDisplay.SIZE.CONTEXT_ICON[1])
    self.borderOffsetX = self:scalePixelToScreenWidth(ContextActionDisplay.OFFSET.X)

    self.inputIconOffsetX, self.inputIconOffsetX = self:scalePixelToScreenVector(ContextActionDisplay.POSITION.INPUT_ICON)

    self.actionTextOffsetX, self.actionTextOffsetY = self:scalePixelToScreenVector(ContextActionDisplay.POSITION.ACTION_TEXT)
    self.actionTextSize = self:scalePixelToScreenHeight(ContextActionDisplay.TEXT_SIZE.ACTION_TEXT)

    self.targetTextOffsetX, self.targetTextOffsetY = self:scalePixelToScreenVector(ContextActionDisplay.POSITION.TARGET_TEXT)
    self.targetTextSize = self:scalePixelToScreenHeight(ContextActionDisplay.TEXT_SIZE.TARGET_TEXT)
end


---Get the position of the background element, which provides this element's absolute position.
-- @param scale Current UI scale
-- @param float width Scaled background width in pixels
-- @return float X position in screen space
-- @return float Y position in screen space
function ContextActionDisplay.getBackgroundPosition(scale, width)
    local offX, offY = getNormalizedScreenValues(unpack(ContextActionDisplay.POSITION.BACKGROUND))
    return 0.5 - width * 0.5 - offX * scale, g_safeFrameOffsetY - offY * scale
end






---Create an empty background overlay as a base frame for this element.
function ContextActionDisplay.createBackground()
    local width, height = getNormalizedScreenValues(unpack(ContextActionDisplay.SIZE.BACKGROUND))
    local posX, posY = ContextActionDisplay.getBackgroundPosition(1, width)

    local overlay = Overlay.new(nil, posX, posY, width, height) -- empty overlay, only used as a positioning frame

    return overlay
end


---Create display components.
-- @param string hudAtlasPath Path to HUD atlas texture
-- @param table inputDisplayManager InputDisplayManager reference
function ContextActionDisplay:createComponents(hudAtlasPath, inputDisplayManager)
    local baseX, baseY = self:getPosition()
    self:createFrame(hudAtlasPath, baseX, baseY)
    self:createInputGlyph(hudAtlasPath, baseX, baseY, inputDisplayManager)
    self:createActionIcons(hudAtlasPath, baseX, baseY)

    self:createFadeBackground(hudAtlasPath)


    self:storeOriginalPosition()
end


---Create the input glyph element.
function ContextActionDisplay:createInputGlyph(hudAtlasPath, baseX, baseY, inputDisplayManager)
    local width, height = getNormalizedScreenValues(unpack(ContextActionDisplay.SIZE.INPUT_ICON))
    local offX, offY = getNormalizedScreenValues(unpack(ContextActionDisplay.POSITION.INPUT_ICON))
    local element = InputGlyphElement.new(inputDisplayManager, width, height)

    local posX, posY = baseX + offX, baseY + offY + (self:getHeight() - height) * 0.5

    element:setPosition(posX, posY)
    element:setKeyboardGlyphColor(ContextActionDisplay.COLOR.INPUT_ICON)

    self.inputGlyphElement = element
    self:addChild(element)
end


---Create the context display frame.
function ContextActionDisplay:createFrame(hudAtlasPath, baseX, baseY)
    -- local frame = HUDFrameElement.new(hudAtlasPath, baseX, baseY, self:getWidth(), self:getHeight())
    -- frame:setColor(unpack(HUD.COLOR.FRAME_BACKGROUND))
    -- self:addChild(frame)
end


---Create action context icons.
Only one of these will be visible at any time.
function ContextActionDisplay:createActionIcons(hudAtlasPath, baseX, baseY)
    local posX, posY = getNormalizedScreenValues(unpack(ContextActionDisplay.POSITION.CONTEXT_ICON))
    local width, height = getNormalizedScreenValues(unpack(ContextActionDisplay.SIZE.CONTEXT_ICON))

    local centerY = baseY + (self:getHeight() - height) * 0.5 + posY

    for _, iconName in pairs(ContextActionDisplay.CONTEXT_ICON) do
        local iconOverlay = Overlay.new(hudAtlasPath, baseX + posX, centerY, width, height)
        local uvs = ContextActionDisplay.UV[iconName]
        iconOverlay:setUVs(GuiUtils.getUVs(uvs))
        iconOverlay:setColor(unpack(ContextActionDisplay.COLOR.CONTEXT_ICON))

        local iconElement = HUDElement.new(iconOverlay)
        iconElement:setVisible(false)

        self.contextIconElements[iconName] = iconElement
        self:addChild(iconElement)
    end
end
