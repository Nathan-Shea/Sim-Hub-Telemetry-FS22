---HUD top notification element.
--
--Displays notifications issued by other game components at the top of the screen.









local TopNotification_mt = Class(TopNotification, HUDDisplayElement)














---Create a new TopNotification.
-- @param string hudAtlasPath Path to the HUD atlas texture.
-- @return table TopNotification instance
function TopNotification.new(hudAtlasPath)
    local backgroundOverlay = TopNotification.createBackground(hudAtlasPath)
    local self = TopNotification:superClass().new(backgroundOverlay, nil, TopNotification_mt)

    self.currentNotification = TopNotification.NO_NOTIFICATION
    self.icons = {} -- icon key -> Overlay

    self.titleTextSize = 0
    self.descTextSize = 0
    self.infoTextSize = 0
    self.maxTextWidth = 0

    self.titleOffsetX, self.titleOffsetY = 0, 0
    self.descOffsetX, self.descOffsetY = 0, 0
    self.infoOffsetX, self.infoOffsetY = 0, 0
    self.iconOffsetX, self.iconOffsetY = 0, 0

    self.notificationStartDuration = 0

    self:storeScaledValues()
    self:createComponents(hudAtlasPath)
    self:createIconOverlays()

    return self
end


---
function TopNotification:delete()
    for k, overlay in pairs(self.icons) do
        overlay:delete()
        self.icons[k] = nil
    end

    if self.customIcon ~= nil then
        self.customIcon:delete()
        self.customIcon = nil
    end

    TopNotification:superClass().delete(self)
end



---Set a notification to be displayed in a frame at the top of the screen.
If another notification is being displayed, it is immediately replaced by this new one.
-- @param string title Notification title
-- @param string text Notification message text
-- @param string info Additional info text
-- @param table iconKey [optional] Icon key for a display icon, use a value from TopNotification.ICON
-- @param int duration [optional] Display duration in milliseconds. Negative values or nil default to a long-ish standard duration.
function TopNotification:setNotification(title, text, info, iconKey, duration, iconFilename)
    local icon = nil
    if iconKey ~= nil and self.icons[iconKey] ~= nil then
        icon = self.icons[iconKey]
    end

    if duration == nil or duration < 0 then
        duration = TopNotification.DEFAULT_DURATION
    end

    local notification = {title=title, text=text, info=info, icon=icon, duration=duration, iconFilename=iconFilename}
    self.notificationStartDuration = duration
    self.currentNotification = notification

    if iconFilename ~= nil then
        self.customIcon = self:createCustomIcon(iconFilename)
    end

    self:setVisible(true, true) -- animate in
end


---Get the screen space translation for hiding.
Override in sub-classes if a different translation is required.
-- @return float Screen space X translation
-- @return float Screen space Y translation
function TopNotification:getHidingTranslation()
    return 0, 0.5 -- hide half a screen height above the upper screen border
end






---Update notification state.
function TopNotification:update(dt)
    TopNotification:superClass().update(self, dt)

    if self:getVisible() and self.currentNotification ~= TopNotification.NO_NOTIFICATION then
        if self.currentNotification.duration < TopNotification.FADE_DURATION and self.animation:getFinished() then
            self:setVisible(false, true) -- animate out
        end

        if self.currentNotification.duration <= 0 then
            self.currentNotification = TopNotification.NO_NOTIFICATION
        else
            self.currentNotification.duration = self.currentNotification.duration - dt
        end
    end
end






