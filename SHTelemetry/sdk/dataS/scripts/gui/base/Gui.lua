---Graphical User Interface controller.
--Builds UI from configurations, provides dialog display and propagates UI input.









local Gui_mt = Class(Gui)






































---
function Gui.new(messageCenter, languageSuffix, inputManager, guiSoundPlayer)
    local self = setmetatable({}, Gui_mt)

    self.messageCenter = messageCenter
    self.languageSuffix = languageSuffix
    -- input manager reference for event registration
    self.inputManager = inputManager
    self.soundPlayer = guiSoundPlayer
    FocusManager:setSoundPlayer(guiSoundPlayer)

    self.screens = {} -- screen class -> screen root element
    self.screenControllers = {} -- screen class -> screen instance
    self.dialogs = {}
    self.profiles = {}
    self.traits = {}
    self.focusElements = {}
    self.guis = {}
    self.nameScreenTypes = {}
    self.currentGuiName = ""

    -- registered frame elements which can be referenced to be displayed in multiple places / on multiple screen views
    self.frames = {} -- frame name -> frame controller element

    -- state flag to check if the GUI input context is active (context can be multiple levels deep)
    self.isInputListening = false
    -- stores event IDs of GUI button/key actions (no movement)
    self.actionEventIds = {}
    -- current frame's input target, all inputs of one frame go to this target
    self.frameInputTarget = nil
    -- flag for handling of current frame's input, avoids reacting to multiple events per frame for double bindings (e.g. ESC on PC)
    self.frameInputHandled = false

    self.changeScreenClosure = self:makeChangeScreenClosure()
    self.toggleCustomInputContextClosure =self:makeToggleCustomInputContextClosure()
    self.playSampleClosure = self:makePlaySampleClosure()

    g_adsSystem:clearGroupRegion(AdsSystem.OCCLUSION_GROUP.UI)
    g_adsSystem:addGroupRegion(AdsSystem.OCCLUSION_GROUP.UI, 0, 0, 1, 1)
    g_adsSystem:setGroupActive(AdsSystem.OCCLUSION_GROUP.UI, false)

    return self
end

















---
function Gui:loadPresets(xmlFile, rootKey)
    local presets = {}

    local i = 0
    while true do
        local key = string.format("%s.Preset(%d)", rootKey, i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key .. "#name")
        local value = getXMLString(xmlFile, key .. "#value")
        if name ~= nil and value ~= nil then
            if value:startsWith("$preset_") then
                local preset = string.gsub(value, "$preset_", "")
                if presets[preset] ~= nil then
                    value = presets[preset]
                else
                    Logging.devWarning("Preset '%s' is not defined in Preset!", preset)
                end
            end

            presets[name] = value
        end

        i = i + 1
    end

    return presets
end


---
function Gui:loadTraits(xmlFile, rootKey, presets)
    local i = 0
    while true do
        local trait = GuiProfile.new(self.profiles, self.traits)
        if not trait:loadFromXML(xmlFile, rootKey .. ".Trait(" .. i .. ")", presets, true) then
            break
        end

        self.traits[trait.name] = trait
        i = i + 1
    end
end


---
function Gui:loadProfileSet(xmlFile, rootKey, presets, categoryName)
    local i = 0
    while true do
        local profile = GuiProfile.new(self.profiles, self.traits)
        if not profile:loadFromXML(xmlFile, rootKey .. ".Profile(" .. i .. ")", presets, false) then
            break
        end

        profile.category = categoryName -- for debugging

        self.profiles[profile.name] = profile

        -- Load variants
        local j = 0
        while true do
            local k = rootKey .. ".Profile(" .. i .. ").Variant(" .. j .. ")"
            if not hasXMLProperty(xmlFile, k) then
                break
            end

            local variantName = getXMLString(xmlFile, k .. "#name")
            if variantName ~= nil then
                local variantProfile = GuiProfile.new(self.profiles, self.traits)
                if not variantProfile:loadFromXML(xmlFile, k, presets, false, true) then
                    break
                end

                if variantProfile.parent == nil then
                    variantProfile.parent = profile.name
                end

                variantProfile.category = categoryName
                variantProfile.name = variantName .. "_" .. profile.name

                self.profiles[variantProfile.name] = variantProfile
            end

            j = j + 1
        end

        i = i + 1
    end
end


---Load UI profile data from XML.
-- @param xmlFilename UI profiles definition XML file path, relative to application root.
function Gui:loadProfiles(xmlFilename)
    local xmlFile = loadXMLFile("Temp", xmlFilename)

    if xmlFile ~= nil and xmlFile ~= 0 then
        local presets = self:loadPresets(xmlFile, "GuiProfiles.Presets")

        self:loadTraits(xmlFile, "GuiProfiles.Traits", presets)
        self:loadProfileSet(xmlFile, "GuiProfiles", presets)

        local i = 0
        while true do
            local key = string.format("GuiProfiles.Category(%d)", i)
            if not hasXMLProperty(xmlFile, key) then
                break
            end

            local categoryName = getXMLString(xmlFile, key .. "#name")

            self:loadProfileSet(xmlFile, key, presets, categoryName)

            i = i + 1
        end

        delete(xmlFile)

        return true
    end

    Logging.error("Could not open guiProfile-config '%s'!", xmlFilename)

    return false
end


