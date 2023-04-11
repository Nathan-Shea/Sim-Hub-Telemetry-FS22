---Layout element which lays out child elements in regular rows or columns.
--Exceptions are elements whose "layoutIgnore" property is true.
--
--Used layers: "image" for a background image.






















local BoxLayoutElement_mt = Class(BoxLayoutElement, BitmapElement)















































---
function BoxLayoutElement.new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = BoxLayoutElement_mt
    end
    local self = BitmapElement.new(target, custom_mt)
    self.alignmentX = BoxLayoutElement.ALIGN_LEFT
    self.alignmentY = BoxLayoutElement.ALIGN_TOP

    self.autoValidateLayout = false
    self.useFullVisibility = true

    self.wrapAround = false
    self.flowDirection = BoxLayoutElement.FLOW_VERTICAL
    self.numFlows = 1 -- number of flows (columns or rows, depending on flow direction)
    self.lateralFlowSize = 0.5 -- lateral size of flow (column width or row height, depending on flow direction)
    self.fitFlowToElements = false -- ignore lateral flow size and fit flows to element dimensions
    self.flowMargin = {0, 0, 0, 0} -- outward offset between flows, no effect at numFlows == 1
    self.layoutToleranceX, self.layoutToleranceY = 0, 0

    self.rememberLastFocus = false
    self.lastFocusElement = nil
    self.incomingFocusTargets = {}
    self.defaultFocusTarget = nil -- first focusable element of the current layout state
    return self
end


