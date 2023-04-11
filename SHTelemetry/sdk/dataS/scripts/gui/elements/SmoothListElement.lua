

















local SmoothListElement_mt = Class(SmoothListElement, GuiElement)


---
function SmoothListElement.new(target, custom_mt)
    local self = SmoothListElement:superClass().new(target, custom_mt or SmoothListElement_mt)
    self:include(IndexChangeSubjectMixin) -- add index change subject mixin for index state observers
    self:include(PlaySampleMixin) -- add sound playing

    self.dataSource = nil
    self.delegate = nil

    self.cellCache = {}
    self.sections = {}

    self.isLoaded = false

    self.clipping = true

    self.sectionHeaderCellName = nil
    self.isHorizontalList = false
    self.numLateralItems = 1
    self.listItemSpacing = 0
    self.listItemLateralSpacing = 0

    self.lengthAxis = 2
    self.widthAxis = 1

    self.viewOffset = 0
    self.targetViewOffset = 0
    self.contentSize = 0
    self.totalItemCount = 0
    self.scrollViewOffsetDelta = 0
    self.selectedIndex = 1
    self.selectedSectionIndex = 1

    self.supportsMouseScrolling = true
    self.doubleClickInterval = 400
    self.selectOnClick = false
    self.ignoreMouse = false
    self.showHighlights = false
    self.selectOnScroll = false
    self.itemizedScrollDelta = false
    self.listSmoothingDisabled = false
    self.selectedWithoutFocus = true -- whether selection is visible even without focus

    self.lastTouchPos = nil
    self.usedTouchId = nil
    self.currentTouchDelta = 0
    self.scrollSpeed = 0
    self.initialScrollSpeed = 0
    self.scrollSpeedPixelPerMS = 0.005
    if self.isHorizontalList then
        self.scrollSpeedInterval = self.scrollSpeedPixelPerMS / g_screenWidth
    else
        self.scrollSpeedInterval = self.scrollSpeedPixelPerMS / g_screenHeight
    end
    self.supportsTouchScrolling = false

    return self
end


---
function SmoothListElement:loadFromXML(xmlFile, key)
    SmoothListElement:superClass().loadFromXML(self, xmlFile, key)

    self:addCallback(xmlFile, key.."#onScroll", "onScrollCallback")
    self:addCallback(xmlFile, key.."#onDoubleClick", "onDoubleClickCallback")
    self:addCallback(xmlFile, key.."#onClick", "onClickCallback")

    self.isHorizontalList = Utils.getNoNil(getXMLBool(xmlFile, key.."#isHorizontalList"), self.isHorizontalList)
    self.lengthAxis = self.isHorizontalList and 1 or 2
    self.widthAxis = self.isHorizontalList and 2 or 1

    self.numLateralItems = Utils.getNoNil(getXMLInt(xmlFile, key.."#numLateralItems"), self.numLateralItems)
    self.listItemSpacing = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemSpacing"), {self.outputSize[self.lengthAxis]}, {self.listItemSpacing}))
    self.listItemLateralSpacing = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemLateralSpacing"), {self.outputSize[self.widthAxis]}, {self.listItemLateralSpacing}))

    self.supportsMouseScrolling = Utils.getNoNil(getXMLBool(xmlFile, key.."#supportsMouseScrolling"), self.supportsMouseScrolling)
    self.supportsTouchScrolling = Utils.getNoNil(getXMLBool(xmlFile, key.."#supportsTouchScrolling"), self.supportsTouchScrolling)
    self.doubleClickInterval = Utils.getNoNil(getXMLInt(xmlFile, key.."#doubleClickInterval"), self.doubleClickInterval)
    self.selectOnClick = Utils.getNoNil(getXMLBool(xmlFile, key .. "#selectOnClick"), self.selectOnClick)
    self.ignoreMouse = Utils.getNoNil(getXMLBool(xmlFile, key .. "#ignoreMouse"), self.ignoreMouse)
    self.showHighlights = Utils.getNoNil(getXMLBool(xmlFile, key .. "#showHighlights"), self.showHighlights)
    self.selectOnScroll = Utils.getNoNil(getXMLBool(xmlFile, key .. "#selectOnScroll"), self.selectOnScroll)
    self.itemizedScrollDelta = Utils.getNoNil(getXMLBool(xmlFile, key .. "#itemizedScrollDelta"), self.itemizedScrollDelta)
    self.listSmoothingDisabled = Utils.getNoNil(getXMLBool(xmlFile, key .. "#listSmoothingDisabled"), self.listSmoothingDisabled)
    self.selectedWithoutFocus = Utils.getNoNil(getXMLBool(xmlFile, key .. "#selectedWithoutFocus"), self.selectedWithoutFocus)

    local delegateName = getXMLString(xmlFile, key .. "#listDelegate")
    if delegateName == "self" then
        self.delegate = self.target
    elseif delegateName ~= "nil" then
        self.delegate = self.target[delegateName]
    end

    local dataSourceName = getXMLString(xmlFile, key .. "#listDataSource")
    if dataSourceName == "self" then
        self.dataSource = self.target
    elseif delegateName ~= "nil" then
        self.dataSource = self.target[dataSourceName]
    end

    self.sectionHeaderCellName = getXMLString(xmlFile, key .. "#listSectionHeader")
    self.startClipperElementName = getXMLString(xmlFile, key.."#startClipperElementName")
    self.endClipperElementName = getXMLString(xmlFile, key.."#endClipperElementName")

    self.updateChildrenOverlayState = false
