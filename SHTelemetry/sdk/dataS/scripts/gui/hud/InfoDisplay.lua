---HUD player information









local InfoDisplay_mt = Class(InfoDisplay, HUDDisplayElement)



















---
function InfoDisplay:setEnabled(isEnabled)
    self.isEnabled = isEnabled
end

























---
function InfoDisplay:update(dt)
    InfoDisplay:superClass().update(self, dt)

    if self.isEnabled then
        self:updateSize()
    end
end


---Update the info display size depending on used rows.
function InfoDisplay:updateSize()
    local height = 0

    for i = 1, #self.boxes do
        local box = self.boxes[i]

        if box:canDraw() then
            height = height + box:getDisplayHeight() + self.boxMarginY
        end
    end

    self.totalHeight = height
end


---
function InfoDisplay:getDisplayHeight()
    if self.isEnabled then
        return self.totalHeight
    else
        return 0
    end
end


---
function InfoDisplay:draw()
    if not self.isEnabled then
        return
    end

    InfoDisplay:superClass().draw(self)

    local posX, posY = 1 - g_safeFrameOffsetX, g_safeFrameOffsetY

    for i = #self.boxes, 1, -1 do
        local box = self.boxes[i]

        if box:canDraw() then
            box:draw(posX, posY)

            posY = posY + box:getDisplayHeight() + self.boxMarginY
        end
    end
end






---Get the scaled background position.
function InfoDisplay.getBackgroundPosition(uiScale)
    local width, _ = getNormalizedScreenValues(unpack(InfoDisplay.SIZE.SELF))
    local posX = 1 - g_safeFrameOffsetX - width * uiScale
    local posY = g_safeFrameOffsetY

    return posX, posY
end


---Set this element's UI scale factor.
-- @param float uiScale UI scale factor
function InfoDisplay:setScale(uiScale)
    InfoDisplay:superClass().setScale(self, uiScale, uiScale)
    self.uiScale = uiScale
    self:storeScaledValues()

    for _, box in ipairs(self.boxes) do
        self:setScale(uiScale)
    end
end


---Store scaled position and size values.
function InfoDisplay:storeScaledValues()
    self.boxMarginY = self:scalePixelToScreenHeight(InfoDisplay.SIZE.BOX_MARGIN)
end


---Create the background overlay.
function InfoDisplay.createBackground()
    local posX, posY = InfoDisplay.getBackgroundPosition(1)
    local width, height = getNormalizedScreenValues(unpack(InfoDisplay.SIZE.SELF))

    local overlay = Overlay.new(g_baseUIFilename, posX, posY, width, height)
    overlay:setUVs(g_colorBgUVs)
    overlay:setColor(1, 0, 0, 0.75)

    return overlay
end
