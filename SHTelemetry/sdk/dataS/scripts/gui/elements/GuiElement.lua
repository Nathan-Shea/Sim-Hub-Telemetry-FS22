---GUI Element base class.
--All elements displayed in the game UI must be instances or descendants of this class.
--
--All XML configuration properties as declared below (and in subclasses) are mirrored in guiProfiles.xml as key-value
--pairs in the form of &ltValue name="property_name" value="value" /&gt. Profiles are able to inherit from other
--profiles, so take care to check their hierarchy if any of your settings do not seem to have any effect. Directly set
--properties in the XML configuration will always override profile values, however.
--
--Layer properties, prefixed with "[layer]", interact with an overlay system and provide display images. Usable
--layers, whose names are substituted for the prefix, are primarily "image" and "icon". UI elements define layer names
--on their own and read them from these generated properties. Whenever an element requires a layer, it is described
--in its documentation such as this one. Example for an icon layer focus color property:
--iconFocusedColor="0.9 0.1 0.5 1.0".
--
--A note regarding callbacks: All callbacks are called on an element's target first. When GUI elements are created from
--configuration, their top-level view (e.g. MainScreen) is the callback target, i.e. MainScreen:callbackName() is
--executed. Unless an element's target has been set to another value explicitly via code, this will always be the case.















































































local GuiElement_mt = Class(GuiElement)


































---Create a new GuiElement.
-- @param target Target ScreenElement instance
function GuiElement.new(target, custom_mt)
    local self = setmetatable({}, custom_mt or GuiElement_mt)
    self:include(GuiMixin) -- adds hasIncluded() method to check for included mixins

    self.elements = {}
    self.target = target
    if target ~= nil then
        self.targetName = target.name
    end

    self.profile = ""
    self.name = nil
    self.screenAlign = 0
    self.screenAlignStr = nil
    self.positionOrigin = 0
    self.positionOriginStr = nil
    self.debugEnabled = false
    self.position = {0, 0}
    self.absPosition = {0, 0}
    self.absSize = {1, 1}
    self.size = {1 * g_aspectScaleX, 1 * g_aspectScaleY}
    self.margin = {0, 0, 0, 0} -- left, top, right, bottom
    self.anchors = {0, 1, 0, 1} -- top left
    self.borders = {0, 0, 1, 1}
    self.parentBorders = {0, 0, 1, 1}
    self.center = {0, 0}
    self.outputSize = {g_referenceScreenWidth, g_referenceScreenHeight}
    self.imageSize = {1024, 1024}
    self.visible = true
    self.disabled = false
    self.thinLineProtection = true
    self.disallowFlowCut = false

    self.alpha = 1
    self.fadeInTime = 0
    self.fadeOutTime = 0
    self.fadeDirection = 0
    self.newLayer = false
    self.toolTipText = nil
    self.toolTipElementId = nil
    self.toolTipElement = nil
    self.layoutIgnore = false

    self.focusFallthrough = false

    self.clipping = false

    self.hasFrame = false
    self.frameThickness = {0, 0, 0, 0} -- left, top, right, bottom
    self.frameColors = {
        [GuiElement.FRAME_LEFT] = {1, 1, 1, 1},
        [GuiElement.FRAME_TOP] = {1, 1, 1, 1},
        [GuiElement.FRAME_RIGHT] = {1, 1, 1, 1},
        [GuiElement.FRAME_BOTTOM] = {1, 1, 1, 1},
    }
    self.frameOverlayVisible = {true, true, true, true}

    self.updateChildrenOverlayState = true
    self.overlayState = GuiOverlay.STATE_NORMAL
    self.previousOverlayState = nil -- remembers the current overlay state when it needs to be temporarily overridden(e.g. STATE_PRESSED)

    self.isSoundSuppressed = false
    self.soundDisabled = false

    self.handleFocus = true
    self.focusChangeData = {}
    self.focusId = nil
    self.focusActive = false

    return self
end


