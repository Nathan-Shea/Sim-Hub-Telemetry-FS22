---Text display element
















































local TextElement_mt = Class(TextElement, GuiElement)





























---
function TextElement.new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = TextElement_mt
    end
    local self = GuiElement.new(target, custom_mt)

    self.textColor = {1, 1, 1, 1}
    self.textDisabledColor = {0.5, 0.5, 0.5, 1}
    self.textSelectedColor = {1, 1, 1, 1}
    self.textHighlightedColor = {1, 1, 1, 1}
    self.textOffset = {0,0}
    self.textFocusedOffset = {0,0}
    self.textSize = 0.03
    self.textBold = false
    self.textSelectedBold = false
    self.textHighlightedBold = false
    self.text2Color = {1, 1, 1, 1}
    self.text2DisabledColor = {1, 1, 1, 0}
    self.text2SelectedColor = {0, 0, 0, 0.5}
    self.text2HighlightedColor = {0, 0, 0, 0.5}
    self.text2Offset = {0,0}
    self.text2FocusedOffset = {0,0}
    self.text2Size = 0
    self.text2Bold = false
    self.text2SelectedBold = false
    self.text2HighlightedBold = false
    self.textUpperCase = false
    self.textLinesPerPage = 0
    self.currentPage = 1
    self.defaultTextSize = self.textSize
    self.defaultText2Size = self.text2Size
    self.textLineHeightScale = RenderText.DEFAULT_LINE_HEIGHT_SCALE
    self.text = ""
    self.textAlignment = RenderText.ALIGN_CENTER
    self.textVerticalAlignment = TextElement.VERTICAL_ALIGNMENT.MIDDLE
    self.ignoreDisabled = false

    self.format = TextElement.FORMAT.NONE
    self.locaKey = nil
    self.value = nil
    self.formatDecimalPlaces = 0

    self.textMaxWidth = nil -- no limit, thus size limited
    self.textMinWidth = 0
    self.textMaxNumLines = 1 -- just one line by default
    self.textAutoWidth = false -- no auto sizing of the element
    self.textLayoutMode = TextElement.LAYOUT_MODE.TRUNCATE -- hide any overflow
    self.textMinSize = 0.01

    self.sourceText = ""

    return self
end


