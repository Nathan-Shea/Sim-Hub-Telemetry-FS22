---Table GUI element.
--Allows sorting by columns when clicking on header elements. Header elements should ideally be defined just before
--the table itself, but never within the table.
























































































































local TableElement_mt = Class(TableElement, ListElement)


---
function TableElement.new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = TableElement_mt
    end
    local self = ListElement.new(target, custom_mt)

    -- override defaults from ListElement
    self.doesFocusScrollList = true
    self.isHorizontalList = false
    self.useSelectionOnLeave = false
    self.updateSelectionOnOpen = true

    self.periodicUpdate = false
    self.updateInterval = 5000 -- update interval, internally stored as ms
    self.timeSinceLastUpdate = 0
    self.timeSinceLastInput = 0 -- ms since last scrolling action, if this exceeds a threshold, allow automatic refocusing on selected table item
    self.columnNames = {}
    self.rowTemplateName = "" -- Name of row template
    self.markRows = true

    self.headersList = {} -- ordered TableHeaderElement references
    self.headersHash = {} -- reverse mapping of headersList

    -- sort state fields for intermittent invalidate calls outside of onClickHeader():
    self.sortingOrder = TableHeaderElement.SORTING_OFF
    self.sortingColumn = nil
    self.sortingAscending = false

    self.numActiveRows = 0

    self.customSortFunction = nil
    self.customSortBeforeData = false
    self.customSortIsFilter = false

    self.data = {} -- stores table data in the format given by the table's row template, using element names as keys if defined
    self.tableRows = {} -- visible GUI element rows of the table, replicated from a template
    self.dataView = {} -- same as self.data but using ordered integer keys instead of arbitrary row identifiers
    self.selectedId = "" -- currently selected row ID, separate from selected index

    self.navigationMode = TableElement.NAV_MODE_ROWS

    self.lateInitialization = false
    self.isInitialized = false -- intialization flag

    return self
end


---
function TableElement:loadFromXML(xmlFile, key)
    TableElement:superClass().loadFromXML(self, xmlFile, key)

    local colNames = Utils.getNoNil(getXMLString(xmlFile, key.."#columnNames"), "")
    for i, name in ipairs(colNames:split(" ")) do
        self.columnNames[name] = name -- make it a hash set
    end

    self.rowTemplateName = Utils.getNoNil(getXMLString(xmlFile, key.."#rowTemplateName"), self.rowTemplateName)
    local navMode = getXMLString(xmlFile, key.."#navigationMode") or self.navigationMode
    self.navigationMode = NAV_MODES[navMode] or self.navigationMode

    self.periodicUpdate = Utils.getNoNil(getXMLBool(xmlFile, key.."#periodicUpdate"), self.periodicUpdate)
    local updateSeconds = Utils.getNoNil(getXMLFloat(xmlFile, key.."#updateInterval"), self.updateInterval / 1000)
    self.updateInterval = updateSeconds * 1000 -- convert to ms

    self.markRows = Utils.getNoNil(getXMLBool(xmlFile, key.."#markRows"), self.markRows)
    self.lateInitialization = Utils.getNoNil(getXMLBool(xmlFile, key.."#lateInitialization"), self.lateInitialization)

    self:addCallback(xmlFile, key.."#onUpdate", "onUpdateCallback")
end


---
function TableElement:loadProfile(profile, applyProfile)
    TableElement:superClass().loadProfile(self, profile, applyProfile)

    local navMode = profile:getValue("navigationMode", self.navigationMode)
    self.navigationMode = NAV_MODES[navMode] or self.navigationMode

    self.periodicUpdate = profile:getBool("periodicUpdate", self.periodicUpdate)
    local updateSeconds = profile:getNumber("updateInterval", self.updateInterval / 1000)
    self.updateInterval = updateSeconds * 1000 -- convert to ms

    self.markRows = profile:getBool("markRows", self.markRows)
    self.lateInitialization = profile:getBool("lateInitialization", self.lateInitialization)
end


---
function TableElement:copyAttributes(src)
    TableElement:superClass().copyAttributes(self, src)

    self.columnNames = src.columnNames
    self.rowTemplateName = src.rowTemplateName
    self.navigationMode = src.navigationMode

    self.periodicUpdate = src.periodicUpdate
    self.updateInterval = src.updateInterval

    self.markRows = src.markRows

    self.onUpdateCallback = src.onUpdateCallback

    self.lateInitialization = src.lateInitialization
    self.isInitialized = src.isInitialized -- copy initialization flag for cloned tables
end


---Called when the GUI is completely loaded. Link relevant collaborators of this table.
function TableElement:onGuiSetupFinished()
    TableElement:superClass().onGuiSetupFinished(self)

    if not self.lateInitialization then
        self:initialize()
    end
end


---
function TableElement:initialize()
    if not self.isInitialized then
        -- find and store headers, start search at parent (headers must be defined outside of table)
        local onlyMyHeaders = function(element)
            return element.targetTableId and element.targetTableId == self.id
        end
        self.headersList = self.parent:getDescendants(onlyMyHeaders)

        -- populate reverse hash of header list
        for i, header in ipairs(self.headersList) do
            self.headersHash[header] = i
        end

        self:buildTableRows()
        self:applyAlternatingBackgroundsToRows()

        -- invalidate layout to position row elements
        self:invalidateLayout()
    end

    self.isInitialized = true
end










































































































































---
function TableElement:updateAlternatingBackground()
    -- we do our own coloring
end















































































































































































































































































































































































































































































---Update selection state of table rows
-- @return Index of selected row
function TableElement:updateRowSelection()
    local selectedTableRowIndex = 0
    if self.selectedIndex ~= 0 and #self.dataView > 0 then
        for i, tableRow in ipairs(self.tableRows) do
            local selected = self.selectedIndex == tableRow.dataRowIndex and self.markRows
            if tableRow.rowElement.setSelected then
                tableRow.rowElement:setSelected(selected)
            end
            if selected then
                selectedTableRowIndex = i
            end
        end
    end
    return selectedTableRowIndex
end


---Get an item factor for visual proportions.
Override from ListElement: Simplified table interaction with slider element to require straight indices only.
Therefore this only needs to return 1 now.
-- @return 1  
function TableElement:getItemFactor()
    return 1
end


---
function TableElement:scrollList(delta)
    if delta ~= 0 then
        self:scrollTo(self.firstVisibleItem + delta)
    end
end






























































































































































































































---Lock and delay up and down directions for focus navigation.
function TableElement:delayNavigationInput()
    FocusManager:lockFocusInput(InputAction.MENU_AXIS_UP_DOWN, TableElement.NAVIGATION_DELAY, 1)
    FocusManager:lockFocusInput(InputAction.MENU_AXIS_UP_DOWN, TableElement.NAVIGATION_DELAY, -1)
end


---
function TableElement:onSliderValueChanged(slider, newValue)
    self:scrollTo(newValue, false)
end


---
function TableElement:update(dt)
    TableElement:superClass().update(self, dt)

    self.timeSinceLastInput = self.timeSinceLastInput + dt

    if self.periodicUpdate then
        self.timeSinceLastUpdate = self.timeSinceLastUpdate + dt
        if self.timeSinceLastUpdate >= self.updateInterval then
            self:raiseCallback("onUpdateCallback", self)
            self.timeSinceLastUpdate = 0
        end
    end
end


---
function TableElement:verifyListItemConfiguration()
    -- Ignore parent there are no list item sizes
end
