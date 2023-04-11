---List display element.
--
--Layouts a list of ListItemElement instances which themselves can contain other elements. The list interacts with a
--slider element for scrolling, if it is set up via configuration.
--
--Use this list element for ordered displaying of a small to medium number of elements. For larger element counts or
--more elaborate ordering logic, consider using the TableElement instead.
--
--An important note:
--- Even in a single column list, set both listItemHeight and listItemWidth. Both are always used to calculate mouse click targets.









































local ListElement_mt = Class(ListElement, GuiElement)


---
function ListElement.new(target, custom_mt)
    local self = GuiElement.new(target, custom_mt or ListElement_mt)
    self:include(IndexChangeSubjectMixin) -- add index change subject mixin for index state observers

    self.doesFocusScrollList = true
    self.isHorizontalList = false
    self.useSelectionOnLeave = false
    self.selectOnScroll = false
    self.updateSelectionOnOpen = true
    self.supportsMouseScrolling = true
    self.ignoreMouse = false
    self.keepSelectedInView = false

    self.maxNumItems = nil
    self.visibleItems = 5
    self.doubleClickInterval = 400

    self.listItems = {}
    self.listItemStartXOffset = 0.00
    self.listItemStartYOffset = 0.00
    self.listItemWidth = 0
    self.listItemHeight = 0
    self.listItemPadding = 0
    self.listItemSpacing = 0
    self.listItemAutoSize = false

    self.firstVisibleItem = 1
    self.lastFirstVisibleItem = 1
    self.selectedIndex = 1
    self.mouseRow = 0
    self.mouseCol = 0
    self.lastClickTime = nil
    self.selectOnClick = false

    self.isPaginated = false

    self.rowBackgroundProfile = "" -- default row background profile, overrides configured profile if specified
    self.rowBackgroundProfileAlternate = "" -- alternating row background profile

    self.itemsPerRow = 1
    self.itemsPerCol = 1

    self.currentRow = 1
    self.currentCol = 1

    self.sliderElement = nil -- sliders register themselves with lists in this field if they point at them via configuration

    return self
end


---
function ListElement:delete()
    -- This forwards to removeElement
    self.deletingAllListItems = true

    local numItems = #self.listItems
    for _ = 1,numItems do
        self.listItems[1]:delete()
    end

    ListElement:superClass().delete(self)
end