---
function TextElement:loadFromXML(xmlFile, key)
    TextElement:superClass().loadFromXML(self, xmlFile, key)

    local xmlFilename = getXMLFilename(xmlFile)
    local modName, _ = Utils.getModNameAndBaseDirectory(xmlFilename)
    if modName ~= nil then
        self.customEnvironment = modName
    end

    self.textColor = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#textColor"), self.textColor)
    self.textSelectedColor = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#textSelectedColor"), self.textSelectedColor)
    self.text2SelectedColor = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#text2SelectedColor"), self.text2SelectedColor)
    self.textHighlightedColor = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#textHighlightedColor"), self.textHighlightedColor)
    self.text2HighlightedColor = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#text2HighlightedColor"), self.text2HighlightedColor)
    self.textDisabledColor = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#textDisabledColor"), self.textDisabledColor)
    self.text2DisabledColor = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#text2DisabledColor"), self.text2DisabledColor)
    self.text2Color = GuiUtils.getColorArray(getXMLString(xmlFile, key.."#text2Color"), self.text2Color)

    self.textOffset = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#textOffset"), self.outputSize, self.textOffset)
    self.textFocusedOffset = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#textFocusedOffset"), self.outputSize, self.textFocusedOffset)
    self.text2Offset = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#text2Offset"), self.outputSize, self.text2Offset)
    self.text2FocusedOffset = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#text2FocusedOffset"), self.outputSize, self.text2FocusedOffset)
    self.textSize = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#textSize"), {self.outputSize[2]}, {self.textSize}))
    self.text2Size = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#text2Size"), {self.outputSize[2]}, {self.text2Size}))

    self.textBold = Utils.getNoNil(getXMLBool(xmlFile, key.."#textBold"), self.textBold)
    self.textSelectedBold = Utils.getNoNil(getXMLBool(xmlFile, key.."#textSelectedBold"), self.textSelectedBold)
    self.textHighlightedBold = Utils.getNoNil(getXMLBool(xmlFile, key.."#textHighlightedBold"), self.textHighlightedBold)
    self.textUpperCase = Utils.getNoNil(getXMLBool(xmlFile, key.."#textUpperCase"), self.textUpperCase)
    self.text2Bold = Utils.getNoNil(getXMLBool(xmlFile, key.."#text2Bold"), self.text2Bold)
    self.text2SelectedBold = Utils.getNoNil(getXMLBool(xmlFile, key.."#text2SelectedBold"), self.text2SelectedBold)
    self.text2HighlightedBold = Utils.getNoNil(getXMLBool(xmlFile, key.."#text2HighlightedBold"), self.text2HighlightedBold)
    self.textLinesPerPage = Utils.getNoNil(getXMLInt(xmlFile, key.."#textLinesPerPage"), self.textLinesPerPage)
    self.textLineHeightScale = Utils.getNoNil(getXMLFloat(xmlFile, key.."#textLineHeightScale"), self.textLineHeightScale)

    self.defaultTextSize = self.textSize
    self.defaultText2Size = self.text2Size

    self.textMaxWidth = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#textMaxWidth"), {self.outputSize[1]}, {self.textMaxWidth}))
    self.textMinWidth = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#textMinWidth"), {self.outputSize[1]}, {self.textMinWidth}))
    self.textMaxNumLines = Utils.getNoNil(getXMLInt(xmlFile, key.."#textMaxNumLines"), self.textMaxNumLines)
    self.textAutoWidth = Utils.getNoNil(getXMLBool(xmlFile, key .."#textAutoWidth"), self.textAutoWidth)
    self.textMinSize = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#textMinSize"), {self.outputSize[2]}, {self.textMinSize}))

    local wrapModeKey = getXMLString(xmlFile, key .. "#textLayoutMode")
    if wrapModeKey ~= nil then
        wrapModeKey = wrapModeKey:lower()
        if wrapModeKey == "truncate" then
            self.textLayoutMode = TextElement.LAYOUT_MODE.TRUNCATE
        elseif wrapModeKey == "resize" then
            self.textLayoutMode = TextElement.LAYOUT_MODE.RESIZE
        elseif wrapModeKey == "overflow" then
            self.textLayoutMode = TextElement.LAYOUT_MODE.OVERFLOW
        end
    end

    local textAlignment = getXMLString(xmlFile, key.."#textAlignment")
    if textAlignment ~= nil then
        textAlignment = textAlignment:lower()
        if textAlignment == "right" then
            self.textAlignment = RenderText.ALIGN_RIGHT
        elseif textAlignment == "center" then
            self.textAlignment = RenderText.ALIGN_CENTER
        else
            self.textAlignment = RenderText.ALIGN_LEFT
        end
    end

    local textVerticalAlignment = getXMLString(xmlFile, key .. "#textVerticalAlignment") or ""
    local verticalAlignKey = string.upper(textVerticalAlignment)
    self.textVerticalAlignment = TextElement.VERTICAL_ALIGNMENT[verticalAlignKey] or self.textVerticalAlignment

    self.ignoreDisabled = Utils.getNoNil(getXMLBool(xmlFile, key.."#ignoreDisabled"), self.ignoreDisabled)

    local text = getXMLString(xmlFile, key.."#text")
    if Platform.isConsole then
        local textConsole = getXMLString(xmlFile, key.."#textConsole")
        if textConsole ~= nil then
            text = textConsole
        end
    end
    if text ~= nil then
        local addColon = false
        local length = text:len()
        if text:sub(length, length + 1) == ":" then
            text = text:sub(1, length - 1)
            addColon = true
        end
        if text:sub(1,6) == "$l10n_" then
            text = g_i18n:getText(text:sub(7), self.customEnvironment)
        end
        if addColon and text ~= "" then
            text = text .. ":"
        end

        self.sourceText = text

        -- Otherwise this overrides the formatting as XML is loaded after profiles
        if self.format == TextElement.FORMAT.NONE then
            self:setText(text, false, true)
        end
    end

    self.formatDecimalPlaces = math.max(Utils.getNoNil(getXMLInt(xmlFile, key.."#formatDecimalPlaces"), self.formatDecimalPlaces), 0)
    local format = getXMLString(xmlFile, key.."#format")
    if format ~= nil then
        format = format:lower()
        local f = TextElement.FORMAT.NONE
        if format == "currency" then
            f = TextElement.FORMAT.CURRENCY
        elseif format == "accounting" then
            f = TextElement.FORMAT.ACCOUNTING
        elseif format == "temperature" then
            f = TextElement.FORMAT.TEMPERATURE
        elseif format == "number" then
            f = TextElement.FORMAT.NUMBER
        elseif format == "percentage" then
            f = TextElement.FORMAT.PERCENTAGE
        elseif format == "none" then
            f = TextElement.FORMAT.NONE
        end
        self:setFormat(f)
    end

    self:addCallback(xmlFile, key.."#onTextChanged", "onTextChangedCallback")
    self:updateSize()
end