---Load element data from an XML definition file.
-- @param xmlFile Definition XML file handle
-- @param key XML node path to this element's definition
function GuiElement:loadFromXML(xmlFile, key)
    local profile = getXMLString(xmlFile, key .. "#profile")
    if profile ~= nil then
        self.profile = profile

        local pro = g_gui:getProfile(profile) -- defaults to base reference if profile name is invalid, also prints warning in that case
        self:loadProfile(pro)
    end

    self:setId(xmlFile, key)

    self.onCreateArgs = getXMLString(xmlFile, key.."#onCreateArgs")
    self:addCallback(xmlFile, key.."#onCreate", "onCreateCallback")
    self:addCallback(xmlFile, key.."#onOpen", "onOpenCallback")
    self:addCallback(xmlFile, key.."#onClose", "onCloseCallback")
    self:addCallback(xmlFile, key.."#onDraw", "onDrawCallback")

    self.name = Utils.getNoNil(getXMLString(xmlFile, key.."#name"), self.name)
    self.imageSize = GuiUtils.get2DArray(getXMLString(xmlFile, key.."#imageSize"), self.imageSize)
    self.outputSize = GuiUtils.get2DArray(getXMLString(xmlFile, key.."#outputSize"), self.outputSize)
    self.position = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#position"), self.outputSize, self.position)
    self.size = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#size"), self.outputSize, self.size)
    self.margin = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#margin"), self.outputSize, self.margin)

    self.pivot = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key .. "#pivot"), self.outputSize, self.pivot)
    self.anchors = GuiUtils.get4DArray(getXMLString(xmlFile, key .. "#anchors"), self.anchors)

    self.thinLineProtection = Utils.getNoNil(getXMLBool(xmlFile, key.."#thinLineProtection"), self.thinLineProtection)

    self.positionOriginStr = Utils.getNoNil(getXMLString(xmlFile, key.."#positionOrigin"), self.positionOriginStr)
    self.screenAlignStr = Utils.getNoNil(getXMLString(xmlFile, key.."#screenAlign"), self.screenAlignStr)

    self.visible = Utils.getNoNil(getXMLBool(xmlFile, key.."#visible"), self.visible)
    self.disabled = Utils.getNoNil(getXMLBool(xmlFile, key.."#disabled"), self.disabled)
    self.newLayer = Utils.getNoNil(getXMLBool(xmlFile, key.."#newLayer"), self.newLayer)
    self.debugEnabled = Utils.getNoNil(getXMLBool(xmlFile, key.."#debugEnabled"), self.debugEnabled)
    self.updateChildrenOverlayState = Utils.getNoNil(getXMLBool(xmlFile, key.."#updateChildrenOverlayState"), self.updateChildrenOverlayState)
    self.toolTipText = getXMLString(xmlFile, key.."#toolTipText")
    self.toolTipElementId = getXMLString(xmlFile, key.."#toolTipElementId")
    self.layoutIgnore = Utils.getNoNil(getXMLBool(xmlFile, key .. "#layoutIgnore"), self.layoutIgnore)
    self.clipping = Utils.getNoNil(getXMLBool(xmlFile, key .. "#clipping"), self.clipping)

    self.handleFocus = Utils.getNoNil(getXMLBool(xmlFile, key.."#handleFocus"), self.handleFocus)
    self.soundDisabled = Utils.getNoNil(getXMLBool(xmlFile, key .. "#soundDisabled"), self.soundDisabled)

    self.focusFallthrough = Utils.getNoNil(getXMLBool(xmlFile, key .. "#focusFallthrough"), self.focusFallthrough)
    self.disallowFlowCut = Utils.getNoNil(getXMLBool(xmlFile, key.."#disallowFlowCut"), self.disallowFlowCut)

    self.hasFrame = Utils.getNoNil(getXMLBool(xmlFile, key .. "#hasFrame"), self.hasFrame)
    if self.hasFrame then
        local thickness = getXMLString(xmlFile, key .. "#frameThickness")
        self.frameThickness = GuiUtils.getNormalizedValues(thickness, self.outputSize) or self.frameThickness

        local color = getXMLString(xmlFile, key .. "#frameLeftColor")
        self.frameColors[GuiElement.FRAME_LEFT] = GuiUtils.getColorArray(color) or self.frameColors[GuiElement.FRAME_LEFT]
        color = getXMLString(xmlFile, key .. "#frameTopColor")
        self.frameColors[GuiElement.FRAME_TOP] = GuiUtils.getColorArray(color) or self.frameColors[GuiElement.FRAME_TOP]
        color = getXMLString(xmlFile, key .. "#frameRightColor")
        self.frameColors[GuiElement.FRAME_RIGHT] = GuiUtils.getColorArray(color) or self.frameColors[GuiElement.FRAME_RIGHT]
        color = getXMLString(xmlFile, key .. "#frameBottomColor")
        self.frameColors[GuiElement.FRAME_BOTTOM] = GuiUtils.getColorArray(color) or self.frameColors[GuiElement.FRAME_BOTTOM]
    end

    local fadeInTime = getXMLFloat(xmlFile, key.."#fadeInTime")
    if fadeInTime ~= nil then
        self.fadeInTime = fadeInTime*1000
    end

    local fadeOutTime = getXMLFloat(xmlFile, key.."#fadeOutTime")
    if fadeOutTime ~= nil then
        self.fadeOutTime = fadeOutTime*1000
    end

    -- self:fixThinLines()

    -- TODO
    -- self:updateScreenAlign(self.screenAlignStr)
    -- self:updatePositionForOrigin(self.positionOriginStr)

    if self.toolTipText ~= nil then
        if self.toolTipText:sub(1,6) == "$l10n_" then
            self.toolTipText = g_i18n:getText(self.toolTipText:sub(7))
        end
    end

    -- load focus properties
    FocusManager:loadElementFromXML(xmlFile, key, self)

    self:verifyConfiguration()
end


---Load profile data for this element.
-- @param profile Loaded GUI profile
-- @param applyProfile If true, will re-calculate some dynamic properties. Use this when setting profiles dynamically at run time.
function GuiElement:loadProfile(profile, applyProfile)
    local imageSize = profile:getValue("imageSize")
    if (imageSize ~= nil) then
        local x, y = imageSize:getVector()
        if x ~= nil and y ~= nil then
            self.imageSize = { x, y }
        end
    end

    local outputSize = profile:getValue("outputSize")
    if (outputSize ~= nil) then
        local x, y = outputSize:getVector()
        if x ~= nil and y ~= nil then
            self.outputSize = { x, y }
        end
    end

    local positionValue = profile:getValue("position")
    self.position = GuiUtils.getNormalizedValues(positionValue, self.outputSize, self.position)
    self.size = GuiUtils.getNormalizedValues(profile:getValue("size"), self.outputSize, self.size)
    self.pivot = GuiUtils.getNormalizedValues(profile:getValue("pivot"), self.outputSize, self.pivot)
    self.margin = GuiUtils.getNormalizedValues(profile:getValue("margin"), self.outputSize, self.margin)

    local anchors = profile:getValue("anchors")
    if anchors ~= nil then
        self.anchors = GuiUtils.get4DArray(anchors, self.anchors)
    end

    self.name = profile:getValue("name", self.name)

    self.positionOriginStr = profile:getValue("positionOrigin", self.positionOriginStr)
    self.screenAlignStr = profile:getValue("screenAlign", self.screenAlignStr)

    self.visible = profile:getBool("visible", self.visible)
    self.disabled = profile:getBool("disabled", self.disabled)
    self.newLayer = profile:getBool("newLayer", self.newLayer)
    self.debugEnabled = profile:getBool("debugEnabled", self.debugEnabled)
    self.updateChildrenOverlayState = profile:getBool("updateChildrenOverlayState", self.updateChildrenOverlayState)
    self.toolTipText = profile:getValue("toolTipText", self.toolTipText)
    self.layoutIgnore = profile:getBool("layoutIgnore", self.layoutIgnore)
    self.thinLineProtection = profile:getBool("thinLineProtection", self.thinLineProtection)
    self.clipping = profile:getBool("clipping", self.clipping)
    self.focusFallthrough = profile:getBool("focusFallthrough", self.focusFallthrough)
    self.disallowFlowCut = profile:getBool("disallowFlowCut", self.disallowFlowCut)

    self.hasFrame = profile:getBool("hasFrame", self.hasFrame)
    if self.hasFrame then
        self.frameThickness = GuiUtils.getNormalizedValues(profile:getValue("frameThickness"), self.outputSize) or self.frameThickness
        self.frameColors[GuiElement.FRAME_LEFT] = GuiUtils.getColorArray(profile:getValue("frameLeftColor"), self.frameColors[GuiElement.FRAME_LEFT])
        self.frameColors[GuiElement.FRAME_TOP] = GuiUtils.getColorArray(profile:getValue("frameTopColor"), self.frameColors[GuiElement.FRAME_TOP])
        self.frameColors[GuiElement.FRAME_RIGHT] = GuiUtils.getColorArray(profile:getValue("frameRightColor"), self.frameColors[GuiElement.FRAME_RIGHT])
        self.frameColors[GuiElement.FRAME_BOTTOM] = GuiUtils.getColorArray(profile:getValue("frameBottomColor"), self.frameColors[GuiElement.FRAME_BOTTOM])
    end

    self.handleFocus = profile:getBool("handleFocus", self.handleFocus)
    self.soundDisabled = profile:getBool("soundDisabled", self.soundDisabled)

    local fadeInTime = profile:getValue("fadeInTime")
    if fadeInTime ~= nil then
        self.fadeInTime = tonumber(fadeInTime) * 1000
    end

    local fadeOutTime = profile:getValue("fadeOutTime")
    if fadeOutTime ~= nil then
        self.fadeOutTime = tonumber(fadeOutTime) * 1000
    end

    if applyProfile then
        self:applyElementAspectScale(positionValue == nil)
        self:fixThinLines()
        self:updateAbsolutePosition()
    end