---Load a UI screen view's elements from an XML definition.
-- @param xmlFilename View definition XML file path, relative to application root.
-- @param name Screen name
-- @param controller FrameElement instance which serves as the controller for loaded elements
-- @param isFrame [optional, default=false] If true, will interpret the loaded view as a frame to be used in multiple places.
-- @return Root GuiElement instance of loaded view or nil if the definition XML file could not be loaded.
function Gui:loadGui(xmlFilename, name, controller, isFrame)
    local xmlFile = loadXMLFile("Temp", xmlFilename)

    local gui = nil
    if xmlFile ~= nil and xmlFile ~= 0 then
        FocusManager:setGui(name)

        gui = GuiElement.new(controller)
        gui.name = name
        gui.xmlFilename = xmlFilename
        controller.name = name
        controller.xmlFilename = xmlFilename

        gui:loadFromXML(xmlFile, "GUI")

        if isFrame then
            controller.name = gui.name
        end

        self:loadGuiRec(xmlFile, "GUI", gui, controller)

        if not isFrame then -- frames must only be scaled as part of screens, do not scale them on loading
            gui:applyScreenAlignment()
            gui:updateAbsolutePosition()
        end

        controller:addElement(gui)
        controller:exposeControlsAsFields(name)

        controller:onGuiSetupFinished()
        -- call onCreate of configuration root node --> targets onCreate on view
        gui:raiseCallback("onCreateCallback", gui, gui.onCreateArgs)

        if isFrame then
            self:addFrame(controller, gui)
        else
            self.guis[name] = gui
            self.nameScreenTypes[name] = controller:class() -- TEMP, until showGui is replaced
            -- store screen by its class for symbolic access
            self:addScreen(controller:class(), controller, gui)
        end

        delete(xmlFile)
    else
        Logging.error("Could not open gui-config '%s'!", xmlFilename)
    end

    return gui
end


---Recursively load and build a UI configuration.
-- @param xmlFile Opened GUI configuration XML file
-- @param xmlNodePath Current XML node path
-- @param parentGuiElement Current parent GuiElement
-- @param target Target of newly instantiated elements
function Gui:loadGuiRec(xmlFile, xmlNodePath, parentGuiElement, target)
    local i = 0
    while true do
        local currentXmlPath = xmlNodePath .. ".GuiElement(" .. i .. ")"
        local typeName = getXMLString(xmlFile, currentXmlPath .. "#type")
        if typeName == nil then
            break
        end

        -- instantiate element and load attribute values
        local newGuiElement
        local elementClass = Gui.CONFIGURATION_CLASS_MAPPING[typeName]
        if elementClass then -- instantiate mapped class
            newGuiElement = elementClass.new(target)
        else -- instantiate base GuiElement as fallback or empty panel
            newGuiElement = GuiElement.new(target)
        end
        newGuiElement.typeName = typeName

        newGuiElement:loadFromXML(xmlFile, currentXmlPath)
        parentGuiElement:addElement(newGuiElement)

        -- run any processing resolution functions for specific types:
        local processingFunction = Gui.ELEMENT_PROCESSING_FUNCTIONS[typeName]
        if processingFunction then
            newGuiElement = processingFunction(self, newGuiElement)
        end

        -- recurse on children
        self:loadGuiRec(xmlFile, currentXmlPath, newGuiElement, target)

        -- raise callback after all child nodes have been processed
        newGuiElement:raiseCallback("onCreateCallback", newGuiElement, newGuiElement.onCreateArgs)
        i = i + 1
    end
end


---Tries resolving a frame reference.
If no frame has been loaded with the name given by the reference, then the reference element itself is returned.
Otherwise, the registered frame is cloned and returned.
-- @param self Gui instance
-- @param frameRefElement FrameReferenceElement instance to resolve
-- @return Cloned FrameElement instance or frameRefElement if resolution failed.
function Gui:resolveFrameReference(frameRefElement)
    local refName = frameRefElement.referencedFrameName or ""
    local frame = self.frames[refName]

    if frame ~= nil then
        local frameName = frameRefElement.name or refName
        -- "frame" is the artificial root GuiElement instance holding the frame,
        -- its parent is the controller FrameElement instance which needs to be cloned
        local frameController = frame.parent
        -- clone the controller, including element IDs and suppressing the onCreate callback for all elements
        FocusManager:setGui(frameName) -- set focus data context
        local frameParent = frameRefElement.parent
        local controllerClone = frameController:clone(frameParent, true, true)
        controllerClone.name = frameName

        -- re-size and re-orient frame controller and its root to fit the new parent element (required for resolution stability)
        controllerClone.positionOrigin = frameParent.positionOrigin
        controllerClone.screenAlign = frameParent.screenAlign
        controllerClone:setSize(unpack(frameParent.size))
        local cloneRoot = controllerClone:getRootElement()
        cloneRoot.positionOrigin = frameParent.positionOrigin
        cloneRoot.screenAlign = frameParent.screenAlign
        cloneRoot:setSize(unpack(frameParent.size))

        controllerClone:setTarget(controllerClone, frameController, true)

        local frameId = frameRefElement.id
        controllerClone.id = frameId -- swap ID

        if frameRefElement.target then
            -- swap frame reference field value for clone frame controller
            frameRefElement.target[frameId] = controllerClone
        end

        -- add cloned frame elements to focus system, would not support navigation otherwise
        FocusManager:loadElementFromCustomValues(controllerClone, nil, nil, false, false)

        -- safely discard reference element
        frameRefElement:unlinkElement()
        frameRefElement:delete()

        return controllerClone
    else
        return frameRefElement
    end
end