---
function TextElement:loadProfile(profile, applyProfile)
    TextElement:superClass().loadProfile(self, profile, applyProfile)

    self.textColor = GuiUtils.getColorArray(profile:getValue("textColor"), self.textColor)
    self.textSelectedColor = GuiUtils.getColorArray(profile:getValue("textSelectedColor"), self.textSelectedColor)
    self.textHighlightedColor = GuiUtils.getColorArray(profile:getValue("textHighlightedColor"), self.textHighlightedColor)
    self.textDisabledColor = GuiUtils.getColorArray(profile:getValue("textDisabledColor"), self.textDisabledColor)
    self.text2Color = GuiUtils.getColorArray(profile:getValue("text2Color"), self.text2Color)
    self.text2SelectedColor = GuiUtils.getColorArray(profile:getValue("text2SelectedColor"), self.text2SelectedColor)
    self.text2HighlightedColor = GuiUtils.getColorArray(profile:getValue("text2HighlightedColor"), self.text2HighlightedColor)
    self.text2DisabledColor = GuiUtils.getColorArray(profile:getValue("text2DisabledColor"), self.text2DisabledColor)

    self.textSize = unpack(GuiUtils.getNormalizedValues(profile:getValue("textSize"), {self.outputSize[2]}, {self.textSize}))
    self.textOffset = GuiUtils.getNormalizedValues(profile:getValue("textOffset"), self.outputSize, self.textOffset)
    self.textFocusedOffset = GuiUtils.getNormalizedValues(profile:getValue("textFocusedOffset"), self.outputSize, {self.textOffset[1], self.textOffset[2]})
    self.text2Size = unpack(GuiUtils.getNormalizedValues(profile:getValue("text2Size"), {self.outputSize[2]}, {self.text2Size}))
    self.text2Offset = GuiUtils.getNormalizedValues(profile:getValue("text2Offset"), self.outputSize, self.text2Offset)
    self.text2FocusedOffset = GuiUtils.getNormalizedValues(profile:getValue("text2FocusedOffset"), self.outputSize, {self.text2Offset[1], self.text2Offset[2]})

    self.textBold = profile:getBool("textBold", self.textBold)
    self.textSelectedBold = profile:getBool("textSelectedBold", self.textSelectedBold)
    self.textHighlightedBold = profile:getBool("textHighlightedBold", self.textHighlightedBold)
    self.text2Bold = profile:getBool("text2Bold", self.text2Bold)
    self.text2SelectedBold = profile:getBool("text2SelectedBold", self.text2SelectedBold)
    self.text2HighlightedBold = profile:getBool("text2HighlightedBold", self.text2HighlightedBold)
    self.textUpperCase = profile:getBool("textUpperCase", self.textUpperCase)
    self.textLinesPerPage = profile:getNumber("textLinesPerPage", self.textLinesPerPage)

    self.textLineHeightScale = profile:getNumber("textLineHeightScale", self.textLineHeightScale)

    self.textMaxWidth = unpack(GuiUtils.getNormalizedValues(profile:getValue("textMaxWidth"), {self.outputSize[1]}, {self.textMaxWidth}))
    self.textMinWidth = unpack(GuiUtils.getNormalizedValues(profile:getValue("textMinWidth"), {self.outputSize[1]}, {self.textMinWidth}))
    self.textMaxNumLines = profile:getNumber("textMaxNumLines", self.textMaxNumLines)
    self.textAutoWidth = profile:getBool("textAutoWidth", self.textAutoWidth)
    self.textMinSize = unpack(GuiUtils.getNormalizedValues(profile:getValue("textMinSize"), {self.outputSize[2]}, {self.textMinSize}))

    self.defaultTextSize = self.textSize
    self.defaultText2Size = self.text2Size

    local wrapModeKey = profile:getValue("textLayoutMode")
    if wrapModeKey ~= nil then
        wrapModeKey = wrapModeKey:lower()
        if wrapModeKey == "truncate" then
            self.textLayoutMode = TextElement.LAYOUT_MODE.TRUNCATE
        elseif wrapModeKey == "resize" then
            self.textLayoutMode = TextElement.LAYOUT_MODE.RESIZE
        elseif wrapModeKey == "overflow" then
            self.textLayoutMode = TextElement.LAYOUT_MODE.OVERFLOW
        end
    end

    self.ignoreDisabled = profile:getBool("ignoreDisabled", self.ignoreDisabled)

    local textAlignment = profile:getValue("textAlignment")
    if textAlignment ~= nil then
        textAlignment = textAlignment:lower()
        if textAlignment == "right" then
            self.textAlignment = RenderText.ALIGN_RIGHT
        elseif textAlignment == "center" then
            self.textAlignment = RenderText.ALIGN_CENTER
        else
            self.textAlignment = RenderText.ALIGN_LEFT
        end
    end

    local textVerticalAlignment = profile:getValue("textVerticalAlignment", "")
    local verticalAlignKey = string.upper(textVerticalAlignment)
    self.textVerticalAlignment = TextElement.VERTICAL_ALIGNMENT[verticalAlignKey] or self.textVerticalAlignment

    self.formatDecimalPlaces = math.max(profile:getNumber("formatDecimalPlaces", self.formatDecimalPlaces), 0)
    local format = profile:getValue("format")

    if format ~= nil then
        format = format:lower()
        local f = TextElement.FORMAT.NONE
        if format == "currency" then
            f = TextElement.FORMAT.CURRENCY
        elseif format == "accounting" then
            f = TextElement.FORMAT.ACCOUNTING
        elseif format == "temperature" then
            f = TextElement.FORMAT.TEMPERATURE
        elseif format == "number" then
            f = TextElement.FORMAT.NUMBER
        elseif format == "percentage" then
            f = TextElement.FORMAT.PERCENTAGE
        elseif format == "none" then
            f = TextElement.FORMAT.NONE
        end
        self:setFormat(f)
    end

    if applyProfile then
        self:applyTextAspectScale()
        self:updateSize()
    end
