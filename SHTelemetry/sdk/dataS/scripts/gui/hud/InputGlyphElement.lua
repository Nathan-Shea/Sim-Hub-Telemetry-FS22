---Input glyph display element.
--
--Displays a key or button glyph for an input.









local InputGlyphElement_mt = Class(InputGlyphElement, HUDElement)









---Create a new instance of InputGlyphElement.
-- @param table inputDisplayManager InputDisplayManager reference
-- @param float baseWidth Default width of this element in screen space
-- @param float baseHeight Default height of this element in screen space
function InputGlyphElement.new(inputDisplayManager, baseWidth, baseHeight)
    local backgroundOverlay = Overlay.new(nil, 0, 0, baseWidth, baseHeight)
    local self = InputGlyphElement:superClass().new(backgroundOverlay, nil, InputGlyphElement_mt)

    self.inputDisplayManager = inputDisplayManager
    self.plusOverlay = inputDisplayManager:getPlusOverlay()
    self.orOverlay = inputDisplayManager:getOrOverlay()
    self.keyboardOverlay = ButtonOverlay.new()

    self.actionNames = {}
    self.actionText = nil -- optional action text to display next to the glyph
    self.displayText = nil -- lower or upper cased version of actionText for rendering
    self.actionTextSize = InputGlyphElement.DEFAULT_TEXT_SIZE
    self.inputHelpElement = nil

    self.buttonOverlays = {} -- action name -> overlays
    self.hasButtonOverlays = false
    self.separators = {} -- {i=InputHelpElement.SEPARATOR}
    self.keyNames = {} -- action name -> key names
    self.hasKeyNames = false

    self.color = {1, 1, 1, 1} -- RGBA array
    self.buttonColor = {1, 1, 1, 1} -- RGBA array
    self.overlayCopies = {} -- contains overlay copies which need to be deleted

    self.baseWidth, self.baseHeight = baseWidth, baseHeight

    self.glyphOffsetX = 0
    self.textOffsetX = 0
    self.iconSizeX, self.iconSizeY = baseWidth, baseHeight
    self.plusIconSizeX, self.plusIconSizeY = baseWidth * 0.5, baseHeight * 0.5
    self.orIconSizeX, self.orIconSizeY = baseWidth * 0.5, baseHeight * 0.5

    self.alignX, self.alignY = 1, 1
    self.alignmentOffsetX, self.alignmentOffsetY = 0, 0
    self.lowerCase = false
    self.upperCase = false
    self.bold = false

    return self
end


---Delete this element and release its resources.
function InputGlyphElement:delete()
    InputGlyphElement:superClass().delete(self)

    self.keyboardOverlay:delete()
    self:deleteOverlayCopies()
end










---Delete any overlay copies.
function InputGlyphElement:deleteOverlayCopies()
    for k, v in pairs(self.overlayCopies) do
        v:delete()
        self.overlayCopies[k] = nil
    end
end


---Set the scale of this element.
-- @param float widthScale Width scale factor
-- @param float heightScale Height scale factor
function InputGlyphElement:setScale(widthScale, heightScale)
    InputGlyphElement:superClass().setScale(self, widthScale, heightScale)

    self.glyphOffsetX = self:scalePixelToScreenWidth(InputGlyphElement.GLYPH_OFFSET_X)
    self.textOffsetX = self:scalePixelToScreenWidth(InputGlyphElement.TEXT_OFFSET_X)

    self.iconSizeX, self.iconSizeY = self.baseWidth * widthScale, self.baseHeight * heightScale
    self.plusIconSizeX, self.plusIconSizeY = self.iconSizeX * 0.5, self.iconSizeY * 0.5
    self.orIconSizeX, self.orIconSizeY = self.iconSizeX * 0.5, self.iconSizeY * 0.5
end


---Set the glyph text to be displayed in all upper case or not.
This resets the lower case setting if upper case is enabled.
function InputGlyphElement:setUpperCase(enableUpperCase)
    self.upperCase = enableUpperCase
    self.lowerCase = self.lowerCase and not enableUpperCase
    self:updateDisplayText()
