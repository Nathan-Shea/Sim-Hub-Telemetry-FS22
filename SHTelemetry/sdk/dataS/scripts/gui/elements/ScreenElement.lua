---Base screen element. All full-screen GUI views inherit from this.
--ScreenElement inherits from FrameElement and has no additional configuration, but contains UI logic shared across all
--full screen views.
















local ScreenElement_mt = Class(ScreenElement, FrameElement)


---
function ScreenElement.new(target, custom_mt)
    local self = FrameElement.new(target, custom_mt or ScreenElement_mt)

    self.isBackAllowed = true
    self.handleCursorVisibility = true
    self.returnScreenName = nil
    self.returnScreen = nil
    self.returnScreenClass = nil
    self.isOpen = false
    self.lastMouseCursorState = false
    self.isInitialized = false
    self.nextClickSoundMuted = false

    self:registerControls(ScreenElement.CONTROLS)

    return self
end


---
function ScreenElement:onOpen()
    -- Break inheritance here to avoid callback loops
    local rootElement = self:getRootElement()
    -- we need to run onOpen() only on children of the screen root element because the root usually has the main
    -- callbacks on itself
    for _, child in ipairs(rootElement.elements) do
        child:onOpen()
    end

    if not self.isInitialized then
        self:initializeScreen()
    end

    self.lastMouseCursorState = g_inputBinding:getShowMouseCursor()
    g_inputBinding:setShowMouseCursor(true)

    self.isOpen = true
end


---
function ScreenElement:initializeScreen()
    self.isInitialized = true

    if self.pageSelector ~= nil and self.pageSelector.disableButtonSounds ~= nil then
        -- disable click sounds for page selector buttons, we use the paging sound in separate screen logic
        self.pageSelector:disableButtonSounds()
    end
end


---
function ScreenElement:onClose()
    -- Break inheritance here to avoid callback loops
    local rootElement = self:getRootElement()
    -- we need to run onClose() only on children of the screen root element because the root usually has the main
    -- callbacks on itself
    for _, child in ipairs(rootElement.elements) do
        child:onClose()
    end

    if self.handleCursorVisibility then
        g_inputBinding:setShowMouseCursor(self.lastMouseCursorState)
    end

    self.isOpen = false
end















































































---
function ScreenElement:invalidateScreen()
end






















---
function ScreenElement:inputEvent(action, value, eventUsed)
    eventUsed = ScreenElement:superClass().inputEvent(self, action, value, eventUsed)

    if self.inputDisableTime <= 0 then
        -- handle special case for screen paging controls:
        if self.pageSelector ~= nil and (action == InputAction.MENU_PAGE_PREV or action == InputAction.MENU_PAGE_NEXT) then
            if action == InputAction.MENU_PAGE_PREV then
                self:onPagePrevious()
            elseif action == InputAction.MENU_PAGE_NEXT then
                self:onPageNext()
            end
            -- always consume event to avoid triggering any other focused elements
            eventUsed = true
        end

        if not eventUsed then
            -- Directly access screen element subclass events by button presses. The abstract implementation of these
            -- methods in this class return true, so that we can evaluate if there is no concrete implementation. In
            -- that case, the event must not be consumed.
            eventUsed = ScreenElement.callButtonsWithAction(self.elements, action)
        end
    end

    return eventUsed
end













---
function ScreenElement:setReturnScreen(screenName, screen)
    self.returnScreenName = screenName
    self.returnScreen = screen
end


---Set the class of the return screen which should be opened when the "back" action is triggered on this screen.
function ScreenElement:setReturnScreenClass(returnScreenClass)
    self.returnScreenClass = returnScreenClass
end


---
function ScreenElement:getIsOpen()
    return self.isOpen
end


---
function ScreenElement:canReceiveFocus()
    if not self.visible then
        return false
    end

    -- element can only receive focus if all sub elements are ready to receive focus
    for i = 1, #self.elements do
        if not self.elements[i]:canReceiveFocus() then
            return false
        end
    end

    return true
end


---Mute the next click sound. Used to override click sounds for the activate/cancel actions
function ScreenElement:setNextScreenClickSoundMuted(value)
    if value == nil then
        value = true
    end
    self.nextClickSoundMuted = value
end