end


---
function TextElement:copyAttributes(src)
    TextElement:superClass().copyAttributes(self, src)
    self.text  = src.text
    self.format = src.format
    self.locaKey = src.locaKey
    self.value = src.value
    self.formatDecimalPlaces = src.formatDecimalPlaces
    self.sourceText = src.sourceText

    self.textColor = table.copy(src.textColor)
    self.textSelectedColor = table.copy(src.textSelectedColor)
    self.textHighlightedColor = table.copy(src.textHighlightedColor)
    self.textDisabledColor = table.copy(src.textDisabledColor)
    self.text2Color = table.copy(src.text2Color)
    self.text2SelectedColor = table.copy(src.text2SelectedColor)
    self.text2HighlightedColor = table.copy(src.text2HighlightedColor)
    self.text2DisabledColor = table.copy(src.text2DisabledColor)
    self.textSize = src.textSize
    self.textOffset = table.copy(src.textOffset)
    self.textFocusedOffset = table.copy(src.textFocusedOffset)
    self.text2Size = src.text2Size
    self.text2Offset = table.copy(src.text2Offset)
    self.text2FocusedOffset = table.copy(src.text2FocusedOffset)
    self.ignoreDisabled = src.ignoreDisabled

    self.textMaxWidth = src.textMaxWidth
    self.textMinWidth = src.textMinWidth
    self.textMaxNumLines = src.textMaxNumLines
    self.textAutoWidth = src.textAutoWidth
    self.textLayoutMode = src.textLayoutMode
    self.textMinSize = src.textMinSize

    self.textBold = src.textBold
    self.textSelectedBold = src.textSelectedBold
    self.textHighlightedBold = src.textHighlightedBold
    self.text2Bold = src.text2Bold
    self.text2SelectedBold = src.text2SelectedBold
    self.text2HighlightedBold = src.text2HighlightedBold
    self.textUpperCase = src.textUpperCase
    self.textLinesPerPage = src.textLinesPerPage
    self.textAlignment = src.textAlignment
    self.currentPage = src.currentPage
    self.defaultTextSize = src.defaultTextSize
    self.defaultText2Size = src.defaultText2Size
    self.textLineHeightScale = src.textLineHeightScale
    self.textVerticalAlignment = src.textVerticalAlignment

    self.onTextChangedCallback = src.onTextChangedCallback
end


---
function TextElement:delete()
    g_messageCenter:unsubscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_FAHRENHEIT], self)
    g_messageCenter:unsubscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.MONEY_UNIT], self)

    TextElement:superClass().delete(self)
end


---
function TextElement:setTextSize(size)
    self.textSize = size
    self:updateSize()
end


---
function TextElement:applyTextAspectScale()
    local xScale, yScale = self:getAspectScale()

    self.textOffset[1] = self.textOffset[1] * xScale
    self.textFocusedOffset[1] = self.textFocusedOffset[1] * xScale
    self.text2Offset[1] = self.text2Offset[1] * xScale
    self.text2FocusedOffset[1] = self.text2FocusedOffset[1] * xScale

    if self.textMaxWidth ~= nil then
        self.textMaxWidth = self.textMaxWidth * xScale
    end
    if self.textMinWidth ~= nil then
        self.textMinWidth = self.textMinWidth * xScale
    end

    self.defaultTextSize = self.defaultTextSize * yScale
    self.defaultText2Size = self.defaultText2Size * yScale
    self.textSize = self.textSize * yScale
    self.textMinSize = self.textMinSize * yScale
    self.text2Size = self.text2Size * yScale
    self.textOffset[2] = self.textOffset[2] * yScale
    self.textFocusedOffset[2] = self.textFocusedOffset[2] * yScale
    self.text2Offset[2] = self.text2Offset[2] * yScale
    self.text2FocusedOffset[2] = self.text2FocusedOffset[2] * yScale

    self.didApplyAspectScaling = true

    self:updateScaledWidth(xScale, yScale)
end