---
function ListElement:loadFromXML(xmlFile, key)
    ListElement:superClass().loadFromXML(self, xmlFile, key)

    self.doesFocusScrollList = Utils.getNoNil(getXMLBool(xmlFile, key.."#focusScrollsList"), self.doesFocusScrollList)
    self.isHorizontalList = Utils.getNoNil(getXMLBool(xmlFile, key.."#isHorizontalList"), self.isHorizontalList)
    self.updateSelectionOnOpen = Utils.getNoNil(getXMLBool(xmlFile, key.."#updateSelectionOnOpen"), self.updateSelectionOnOpen)
    self.useSelectionOnLeave = Utils.getNoNil(getXMLBool(xmlFile, key.."#useSelectionOnLeave"), self.useSelectionOnLeave)
    self.selectOnScroll = Utils.getNoNil(getXMLBool(xmlFile, key.."#selectOnScroll"), self.selectOnScroll)
    self.supportsMouseScrolling = Utils.getNoNil(getXMLBool(xmlFile, key.."#supportsMouseScrolling"), self.supportsMouseScrolling)
    self.maxNumItems = Utils.getNoNil(getXMLInt(xmlFile, key.."#maxNumItems"), self.maxNumItems)
    self.doubleClickInterval = Utils.getNoNil(getXMLInt(xmlFile, key.."#doubleClickInterval"), self.doubleClickInterval)
    self.selectOnClick = Utils.getNoNil(getXMLBool(xmlFile, key .. "#selectOnClick"), self.selectOnClick)
    self.ignoreMouse = Utils.getNoNil(getXMLBool(xmlFile, key .. "#ignoreMouse"), self.ignoreMouse)
    self.keepSelectedInView = Utils.getNoNil(getXMLBool(xmlFile, key .. "#keepSelectedInView"), self.keepSelectedInView)
    self.isPaginated = Utils.getNoNil(getXMLBool(xmlFile, key .. "#isPaginated"), self.isPaginated)

    self.itemsPerRow = Utils.getNoNil(getXMLInt(xmlFile, key.."#itemsPerRow"), self.itemsPerRow)
    self.itemsPerCol = Utils.getNoNil(getXMLInt(xmlFile, key.."#itemsPerCol"), self.itemsPerCol)
    self.visibleItems = self.itemsPerRow * self.itemsPerCol

    self.listItemStartXOffset = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemStartXOffset"), {self.outputSize[1]}, {self.listItemStartXOffset}))
    self.listItemStartYOffset = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemStartYOffset"), {self.outputSize[2]}, {self.listItemStartYOffset}))
    self.listItemWidth = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemWidth"), {self.outputSize[1]}, {self.listItemWidth}))
    self.listItemHeight = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemHeight"), {self.outputSize[2]}, {self.listItemHeight}))
    self.listItemPadding = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemPadding"), {self.outputSize[1]}, {self.listItemPadding}))
    self.listItemSpacing = unpack(GuiUtils.getNormalizedValues(getXMLString(xmlFile, key.."#listItemSpacing"), {self.outputSize[2]}, {self.listItemSpacing}))
    self.listItemAutoSize = getXMLBool(xmlFile, key .. "#listItemAutoSize") or self.listItemAutoSize

    self.rowBackgroundProfile = Utils.getNoNil(getXMLString(xmlFile, key.."#rowBackgroundProfile"), self.rowBackgroundProfile)
    self.rowBackgroundProfileAlternate = Utils.getNoNil(getXMLString(xmlFile, key.."#rowBackgroundProfileAlternate"), self.rowBackgroundProfileAlternate)

    self:addCallback(xmlFile, key.."#onSelectionChanged", "onSelectionChangedCallback")
    self:addCallback(xmlFile, key.."#onScroll", "onScrollCallback")
    self:addCallback(xmlFile, key.."#onDoubleClick", "onDoubleClickCallback")
    self:addCallback(xmlFile, key.."#onClick", "onClickCallback")
    self:addCallback(xmlFile, key.."#onItemAppear", "onItemAppearCallback")
    self:addCallback(xmlFile, key.."#onItemDisappear", "onItemDisappearCallback")
end


---
function ListElement:loadProfile(profile, applyProfile)
    ListElement:superClass().loadProfile(self, profile, applyProfile)

    self.doesFocusScrollList = profile:getBool("focusScrollsList", self.doesFocusScrollList)
    self.isHorizontalList = profile:getBool("isHorizontalList", self.isHorizontalList)
    self.updateSelectionOnOpen = profile:getBool("updateSelectionOnOpen", self.updateSelectionOnOpen)
    self.useSelectionOnLeave = profile:getBool("useSelectionOnLeave", self.useSelectionOnLeave)
    self.selectOnScroll = profile:getBool("selectOnScroll", self.selectOnScroll)
    self.supportsMouseScrolling = profile:getBool("supportsMouseScrolling", self.supportsMouseScrolling)
    self.maxNumItems = profile:getNumber("maxNumItems", self.maxNumItems)
    self.itemsPerRow = profile:getNumber("itemsPerRow", self.itemsPerRow)
    self.itemsPerCol = profile:getNumber("itemsPerCol", self.itemsPerCol)
    self.doubleClickInterval = profile:getNumber("doubleClickInterval", self.doubleClickInterval)
    self.selectOnClick = profile:getBool("selectOnClick", self.selectOnClick)
    self.ignoreMouse = profile:getBool("ignoreMouse", self.ignoreMouse)
    self.keepSelectedInView = profile:getBool("keepSelectedInView", self.keepSelectedInView)
    self.isPaginated = profile:getBool("isPaginated", self.isPaginated)

    self.rowBackgroundProfile = profile:getValue("rowBackgroundProfile", self.rowBackgroundProfile)
    self.rowBackgroundProfileAlternate = profile:getValue("rowBackgroundProfileAlternate", self.rowBackgroundProfileAlternate)

    self.listItemStartXOffset = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemStartXOffset"), {self.outputSize[1]}, {self.listItemStartXOffset}))
    self.listItemStartYOffset = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemStartYOffset"), {self.outputSize[2]}, {self.listItemStartYOffset}))
    self.listItemWidth = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemWidth"), {self.outputSize[1]}, {self.listItemWidth}))
    self.listItemHeight = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemHeight"), {self.outputSize[2]}, {self.listItemHeight}))
    self.listItemPadding = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemPadding"), {self.outputSize[1]}, {self.listItemPadding}))
    self.listItemSpacing = unpack(GuiUtils.getNormalizedValues(profile:getValue("listItemSpacing"), {self.outputSize[2]}, {self.listItemSpacing}))
    self.listItemAutoSize = profile:getBool("listItemAutoSize", self.listItemAutoSize)

    if applyProfile then
        self:applyListAspectScale()
    end
