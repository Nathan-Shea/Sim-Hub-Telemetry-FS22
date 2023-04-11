---HUD popup message.
--
--Displays a modal popup message which requires a player input to be accepted / dismissed or expires after a given
--time.









local HUDPopupMessage_mt = Class(HUDPopupMessage, HUDDisplayElement)



















---Create a new instance of HUDPopupMessage.
-- @param string hudAtlasPath Path to the HUD texture atlas
-- @param l10n I18N reference for text localization
-- @param inputManager InputBinding reference for custom input context handling
-- @param inputDisplayManager InputDisplayManager for input glyph display
-- @param ingameMap IngameMap reference used to notify the map when a message is shown
-- @return table HUDPopupMessage instance
function HUDPopupMessage.new(hudAtlasPath, l10n, inputManager, inputDisplayManager, ingameMap, guiSoundPlayer)
    local backgroundOverlay = HUDPopupMessage.createBackground(hudAtlasPath)
    local self = HUDPopupMessage:superClass().new(backgroundOverlay, nil, HUDPopupMessage_mt)

    self.l10n = l10n
    self.inputManager = inputManager
    self.inputDisplayManager = inputDisplayManager
    self.ingameMap = ingameMap -- in game map reference required to hide the map when showing a message
    self.guiSoundPlayer = guiSoundPlayer

    self.pendingMessages = {} -- {i={<message as defined in showMessage()>}}, ordered as a queue
    self.isCustomInputActive = false -- input state flag
    self.lastInputMode = self.inputManager:getInputHelpMode()

    self.inputRows = {} -- {i=HUDElement}
    self.inputGlyphs = {} -- {i=InputGlyphElement}, synchronous with self.inputRows
    self.skipGlyph = nil -- InputGlyphElement

    self.isMenuVisible = false
    self.time = 0 -- accumulated message display time
    self.isGamePaused = false -- game paused state

    self:storeScaledValues()
    self:createComponents(hudAtlasPath)

    return self
end











---Show a new message.
-- @param string title Title text
-- @param string message Main message text
-- @param int duration Message display duration in milliseconds. If set to 0, will cause the message to be
displayed for a duration derived from the message length. If set to <0, will cause the message to be displayed
for a very long time.
-- @param table controls [optional] Array of InputHelpElement instance for input hint row display
-- @param function callback [optional] Function to be called when the message is acknowledged or expires
-- @param table target [optional] Callback target which is passed as the first argument to the given callback function
function HUDPopupMessage:showMessage(title, text, duration, controls, callback, target)
    if duration == 0 then -- if no duration indicated, adjust duration according to message length
        duration = HUDPopupMessage.MIN_DURATION + string.len(text) * HUDPopupMessage.DURATION_PER_CHARACTER
    elseif duration < 0 then -- a negative duration is adjusted to five minutes ("almost" indefinite)
        duration = HUDPopupMessage.MAX_DURATION
    end

    while #self.pendingMessages > HUDPopupMessage.MAX_PENDING_MESSAGE_COUNT do
        table.remove(self.pendingMessages, 1)
    end

    local message = {
        isDialog=false,
        title=title,
        message=text,
        duration=duration,
        controls=Utils.getNoNil(controls, {}),
        callback=callback,
        target=target
    }

    if #message.controls > HUDPopupMessage.MAX_INPUT_ROW_COUNT then -- truncate
        for i = #message.controls, HUDPopupMessage.MAX_INPUT_ROW_COUNT + 1, -1 do
            table.remove(message.controls, i)
        end
    end

    table.insert(self.pendingMessages, message)
end








---Get this HUD element's visibility.
function HUDPopupMessage:getVisible()
    return HUDPopupMessage:superClass().getVisible(self) and self.currentMessage ~= nil
end











---Handle menu visibility changes.
function HUDPopupMessage:onMenuVisibilityChange(isMenuVisible)
    self.isMenuVisible = isMenuVisible
