---Display
--HUD input help display.
--
--Displays controls and further information for the current input context.








local InputHelpDisplay_mt = Class(InputHelpDisplay, HUDDisplayElement)












---Create a new instance of InputHelpDisplay.
-- @param string hudAtlasPath Path to the HUD texture atlas
function InputHelpDisplay.new(hudAtlasPath, messageCenter, inputManager, inputDisplayManager, ingameMap, communicationDisplay, ingameMessage, isConsoleVersion)
    local backgroundOverlay = InputHelpDisplay.createBackground()
    local self = InputHelpDisplay:superClass().new(backgroundOverlay, nil, InputHelpDisplay_mt)

    self.messageCenter = messageCenter
    self.inputManager = inputManager
    self.inputDisplayManager = inputDisplayManager
    self.ingameMap = ingameMap
    self.communicationDisplay = communicationDisplay
    self.ingameMessage = ingameMessage
    self.isConsoleVersion = isConsoleVersion

    self.isOverlayMenuVisible = false

    self.controlsLabelText = utf8ToUpper(g_i18n:getText(InputHelpDisplay.L10N_CONTROLS_LABEL))

    self.vehicle = nil -- currently controlled vehicle
    self.vehicleHudExtensions = {} -- known and active vehicle HUD extensions, specialization -> extension

    self.extraHelpTexts = {}
    self.extraExtensionVehicleNodeIds = {}  -- vehicle nodeIds to draw HUDExtensions for, which are not controlled by player
    self.currentAvailableHeight = 0

    self.comboInputGlyphs = {} -- actionName -> InputGlyphElement
    self.entries = {} -- array of HUDElement
    self.entryGlyphWidths = {} -- array of float -> synchronous with self.entries, stores the currently required glyph width
    self.inputGlyphs = {} -- array of InputGlyphElement, synchronous with self.entries
    self.horizontalSeparators = {} -- array of HUDElement
    self.frame = nil -- HUDFrameElement for the background frame
    self.entriesFrame = nil -- HUDElement which holds all help entries for repositioning
    self.mouseComboHeader = nil
    self.gamepadComboHeader = nil
    self.customHelpElements = {} -- array of InputHelpElement

    self.headerHeight = 0
    self.entryWidth, self.entryHeight = 0, 0
    self.controlsLabelTextSize = 0
    self.controlsLabelOffsetX, self.controlsLabelOffsetY = 0, 0
    self.helpTextSize = 0
    self.helpTextOffsetX, self.helpTextOffsetY = 0, 0
    self.extraTextOffsetX, self.extraTextOffsetY = 0, 0
    self.axisIconOffsetX = 0
    self.axisIconWidth, self.axisIconHeight = 0, 0
    self.frameOffsetX, self.frameOffsetY = 0, 0
    self.frameBarOffsetY = 0

    self.hasComboCommands = false
    self.visibleHelpElements = {} -- current frame help elements
    self.currentHelpElementCount = 0 -- maximum number of help elements which are currently active
    self.requireHudExtensionsRefresh = false
    self.numUsedEntries = 0 -- number of used entries in the current frame
    self.extensionsHeight = 0 -- screen height of active HUDExensions in the current frame
    self.extensionsStartY = 0 -- start Y position of vehicle extensions
    self.comboIterator = {}

    self.animationAvailableHeight = math.huge
    self.animationOffsetX = 0
    self.animationOffsetY = 0

    self.extensionBg = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    self.extensionBg:setUVs(g_colorBgUVs)
    self.extensionBg:setColor(0, 0, 0, 0.56)

    self:createComponents(hudAtlasPath)
    self:subscribeMessages()

    return self
end


---
function InputHelpDisplay:subscribeMessages()
    self.messageCenter:subscribe(MessageType.INPUT_DEVICES_CHANGED, self.onInputDevicesChanged, self)
end


---
function InputHelpDisplay:delete()
    self.messageCenter:unsubscribeAll(self)

    if self.frame ~= nil then
        self.frame:delete()
    end

    if self.extensionBg ~= nil then
        self.extensionBg:delete()
    end

    for k, hudExtension in pairs(self.vehicleHudExtensions) do
        hudExtension:delete()
        self.vehicleHudExtensions[k] = nil
    end

    InputHelpDisplay:superClass().delete(self)
end


---Add a help text line for this frame.
Will be cleared after the current frame.
function InputHelpDisplay:addHelpText(text)
    table.insert(self.extraHelpTexts, text)
end


---Add rootNode of vehicle to draw HUDExtension for which is not controlled by the player
using vehicle nodeId instead of vehicle itself to prevent reference leak
function InputHelpDisplay:addExtraExtensionVehicleNodeId(vehicleNodeId)
    if table.addElement(self.extraExtensionVehicleNodeIds, vehicleNodeId) then
        -- refresh if nodeId was not in list yet
        self.requireHudExtensionsRefresh = true
    end
end


---Remove rootNode of vehicle to draw HUDExtension for which is not controlled by the player
using vehicle nodeId instead of vehicle itself to prevent reference leak
function InputHelpDisplay:removeExtraExtensionVehicleNodeId(vehicleNodeId)
    if table.removeElement(self.extraExtensionVehicleNodeIds, vehicleNodeId) then
        -- refresh if nodeId was still in list
        self.requireHudExtensionsRefresh = true
    end
end


---Override of HUDDisplayElement.
Moves out to the left to hide.
function InputHelpDisplay:getHidingTranslation()
    return -0.5, 0
end