end


---Apply a GUI profile with a given name to this element.
-- @param profileName Name of the profile to apply to this element
-- @param bool force [optional] If true, will apply all profile settings, including position and size.
function GuiElement:applyProfile(profileName, force)
    if profileName then
        local pro = g_gui:getProfile(profileName)
        if pro ~= nil then
            self.profile = profileName
            self:loadProfile(pro, not force)
        end
    end
end


---Delete this GuiElement.
Also deletes all child elements and removes itself from its parent and focus.
function GuiElement:delete()
    for i = #self.elements, 1, -1 do
        self.elements[i].parent = nil
        self.elements[i]:delete()
    end

    if self.parent ~= nil then
        self.parent:removeElement(self)
    end
    -- unset focus data
    FocusManager:removeElement(self)
end


---Create a deep copy clone of this GuiElement.
-- @param parent Target parent element of the cloned element
-- @param includeId [optional, default=false] If true, will also clone ID values
-- @param suppressOnCreate [optional, default=false] If true, will not trigger the "onCreate" callback
function GuiElement:clone(parent, includeId, suppressOnCreate)
    local ret = self.new()
    ret:copyAttributes(self)

    if parent ~= nil then
        parent:addElement(ret)
    end

    for i=1, #self.elements do
        local clonedChild = self.elements[i]:clone(ret, includeId, suppressOnCreate)
        if includeId then
            clonedChild.id = self.elements[i].id
        end
    end

    if not suppressOnCreate then
        ret:raiseCallback("onCreateCallback", ret, ret.onCreateArgs)
    end

    return ret
end


---Copy all attributes from a source GuiElement to this GuiElement.
function GuiElement:copyAttributes(src)
    self.visible = src.visible
    self.name = src.name
    self.typeName = src.typeName
    self.disabled = src.disabled
    self.positionOrigin = src.positionOrigin
    self.screenAlign = src.screenAlign
    self.newLayer = src.newLayer
    self.debugEnabled = src.debugEnabled

    self.size = table.copy(src.size)
    self.margin = table.copy(src.margin)
    self.onCreateCallback = src.onCreateCallback
    self.onCreateArgs = src.onCreateArgs
    self.onCloseCallback = src.onCloseCallback
    self.onOpenCallback = src.onOpenCallback
    self.onDrawCallback = src.onDrawCallback

    self.target = src.target
    self.targetName = src.targetName
    self.profile = src.profile
    self.outputSize = table.copy(src.outputSize)
    self.imageSize = table.copy(src.imageSize)
    self.fadeInTime = src.fadeInTime
    self.fadeOutTime = src.fadeOutTime
    self.alpha = src.alpha
    self.fadeDirection = src.fadeDirection
    self.updateChildrenOverlayState = src.updateChildrenOverlayState
    self.toolTipElementId = src.toolTipElementId
    self.toolTipText = src.toolTipText
    self.handleFocus = src.handleFocus
    self.clipping = src.clipping
    self.focusFallthrough = src.focusFallthrough
    self.disallowFlowCut = src.disallowFlowCut

    self.ignoreLayout = src.ignoreLayout
    self.soundDisabled = src.soundDisabled

    self.hasFrame = src.hasFrame
    self.frameThickness = src.frameThickness
    self.frameColors = table.copy(src.frameColors, math.huge)
    self.frameOverlayVisible = table.copy(src.frameOverlayVisible)

    self.focusId = src.focusId
    self.focusChangeData = table.copy(src.focusChangeData)
    self.focusActive = src.focusActive
    self.isAlwaysFocusedOnOpen = src.isAlwaysFocusedOnOpen

    self.position = table.copy(src.position)
    self.absPosition = table.copy(src.absPosition)
    self.absSize = table.copy(src.absSize)
    self.anchors = table.copy(src.anchors)
    self.pivot = table.copy(src.pivot)
end


---Called on a screen view's root GuiElement when all elements in a screen view have been created.
The event is propagated to all children, depth-first.
function GuiElement:onGuiSetupFinished()
    for _, elem in ipairs(self.elements) do
        elem:onGuiSetupFinished()
    end

    if self.toolTipElementId ~= nil then
        local toolTipElement = self.target:getDescendantById(self.toolTipElementId)
        if toolTipElement ~= nil then
            self.toolTipElement = toolTipElement
        else
            Logging.warning("toolTipElementId '%s' not found for '%s'!", self.toolTipElementId, self.target.name)
        end
    end
end


---Toggle a frame side's visibility identified by index.
If this element has no frame this will have no effect.
-- @param int sideIndex Index of the frame side, use one of GuiElement.FRAME_...
function GuiElement:toggleFrameSide(sideIndex, isVisible)
    if self.hasFrame then
        self.frameOverlayVisible[sideIndex] = isVisible
    end
end


