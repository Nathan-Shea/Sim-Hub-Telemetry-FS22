---Number of menu buttons which can be modified by pages.








local TabbedMenu_mt = Class(TabbedMenu, ScreenElement)







































---
function TabbedMenu.new(target, customMt, messageCenter, l10n, inputManager)
    local self = ScreenElement.new(target, customMt or TabbedMenu_mt)

    self:registerControls(TabbedMenu.CONTROLS)

    self.messageCenter = messageCenter
    self.l10n = l10n
    self.inputManager = inputManager

    self.pageFrames = {} -- FrameElement instances array in order of display
    self.pageTabs = {} -- Page tabs in the header, {FrameElement -> ListItemElement}
    self.pageTypeControllers = {} -- Mapping of page FrameElement sub-classes to the controller instances
    self.pageRoots = {} -- Mapping of page controller instances to their original root GuiElements
    self.pageEnablingPredicates = {} -- Mapping of page controller instances to enabling predicate functions (if return true -> enable)
    self.disabledPages = {} -- hash of disabled paging controllers to avoid re-activation in updatePages()
    self.pageToTabIndex = {}

    self.currentPageId = 1
    self.currentPageName = "" -- currently active page name for focus context setting
    self.currentPage = nil -- current page controller reference

    self.restorePageIndex = 1 -- memorized menu page mapping index (initialize on index 1 for the map overview)
    self.restorePageScrollIndex = 1

    self.buttonActionCallbacks = {} -- InputAction name -> function
    self.defaultButtonActionCallbacks = {} -- InputAction name -> function
    self.defaultMenuButtonInfoByActions = {}
    self.customButtonEvents = {} -- array of event IDs from InputBinding

    self.clickBackCallback = NO_CALLBACK

    self.frameClosePageNextCallback = self:makeSelfCallback(self.onPageNext)
    self.frameClosePagePreviousCallback = self:makeSelfCallback(self.onPagePrevious)

    -- Subclass configuration
    self.performBackgroundBlur = false

    return self
end


---
function TabbedMenu:delete()
    self.messageCenter:unsubscribeAll(self)
    self.pagingTabTemplate:delete() -- need to delete the template here because we have unlinked it during setup

    for _, tab in pairs(self.pageTabs) do
        tab:delete()
    end

    TabbedMenu:superClass().delete(self)
end


---
function TabbedMenu:onGuiSetupFinished()
    TabbedMenu:superClass().onGuiSetupFinished(self)

    self.clickBackCallback = self:makeSelfCallback(self.onButtonBack)

    -- take the tab template out of the element hierarchy, later we clone it as needed (and delete it separately)
    self.pagingTabTemplate:unlinkElement()

    self:setupMenuButtonInfo()

    self.header.parent:addElement(self.header) -- re-add (will remove first, does not copy) header as last child to draw on top

    if self.pagingElement.profile == "uiInGameMenuPaging" then
        self.pagingElement:setSize(1 - self.header.absSize[1])
    end
end


---
function TabbedMenu:exitMenu()
    self:changeScreen(nil)
end


---
function TabbedMenu:reset()
    TabbedMenu:superClass().reset(self)

    self.currentPageId = 1
    self.currentPageName = ""
    self.currentPage = nil

    self.restorePageIndex = 1
    self.restorePageScrollIndex = 1
end


---Handle in-game menu opening event.
function TabbedMenu:onOpen(element)
    TabbedMenu:superClass().onOpen(self)

    if self.performBackgroundBlur then
        g_depthOfFieldManager:pushArea(0, 0, 1, 1)
    end

    if not self.muteSound then
        self:playSample(GuiSoundPlayer.SOUND_SAMPLES.PAGING)
    end

    if self.gameState ~= nil then
        g_gameStateManager:setGameState(self.gameState)
    end

    -- Disable all focus sounds. We play our own for opening the menu
    self:setSoundSuppressed(true)

    -- setup menus
    self:updatePages()

    -- restore last selected page
    if self.restorePageIndex ~= nil then
        self.pageSelector:setState(self.restorePageIndex, true)
        self.pagingTabList:scrollTo(self.restorePageScrollIndex)
    end

    self:setSoundSuppressed(false)

    self:onMenuOpened()