---
function TextElement:applyScreenAlignment()
    self:applyTextAspectScale()

    TextElement:superClass().applyScreenAlignment(self)
end


---Update text after size changes
function TextElement:updateAbsolutePosition()
    TextElement:superClass().updateAbsolutePosition(self)

    if (self.textMaxNumLines ~= 1 or self.textLayoutMode ~= TextElement.LAYOUT_MODE.OVERFLOW) and not self.textAutoWidth then
        self:setTextInternal(self.sourceText, nil, true)
    end
end


---Set text
-- @return string leftover part of the string if textMaxNumLines is set
function TextElement:setText(text, forceTextSize, isInitializing)
    -- Reset so it is not overwritten
    self.locaKey = nil
    self.value = nil
    self.format = TextElement.FORMAT.NONE

    self:setTextInternal(text, forceTextSize, isInitializing)
end


---Internal call for setting text
function TextElement:setTextInternal(text, forceTextSize, skipCallback, doNotUpdateSize)
    if text == nil then
        text = ""
    end

    text = tostring(text)

    -- Save the original text in case any text properties change
    local textHasChanged = self.sourceText ~= text
    if self.textUpperCase then
        text = utf8ToUpper(text)
    end
    self.sourceText = text

    -- Reset to original size before resizing again
    self.textSize = self.defaultTextSize
    self.text2Size = self.defaultText2Size

    self:updateSize()

    local maxWidth = self.absSize[1]
    if self.textMaxWidth ~= nil then
        maxWidth = self.textMaxWidth
    elseif self.textAutoWidth then
        maxWidth = 1
    end

    local limitVerticalLines = false

    setTextBold(self.textBold)

    if self.textLayoutMode == TextElement.LAYOUT_MODE.RESIZE then
        -- Wrap at max length
        setTextWrapWidth(maxWidth)

        local textMaxNumLines = self.textMaxNumLines
        -- Breaking is not possible on spaces
        if text:find("[ -]") == nil then
            textMaxNumLines = 1
        end

        -- Then find how long the max line would be
        local lengthWithNoLineLimit = getTextLength(self.textSize, text, 99999)

        -- We want to fully fit inside, so our final length must be <= our max length
        while getTextLength(self.textSize, text, textMaxNumLines) < lengthWithNoLineLimit do
            self.textSize = self.textSize - self.defaultTextSize * 0.05
            self.text2Size = self.text2Size - self.defaultText2Size * 0.05

            -- Limit size. Cut off any extra text
            if self.textSize <= self.textMinSize then
                -- Undo
                self.textSize = self.textSize + self.defaultTextSize * 0.05
                self.text2Size = self.text2Size + self.defaultText2Size * 0.05

                if textMaxNumLines == 1 then
                    text = Utils.limitTextToWidth(text, self.textSize, maxWidth, false, "...")
                else
                    limitVerticalLines = true
                end

                break
            end
        end

        setTextWrapWidth(0)
    elseif self.textLayoutMode == TextElement.LAYOUT_MODE.OVERFLOW then -- luacheck: ignore
        -- Note: with textMaxNumLines set, it overflows vertically instead of horizontally
    elseif self.textLayoutMode == TextElement.LAYOUT_MODE.TRUNCATE then
        -- We need to find a fitting amount of text for the width and max num lines
        -- Engine tools don't provide max num lines so we do it by hand

        -- Fast case: use engine
        if self.textMaxNumLines == 1 then
            text = Utils.limitTextToWidth(text, self.textSize, maxWidth, false, "...")
        else
            limitVerticalLines = true
        end
    end

    if limitVerticalLines then
        -- for limiting vertically with num lines and wrap
        -- local leftover = nil
        -- if self.textMaxNumLines ~= nil and self.textWrapWidth ~= nil then
        --     setTextWrapWidth(self.textWrapWidth)
        --     local l = getTextLength(self.textSize, text, self.textMaxNumLines)
        --     setTextWrapWidth(0)
        --     leftover = utf8Substr(text, l)
        --     text = utf8Substr(text, 0, l)
        -- end
        -- Check for too-many first
        setTextWrapWidth(maxWidth)
        local _, numLines = getTextHeight(self.textSize, text)

        if numLines > self.textMaxNumLines then
            while true do
                _, numLines = getTextHeight(self.textSize, text)
                if numLines > self.textMaxNumLines then
                    text = utf8Substr(text, 0, utf8Strlen(text) - 1)
                else
                    break
                end
            end

            -- Add ellipsis
            text = utf8Substr(text, 0, math.max(utf8Strlen(text) - 3, 0)) .. "..."
        end

        setTextWrapWidth(0)
    end

    setTextBold(false)

    self.text = text

    if textHasChanged and not skipCallback then
        self:raiseCallback("onTextChangedCallback", self, self.text)
        self:updateScaledWidth(1, 1)
    end

    self:updateSize(forceTextSize)

    return ""
