---Input handling for brushes




































local ConstructionScreen_mt = Class(ConstructionScreen, ScreenElement)


---Constructor
-- @param table target 
-- @param table metatable 
-- @return table self instance
function ConstructionScreen.new(target, customMt, l10n, messageCenter, inputManager)
    local self = ConstructionScreen:superClass().new(target, customMt or ConstructionScreen_mt)

    self:registerControls(ConstructionScreen.CONTROLS)

    self.inputManager = inputManager
    self.l10n = l10n
    self.messageCenter = messageCenter

    self.isMouseMode = true

    self.camera = GuiTopDownCamera.new(nil, messageCenter, inputManager)
    self.cursor = GuiTopDownCursor.new(nil, messageCenter, inputManager)
    self.sound = ConstructionSound.new()

    self.brush = nil

    self.items = {}
    self.clonedElements = {}
    self.menuEvents = {}
    self.brushEvents = {}
    self.marqueeBoxes = {}

    return self
end




















---Callback on open
function ConstructionScreen:onOpen()
    ConstructionScreen:superClass().onOpen(self)

    -- Used for a basic undo feature
    g_currentMission.lastConstructionScreenOpenTime = g_time

    self.inputManager:setContext(ConstructionScreen.INPUT_CONTEXT)

    self.camera:setTerrainRootNode(g_currentMission.terrainRootNode)
    self.camera:setControlledPlayer(g_currentMission.player)
    self.camera:setControlledVehicle(g_currentMission.controlledVehicle)

    self.camera:activate()
    self.cursor:activate()

    g_currentMission.hud.ingameMap:setTopDownCamera(self.camera)

    -- Initial brush is always the selector
    if self.selectorBrush == nil then
        local class = g_constructionBrushTypeManager:getClassObjectByTypeName("select")
        self.selectorBrush = class.new(nil, self.cursor)
    end
    self:setBrush(self.selectorBrush, true)

    if self.destructBrush == nil then
        local class = g_constructionBrushTypeManager:getClassObjectByTypeName("destruct")
        self.destructBrush = class.new(nil, self.cursor)
    end
    self.destructMode = false

    -- We need to know when mouse/gamepad changes
    self.isMouseMode = self.inputManager.lastInputMode == GS_INPUT_HELP_MODE_KEYBOARD
    self.messageCenter:subscribe(MessageType.INPUT_MODE_CHANGED, self.onInputModeChanged, self)

    -- Initial blur
    g_depthOfFieldManager:pushArea(self.menuBox.absPosition[1], self.menuBox.absPosition[2], self.menuBox.absSize[1], self.menuBox.absSize[2])

    -- TODO: only load once every mission
    self:rebuildData()

    self:resetMenuState()
    self:updateMenuState()

    self.messageCenter:subscribe(MessageType.SLOT_USAGE_CHANGED, self.onSlotUsageChanged, self)
end


---Callback on close
-- @param table element 
function ConstructionScreen:onClose(element)
    self.messageCenter:unsubscribeAll(self)

    -- Reset so it is known it is currently not open
    g_currentMission.lastConstructionScreenOpenTime = -1

    -- This will deactivate the selector brush
    self:setBrush(nil)

    self.cursor:deactivate()
    self.camera:deactivate()

    g_currentMission.hud.ingameMap:setTopDownCamera(nil)

    g_depthOfFieldManager:popArea()

    self:removeMenuActionEvents()
    self.inputManager:revertContext()

    ConstructionScreen:superClass().onClose(self)
end

























































































































































































































