end


---
function ListElement:copyAttributes(src)
    ListElement:superClass().copyAttributes(self, src)

    self.doesFocusScrollList = src.doesFocusScrollList
    self.isHorizontalList = src.isHorizontalList
    self.updateSelectionOnOpen = src.updateSelectionOnOpen
    self.useSelectionOnLeave = src.useSelectionOnLeave
    self.selectOnScroll = src.selectOnScroll
    self.supportsMouseScrolling = src.supportsMouseScrolling
    self.doubleClickInterval = src.doubleClickInterval
    self.selectOnClick = src.selectOnClick
    self.ignoreMouse = src.ignoreMouse
    self.maxNumItems = src.maxNumItems
    self.keepSelectedInView = src.keepSelectedInView
    self.isPaginated = src.isPaginated

    self.visibleItems = src.visibleItems
    self.itemsPerRow = src.itemsPerRow
    self.itemsPerCol = src.itemsPerCol

    self.listItemStartXOffset = src.listItemStartXOffset
    self.listItemStartYOffset = src.listItemStartYOffset
    self.listItemWidth = src.listItemWidth
    self.listItemHeight = src.listItemHeight
    self.listItemPadding = src.listItemPadding
    self.listItemSpacing = src.listItemSpacing
    self.listItemAutoSize = src.listItemAutoSize

    self.rowBackgroundProfile = src.rowBackgroundProfile
    self.rowBackgroundProfileAlternate = src.rowBackgroundProfileAlternate

    self.onSelectionChangedCallback = src.onSelectionChangedCallback
    self.onScrollCallback = src.onScrollCallback
    self.onDoubleClickCallback = src.onDoubleClickCallback
    self.onClickCallback = src.onClickCallback
    self.onItemAppearCallback = src.onItemAppearCallback
    self.onItemDisappearCallback = src.onItemDisappearCallback

    GuiMixin.cloneMixin(IndexChangeSubjectMixin, src, self)
end


---
function ListElement:applyListAspectScale()
    local xScale, yScale = self:getAspectScale()

    self.listItemStartXOffset = self.listItemStartXOffset * xScale
    self.listItemWidth = self.listItemWidth * xScale
    self.listItemPadding = self.listItemPadding * xScale

    self.listItemStartYOffset = self.listItemStartYOffset * yScale
    self.listItemHeight = self.listItemHeight * yScale
    self.listItemSpacing = self.listItemSpacing * yScale
end


---
function ListElement:applyScreenAlignment()
    self:applyListAspectScale()

    ListElement:superClass().applyScreenAlignment(self)
end


---
function ListElement:onGuiSetupFinished()
    ListElement:superClass().onGuiSetupFinished(self)

    if self.listItemAutoSize then
        local firstListItem = self:getFirstDescendant(function(element) return element:isa(ListItemElement) end)
        if firstListItem ~= nil then
            self.listItemWidth, self.listItemHeight = unpack(firstListItem.absSize)
        end
    end
end


---
function ListElement:onOpen()
    ListElement:superClass().onOpen(self)
    if self.updateSelectionOnOpen then
        self:setSelectedIndex(self.selectedIndex)
    end
end


---
function ListElement:onSliderValueChanged(slider, newValue)
    self:scrollTo(math.floor(newValue + 0.001)*self:getItemFactor(), false)
end


---
function ListElement:raiseSliderUpdateEvent()
    if self.sliderElement ~= nil then
        self.sliderElement:onBindUpdate(self)
    end
end