end


---Assign a new current message and adjust display state accordingly.
This also resizes the message box according to the required space.
function HUDPopupMessage:assignCurrentMessage(message)
    self.time = 0
    self.currentMessage = message

    local reqHeight = self:getTitleHeight() + self:getTextHeight() + self:getInputRowsHeight()
    reqHeight = reqHeight + self.borderPaddingY * 2 + self.textOffsetY + self.titleTextSize + self.textSize
    if #message.controls > 0 then
        reqHeight = reqHeight + self.inputRowsOffsetY
    end

    if not g_isServerStreamingVersion then
        reqHeight = reqHeight + self.skipButtonHeight
    end

    self:setDimension(self:getWidth(), math.max(self.minHeight, reqHeight))
    self:updateButtonGlyphs()
end


---Get the display height of the current message's title.
function HUDPopupMessage:getTitleHeight()
    local height = 0
    if self.currentMessage ~= nil then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(false)
        setTextWrapWidth(self:getWidth() - 2 * self.borderPaddingX)
        local title = utf8ToUpper(self.currentMessage.title)
        local lineHeight, numTitleRows = getTextHeight(self.titleTextSize, title)

        height = numTitleRows * lineHeight

        setTextWrapWidth(0)
    end

    return height
end


---Get the display height of the current message's text.
function HUDPopupMessage:getTextHeight()
    local height = 0
    if self.currentMessage ~= nil then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(false)
        setTextWrapWidth(self:getWidth() - 2 * self.borderPaddingX)
        setTextLineHeightScale(HUDPopupMessage.TEXT_LINE_HEIGHT_SCALE)
        height = getTextHeight(self.textSize, self.currentMessage.message)

        setTextWrapWidth(0)
        setTextLineHeightScale(RenderText.DEFAULT_LINE_HEIGHT_SCALE)
    end

    return height
end