---
function BoxLayoutElement:loadFromXML(xmlFile, key)
    BoxLayoutElement:superClass().loadFromXML(self, xmlFile, key)

    local alignmentX = getXMLString(xmlFile, key.."#alignmentX")
    if alignmentX ~= nil then
        alignmentX = alignmentX:lower()
        if alignmentX == "right" then
            self.alignmentX = BoxLayoutElement.ALIGN_RIGHT
        elseif alignmentX == "center" then
            self.alignmentX = BoxLayoutElement.ALIGN_CENTER
        else
            self.alignmentX = BoxLayoutElement.ALIGN_LEFT
        end
    end

    local alignmentY = getXMLString(xmlFile, key.."#alignmentY")
    if alignmentY ~= nil then
        alignmentY = alignmentY:lower()
        if alignmentY == "bottom" then
            self.alignmentY = BoxLayoutElement.ALIGN_BOTTOM
        elseif alignmentY == "middle" then
            self.alignmentY = BoxLayoutElement.ALIGN_MIDDLE
        else
            self.alignmentY = BoxLayoutElement.ALIGN_TOP
        end
    end

    self.flowDirection = Utils.getNoNil(getXMLString(xmlFile, key.."#flowDirection"), self.flowDirection)
    self.focusDirection = getXMLString(xmlFile, key.."#focusDirection") or self.flowDirection -- use flow direction as default

    self.numFlows = Utils.getNoNil(tonumber(getXMLString(xmlFile, key.."#numFlows")), self.numFlows)
    self.lateralFlowSize = Utils.getNoNil(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#lateralFlowSize"), self.outputSize, {self.lateralFlowSize})[1], self.lateralFlowSize)
    self.flowMargin = GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#flowMargin"), self.outputSize, self.flowMargin)
    self.fitFlowToElements = Utils.getNoNil(getXMLBool(xmlFile, key.."#fitFlowToElements"), self.fitFlowToElements)

    self.autoValidateLayout = Utils.getNoNil(getXMLBool(xmlFile, key.."#autoValidateLayout"), self.autoValidateLayout)
    self.useFullVisibility = Utils.getNoNil(getXMLBool(xmlFile, key.."#useFullVisibility"), self.useFullVisibility)

    self.wrapAround = Utils.getNoNil(getXMLBool(xmlFile, key.."#wrapAround"), self.wrapAround)
    self.rememberLastFocus = Utils.getNoNil(getXMLBool(xmlFile, key.."#rememberLastFocus"), self.rememberLastFocus)
end


---
function BoxLayoutElement:loadProfile(profile, applyProfile)
    BoxLayoutElement:superClass().loadProfile(self, profile, applyProfile)

    local alignmentX = profile:getValue("alignmentX")
    if alignmentX ~= nil then
        alignmentX = alignmentX:lower()
        if alignmentX == "right" then
            self.alignmentX = BoxLayoutElement.ALIGN_RIGHT
        elseif alignmentX == "center" then
            self.alignmentX = BoxLayoutElement.ALIGN_CENTER
        else
            self.alignmentX = BoxLayoutElement.ALIGN_LEFT
        end
    end

    local alignmentY = profile:getValue("alignmentY")
    if alignmentY ~= nil then
        alignmentY = alignmentY:lower()
        if alignmentY == "bottom" then
            self.alignmentY = BoxLayoutElement.ALIGN_BOTTOM
        elseif alignmentY == "middle" then
            self.alignmentY = BoxLayoutElement.ALIGN_MIDDLE
        else
            self.alignmentY = BoxLayoutElement.ALIGN_TOP
        end
    end

    local autoValidateLayout = profile:getBool("autoValidateLayout")
    if autoValidateLayout ~= nil then
        self.autoValidateLayout = autoValidateLayout
    end
    local useFullVisibility = profile:getBool("useFullVisibility")
    if useFullVisibility ~= nil then
        self.useFullVisibility = useFullVisibility
    end

    self.flowDirection = Utils.getNoNil(profile:getValue("flowDirection"), self.flowDirection)
    self.focusDirection = profile:getValue("focusDirection") or self.flowDirection
    self.numFlows = profile:getNumber("numFlows", self.numFlows)

    self.lateralFlowSize = GuiUtils.getNormalizedValues(profile:getValue("lateralFlowSize", "0px"), self.outputSize, {self.lateralFlowSize})[1]
    self.flowMargin = GuiUtils.getNormalizedValues(profile:getValue("flowMargin", "0px 0px 0px 0px"), self.outputSize, self.flowMargin)
    self.fitFlowToElements = profile:getBool("fitFlowToElements", self.fitFlowToElements)

    self.wrapAround = profile:getBool("wrapAround", self.wrapAround)
    self.rememberLastFocus = profile:getBool("rememberLastFocus", self.rememberLastFocus)
end


---
function BoxLayoutElement:copyAttributes(src)
    BoxLayoutElement:superClass().copyAttributes(self, src)

    self.alignmentX = src.alignmentX
    self.alignmentY = src.alignmentY
    self.autoValidateLayout = src.autoValidateLayout
    self.useFullVisibility = src.useFullVisibility

    self.layoutToleranceX, self.layoutToleranceY = src.layoutToleranceX, src.layoutToleranceY

    self.flowDirection = src.flowDirection
    self.focusDirection = src.focusDirection
    self.numFlows = src.numFlows
    self.lateralFlowSize = src.lateralFlowSize
    self.flowMargin = src.flowMargin
    self.fitFlowToElements = src.fitFlowToElements

    self.wrapAround = src.wrapAround
    self.rememberLastFocus = src.rememberLastFocus
end


---
function BoxLayoutElement:onGuiSetupFinished()
    BoxLayoutElement:superClass().onGuiSetupFinished(self)
    self.layoutToleranceX = BoxLayoutElement.LAYOUT_TOLERANCE / g_screenWidth
    self.layoutToleranceY = BoxLayoutElement.LAYOUT_TOLERANCE / g_screenHeight

    self:invalidateLayout(false)
end


---
function BoxLayoutElement:addElement(element)
    BoxLayoutElement:superClass().addElement(self, element)
    if self.autoValidateLayout then
        self:invalidateLayout()
    end
end


---
function BoxLayoutElement:removeElement(element)
    BoxLayoutElement:superClass().removeElement(self, element)
    if self.autoValidateLayout then
        self:invalidateLayout()
    end
end


---
function BoxLayoutElement:getIsElementIncluded(element, ignoreVisibility)
    return not element.ignoreLayout and ignoreVisibility or (element:getIsVisibleNonRec() and self.useFullVisibility) or (element.visible and not self.useFullVisibility)
end














































































































































































































































































































































































---
function BoxLayoutElement:canReceiveFocus()
    -- element can receive focus if any sub elements are ready to receive focus
    if self.handleFocus then
        for _, v in ipairs(self.elements) do
            if (v:canReceiveFocus()) then
                return true
            end
        end
    end
    return false
end











































---
function BoxLayoutElement:onFocusLeave()
    BoxLayoutElement:superClass().onFocusLeave(self)

    if self.rememberLastFocus then
        local lastFocus = FocusManager:getFocusedElement()
        if lastFocus:isChildOf(self) then
            self.lastFocusElement = lastFocus
        end
    end
end