---Add a custom input help entry which is displayed in the current input context until removed.
Custom entries will be displayed in order of addition after any automatically detected input help entries and before
vehicle extensions.
function InputHelpDisplay:addCustomEntry(actionName1, actionName2, displayText, ignoreComboButtons)
    local entry = self.inputDisplayManager:getControllerSymbolOverlays(actionName1, actionName2, displayText, ignoreComboButtons)
    local contextName = self.inputManager:getContextName()
    local contextElements = self.customHelpElements[contextName]

    if contextElements == nil then
        contextElements = {}
        self.customHelpElements[contextName] = contextElements
    end

    table.insert(contextElements, entry)
end


---Clear all custom input help entries in the current context.
function InputHelpDisplay:clearCustomEntries()
    local contextElements = self.customHelpElements[self.inputManager:getContextName()]

    if contextElements ~= nil then
        for k in pairs(self.customHelpElements) do
            self.customHelpElements[k] = nil
        end
    end
end














---Set the currently controlled vehicle.
-- @param table vehicle Vehicle reference or nil if no vehicle is controlled.
function InputHelpDisplay:setVehicle(vehicle)
    self.vehicle = vehicle
    self.lastVehicleSpecHash = nil
    self.requireHudExtensionsRefresh = true
end


---Update the input help's state.
function InputHelpDisplay:update(dt)
    InputHelpDisplay:superClass().update(self, dt)

    if self:getVisible() then
        self:updateInputContext()
        self:updateHUDExtensions()

        if self.sizeAndPositionDirty then
            self:updateSizeAndPositions()
            self.sizeAndPositionDirty = false
        end

        clearTable(self.extraHelpTexts) -- clear current frame help texts, they have been copied already for drawing
    end

    if not self.animation:getFinished() then
        self:storeScaledValues()
        self.sizeAndPositionDirty = true
    end
end



---Update sizes and positions of this elements and its children.
function InputHelpDisplay:updateSizeAndPositions()
    local totalSize = 0--- self.frameOffsetY

    local baseX, baseTopY = self:getTopLeftPosition()
    local frameX, frameTopY = baseX + self.frameOffsetX, baseTopY + self.frameOffsetY
    local entriesHeight = self.entriesFrame:getHeight()
    local entriesPosY = frameTopY - entriesHeight

    if self.hasComboCommands then
        totalSize = totalSize + self.headerHeight
        entriesPosY = entriesPosY - self.headerHeight
    end

    totalSize = totalSize + self.numUsedEntries * self.entryHeight
    self.extensionsStartY = frameTopY - totalSize -- store the extensions starting Y position for drawing

    totalSize = totalSize + self.extensionsHeight

    self:setDimension(self:getWidth(), totalSize)
    self:setPosition(baseX, baseTopY - totalSize)

    if self:getVisible() and not self.animation:getFinished() then
        self:storeOriginalPosition()
    end

    -- need to adjust header positions to keep them anchored to top left
    self.mouseComboHeader:setPosition(frameX, frameTopY - self.headerHeight)
    self.gamepadComboHeader:setPosition(frameX, frameTopY - self.headerHeight)

    self.entriesFrame:setPosition(frameX, entriesPosY) -- moves up or down depending on header visibility
    local frameHeight = self:getHeight() + self.frameOffsetY + self.frameBarOffsetY
    self.frame:setPosition(frameX, frameTopY - frameHeight)
end


---Create any required HUD extensions when the current vehicle configuration changes.
function InputHelpDisplay:refreshHUDExtensions()
--#profile     g_remoteProfiler:ZoneBeginN(" InputHelpDisplay:refreshHUDExtensions")
    for k, hudExtension in pairs(self.vehicleHudExtensions) do
        hudExtension:delete()
        self.vehicleHudExtensions[k] = nil
    end

    local uiScale = self:getScale()

    local vehiclesAlreadyAdded = {}  -- keep track of vehicles for which HUDExtensions were already added to avoid duplicates

    local function addExtensionForVehicle(vehicle, drawableWhileNotActive)
        if vehiclesAlreadyAdded[vehicle] ~= nil then
            return
        end
        for j=1, #vehicle.specializations do
            local spec = vehicle.specializations[j]
            local hudExtension = self.vehicleHudExtensions[spec]
            if hudExtension == nil and VehicleHUDExtension.hasHUDExtensionForSpecialization(spec) then
                hudExtension = VehicleHUDExtension.createHUDExtensionForSpecialization(spec, vehicle, uiScale, InputHelpDisplay.COLOR.HELP_TEXT, self.helpTextSize)
                if drawableWhileNotActive then
                    hudExtension.canDraw = Utils.overwrittenFunction(hudExtension.canDraw, function(self, superFunc)
                        return superFunc(self) and g_currentMission.accessHandler:canPlayerAccess(hudExtension.vehicle)
                    end)
                end

                table.addElement(self.vehicleHudExtensions, hudExtension)
                vehiclesAlreadyAdded[vehicle] = true
            end
        end
    end

    -- add extensions for currently controlled vehicle and attached implements
    if self.vehicle ~= nil then
        local vehicles = self.vehicle.rootVehicle.childVehicles
        for i=1, #vehicles do
            addExtensionForVehicle(vehicles[i])
        end
    end

    -- add extensions for vehicles not currently controlled such as mixer wagons near the player
    for i=#self.extraExtensionVehicleNodeIds, 1, -1 do
        local vehicleNodeId = self.extraExtensionVehicleNodeIds[i]
        local vehicle = g_currentMission.nodeToObject[vehicleNodeId]
        if vehicle == nil then
            table.remove(self.extraExtensionVehicleNodeIds, i)
        elseif self.vehicle ~= vehicle  then
            if vehicle.getIsPlayerInTrigger == nil or (vehicle.getIsPlayerInTrigger and vehicle:getIsPlayerInTrigger()) then
                addExtensionForVehicle(vehicle, true)
            end
        end
    end

    table.sort(self.vehicleHudExtensions, VehicleHUDExtension.sortHUDExtensions)
