---Vehicle HUD fill levels display element.
--
--Displays fill level bars for the current vehicle configuration









local FillLevelsDisplay_mt = Class(FillLevelsDisplay, HUDDisplayElement)


---Creates a new FillLevelsDisplay instance.
-- @param string hudAtlasPath Path to the HUD texture atlas.
function FillLevelsDisplay.new(hudAtlasPath)
    local backgroundOverlay = FillLevelsDisplay.createBackground()
    local self = FillLevelsDisplay:superClass().new(backgroundOverlay, nil, FillLevelsDisplay_mt)

    self.uiScale = 1.0
    self.hudAtlasPath = hudAtlasPath

    self.vehicle = nil -- currently controlled vehicle
    self.fillLevelBuffer = {}
    self.fillLevelTextBuffer = {}
    self.fillTypeTextBuffer = {}

    self.fillTypeFrames = {} -- fill type index -> HUDElement
    self.fillTypeLevelBars = {} -- fill type index -> HUDElement
    self.weightFrames = {} -- fill type index -> HUDELement

    self.frameHeight = 0
    self.fillLevelTextSize = 0
    self.fillLevelTextOffsetX = 0
    self.fillLevelTextOffsetY = 0

    return self
end
















---Set the currently controlled vehicle which provides display data.
-- @param table vehicle Currently controlled vehicle
function FillLevelsDisplay:setVehicle(vehicle)
    self.vehicle = vehicle
end






---Update fill levels data.
function FillLevelsDisplay:addFillLevel(fillType, fillLevel, capacity, precision, maxReached)
    local added = false
    for j=1, #self.fillLevelBuffer do
        local fillLevelInformation = self.fillLevelBuffer[j]
        if fillLevelInformation.fillType == fillType then
            fillLevelInformation.fillLevel = fillLevelInformation.fillLevel + fillLevel
            fillLevelInformation.capacity = fillLevelInformation.capacity + capacity
            fillLevelInformation.precision = precision
            fillLevelInformation.maxReached = maxReached

            if self.addIndex ~= fillLevelInformation.addIndex then
                fillLevelInformation.addIndex = self.addIndex
                self.needsSorting = true
            end

            added = true
            break
        end
    end

    if not added then
        table.insert(self.fillLevelBuffer, {fillType=fillType, fillLevel=fillLevel, capacity=capacity, precision=precision, addIndex=self.addIndex, maxReached=maxReached})
        self.needsSorting = true
    end

    self.addIndex = self.addIndex + 1
end


---Update fill levels data.
function FillLevelsDisplay:updateFillLevelBuffers()
    clearTable(self.fillLevelTextBuffer)
    clearTable(self.fillTypeTextBuffer)

    for i=1, #self.fillLevelBuffer do
        local fillLevelInformation = self.fillLevelBuffer[i]
        local frame = self.fillTypeFrames[fillLevelInformation.fillType]
        frame:setVisible(false)
    end

    -- only empty fill level and capacity, so we won't need create the sub tables every frame
    for i = 1, #self.fillLevelBuffer do
        self.fillLevelBuffer[i].fillLevel = 0
        self.fillLevelBuffer[i].capacity = 0
    end

    self.addIndex = 0
    self.needsSorting = false
    self.vehicle:getFillLevelInformation(self)

    if self.needsSorting then
        table.sort(self.fillLevelBuffer, sortBuffer)
    end
end


