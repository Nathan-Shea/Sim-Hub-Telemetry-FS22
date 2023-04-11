---Animal Buying Screen.

















































local AnimalScreen_mt = Class(AnimalScreen, ScreenElement)


---Constructor
-- @param table target 
-- @param table metatable 
-- @return table self instance
function AnimalScreen.new(custom_mt)
    local self = ScreenElement.new(nil, custom_mt or AnimalScreen_mt)

    self:registerControls(AnimalScreen.CONTROLS)

    self.isSourceSelected = true

    self.isOpen = false
    self.lastBalance = 0

    self.selectionState = AnimalScreen.SELECTION_NONE

    return self
end










































---Callback on open
function AnimalScreen:onOpen()
    AnimalScreen:superClass().onOpen(self)

    self.isOpen = true
    self.isUpdating = false

    g_gameStateManager:setGameState(GameState.MENU_ANIMAL_SHOP)
    g_depthOfFieldManager:pushArea(0, 0, 1, 1)

    self:updateScreen()
    self:setSelectionState(AnimalScreen.SELECTION_NONE)

    -- initialize selection and focus
    if self.listSource:getItemCount() > 0 then
        FocusManager:setFocus(self.listSource)
    elseif self.listTarget:getItemCount() > 0 then
        FocusManager:setFocus(self.listTarget)
    end

    self:toggleCustomInputContext(true, AnimalScreen.INPUT_CONTEXT)
    self:registerActionEvents()
end


---Callback on close
-- @param table element 
function AnimalScreen:onClose(element)
    AnimalScreen:superClass().onClose(self)
    self.controller:reset()
    self.isOpen = false

    self:removeActionEvents()
    self:toggleCustomInputContext(false, AnimalScreen.INPUT_CONTEXT)

    g_currentMission:resetGameState()

    g_currentMission:showMoneyChange(MoneyType.NEW_ANIMALS_COST)
    g_currentMission:showMoneyChange(MoneyType.SOLD_ANIMALS)

    g_messageCenter:unsubscribeAll(self)

    g_depthOfFieldManager:popArea()
end






































































































































































































































---Callback on click back
function AnimalScreen:onClickBack()
    AnimalScreen:superClass().onClickBack(self)

    if self.selectionState == AnimalScreen.SELECTION_NONE then
        self:changeScreen(nil)
    else
        self:setSelectionState(AnimalScreen.SELECTION_NONE)
    end
end


---Callback on click cancel
function AnimalScreen:onClickSelect()

    if self.isSourceSelected then
        self:setSelectionState(AnimalScreen.SELECTION_SOURCE)
    else
        self:setSelectionState(AnimalScreen.SELECTION_TARGET)
    end

    return true
end














































---Remove non-GUI input action events.
function AnimalScreen:removeActionEvents()
    g_inputBinding:removeActionEventsByTarget(self)
end
