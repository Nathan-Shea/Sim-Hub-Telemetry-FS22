---Top-down cursor









local GuiTopDownCursor_mt = Class(GuiTopDownCursor)


































































---
function GuiTopDownCursor:delete()
    if self.isActive then
        self:deactivate()
    end

    if self.cursorOverlay ~= nil then
        self.cursorOverlay:delete()
        self.cursorOverlay = nil
    end

    if self.rootNode ~= nil then
        delete(self.rootNode)
    end
end
































---Activate the cursor. This will show the cursor and take some input.
function GuiTopDownCursor:activate()
    self.isActive = true
    self:onInputModeChanged({self.inputManager:getLastInputMode()})

    if not self.shapesLoaded then
        self:loadShapes()
    end

    setVisibility(self.rootNode, self.isVisible)

    self:registerActionEvents()
    self.messageCenter:subscribe(MessageType.INPUT_MODE_CHANGED, self.onInputModeChanged, self)
end


---Deactivate the cursor. This will hide the cursor and stop any grabbing of input.
function GuiTopDownCursor:deactivate()
    setVisibility(self.rootNode, false)

    self.messageCenter:unsubscribeAll(self)
    self:removeActionEvents()

    self.isActive = false
end








































































































































































































































































































































---Register required action events for the cursor.
function GuiTopDownCursor:registerActionEvents()
    local _, eventId = self.inputManager:registerActionEvent(InputAction.AXIS_CONSTRUCTION_CURSOR_ROTATE, self, self.onRotate, false, false, true, false)
    self.rotateEventId = eventId

    self.inputManager:setActionEventActive(self.rotateEventId, self.rotationEnabled)
    self.inputManager:setActionEventTextPriority(self.rotateEventId, GS_PRIO_NORMAL)
end


---Remove action events registered for the cursor.
function GuiTopDownCursor:removeActionEvents()
    self.rotateEventId = nil

    self.inputManager:removeActionEventsByTarget(self)
end


---Handle mouse moves that are not caught by actions.
function GuiTopDownCursor:mouseEvent(posX, posY, isDown, isUp, button)
    if self.mouseDisabled then
        return
    end

    -- if self.isMouseMode and not self.isCatchingCursor then
    --     self.mousePosX = posX
    --     self.mousePosY = posY
    -- end

    if self.lastActionFrame >= g_time then
        return
    end

    -- Mouse move only happens when other actions did not
    if self.isCatchingCursor then
        self.isCatchingCursor = false
        self.inputManager:setShowMouseCursor(true, true)

        wrapMousePosition(self.lockedMousePosX, self.lockedMousePosY)

        self.inputManager.mousePosXLast, self.inputManager.mousePosYLast = self.lockedMousePosX, self.lockedMousePosY

        self.mousePosX = self.lockedMousePosX
        self.mousePosY = self.lockedMousePosY
    else
        if self.isMouseMode then
            self.mousePosX = posX
            self.mousePosY = posY
        end
    end
end








































---Called when the mouse input mode changes.
function GuiTopDownCursor:onInputModeChanged(inputMode)
    self.isMouseMode = inputMode[1] == GS_INPUT_HELP_MODE_KEYBOARD

    -- Reset to center of screen
    if not self.isMouseMode then
        self.mousePosX = 0.5
        self.mousePosY = 0.5
    end
end