---Get the display height of the current message's input rows.
function HUDPopupMessage:getInputRowsHeight()
    local height = 0
    if self.currentMessage ~= nil then
        -- add one to row count for the skip button
        height = (#self.currentMessage.controls + 1) * self.inputRowHeight
    end

    return height
end


---Animate this element on showing.
function HUDPopupMessage:animateHide()
    HUDPopupMessage:superClass().animateHide(self)

    g_depthOfFieldManager:popArea()
    self.blurAreaActive = false
    self.animation:addCallback(self.finishMessage) -- call finishMessage when animation has completed
end


---Start displaying a message dequeued from the currently pending messages.
Sets all required display and input state.
function HUDPopupMessage:startMessage()
    self.ingameMap:setAllowToggle(false) -- disable toggle input on map
    self.ingameMap:turnSmall() -- force map size to minimap state

    self:assignCurrentMessage(self.pendingMessages[1])
    table.remove(self.pendingMessages, 1)
end


---Finish displaying a message after it has either elapsed or been acknowledged by the player.
Resets display and input state and triggers any provided message callback.
function HUDPopupMessage:finishMessage()
    self.ingameMap:setAllowToggle(true) -- (re-)enable toggle input on map

    if self.currentMessage ~= nil and self.currentMessage.callback ~= nil then
        if self.currentMessage.target ~= nil then
            self.currentMessage.callback(self.currentMessage.target)
        else
            self.currentMessage.callback(self)
        end
    end

    self.currentMessage = nil
end






---Update this element's state.
function HUDPopupMessage:update(dt)
    if not self.isMenuVisible then
        HUDPopupMessage:superClass().update(self, dt)

        if not self.isGamePaused and not g_sleepManager:getIsSleeping() then
            self.time = self.time + dt
            self:updateCurrentMessage()
        end

        if self:getVisible() then
            local inputMode = self.inputManager:getInputHelpMode()
            if inputMode ~= self.lastInputMode then
                self.lastInputMode = inputMode
                self:updateButtonGlyphs()
            end
        end
    end
end


---Update the current message.
Disables this popup when time runs out and dequeues a pending messages for displaying.
function HUDPopupMessage:updateCurrentMessage()
    if self.currentMessage ~= nil then
        if self.time > self.currentMessage.duration then
            self.time = -math.huge -- clear time to avoid double triggers
            self:setVisible(false, true) -- animate out
        end
    elseif #self.pendingMessages > 0 then
        self:startMessage()
        self:setVisible(true, true) -- animate in

        self.animation:addCallback(function()
            local x, y = self:getPosition()
            g_depthOfFieldManager:pushArea(x, y, self:getWidth(), self:getHeight())
            self.blurAreaActive = true
        end)
    end
end


---Update button glyphs when the player input mode has changed.
function HUDPopupMessage:updateButtonGlyphs()
    if self.skipGlyph ~= nil then
        self.skipGlyph:setAction(InputAction.SKIP_MESSAGE_BOX, self.l10n:getText(HUDPopupMessage.L10N_SYMBOL.BUTTON_OK), self.skipTextSize, true, false)
    end

    if self.currentMessage ~= nil then
        local controlIndex = 1
        for i = 1, HUDPopupMessage.MAX_INPUT_ROW_COUNT do
            local rowIndex = HUDPopupMessage.MAX_INPUT_ROW_COUNT - i + 1
            local inputRowVisible = rowIndex <= #self.currentMessage.controls
            self.inputRows[i]:setVisible(inputRowVisible)

            if inputRowVisible then
                local control = self.currentMessage.controls[controlIndex]
                self.inputGlyphs[i]:setActions(control:getActionNames(), "", self.textSize, false, false)
                self.inputGlyphs[i]:setKeyboardGlyphColor(HUDPopupMessage.COLOR.INPUT_GLYPH)
                controlIndex = controlIndex + 1
            end
        end
    end
end






---Enable / disable input events for message confirmation / skipping.
function HUDPopupMessage:setInputActive(isActive)
    if not self.isCustomInputActive and isActive then
        self.inputManager:setContext(HUDPopupMessage.INPUT_CONTEXT_NAME, true, false)

        local _, eventId = self.inputManager:registerActionEvent(InputAction.MENU_ACCEPT, self, self.onConfirmMessage, false, true, false, true)
        self.inputManager:setActionEventTextVisibility(eventId, false)

        _, eventId = self.inputManager:registerActionEvent(InputAction.SKIP_MESSAGE_BOX, self, self.onConfirmMessage, false, true, false, true)
        self.inputManager:setActionEventTextVisibility(eventId, false)

        self.isCustomInputActive = true
    elseif self.isCustomInputActive and not isActive then
        self.inputManager:removeActionEventsByTarget(self)
        self.inputManager:revertContext(true) -- revert and clear message context
        self.isCustomInputActive = false
    end
end


---Event function for either InputAction.SKIP_MESSAGE_BOX or InputAction.MENU_ACCEPT.
function HUDPopupMessage:onConfirmMessage(actionName, inputValue)
    if self.animation:getFinished() then -- callbacks are tied to animation, make sure animation is not active
        self:setVisible(false, true)
    end
end











---Draw the message.
function HUDPopupMessage:draw()
    if not self.isMenuVisible and self:getVisible() and self.currentMessage ~= nil then
        HUDPopupMessage:superClass().draw(self)

        local baseX, baseY = self:getPosition()
        local width, height = self:getWidth(), self:getHeight()

        -- title
        setTextColor(unpack(HUDPopupMessage.COLOR.TITLE))
        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextWrapWidth(width - 2 * self.borderPaddingX)
        local textPosY = baseY + height - self.borderPaddingY

        if self.currentMessage.title ~= "" then
            local title = utf8ToUpper(self.currentMessage.title)
            textPosY = textPosY - self.titleTextSize
            renderText(baseX + width * 0.5, textPosY, self.titleTextSize, title)
        end

        -- message
        setTextBold(false)
        setTextColor(unpack(HUDPopupMessage.COLOR.TEXT))
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextLineHeightScale(HUDPopupMessage.TEXT_LINE_HEIGHT_SCALE)
        textPosY = textPosY - self.textSize + self.textOffsetY
        renderText(baseX + self.borderPaddingX, textPosY, self.textSize, self.currentMessage.message)
        textPosY = textPosY - getTextHeight(self.textSize, self.currentMessage.message)

        -- input rows
        setTextColor(unpack(HUDPopupMessage.COLOR.SKIP_TEXT))
        setTextAlignment(RenderText.ALIGN_RIGHT)
        local posX = baseX + width - self.borderPaddingX
        local posY = textPosY + self.inputRowsOffsetY - self.inputRowHeight - self.textSize
        for i = 1, #self.currentMessage.controls do
            local inputText = self.currentMessage.controls[i].textRight
            renderText(posX + self.inputRowTextX, posY + self.inputRowTextY, self.textSize, inputText)

            posY = posY - self.inputRowHeight
        end

        -- reset uncommon text settings:
        setTextWrapWidth(0)
        setTextLineHeightScale(RenderText.DEFAULT_LINE_HEIGHT_SCALE)
    end
end






---Get this element's base background position.
-- @param float uiScale Current UI scale factor
function HUDPopupMessage.getBackgroundPosition(uiScale)
    local offX, offY = getNormalizedScreenValues(unpack(HUDPopupMessage.POSITION.SELF))
    return 0.5 + offX * uiScale, g_safeFrameOffsetY + offY * uiScale -- bottom center plus offset
end


---Set uniform UI scale.
function HUDPopupMessage:setScale(uiScale)
    HUDPopupMessage:superClass().setScale(self, uiScale)
    self:storeScaledValues()

    -- reposition to middle of the screen, because the scale affects the position from bottom left corner
    local posX, posY = HUDPopupMessage.getBackgroundPosition(uiScale)
    local width = self:getWidth()
    self:setPosition(posX - width * 0.5, posY)
end


---Set this HUD element's width and height.
function HUDPopupMessage:setDimension(width, height)
    HUDPopupMessage:superClass().setDimension(self, width, height)
end


---Store scaled positioning, size and offset values.
function HUDPopupMessage:storeScaledValues()
    self.minWidth, self.minHeight = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.SELF)

    self.textOffsetX, self.textOffsetY = self:scalePixelToScreenVector(HUDPopupMessage.POSITION.MESSAGE_TEXT)
    self.inputRowsOffsetX, self.inputRowsOffsetY = self:scalePixelToScreenVector(HUDPopupMessage.POSITION.INPUT_ROWS)
    self.skipButtonOffsetX, self.skipButtonOffsetY = self:scalePixelToScreenVector(HUDPopupMessage.POSITION.SKIP_BUTTON)
    self.skipButtonWidth, self.skipButtonHeight = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.SKIP_BUTTON)

    self.inputRowWidth, self.inputRowHeight = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.INPUT_ROW)
    self.borderPaddingX, self.borderPaddingY = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.BORDER_PADDING)

    self.inputRowTextX, self.inputRowTextY = self:scalePixelToScreenVector(HUDPopupMessage.POSITION.INPUT_TEXT)

    self.titleTextSize = self:scalePixelToScreenHeight(HUDPopupMessage.TEXT_SIZE.TITLE)
    self.textSize = self:scalePixelToScreenHeight(HUDPopupMessage.TEXT_SIZE.TEXT)
    self.skipTextSize = self:scalePixelToScreenHeight(HUDPopupMessage.TEXT_SIZE.SKIP_TEXT)