---Update fill level frames display state.
function FillLevelsDisplay:updateFillLevelFrames()
    local _, yOffset = self:getPosition()
    local isFirst = true

    for i = 1, #self.fillLevelBuffer do
        local fillLevelInformation = self.fillLevelBuffer[i]
        if fillLevelInformation.capacity > 0 or fillLevelInformation.fillLevel > 0 then
            local value = 0
            if fillLevelInformation.capacity > 0 then
                value = fillLevelInformation.fillLevel / fillLevelInformation.capacity
            end

            local frame = self.fillTypeFrames[fillLevelInformation.fillType]
            frame:setVisible(true)

            local fillBar = self.fillTypeLevelBars[fillLevelInformation.fillType]
            fillBar:setValue(value)

            local baseX = self:getPosition()
            if isFirst then
                baseX = baseX + self.firstFillTypeOffset
            end
            frame:setPosition(baseX, yOffset)

            local precision = fillLevelInformation.precision or 0

            local formattedNumber
            if precision > 0 then
                local rounded = MathUtil.round(fillLevelInformation.fillLevel, precision)
                formattedNumber = string.format("%d%s%0"..precision.."d", math.floor(rounded), g_i18n.decimalSeparator, (rounded - math.floor(rounded)) * 10 ^ precision)
            else
                formattedNumber = string.format("%d", MathUtil.round(fillLevelInformation.fillLevel))
            end

            self.weightFrames[fillLevelInformation.fillType]:setVisible(fillLevelInformation.maxReached)

            local fillTypeName, unitShort
            if fillLevelInformation.fillType ~= FillType.UNKNOWN then
                local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillLevelInformation.fillType)
                fillTypeName = fillTypeDesc.title
                unitShort = fillTypeDesc.unitShort
            end

            local fillText = string.format("%s%s (%d%%)", formattedNumber, unitShort or "", math.floor(100 * value))
            self.fillLevelTextBuffer[#self.fillLevelTextBuffer + 1] = fillText

            if fillTypeName ~= nil then
                self.fillTypeTextBuffer[#self.fillLevelTextBuffer] = fillTypeName
            end

            yOffset = yOffset + self.frameHeight + self.frameOffsetY
            isFirst = false
        end
    end
end


---Update the fill levels state.
function FillLevelsDisplay:update(dt)
    FillLevelsDisplay:superClass().update(self, dt)

    if self.vehicle ~= nil then
        self:updateFillLevelBuffers()

        if #self.fillLevelBuffer > 0 then
            if not self:getVisible() and self.animation:getFinished() then
                self:setVisible(true, true)
            end

            self:updateFillLevelFrames()
        elseif self:getVisible() and self.animation:getFinished() then
            self:setVisible(false, true)
        end
    end
end






---Draw this element.
function FillLevelsDisplay:draw()
    FillLevelsDisplay:superClass().draw(self)

    if self:getVisible() then
        local baseX, baseY = self:getPosition()
        local width = self:getWidth()

        for i = 1, #self.fillLevelTextBuffer do
            local fillLevelText = self.fillLevelTextBuffer[i]

            local posX = baseX + width + self.fillLevelTextOffsetX
            local posY = baseY + (i - 1) * (self.frameHeight + self.frameOffsetY)
            if i == 1 then
                posX = posX + self.firstFillTypeOffset
            end

            setTextColor(unpack(FillLevelsDisplay.COLOR.FILL_LEVEL_TEXT))
            setTextBold(false)
            setTextAlignment(RenderText.ALIGN_RIGHT)

            renderText(posX, posY + self.fillLevelTextOffsetY, self.fillLevelTextSize, fillLevelText)

            -- if self.fillTypeTextBuffer[i] ~= nil then
            --     renderText(posX, posY + self.fillTypeTextOffsetY, self.fillLevelTextSize, self.fillTypeTextBuffer[i])
            -- end
        end
    end
end






---Set this element's scale.
function FillLevelsDisplay:setScale(uiScale)
    FillLevelsDisplay:superClass().setScale(self, uiScale, uiScale)

    local currentVisibility = self:getVisible()
    self:setVisible(true, false)

    self.uiScale = uiScale
    local posX, posY = FillLevelsDisplay.getBackgroundPosition(uiScale, self:getWidth())
    self:setPosition(posX, posY)

    self:storeOriginalPosition()
    self:setVisible(currentVisibility, false)

    self:storeScaledValues()
end


---Get the position of the background element, which provides this element's absolute position.
-- @param scale Current UI scale
-- @param float width Scaled background width in pixels
-- @return float X position in screen space
-- @return float Y position in screen space
function FillLevelsDisplay.getBackgroundPosition(scale, width)
    local x, y = unpack(FillLevelsDisplay.POSITION.BACKGROUND)

    -- For some reason there is an issue with positioning the display for uiScale<1
    -- This will move it a bit to the left so it does not clip into the speedometer.
    x = x - 80 + 80 / scale

    local offX, offY = getNormalizedScreenValues(x, y)
    return 1 - g_safeFrameOffsetX - width - offX * scale, g_safeFrameOffsetY + offY * scale
end


---Calculate and store scaling values based on the current UI scale.
function FillLevelsDisplay:storeScaledValues()
    self.fillLevelTextSize = self:scalePixelToScreenHeight(HUDElement.TEXT_SIZE.DEFAULT_TEXT)
    self.fillLevelTextOffsetX, self.fillLevelTextOffsetY = self:scalePixelToScreenVector(FillLevelsDisplay.POSITION.FILL_LEVEL_TEXT)

    self.fillTypeTextOffsetX, self.fillTypeTextOffsetY = self:scalePixelToScreenVector(FillLevelsDisplay.POSITION.FILL_TYPE_TEXT)

    local _
    _, self.frameHeight = self:scalePixelToScreenVector(FillLevelsDisplay.SIZE.FILL_TYPE_FRAME)
    _, self.frameOffsetY = self:scalePixelToScreenVector(FillLevelsDisplay.POSITION.FILL_TYPE_FRAME_MARGIN)
    self.firstFillTypeOffset = self:scalePixelToScreenVector(FillLevelsDisplay.POSITION.FIRST_FILL_TYPE_OFFSET)
end






---Create an empty background overlay as a base frame for this element.
function FillLevelsDisplay.createBackground()
    local width, height = getNormalizedScreenValues(unpack(FillLevelsDisplay.SIZE.BACKGROUND))
    local posX, posY = FillLevelsDisplay.getBackgroundPosition(1, width)

    return Overlay.new(nil, posX, posY, width, height) -- empty overlay, only used as a positioning frame
end


---Refresh fill type data and elements.
-- @param table fillTypeManager FillTypeManager reference
function FillLevelsDisplay:refreshFillTypes(fillTypeManager)
    for _, v in pairs(self.fillTypeFrames) do
        v:delete()
    end

    clearTable(self.fillTypeFrames)
    clearTable(self.fillTypeLevelBars)

    local posX, posY = self:getPosition()
    self:createFillTypeFrames(fillTypeManager, self.hudAtlasPath, posX, posY)
end


---Create fill type frames for all known fill types.
function FillLevelsDisplay:createFillTypeFrames(fillTypeManager, hudAtlasPath, baseX, baseY)
    for _, fillType in ipairs(fillTypeManager:getFillTypes()) do
        local frame = self:createFillTypeFrame(hudAtlasPath, baseX, baseY, fillType)
        self.fillTypeFrames[fillType.index] = frame
        frame:setScale(self.uiScale, self.uiScale)
        self:addChild(frame)
    end
end


---Create a fill type frame for the display of a fill type level state.
function FillLevelsDisplay:createFillTypeFrame(hudAtlasPath, baseX, baseY, fillType)
    local frameWidth, frameHeight = self:scalePixelToScreenVector(FillLevelsDisplay.SIZE.FILL_TYPE_FRAME)
    local frameX, frameY = self:scalePixelToScreenVector(FillLevelsDisplay.POSITION.FILL_TYPE_FRAME)

    local posX, posY = baseX + frameX, baseY + frameY

    local frameOverlay = Overlay.new(nil, posX, posY, frameWidth, frameHeight)
    local frame = HUDElement.new(frameOverlay)
    frame:setVisible(false)

    self:createFillTypeIcon(frame, posX, posY, fillType)
    self:createFillTypeBar(hudAtlasPath, frame, posX, posY, fillType)


    -- Icon for showing max weight has been reached
    local weightWidth, weightHeight = getNormalizedScreenValues(unpack(FillLevelsDisplay.SIZE.WEIGHT_LIMIT))
    local weightOffsetX, weightOffsetY = getNormalizedScreenValues(unpack(FillLevelsDisplay.POSITION.WEIGHT_LIMIT))
    local weightOverlay = Overlay.new(hudAtlasPath, posX + weightOffsetX, posY + weightOffsetY, weightWidth, weightHeight)
    weightOverlay:setUVs(GuiUtils.getUVs(FillLevelsDisplay.UV.WEIGHT_LIMIT))

    local weightFrame = HUDElement.new(weightOverlay)
    frame:addChild(weightFrame)

    self.weightFrames[fillType.index] = weightFrame

    return frame
end


---Create an icon for a fill type.
function FillLevelsDisplay:createFillTypeIcon(frame, baseX, baseY, fillType)
    if fillType.hudOverlayFilename ~= "" then
        local baseWidth = self:getWidth()
        local width, height = getNormalizedScreenValues(unpack(FillLevelsDisplay.SIZE.FILL_TYPE_ICON))
        local posX, posY = getNormalizedScreenValues(unpack(FillLevelsDisplay.POSITION.FILL_TYPE_ICON))


        -- local backdropOverlay = Overlay.new(self.hudAtlasPath, baseX + baseWidth - width + posX , baseY + posY, width, height)
        local backdropOverlay = Overlay.new(self.hudAtlasPath, baseX + posX , baseY + posY, width, height)
        backdropOverlay:setColor(unpack(FillLevelsDisplay.COLOR.FILL_TYPE_BACKDROP))
        backdropOverlay:setUVs(GuiUtils.getUVs(FillLevelsDisplay.UV.FILL_ICON_BACKDROP))

        local backdrop = HUDElement.new(backdropOverlay)
        frame:addChild(backdrop)

        local iconOverlay = Overlay.new(fillType.hudOverlayFilename, baseX + posX , baseY + posY, width, height)
        iconOverlay:setColor(unpack(FillLevelsDisplay.COLOR.FILL_TYPE_ICON))

        backdrop:addChild(HUDElement.new(iconOverlay))
    end
end


---Create a fill type bar used to display a fill level.
The newly created bar is added to the given parent frame and an internal collection indexable by fill type index.
-- @param string hudAtlasPath Path to HUD texture atlas
-- @param table frame Parent frame HUD element
-- @param float baseX Origin X position in screen space
-- @param float baseY Origin Y position in screen space
-- @param table fillType Fill type whose fill level is represented by the created bar
function FillLevelsDisplay:createFillTypeBar(hudAtlasPath, frame, baseX, baseY, fillType)
    local width, height = getNormalizedScreenValues(unpack(FillLevelsDisplay.SIZE.BAR))
    local barX, barY = getNormalizedScreenValues(unpack(FillLevelsDisplay.POSITION.BAR))
    local posX, posY = baseX + barX, baseY + barY

    local element = HUDRoundedBarElement.new(hudAtlasPath, posX, posY, width, height, true)
    element:setBarColor(unpack(FillLevelsDisplay.COLOR.BAR_FILLED))

    frame:addChild(element)

    -- store the fill bar for scaling with fill level
    self.fillTypeLevelBars[fillType.index] = element
end