--#profile     g_remoteProfiler:ZoneEnd()
end


---Update HUD extensions if controlled vehicles have changed.
function InputHelpDisplay:updateHUDExtensions()
    if self.vehicle ~= nil then -- update HUD extensions, can change when implements are attached / detached
        local currentHash = self:getCurrentVehicleTypeHash(self.vehicle)
        if currentHash ~= self.lastVehicleSpecHash then
            self.requireHudExtensionsRefresh = true
            self.lastVehicleSpecHash = currentHash
        end
    else
        self.lastVehicleSpecHash = nil
    end

    -- check if vehicle for nodeId still exists
    for i=#self.extraExtensionVehicleNodeIds, 1, -1  do
        local nodeId = self.extraExtensionVehicleNodeIds[i]
        if g_currentMission.nodeToObject[nodeId] == nil then
            table.remove(self.extraExtensionVehicleNodeIds, i)
            self.requireHudExtensionsRefresh = true
        end
    end

    -- refresh extensions if number of vehicles changed
    local count = table.size(self.extraExtensionVehicleNodeIds)
    if self.lastExtraExtensionVehiclesCount ~= count then
        self.lastExtraExtensionVehiclesCount = count
        self.requireHudExtensionsRefresh = true
    end

    if self.requireHudExtensionsRefresh then
        self:refreshHUDExtensions()
        self.requireHudExtensionsRefresh = false
    end

    local extensionsHeight = 0
    for _, hudExtension in pairs(self.vehicleHudExtensions) do
        local height = hudExtension:getDisplayHeight()
        if hudExtension:canDraw() and extensionsHeight + height <= self.currentAvailableHeight then
            extensionsHeight = extensionsHeight + height
        end
    end

    self.sizeAndPositionDirty = self.sizeAndPositionDirty or self.extensionsHeight ~= extensionsHeight
    self.extensionsHeight = extensionsHeight
end


---Get combined string of all vehicle types attached
function InputHelpDisplay:getCurrentVehicleTypeHash(vehicle)
    local vehicles = vehicle.rootVehicle.childVehicles
    local hash = ""
    for i=1, #vehicles do
        hash = hash .. vehicle.typeName
    end

    return hash
end


---Get the available screen space height for displaying input help.
function InputHelpDisplay:getAvailableHeight()
    local mapTop = self.ingameMap:getRequiredHeight()

    local commTop = 0
    if self.communicationDisplay:getVisible() then
        local _, commPosY = self.communicationDisplay:getPosition()
        commTop = commPosY + self.communicationDisplay:getHeight()
    end

    local otherElementsTop = math.max(mapTop, commTop)
    return 1 - g_safeFrameOffsetY * 2 - otherElementsTop - self.minimumMapSpacingY
end


---Update display elements with the current input context.
function InputHelpDisplay:updateInputContext()
    local availableHeight = self:getAvailableHeight()
    if not self.animation:getFinished() then
        availableHeight = math.min(availableHeight, self.animationAvailableHeight)
    end

    local pressedComboMaskGamepad, pressedComboMaskMouse = self.inputManager:getComboCommandPressedMask()
    local useGamepadButtons = self.isConsoleVersion or (self.inputManager:getInputHelpMode() == GS_INPUT_HELP_MODE_GAMEPAD)

    self:updateComboHeaders(useGamepadButtons, pressedComboMaskMouse, pressedComboMaskGamepad)
    if self.hasComboCommands then
        availableHeight = availableHeight - self.headerHeight
    end

    local helpElements, usedHeight = self:getInputHelpElements(availableHeight, pressedComboMaskGamepad, pressedComboMaskMouse, useGamepadButtons)
    self.visibleHelpElements = helpElements
    availableHeight = availableHeight - usedHeight

    for _, text in pairs(self.extraHelpTexts) do
        if availableHeight - self.entryHeight >= 0 then
            local extraTextHelpElement = InputHelpElement.new(nil, nil, nil, nil, nil, text)
            table.insert(helpElements, extraTextHelpElement)
            availableHeight = availableHeight - self.entryHeight
        else
            break
        end
    end

    self:updateEntries(helpElements)
    self.currentAvailableHeight = availableHeight -- store remainder for dynamic components (e.g. HUD extensions)
end