end






---Create the background overlay.
function HUDPopupMessage.createBackground(hudAtlasPath)
    local posX, posY = HUDPopupMessage.getBackgroundPosition(1)
    local width, height = getNormalizedScreenValues(unpack(HUDPopupMessage.SIZE.SELF))

    local overlay = Overlay.new(hudAtlasPath, posX - width * 0.5, posY, width, height)
    overlay:setUVs(GuiUtils.getUVs(HUDPopupMessage.UV.BACKGROUND))
    overlay:setColor(unpack(HUDPopupMessage.COLOR.BACKGROUND))
    return overlay
end


---Create required display components.
function HUDPopupMessage:createComponents(hudAtlasPath)
    local basePosX, basePosY = self:getPosition()
    local baseWidth = self:getWidth()

    local _, inputRowHeight = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.INPUT_ROW)

    local posY = basePosY + inputRowHeight -- add one row's height as spacing for the skip button
    for i = 1, HUDPopupMessage.MAX_INPUT_ROW_COUNT do
        local buttonRow, inputGlyph

        buttonRow, inputGlyph, posY = self:createInputRow(hudAtlasPath, basePosX, posY)
        local rowIndex = HUDPopupMessage.MAX_INPUT_ROW_COUNT - i + 1
        self.inputRows[rowIndex] = buttonRow
        self.inputGlyphs[rowIndex] = inputGlyph
        self:addChild(buttonRow)
    end

    if not g_isServerStreamingVersion then
        local offX, offY = self:scalePixelToScreenVector(HUDPopupMessage.POSITION.SKIP_BUTTON)
        local glyphWidth, glyphHeight = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.INPUT_GLYPH)
        local skipGlyph = InputGlyphElement.new(self.inputDisplayManager, glyphWidth, glyphHeight)
        skipGlyph:setPosition(basePosX + (baseWidth - glyphWidth) * 0.5 + offX, basePosY - offY)
        skipGlyph:setAction(InputAction.SKIP_MESSAGE_BOX, self.l10n:getText(HUDPopupMessage.L10N_SYMBOL.BUTTON_OK), self.skipTextSize, true, false)

        self.skipGlyph = skipGlyph
        self:addChild(skipGlyph)
    end