---Update the frame overlay positions if necessary.
function GuiElement:updateFramePosition()
    local x, y = unpack(self.absPosition)
    local width, height = unpack(self.absSize)

    local xPixel = 1 / g_screenWidth
    local yPixel = 1 / g_screenHeight
    width = math.max(width, xPixel)
    height = math.max(height, yPixel)

    if self.frameBounds == nil then
        self.frameBounds = {{}, {}, {}, {}}
    end

    local frameLeft = GuiElement.FRAME_LEFT
    local frameRight = GuiElement.FRAME_RIGHT
    local frameTop = GuiElement.FRAME_TOP
    local frameBottom = GuiElement.FRAME_BOTTOM


    local left = self.frameBounds[frameLeft]
    left.x = x
    left.y = y
    left.width = self.frameThickness[frameLeft]
    left.height = height

    local top = self.frameBounds[frameTop]
    top.x = x
    top.y = y + height - self.frameThickness[frameTop]
    top.width = width
    top.height = self.frameThickness[frameTop]

    local right = self.frameBounds[frameRight]
    right.x = x + width - self.frameThickness[frameRight]
    right.y = y
    right.width = self.frameThickness[frameRight]
    right.height = height

    local bottom = self.frameBounds[frameBottom]
    bottom.x = x
    bottom.y = y
    bottom.width = width
    bottom.height = self.frameThickness[frameBottom]

    self:cutFrameBordersHorizontal(self.frameBounds[frameLeft], self.frameBounds[frameTop], true)
    self:cutFrameBordersHorizontal(self.frameBounds[frameLeft], self.frameBounds[frameBottom], true)
    self:cutFrameBordersHorizontal(self.frameBounds[frameRight], self.frameBounds[frameTop], false)
    self:cutFrameBordersHorizontal(self.frameBounds[frameRight], self.frameBounds[frameBottom], false)

    self:cutFrameBordersVertical(self.frameBounds[frameBottom], self.frameBounds[frameLeft], true)
    self:cutFrameBordersVertical(self.frameBounds[frameBottom], self.frameBounds[frameRight], true)
    self:cutFrameBordersVertical(self.frameBounds[frameTop], self.frameBounds[frameLeft], false)
    self:cutFrameBordersVertical(self.frameBounds[frameTop], self.frameBounds[frameRight], false)
end


---Cut horizontal frame borders if a vertical frame side is thicker.
function GuiElement:cutFrameBordersHorizontal(verticalPart, horizontalPart, isLeft)
    if verticalPart.width > horizontalPart.height then -- equals test for thickness
        if isLeft then
            horizontalPart.x = horizontalPart.x + verticalPart.width
        end

        horizontalPart.width = horizontalPart.width - verticalPart.width
    end
end


---Cut vertical frame borders if a horizontal frame side is thicker.
function GuiElement:cutFrameBordersVertical(horizontalPart, verticalPart, isBottom)
    if horizontalPart.width >= verticalPart.height then -- test for greater or equals here to avoid overlaps when thickness is the same
        if isBottom then
            verticalPart.y = verticalPart.y + horizontalPart.height
        end

        verticalPart.height = verticalPart.height - horizontalPart.height
    end
end


---Mouse event hook for mouse movement checks.
function GuiElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    if eventUsed == nil then
        eventUsed = false
    end

    if self.visible then
        for i=#self.elements, 1, -1 do
            local v = self.elements[i]
            if v:mouseEvent(posX, posY, isDown, isUp, button, eventUsed) then
                eventUsed = true
            end
        end
    end

    return eventUsed
end


---Touch event hook for touch movement checks.
function GuiElement:touchEvent(posX, posY, isDown, isUp, touchId, eventUsed)
    if eventUsed == nil then
        eventUsed = false
    end

    if self.visible then
        for i=#self.elements, 1, -1 do
            local v = self.elements[i]
            if v:touchEvent(posX, posY, isDown, isUp, touchId, eventUsed) then
                eventUsed = true
            end
        end
    end

    return eventUsed
end


---Handles an input event on a menu input action.
Input is first passed to the current GUI view, then to the focused element, then to the focus manager for navigation.
When a GUI element receives input, it should always propagate the input to its parent element first so they may
override behavior and/or set the event used flag. If properly inherited from GuiElement and descendants, this
behavior is guaranteed.
-- @param action Name of input action which was triggered.
-- @param value Input value in the range of [-1, 1] for full axes and [0, 1] for half axes (includes buttons)
-- @param eventUsed If true, the event has been used by an input handler and should only be acted upon in exceptional cases.
-- @return True if the input event has been handled, false otherwise.
function GuiElement:inputEvent(action, value, eventUsed)
    if not eventUsed then
        eventUsed = self.parent and self.parent:inputEvent(action, value, eventUsed)
        if eventUsed == nil then
            eventUsed = false
        end
    end

    return eventUsed
end













---Key event hook for raw keyboard input.
-- @return True if the keyboard input has been processed by this element.
function GuiElement:keyEvent(unicode, sym, modifier, isDown, eventUsed)
    if eventUsed == nil then
        eventUsed = false
    end

    if self.visible then
        for i=#self.elements, 1, -1 do
            local v = self.elements[i]
            if v:keyEvent(unicode, sym, modifier, isDown, eventUsed) then
                eventUsed = true
            end
        end
    end

    return eventUsed
end


---Update this GuiElement.
function GuiElement:update(dt)
    if self.fadeDirection ~= 0 then
        if self.fadeDirection > 0 then
            self:setAlpha(self.alpha + self.fadeDirection * (dt / self.fadeInTime))
        else
            self:setAlpha(self.alpha + self.fadeDirection * (dt / self.fadeOutTime))
        end
    end

    for i = 1, #self.elements do
        local child = self.elements[i]
        if child:getIsActiveNonRec() then
        -- if child:getIsVisibleNonRec() then
            child:update(dt)
        end
    end
end