---Update entry glyphs and visibility with the current input help elements.
-- @param table helpElements Array of InputHelpElement for the current input context
function InputHelpDisplay:updateEntries(helpElements)
    local usedCount = 0

    local entryCount = #self.entries
    local separatorCount = math.min(#helpElements - 1, entryCount - 1)
    if self.extensionsHeight > 0 and not self.ingameMap:getIsLarge() then
        separatorCount = separatorCount + 1
    end

    for i = 1, entryCount do
        local entry = self.entries[i]
        if i <= #helpElements then
            usedCount = usedCount + 1

            local helpElement = helpElements[i]

            local showInput = #helpElement.buttons > 0 or #helpElement.keys > 0
            local showText = helpElement.textLeft ~= ""

            entry:setVisible(showInput or showText)
            self.inputGlyphs[i]:setVisible(not showText)
            self.inputGlyphs[i].background:setVisible(not showText)

            if helpElement.actionName ~= "" then
                if helpElement.actionName2 ~= "" then
                    self.inputGlyphs[i]:setActions({helpElement.actionName, helpElement.actionName2}, nil, nil, helpElement.inlineModifierButtons)
                else
                    self.inputGlyphs[i]:setAction(helpElement.actionName, nil, nil, helpElement.inlineModifierButtons) -- no action text, do not show combo buttons
                end

                self.entryGlyphWidths[i] = self.inputGlyphs[i]:getGlyphWidth()

                self.inputGlyphs[i].background:setDimension(self.entryGlyphWidths[i] + 2 * self.inputGlyphs[i].spacing)
            else
                self.entryGlyphWidths[i] = 0
            end
        else
            entry:setVisible(false)
        end
    end

    for i = 1, #self.horizontalSeparators do
        local separator = self.horizontalSeparators[i]
        separator:setVisible(i <= separatorCount)
    end

    self.sizeAndPositionDirty = self.sizeAndPositionDirty or self.numUsedEntries ~= usedCount
    self.numUsedEntries = usedCount
end


---Update combo header state.
-- @param bool useGamepadButtons If true, check gamepad input. Otherwise, check keyboard / mouse.
-- @param int pressedComboMaskMouse Bit mask of pressed mouse combo actions
-- @param int pressedComboMaskGamepad Bit mask of pressed gamepad combo actions
-- @return float Screen space height used by the combo header (0 if invisible)
function InputHelpDisplay:updateComboHeaders(useGamepadButtons, pressedComboMaskMouse, pressedComboMaskGamepad)
    local comboActionStatus = self.inputDisplayManager:getComboHelpElements(useGamepadButtons)

    local hasComboCommands = next(comboActionStatus) ~= nil
    self.sizeAndPositionDirty = self.sizeAndPositionDirty or self.hasComboCommands ~= hasComboCommands
    self.hasComboCommands = hasComboCommands

    if self.hasComboCommands then
        self:updateComboInputGlyphs(comboActionStatus, pressedComboMaskMouse, pressedComboMaskGamepad)
    end

    self.mouseComboHeader:setVisible(self.hasComboCommands and not useGamepadButtons)
    self.gamepadComboHeader:setVisible(self.hasComboCommands and useGamepadButtons)
end


---Update visibility and color of combo input glyphs.
-- @param table comboActionStatus Hashtable of combo action names which are currently available
-- @param int pressedComboMaskMouse Bit mask of pressed mouse combo actions
-- @param int pressedComboMaskGamepad Bit mask of pressed gamepad combo actions
function InputHelpDisplay:updateComboInputGlyphs(comboActionStatus, pressedComboMaskMouse, pressedComboMaskGamepad)
    self.comboIterator[InputBinding.MOUSE_COMBOS] = pressedComboMaskMouse
    self.comboIterator[InputBinding.GAMEPAD_COMBOS] = pressedComboMaskGamepad

    -- apply visibility settings to combo buttons
    for actionCombos, pressedComboMask in pairs(self.comboIterator) do
        for actionName, comboData in pairs(actionCombos) do
            local comboGlyph = self.comboInputGlyphs[actionName]
            if comboActionStatus[actionName] then
                comboGlyph:setVisible(true)

                local isPressed = bitAND(pressedComboMask, comboData.mask) ~= 0
                if isPressed then
                    comboGlyph:setButtonGlyphColor(InputHelpDisplay.COLOR.COMBO_GLYPH_PRESSED)
                else
                    comboGlyph:setButtonGlyphColor(InputHelpDisplay.COLOR.COMBO_GLYPH)
                end
            else
                comboGlyph:setVisible(false)
            end
        end
    end
end


---Get input help elements based on the current input context.
-- @param float availableHeight Maximum available height to use for input help elements
-- @param int pressedComboMaskGamepad Bit mask of pressed gamepad combo buttons
-- @param int pressedComboMaskMouse Bit mask of pressed mouse combo buttons
-- @param bool useGamepadButtons If true, we should draw gamepad / controller combo button glyphs
-- @return table Input help elements
-- @return float Screen space height used by the returned help elements
function InputHelpDisplay:getInputHelpElements(availableHeight, pressedComboMaskGamepad, pressedComboMaskMouse, useGamepadButtons)
    local currentPressedMask = useGamepadButtons and pressedComboMaskGamepad or pressedComboMaskMouse
    local isCombo = currentPressedMask ~= 0
    local isFillUp = false

    local eventHelpElements = self.inputDisplayManager:getEventHelpElements(currentPressedMask, useGamepadButtons)
    if #eventHelpElements == 0 and not self.hasComboCommands and isCombo then
        -- just load the base input list without modifier (pressed mask == 0)
        eventHelpElements = self.inputDisplayManager:getEventHelpElements(0, useGamepadButtons)
        isFillUp = true
    end

    self.currentHelpElementCount = #eventHelpElements
    local helpElements = {}

    local usedHeight = 0
    local i = 1
    while usedHeight + self.entryHeight <= availableHeight and i <= #eventHelpElements do
        if not self:getIsHelpElementAllowed(helpElements, eventHelpElements[i]) then
            break
        end

        table.insert(helpElements, eventHelpElements[i])
        usedHeight = usedHeight + self.entryHeight
        i = i + 1
    end

    local contextCustomElements = self.customHelpElements[self.inputManager:getContextName()]
    if contextCustomElements ~= nil then
        self.currentHelpElementCount = self.currentHelpElementCount + #contextCustomElements

        i = 1
        while usedHeight + self.entryHeight <= availableHeight and i <= #contextCustomElements do
            local customHelpElement = contextCustomElements[i]
            -- display custom element if bindings and controller symbols could be resolved, otherwise a null-element is
            -- returned which we test against:
            if customHelpElement ~= InputDisplayManager.NO_HELP_ELEMENT then
                local action = self.inputManager:getActionByName(customHelpElement.actionName)
                if action ~= nil then
                    local fitsComboMask = action.comboMaskGamepad == pressedComboMaskGamepad and action.comboMaskMouse == pressedComboMaskMouse
                    local noComboFillUp = action.comboMaskGamepad == 0 and action.comboMaskMouse == 0 and isFillUp

                    if fitsComboMask or noComboFillUp then
                        table.insert(helpElements, customHelpElement)
                        usedHeight = usedHeight + self.entryHeight
                    end
                end
            end

            i = i + 1
        end
    end

    return helpElements, usedHeight
end


---Set the current animation value for available height.
function InputHelpDisplay:setAnimationAvailableHeight(value)
    self.animationAvailableHeight = math.min(value, self:getAvailableHeight())
end


---Set the current animation position offset.
function InputHelpDisplay:setAnimationOffset(offX, offY)
    self.animationOffsetX, self.animationOffsetY = offX, offY
end


---Animate this element on hiding.
function InputHelpDisplay:animateHide()
    local transX, transY = self:getHidingTranslation()

    local sequence = TweenSequence.new(self)
    local foldEntries = Tween.new(self.setAnimationAvailableHeight, self:getAvailableHeight(), 0, HUDDisplayElement.MOVE_ANIMATION_DURATION)
    local moveOut = MultiValueTween.new(self.setAnimationOffset, {0, 0}, {transX, transY}, HUDDisplayElement.MOVE_ANIMATION_DURATION)

    sequence:addTween(foldEntries)
    sequence:addTween(moveOut)
    sequence:addCallback(self.onAnimateVisibilityFinished, false)

    sequence:start()
    self.animation = sequence
end


---Animate this element on showing.
function InputHelpDisplay:animateShow()
    InputHelpDisplay:superClass().setVisible(self, true)

    local transX, transY = self:getHidingTranslation()

    local sequence = TweenSequence.new(self)
    local moveIn = MultiValueTween.new(self.setAnimationOffset, {transX, transY}, {0, 0}, HUDDisplayElement.MOVE_ANIMATION_DURATION)
    local unfoldEntries = Tween.new(self.setAnimationAvailableHeight, 0, self:getAvailableHeight(), HUDDisplayElement.MOVE_ANIMATION_DURATION)

    sequence:addTween(moveIn)
    sequence:addTween(unfoldEntries)
    sequence:addCallback(self.onAnimateVisibilityFinished, true)

    sequence:start()
    self.animation = sequence
end


---Called when a hiding or showing animation has finished.
function InputHelpDisplay:onAnimateVisibilityFinished(isVisible)
    InputHelpDisplay:superClass().onAnimateVisibilityFinished(self, isVisible)
end


---Called when the connected input devices have changed.
function InputHelpDisplay:onInputDevicesChanged()
    for _, combos in pairs{InputBinding.ORDERED_MOUSE_COMBOS, InputBinding.ORDERED_GAMEPAD_COMBOS} do
        for i, combo in ipairs(combos) do
            local actionName = combo.controls
            local glyphElement = self.comboInputGlyphs[actionName]
            local prevWidth = glyphElement:getGlyphWidth()
            glyphElement:setAction(actionName, nil, nil, false, true) -- no action text, use combo buttons, make copies of overlays
            local glyphWidth = glyphElement:getGlyphWidth() -- get modified width based on action

            -- reposition glyphs
            if prevWidth ~= glyphWidth then
                if i > 1 then -- first (left) glyph is always correctly aligned, no correction needed
                    local posX, posY = glyphElement:getPosition()
                    if i == #combos then
                        posX = posX + prevWidth - glyphWidth
                    else
                        posX = posX + (prevWidth - glyphWidth) * 0.5
                    end

                    glyphElement:setPosition(posX, posY)
                end
            end
        end
    end
end


---Handle menu visibility changes.
function InputHelpDisplay:onMenuVisibilityChange(isMenuVisible, isOverlayMenu)
    self.isOverlayMenuVisible = isMenuVisible and isOverlayMenu
end






---Draw the input help.
Only draws if the element is visible and there are any help elements.
function InputHelpDisplay:draw()
    local needInfos = self:getVisible() and #self.visibleHelpElements > 0 or self.hasComboCommands
    local needBackground = needInfos or not self.animation:getFinished() and self.currentHelpElementCount > 0

    if needBackground then
        InputHelpDisplay:superClass().draw(self)
    end

    if needInfos then
        self:drawHelpInfos()
        self:drawVehicleHUDExtensions()
        self:drawControlsLabel()
    end
end


---Draw the "controls" label on top of the display frame.
function InputHelpDisplay:drawControlsLabel()
    setTextBold(true)
    setTextColor(unpack(InputHelpDisplay.COLOR.CONTROLS_LABEL))
    setTextAlignment(RenderText.ALIGN_LEFT)

    local baseX, baseY = self:getPosition()
    local baseTopY = baseY + self:getHeight()
    local frameX, frameTopY = baseX + self.frameOffsetX, baseTopY + self.frameOffsetY
    local posX, posY = frameX + self.controlsLabelOffsetX, frameTopY + self.controlsLabelOffsetY
    renderText(posX, posY, self.controlsLabelTextSize, self.controlsLabelText)
end


---Draw icons and text in help entries.
function InputHelpDisplay:drawHelpInfos()
    local framePosX, framePosY = self.entriesFrame:getPosition()
    local entriesHeight = self.entriesFrame:getHeight()
    for i, helpElement in ipairs(self.visibleHelpElements) do
        local entryPosY = framePosY + entriesHeight - i * self.entryHeight
        if helpElement.iconOverlay ~= nil then
            local posX = framePosX + self.entryWidth - self.axisIconWidth + self.axisIconOffsetX
            local posY = entryPosY + self.entryHeight * 0.5

            helpElement.iconOverlay:setPosition(posX, posY)
            helpElement.iconOverlay:setDimension(self.axisIconWidth, self.axisIconHeight)
            helpElement.iconOverlay:render()
        else
            setTextBold(false)
            setTextColor(unpack(InputHelpDisplay.COLOR.HELP_TEXT))

            local text = ""
            local posX, posY = framePosX, entryPosY
            local textLeftX = 1
            if helpElement.textRight ~= "" then
                setTextAlignment(RenderText.ALIGN_RIGHT)
                text = helpElement.textRight
                local textWidth = getTextWidth(self.helpTextSize, text)
                posX = posX + self.entryWidth + self.helpTextOffsetX
                posY = posY + (self.entryHeight - self.helpTextSize) * 0.5 + self.helpTextOffsetY
                textLeftX = posX - textWidth
            elseif helpElement.textLeft ~= "" then
                setTextAlignment(RenderText.ALIGN_LEFT)
                text = helpElement.textLeft
                posX = posX + self.extraTextOffsetX
                posY = posY + (self.entryHeight - self.helpTextSize) * 0.5 + self.extraTextOffsetY
                textLeftX = posX
            end

            -- check glyph width and re-align text if necessary
            local glyphWidth = self.entryGlyphWidths[i] or 0 -- 0 -> no glyph to display for this entry
            local glyphLeftX = glyphWidth ~= 0 and self.inputGlyphs[i]:getPosition() or 0
            local glyphRightX = glyphLeftX + glyphWidth

            if glyphRightX < textLeftX then
                renderText(posX, posY, self.helpTextSize, text)
            else
                -- distribute text over two lines
                local availableTextWidth = posX - glyphRightX - math.abs(self.helpTextOffsetX)
                setTextWrapWidth(availableTextWidth)
                setTextLineBounds(0, 2) -- start at first line (engine zero-indexed), for two lines

                -- center posY again when using two lines
                posY = entryPosY + self.entryHeight * 0.5 + self.helpTextOffsetY
                renderText(posX, posY, self.helpTextSize, text)

                -- reset uncommon text rendering state:
                setTextWrapWidth(0)
                setTextLineBounds(0, 0)
            end
        end
    end
end


---Draw vehicle HUD extensions.
function InputHelpDisplay:drawVehicleHUDExtensions()
    if self.extensionsHeight > 0 then
        local leftPosX = self:getPosition()
        local width = self:getWidth()
        local posY = self.extensionsStartY
        local usedHeight = 0
        for _, extension in pairs(self.vehicleHudExtensions) do
            local extHeight = extension:getDisplayHeight()
            if extension:canDraw() and usedHeight + extHeight <= self.extensionsHeight then
                posY = posY - extHeight - self.entryOffsetY

                self.extensionBg:setPosition(leftPosX, posY)
                self.extensionBg:setDimension(width, extHeight)
                self.extensionBg:render()

                extension:draw(leftPosX + self.extraTextOffsetX, leftPosX + width + self.helpTextOffsetX, posY)

                usedHeight = usedHeight + extHeight
            end
        end
    end
end






---Set this element's UI scale.
-- @param float uiScale UI scale factor
function InputHelpDisplay:setScale(uiScale)
    InputHelpDisplay:superClass().setScale(self, uiScale, uiScale)
    self:storeScaledValues()
end


---Store scaled positioning, size and offset values.
function InputHelpDisplay:storeScaledValues()
    self.headerHeight = self:scalePixelToScreenHeight(InputHelpDisplay.SIZE.HEADER[2])
    self.entryWidth, self.entryHeight = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.HELP_ENTRY)
    self.controlsLabelTextSize = self:scalePixelToScreenHeight(HUDElement.TEXT_SIZE.DEFAULT_TITLE)
    self.controlsLabelOffsetX, self.controlsLabelOffsetY = self:scalePixelToScreenVector(InputHelpDisplay.POSITION.CONTROLS_LABEL)
    self.helpTextSize = self:scalePixelToScreenHeight(HUDElement.TEXT_SIZE.DEFAULT_TEXT)
    self.helpTextOffsetX, self.helpTextOffsetY = self:scalePixelToScreenVector(InputHelpDisplay.POSITION.HELP_TEXT)
    self.extraTextOffsetX, self.extraTextOffsetY = self:scalePixelToScreenVector(InputHelpDisplay.POSITION.EXTRA_TEXT)
    self.axisIconOffsetX = self:scalePixelToScreenWidth(InputHelpDisplay.POSITION.AXIS_ICON[1])
    self.axisIconWidth, self.axisIconHeight = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.AXIS_ICON)
    self.frameOffsetX, self.frameOffsetY = self:scalePixelToScreenVector(InputHelpDisplay.POSITION.FRAME)
    self.frameBarOffsetY = self:scalePixelToScreenHeight(HUDFrameElement.THICKNESS.BAR)
    self.minimumMapSpacingY = self:scalePixelToScreenHeight(InputHelpDisplay.MIN_MAP_SPACING)
    self.entryOffsetX, self.entryOffsetY = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.HELP_ENTRY_OFFSET)

    for _, element in ipairs(self.inputGlyphs) do
        element.spacing = self:scalePixelToScreenWidth(InputHelpDisplay.POSITION.INPUT_GLYPH[1])
    end