end


---Handle in-game menu closing event.
function TabbedMenu:onClose(element)
    if self.currentPage ~= nil then
        self.currentPage:onFrameClose() -- the current page gets its specific close event first
    end

    TabbedMenu:superClass().onClose(self)

    if self.performBackgroundBlur then
        g_depthOfFieldManager:popArea()
    end

    self.inputManager:storeEventBindings() -- reset any disabled bindings for page custom input in menu context
    self:clearMenuButtonActions()

    self.restorePageIndex = self.pageSelector:getState()
    self.restorePageScrollIndex = self.pagingTabList.firstVisibleItem

    if self.gameState ~= nil then
        g_currentMission:resetGameState()
    end
end


---Update the menu state each frame.
This uses a state machine approach for the game saving process.
function TabbedMenu:update(dt)
    TabbedMenu:superClass().update(self, dt)

    -- Enforce the current page as the focus context. This is required because dialogs on dialogs (e.g. during saving)
    -- can break reverting to a valid focus state in this menu.
    if FocusManager.currentGui ~= self.currentPageName and not g_gui:getIsDialogVisible() then
        FocusManager:setGui(self.currentPageName)
    end

    if self.currentPage ~= nil then
        if self.currentPage:isMenuButtonInfoDirty() then
            self:assignMenuButtonInfo(self.currentPage:getMenuButtonInfo())
            self.currentPage:clearMenuButtonInfoDirty()
        end
        if self.currentPage:isTabbingMenuVisibleDirty() then
            self:updatePagingVisibility(self.currentPage:getTabbingMenuVisible())
        end
    end
end






---Setup the menu buttons. Override to initialize
function TabbedMenu:setupMenuButtonInfo()
end


---Add a page tab in the menu header.
Call this synchronously with TabbedMenu:registerPage() to ensure a correct order of pages and tabs.
function TabbedMenu:addPageTab(frameController, iconFilename, iconUVs)
    local tab = self.pagingTabTemplate:clone()
    tab:fadeIn()
    self.pagingTabList:addElement(tab)
    self.pageTabs[frameController] = tab

    local tabButton = tab:getDescendantByName(TabbedMenu.PAGE_TAB_TEMPLATE_BUTTON_NAME)
    tabButton:setImageFilename(nil, iconFilename)
    tabButton:setImageUVs(nil, iconUVs)

    tabButton.onClickCallback = function()
        self:onPageClicked(self.activeDetailPage)

        local pageId = self.pagingElement:getPageIdByElement(frameController)
        local pageMappingIndex = self.pagingElement:getPageMappingIndex(pageId)

        self.pageSelector:setState(pageMappingIndex, true) -- set state with force event
    end
end


---
function TabbedMenu:onPageClicked(oldPage)
end


---Set enabled state of a page tab in the header.
function TabbedMenu:setPageTabEnabled(pageController, isEnabled)
    local tab = self.pageTabs[pageController]
    tab:setDisabled(not isEnabled)
    tab:setVisible(isEnabled)
end


---Rebuild page tab list in order.
function TabbedMenu:rebuildTabList()
    self.pageToTabIndex = {}

    -- removeAllitems does not work... so we do it manually
    for i = #self.pagingTabList.listItems, 1, -1 do
        local tab = self.pagingTabList.listItems[i]
        self.pagingTabList:removeElement(tab)
    end

    for i, page in ipairs(self.pageFrames) do
        local tab = self.pageTabs[page]

        local pageId = self.pagingElement:getPageIdByElement(page)
        local enabled = not self.pagingElement:getIsPageDisabled(pageId)

        -- Add any enabled item. List will scroll for us to keep selection in view
        if enabled then
            self.pagingTabList:addElement(tab)
            self.pageToTabIndex[i] = #self.pagingTabList.listItems
        end
    end

    self.pagingTabList.firstVisibleItem = 1


    local listIndex = self.pageToTabIndex[self.currentPageId]
    if listIndex ~= nil then
        local direction = 0--MathUtil.sign(listIndex - oldIndex)
        self.pagingTabList:setSelectedIndex(listIndex, true, direction)
    end