---Get a UI profile by name.
function Gui:getProfile(profileName)
    if profileName ~= nil then
        local specialized = false

        local defaultProfileName = profileName
        for _, prefix in ipairs(Platform.guiPrefixes) do
            local customProfileName = prefix .. defaultProfileName
            if self.profiles[customProfileName] ~= nil then
                profileName = customProfileName
                specialized = true
            end
        end

        if not specialized and Platform.isConsole then
            local consoleProfileName = "console_" .. profileName
            if self.profiles[consoleProfileName] ~= nil then
                profileName = consoleProfileName
                specialized = true
            end
        end

        if not specialized and Platform.isMobile then
            local consoleProfileName = "mobile_" .. profileName
            if self.profiles[consoleProfileName] ~= nil then
                profileName = consoleProfileName
                -- specialized = true
            end
        end
    end

    if not profileName or not self.profiles[profileName] then
        -- only warn if profile name is wrong, undefined is fine
        if profileName and profileName ~= "" then
            Logging.warning("Could not retrieve GUI profile '%s'. Using base reference profile instead.", tostring(profileName))
        end

        profileName = Gui.GUI_PROFILE_BASE
    end

    return self.profiles[profileName]
end


---Determine if any menu or dialog is visible.
function Gui:getIsGuiVisible()
    return self.currentGui ~= nil or self:getIsDialogVisible()
end


---Determine if any dialog is visible.
function Gui:getIsDialogVisible()
    return #self.dialogs > 0
end


---Determine if an overlaid UI view with regular game display is visible, e.g. placement or landscaping.
function Gui:getIsOverlayGuiVisible()
    return self.currentGui == self.screens[ConstructionScreen]
end


---Display and return a screen identified by name.
-- @return Root GuiElement of screen or nil if the name did not match any known screen.
function Gui:showGui(guiName)
    -- TODO: replace all calls to this with Gui:changeScreen
    if guiName == nil then
        guiName = ""
    end

    return self:changeScreen(self.guis[self.currentGui], self.nameScreenTypes[guiName])
end


---Display a dialog identified by name.
-- @return Root GuiElement of dialog or nil if the name did not match any known dialog.
function Gui:showDialog(guiName, closeAllOthers)
    local gui = self.guis[guiName]
    if gui ~= nil then
        if closeAllOthers then
            local list = self.dialogs
            for _,v in ipairs(list) do
                if v ~= gui then
                    self:closeDialog(v)
                end
            end
        end

        local oldListener = self.currentListener
        if self.currentListener == gui then
            return gui
        end

        if self.currentListener ~= nil then
            self.focusElements[self.currentListener] = FocusManager:getFocusedElement()
        end

        if not self:getIsGuiVisible() then
            self:enterMenuContext()
        end

        -- set distinct dialog context which can be reverted on dialog closing if we are in menu already
        self:enterMenuContext(Gui.INPUT_CONTEXT_DIALOG .. "_" .. tostring(guiName))

        FocusManager:setGui(guiName)
        table.insert(self.dialogs, gui)
        gui:onOpen()
        self.currentListener = gui

        g_messageCenter:publish(MessageType.GUI_DIALOG_OPENED, guiName, oldListener ~= nil and oldListener ~= gui)

        gui.blurAreaActive = false
        if gui.target.getBlurArea ~= nil then
            local x, y, width, height = gui.target:getBlurArea()
            if x ~= nil then
                gui.blurAreaActive = true
                g_depthOfFieldManager:pushArea(x, y, width, height)
            end
        end
    end

    return gui
end


---Close a dialog identified by name.
function Gui:closeDialogByName(guiName)
    local gui = self.guis[guiName]
    if gui ~= nil then
        self:closeDialog(gui)
    end
end