end


---Get text
function TextElement:getText()
    return self.sourceText
end


---Set value to format. Overrides text
function TextElement:setValue(value)
    self.value = value
    self:updateFormattedText()
end


---Get the value
function TextElement:getValue()
    return self.value
end


---Set a new formatter
function TextElement:setFormat(format)
    if format == nil then
        format = TextElement.FORMAT.NONE
    end

    if self.format ~= format then
        -- Unsubscribe for previous format
        if self.format == TextElement.FORMAT.TEMPERATURE then
            g_messageCenter:unsubscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_FAHRENHEIT], self)
        elseif format == TextElement.FORMAT.CURRENCY or format == TextElement.FORMAT.ACCOUNTING then
            g_messageCenter:unsubscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.MONEY_UNIT], self)
        end

        self.format = format
        self:updateFormattedText()

        -- Subscribe to setting changes for the new format
        if format == TextElement.FORMAT.TEMPERATURE then
            g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_FAHRENHEIT], self.onFormatUnitChanged, self)
        elseif format == TextElement.FORMAT.CURRENCY or format == TextElement.FORMAT.ACCOUNTING then
            g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.MONEY_UNIT], self.onFormatUnitChanged, self)
        end
    end
end


---Set a loca key to show the text of
function TextElement:setLocaKey(key)
    self.locaKey = key
    self.format = TextElement.FORMAT.NONE
    self.value = nil
    self:updateFormattedText()
end


---Update the formatted text after value or formatter changed
function TextElement:updateFormattedText()
    local text = ""

    local value = self.value
    if value ~= nil then
        local format = self.format

        local decimalPlaces = self.formatDecimalPlaces

        if format == TextElement.FORMAT.NONE then
            text = tostring(value)
        elseif format == TextElement.FORMAT.NUMBER then
            text = g_i18n:formatNumber(value, decimalPlaces)
        elseif format == TextElement.FORMAT.CURRENCY then
            text = g_i18n:formatMoney(value, decimalPlaces, true, true)
        elseif format == TextElement.FORMAT.ACCOUNTING then
            text = g_i18n:formatMoney(value, decimalPlaces, true, false)
        elseif format == TextElement.FORMAT.TEMPERATURE then
            text = g_i18n:formatTemperature(value, decimalPlaces)
        elseif format == TextElement.FORMAT.PERCENTAGE then
            text = g_i18n:formatNumber(value * 100, decimalPlaces) .. "%"
        end
    elseif self.locaKey ~= nil then
        local length = self.locaKey:len()

        if self.locaKey:sub(length, length + 1) == ":" then
            text = g_i18n:getText(self.locaKey:sub(1, length - 1), self.customEnvironment) .. ":"
        else
            text = g_i18n:getText(self.locaKey, self.customEnvironment)
        end
    end

    self:setTextInternal(text)
end







---Set text color
function TextElement:setTextColor(r,g,b,a)
    self.textColor = {r,g,b,a}
end


---Set text selected color
function TextElement:setTextSelectedColor(r,g,b,a)
    self.textSelectedColor = {r,g,b,a}
end


---Set text highlighted color
function TextElement:setTextHighlightedColor(r, g, b, a)
    self.textHighlightedColor = {r, g, b, a}
end


---Get text color
function TextElement:getTextColor()
    if self.disabled and not self.ignoreDisabled then
        return self.textDisabledColor
    elseif self:getIsSelected() then
        return self.textSelectedColor
    elseif self:getIsHighlighted() then
        return self.textHighlightedColor
    else
        return self.textColor
    end
end


---Set text 2 color
function TextElement:setText2Color(r,g,b,a)
    self.text2Color = {r,g,b,a}
end


---Set text 2 selected color
function TextElement:setText2SelectedColor(r,g,b,a)
    self.text2SelectedColor = {r,g,b,a}
end


---Set text 2 highlighted color
function TextElement:setText2HighlightedColor(r,g,b,a)
    self.text2HighlightedColor = {r,g,b,a}
end


---Get text 2 color
function TextElement:getText2Color()
    if self.disabled and not self.ignoreDisabled then
        return self.text2DisabledColor
    elseif self:getIsSelected() then
        return self.text2SelectedColor
    elseif self:getIsHighlighted() then
        return self.text2HighlightedColor
    else
        return self.text2Color
    end
end



---Get text width
function TextElement:getTextWidth()
    setTextBold(self.textBold)
    local width = getTextWidth(self.textSize, self.text)
    setTextBold(false)

    -- When not overflowing, limit size to element
    if self.textLayoutMode ~= TextElement.LAYOUT_MODE.OVERFLOW then
        width = math.min(width, self.absSize[1])
    end

    return width
end