end


---Get this element's base background position in screen space.
function InputHelpDisplay.getBackgroundPosition()
    return g_safeFrameOffsetX, 1 - g_safeFrameOffsetY -- top left anchored
end


---Get the current top left position of the input help, including animation.
function InputHelpDisplay:getTopLeftPosition()
    local posX, posY = InputHelpDisplay.getBackgroundPosition()
    if not self.animation:getFinished() then
        posX = posX + self.animationOffsetX
        posY = posY + self.animationOffsetY
    end

    return posX, posY
end


---Get the maximum number of help entries which may be shown at any time.
-- @return int Maximum number of entries to show
function InputHelpDisplay:getMaxEntryCount(prio, ignoreLive)
    prio = Utils.getNoNil(prio, false)
    local count = (prio and InputHelpDisplay.ENTRY_COUNT_PC) or InputHelpDisplay.ENTRY_COUNT_PRIO_PC
    if self.isConsoleVersion then
        count = (prio and InputHelpDisplay.ENTRY_COUNT_CONSOLE) or InputHelpDisplay.ENTRY_COUNT_PRIO_CONSOLE
    end

    if not ignoreLive then
        -- Combos also take space
        if self.hasComboCommands then
            count = count - 1
        end

        count = count - #self.extraHelpTexts
    end

    for _, hudExtension in pairs(self.vehicleHudExtensions) do
        if hudExtension.getHelpEntryCountReduction ~= nil then
            count = count - hudExtension:getHelpEntryCountReduction()
        end
    end

    return count
