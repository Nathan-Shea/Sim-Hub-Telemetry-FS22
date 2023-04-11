---HUD side notification element.
--
--Displays notifications issued by other game components at the side of the screen.









local SideNotification_mt = Class(SideNotification, HUDDisplayElement)







---Create a new SideNotification.
-- @param string hudAtlasPath Path to the HUD atlas texture
-- @return table SideNotification instance
function SideNotification.new(customMt, hudAtlasPath)
    local self = SideNotification:superClass().new(nil, nil, customMt or SideNotification_mt)
    self.overlay = self:createBackground(hudAtlasPath)

    self.notificationQueue = {} -- i={text=<text>, color={r,g,b,a}, duration=<time in ms>}

    self.textSize = 0
    self.textOffsetY = 0 -- vertical alignment compensation offset
    self.lineOffset = 0
    self.notificationMarginX, self.notificationMarginY = 0, 0

    return self
end


---Add a notification message to display.
-- @param string text Display message text
-- @param table color Color array as {r, g, b, a}
-- @param int displayDuration Display duration of message in milliseconds
function SideNotification:addNotification(text, color, displayDuration)
    local notification = {text=text, color=color, duration=displayDuration, startDuration=displayDuration}
    table.insert(self.notificationQueue, notification)

    self:updateSizeAndPositions()
end






---Update notifications state.
function SideNotification:update(dt)
    local hasRemoval = false
    for i = math.min(#self.notificationQueue, SideNotification.MAX_NOTIFICATIONS), 1, -1  do
        local notification = self.notificationQueue[i]
        if notification.duration <= 0 then
            table.remove(self.notificationQueue, i)
            hasRemoval = true
        else
            notification.duration = math.max(0, notification.duration - dt) -- limit to zero for alpha calculations
        end
    end

    if hasRemoval then
        self:updateSizeAndPositions()
    end
end






---Draw the notifications.
function SideNotification:draw()
    if self:getVisible() and #self.notificationQueue > 0 then
        SideNotification:superClass().draw(self)

        local baseX, baseY = self:getPosition()
        local width, height = self:getWidth(), self:getHeight()

        local offsetX = 1 / g_screenWidth
        local offsetY = 1 / g_screenHeight
        local notificationX = baseX + width - self.notificationMarginX
        local notificationY = baseY + height - self.textSize - self.notificationMarginY

        local _, _, _, alpha = self:getColor()
        for i = 1, math.min(#self.notificationQueue, SideNotification.MAX_NOTIFICATIONS) do
            local notification = self.notificationQueue[i]

            local fadeAlpha = 1
            if notification.startDuration - notification.duration < SideNotification.FADE_DURATION then
                fadeAlpha = (notification.startDuration - notification.duration) / SideNotification.FADE_DURATION
            elseif notification.duration < SideNotification.FADE_DURATION then
                fadeAlpha = notification.duration / SideNotification.FADE_DURATION
            end

            setTextBold(false)
            setTextAlignment(RenderText.ALIGN_RIGHT)
            -- render shadow
            setTextColor(0, 0, 0, alpha * fadeAlpha)
            renderText(notificationX + offsetX, notificationY - offsetY + self.textOffsetY, self.textSize, notification.text)
            -- render text
            setTextColor(notification.color[1], notification.color[2], notification.color[3], notification.color[4] * alpha * fadeAlpha)
            renderText(notificationX, notificationY + self.textOffsetY, self.textSize, notification.text)

            notificationY = notificationY - self.textSize - self.lineOffset
        end
        -- reset color to prevent following texts from being colored
        setTextColor(1, 1, 1, 1)
    end
end







---Get this element's base background position.
-- @param float uiScale Current UI scale factor
function SideNotification.getBackgroundPosition(uiScale)
    local offX, offY = getNormalizedScreenValues(unpack(SideNotification.POSITION.SELF))
    return 1 - g_safeFrameOffsetX + offX * uiScale, 1 - g_safeFrameOffsetY + offY * uiScale -- top right corner plus offset
end


---Set uniform UI scale.
function SideNotification:setScale(uiScale)
    SideNotification:superClass().setScale(self, uiScale)
    self:updateSizeAndPositions()
end


---Update sizes and positions of this elements and its children.
function SideNotification:updateSizeAndPositions()
    local numLines = math.min(#self.notificationQueue, SideNotification.MAX_NOTIFICATIONS)

    local height = numLines * self.textSize + (numLines - 1) * self.lineOffset + self.notificationMarginY * 2
    local width = self:getWidth()
    self:setDimension(width, height)

    local topRightX, topRightY = SideNotification.getBackgroundPosition(self:getScale())
    local bottomY = topRightY - self:getHeight()
    self:setPosition(topRightX - width, bottomY)

    self:storeScaledValues()
end


---Store scaled positioning, size and offset values.
function SideNotification:storeScaledValues()
    self.textSize = self:scalePixelToScreenHeight(SideNotification.TEXT_SIZE.DEFAULT_NOTIFICATION)
    self.textOffsetY = self.textSize * 0.15
    self.lineOffset = self.textSize * 0.3
    self.notificationMarginX, self.notificationMarginY = self:scalePixelToScreenVector(SideNotification.SIZE.NOTIFICATION_MARGIN)
end






---Create the background overlay.
function SideNotification:createBackground(hudAtlasPath)
    local posX, posY = SideNotification.getBackgroundPosition(1)
    local width, height = getNormalizedScreenValues(unpack(SideNotification.SIZE.SELF))

    local overlay = Overlay.new(hudAtlasPath, posX - width, posY - height, width, height)
    overlay:setUVs(GuiUtils.getUVs(SideNotification.UV.DEFAULT_BACKGROUND))
    overlay:setColor(unpack(SideNotification.COLOR.DEFAULT_BACKGROUND))
    return overlay
end


---Create required display components.
function SideNotification:createComponents(hudAtlasPath)
end