---Get text height
function TextElement:getTextHeight(includeNegativeSpacing)
    -- Only wrap when having more than 1 line available
    if self.textMaxNumLines > 1 then
        setTextWrapWidth(self.absSize[1])
    end
    setTextBold(self.textBold)
    setTextLineHeightScale(self.textLineHeightScale)

    local height, numLines = getTextHeight(self.textSize, self.text)

    -- inlcude negative height for letters like 'g', 'y' or 'j'
    if includeNegativeSpacing == true and numLines > 0 then
        height = height + (height / numLines) * 0.1
    end

    setTextLineHeightScale(RenderText.DEFAULT_LINE_HEIGHT_SCALE)
    setTextBold(false)
    setTextWrapWidth(0)
    return height, numLines
end


---Get text offset
function TextElement:getTextOffset()
    local xOffset, yOffset = self.textOffset[1], self.textOffset[2]
    local state = self:getOverlayState()
    if state == GuiOverlay.STATE_FOCUSED or state == GuiOverlay.STATE_PRESSED or state == GuiOverlay.STATE_SELECTED or state == GuiOverlay.STATE_HIGHLIGHTED then
        xOffset = self.textFocusedOffset[1]
        yOffset = self.textFocusedOffset[2]
    end
    return xOffset, yOffset
end


---Get text 2 offset
function TextElement:getText2Offset()
    local xOffset, yOffset = self.text2Offset[1], self.text2Offset[2]
    local state = self:getOverlayState()
    if state == GuiOverlay.STATE_FOCUSED or state == GuiOverlay.STATE_PRESSED or state == GuiOverlay.STATE_SELECTED or state == GuiOverlay.STATE_HIGHLIGHTED then
        xOffset = self.text2FocusedOffset[1]
        yOffset = self.text2FocusedOffset[2]
    end
    return xOffset, yOffset
end


---
function TextElement:getDoRenderText()
    return true
end


---Get text position x
function TextElement:getTextPositionX()
    local xPos = self.absPosition[1]
    if self.textAlignment == RenderText.ALIGN_CENTER then
        xPos = xPos + (self.absSize[1] * 0.5)
    elseif self.textAlignment == RenderText.ALIGN_RIGHT then
        xPos = xPos + self.absSize[1]
    end
    return xPos
end


---
function TextElement:getTextPositionY(lineHeight, totalHeight)
    local yPos = self.absPosition[2]

    if self.textVerticalAlignment == TextElement.VERTICAL_ALIGNMENT.TOP then
        yPos = yPos + self.absSize[2] - lineHeight
    elseif self.textVerticalAlignment == TextElement.VERTICAL_ALIGNMENT.MIDDLE then
        yPos = yPos + (self.absSize[2] + totalHeight) * 0.5 - lineHeight
    else
        yPos = yPos + totalHeight - lineHeight
    end

    return yPos
end