end


---Returns if it is still allowed to add more help elements
-- @param table helpElements existing table of help elements
-- @param table helpElement help element to add
-- @return boolean isAllowed isAllowed
function InputHelpDisplay:getIsHelpElementAllowed(helpElements, helpElement)
    if #helpElements >= self:getMaxEntryCount(true) then
        -- if we are above the lower limit and no overlay menu is visible we only allow to add high prio elements
        if helpElement.priority >= GS_PRIO_NORMAL and not self.isOverlayMenuVisible then
            return false
        else
            -- if we are above the upper limit we don't allow anything because there is no more space
            if #helpElements >= self:getMaxEntryCount(false) then
                return false
            end
        end
    end

    -- if we are below both limits we allow all prios
    return true
end


---Set this element's dimensions.
Override from HUDElement which adjusts frame with offset.
function InputHelpDisplay:setDimension(width, height)
    InputHelpDisplay:superClass().setDimension(self, width, height)
    self.frame:setDimension(width, height + self.frameOffsetY + self.frameBarOffsetY)
end






---Create the background overlay for positioning.
function InputHelpDisplay.createBackground()
    local posX, posY = InputHelpDisplay.getBackgroundPosition()
    local width, height = getNormalizedScreenValues(unpack(InputHelpDisplay.SIZE.HELP_ENTRY))
    local overlay = Overlay.new(nil, posX, posY, width, height)
    return overlay