---Draw this GuiElement.
If defined, triggers the "onDrawCallback".
function GuiElement:draw(clipX1, clipY1, clipX2, clipY2)
    if self.newLayer then
        new2DLayer()
    end

    -- update clip with own element clipping
    clipX1, clipY1, clipX2, clipY2 = self:getClipArea(clipX1, clipY1, clipX2, clipY2)

    self:raiseCallback("onDrawCallback", self)

    if self.debugEnabled or g_uiDebugEnabled then
        local xPixel = 1 / g_screenWidth
        local yPixel = 1 / g_screenHeight

        drawFilledRect(self.absPosition[1] - xPixel, self.absPosition[2] - yPixel, self.absSize[1] + 2 * xPixel, yPixel, 1, 0, 0, 1)
        drawFilledRect(self.absPosition[1] - xPixel, self.absPosition[2] + self.absSize[2], self.absSize[1] + 2 * xPixel, yPixel, 1, 0, 0, 1)
        drawFilledRect(self.absPosition[1] - xPixel, self.absPosition[2], xPixel, self.absSize[2], 1, 0, 0, 1)
        drawFilledRect(self.absPosition[1] + self.absSize[1], self.absPosition[2], xPixel, self.absSize[2], 1, 0, 0, 1)
    end

    for i = 1, #self.elements do
        local child = self.elements[i]
        if child:getIsVisibleNonRec() then
            -- Clip beforehand so not every element class has to do it
            child:draw(child:getClipArea(clipX1, clipY1, clipX2, clipY2))
        end
    end

    if self.hasFrame then
        for i = 1, 4 do
            if self.frameOverlayVisible[i] then
                local frame = self.frameBounds[i]
                local color = self.frameColors[i]

                drawFilledRect(frame.x, frame.y, frame.width, frame.height, color[1], color[2], color[3], color[4], clipX1, clipY1, clipX2, clipY2)
            end
        end
    end

    if g_uiFocusDebugEnabled and self.focusId ~= nil and self:canReceiveFocus() then
        setTextColor(1, 0, 0, 1)
        local size = 0.008
        local y = self.absPosition[2] + self.absSize[2]
        renderText(self.absPosition[1], y-1*size, size, " FocusId: " .. tostring(self.focusId) .. " " .. tostring(ClassUtil.getClassNameByObject(self)))
        renderText(self.absPosition[1], y-2*size, size, " T: " .. tostring(self.focusChangeData[FocusManager.TOP]))
        renderText(self.absPosition[1], y-3*size, size, " B: " .. tostring(self.focusChangeData[FocusManager.BOTTOM]))
        renderText(self.absPosition[1], y-4*size, size, " L: " .. tostring(self.focusChangeData[FocusManager.LEFT]))
        renderText(self.absPosition[1], y-5*size, size, " R: " .. tostring(self.focusChangeData[FocusManager.RIGHT]))

        setTextColor(1, 1, 1, 1)
    end
end


---Called on the root element of a screen view when it is opened.
This raises the "onOpenCallback" if defined and propagates to all children.
function GuiElement:onOpen()
    self:raiseCallback("onOpenCallback", self)
    for i = 1, #self.elements do
        local child = self.elements[i]
        child:onOpen()
    end
end


---Called on the root element of a screen view when it is closed.
This raises the "onCloseCallback" if defined and propagates to all children.
function GuiElement:onClose()
    self:raiseCallback("onCloseCallback", self)
    for i = 1, #self.elements do
        local child = self.elements[i]
        child:onClose()
    end
end


---Determine if this GuiElement should change focus in a given direction.
function GuiElement:shouldFocusChange(direction)
    -- focus should only change if all sub elements allow the change
    for _, v in ipairs(self.elements) do
        if (not v:shouldFocusChange(direction)) then
            return false
        end
    end

    return true
end


---Determine if this GuiElement can receive focus.
function GuiElement:canReceiveFocus()
    return false -- default is not focusable, subclasses need to make themselves available
end


---Called when this element loses focus.
This propagates to all children.
function GuiElement:onFocusLeave()
    for i = 1, #self.elements do
        local child = self.elements[i]
        child:onFocusLeave()
    end

    if self.toolTipElement ~= nil and self.toolTipText ~= nil then
        self.toolTipElement:setText("")
    end
end


---Called when this element becomes focused.
This propagates to all children.
function GuiElement:onFocusEnter()
    for i = 1, #self.elements do
        local child = self.elements[i]
        child:onFocusEnter()
    end

    if self.toolTipElement ~= nil and self.toolTipText ~= nil then
        self.toolTipElement:setText(self.toolTipText)
    end
end


---Called when this element has focus and the focus activation action is triggered.
This propagates to all children.
function GuiElement:onFocusActivate()
    for i = 1, #self.elements do
        local child = self.elements[i]
        if child.handleFocus then
            child:onFocusActivate()
        end
    end
end


---Called when this element is highlighted.
This propagates to all children.
function GuiElement:onHighlight()
    for i = 1, #self.elements do
        local child = self.elements[i]
        child:onHighlight()
    end

    if self.toolTipElement ~= nil and self.toolTipText ~= nil then
        self.toolTipElement:setText(self.toolTipText)
    end
end


---Called when this element loses the highlight.
This propagates to all children.
function GuiElement:onHighlightRemove()
    for i = 1, #self.elements do
        local child = self.elements[i]
        child:onHighlightRemove()
    end

    if self.toolTipElement ~= nil and self.toolTipText ~= nil then
        self.toolTipElement:setText("")
    end
end



---Store the current overlay state while another overrides it (e.g. pressed state)
function GuiElement:storeOverlayState()
    self.previousOverlayState = self:getOverlayState()
end


---Restore a previously stored overlay state after an overriding state has expired
function GuiElement:restoreOverlayState()
    if self.previousOverlayState then -- restore overlay state from before
        self:setOverlayState(self.previousOverlayState)
        self.previousOverlayState = nil
    end
end


---Determine if this element can receive focus.
function GuiElement:getHandleFocus()
    return self.handleFocus
end


---Set this elements capability to receive focus.
function GuiElement:setHandleFocus(handleFocus)
    self.handleFocus = handleFocus
end


---Add a child GuiElement to this GuiElement.
function GuiElement:addElement(element)
    if element.parent ~= nil then
        element.parent:removeElement(element)
    end

    table.insert(self.elements, element)
    element.parent = self
end


---Remove a child GuiElement from this GuiElement.
function GuiElement:removeElement(element)
    for i = 1, #self.elements do
        local child = self.elements[i]
        if child == element then
            table.remove(self.elements, i)
            element.parent = nil
            break
        end
    end
end


---Safely remove this GuiElement from its parent, if it has a parent.
function GuiElement:unlinkElement()
    if self.parent ~= nil then
        self.parent:removeElement(self)
    end
end