---
function TextElement:draw(clipX1, clipY1, clipX2, clipY2)
    if self:getDoRenderText() then
        if self.text ~= nil and self.text ~= "" then

            if clipX1 ~= nil then
                setTextClipArea(clipX1, clipY1, clipX2, clipY2)
            end

            setTextAlignment(self.textAlignment)

            local maxWidth = self.absSize[1]
            if self.textMaxWidth ~= nil then
                maxWidth = self.textMaxWidth
            end

            if self.textMaxNumLines > 1 then
                setTextWrapWidth(maxWidth)
            end

            setTextLineBounds((self.currentPage - 1) * self.textLinesPerPage, self.textLinesPerPage)
            setTextLineHeightScale(self.textLineHeightScale)

            local text = self.text

            local bold = self.textBold or (self.textSelectedBold and self:getIsSelected() or (self.textHighlightedBold and self:getIsHighlighted()))
            setTextBold(bold)

            local xPos, yPos = self:getTextPosition(text)

            -- The rendering engine works as follows:
            -- The text size is from baseline to above the umlaut of a capital. This causes
            -- very weird vertical alignment. We are going to adjust this by drawing our text
            -- vertically based on xheight+ascending. The engine does not provide this info,
            -- because we are drawing simple bitmap fonts.
            -- and there is only 1 font, so instead these values are using pixel counting.
            -- For fonts of size 20, we offset on Y for 2px. It is proportional so we scale it.
            local baselineOffset = self.textSize * 0.1
            yPos = yPos + baselineOffset

            if self.text2Size > 0 then
                local x2Offset, y2Offset = self:getText2Offset()
                bold = self.text2Bold or (self.text2SelectedBold and self:getIsSelected()) or (self.text2HighlightedBold and self:getIsHighlighted())
                setTextBold(bold)
                local r,g,b,a = unpack(self:getText2Color())
                setTextColor(r,g,b,a*self.alpha)
                renderText(xPos + x2Offset, yPos + y2Offset, self.text2Size, text)
            end

            local r,g,b,a = unpack(self:getTextColor())
            setTextColor(r,g,b,a*self.alpha)

            local xOffset, yOffset = self:getTextOffset()
            renderText(xPos + xOffset, yPos + yOffset, self.textSize, text)

            -- TODO: apply engine vertical text alignment as soon as it's exposed to script
            setTextBold(false)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextLineHeightScale(RenderText.DEFAULT_LINE_HEIGHT_SCALE)
            setTextColor(1, 1, 1, 1)
            setTextLineBounds(0, 0)
            setTextWrapWidth(0)

            if clipX1 ~= nil then
                setTextClipArea(0, 0, 1, 1)
            end

            if self.debugEnabled or g_uiDebugEnabled then
                if self.textMaxWidth ~= nil then
                    local yPixel = 1 / g_screenHeight
                    setOverlayColor(GuiElement.debugOverlay, 0, 0, 0, 1)

                    local x = xPos + xOffset
                    if self.textAlignment == RenderText.ALIGN_RIGHT then
                        x = x - self.textMaxWidth
                    elseif self.textAlignment == RenderText.ALIGN_CENTER then
                        x = x - self.textMaxWidth / 2
                    end

                    renderOverlay(GuiElement.debugOverlay, x, yPos + yOffset, self.textMaxWidth, yPixel)
                end

                local width = self:getTextWidth()
                local x = xPos + xOffset
                if self.textAlignment == RenderText.ALIGN_RIGHT then
                    x = x - width
                elseif self.textAlignment == RenderText.ALIGN_CENTER then
                    x = x - width * 0.5
                end

                -- Baseline
                setOverlayColor(GuiElement.debugOverlay, 0, 1, 0, 1)
                renderOverlay(GuiElement.debugOverlay, x, yPos + yOffset, width, 1 / g_screenHeight)
                -- xHeight
                setOverlayColor(GuiElement.debugOverlay, 1, 0.5, 0, 1)
                renderOverlay(GuiElement.debugOverlay, x, yPos + yOffset + getTextHeight(self.textSize, text) * 0.5, width, 1 / g_screenHeight)
                -- Ascending
                setOverlayColor(GuiElement.debugOverlay, 0, 0, 1, 1)
                renderOverlay(GuiElement.debugOverlay, x, yPos + yOffset + getTextHeight(self.textSize, text) * 0.75, width, 1 / g_screenHeight)
            end
        end
    end
    TextElement:superClass().draw(self, clipX1, clipY1, clipX2, clipY2)
end


---Update a zero-size text element width to its text width.
-- @param float xScale Aspect ratio x scale
function TextElement:updateScaledWidth(xScale)
    if self.text ~= nil and self.text ~= "" and self.absSize[1] == 0 and self.absSize[2] == 0 then
        local width = self:getTextWidth()
        -- TODO
        -- if self.textWrapWidth > 0 then
        --     width = math.min(width, self.textWrapWidth)
        -- end

        -- compensate pre-scaled width with xScale
        self:setSize(width / xScale, self.textSize)
    end
end


---Update the size of the element depending on the contents
function TextElement:updateSize(forceTextSize)
    -- Only update when auto width is enabled and max lines is 1
    if (not self.textAutoWidth or self.textMaxNumLines ~= 1) and forceTextSize ~= true then
        return
    end

    local offset = self:getTextOffset()

    -- We need to manually apply aspect scaling because element size is not updated
        -- This is a bit of a hack... the aspect scaling at all is quite a hack.
    local textSize = self.textSize
    local xScale, yScale = self:getAspectScale()
    -- if not self.didApplyAspectScaling then
    --     textSize = textSize * yScale
    -- end

    -- Get width using the source text, as the element is supposed to fit all text (as
    -- textAutoWidth is enabled and max lines is 1)
    setTextBold(self.textBold)
    local textWidth = getTextWidth(textSize, self.sourceText)
    setTextBold(false)

    -- Limit element to max width
    if self.textMaxWidth ~= nil then
        textWidth = math.min(self.textMaxWidth, textWidth)
    end
    if self.textMinWidth ~= nil then
        textWidth = math.max(self.textMinWidth, textWidth)
    end

    local width = offset + textWidth
    if width ~= self.size[1] then
        local height = nil
        if self.size[2] == 0 then
            height = self.textSize
        end
        self:setSize(width, height)

        -- We need to manually apply aspect scaling because element size is not updated
        -- This is a bit of a hack... the aspect scaling at all is quite a hack.
        if not self.didApplyAspectScaling then
            local xScale, yScale = self:getAspectScale()
            width = width / xScale
        end

        self:setSize(width, height) -- do not overwrite height

        if self.parent ~= nil and self.parent.invalidateLayout ~= nil and self.parent.autoValidateLayout then
            self.parent:invalidateLayout()
        end
    end
end