end


---Create required display components.
function InputHelpDisplay:createComponents(hudAtlasPath)
    local baseWidth, baseHeight = getNormalizedScreenValues(unpack(InputHelpDisplay.SIZE.HELP_ENTRY))

    local baseX, baseY = self:getPosition()
    local frame = self:createFrame(hudAtlasPath, baseX, baseY, baseWidth, baseHeight)

    local maxEntries = self:getMaxEntryCount(nil, true)
    local frameX, frameY = frame:getPosition()
    self:createEntries(hudAtlasPath, frameX, frameY, maxEntries)

    self:createMouseComboHeader(hudAtlasPath, frameX, frameY)
    self:createControllerComboHeader(hudAtlasPath, frameX, frameY)
end


---Create the frame around input help elements.
function InputHelpDisplay:createFrame(hudAtlasPath, baseX, baseY, width, height)
    local frame = HUDFrameElement.new(hudAtlasPath, baseX, baseY, width, height)
    frame:setColor(unpack(HUD.COLOR.FRAME_BACKGROUND))
    -- self:addChild(frame)
    self.frame = frame

    return frame
end


---Create a vertical separator element.
function InputHelpDisplay:createVerticalSeparator(hudAtlasPath, leftPosX, centerPosY)
    local width, height = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.VERTICAL_SEPARATOR)
    width = math.max(width, 1 / g_screenWidth)
    local overlay = Overlay.new(hudAtlasPath, leftPosX + width * 0.5, centerPosY - height * 0.5, width, height)
    overlay:setUVs(GuiUtils.getUVs(HUDElement.UV.FILL))
    overlay:setColor(unpack(InputHelpDisplay.COLOR.SEPARATOR))

    return HUDElement.new(overlay)
end


---Create a horizontal separator element.
function InputHelpDisplay:createHorizontalSeparator(hudAtlasPath, leftPosX, posY)
    local width, height = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.HORIZONTAL_SEPARATOR)
    height = math.max(height, 1 / g_screenHeight)
    local overlay = Overlay.new(hudAtlasPath, leftPosX, posY - height * 0.5, width, height)
    overlay:setUVs(GuiUtils.getUVs(HUDElement.UV.FILL))
    overlay:setColor(unpack(InputHelpDisplay.COLOR.SEPARATOR))

    return HUDElement.new(overlay)
end


---Create an input glyph for displaying combo input buttons.
-- @param float posX Screen space X position
-- @param float posY Screen space Y position
-- @param float width Screen space width
-- @param float height Screen space height
-- @param string actionName InputAction name of the combo action whose input glyphs need to be displayed
-- @return table Combo InputGlyphElement instance
function InputHelpDisplay:createComboInputGlyph(posX, posY, width, height, actionName)
    local element = InputGlyphElement.new(self.inputDisplayManager, width, height)
    element:setPosition(posX, posY)
    element:setKeyboardGlyphColor(InputHelpDisplay.COLOR.COMBO_GLYPH)
    element:setButtonGlyphColor(InputHelpDisplay.COLOR.COMBO_GLYPH)
    element:setAction(actionName, nil, nil, false, true) -- no action text, use combo buttons, make copies of overlays

    return element
end