end


---
function SmoothListElement:loadProfile(profile, applyProfile)
    SmoothListElement:superClass().loadProfile(self, profile, applyProfile)

    self.isHorizontalList = profile:getBool("isHorizontalList", self.isHorizontalList)
    self.lengthAxis = self.isHorizontalList and 1 or 2
    self.widthAxis = self.isHorizontalList and 2 or 1

    self.numLateralItems = profile:getNumber("numLateralItems", self.numLateralItems)
    self.listItemSpacing = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemSpacing"), {self.outputSize[self.lengthAxis]}, {self.listItemSpacing}))
    self.listItemLateralSpacing = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemLateralSpacing"), {self.outputSize[self.widthAxis]}, {self.listItemLateralSpacing}))

    self.supportsMouseScrolling = profile:getBool("supportsMouseScrolling", self.supportsMouseScrolling)
    self.doubleClickInterval = profile:getNumber("doubleClickInterval", self.doubleClickInterval)
    self.selectOnClick = profile:getBool("selectOnClick", self.selectOnClick)
    self.ignoreMouse = profile:getBool("ignoreMouse", self.ignoreMouse)
    self.showHighlights = profile:getBool("showHighlights", self.showHighlights)
    self.selectOnScroll = profile:getBool("selectOnScroll", self.selectOnScroll)
    self.itemizedScrollDelta = profile:getBool("itemizedScrollDelta", self.itemizedScrollDelta)
    self.listSmoothingDisabled = profile:getBool("listSmoothingDisabled", self.listSmoothingDisabled)
    self.selectedWithoutFocus = profile:getBool("selectedWithoutFocus", self.selectedWithoutFocus)
    self.supportsTouchScrolling = profile:getBool("supportsTouchScrolling", self.supportsTouchScrolling)
end




