---Draw notification.
function TopNotification:draw()
    if self:getVisible() then
        TopNotification:superClass().draw(self) -- background and frame

        local notification = self.currentNotification
        local title = Utils.limitTextToWidth(notification.title, self.titleTextSize, self.maxTextWidth, false, "...")
        local text = Utils.limitTextToWidth(notification.text, self.descTextSize, self.maxTextWidth, false, "...")
        local info = Utils.limitTextToWidth(notification.info, self.infoTextSize, self.maxTextWidth, false, "...")

        local fadeAlpha = 1
        if self.notificationStartDuration - self.currentNotification.duration < TopNotification.FADE_DURATION then
            fadeAlpha = (self.notificationStartDuration - self.currentNotification.duration) / TopNotification.FADE_DURATION
        elseif self.currentNotification.duration < TopNotification.FADE_DURATION then
            fadeAlpha = self.currentNotification.duration / TopNotification.FADE_DURATION
        end

        local _, _, _, baseAlpha = self:getColor()
        local baseX, baseY = self:getPosition()
        local width, height = self:getWidth(), self:getHeight()

        local alpha = baseAlpha * fadeAlpha

        if notification.iconFilename ~= nil then
            local icon = self.customIcon
            icon:setColor(nil, nil, nil, alpha)
            icon:setPosition(baseX + self.iconOffsetX, -- left
                baseY + (height - notification.icon.height) * 0.5) -- middle
            icon:render()
        elseif notification.icon ~= nil then
            local icon = notification.icon
            icon:setColor(nil, nil, nil, alpha)
            icon:setPosition(baseX + self.iconOffsetX, -- left
                baseY + (height - notification.icon.height) * 0.5) -- middle
            icon:render()
        end

        local r, g, b, a = unpack(TopNotification.COLOR.TEXT_TITLE)
        setTextColor(r, g, b, a * alpha)
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_CENTER)

        local centerX = baseX + width * 0.5
        renderText(centerX + self.titleOffsetX, baseY + self.titleOffsetY, self.titleTextSize, title)

        r, g, b, a = unpack(TopNotification.COLOR.TEXT_DESC)
        setTextColor(r, g, b, a * alpha)
        renderText(centerX + self.descOffsetX, baseY + self.descOffsetY, self.descTextSize, text)

        r, g, b, a = unpack(TopNotification.COLOR.TEXT_INFO)
        setTextColor(r, g, b, a * alpha)
        renderText(centerX + self.infoOffsetX, baseY + self.infoOffsetY, self.infoTextSize, info)
    end
end






---Get this element's base background position.
-- @param float uiScale Current UI scale factor
function TopNotification.getBackgroundPosition(uiScale, width, height)
    local offX, offY = getNormalizedScreenValues(unpack(TopNotification.POSITION.SELF))
    return 0.5 - width * 0.5 + offX * uiScale, 1 - g_safeFrameOffsetY - height + offY * uiScale -- top center plus offset
end


---Set uniform UI scale.
function TopNotification:setScale(uiScale)
    TopNotification:superClass().setScale(self, uiScale)
    self:storeScaledValues()

    -- set position again because we anchor from the top (scaling protrudes from bottom left)
    local width, height = self:scalePixelToScreenVector(TopNotification.SIZE.SELF)
    local posX, posY = TopNotification.getBackgroundPosition(uiScale, width, height)
    self:setPosition(posX, posY)
end


---Store scaled positioning, size and offset values.
function TopNotification:storeScaledValues()
    self.titleTextSize = self:scalePixelToScreenHeight(TopNotification.TEXT_SIZE.TITLE)
    self.descTextSize = self:scalePixelToScreenHeight(TopNotification.TEXT_SIZE.TEXT)
    self.infoTextSize = self:scalePixelToScreenHeight(TopNotification.TEXT_SIZE.INFO)

    self.maxTextWidth = self:scalePixelToScreenWidth(TopNotification.TEXT_SIZE.MAX_TEXT_WIDTH)

    self.titleOffsetX, self.titleOffsetY = self:scalePixelToScreenVector(TopNotification.POSITION.TITLE_OFFSET)
    self.descOffsetX, self.descOffsetY = self:scalePixelToScreenVector(TopNotification.POSITION.TEXT_OFFSET)
    self.infoOffsetX, self.infoOffsetY = self:scalePixelToScreenVector(TopNotification.POSITION.INFO_OFFSET)

    self.iconOffsetX, self.iconOffsetY = self:scalePixelToScreenVector(TopNotification.POSITION.ICON)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(TopNotification.SIZE.ICON)
    for _, overlay in pairs(self.icons) do
        overlay:setDimension(iconWidth, iconHeight)
    end
end






---Create the background overlay.
function TopNotification.createBackground(hudAtlasPath)
    local width, height = getNormalizedScreenValues(unpack(TopNotification.SIZE.SELF))
    local posX, posY = TopNotification.getBackgroundPosition(1, width, height)

    local overlay = Overlay.new(g_baseUIFilename, posX, posY, width, height)
    overlay:setUVs(g_colorBgUVs)
    overlay:setColor(unpack(TopNotification.COLOR.BACKGROUND))

    return overlay
end


---Create required display components.
function TopNotification:createComponents(hudAtlasPath)
end


---
function TopNotification:createIconOverlays()
    local width, height = getNormalizedScreenValues(unpack(TopNotification.SIZE.ICON))

    local iconOverlay = Overlay.new(g_iconsUIFilename, 0, 0, width, height)
    iconOverlay:setUVs(GuiUtils.getUVs(TopNotification.UV.ICON_RADIO_STREAM))
    iconOverlay:setColor(unpack(TopNotification.COLOR.ICON))
    self.icons[TopNotification.ICON.RADIO] = iconOverlay
end