---Update this elements absolute screen position.
This needs to be called whenever a position, alignment, origin or size value changes.
function GuiElement:updateAbsolutePosition()
    local borders = self:getParentBorders()

    -- Get absolute anchor position
    local ax1 = borders[1] + (borders[3] - borders[1]) * self.anchors[1]
    local ax2 = borders[1] + (borders[3] - borders[1]) * self.anchors[2]
    local ay1 = borders[2] + (borders[4] - borders[2]) * self.anchors[3]
    local ay2 = borders[2] + (borders[4] - borders[2]) * self.anchors[4]


    local tlX = ax1 + self.position[1]
    local tlY = ay1 + self.position[2]
    local trX = ax2 + self.position[1]
    local blY = ay2 + self.position[2]

    local isStretchingX = self.anchors[1] < self.anchors[2]
    local isStretchingY = self.anchors[3] < self.anchors[4]

    local width = self.size[1]
    local height = self.size[2]

    if not isStretchingX then
        if self.pivot ~= nil then
            tlX = tlX - width * self.pivot[1]
            trX = trX + width - width * self.pivot[1]
        else
            tlX = tlX - width * self.anchors[1]
            trX = trX + width - width * self.anchors[2]
        end
    end

    if not isStretchingY then
        if self.pivot ~= nil then
            tlY = tlY - height * self.pivot[2]
            blY = blY + height - height * self.pivot[2]
        else
            tlY = tlY - height * self.anchors[3]
            blY = blY + height - height * self.anchors[4]
        end
    end

    self.absPosition[1] = tlX
    self.absPosition[2] = tlY

    self.absSize[1] = trX - tlX
    self.absSize[2] = blY - tlY


    for i = 1, #self.elements do
        self.elements[i]:updateAbsolutePosition()
    end

    if self.hasFrame then
        self:updateFramePosition()
    end
end


---Resets the state of this GuiElement and its children.
function GuiElement:reset()
    for i = 1, #self.elements do
        self.elements[i]:reset()
    end
end


---Check if this element is the child of another element.
This checks the full parent hierarchy.
function GuiElement:isChildOf(element)
    if element == self then
        return false
    end

    local p = self.parent
    while p do
        if p == self then
            return false
        end

        if p == element then
            return true
        end

        p = p.parent
    end

    return false
end


---Get the actual focus target, in case a child or parent element needs to be targeted instead.
-- @param incomingDirection (Optional) If specified, may return different targets for different incoming directions.
-- @param moveDirection (Optional) Actual movement direction per input. This is the opposing direction of incomingDirection.
-- @return GuiElement Actual element to focus.
function GuiElement:getFocusTarget(incomingDirection, moveDirection)
    return self
end


---Set this element's position.
function GuiElement:setPosition(x, y)
    self.position[1] = Utils.getNoNil(x, self.position[1])
    self.position[2] = Utils.getNoNil(y, self.position[2])
    self:updateAbsolutePosition()
end


---Modify this element's position (i.e. translate position).
function GuiElement:move(dx, dy)
    self.position[1] = self.position[1] + dx
    self.position[2] = self.position[2] + dy
    self:updateAbsolutePosition()
end


---Directly set the absolute screen position of this GuiElement.
Also updates children accordingly.
function GuiElement:setAbsolutePosition(x, y)
    local xDif = x - self.absPosition[1]
    local yDif = y - self.absPosition[2]
    self.absPosition[1] = x
    self.absPosition[2] = y

    for i = 1, #self.elements do
        local child = self.elements[i]
        child:setAbsolutePosition(child.absPosition[1] + xDif, child.absPosition[2] + yDif)
    end

    if self.hasFrame then
        self:updateFramePosition()
    end
end


---Set this element's size.
function GuiElement:setSize(x, y)
    x = Utils.getNoNil(x, self.size[1])
    y = Utils.getNoNil(y, self.size[2])

    if self.thinLineProtection then
        if x ~= 0 then
            x = math.max(x, 1 / g_screenWidth)
        end

        if y ~= 0 then
            y = math.max(y, 1 / g_screenHeight)
        end
    end

    self.size[1] = x
    self.size[2] = y
    self:updateAbsolutePosition()
end


---Set this element's visibility.
function GuiElement:setVisible(visible)
    self.visible = visible
end


---Determine if this element is visible.
This checks both its current alpha value (set by fadeIn() / fadeOut()) as well as the visibility flag. If the parent
is invisible, then so is this element.
function GuiElement:getIsVisible()
    if not self.visible or self.alpha == 0 then
        return false
    end

    if self.parent ~= nil then
        return self.parent:getIsVisible()
    end

    return true
end


---Determine if this element is visible without checking the parents
function GuiElement:getIsVisibleNonRec()
    return self.visible and self.alpha > 0
end


---Set this element's disabled state.
Disabled elements can be displayed differently and do not respond to input actions.
-- @param disabled If true, disables the element. False enables it again.
-- @param doNotUpdateChildren If true, does not apply the disabled state to child elements.
function GuiElement:setDisabled(disabled, doNotUpdateChildren)
    self.disabled = disabled
    if doNotUpdateChildren == nil or not doNotUpdateChildren then
        for i=1, #self.elements do
            self.elements[i]:setDisabled(disabled)
        end
    end
end


---Determine if this element is disabled.
function GuiElement:getIsDisabled()
    return self.disabled
end


---Determine if this element is currently selected.
function GuiElement:getIsSelected()
    if self.parent ~= nil then
        return self.parent:getIsSelected()
    end

    return false
end


---Determine if this element is currently highlighted.
function GuiElement:getIsHighlighted()
    if self.parent ~= nil then
        return self.parent:getIsHighlighted()
    end

    return false
end


---Fade this element into visibility.
function GuiElement:fadeIn(factor)
    if self.fadeInTime > 0 then
        self.fadeDirection = 1 * Utils.getNoNil(factor, 1)
        self:setAlpha(math.max(self.alpha, 0.0001)) -- Ensure that we are considered visible and get an update
    else
        self.fadeDirection = 0
        self:setAlpha(1)
    end
end


---Fade this element out of visibility.
function GuiElement:fadeOut(factor)
    if self.fadeOutTime > 0 then
        self.fadeDirection = -1 * Utils.getNoNil(factor, 1)
    else
        self.fadeDirection = 0
        self:setAlpha(0)
    end
end


---Directly set this element's alpha (transparency) value
-- @param alpha Transparency value in the floating point range of [0, 1], where 0 is invisible and 1 is opaque.
function GuiElement:setAlpha(alpha)
    if alpha ~= self.alpha then

        self.alpha = MathUtil.clamp(alpha, 0, 1)
        for _, childElem in pairs(self.elements) do
            childElem:setAlpha(self.alpha)
        end

        if self.alpha == 1 or self.alpha == 0 then
            self.fadeDirection = 0
        end
    end
end


---Determine if this element is active (not disabled and visible).
function GuiElement:getIsActive()
    return not self.disabled and self:getIsVisible()
end


---Determine if this element is active (not disabled and visible) without checking the parents
function GuiElement:getIsActiveNonRec()
    return not self.disabled and self:getIsVisibleNonRec()
end