---
function SmoothListElement:copyAttributes(src)
    SmoothListElement:superClass().copyAttributes(self, src)

    self.dataSource = src.dataSource
    self.delegate = src.delegate

    self.singularCellName = src.singularCellName

    self.sectionHeaderCellName = src.sectionHeaderCellName
    self.startClipperElementName = src.startClipperElementName
    self.endClipperElementName = src.endClipperElementName

    self.isHorizontalList = src.isHorizontalList
    self.numLateralItems = src.numLateralItems
    self.listItemSpacing = src.listItemSpacing
    self.listItemLateralSpacing = src.listItemLateralSpacing

    self.supportsMouseScrolling = src.supportsMouseScrolling
    self.doubleClickInterval = src.doubleClickInterval
    self.selectOnClick = src.selectOnClick
    self.ignoreMouse = src.ignoreMouse
    self.showHighlights = src.showHighlights
    self.itemizedScrollDelta = src.itemizedScrollDelta
    self.selectOnScroll = src.selectOnScroll
    self.listSmoothingDisabled = src.listSmoothingDisabled
    self.selectedWithoutFocus = src.selectedWithoutFocus

    self.lengthAxis = src.lengthAxis
    self.widthAxis = src.widthAxis

    self.onScrollCallback = src.onScrollCallback
    self.onDoubleClickCallback = src.onDoubleClickCallback
    self.onClickCallback = src.onClickCallback

    self.supportsTouchScrolling = src.supportsTouchScrolling

    self.isLoaded = src.isLoaded

    GuiMixin.cloneMixin(PlaySampleMixin, src, self)
end


---
function SmoothListElement:onGuiSetupFinished()
    SmoothListElement:superClass().onGuiSetupFinished(self)

    if self.startClipperElementName ~= nil then
        self.startClipperElement = self.parent:getDescendantByName(self.startClipperElementName)
    end
    if self.endClipperElementName ~= nil then
        self.endClipperElement = self.parent:getDescendantByName(self.endClipperElementName)
    end

    if not self.isLoaded then
        self:buildCellDatabase()

        self.isLoaded = true
    end
end












































































---
function SmoothListElement:delete()
    for name, elements in pairs(self.cellCache) do
        for _, element in ipairs(elements) do
            element:delete()
        end
    end

    for name, element in pairs(self.cellDatabase) do
        element:delete()
    end

    SmoothListElement:superClass().delete(self)
end


























































































































































































































































































































































































































































































































































































































































---Apply visual list item selection state based on the current data selection.
function SmoothListElement:applyElementSelection()
    local focusAllowed = self.selectedWithoutFocus or FocusManager:getFocusedElement() == self

    for i = 1, #self.elements do
        local element = self.elements[i]

        if element.setSelected ~= nil then
            element:setSelected(focusAllowed and element.sectionIndex == self.selectedSectionIndex and element.indexInSection == self.selectedIndex)
        end
    end
end


---Remove element selection state on all elements (e.g. when losing focus).
function SmoothListElement:clearElementSelection()
    for i = 1, #self.elements do
        local element = self.elements[i]

        if element.setSelected ~= nil then
            element:setSelected(false)
        end
    end
end






























































































































---Get the number of list items in the list's data source. Includes section headers.
-- @return Number of list items in data source
function SmoothListElement:getItemCount()
    return self.totalItemCount
end





































































---Handles mouse button down event
function SmoothListElement:onMouseDown()
    self.mouseDown = true

    FocusManager:setFocus(self)
end


---Handles mouse button up (after down) event
function SmoothListElement:onMouseUp()
    if self.mouseOverElement ~= nil then
        local previousSection, previousIndex = self.selectedSectionIndex, self.selectedIndex
        local clickedSection, clickedIndex = self.mouseOverElement.sectionIndex, self.mouseOverElement.indexInSection
        local notified = false

        self:setSelectedItem(clickedSection, clickedIndex, nil, 0)

        if self.lastClickTime ~= nil and self.lastClickTime > self.target.time - self.doubleClickInterval then
    --         -- Only activate click if the target was hit
            if clickedSection == previousSection and clickedIndex == previousIndex then
                self:notifyDoubleClick(clickedSection, clickedIndex, self.mouseOverElement)
                notified = true
            end
            self.lastClickTime = nil
        else
            self.lastClickTime = self.target.time
        end

        if not self.selectOnClick and not notified then
            self:notifyClick(clickedSection, clickedIndex, self.mouseOverElement)
        end
    else
        self.lastClickTime = nil
    end

    self.mouseDown = false
end


---
function SmoothListElement:notifyDoubleClick(section, index, element)
    self:raiseCallback("onDoubleClickCallback", self, section, index, element)