---Create a combo input glyph header.
-- @param hudAtlasPath Path to HUD texture atlas
-- @param frameX Screen space X position of the display frame
-- @param frameY Screen space Y position of the display frame
-- @param table combos Array of input combination descriptions as defined in InputBinding
-- @param table boxSize 2D vector which holds the pixel size of one combo input box within the header
-- @param table separatorPositions Array of 2D vectors of separator pixel positions
-- @return table Combo header HUDElement
function InputHelpDisplay:createComboHeader(hudAtlasPath, frameX, frameY, combos, boxSize, separatorPositions)
    local width, height = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.HEADER)
    local posY = frameY - height
    local bgOverlay = Overlay.new(nil, frameX, posY, width, height)
    local headerElement = HUDElement.new(bgOverlay)

    local entryOffset, _ = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.HELP_ENTRY_OFFSET)
    local headerItemWidth = (width - entryOffset * (#combos - 1)) / #combos

    local glyphWidth, glyphHeight = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.COMBO_GLYPH)
    local boxWidth, boxHeight = self:scalePixelToScreenVector(boxSize)
    local count = 0
    for i, combo in ipairs(combos) do
        -- Background
        local overlay = Overlay.new(g_baseUIFilename, frameX + headerItemWidth * (i - 1) + entryOffset * (i - 1), posY, headerItemWidth, height)
        overlay:setUVs(g_colorBgUVs)
        overlay:setColor(0, 0, 0, 0.56)
        headerElement:addChild(HUDElement.new(overlay))

        local actionName = combo.controls
        local glyphElement = self:createComboInputGlyph(0, 0, glyphWidth, glyphHeight, actionName)
        local glyphModifiedWidth = glyphElement:getGlyphWidth() -- get modified width based on action

        local glyphPosX = frameX + boxWidth * count + (boxWidth - glyphModifiedWidth) * 0.5
        local glyphPosY = posY + (boxHeight - glyphHeight) * 0.5

        -- align left and right outer combo icons with help entry icons
        if i == 1 then -- leftmost
            local offX = self:scalePixelToScreenWidth(InputHelpDisplay.POSITION.INPUT_GLYPH[1])
            glyphPosX = frameX + offX
        elseif i == #combos then -- rightmost
            local offX = self:scalePixelToScreenWidth(InputHelpDisplay.POSITION.AXIS_ICON[1]) - glyphModifiedWidth
            glyphPosX = frameX + boxWidth * i + offX
        end

        glyphElement:setPosition(glyphPosX, glyphPosY)
        headerElement:addChild(glyphElement)

        self.comboInputGlyphs[actionName] = glyphElement -- store by action name for visibility changes

        count = count + 1
    end

    return headerElement
end


---Create the mouse combo header.
function InputHelpDisplay:createMouseComboHeader(hudAtlasPath, frameX, frameY)
    local header = self:createComboHeader(hudAtlasPath, frameX, frameY,
        InputBinding.ORDERED_MOUSE_COMBOS, InputHelpDisplay.SIZE.MOUSE_COMBO_BOX, InputHelpDisplay.POSITION.MOUSE_COMBO_SEPARATOR)

    self.mouseComboHeader = header
    self:addChild(header)
end


---Create the gamepad / controller combo header.
function InputHelpDisplay:createControllerComboHeader(hudAtlasPath, frameX, frameY)
    local header = self:createComboHeader(hudAtlasPath, frameX, frameY,
        InputBinding.ORDERED_GAMEPAD_COMBOS, InputHelpDisplay.SIZE.GAMEPAD_COMBO_BOX, InputHelpDisplay.POSITION.GAMEPAD_COMBO_SEPARATOR)

    self.gamepadComboHeader = header
    self:addChild(header)
end


---Create an input help entry box.
function InputHelpDisplay:createEntry(hudAtlasPath, posX, posY, width, height)
    local overlay = Overlay.new(g_baseUIFilename, posX, posY, width, height)
    overlay:setUVs(g_colorBgUVs)
    overlay:setColor(0, 0, 0, 0.56)
    local entryElement = HUDElement.new(overlay)

    local glyphWidth, glyphHeight = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.INPUT_GLYPH)
    local offX, offY = self:scalePixelToScreenWidth(InputHelpDisplay.POSITION.INPUT_GLYPH[1]), (height - glyphHeight) * 0.5

    overlay = Overlay.new(g_baseUIFilename, posX, posY, glyphWidth + 2 * offX, height)
    overlay:setUVs(g_colorBgUVs)
    overlay:setColor(0, 0, 0, 0.6)
    local glyphBackground = HUDElement.new(overlay)
    entryElement:addChild(glyphBackground)

    local glyphElement = InputGlyphElement.new(self.inputDisplayManager, glyphWidth, glyphHeight)
    glyphElement:setPosition(posX + offX, posY + offY)
    glyphElement:setKeyboardGlyphColor(InputHelpDisplay.COLOR.INPUT_GLYPH)
    glyphElement.background = glyphBackground
    glyphElement.spacing = offX

    entryElement:addChild(glyphElement)
    table.insert(self.inputGlyphs, glyphElement)

    return entryElement
end


---Create all required input help entry boxes.
The boxes are modified as required to reflect the current input context.
function InputHelpDisplay:createEntries(hudAtlasPath, frameX, frameY, count)
    local posX, posY = frameX, frameY
    local entryWidth, entryHeight = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.HELP_ENTRY)
    local _, entryOffset = self:scalePixelToScreenVector(InputHelpDisplay.SIZE.HELP_ENTRY_OFFSET)

    local overlay = Overlay.new(nil, posX, posY, entryWidth, entryHeight * count)
    local entriesFrame = HUDElement.new(overlay)
    self.entriesFrame = entriesFrame
    self:addChild(entriesFrame)

    local totalHeight = count * entryHeight
    for i = 1, count do
        posY = frameY + totalHeight - entryHeight * i
        local entry = self:createEntry(hudAtlasPath, posX, posY, entryWidth, entryHeight - entryOffset)
        table.insert(self.entries, entry)
        table.insert(self.entryGlyphWidths, 0)
        entriesFrame:addChild(entry)
    end
end