end


---Create components for an input button row.
function HUDPopupMessage:createInputRow(hudAtlasPath, posX, posY)
    local overlay = Overlay.new(hudAtlasPath, posX, posY, self.inputRowWidth, self.inputRowHeight)
    overlay:setUVs(GuiUtils.getUVs(HUDPopupMessage.UV.BACKGROUND))
    overlay:setColor(unpack(HUDPopupMessage.COLOR.INPUT_ROW))
    local buttonPanel = HUDElement.new(overlay)

    local rowHeight = buttonPanel:getHeight()

    local glyphWidth, glyphHeight = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.INPUT_GLYPH)
    local inputGlyph = InputGlyphElement.new(self.inputDisplayManager, glyphWidth, glyphHeight)
    local offX, offY = self:scalePixelToScreenVector(HUDPopupMessage.POSITION.INPUT_GLYPH)
    local glyphX, glyphY = posX + self.borderPaddingX + offX, posY + (rowHeight - glyphHeight) * 0.5 + offY
    inputGlyph:setPosition(glyphX, glyphY)
    buttonPanel:addChild(inputGlyph)

    local width, height = self:scalePixelToScreenVector(HUDPopupMessage.SIZE.SEPARATOR)
    height = math.max(height, HUDPopupMessage.SIZE.SEPARATOR[2] / g_screenHeight)
    offX, offY = self:scalePixelToScreenVector(HUDPopupMessage.POSITION.SEPARATOR)
    overlay = Overlay.new(hudAtlasPath, posX + offX, posY + offY, width, height)
    overlay:setUVs(GuiUtils.getUVs(GameInfoDisplay.UV.SEPARATOR))
    overlay:setColor(unpack(GameInfoDisplay.COLOR.SEPARATOR))
    local separator = HUDElement.new(overlay)
    buttonPanel:addChild(separator)

    return buttonPanel, inputGlyph, posY + rowHeight
end