end


---Update page enabled states.
function TabbedMenu:updatePages()
    for pageElement, predicate in pairs(self.pageEnablingPredicates) do
        local pageId = self.pagingElement:getPageIdByElement(pageElement)
        local enable = self.disabledPages[pageElement] == nil and predicate()

        self.pagingElement:setPageIdDisabled(pageId, not enable)
        self:setPageTabEnabled(pageElement, enable)
    end

    self:rebuildTabList()
    self:updatePageTabDisplay()
    self:setPageSelectorTitles()
    self:updatePageControlVisibility()
end


---Update page tabs display after any page changes.
function TabbedMenu:updatePageTabDisplay()
end


---
function TabbedMenu:updatePageControlVisibility()
    local showButtons = #self.pagingTabList.listItems ~= 1

    self.pagingButtonLeft:setVisible(showButtons)
    self.pagingButtonRight:setVisible(showButtons)
end


---Clear menu button actions, events and callbacks.
function TabbedMenu:clearMenuButtonActions()
    for k in pairs(self.buttonActionCallbacks) do
        self.buttonActionCallbacks[k] = nil
    end

    for i in ipairs(self.customButtonEvents) do
        self.inputManager:removeActionEvent(self.customButtonEvents[i])
        self.customButtonEvents[i] = nil
    end
end


---Assign menu button information to the in-game menu buttons.
function TabbedMenu:assignMenuButtonInfo(menuButtonInfo)
    self:clearMenuButtonActions()

    for i, button in ipairs(self.menuButton) do
        local info = menuButtonInfo[i]
        local hasInfo = info ~= nil
        button:setVisible(hasInfo)

        -- Do not show actions when the game is paused unless specified
        if hasInfo and info.inputAction ~= nil and InputAction[info.inputAction] ~= nil then
            button:setInputAction(info.inputAction)

            local buttonText = info.text
            if buttonText == nil and self.defaultMenuButtonInfoByActions[info.inputAction] ~= nil then
                buttonText = self.defaultMenuButtonInfoByActions[info.inputAction].text
            end
            button:setText(buttonText)

            local buttonClickCallback = info.callback or self.defaultButtonActionCallbacks[info.inputAction] or NO_CALLBACK

            if GS_IS_MOBILE_VERSION then
                if info.profile ~= nil then
                    button:applyProfile(info.profile)
                else
                    button:applyProfile("buttonBack")
                end
            end

            local sound = GuiSoundPlayer.SOUND_SAMPLES.CLICK
            if info.inputAction == InputAction.MENU_BACK then
                sound = GuiSoundPlayer.SOUND_SAMPLES.BACK
            end

            if info.clickSound ~= nil and info.clickSound ~= sound then
                sound = info.clickSound

                -- We need to activate the sound by hand so that it is also played for gamepad and keyboard input
                -- as those are not triggered by the button
                local oldButtonClickCallback = buttonClickCallback
                buttonClickCallback = function (...)
                    self:playSample(sound)
                    self:setNextScreenClickSoundMuted()

                    return oldButtonClickCallback(...)
                end

                -- Deactivate sound on button to prevent double-sounds
                button:setClickSound(GuiSoundPlayer.SOUND_SAMPLES.NONE)
            else
                button:setClickSound(sound)
            end

            local showForGameState = GS_IS_MOBILE_VERSION or (not self.paused or info.showWhenPaused)
            local showForCurrentState = showForGameState or info.inputAction == InputAction.MENU_BACK

            local disabled = info.disabled or not showForCurrentState
            if not disabled then
                if not TabbedMenu.DEFAULT_BUTTON_ACTIONS[info.inputAction] then
                    local _, eventId = self.inputManager:registerActionEvent(info.inputAction, InputBinding.NO_EVENT_TARGET, buttonClickCallback, false, true, false, true)
                    table.insert(self.customButtonEvents, eventId) -- store event ID to remove again on page change
                else
                    self.buttonActionCallbacks[info.inputAction] = buttonClickCallback
                end
            end

            button.onClickCallback = buttonClickCallback
            button:setDisabled(disabled)
        end
    end

    -- make sure that menu exit is always possible:
    if self.buttonActionCallbacks[InputAction.MENU_BACK] == nil then
        self.buttonActionCallbacks[InputAction.MENU_BACK] = self.clickBackCallback
    end

    self.buttonsPanel:invalidateLayout()