---
function ListElement:scrollTo(index, updateSlider)
    local itemFactor = self:getItemFactor()

    -- convert to valid firstVisibleItem (always has to be:  n*itemFactor + 1 )
    index = math.ceil(index / itemFactor) * itemFactor - (itemFactor - 1)

    if not self.isPaginated then
        -- clamp index to valid range
        index = math.max(math.min(index, math.ceil(self:getItemCount() / itemFactor) * itemFactor - self.visibleItems + 1), 1)
    end

    if index ~= self.firstVisibleItem  then
        self.firstVisibleItem = index
        self:updateItemPositions()

        if self.keepSelectedInView then
            -- Check if visible
            if self.selectedIndex < self.firstVisibleItem or self.selectedIndex > self.firstVisibleItem + self.visibleItems - 1 then
                local direction = MathUtil.sign(index - self.selectedIndex)

                -- Find if at top or bottom
                if self.selectedIndex < self.firstVisibleItem then
                    self:setSelectedIndex(self.firstVisibleItem, nil, direction)
                else
                    self:setSelectedIndex(self.firstVisibleItem + self.visibleItems - 1, nil, direction)
                end
            end
        end

        -- update scrolling
        if updateSlider == nil or updateSlider then
            if self.sliderElement ~= nil then
                self.sliderElement:setValue(math.ceil(index / itemFactor), true)
            end
        end

        self:raiseCallback("onScrollCallback")
    end
end


---
function ListElement:calculateFirstVisibleItem(index)
    local newFirstVisibleItem = self.firstVisibleItem
    local itemFactor = self:getItemFactor()
    local count = self:getItemCount()

    -- only change firstVisibleItem if index is out of visible range
    if index < self.firstVisibleItem then
        newFirstVisibleItem = math.ceil(index/itemFactor) * itemFactor - (itemFactor - 1)
    elseif index >= self.firstVisibleItem+self.visibleItems then
        -- With pagination, we need to stick to page alignment
        if self.isPaginated then
            local page = math.ceil(index / self.visibleItems)
            newFirstVisibleItem = (page - 1) * self.visibleItems + 1

        -- Otherwise, just put the item inside (as last item)
        else
            newFirstVisibleItem = math.ceil(index/itemFactor) * itemFactor - self.visibleItems + 1
        end
    elseif count == 0 then
        newFirstVisibleItem = 0
    end

    return MathUtil.clamp(newFirstVisibleItem, 1, count)
end


---
function ListElement:getItemFactor()
    if self.isHorizontalList then
        return self.itemsPerCol
    else
        return self.itemsPerRow
    end
end


---
function ListElement:scrollList(delta)
    if delta ~= 0 then
        local index = self.firstVisibleItem
        if self.isHorizontalList then
            index = index + self.itemsPerCol * delta
        else
            index = index + self.itemsPerRow * delta
        end

        self:scrollTo(index)
    end
end


---
function ListElement:setSelectedIndex(index, force, direction)
    local numItems = #self.listItems
    local newIndex = MathUtil.clamp(index, 0, numItems)

    if newIndex ~= self.selectedIndex then
        self.lastClickTime = nil
    end

    -- Try to scroll over disabled items
    if self.listItems[newIndex] ~= nil and self.listItems[newIndex].disabled then
        newIndex = newIndex + (direction or 1)

        -- If we can't, stay where we are
        if newIndex > #self.listItems or newIndex < 1 then
            if newIndex == 0 then
                -- make sure we are scrolled to the top
                self:scrollTo(1)
            end

            return
        end

        -- Force no change when direction is explicitly absent (mouse clicks on an item)
        if direction == 0 then
            return
        end

        return self:setSelectedIndex(newIndex, force, direction or 1)
    end

    local hasChanged = self.selectedIndex ~= newIndex
    self.selectedIndex = newIndex

    local newFirstVisibleItem = self:calculateFirstVisibleItem(newIndex)

        -- do we need to scroll?
    if hasChanged or newFirstVisibleItem ~= self.firstVisibleItem then
        self:scrollTo(newFirstVisibleItem)
    end

    if hasChanged or force then
        self:notifyIndexChange(newIndex, numItems)
        self:raiseCallback("onSelectionChangedCallback", newIndex)
    end

    -- update selection state
    if self.firstVisibleItem > 0 then
        for i = 1, self.visibleItems do
            index = self.firstVisibleItem + i - 1
            if index > numItems then
                break
            end
            local listItem = self.listItems[index]
            if listItem.setSelected ~= nil then
                listItem:setSelected(newIndex == index)
            end
        end
    end