---Update given clip area with clip settings
function GuiElement:getClipArea(clipX1, clipY1, clipX2, clipY2)
    if self.clipping then
        clipX1 = math.max(clipX1 or 0, self.absPosition[1])
        clipY1 = math.max(clipY1 or 0, self.absPosition[2])
        clipX2 = math.min(clipX2 or 1, self.absPosition[1] + self.absSize[1])
        clipY2 = math.min(clipY2 or 1, self.absPosition[2] + self.absSize[2])
    end

    return clipX1, clipY1, clipX2, clipY2
end


---Toggle a flag to suppress UI sounds issued by this element or by the FocusManager when handling this element.
This setting will propagate to children.
function GuiElement:setSoundSuppressed(doSuppress)
    self.isSoundSuppressed = doSuppress

    for _, child in pairs(self.elements) do
        child:setSoundSuppressed(doSuppress)
    end
end


---Get the sound suppression flag from this element.
If the flag is set to true, no sounds should be played when interacting with this element.
function GuiElement:getSoundSuppressed()
    return self.isSoundSuppressed
end



---Recursively add descendant elements of a root to an accumulator list. If a predicate function is given, it is
evaluated per element and only elements which yield a true value for the function are added to the accumulator.
-- @param accumulator List which receives descendant elements
-- @param rootElement Current element root whose direction children are added (after optional evaluation)
-- @param predicateFunction [optional] If specified, will be evaluated per element (see getDescendants)
function GuiElement:findDescendantsRec(accumulator, rootElement, predicateFunction)
    if not rootElement then return end -- safety
    for _, element in ipairs(rootElement.elements) do
        self:findDescendantsRec(accumulator, element, predicateFunction) -- depth first
        if not predicateFunction or predicateFunction(element) then
            table.insert(accumulator, element)
        end
    end
end


---Get all contained elements of this element in the entire hierarchy.
Descendants are traversed depth-first, meaning that if elements have been properly added, the element order mirrors
the order in the XML configuration (lines). Use this method sparingly, especially on high-level elements.
Optionally, a predicate function can be passed which filters descendant elements. The function must return true for
any desired element and false otherwise.
-- @param predicateFunction [optional] A function which determines if a descendant element should be returned. Must
take a GuiElement as an argument and return true if that element should be returned or false otherwise.
-- @return List of this element's descendants in depth-first order with contiguous numeric indices.
function GuiElement:getDescendants(predicateFunction)
    local descendants = {}
    self:findDescendantsRec(descendants, self, predicateFunction)
    return descendants
end

















---Get the first descendant element of this element which matches a predicate function.
This is a shorthand for getDescendants() which returns just the first element matching the predicate function or nil
if no matching element exists.
-- @param predicateFunction A function which determines if a descendant element should be returned. Must take a
GuiElement as an argument and return true if that element should be returned or false otherwise.
-- @return First matching descendant element in depth-first order or nil, if no element matched the predicate function
function GuiElement:getFirstDescendant(predicateFunction)
    local element = nil
    local res = self:getDescendants(predicateFunction)
    if #res > 0 then
        element = res[1]
    end
    return element
end


---Get a descendant element of this element by its ID.
This is a shorthand for getDescendants() with an ID matching predicate function.
-- @param id Element id
-- @return Element or nil
function GuiElement:getDescendantById(id)
    local element = nil
    if id then
        local function findId(e)
            return e.id and e.id == id
        end

        element = self:getFirstDescendant(findId)
    end
    return element
end


---Get a descendant element of this element by its name.
This is a shorthand for getDescendants() with an ID matching predicate function.
-- @param name Element name
-- @return Element or nil
function GuiElement:getDescendantByName(name)
    local element = nil
    if name then
        local function findId(e)
            return e.name and e.name == name
        end

        element = self:getFirstDescendant(findId)
    end
    return element
end


---Get the bit mask value for a position origin string value.
function GuiElement:updatePositionForOrigin(origin)
    if origin == "topLeft" then
        -- self.positionOrigin = GuiElement.ORIGIN_TOP + GuiElement.ORIGIN_LEFT
        self.pivot = {0, 0}
    elseif origin == "topCenter" then
        -- self.positionOrigin = GuiElement.ORIGIN_CENTER + GuiElement.ORIGIN_TOP
        self.pivot = {0.5, 0}
    elseif origin == "topRight" then
        -- self.positionOrigin = GuiElement.ORIGIN_RIGHT + GuiElement.ORIGIN_TOP
        self.pivot = {1, 0}
    elseif origin == "middleLeft" then
        -- self.positionOrigin = GuiElement.ORIGIN_MIDDLE + GuiElement.ORIGIN_LEFT
        self.pivot = {0, 0.5}
    elseif origin == "middleCenter" then
        -- self.positionOrigin = GuiElement.ORIGIN_CENTER + GuiElement.ORIGIN_MIDDLE
        self.pivot = {0.5, 0.5}
    elseif origin == "middleRight" then
        -- self.positionOrigin = GuiElement.ORIGIN_RIGHT + GuiElement.ORIGIN_MIDDLE
        self.pivot = {1, 0.5}
    elseif origin == "bottomCenter" then
        -- self.positionOrigin = GuiElement.ORIGIN_CENTER + GuiElement.ORIGIN_BOTTOM
        self.pivot = {0, 1}
    elseif origin == "bottomRight" then
        -- self.positionOrigin = GuiElement.ORIGIN_RIGHT + GuiElement.ORIGIN_BOTTOM
        self.pivot = {0.5, 1}
    else -- bottomLeft
        -- self.positionOrigin = GuiElement.ORIGIN_BOTTOM + GuiElement.ORIGIN_LEFT
        self.pivot = {1, 1}
    end
end


---Get the bit mask value for a screen alignment string value.
function GuiElement:updateScreenAlign(align)
    if align == "topLeft" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_LEFT + GuiElement.SCREEN_ALIGN_TOP
        self:setAnchor(0, 1)
    elseif align == "topCenter" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_CENTER + GuiElement.SCREEN_ALIGN_TOP
        self:setAnchor(0.5, 1)
    elseif align == "topRight" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_RIGHT + GuiElement.SCREEN_ALIGN_TOP
        self:setAnchor(1, 1)
    elseif align == "middleLeft" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_LEFT + GuiElement.SCREEN_ALIGN_MIDDLE
        self:setAnchor(0, 0.5)
    elseif align == "middleCenter" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_CENTER + GuiElement.SCREEN_ALIGN_MIDDLE
        self:setAnchor(0.5, 0.5)
    elseif align == "middleRight" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_RIGHT + GuiElement.SCREEN_ALIGN_MIDDLE
        self:setAnchor(1, 0.5)
    elseif align == "bottomLeft" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_LEFT + GuiElement.SCREEN_ALIGN_BOTTOM
        self:setAnchor(0, 0)
    elseif align == "bottomCenter" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_CENTER + GuiElement.SCREEN_ALIGN_BOTTOM
        self:setAnchor(0.5, 0)
    elseif align == "bottomRight" then
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_RIGHT + GuiElement.SCREEN_ALIGN_BOTTOM
        self:setAnchor(1, 0)
    else
        self:setAnchors(0, 1, 0, 1)
        -- self.screenAlign = GuiElement.SCREEN_ALIGN_XNONE + GuiElement.SCREEN_ALIGN_YNONE
    end