end


---Set the glyph text to be displayed in all lower case or not.
This resets the upper case setting if lower case is enabled.
function InputGlyphElement:setLowerCase(enableLowerCase)
    self.lowerCase = enableLowerCase
    self.upperCase = self.upperCase and not enableLowerCase
    self:updateDisplayText()
end


---Set the glyph text to be displayed in bold print or not.
function InputGlyphElement:setBold(isBold)
    self.bold = isBold
end


---Set the button frame color for the keyboard glyphs.
-- @param table color Color as an RGBA array
function InputGlyphElement:setKeyboardGlyphColor(color)
    self.color = color
    self.keyboardOverlay:setColor(unpack(color))
end


---Set the color for button glyphs.
-- @param table color Color as an RGBA array
function InputGlyphElement:setButtonGlyphColor(color)
    self.buttonColor = color

    for _, actionName in ipairs(self.actionNames) do
        local buttonOverlays = self.buttonOverlays[actionName]
        if buttonOverlays ~= nil then -- safety-catch to avoid errors for invalid setups (will just not show icon)
            for _, overlay in pairs(buttonOverlays) do
                overlay:setColor(unpack(color))
            end
        end
    end
end


---Set the action whose input glyphs need to be displayed by this element.
-- @param string actionName InputAction name
-- @param string actionText [optional] Additional action text to display after the glyph
-- @param float actionTextSize [optional] Additional action text size in screen space
-- @param bool noModifiers [optional] If true, will only show the input glyph of the last unmodified input binding axis
-- @param bool copyOverlays [optional] If true, will create and handle a separate copy of an input glyph. Do not use
this when updating the action each frame!
function InputGlyphElement:setAction(actionName, actionText, actionTextSize, noModifiers, copyOverlays)
    -- use this instance's action names array instead of creating a new one each time this is called
    clearTable(self.actionNames)
    table.insert(self.actionNames, actionName)
    self:setActions(self.actionNames, actionText, actionTextSize, noModifiers, copyOverlays)
end