end


---Get the currently selected list element's index.
function ListElement:getSelectedElementIndex()
    return self.selectedIndex
end


---Get the selected element
function ListElement:getSelectedElement()
    if self.selectedIndex >= 1 then
        return self.listItems[self:getSelectedElementIndex()], self.selectedIndex
    end
end


---
function ListElement:updateAbsolutePosition()
    ListElement:superClass().updateAbsolutePosition(self)
    self:updateItemPositions()
end


---Add a new element (cloning into the list element also works)
function ListElement:addElement(element)
    self:addElementAtPosition(element, #self.listItems + 1)
end


---
function ListElement:addElementAtPosition(element, position)
    ListElement:superClass().addElement(self, element)

    if self.maxNumItems == nil or #self.listItems <= self.maxNumItems  then
        table.insert(self.listItems, position, element)

        element:fadeOut()
        self:setDisabled(self.disabled)

        self:updateAlternatingBackground()

        if self.selectedIndex >= position then
            self:setSelectedIndex(self.selectedIndex + 1)
            if #self.listItems == 1 then
                self:updateItemPositions()
            end
        else
            self:updateItemPositions()
        end

        self:raiseSliderUpdateEvent()
        if not element.focusId then
            FocusManager:loadElementFromCustomValues(element, nil, element.focusChangeData, element.focusActive, element.isAlwaysFocusedOnOpen)
        end
    end

    self:notifyIndexChange(self.selectedIndex, #self.listItems)
end


---Remove an element
function ListElement:removeElement(element)
    -- Do not do fancy selection stuff when we are destroying this list
    if not self.deletingAllListItems then
        for i = 1, #self.listItems do
            local v = self.listItems[i]
            if v == element then
                table.remove(self.listItems, i)
                FocusManager:removeElement(element)
                self:setDisabled(self.disabled)

                if self.selectedIndex >= #self.listItems then
                    self:setSelectedIndex(self.selectedIndex - 1)
                end

                self:raiseSliderUpdateEvent()
                break
            end
        end

        -- shift visible part of list if possible and needed
        if (self.firstVisibleItem > 1 and (self.firstVisibleItem > (#self.listItems - self.visibleItems))) then
            if self.selectedIndex > #self.listItems then
                self:setSelectedIndex(#self.listItems)
            else
                self:scrollTo(#self.listItems)
            end
        end
    end

    ListElement:superClass().removeElement(self, element)
end


---Delete all list items
function ListElement:deleteListItems()
    local numItems = #self.listItems
    for _ = 1, numItems do
        self.listItems[1]:delete()
    end

    self.selectedIndex = 1

    self:notifyIndexChange(1, numItems)
    self:raiseSliderUpdateEvent()
end


---Handles mouse button down event
function ListElement:onMouseDown()
    self.mouseDown = true
    FocusManager:setFocus(self)
end


---Handles mouse button up (after down) event
function ListElement:onMouseUp()
    if self.mouseRow ~= 0 and self.mouseCol ~= 0 then
        local r, c = self:convertVisualRowColumToReal(self.mouseRow, self.mouseCol)

        self:setSelectionByRealRowAndColumn(r, c, 0)

        local clickedIndex = self:getUnclampedIndexByRealRowColumn(r, c)

        if self.lastClickTime ~= nil and self.lastClickTime > self.target.time-self.doubleClickInterval then
            -- Only activate click if the target was hit
            if clickedIndex == self.selectedIndex then
                self:notifyDoubleClick(clickedIndex)
            end
            self.lastClickTime = nil
        else
            self.lastClickTime = self.target.time
        end

        if not self.selectOnClick then
            self:notifyClick(clickedIndex)
        end
    else
        self.lastClickTime = nil
    end
    self.mouseDown = false
end


---
function ListElement:notifyDoubleClick(clickedElementIndex)
    self:raiseCallback("onDoubleClickCallback", clickedElementIndex, self.listItems[clickedElementIndex])
end


---
function ListElement:notifyClick(clickedElementIndex)
    self:raiseCallback("onClickCallback", clickedElementIndex, self.listItems[clickedElementIndex])
end


---Update alternating item background profiles.
-- @param bool forceProfile If true, forces a full application of the profile including aspect ratio scaling. Required for some cloned lists.
function ListElement:updateAlternatingBackground(forceProfile)
    if not self.rowBackgroundProfile or self.rowBackgroundProfile == "" or not self.rowBackgroundProfileAlternate or self.rowBackgroundProfileAlternate == "" then
        return
    end

    for k = 1, #self.listItems do
        local item = self.listItems[k]
        if not item.doNotAlternate then
            if k % 2 == 0 then
                item:applyProfile(self.rowBackgroundProfile, forceProfile)
            else
                item:applyProfile(self.rowBackgroundProfileAlternate, forceProfile)
            end
        end
    end
end


























---
function ListElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    if self:getIsActive() and not self.ignoreMouse then
        if ListElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed) then
            eventUsed = true
        end

        self.mouseRow = 0
        self.mouseCol = 0
        if not eventUsed and GuiUtils.checkOverlayOverlap(posX, posY, self.absPosition[1], self.absPosition[2], self.absSize[1], self.absSize[2]) then
            self.mouseRow, self.mouseCol = self:getRowColumnForScreenPosition(posX, posY)

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
                        eventUsed = true

                        if self.selectOnScroll then
                            -- clamp the new index to an always valid range for scrolling, setSelectedIndex would also
                            -- allow an index value of 0 meaning "no selection"
                            local newIndex = MathUtil.clamp(self.selectedIndex + deltaIndex, 1, self:getItemCount())
                            self:setSelectedIndex(newIndex, nil, deltaIndex)
                        else
                            self:scrollList(deltaIndex)
                        end
                    end
                end
            end

            if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
                self:onMouseUp()
                eventUsed = true
            end
        end
    end

    return eventUsed
end


---Update item positions for elements within a given item list range. The caller is responsible for index validity.
-- @param startIndex Starting index in self.listItems
-- @param endIndex End index in self.listItems
function ListElement:updateItemPositionsInRange(startIndex, endIndex)
    local topPos = self.absSize[2] - self.listItemStartYOffset - self.listItemHeight
    local leftPos = self.listItemStartXOffset

    for i = startIndex, endIndex do
        local elem = self.listItems[i]
        local index = i - self.firstVisibleItem

        --#debug assertWithCallstack(elem ~= nil)
        local wasVisible = elem:getIsVisible()

        local xPos, yPos = self:getItemPosition(leftPos, topPos, index, elem)
        elem:setPosition(xPos, yPos)

        if i >= self.firstVisibleItem and i < self.firstVisibleItem + self.visibleItems then
            -- make items visible in the designated range
            elem:fadeIn()

            if not wasVisible then
                self:raiseCallback("onItemAppearCallback", elem)
            end
        else
            -- make all others invisible
            elem:fadeOut()

            if wasVisible then
                self:raiseCallback("onItemDisappearCallback", elem)
            end
        end

        elem:reset()
        if elem.setSelected ~= nil then
            elem:setSelected(i == self.selectedIndex)
        end
    end
end


---
function ListElement:updateItemPositions()
    if self.ignoreUpdate == nil or not self.ignoreUpdate then
        if #self.listItems > 0 and self.selectedIndex == 0 then
            self.selectedIndex = 1
        end

        if self.firstVisibleItem > 0 then
            local scrollDiff = math.abs(self.lastFirstVisibleItem - self.firstVisibleItem)
            -- update range of items affected by last scrolling movement:
            self:updateItemPositionsInRange(math.max(1, self.firstVisibleItem - scrollDiff),
                math.min(self:getItemCount(), self.firstVisibleItem + self.visibleItems + scrollDiff))
        end

        self.lastFirstVisibleItem = self.firstVisibleItem
    end
end


---
function ListElement:getItemPosition(leftPos, topPos, index, item)
    local xPos, yPos

    if self.isHorizontalList then
        xPos = leftPos + math.floor(index / self.itemsPerCol) * (self.listItemWidth + self.listItemPadding)
        yPos = topPos - index % self.itemsPerCol * (self.listItemHeight + self.listItemSpacing)
    else
        xPos = leftPos + index % self.itemsPerRow * (self.listItemWidth + self.listItemPadding)
        yPos = topPos - math.floor(index / self.itemsPerRow) * (self.listItemHeight + self.listItemSpacing)
    end

    return xPos, yPos
end


---
function ListElement:getRealRowColumnByIndex(index)
    local row, column

    if self.isHorizontalList then
        row = ((index-1) % self.itemsPerCol) + 1
        column = math.floor((index-1)/self.itemsPerCol) + 1
    else
        row = math.ceil(index / self.itemsPerRow)
        column = ((index-1) % self.itemsPerRow) + 1
    end

    return row, column
end


---Get the number of rows
function ListElement:getNumOfRows()
    return math.ceil(self:getItemCount() / self.itemsPerRow)
end


---Get the number of colums
function ListElement:getNumOfColumns()
    return math.ceil(self:getItemCount() / self.itemsPerCol)
end










---Get the number of visible items.
-- @return Number of visible items
function ListElement:getVisibleItemCount()
    return self.visibleItems
end


---
function ListElement:getUnclampedIndexByRealRowColumn(realRow, realColumn)
    if self.isHorizontalList then
        return realRow + (realColumn - 1) * self.itemsPerCol
    else
        return realColumn + (realRow - 1) * self.itemsPerRow
    end
end


---
function ListElement:getItemIndexByRealRowColumn(realRow, realColumn)
    local number = self:getUnclampedIndexByRealRowColumn(realRow, realColumn)

    return MathUtil.clamp(number, 1, self:getItemCount())
end


---
function ListElement:convertVisualRowColumToReal(row, column)
    local realRow = row
    local realColumn = column

    if self.isHorizontalList then
        realColumn = math.floor((self.firstVisibleItem-1)/self.itemsPerCol) + column
    else
        realRow = math.floor((self.firstVisibleItem-1)/self.itemsPerRow) + row
    end

    return realRow, realColumn
end


---
function ListElement:setSelectionByRealRowAndColumn(realRow, realCol, direction)
    local index = self:getItemIndexByRealRowColumn(realRow, realCol)
    self:setSelectedIndex(index, nil, direction)
end























































































---
function ListElement:canReceiveFocus()
    return self:getIsVisible() and self.handleFocus and not self.disabled and (#self.listItems > 0)
end


---
function ListElement:onFocusActivate()
    if self.onClickCallback ~= nil then
        self:notifyClick(self:getSelectedElementIndex())
        return
    end

    if self.onDoubleClickCallback ~= nil then   -- when is this triggered in conjunction with focus?
        self:notifyDoubleClick(self:getSelectedElementIndex())
        return
    end
end


---
function ListElement:onFocusEnter()
    if self.selectedIndex > 0 and #self.listItems > 0 then
        local index = self:getSelectedElementIndex()
        local element = self.elements[index]

        if element ~= nil and element.setSelected ~= nil then
            self.elements[index]:setSelected(true)
        end
    end
end


---
function ListElement:onFocusLeave()
    if self.useSelectionOnLeave and self.selectedIndex ~= nil and self.selectedIndex ~= 0 and self:getItemCount() > self.selectedIndex then
        -- make sure to get a valid index to update the selection (data may have changed)
        local clampedIndex = MathUtil.clamp(self:getSelectedElementIndex(), 0, self:getItemCount())
        if clampedIndex > 0 then
            self.listItems[clampedIndex]:setSelected(true)
        end
    else
        self:clearElementSelection()
    end

    ListElement:superClass().onFocusLeave(self)
end


---Apply visual list item selection state based on the current data selection.
function ListElement:applyElementSelection()
    if self.firstVisibleItem > 0 then
        local index = self:getSelectedElementIndex()
        for i = 1, #self.elements do
            local element = self.elements[i]
            if element.setSelected ~= nil then
                element:setSelected(index == i)
            end
        end
    end
end


---Remove element selection state on all elements (e.g. when losing focus).
function ListElement:clearElementSelection()
    for i = 1, #self.elements do
        local element = self.elements[i]
        if element.setSelected ~= nil then
            element:setSelected(false)
        end
    end
end


---
function ListElement:verifyConfiguration()
    ListElement:superClass().verifyConfiguration(self)

    self:verifyListItemConfiguration()
end
