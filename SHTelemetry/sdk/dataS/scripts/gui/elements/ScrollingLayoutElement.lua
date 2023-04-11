---Box layout that supports smooth scrolling









local ScrollingLayoutElement_mt = Class(ScrollingLayoutElement, BoxLayoutElement)


---
function ScrollingLayoutElement.new(target, custom_mt)
    local self = BoxLayoutElement.new(target, custom_mt or ScrollingLayoutElement_mt)

    self.alignmentX = BoxLayoutElement.ALIGN_LEFT
    self.alignmentY = BoxLayoutElement.ALIGN_TOP
    self.clipping = true
    self.wrapAround = true -- needed for focus handling when scrolling

    self.sliderElement = nil -- sliders register themselves with lists in this field if they point at them via configuration

    self.firstVisibleY = 0
    self.targetFirstVisibleY = 0
    self.contentSize = 1 -- height only for now

    return self
end


---
function ScrollingLayoutElement:loadFromXML(xmlFile, key)
    ScrollingLayoutElement:superClass().loadFromXML(self, xmlFile, key)

    self.topClipperElementName = getXMLString(xmlFile, key.."#topClipperElementName")
    self.bottomClipperElementName = getXMLString(xmlFile, key.."#bottomClipperElementName")
end


---
function ScrollingLayoutElement:copyAttributes(src)
    ScrollingLayoutElement:superClass().copyAttributes(self, src)

    self.topClipperElementName = src.topClipperElementName
    self.bottomClipperElementName = src.bottomClipperElementName
end


---
function ScrollingLayoutElement:onGuiSetupFinished()
    ScrollingLayoutElement:superClass().onGuiSetupFinished(self)

    if self.topClipperElementName ~= nil then
        self.topClipperElement = self.parent:getDescendantByName(self.topClipperElementName)
    end
    if self.bottomClipperElementName ~= nil then
        self.bottomClipperElement = self.parent:getDescendantByName(self.bottomClipperElementName)
    end

    for _, e in pairs(self.elements) do
        self:addFocusListener(e)
    end
end


---Rebuild the layout. Adjusts start Y with our visible Y
function ScrollingLayoutElement:invalidateLayout(ignoreVisibility)
    local cells = self:getLayoutCells(ignoreVisibility)

    local lateralFlowSizes, totalLateralSize, flowSize = self:getLayoutSizes(cells)
    local offsetStartX, offsetStartY, xDir, yDir = self:getAlignmentOffset(flowSize, totalLateralSize)

    offsetStartY = offsetStartY + self.firstVisibleY

    self:applyCellPositions(cells, offsetStartX, offsetStartY, xDir, yDir, lateralFlowSizes)

    if self.handleFocus and self.focusDirection ~= BoxLayoutElement.FLOW_NONE then
        self:focusLinkCells(cells)
    end

    self:updateContentSize()
    self:updateScrollClippers()

    for _, e in pairs(self.elements) do
        self:addFocusListener(e)
    end

    return flowSize
end














---
function ScrollingLayoutElement:onSliderValueChanged(slider, newValue)
    local newStartY = 0
    if slider.minValue ~= slider.maxValue then
        newStartY = ((self.contentSize - self.absSize[2]) / (slider.maxValue - slider.minValue)) * (newValue - slider.minValue)
    end

    self:scrollTo(newStartY, false)
end


---Scroll to an Y position within the content
function ScrollingLayoutElement:scrollTo(startY, updateSlider, noUpdateTarget)
    self.firstVisibleY = startY

    if not noUpdateTarget then
        self.targetFirstVisibleY = startY
        self.isMovingToTarget = false
    end

    self:invalidateLayout()

    -- update scrolling
    if updateSlider == nil or updateSlider then
        if self.sliderElement ~= nil then
            local newValue = startY / ((self.contentSize - self.absSize[2]) / self.sliderElement.maxValue)
            self.sliderElement:setValue(newValue, true)
        end
    end

    self:raiseCallback("onScrollCallback")
end






























---
function ScrollingLayoutElement:raiseSliderUpdateEvent()
    if self.sliderElement ~= nil then
        self.sliderElement:onBindUpdate(self)
    end
end


---Update content size when an element is added
function ScrollingLayoutElement:addElement(element)
    ScrollingLayoutElement:superClass().addElement(self, element)

    if self.autoValidateLayout then
        self:invalidateLayout()
    end
end















---Update content size when an element is removed
function ScrollingLayoutElement:removeElement(element)
    ScrollingLayoutElement:superClass().removeElement(self, element)

    if element.scrollingFocusEnter_orig == nil then
        element.onFocusEnter = element.scrollingFocusEnter_orig
    end

    if self.autoValidateLayout then
        self:invalidateLayout()
    end
end






































































---Remove non-GUI input action events.
function ScrollingLayoutElement:removeActionEvents()
    g_inputBinding:removeActionEventsByTarget(self)
end


---Event function for vertical cursor input bound to InputAction.MENU_AXIS_UP_DOWN_SECONDARY.
function ScrollingLayoutElement:onVerticalCursorInput(_, inputValue)
    if not self.useMouse then
        self.sliderElement:setValue(self.sliderElement.currentValue + self.sliderElement.stepSize * inputValue)
    end
    self.useMouse = false
end