end


---Get page titles from currently visible pages and apply to the selector element.
function TabbedMenu:setPageSelectorTitles()
    local texts = self.pagingElement:getPageTitles()

    self.pageSelector:setTexts(texts)
    self.pageSelector:setDisabled(#texts == 1)

    -- Update state without triggering any events
    local id = self.pagingElement:getCurrentPageId()
    self.pageSelector.state = self.pagingElement:getPageMappingIndex(id)
end


---
function TabbedMenu:goToPage(page, muteSound)
    local oldMute = self.muteSound
    self.muteSound = muteSound

    local index = self.pagingElement:getPageMappingIndexByElement(page)
    if index ~= nil then
        self.pageSelector:setState(index, true)
    end

    self.muteSound = oldMute
end


---
function TabbedMenu:updatePagingVisibility(visible)
    self.header:setVisible(visible)
end






---Handle a menu action click by calling one of the menu button callbacks.
-- @return bool True if no callback was present and no action was taken, false otherwise
function TabbedMenu:onMenuActionClick(menuActionName)
    local buttonCallback = self.buttonActionCallbacks[menuActionName]
    if buttonCallback ~= nil and buttonCallback ~= NO_CALLBACK then
        return buttonCallback() or false
    end

    return true
end


---Handle menu confirmation input event.
function TabbedMenu:onClickOk()
    -- do not call the super class event here so we can always handle this event any way we need
    local eventUnused = self:onMenuActionClick(InputAction.MENU_ACCEPT)
    return eventUnused
end


---Handle menu back input event.
function TabbedMenu:onClickBack()
    local eventUnused = true

    if self.currentPage:requestClose(self.clickBackCallback) then
        eventUnused = TabbedMenu:superClass().onClickBack(self)
        if eventUnused then
            eventUnused = self:onMenuActionClick(InputAction.MENU_BACK)
        end
    end

    return eventUnused
end


---Handle menu cancel input event.
Bound to quite the game to the main menu.
function TabbedMenu:onClickCancel()
    local eventUnused = TabbedMenu:superClass().onClickCancel(self)
    if eventUnused then
        eventUnused = self:onMenuActionClick(InputAction.MENU_CANCEL)
    end

    return eventUnused
end


---Handle menu activate input event.
Bound to save the game.
function TabbedMenu:onClickActivate()
    local eventUnused = TabbedMenu:superClass().onClickActivate(self)
    if eventUnused then
        eventUnused = self:onMenuActionClick(InputAction.MENU_ACTIVATE)
    end

    return eventUnused
end


---Handle menu extra 1 input event.
Used for various functions when convenient buttons run out.
function TabbedMenu:onClickMenuExtra1()
    local eventUnused = TabbedMenu:superClass().onClickMenuExtra1(self)
    if eventUnused then
        eventUnused = self:onMenuActionClick(InputAction.MENU_EXTRA_1)
    end

    return eventUnused
end


---Handle menu extra 2 input event.
Used for various functions when convenient buttons run out.
function TabbedMenu:onClickMenuExtra2()
    local eventUnused = TabbedMenu:superClass().onClickMenuExtra2(self)
    if eventUnused then
        eventUnused = self:onMenuActionClick(InputAction.MENU_EXTRA_2)
    end

    return eventUnused
end


---Handle activation of page selection.
function TabbedMenu:onClickPageSelection(state)
    -- Mobile uses the header for paging within the frame
    if self.pagingElement:setPage(state) and not self.muteSound then
        self:playSample(GuiSoundPlayer.SOUND_SAMPLES.PAGING)
    end
end


---Handle previous page event.
function TabbedMenu:onPagePrevious()
    if GS_IS_MOBILE_VERSION then
        if self.currentPage:getHasPreviousPage() then
            self.currentPage:onPreviousPage()
        end
    else
        if self.currentPage:requestClose(self.frameClosePagePreviousCallback) then
            TabbedMenu:superClass().onPagePrevious(self)
        end
    end
end


---Handle next page event.
function TabbedMenu:onPageNext()
    if GS_IS_MOBILE_VERSION then
        if self.currentPage:getHasNextPage() then
            self.currentPage:onNextPage()
        end
    else
        if self.currentPage:requestClose(self.frameClosePageNextCallback) then
            TabbedMenu:superClass().onPageNext(self)
        end
    end
end


---Handle changing to another menu page.
function TabbedMenu:onPageChange(pageIndex, pageMappingIndex, element, skipTabVisualUpdate)
    -- ask the paging element for the current page which is safer than the currentPage reference (may not be initialized)
    local prevPage = self.pagingElement:getPageElementByIndex(self.currentPageId)

    prevPage:onFrameClose()
    prevPage:setVisible(false)

    self.inputManager:storeEventBindings() -- reset any disabled bindings for page custom input in menu context

    local page = self.pagingElement:getPageElementByIndex(pageIndex)
    self.currentPage = page
    self.currentPageName = page.name -- store page name for FocusManager GUI context override in update()

    if not skipTabVisualUpdate then
        local oldIndex = self.pageToTabIndex[self.currentPageId]
        self.currentPageId = pageIndex

        local listIndex = self.pageToTabIndex[pageIndex]
        if listIndex ~= nil then
            local direction = MathUtil.sign(listIndex - oldIndex)
            self.pagingTabList:setSelectedIndex(listIndex, true, direction)
        end
    end

    page:setVisible(true)
    page:setSoundSuppressed(true)
    FocusManager:setGui(page.name)
    page:setSoundSuppressed(false)
    page:onFrameOpen()

    self:updateButtonsPanel(page)
    self:updateTabDisplay()
end









---Update the buttons panel when a given page is visible.
function TabbedMenu:updateButtonsPanel(page)
    -- assign button info anyway to make at least MENU_BACK work in all cases:
    local buttonInfo = self:getPageButtonInfo(page)
    self:assignMenuButtonInfo(buttonInfo)
end


































---Get button actions and display information for a given menu page.
function TabbedMenu:getPageButtonInfo(page)
    local buttonInfo

    if page:getHasCustomMenuButtons() then
        buttonInfo = page:getMenuButtonInfo()
    else
        buttonInfo = self.defaultMenuButtonInfo
    end

    return buttonInfo
end


---Handle a page being disabled.
function TabbedMenu:onPageUpdate()
end


---
function TabbedMenu:onButtonBack()
    self:exitMenu()
end


---Called when opening the menu, after changing the page
function TabbedMenu:onMenuOpened()
end

















---Register a page frame element in the menu.
This does not add the page to the paging component of the menu.
-- @param table pageFrameElement Page FrameElement instance
-- @param int position [optional] Page position index in menu
-- @param function enablingPredicateFunction [optional] A function which returns the current enabling state of the page
at any time. If the function returns true, the page should be enabled. If no argument is given, the page is
always enabled.
function TabbedMenu:registerPage(pageFrameElement, position, enablingPredicateFunction)
    if position == nil then
        position = #self.pageFrames + 1
    else
        position = math.max(1, math.min(#self.pageFrames + 1, position))
    end

    table.insert(self.pageFrames, position, pageFrameElement)
    self.pageTypeControllers[pageFrameElement:class()] = pageFrameElement
    local pageRoot = pageFrameElement.elements[1]
    self.pageRoots[pageFrameElement] = pageRoot
    self.pageEnablingPredicates[pageFrameElement] = enablingPredicateFunction

    pageFrameElement:setVisible(false) -- set invisible at the start to allow visibility-based behavior for pages

    return pageRoot, position
end



---Unregister a page frame element identified by class from the menu.
This does not remove the page from the paging component of the menu or the corresponding page tab from the header.
-- @param table pageFrameClass FrameElement descendant class of a page which was previously registered
-- @return bool True if there was a page of the given class and it was unregistered
-- @return table Unregistered page controller instance or nil
-- @return table Unregistered page root GuiElement instance or nil
-- @return table Unregistered page tab ListElement instance of nil
function TabbedMenu:unregisterPage(pageFrameClass)
    local pageController = self.pageTypeControllers[pageFrameClass]
    local pageTab = nil
    local pageRoot = nil
    if pageController ~= nil then
        local pageRemoveIndex = -1
        for i, page in ipairs(self.pageFrames) do
            if page == pageController then
                pageRemoveIndex = i
                break
            end
        end

        table.remove(self.pageFrames, pageRemoveIndex)

        pageRoot = self.pageRoots[pageController]
        self.pageRoots[pageController] = nil
        self.pageTypeControllers[pageFrameClass] = nil
        self.pageEnablingPredicates[pageController] = nil

        self.pageTabs[pageController] = nil
    end

    return pageController ~= nil, pageController, pageRoot, pageTab
end














---Add a page frame to be displayed in the menu at runtime.
The page will be part of the in-game menu until restarting the game or removing the page again.

-- @param table pageFrameElement FrameElement instance which is used as a page.
-- @param int position Position index of added page, starting from left at 1 going to right.
-- @param string tabIconFilename Path to the texture file which contains the icon for the page tab in the header
-- @param table tabIconUVs UV array for the tab icon. Format: {x, y, width, height} in pixels on the texture.
-- @param function enablingPredicateFunction [optional] A function which returns the current enabling state of the page
at any time. If the function returns true, the page should be enabled. If no argument is given, the page is
always enabled.
function TabbedMenu:addPage(pageFrameElement, position, tabIconFilename, tabIconUVs, enablingPredicateFunction)
    local pageRoot, actualPosition = self:registerPage(pageFrameElement, position, enablingPredicateFunction)
    self:addPageTab(pageFrameElement, tabIconFilename, GuiUtils.getUVs(tabIconUVs))

    local name = pageRoot.title
    if name == nil then
        name = self.l10n:getText("ui_" .. pageRoot.name)
    end

    self.pagingElement:addPage(string.upper(pageRoot.name), pageRoot, name, actualPosition)
end





---Remove a page from the menu at runtime by its class type.
The removed page is also deleted, including all of its children. Note that this method removes the page for an entire
game run, because the UI is loaded on game start. If you only need to disable a page, use TabbedMenu:setPageEnabled()
instead.

The method will not remove game default pages, but only disable them.

-- @param table pageFrameClass Class table of a FrameElement sub-class
function TabbedMenu:removePage(pageFrameClass)
    local defaultPage = self.pageTypeControllers[pageFrameClass]
    if self.defaultPageElementIDs[defaultPage] ~= nil then
        self:setPageEnabled(pageFrameClass, false)
    else
        local needDelete, pageController, pageRoot, pageTab = self:unregisterPage(pageFrameClass)
        if needDelete then
            self.pagingElement:removeElement(pageRoot)
            pageRoot:delete()
            pageController:delete()

            self.pagingTabList:removeElement(pageTab)
            pageTab:delete()
        end
    end
end


---Set the enabled state of a page identified by its controller class type.
This will also set the controller's state, so it can react to being enabled/disabled. The setting will persist
through calls to TabbedMenu:reset() and must be reverted manually, if necessary.
-- @param table pageFrameClass Class table of a FrameElement sub-class
-- @param bool isEnabled True for enabled, false for disabled
function TabbedMenu:setPageEnabled(pageFrameClass, isEnabled)
    local pageController = self.pageTypeControllers[pageFrameClass]
    if pageController ~= nil then
        local pageId = self.pagingElement:getPageIdByElement(pageController)
        self.pagingElement:setPageIdDisabled(pageId, not isEnabled)

        pageController:setDisabled(not isEnabled)

        if not isEnabled then
            self.disabledPages[pageController] = pageController
        else
            self.disabledPages[pageController] = nil
        end

        self:setPageTabEnabled(pageController, isEnabled)
        self.pagingTabList:updateItemPositions()
    end
end


---
function TabbedMenu:makeSelfCallback(func)
    return function(...)
        return func(self, ...)
    end
end
