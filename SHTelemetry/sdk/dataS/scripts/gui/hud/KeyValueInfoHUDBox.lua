---Info box with key-value layout









local KeyValueInfoHUDBox_mt = Class(KeyValueInfoHUDBox, InfoHUDBox)


---
function KeyValueInfoHUDBox.new(uiScale)
    local self = InfoHUDBox.new(KeyValueInfoHUDBox_mt, uiScale)

    self.displayComponents = {}

    self.cachedLines = {}
    self.activeLines = {}

    self.title = "Unknown Title"

    return self
end






---
function KeyValueInfoHUDBox:canDraw()
    return self.doShowNextFrame
end


---Get this HUD extension's display height.
-- @return float Display height in screen space
function KeyValueInfoHUDBox:getDisplayHeight()
    return 2 * self.listMarginHeight + #self.activeLines * self.rowHeight + self.labelTextSize + self.labelTextOffsetY
end


---
function KeyValueInfoHUDBox:draw(posX, posY)
    local rightX = posX
    local leftX = posX - self.boxWidth
    local y = posY

    local height = 2 * self.listMarginHeight + #self.activeLines * self.rowHeight
    drawFilledRect(leftX, y, self.boxWidth, height, 0, 0, 0, 0.75)

    -- Draw title
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(KeyValueInfoHUDBox.COLOR.TEXT_DEFAULT))
    setTextBold(true)
    renderText(leftX + self.labelTextOffsetX, y + height + self.labelTextOffsetY, self.titleTextSize, self.title)
    setTextBold(false)

    -- Displayitems
    y = y + self.listMarginHeight
    leftX = leftX + self.leftTextOffsetX + self.listMarginWidth
    rightX = rightX - self.rightTextOffsetX - self.listMarginWidth

    local textAreaX = self.boxWidth - self.leftTextOffsetX - self.listMarginWidth - self.rightTextOffsetX - self.listMarginWidth

    for i = #self.activeLines, 1, -1 do
        local line = self.activeLines[i]

        setTextBold(true)
        if line.accentuate then
            setTextColor(unpack(line.accentuateColor or KeyValueInfoHUDBox.COLOR.TEXT_HIGHLIGHT))
        end

        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(leftX, y + self.leftTextOffsetY, self.rowTextSize, line.key)

        setTextAlignment(RenderText.ALIGN_RIGHT)
        local maxWidth = textAreaX - 0.025 * self.boxWidth - getTextWidth(self.rowTextSize, line.key)
        setTextBold(false)

        local text = Utils.limitTextToWidth(line.value, self.rowTextSize, maxWidth, false, "...")
        renderText(rightX, y + self.rightTextOffsetY, self.rowTextSize, text)

        if line.accentuate then
            setTextColor(unpack(KeyValueInfoHUDBox.COLOR.TEXT_DEFAULT))
        end

        if i < #self.activeLines then
            drawFilledRect(leftX, y, self.rowWidth, 1 / g_screenHeight, unpack(KeyValueInfoHUDBox.COLOR.SEPARATOR))
        end

        y = y + self.rowHeight
    end

    setTextAlignment(RenderText.ALIGN_LEFT)

    self.doShowNextFrame = false
end






---
function KeyValueInfoHUDBox:clear()
    for i = #self.activeLines, 1, -1 do
        self.cachedLines[#self.cachedLines + 1] = self.activeLines[i]
        self.activeLines[i] = nil
    end
end


---
function KeyValueInfoHUDBox:setTitle(title)
    title = utf8ToUpper(title)
    if title ~= self.title then
        self.title = title

        -- Try to fit text by wrapping it at max-length and then testing is we lost any characters after
        -- the first line
        self.titleTextSize = self:textSizeToFit(self.labelTextSize, self.title, self.boxWidth)
    end
end


---
function KeyValueInfoHUDBox:textSizeToFit(baseSize, text, maxWidth, minSize)
    local size = baseSize
    if minSize == nil then
        minSize = baseSize / 2
    end

    setTextWrapWidth(maxWidth)
    local lengthWithNoLineLimit = getTextLength(size, text, 99999)

    while getTextLength(size, text, 1) < lengthWithNoLineLimit do
        size = size - baseSize * 0.05

        -- Limit size. Cut off any extra text
        if size <= baseSize / 2 then
            -- Undo
            size = size + baseSize * 0.05

            break
        end
    end

    setTextWrapWidth(0)

    return size
end


---
function KeyValueInfoHUDBox:addLine(key, value, accentuate, accentuateColor)
    local line
    local cached = self.cachedLines
    local numCached = #cached
    if numCached > 0 then
        line = self.cachedLines[numCached]
        self.cachedLines[numCached] = nil
    else
        line = {}
    end

    line.key = key
    line.value = value or ""
    line.accentuate = accentuate
    line.accentuateColor = accentuateColor

    self.activeLines[#self.activeLines + 1] = line
end


---
function KeyValueInfoHUDBox:showNextFrame()
    self.doShowNextFrame = true
end






---
function KeyValueInfoHUDBox:setScale(uiScale)
    self.uiScale = uiScale
    self:storeScaledValues()
end


---
function KeyValueInfoHUDBox:storeScaledValues()
    local scale = self.uiScale

    local function normalize(x, y)
        return x * scale * g_aspectScaleX / g_referenceScreenWidth, y * scale * g_aspectScaleY / g_referenceScreenHeight
    end

    self.boxWidth = normalize(340, 0)

    local _
    _, self.labelTextSize = normalize(0, HUDElement.TEXT_SIZE.DEFAULT_TITLE)
    _, self.rowTextSize = normalize(0, HUDElement.TEXT_SIZE.DEFAULT_TEXT)
    self.titleTextSize = self.labelTextSize

    self.labelTextOffsetX, self.labelTextOffsetY = normalize(0, 3)
    self.leftTextOffsetX, self.leftTextOffsetY = normalize(0, 6)
    self.rightTextOffsetX, self.rightTextOffsetY = normalize(0, 6)

    self.rowWidth, self.rowHeight = normalize(308, 26)
    self.listMarginWidth, self.listMarginHeight = normalize(16, 15)
end
