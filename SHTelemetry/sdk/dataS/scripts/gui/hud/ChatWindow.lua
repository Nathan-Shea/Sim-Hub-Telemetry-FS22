---HUD chat window.
--
--Displays chat messages.









local ChatWindow_mt = Class(ChatWindow, HUDDisplayElement)






---Create a new ChatWindow.
-- @param string hudAtlasPath Path to the HUD atlas texture.
-- @param table speakerDisplay SpeakerDisplay reference which is notified when this window is visible
-- @return table ChatWindow instance
function ChatWindow.new(hudAtlasPath, speakerDisplay)
    local backgroundOverlay = ChatWindow.createBackground(hudAtlasPath)
    local self = ChatWindow:superClass().new(backgroundOverlay, nil, ChatWindow_mt)

    self.speakerDisplay = speakerDisplay

    self.maxLines = ChatWindow.MAX_NUM_MESSAGES -- overrides parent class value
    self.messages = {} -- reference to chat message history owned by mission object
    self.historyNum = 50

    self.scrollOffset = 0
    self.hideTime = 0

    self.messageOffsetX, self.messageOffsetY = 0, 0
    self.textSize = 0
    self.textOffsetY = 0
    self.lineOffset = 0
    self.shadowOffset = 0

    self.isMenuVisible = false
    self.newMessageDuringMenu = false

    self:storeScaledValues()

    return self
end


---
function ChatWindow:setVisible(isVisible, animate)
    if isVisible then
        if not self.isMenuVisible then
            self.newMessageDuringMenu = false
        end

        -- Already visible
        if self:getVisible() then
            return
        end

        ChatWindow:superClass().setVisible(self, true, false)

        if animate then
            self.hideTime = ChatWindow.DISPLAY_DURATION
        else
            self.hideTime = -1
        end
    else
        self.hideTime = self:getVisible() and ChatWindow.DISPLAY_DURATION or 0
    end
end


---Scroll chat messages by a given amount.
-- @param int delta Number of lines (positive or negative) to scroll
-- @param int numMessages Number of currently stored chat messages
function ChatWindow:scrollChatMessages(delta)
    self.scrollOffset = math.max(0, math.min(self.scrollOffset + delta * self.textSize * 1.1, #self.messages * self.textSize * 2.5 - self:getHeight()))
end

















---Handle menu visibility state change.
function ChatWindow:onMenuVisibilityChange(isMenuVisible)
    self.isMenuVisible = isMenuVisible

    if self:getVisible() then
        self.newMessageDuringMenu = false
    end
end











---Update element state.
function ChatWindow:update(dt)
    ChatWindow:superClass().update(self, dt)

    if self.hideTime >= 0 then -- also update and hide if time has been set to 0, see test below
        self.hideTime = self.hideTime - dt
        if self.hideTime <= 0 then
            ChatWindow:superClass().setVisible(self, false, false)
        end
    end
end






---Draw the chat window.
function ChatWindow:draw()
    if self:getVisible() and (not self.isMenuVisible or g_gui.currentGuiName == "ChatDialog") and #self.messages > 0 then
        if g_gui.currentGuiName == "ChatDialog" then
            ChatWindow:superClass().draw(self)
        end

        local baseX, baseY = self:getPosition()
        setTextClipArea(baseX, baseY, baseX + self:getWidth(), baseY + self:getHeight())

        local posX, posY = baseX + self.messageOffsetX, baseY + self.messageOffsetY

        setTextWrapWidth(self:getWidth() - self.messageOffsetX * 2)
        setTextAlignment(RenderText.ALIGN_LEFT)

        local currentY = posY - self.scrollOffset

        for i = #self.messages, 1, -1 do
            local sender = self.messages[i].sender .. ":"
            local text = self.messages[i].msg

            -- Get text height
            local textHeight, _ = getTextHeight(self.textSize, text)

            -- Draw text
            currentY = currentY + textHeight

            setTextBold(false)
            setTextColor(unpack(ChatWindow.COLOR.MESSAGE_SHADOW))
            renderText(posX + self.shadowOffset, currentY - self.shadowOffset, self.textSize, text)
            setTextColor(unpack(ChatWindow.COLOR.MESSAGE))
            renderText(posX, currentY, self.textSize, text)

            -- Draw name above it
            currentY = currentY + self.textSize

            setTextBold(true)
            setTextColor(unpack(ChatWindow.COLOR.MESSAGE_SHADOW))
            renderText(posX + self.shadowOffset, currentY - self.shadowOffset, self.textSize, sender)

            local color = ChatWindow.COLOR.MESSAGE
            if self.messages[i].farmId ~= 0 then
                local farm = g_farmManager:getFarmById(self.messages[i].farmId)
                if farm ~= nil then
                    color = farm:getColor()
                end
            end

            setTextColor(unpack(color))
            renderText(posX, currentY, self.textSize, sender)

            -- Add margin between messages
            currentY = currentY + self.textSize * 0.5

            -- setTextLineBounds(lineShowOffset, numLinesShow)
            -- setTextLineBounds(0, 0)

            if currentY > posY + self:getHeight() then
                break
            end
        end

        setTextWrapWidth(0)
        setTextClipArea(0, 0, 1, 1)
        setTextBold(false)
    end
end






---Set this element's UI scale.
function ChatWindow:setScale(uiScale)
    ChatWindow:superClass().setScale(self, uiScale)
    self:storeScaledValues()
end


---Get this element's base background position.
-- @param float uiScale Current UI scale factor
function ChatWindow.getBackgroundPosition(uiScale)
    local offX, offY = getNormalizedScreenValues(unpack(ChatWindow.POSITION.SELF))
    return g_safeFrameMajorOffsetX + offX, g_safeFrameMajorOffsetY + offY
end


---Store scaled positioning, size and offset values.
function ChatWindow:storeScaledValues()
    self.messageOffsetX, self.messageOffsetY = self:scalePixelToScreenVector(ChatWindow.POSITION.MESSAGE)

    self.textSize = self:scalePixelToScreenHeight(ChatWindow.TEXT_SIZE.MESSAGE)
    self.textOffsetY = self.textSize * 0.15
    self.lineOffset = self.textSize * 0.3
    self.shadowOffset = ChatWindow.SHADOW_OFFSET_FACTOR * self.textSize
end






---Create the background overlay.
function ChatWindow.createBackground(hudAtlasPath)
    local posX, posY = ChatWindow.getBackgroundPosition(1)
    local width, height = getNormalizedScreenValues(unpack(ChatWindow.SIZE.SELF))

    local overlay = Overlay.new(hudAtlasPath, posX, posY, width, height)
    overlay:setUVs(GuiUtils.getUVs(HUD.UV.AREA))

    setOverlayCornerColor(overlay.overlayId, 0, 0, 0, 0, 0.9)
    setOverlayCornerColor(overlay.overlayId, 1, 0, 0, 0, 0.9)
    setOverlayCornerColor(overlay.overlayId, 2, 0, 0, 0, 0.4)
    setOverlayCornerColor(overlay.overlayId, 3, 0, 0, 0, 0.4)

    overlay.visible = false -- initialize as invisible, important for first hide call and hide timer
    return overlay
end