---Close a dialog identified by its root GuiElement.
This is always called when a dialog is closed, usually by itself.
function Gui:closeDialog(gui)
    for k,v in ipairs(self.dialogs) do
        if v == gui then
            v:onClose()
            table.remove(self.dialogs, k)

            if gui.blurAreaActive then
                g_depthOfFieldManager:popArea()
                gui.blurAreaActive = false
            end

            if self.currentListener == gui then
                if #self.dialogs > 0 then
                    self.currentListener = self.dialogs[#self.dialogs]
                else
                    if self.currentGui == gui then
                        self.currentListener = nil
                        self.currentGui = nil
                    else
                        self.currentListener = self.currentGui
                    end
                end

                if self.currentListener ~= nil then
                    FocusManager:setGui(self.currentListener.name)
                    if self.focusElements[self.currentListener] ~= nil then
                        FocusManager:setFocus(self.focusElements[self.currentListener])
                        self.focusElements[self.currentListener] = nil
                    end
                end
            end

            -- revert dialog input context
            self.inputManager:revertContext(false)

            break
        end
    end

    if not self:getIsGuiVisible() then
        -- trigger close screen which dispatches required messages and adjusts input context:
        self:changeScreen(nil)
    end
end


---Close all open dialogs.
function Gui:closeAllDialogs()
    for _,v in ipairs(self.dialogs) do
        self:closeDialog(v)
    end
end


---Register menu input.
function Gui:registerMenuInput()
    self.actionEventIds = {}

    -- register the menu input event for all menu navigation actions on button up
    for _, actionName in ipairs(Gui.NAV_ACTIONS) do -- use ipairs to enforce action order
        local _, eventId = self.inputManager:registerActionEvent(actionName, self, self.onMenuInput, false, true, false, true)
        self.inputManager:setActionEventTextVisibility(eventId, false)

        if self.actionEventIds[actionName] == nil then
            self.actionEventIds[actionName] = {}
        end
        table.addElement(self.actionEventIds[actionName], eventId)


        if actionName == InputAction.MENU_PAGE_PREV or actionName == InputAction.MENU_PAGE_NEXT then
            -- react to movement input stops ("up" state), releases locks on focus manager input:
            _, eventId = self.inputManager:registerActionEvent(actionName, self, self.onReleaseInput, true, false, false, true)
            self.inputManager:setActionEventTextVisibility(eventId, false)
            table.addElement(self.actionEventIds[actionName], eventId)
        end
    end

    -- register input events for navigation movement actions for each input change
    for _, actionName in pairs(Gui.NAV_AXES) do
        -- react to any axis value changes:
        local _, eventId = self.inputManager:registerActionEvent(actionName, self, self.onMenuInput, false, true, true, true)
        self.inputManager:setActionEventTextVisibility(eventId, false)

        if self.actionEventIds[actionName] == nil then
            self.actionEventIds[actionName] = {}
        end
        table.addElement(self.actionEventIds[actionName], eventId)

        -- react to movement input stops ("up" state), releases locks on focus manager input:
        _, eventId = self.inputManager:registerActionEvent(actionName, self, self.onReleaseMovement, true, false, false, true)
        self.inputManager:setActionEventTextVisibility(eventId, false)
        table.addElement(self.actionEventIds[actionName], eventId)
    end

    self.isInputListening = true
end


---GUI mouse event hook.
This is used primarily for mouse location checks, as button inputs are handled by InputBinding.
function Gui:mouseEvent(posX, posY, isDown, isUp, button)
    local eventUsed = false

    if self.currentListener ~= nil then
        eventUsed = self.currentListener:mouseEvent(posX, posY, isDown, isUp, button)
    end

    if not eventUsed and self.currentListener ~= nil and self.currentListener.target ~= nil then
        if self.currentListener.target.mouseEvent ~= nil then
            self.currentListener.target:mouseEvent(posX, posY, isDown, isUp, button)
        end
    end
end


---GUI touch event hook.
This is used primarily for touch location checks, as button inputs are handled by InputBinding.
function Gui:touchEvent(posX, posY, isDown, isUp, touchId)
    local eventUsed = false

    if self.currentListener ~= nil and self.currentListener.touchEvent ~= nil  then
        eventUsed = self.currentListener:touchEvent(posX, posY, isDown, isUp, touchId)
    end

    if not eventUsed and self.currentListener ~= nil and self.currentListener.target ~= nil then
        if self.currentListener.target.touchEvent ~= nil then
            self.currentListener.target:touchEvent(posX, posY, isDown, isUp, touchId)
        end
    end
end


---GUI key event hook.
This is used for GuiElements which need to have direct access to raw key input, such as TextInputElement.
function Gui:keyEvent(unicode, sym, modifier, isDown)
    local eventUsed = false
    if self.currentListener ~= nil then
        eventUsed = self.currentListener:keyEvent(unicode, sym, modifier, isDown)
    end

    if self.currentListener ~= nil and self.currentListener.target ~= nil and not eventUsed then
        if self.currentListener.target.keyEvent ~= nil then
            self.currentListener.target:keyEvent(unicode, sym, modifier, isDown, eventUsed)
        end
    end
end


---Update the GUI.
Propagates update to all active UI elements.
function Gui:update(dt)
    for _,v in pairs(self.dialogs) do
        -- v:update(dt)
        if v.target ~= nil then
            v.target:update(dt)
        end
    end

    local currentGui = self.currentGui
    if currentGui ~= nil then
        if currentGui.target ~= nil and currentGui.target.preUpdate ~= nil then
            currentGui.target:preUpdate(dt)
        end

        if currentGui == self.currentGui then -- self.currentGui can change during update
            -- currentGui:update(dt)
            if currentGui == self.currentGui then -- self.currentGui can change during update
                if currentGui.target ~= nil and currentGui.target.update ~= nil then
                    currentGui.target:update(dt)
                end
            end
        end
    end

    -- reset input fields for next frame
    self.frameInputTarget = nil
    self.frameInputHandled = false
end


---Draw the GUI.
Propagates draw calls to all active UI elements.
function Gui:draw()
    if self.currentGui ~= nil then
        -- self.currentGui:draw()
        if self.currentGui.target ~= nil then
            if self.currentGui.target.draw ~= nil then
                self.currentGui.target:draw()
            end
        end
    end

    for _,v in pairs(self.dialogs) do
        -- v:draw()
        if v.target ~= nil then
            v.target:draw()
        end
    end

    if g_uiDebugEnabled then
        local item = FocusManager.currentFocusData.focusElement

        local function getName(e)
            if e == nil then
                return "none"
            else
                return e.id or e.profile or e.name
            end
        end

        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(0.5, 0.94, 0.02, "Focused element: " .. getName(item))
        if item ~= nil then
            renderText(0.5, 0.92, 0.02, "Top element: " .. getName(FocusManager:getNextFocusElement(item, FocusManager.TOP)))
            renderText(0.5, 0.90, 0.02, "Bottom element: " .. getName(FocusManager:getNextFocusElement(item, FocusManager.BOTTOM)))
            renderText(0.5, 0.88, 0.02, "Left element: " .. getName(FocusManager:getNextFocusElement(item, FocusManager.LEFT)))
            renderText(0.5, 0.86, 0.02, "Right element: " .. getName(FocusManager:getNextFocusElement(item, FocusManager.RIGHT)))

            local xPixel = 3 / g_screenWidth
            local yPixel = 3 / g_screenHeight

            drawFilledRect(item.absPosition[1] - xPixel, item.absPosition[2] - yPixel, item.absSize[1] + 2 * xPixel, yPixel, 1, 0.5, 0, 1)
            drawFilledRect(item.absPosition[1] - xPixel, item.absPosition[2] + item.absSize[2], item.absSize[1] + 2 * xPixel, yPixel, 1, 0.5, 0, 1)
            drawFilledRect(item.absPosition[1] - xPixel, item.absPosition[2], xPixel, item.absSize[2], 1, 0.5, 0, 1)
            drawFilledRect(item.absPosition[1] + item.absSize[1], item.absPosition[2], xPixel, item.absSize[2], 1, 0.5, 0, 1)
        end
        setTextAlignment(RenderText.ALIGN_LEFT)
    end
end


---Notify controls of an action input with a value.
-- @param action Action name as defined by loaded actions, see also scripts/input/InputAction.lua
-- @param value Action value [-1, 1]
-- @return True if any control has consumed the action event
function Gui:notifyControls(action, value)
    local eventUsed = false

    -- Ensure that only one component receives input per frame, otherwise we risk some unwanted input handling chains
    -- when GUI current listeners (or similar) change.
    if self.frameInputTarget == nil then
        self.frameInputTarget = self.currentListener
    end

    -- check with focus manager if it currently blocks this input
    local locked = FocusManager:isFocusInputLocked(action, value)

    if not locked then
        -- try notifying current listener element or its target (usually either of these is a ScreenElement)
        if not eventUsed and self.frameInputTarget ~= nil then
            eventUsed = self.frameInputTarget:inputEvent(action, value)
        end

        if not eventUsed and self.frameInputTarget ~= nil and self.frameInputTarget.target ~= nil then
            eventUsed = self.frameInputTarget.target:inputEvent(action, value)
        end

        -- send input to the currently focused element if it's active
        local focusedElement = FocusManager:getFocusedElement()
        if not eventUsed and focusedElement ~= nil and focusedElement:getIsActive() then
            eventUsed = focusedElement:inputEvent(action, value)
        end

        -- always notify the focus manager, but pass in event usage information
        if not eventUsed then
            eventUsed = FocusManager:inputEvent(action, value, eventUsed)
        end
    end

    -- lock down input for the current frame if we have reacted on the current input action
    self.frameInputHandled = eventUsed
end


---Event callback for menu input.
function Gui:onMenuInput(actionName, inputValue)
    if not self.frameInputHandled and self.isInputListening then
        self:notifyControls(actionName, inputValue)
    end
end


---Event callback for released movement menu input.
function Gui:onReleaseMovement(action)
    self:onReleaseInput(action)

    FocusManager:releaseMovementFocusInput(action)
end


---Event callback for released movement menu input.
function Gui:onReleaseInput(action)
    if not self.frameInputHandled and self.isInputListening then
        -- check with focus manager if it currently blocks this input
        local locked = FocusManager:isFocusInputLocked(action)

        if not locked then
            -- try notifying current listener element or its target (usually either of these is a ScreenElement)
            if self.frameInputTarget ~= nil then
                self.frameInputTarget:inputReleaseEvent(action)
            end

            if self.frameInputTarget ~= nil and self.frameInputTarget.target ~= nil then
                self.frameInputTarget.target:inputReleaseEvent(action)
            end

            -- send input to the currently focused element if it's active
            local focusedElement = FocusManager:getFocusedElement()
            if focusedElement ~= nil and focusedElement:getIsActive() then
                focusedElement:inputReleaseEvent(action)
            end
        end
    end
end


---Determine if a given GuiElement has input focus.
function Gui:hasElementInputFocus(element)
    return self.currentListener ~= nil and self.currentListener.target == element
end






---Get a screen controller instance by class for special cases.
-- @param table screenClass Class table of the requested screen
-- @return table ScreenElement descendant instance of the given class or nil if no such instance was registered
function Gui:getScreenInstanceByClass(screenClass)
    return self.screenControllers[screenClass]
end


---Change the currently displayed screen.
-- @param table source Source screen instance
-- @param table screenClass Class table of the requested screen to change to or nil to close the GUI
-- @param table returnScreenClass [optional] Class table of the screen which will be opened on a "back" action in the
new screen.
-- @return table Root GuiElement instance of target screen
function Gui:changeScreen(source, screenClass, returnScreenClass)
    local screenController = self.screenControllers[screenClass]
    if screenClass ~= nil and screenController == nil then
        Logging.devWarning("UI '%s' not found", ClassUtil.getClassName(screenClass))
        return nil
    end

    self:closeAllDialogs()

    local isMenuOpening = not self:getIsGuiVisible()
    local screenElement = self.screens[screenClass]

    if source ~= nil then
        source:onClose()
    end

    if source == nil and self.currentGui ~= nil then
        self.currentGui:onClose()
    end

    local screenName = screenElement and screenElement.name or ""
    self.currentGui = screenElement
    self.currentGuiName = screenName
    self.currentListener = screenElement

    if screenElement ~= nil and isMenuOpening then
        self.messageCenter:publish(MessageType.GUI_BEFORE_OPEN)
        self:enterMenuContext()
    end

    FocusManager:setGui(screenName)

    screenController = self.screenControllers[screenClass]
    if screenElement ~= nil and screenController ~= nil then
        screenController:setReturnScreenClass(returnScreenClass or screenController.returnScreenClass) -- it's fine if its nil, the value is being checked
        screenElement:onOpen()

        if isMenuOpening then
            self.messageCenter:publish(MessageType.GUI_AFTER_OPEN)
        end
    end

    if not self:getIsGuiVisible() then
        self.messageCenter:publish(MessageType.GUI_BEFORE_CLOSE)
        -- clear input context if GUI is now completely closed (including dialogs)
        self:leaveMenuContext()
        self.messageCenter:publish(MessageType.GUI_AFTER_CLOSE)
    end

    g_adsSystem:setGroupActive(AdsSystem.OCCLUSION_GROUP.UI, self.currentGui ~= nil)

    return screenElement -- required by some screens to transfer state to the next view
end


---Make a change screen callback function which encloses the Gui self reference.
This avoids passing the reference around as a parameter or global reference.
function Gui:makeChangeScreenClosure()
    return function(source, screenClass, returnScreenClass)
        self:changeScreen(source, screenClass, returnScreenClass)
    end
end


---Toggle a custom menu input context for one of the managed frames or screens.
function Gui:toggleCustomInputContext(isActive, contextName)
    if isActive then
        self:enterMenuContext(contextName)
    else
        self:leaveMenuContext()
    end
end


---Make a toggle custom input context function which encloses the Gui self reference.
function Gui:makeToggleCustomInputContextClosure()
    return function(isActive, contextName)
        self:toggleCustomInputContext(isActive, contextName)
    end
end


---Make a play sample function which encloses the Gui self reference.
function Gui:makePlaySampleClosure()
    return function(sampleName)
        self.soundPlayer:playSample(sampleName)
    end
end


---Assign the play sample closure to a GUI element which has the PlaySampleMixin included.
-- @param table guiElement GuiElement instance
-- @return table The GuiElement instance given in the guiElement parameter
function Gui:assignPlaySampleCallback(guiElement)
    if guiElement:hasIncluded(PlaySampleMixin) then
        guiElement:setPlaySampleCallback(self.playSampleClosure)
    end

    return guiElement
end


---Enter a new menu input context.
Menu views which require special input should provide a context name to not collide with the base menu input scheme.
-- @param string contextName [optional] Custom menu input context name
function Gui:enterMenuContext(contextName)
    self.inputManager:setContext(contextName or Gui.INPUT_CONTEXT_MENU, true, false)
    self:registerMenuInput()
    self.isInputListening = true
end


---Leave a menu input context.
This wraps the input context setting to check if the menu is actually active and the context should be reverted to
the state before entering the menu (or a custom menu input context within the menu).
function Gui:leaveMenuContext()
    if self.isInputListening then
        self.inputManager:revertContext(false)
        self.isInputListening = self:getIsGuiVisible() -- keep listening if still visible
    end
end


---Add the instance of a specific reusable GUI frame.
function Gui:addFrame(frameController, frameRootElement)
    -- TODO: switch to class keys like screens
    self.frames[frameController.name] = frameRootElement

    frameController:setChangeScreenCallback(self.changeScreenClosure)
    frameController:setInputContextCallback(self.toggleCustomInputContextClosure)
    frameController:setPlaySampleCallback(self.playSampleClosure)
end


---Add the instance of a specific GUI screen.
function Gui:addScreen(screenClass, screenInstance, screenRootElement)
    self.screens[screenClass] = screenRootElement
    self.screenControllers[screenClass] = screenInstance

    -- TODO: use the same pattern for dialog calling from screens
    screenInstance:setChangeScreenCallback(self.changeScreenClosure)
    screenInstance:setInputContextCallback(self.toggleCustomInputContextClosure)
    screenInstance:setPlaySampleCallback(self.playSampleClosure)
end


---Set the current mission reference for GUI screens.
function Gui:setCurrentMission(currentMission)
    for _, controller in pairs(self.screenControllers) do
        if controller.setCurrentMission ~= nil then
            controller:setCurrentMission(currentMission)
        end
    end
end


---Let the GUI (and its components) process map data when it's loaded.
-- @param int mapXmlFile Map configuration XML file handle, do not close, will be handled by caller.
function Gui:loadMapData(mapXmlFile, missionInfo, baseDirectory)
    if not Platform.isMobile then
        self.screenControllers[ShopConfigScreen]:loadMapData(mapXmlFile, missionInfo, baseDirectory)
    end

    if Platform.hasWardrobe then
        self.screenControllers[WardrobeScreen]:loadMapData(mapXmlFile, missionInfo, baseDirectory)
    end
end


---
function Gui:unloadMapData()
    self.screenControllers[ShopConfigScreen]:unloadMapData()

    if Platform.hasWardrobe then
        self.screenControllers[WardrobeScreen]:unloadMapData()
    end
end


---Set the network client reference for GUI screens.
function Gui:setClient(client)
    for _, controller in pairs(self.screenControllers) do
        if controller.setClient ~= nil then
            controller:setClient(client)
        end
    end
end


---Set the network client reference for GUI screens.
function Gui:setServer(server)
    for _, controller in pairs(self.screenControllers) do
        if controller.setServer ~= nil then
            controller:setServer(server)
        end
    end
end




















---
function Gui:showColorPickerDialog(args)
    local dialog = self:showDialog("ColorPickerDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setColors(args.colors, args.defaultColor, args.defaultColorMaterial)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showLicensePlateDialog(args)
    local dialog = self:showDialog("LicensePlateDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setLicensePlateData(args.licensePlateData)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showTextInputDialog(args)
    local dialog = self.guis["TextInputDialog"]
    if dialog ~= nil and args ~= nil then
        dialog.target:setText(args.text)
        dialog.target:setCallback(args.callback, args.target, args.defaultText, args.dialogPrompt, args.imePrompt, args.maxCharacters, args.args, false, args.disableFilter)
        dialog.target:setButtonTexts(args.confirmText, args.backText, args.activateInputText)

        self:showDialog("TextInputDialog")
    end
end


---
function Gui:showPasswordDialog(args)
    local dialog = self.guis["PasswordDialog"]
    if dialog ~= nil and args ~= nil then
        dialog.target:setText(args.text)
        dialog.target:setCallback(args.callback, args.target, args.defaultPassword, nil, nil, nil, args.args, true)
        dialog.target:setButtonTexts(args.startText, args.backText)

        self:showDialog("PasswordDialog")
    end
end


---
function Gui:showYesNoDialog(args)
    local dialog = self:showDialog("YesNoDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setText(args.text)
        dialog.target:setTitle(args.title)
        dialog.target:setDialogType(Utils.getNoNil(args.dialogType, DialogElement.TYPE_QUESTION))
        dialog.target:setCallback(args.callback, args.target, args.args)
        dialog.target:setButtonTexts(args.yesText, args.noText)
        dialog.target:setButtonSounds(args.yesSound, args.noSound)
    end
end


---
function Gui:showLeaseYesNoDialog(args)
    local dialog = self:showDialog("LeaseYesNoDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setText(args.text)
        dialog.target:setTitle(args.title)
        dialog.target:setPrices(args.costsBase, args.initialCosts, args.costsPerOperatingHour, args.costsPerDay)
        dialog.target:setDialogType(Utils.getNoNil(args.dialogType, DialogElement.TYPE_QUESTION))
        dialog.target:setCallback(args.callback, args.target, args.args)
        dialog.target:setButtonTexts(args.yesText, args.noText)
        dialog.target:setButtonSounds(args.yesSound, args.noSound)
    end
end


---
function Gui:showOptionDialog(args)
    local dialog = self:showDialog("OptionDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setText(args.text)
        dialog.target:setTitle(args.title)
        dialog.target:setOptions(args.options)
        dialog.target:setCallback(args.callback, args.target, args.args)
        dialog.target:setButtonTexts(args.okText)
    end
end


---
function Gui:showInfoDialog(args)
    local dialog = self:showDialog("InfoDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setDialogType(Utils.getNoNil(args.dialogType, DialogElement.TYPE_WARNING))
        dialog.target:setText(args.text)
        dialog.target:setCallback(args.callback, args.target, args.args)
        dialog.target:setButtonTexts(args.okText)
        dialog.target:setButtonAction(args.buttonAction)
    end
end


---
function Gui:showMessageDialog(args)
    if args ~= nil then
        if args.visible then
            local dialog = self.guis["MessageDialog"]
            dialog.target:setDialogType(Utils.getNoNil(args.dialogType, DialogElement.TYPE_LOADING))
            dialog.target:setIsCloseAllowed(Utils.getNoNil(args.isCloseAllowed, true))
            dialog.target:setText(args.text)
            dialog.target:setUpdateCallback(args.updateCallback, args.updateTarget, args.updateArgs)

            self:showDialog("MessageDialog")
        else
            self:closeDialogByName("MessageDialog")
        end
    end
end


---
function Gui:showConnectionFailedDialog(args)
    local dialog = self:showDialog("ConnectionFailedDialog", true)
    if dialog ~= nil and args ~= nil then
        dialog.target:setDialogType(Utils.getNoNil(args.dialogType, DialogElement.TYPE_WARNING))
        dialog.target:setText(args.text)
        dialog.target:setCallback(args.callback, args.target, args.args)
        dialog.target:setButtonTexts(args.okText)
    end
end


---
function Gui:showDenyAcceptDialog(args)
    local dialog = self:showDialog("DenyAcceptDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setCallback(args.callback, args.target)
        dialog.target:setConnection(args.connection, args.nickname, args.platformId, args.splitShapesWithinLimits)
    end
end


---
function Gui:showSiloDialog(args)
    local dialog = self:showDialog("SiloDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setTitle(args.title)
        dialog.target:setText(args.text)
        dialog.target:setFillLevels(args.fillLevels, args.hasInfiniteCapacity)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showRefillDialog(args)
    local dialog = self:showDialog("RefillDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setData(args.data, args.priceFactor)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showAnimalDialog(args)
    local dialog = self:showDialog("AnimalDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setTitle(args.title)
        dialog.target:setText(args.text)
        dialog.target:setHusbandries(args.husbandries)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showSellItemDialog(args)
    local dialog = self:showDialog("SellItemDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setItem(args.item, args.price, args.storeItem)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showEditFarmDialog(args)
    local dialog = self:showDialog("EditFarmDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setExistingFarm(args.farmId)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showPlaceableInfoDialog(args)
    local dialog = self:showDialog("PlaceableInfoDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setPlaceable(args.placeable)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showUnblockDialog(args)
    local dialog = self:showDialog("UnBanDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setUseLocalList(args.useLocal or false)
        dialog.target:setCallback(args.callback, args.target)
    end
end


---
function Gui:showSleepDialog(args)
    local dialog = self:showDialog("SleepDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setTitle(g_i18n:getText("ui_inGameSleep"))
        dialog.target:setText(args.text)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showTransferMoneyDialog(args)
    local dialog = self:showDialog("TransferMoneyDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setTargetFarm(args.farm)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showServerSettingsDialog(args)
    local dialog = self:showDialog("ServerSettingsDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


---
function Gui:showVoteDialog(args)
    local dialog = self:showDialog("VoteDialog")
    if dialog ~= nil and args ~= nil then
        dialog.target:setValue(args.value)
        dialog.target:setCallback(args.callback, args.target, args.args)
    end
end


















---Source in UI modules.
-- @param baseDir Base scripts directory
function Gui.initGuiLibrary(baseDir)
    source(baseDir .. "/base/GuiProfile.lua")
    source(baseDir .. "/base/GuiUtils.lua")
    source(baseDir .. "/base/GuiOverlay.lua")

    source(baseDir .. "/base/GuiDataSource.lua")

    source(baseDir .. "/base/GuiMixin.lua")
    source(baseDir .. "/base/IndexChangeSubjectMixin.lua")
    source(baseDir .. "/base/PlaySampleMixin.lua")

    source(baseDir .. "/base/Tween.lua")
    source(baseDir .. "/base/MultiValueTween.lua")
    source(baseDir .. "/base/TweenSequence.lua")

    source(baseDir .. "/elements/GuiElement.lua")
    source(baseDir .. "/elements/FrameElement.lua")
    source(baseDir .. "/elements/ScreenElement.lua")
    source(baseDir .. "/elements/DialogElement.lua")
    source(baseDir .. "/elements/BitmapElement.lua")
    source(baseDir .. "/elements/ClearElement.lua")
    source(baseDir .. "/elements/TextElement.lua")
    source(baseDir .. "/elements/ButtonElement.lua")
    source(baseDir .. "/elements/ToggleButtonElement.lua")
    source(baseDir .. "/elements/ColorPickButtonElement.lua") -- not used anywhere
    source(baseDir .. "/elements/VideoElement.lua")
    source(baseDir .. "/elements/SliderElement.lua")
    source(baseDir .. "/elements/TextInputElement.lua")
    source(baseDir .. "/elements/ListElement.lua")
    source(baseDir .. "/elements/MultiTextOptionElement.lua")
    source(baseDir .. "/elements/CheckedOptionElement.lua")
    source(baseDir .. "/elements/ListItemElement.lua")
    source(baseDir .. "/elements/AnimationElement.lua")
    source(baseDir .. "/elements/TimerElement.lua") -- not used anywhere
    source(baseDir .. "/elements/BoxLayoutElement.lua")
    source(baseDir .. "/elements/FlowLayoutElement.lua")
    source(baseDir .. "/elements/PagingElement.lua")
    source(baseDir .. "/elements/TableElement.lua")
    source(baseDir .. "/elements/TableHeaderElement.lua")
    source(baseDir .. "/elements/IngameMapElement.lua")
    source(baseDir .. "/elements/IndexStateElement.lua")
    source(baseDir .. "/elements/FrameReferenceElement.lua")
    source(baseDir .. "/elements/RenderElement.lua")
    source(baseDir .. "/elements/BreadcrumbsElement.lua")
    source(baseDir .. "/elements/ThreePartBitmapElement.lua")
    source(baseDir .. "/elements/PictureElement.lua")
    source(baseDir .. "/elements/ScrollingLayoutElement.lua")
    source(baseDir .. "/elements/MultiOptionElement.lua")
    source(baseDir .. "/elements/TextBackdropElement.lua")
    source(baseDir .. "/elements/InputGlyphElementUI.lua")
    source(baseDir .. "/elements/TerrainLayerElement.lua")
    source(baseDir .. "/elements/SmoothListElement.lua")
    source(baseDir .. "/elements/DynamicFadedBitmapElement.lua")
    source(baseDir .. "/elements/PlatformIconElement.lua")
    source(baseDir .. "/elements/OptionToggleElement.lua")

    -- Add new elements here and just above to make them available.
    local mapping = Gui.CONFIGURATION_CLASS_MAPPING
    mapping["button"] = ButtonElement
    mapping["toggleButton"] = ToggleButtonElement
    mapping["video"] = VideoElement
    mapping["slider"] = SliderElement
    mapping["text"] = TextElement
    mapping["textInput"] = TextInputElement
    mapping["bitmap"] = BitmapElement
    mapping["clear"] = ClearElement
    mapping["list"] = ListElement
    mapping["multiTextOption"] = MultiTextOptionElement
    mapping["checkedOption"] = CheckedOptionElement
    mapping["listItem"] = ListItemElement
    mapping["animation"] = AnimationElement
    mapping["timer"] = TimerElement
    mapping["boxLayout"] = BoxLayoutElement
    mapping["flowLayout"] = FlowLayoutElement
    mapping["paging"] = PagingElement
    mapping["table"] = TableElement
    mapping["tableHeader"] = TableHeaderElement
    mapping["ingameMap"] = IngameMapElement
    mapping["indexState"] = IndexStateElement
    mapping["frameReference"] = FrameReferenceElement
    mapping["render"] = RenderElement
    mapping["breadcrumbs"] = BreadcrumbsElement
    mapping["threePartBitmap"] = ThreePartBitmapElement
    mapping["picture"] = PictureElement
    mapping["scrollingLayout"] = ScrollingLayoutElement
    mapping["multiOption"] = MultiOptionElement
    mapping["optionToggle"] = OptionToggleElement
    mapping["textBackdrop"] = TextBackdropElement
    mapping["inputGlyph"] = InputGlyphElementUI
    mapping["colorPickButton"] = ColorPickButtonElement
    mapping["terrainLayer"] = TerrainLayerElement
    mapping["smoothList"] = SmoothListElement
    mapping["dynamicFadedBitmap"] = DynamicFadedBitmapElement
    mapping["platformIcon"] = PlatformIconElement

    -- Add element processing function mappings in the same format:
    local procFuncs = Gui.ELEMENT_PROCESSING_FUNCTIONS
    procFuncs["frameReference"] = Gui.resolveFrameReference
    procFuncs["button"] = Gui.assignPlaySampleCallback
    procFuncs["slider"] = Gui.assignPlaySampleCallback
    procFuncs["multiTextOption"] = Gui.assignPlaySampleCallback
    procFuncs["checkedOption"] = Gui.assignPlaySampleCallback
    procFuncs["smoothList"] = Gui.assignPlaySampleCallback
end