end












---
function GuiElement:fixThinLines()
    if self.thinLineProtection then
        if self.size[1] ~= 0 then
            self.size[1] = math.max(self.size[1], 1 / g_screenWidth)
        end

        if self.size[2] ~= 0 then
            self.size[2] = math.max(self.size[2], 1 / g_screenHeight)
        end

        self:updateAbsolutePosition()
    end
end


---Get the bottom left and top right corners of this element's parent's border rectangle.
If this element has no parent, the full screen's borders are returned (i.e. {0, 0, 1, 1})
-- @return Parent element or full screen borders in an array: {minX, minY, maxX, maxY}
function GuiElement:getParentBorders()
    if self.parent ~= nil then
        return self.parent:getBorders()
    end

    return self.parentBorders
end


---Get this element's border rectangle represented by minimum and maximum points.
-- @return Element borders in an array: {minX, minY, maxX, maxY}
function GuiElement:getBorders()
    self.borders[1] = self.absPosition[1]
    self.borders[2] = self.absPosition[2]
    self.borders[3] = self.absPosition[1] + self.absSize[1]
    self.borders[4] = self.absPosition[2] + self.absSize[2]
    return self.borders
end


---Get this element's center position.
function GuiElement:getCenter()
    self.center[1] = self.absPosition[1] + self.absSize[1] * 0.5
    self.center[2] = self.absPosition[2] + self.absSize[2] * 0.5
    return self.center
end


---Get aspect scaling values for this element's settings and the game's resolution.
-- @return float X aspect scale factor
-- @return float Y aspect scale factor
function GuiElement:getAspectScale()
    return g_aspectScaleX, g_aspectScaleY
end


---Apply element aspect scale transformations.
-- @param bool ignorePosition If true, will not apply aspect scaling to this element's position
function GuiElement:applyElementAspectScale(ignorePosition)
    local scaleX, scaleY = self:getAspectScale()

    self.size[1] = self.size[1] * scaleX
    self.margin[1] = self.margin[1] * scaleX
    self.margin[3] = self.margin[3] * scaleX

    self.size[2] = self.size[2] * scaleY
    self.margin[2] = self.margin[2] * scaleY
    self.margin[4] = self.margin[4] * scaleY

    if not ignorePosition then
        self.position[1] = self.position[1] * scaleX
        self.position[2] = self.position[2] * scaleY
    end
end


---Apply screen alignment to this element and its children.
Scales size, position and margin depending on alignment settings.
function GuiElement:applyScreenAlignment()
    self:applyElementAspectScale()

    for _,child in ipairs(self.elements) do
        child:applyScreenAlignment()
    end
end


---Set this element's overlay state
-- @param overlayState Overlay state identified by one of the GuiOverlay.STATE_[...] constants.
function GuiElement:setOverlayState(overlayState)
    self.overlayState = overlayState
    if self.updateChildrenOverlayState then
        for _, child in ipairs(self.elements) do
            child:setOverlayState(overlayState)
        end
    end
end


---Get this element's overlay state.
function GuiElement:getOverlayState()
    return self.overlayState
end


---Add a callback to this element which was defined in its XML definition.
If this element has a target, the given function name will be called on the target. Otherwise, the function is
assumed to be global.
-- @param xmlFile XML file handle
-- @param key XML node path of this GuiElement's definition.
-- @param funcName Name of the callback function
function GuiElement:addCallback(xmlFile, key, funcName)
    local callbackName = getXMLString(xmlFile, key)
    if callbackName ~= nil then
        if self.target ~= nil then
            self[funcName] = self.target[callbackName]
        else
            self[funcName] = ClassUtil.getFunction(callbackName)
        end
    end
end










---Raise a previously added callback by name.
function GuiElement:raiseCallback(name, ...)
    if self[name] ~= nil then
        if self.target ~= nil then
            return self[name](self.target, ...)
        else
            return self[name](...)
        end
    end
    return nil
end


---Try to extract a field name and index from an element ID.
IDs in configurations may be indexed on definition (e.g. fillTypes[2]). This function extracts the list name and
index if such a case is found. Otherwise, it will return no index and the original element ID.
-- @param elementId Element ID, to be used as a field name on a ScreenElement view.
-- @return Index or nil, field name
function GuiElement.extractIndexAndNameFromID(elementId)
    local len = elementId:len()
    local varName = elementId
    local index = nil
    if len >= 4 and elementId:sub(len, len) == "]" then
        local startI = elementId:find("[", 1, true)
        if startI ~= nil and startI > 1 and startI < len-1 then
            index = Utils.evaluateFormula(elementId:sub(startI + 1, len - 1))
            if index ~= nil then
                varName = elementId:sub(1, startI - 1)
            end
        end
    end
    return index, varName
end


---Try setting this element's ID from its XML definition.
function GuiElement:setId(xmlFile, key)
    local id = getXMLString(xmlFile, key.."#id")
    if id ~= nil then
        local valid = true

        local _, varName = GuiElement.extractIndexAndNameFromID(id)

        if varName:find("[^%w_]") ~= nil then
            print("Error: Invalid gui element id "..id)
            valid = false
        end

        if valid then
            self.id = id
        end
    end
end


---Include a mixin in this element.
See GuiMixin.lua for the details on usage and implementation of mixins.
-- @param guiMixinType Class table reference of a descendant of GuiMixin
function GuiElement:include(guiMixinType)
    guiMixinType.new():addTo(self)
end

















































---Get a nice string representation for this GUI element.
function GuiElement:toString()
    return string.format(
        "[ID: %s, FocusID: %s, GuiProfile: %s, Position: %g, %g]",
        tostring(self.id),
        tostring(self.focusId),
        tostring(self.profile),
        self.absPosition[1], self.absPosition[2]
    )
end