end


---
function SmoothListElement:notifyClick(section, index, element)
    self:raiseCallback("onClickCallback", self, section, index, element)
end


---Handle mouse input
function SmoothListElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    if self:getIsActive() and not self.ignoreMouse then
        if SmoothListElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed) then
            eventUsed = true
        end

        if not eventUsed and GuiUtils.checkOverlayOverlap(posX, posY, self.absPosition[1], self.absPosition[2], self.absSize[1], self.absSize[2]) then
            local mouseOverElement = self:getElementAtScreenPosition(posX, posY)
            if mouseOverElement ~= nil and mouseOverElement.indexInSection == 0 then
                mouseOverElement = nil
            end

            -- Mouse over changed
            if self.mouseOverElement ~= mouseOverElement then
                self:setHighlightedItem(mouseOverElement)
                self.mouseOverElement = mouseOverElement
            end

            if isDown then
                if button == Input.MOUSE_BUTTON_LEFT then
                    self:onMouseDown()
                    eventUsed = true
                end

                if self.supportsMouseScrolling then
                    local deltaIndex = 0
                    if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                        deltaIndex = -1
                    elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                        deltaIndex = 1
                    end

                    if deltaIndex ~= 0 then
                        if self.selectOnScroll then
                            -- Fast code for just 1 section as it is easy. If need arises we can expand to support multiple sections
                            if #self.sections == 1 then
                                local newIndex = math.max(1, math.min(self.sections[1].numItems, self.selectedIndex + deltaIndex))
                                self:setSelectedItem(1, newIndex)
                            end
                        else
                            self:smoothScrollTo(self.targetViewOffset + deltaIndex * self.scrollViewOffsetDelta)
                        end

                        eventUsed = true
                    end
                end
            end

            if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
                self:onMouseUp()
                eventUsed = true
            end
        elseif self.mouseOverElement ~= nil then
            self.mouseOverElement = nil
            self:setHighlightedItem(self.mouseOverElement)
        end
    end

    return eventUsed
end






























































































































































































---
function SmoothListElement:canReceiveFocus()
    return self:getIsVisible() and self.handleFocus and not self.disabled and self.totalItemCount > 0
end


---
function SmoothListElement:onFocusActivate()
    if self.totalItemCount == 0 then
        return
    end

    if self.onClickCallback ~= nil then
        self:notifyClick(self.selectedSectionIndex, self.selectedIndex, nil)
        return
    end

    if self.onDoubleClickCallback ~= nil then   -- when is this triggered in conjunction with focus?
        self:notifyDoubleClick(self.selectedSectionIndex, self.selectedIndex, nil)
        return
    end
end


---
function SmoothListElement:onFocusEnter()
    -- if self.selectedIndex > 0 and #self.listItems > 0 then
    --     local index = self:getSelectedElementIndex()
    --     local element = self.elements[index]

    --     if element ~= nil and element.setSelected ~= nil then
    --         self.elements[index]:setSelected(true)
    --     end
    -- end

    if not self.selectedWithoutFocus then
        self:applyElementSelection()

        if self.delegate.onListSelectionChanged ~= nil then
            self.delegate:onListSelectionChanged(self, self.selectedSectionIndex, self.selectedIndex)
        end
    end
end


---
function SmoothListElement:onFocusLeave()
    -- if self.useSelectionOnLeave and self.selectedIndex ~= nil and self.selectedIndex ~= 0 and self:getItemCount() > self.selectedIndex then
    --     -- make sure to get a valid index to update the selection (data may have changed)
    --     local clampedIndex = MathUtil.clamp(self:getSelectedElementIndex(), 0, self:getItemCount())
    --     if clampedIndex > 0 then
    --         self.listItems[clampedIndex]:setSelected(true)
    --     end
    -- else
    if not self.selectedWithoutFocus then
        self:clearElementSelection()
    end

    SmoothListElement:superClass().onFocusLeave(self)
end