---Set multiple actions whose input glyphs need to be displayed by this element.
If exactly two actions are passed in, they will be interpreted as belonging to the same axis and the system tries
to resolved the actions to a combined glyph. Otherwise, the glyphs will just be displayed in order of the actions.
-- @param table actionNames InputAction names array
-- @param string actionText [optional] Additional action text to display after the glyph
-- @param float actionTextSize [optional] Additional action text size in screen space
-- @param bool noModifiers [optional] If true, will only show the input glyph of the last unmodified input binding axis
-- @param bool copyOverlays [optional] If true, will create and handle a separate copy of an input glyph. Do not use
this when updating the action each frame!
function InputGlyphElement:setActions(actionNames, actionText, actionTextSize, noModifiers, copyOverlays)
    self.actionNames = actionNames
    self.actionText = actionText
    self.actionTextSize = actionTextSize or InputGlyphElement.DEFAULT_TEXT_SIZE

    self:updateDisplayText() -- apply lower / upper case if necessary

    local height = self:getHeight()
    local width = 0

    self:deleteOverlayCopies()

    local isDoubleAction = #actionNames == 2

    for i, actionName in ipairs(actionNames) do
        local actionName2 = nil
        if isDoubleAction then
            actionName2 = actionNames[i + 1]
        end

        local helpElement = self.inputDisplayManager:getControllerSymbolOverlays(actionName, actionName2, "", noModifiers)
        local buttonOverlays = helpElement.buttons
        self.separators = helpElement.separators

        if copyOverlays then
            local originals = buttonOverlays
            buttonOverlays = {}

            for _, overlay in ipairs(originals) do
                -- TODO: make overlay:clone() function
                local overlayCopy = Overlay.new(overlay.filename, overlay.x, overlay.y, overlay.defaultWidth, overlay.defaultHeight)
                overlayCopy:setUVs(overlay.uvs)
                overlayCopy:setAlignment(overlay.alignmentVertical, overlay.alignmentHorizontal)

                table.insert(self.overlayCopies, overlayCopy)
                table.insert(buttonOverlays, overlayCopy)
            end
        end

        if self.buttonOverlays[actionName] == nil then
            self.buttonOverlays[actionName] = {}
        else
            for j=1, #self.buttonOverlays[actionName] do
                self.buttonOverlays[actionName][j] = nil
            end
        end
        self.hasButtonOverlays = false

        if #buttonOverlays > 0 then
            for _, overlay in ipairs(buttonOverlays) do
                table.insert(self.buttonOverlays[actionName], overlay)
                self.hasButtonOverlays = true
            end
        end

        if self.keyNames[actionName] == nil then
            self.keyNames[actionName] = {}
        else
            for j=1, #self.keyNames[actionName] do
                self.keyNames[actionName][j] = nil
            end
        end
        self.hasKeyNames = false

        if #helpElement.keys > 0 then
            for _, key in ipairs(helpElement.keys) do
                table.insert(self.keyNames[actionName], key)
                self.hasKeyNames = true
            end
        end

        if isDoubleAction then
            table.remove(self.actionNames, 2)
            break -- should have resolved everything now
        end
    end

    if self.hasButtonOverlays then
        for _, buttonOverlays in pairs(self.buttonOverlays) do
            for i, _ in ipairs(buttonOverlays) do
                if i > 1 then -- TODO: use separator types to get width
                    width = width + self.plusIconSizeX + self.glyphOffsetX
                end

                width = width + self.iconSizeX + (i < #buttonOverlays and self.glyphOffsetX or 0)
            end
        end
    elseif self.hasKeyNames then
        for _, keyNames in pairs(self.keyNames) do
            for _, key in ipairs(keyNames) do
                width = width + self.keyboardOverlay:getButtonWidth(key, height)
            end
        end
    end

    -- adjust this element's size so other elements can correctly offset from this
    self:setDimension(width, height)
end


---Update the display text from the set action text according to current casing settings.
function InputGlyphElement:updateDisplayText()
    if self.actionText ~= nil then
        self.displayText = self.actionText
        if self.upperCase then
            self.displayText = utf8ToUpper(self.actionText)
        elseif self.lowerCase then
            self.displayText = utf8ToLower(self.actionText)
        end
    end
end


---Get the screen space width required by the glyphs used to display input in the current input context.
function InputGlyphElement:getGlyphWidth()
    local width = 0
    if self.hasButtonOverlays then
        for _, actionName in ipairs(self.actionNames) do
            for i, _ in ipairs(self.buttonOverlays[actionName]) do
                if i > 1 then
                    local separatorType = self.separators[i - 1]
                    local separatorWidth = 0
                    if separatorType == InputHelpElement.SEPARATOR.COMBO_INPUT then
                        separatorWidth = self.plusIconSizeX
                    elseif separatorType == InputHelpElement.SEPARATOR.ANY_INPUT then
                        separatorWidth = self.orIconSizeX
                    end

                    width = width + separatorWidth + self.glyphOffsetX
                end

                local padding = i < #self.buttonOverlays[actionName] and self.glyphOffsetX or 0
                width = width + self.iconSizeX + padding
            end
        end
    elseif self.hasKeyNames then
        for _, actionName in ipairs(self.actionNames) do
            for i, key in ipairs(self.keyNames[actionName]) do
                local padding = i < #self.keyNames[actionName] and self.glyphOffsetX or 0
                width = width + self.keyboardOverlay:getButtonWidth(key, self.iconSizeY) + padding
            end
        end
    end

    return width
end


---Draw the input glyph(s).
function InputGlyphElement:draw(clipX1, clipY1, clipX2, clipY2)
    if #self.actionNames == 0 or not self.overlay.visible then
        return
    end

    local posX, posY = self:getPosition()

    if self.hasButtonOverlays then
        for _, actionName in ipairs(self.actionNames) do
            posX = self:drawControllerButtons(self.buttonOverlays[actionName], posX, posY, clipX1, clipY1, clipX2, clipY2)
        end
    elseif self.hasKeyNames then
        for _, actionName in ipairs(self.actionNames) do
            posX = self:drawKeyboardKeys(self.keyNames[actionName], posX, posY, clipX1, clipY1, clipX2, clipY2)
        end
    end

    if self.actionText ~= nil then
        self:drawActionText(posX, posY, clipX1, clipY1, clipX2, clipY2)
    end
end


---Draw controller button glyphs.
-- @param table Array of controller button glyph overlays
-- @param float posX Initial drawing X position in screen space
-- @param float posY Initial drawing Y position in screen space
-- @return float X position in screen space after the last glyph
function InputGlyphElement:drawControllerButtons(buttonOverlays, posX, posY, clipX1, clipY1, clipX2, clipY2)
    for i, overlay in ipairs(buttonOverlays) do
        if i > 1 then
            local separatorType = self.separators[i - 1]
            local separatorOverlay = self.orOverlay
            local separatorWidth = 0
            local separatorHeight = 0
            if separatorType == InputHelpElement.SEPARATOR.COMBO_INPUT then
                separatorOverlay = self.plusOverlay
                separatorWidth, separatorHeight = self.plusIconSizeX, self.plusIconSizeY
            elseif separatorType == InputHelpElement.SEPARATOR.ANY_INPUT then
                separatorWidth, separatorHeight = self.orIconSizeX, self.orIconSizeY
            end

            separatorOverlay:setColor(nil, nil, nil, self.buttonColor[4])
            separatorOverlay:setPosition(posX, posY + separatorHeight)
            separatorOverlay:setDimension(separatorWidth, separatorHeight)
            separatorOverlay:render(clipX1, clipY1, clipX2, clipY2)

            separatorOverlay:setColor(nil, nil, nil, 1) -- reset alpha

            separatorOverlay:resetDimensions()
            posX = posX + separatorWidth + self.glyphOffsetX
        end

        overlay:setPosition(posX, posY + self.iconSizeY * 0.5) -- controller symbols are vertically aligned to middle
        overlay:setDimension(self.iconSizeX, self.iconSizeY)
        overlay:setColor(unpack(self.buttonColor))
        overlay:render(clipX1, clipY1, clipX2, clipY2)

        overlay:resetDimensions()

        local padding = i < #buttonOverlays and self.glyphOffsetX or 0
        posX = posX + self.iconSizeX + padding
    end

    return posX
end


---Draw keyboard key glyphs.
-- @param table Array of keyboard key names
-- @param float posX Initial drawing X position in screen space
-- @param float posY Initial drawing Y position in screen space
-- @return float X position in screen space after the last glyph
function InputGlyphElement:drawKeyboardKeys(keyNames, posX, posY, clipX1, clipY1, clipX2, clipY2)
    for i, key in ipairs(keyNames) do
        local padding = i < #keyNames and self.glyphOffsetX or 0
        posX = posX + self.keyboardOverlay:renderButton(key, posX, posY, self.iconSizeY, nil, true, clipX1, clipY1, clipX2, clipY2) + padding
    end

    return posX
end


---Draw the action text after the input glyphs.
-- @param float posX Drawing X position in screen space
-- @param float posY Drawing Y position in screen space
function InputGlyphElement:drawActionText(posX, posY, clipX1, clipY1, clipX2, clipY2)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(self.bold)
    setTextColor(unpack(self.color))

    if clipX1 ~= nil then
        setTextClipArea(clipX1, clipY1, clipX2, clipY2)
    end

    renderText(posX + self.textOffsetX, posY + self.actionTextSize * 0.5, self.actionTextSize, self.displayText)

    if clipX1 ~= nil then
        setTextClipArea(0, 0, 1, 1)
    end
end