---Register required action events for the camera.
function ConstructionScreen:registerBrushActionEvents()
    local _, eventId

    local brush = self.brush
    if brush == nil then
        return
    end

    self.brushEvents = {}

    -- We need primary button also to select objects without brush
    if brush.supportsPrimaryButton then
        if brush.supportsPrimaryDragging then
            _, eventId = self.inputManager:registerActionEvent(InputAction.CONSTRUCTION_ACTION_PRIMARY, self, self.onButtonPrimaryDrag, true, true, true, true)
            table.insert(self.brushEvents, eventId)

            self.primaryBrushEvent = eventId
        else
            _, eventId = self.inputManager:registerActionEvent(InputAction.CONSTRUCTION_ACTION_PRIMARY, self, self.onButtonPrimary, false, true, false, true)
            table.insert(self.brushEvents, eventId)

            self.primaryBrushEvent = eventId
        end

        self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
    end

    if brush.supportsSecondaryButton then
        if brush.supportsSecondaryDragging then
            _, eventId = self.inputManager:registerActionEvent(InputAction.CONSTRUCTION_ACTION_SECONDARY, self, self.onButtonSecondaryDrag, true, true, true, true)
            table.insert(self.brushEvents, eventId)

            self.secondaryBrushEvent = eventId
        else
            _, eventId = self.inputManager:registerActionEvent(InputAction.CONSTRUCTION_ACTION_SECONDARY, self, self.onButtonSecondary, false, true, false, true)
            table.insert(self.brushEvents, eventId)

            self.secondaryBrushEvent = eventId
        end

        self.inputManager:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
    end

    if brush.supportsTertiaryButton then
        _, self.tertiaryBrushEvent = self.inputManager:registerActionEvent(InputAction.CONSTRUCTION_ACTION_TERTIARY, self, self.onButtonTertiary, false, true, false, true)
        self.inputManager:setActionEventTextPriority(self.tertiaryBrushEvent, GS_PRIO_HIGH)
        table.insert(self.brushEvents, self.tertiaryBrushEvent)
    end

    if brush.supportsFourthButton then
        _, self.fourthBrushEvent = self.inputManager:registerActionEvent(InputAction.CONSTRUCTION_ACTION_FOURTH, self, self.onButtonFourth, false, true, false, true)
        self.inputManager:setActionEventTextPriority(self.fourthBrushEvent, GS_PRIO_HIGH)
        table.insert(self.brushEvents, self.fourthBrushEvent)
    end

    -- Action axis: trigger on down. They are step-based axis or continuous, defined by the brush.

    if brush.supportsPrimaryAxis then
        _, self.primaryBrushAxisEvent = self.inputManager:registerActionEvent(InputAction.AXIS_CONSTRUCTION_ACTION_PRIMARY, self, self.onAxisPrimary, false, not brush.primaryAxisIsContinuous, brush.primaryAxisIsContinuous, true)
        self.inputManager:setActionEventTextPriority(self.primaryBrushAxisEvent, GS_PRIO_HIGH)
        table.insert(self.brushEvents, self.primaryBrushAxisEvent)
    end

    if brush.supportsSecondaryAxis then
        _, self.secondaryBrushAxisEvent = self.inputManager:registerActionEvent(InputAction.AXIS_CONSTRUCTION_ACTION_SECONDARY, self, self.onAxisSecondary, false, not brush.secondaryAxisIsContinuous, brush.secondaryAxisIsContinuous, true)
        self.inputManager:setActionEventTextPriority(self.secondaryBrushAxisEvent, GS_PRIO_HIGH)
        table.insert(self.brushEvents, self.secondaryBrushAxisEvent)
    end

    if brush.supportsSnapping then
        _, self.snappingBrushEvent = g_inputBinding:registerActionEvent(InputAction.CONSTRUCTION_ACTION_SNAPPING, self, self.onButtonSnapping, false, true, false, true)
        g_inputBinding:setActionEventTextPriority(self.snappingBrushEvent, GS_PRIO_HIGH)
        table.insert(self.brushEvents, self.snappingBrushEvent)
    end
end





























































---Remove action events registered on this screen.
function ConstructionScreen:removeBrushActionEvents()
    for _, event in ipairs(self.brushEvents) do
        self.inputManager:removeActionEvent(event)
    end

    self.primaryBrushEvent = nil
    self.secondaryBrushEvent = nil
    self.tertiaryBrushEvent = nil
    self.fourthBrushEvent = nil
    self.primaryBrushAxisEvent = nil
    self.secondaryBrushAxisEvent = nil
    self.snappingBrushEvent = nil
end
