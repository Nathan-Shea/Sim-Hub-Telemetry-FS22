---In-game map element.
--Controls input on the map in the in-game menu with objectives, vehicles, etc. The actual map rendering is deferred to
--the map component of the current mission. The map reference and terrain size must be set during mission
--initialization via the setIngameMap() and setTerrainSize() methods.


















local IngameMapElement_mt = Class(IngameMapElement, GuiElement)










---
function IngameMapElement.new(target, custom_mt)
    local self = GuiElement.new(target, custom_mt or IngameMapElement_mt)

    self.ingameMap = nil

    -- cursor
    self.cursorId = nil

    self.inputMode = GS_INPUT_HELP_MODE_GAMEPAD

    -- map attributes
    self.terrainSize = 0
    self.mapAlpha = 1
    self.zoomMin = 1
    self.zoomMax = 5
    self.zoomDefault = 2

    self.mapCenterX = 0.5
    self.mapCenterY = 0.5

    self.mapZoom = self.zoomDefault

    -- horizontal cursor input since last frame
    self.accumHorizontalInput = 0
    -- vertical cursor input since last frame
    self.accumVerticalInput = 0
    -- zoom input since last frame
    self.accumZoomInput = 0
    -- mouse input flag to override potential double binding on cursor movement
    self.useMouse = false
    -- reset flag for mouse input flag to avoid catching input in the current frame
    self.resetMouseNextFrame = false
    -- screen space rectangle definitions {x, y, w, h} where the cursor/mouse should not go and react to input
    self.cursorDeadzones = {}

    self.minDragDistanceX = IngameMapElement.DRAG_START_DISTANCE / g_screenWidth
    self.minDragDistanceY = IngameMapElement.DRAG_START_DISTANCE / g_screenHeight
    self.hasDragged = false -- drag state flag to avoid triggering a click event on a dragging mouse up

    self.minimalHotspotSize = getNormalizedScreenValues(9, 1)

    self.isHotspotSelectionActive = true
    self.isCursorAvailable = true

    return self
end


---
function IngameMapElement:delete()
    GuiOverlay.deleteOverlay(self.overlay)
    self.ingameMap = nil

    IngameMapElement:superClass().delete(self)
end


---
function IngameMapElement:loadFromXML(xmlFile, key)
    IngameMapElement:superClass().loadFromXML(self, xmlFile, key)

    self.cursorId = getXMLString(xmlFile, key.."#cursorId")
    self.mapAlpha = getXMLFloat(xmlFile, key .. "#mapAlpha") or self.mapAlpha

    self:addCallback(xmlFile, key.."#onDrawPreIngameMap", "onDrawPreIngameMapCallback")
    self:addCallback(xmlFile, key.."#onDrawPostIngameMap", "onDrawPostIngameMapCallback")
    self:addCallback(xmlFile, key.."#onDrawPostIngameMapHotspots", "onDrawPostIngameMapHotspotsCallback")
    self:addCallback(xmlFile, key.."#onClickHotspot", "onClickHotspotCallback")
    self:addCallback(xmlFile, key.."#onClickMap", "onClickMapCallback")
end


---
function IngameMapElement:loadProfile(profile, applyProfile)
    IngameMapElement:superClass().loadProfile(self, profile, applyProfile)

    self.mapAlpha = profile:getNumber("mapAlpha", self.mapAlpha)
end


---
function IngameMapElement:copyAttributes(src)
    IngameMapElement:superClass().copyAttributes(self, src)

    self.mapZoom = src.mapZoom
    self.mapAlpha = src.mapAlpha
    self.cursorId = src.cursorId
    self.onDrawPreIngameMapCallback = src.onDrawPreIngameMapCallback
    self.onDrawPostIngameMapCallback = src.onDrawPostIngameMapCallback
    self.onDrawPostIngameMapHotspotsCallback = src.onDrawPostIngameMapHotspotsCallback
    self.onClickHotspotCallback = src.onClickHotspotCallback
    self.onClickMapCallback = src.onClickMapCallback
end


---
function IngameMapElement:onGuiSetupFinished()
    IngameMapElement:superClass().onGuiSetupFinished(self)

    if self.cursorId ~= nil then
        if self.target[self.cursorId] ~= nil then
            self.cursorElement = self.target[self.cursorId]
        else
            print("Warning: CursorId '"..self.cursorId.."' not found for '"..self.target.name.."'!")
        end
    end
end






---Add a dead zone wherein the map will not react to cursor inputs.
Used this to designate areas where other controls should receive cursor input which would otherwise be used up by
the map (e.g. in full-screen mode in the map overview screen in-game). The deadzones will also restrict cursor
movement.
function IngameMapElement:addCursorDeadzone(screenX, screenY, width, height)
    table.insert(self.cursorDeadzones, {screenX, screenY, width, height})
end


---Clear cursor dead zones.
function IngameMapElement:clearCursorDeadzones()
    self.cursorDeadzones = {}
end


---Check if a cursor position is within one of the stored deadzones.
function IngameMapElement:isCursorInDeadzones(cursorScreenX, cursorScreenY)
    for _, zone in pairs(self.cursorDeadzones) do
        if GuiUtils.checkOverlayOverlap(cursorScreenX, cursorScreenY, zone[1], zone[2], zone[3], zone[4]) then
            return true
        end
    end

    return false
end


---Custom mouse event handling for the in-game map.
Directly handles zoom, click and drag events on the map. See input events and IngameMapElement:checkAndResetMouse()
for the state checking code required to bypass player mouse input bindings.
function IngameMapElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    if self:getIsActive() then
        eventUsed = IngameMapElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)

        if not GS_IS_CONSOLE_VERSION and (isDown or isUp or posX ~= self.lastMousePosX or posY ~= self.lastMousePosY) then
            self.useMouse = true

            if self.cursorElement then
                self.cursorElement:setVisible(false)
            end
            self.isCursorActive = false
        end

        -- On mobile we have touch input. Touch does not give us a position until there is a touch.
        -- This means on the first touch-begin, the lastMousePos is wrong and has a big offset.
        -- We set it when the touch begins so it becomes a drag action
        if GS_IS_MOBILE_VERSION and self.useMouse then
            if isDown then
                self.lastMousePosY = posY
            end
        end

        if not eventUsed then
            if isDown and button == Input.MOUSE_BUTTON_LEFT and not self:isCursorInDeadzones(posX, posY) then
                eventUsed = true
                if not self.mouseDown then
                    self.mouseDown = true
                end
            end
        end

        if self.mouseDown and self.lastMousePosX ~= nil then
            local distX = self.lastMousePosX - posX
            local distY = posY - self.lastMousePosY

            if self.isFixedHorizontal then
                distX = 0
            end

            if math.abs(distX) > self.minDragDistanceX or math.abs(distY) > self.minDragDistanceY then
                local factorX = -distX
                local factorY = distY

                self:moveCenter(factorX, factorY)

                self.hasDragged = true
            end
        end

        if isUp and button == Input.MOUSE_BUTTON_LEFT then
            if not eventUsed and self.mouseDown and not self.hasDragged then
                local localX, localY = self:getLocalPosition(posX, posY)

                -- save state locally to avoid issues if activating/deactivating selection in the onClickMap callback
                local isHotspotSelectionActive = self.isHotspotSelectionActive

                self:onClickMap(localX, localY)

                if isHotspotSelectionActive then
                    -- Trigger hot spot selection after map clicking because it's the more specific event
                    self:selectHotspotAt(posX, posY)
                end

                eventUsed = true
            end

            self.mouseDown = false
            self.hasDragged = false
        end

        self.lastMousePosX = posX
        self.lastMousePosY = posY
    end

    return eventUsed
end


---Move center of the map
function IngameMapElement:moveCenter(x, y)
    local width, height = self.ingameMap.fullScreenLayout:getMapSize()

    local centerX = self.cursorElement.absPosition[1] + self.cursorElement.absSize[1] * 0.5
    local centerY = self.cursorElement.absPosition[2] + self.cursorElement.absSize[2] * 0.5

    self.mapCenterX = MathUtil.clamp(self.mapCenterX + x, width * -0.25 + centerX, width * 0.25 + centerX)
    self.mapCenterY = MathUtil.clamp(self.mapCenterY + y, height * -0.25 + centerY, height * 0.25 + centerY)

    self.ingameMap.fullScreenLayout:setMapCenter(self.mapCenterX, self.mapCenterY)
end












---
function IngameMapElement:zoom(direction)
    -- No zooming for mobile
    if GS_IS_MOBILE_VERSION then
        return
    end

    -- Find the location pointed at by the cursor so we can zoom towards it
    local targetX, targetZ = self:localToWorldPos(self:getLocalPointerTarget())

    local width, height = self.ingameMap.fullScreenLayout:getMapSize()

    -- Zoom by a set factor
    local oldZoom = self.mapZoom
    local speed = IngameMapElement.ZOOM_SPEED_FACTOR * direction * width -- multiply by size to mimic a constant scroll
    self.mapZoom = MathUtil.clamp(self.mapZoom + speed, self.zoomMin, self.zoomMax)

    self.ingameMap.fullScreenLayout:setMapZoom(self.mapZoom)

    -- Size depends on zoom, center bounds depend on size. So clamp the center
    self:moveCenter(0, 0)

    -- -- Do not change focus position if we did not change zoom
    if oldZoom ~= self.mapZoom then
        -- Find the location the mouseis pointing at now
        local newTargetX, newTargetZ = self:localToWorldPos(self:getLocalPointerTarget())

        -- Above location is wrong. We want it to point at the same location as before, so find the different for moving
        local diffX, diffZ = newTargetX - targetX, newTargetZ - targetZ

        -- The diff is in world coordinates. Transform it to screenspace.
        local dx, dy = diffX / self.terrainSize * 0.5 * width, -diffZ / self.terrainSize * 0.5 * height

        self:moveCenter(dx, dy)
    end
end





















---
function IngameMapElement:update(dt)
    IngameMapElement:superClass().update(self, dt)

    self.inputMode = g_inputBinding:getLastInputMode()

    if not g_gui:getIsDialogVisible() then
        if not self.alreadyClosed then
            local zoomFactor = MathUtil.clamp(self.accumZoomInput, -1, 1)

            if zoomFactor ~= 0 then
                self:zoom(zoomFactor * -0.015 * dt)
            end

            if self.cursorElement ~= nil then
                self.isCursorActive = self.inputMode == GS_INPUT_HELP_MODE_GAMEPAD and not GS_IS_MOBILE_VERSION
                self.cursorElement:setVisible(self.isCursorAvailable and self.isCursorActive)
                self:updateCursor(self.accumHorizontalInput, -self.accumVerticalInput, dt)
                self.useMouse = false
            end

            self:updateMap()
        end
    end

    self:resetFrameInputState()
end


---Update our element to match the zoom level and map center
function IngameMapElement:updateMap()
    -- Update the ingame map. The ingame map draws the map background and hotspots
    -- self.ingameMap:setPosition(self.absPosition[1], self.absPosition[2])
    -- self.ingameMap:setSize(self.size[1], self.size[2])
    -- self.ingameMap.iconZoom = 0.3 + (self.zoomMax - self.zoomMin) * self.mapZoom
    -- self.ingameMap:setZoomScale(self.ingameMap.iconZoom)

    -- self.ingameMap:updatePlayerPosition()
end


---
function IngameMapElement:resetFrameInputState()
    self.accumZoomInput = 0
    self.accumHorizontalInput = 0
    self.accumVerticalInput = 0
    if self.resetMouseNextFrame then
        self.useMouse = false
        self.resetMouseNextFrame = false
    end
end


---
function IngameMapElement:draw(clipX1, clipY1, clipX2, clipY2)
    self:raiseCallback("onDrawPreIngameMapCallback", self, self.ingameMap)
    self.ingameMap:drawMapOnly()
    self:raiseCallback("onDrawPostIngameMapCallback", self, self.ingameMap)

    self.ingameMap:drawHotspotsOnly()

    self:raiseCallback("onDrawPostIngameMapHotspotsCallback", self, self.ingameMap)
end


---
function IngameMapElement:onOpen()
    IngameMapElement:superClass().onOpen(self)

    if self.cursorElement ~= nil then
        self.cursorElement:setVisible(false)
    end
    self.isCursorActive = false

    if self.largestSize == nil then
        self.largestSize = self.size
    end

    self.ingameMap:setFullscreen(true)

    self:zoom(0)
end


---
function IngameMapElement:onClose()
    IngameMapElement:superClass().onClose(self)

    self:removeActionEvents()

    self.ingameMap:setFullscreen(false)
end


---
function IngameMapElement:reset()
    IngameMapElement:superClass().reset(self)

    self.mapCenterX = 0.5
    self.mapCenterY = 0.5
    self.mapZoom = self.zoomDefault

    -- self.ingameMap:resetSettings()
end



---
function IngameMapElement:updateCursor(deltaX, deltaY, dt)
    if self.cursorElement ~= nil then
        local speed = IngameMapElement.CURSOR_SPEED_FACTOR

        local diffX = deltaX * speed * dt / g_screenAspectRatio
        local diffY = deltaY * speed * dt

        self:moveCenter(-diffX, -diffY)
    end
end


---
function IngameMapElement:selectHotspotAt(posX, posY)
    if self.isHotspotSelectionActive then
        if self.ingameMap.hotspotsSorted ~= nil then
            if not self:selectHotspotFrom(self.ingameMap.hotspotsSorted[true], posX, posY) then
                self:selectHotspotFrom(self.ingameMap.hotspotsSorted[false], posX, posY)
            end

            return
        end

        self:selectHotspotFrom(self.ingameMap.hotspots, posX, posY)
    end
end


---
function IngameMapElement:selectHotspotFrom(hotspots, posX, posY)
    for i=#hotspots, 1, -1 do
        local hotspot = hotspots[i]

        if self.ingameMap.filter[hotspot:getCategory()] and hotspot:getIsVisible() and hotspot:getCanBeAccessed() then
            if hotspot:hasMouseOverlap(posX, posY) then
                self:raiseCallback("onClickHotspotCallback", self, hotspot)

                return true
            end
        end
    end

    return false
end


---
function IngameMapElement:getLocalPosition(posX, posY)
    local width, height = self.ingameMap.fullScreenLayout:getMapSize()
    local offX, offY = self.ingameMap.fullScreenLayout:getMapPosition()

    -- offset with map poisition, then conver to 0-1 and adjust for minimap being doubled in size
    -- from actual map.
    local x = ((posX - offX) / width - 0.25) * 2
    local y = ((posY - offY) / height - 0.25) * 2

    return x, y
end


---
function IngameMapElement:getLocalPointerTarget()
    if self.useMouse then
        return self:getLocalPosition(self.lastMousePosX, self.lastMousePosY)
    elseif self.cursorElement then
        local posX = self.cursorElement.absPosition[1] + self.cursorElement.size[1] * 0.5
        local posY = self.cursorElement.absPosition[2] + self.cursorElement.size[2] * 0.5

        return self:getLocalPosition(posX, posY)
    end

    return 0, 0
end


---
function IngameMapElement:onClickMap(localPosX, localPosY)
    local worldPosX, worldPosZ = self:localToWorldPos(localPosX, localPosY)

    self:raiseCallback("onClickMapCallback", self, worldPosX, worldPosZ)
end


---
function IngameMapElement:localToWorldPos(localPosX, localPosY)
    local worldPosX = localPosX * self.terrainSize
    local worldPosZ = -localPosY * self.terrainSize

    -- move world positions to range -1024 to 1024 on a 2k map
    worldPosX = worldPosX - self.terrainSize * 0.5
    worldPosZ = worldPosZ + self.terrainSize * 0.5

    return worldPosX, worldPosZ
end













---
function IngameMapElement:setMapFocusToHotspot(hotspot)
    -- if hotspot ~= nil then
    --     local objectX = (hotspot.worldX + self.ingameMap.worldCenterOffsetX) / self.ingameMap.worldSizeX
    --     local objectZ = (hotspot.worldZ + self.ingameMap.worldCenterOffsetZ) / self.ingameMap.worldSizeZ

    --     -- This function is only used to cycle for visible hotspots. So we only need to check the 'visible' does not overlap deadzones
    --     if self:isCursorInDeadzones(objectX, objectZ) then
    --         self.ingameMapCenterX = MathUtil.clamp(objectX, 0 + self.ingameMap.mapVisWidth * 0.5, 1 - self.ingameMap.mapVisWidth * 0.5)
    --         self.ingameMapCenterY = MathUtil.clamp(objectZ, 0 + self.ingameMap.mapVisHeight * 0.5, 1 - self.ingameMap.mapVisHeight * 0.5)
    --     end

    --     if self.isFixedHorizontal then
    --         if objectZ < 0.5 then
    --             self:moveCenter(0, -1)
    --         else
    --             self:moveCenter(0, 1)
    --         end
    --     end
    -- end
end


---
function IngameMapElement:isPointVisible(x, z)
end


---Set the IngameMap reference to use for display.
function IngameMapElement:setIngameMap(ingameMap)
    self.ingameMap = ingameMap
end


---Set the current map's terrain size for map display.
function IngameMapElement:setTerrainSize(terrainSize)
    self.terrainSize = terrainSize
end









---Register non-GUI input action events.
function IngameMapElement:registerActionEvents()
    g_inputBinding:registerActionEvent(InputAction.AXIS_MAP_SCROLL_LEFT_RIGHT, self, self.onHorizontalCursorInput, false, false, true, true)
    g_inputBinding:registerActionEvent(InputAction.AXIS_MAP_SCROLL_UP_DOWN, self, self.onVerticalCursorInput, false, false, true, true)
    g_inputBinding:registerActionEvent(InputAction.INGAMEMAP_ACCEPT, self, self.onAccept, false, true, false, true)
    g_inputBinding:registerActionEvent(InputAction.AXIS_MAP_ZOOM_OUT, self, self.onZoomInput, false, false, true, true, -1) -- -1 == zoom out
    g_inputBinding:registerActionEvent(InputAction.AXIS_MAP_ZOOM_IN, self, self.onZoomInput, false, false, true, true, 1) -- 1 == zoom in
end


---Remove non-GUI input action events.
function IngameMapElement:removeActionEvents()
    g_inputBinding:removeActionEventsByTarget(self)
end


---Event function for horizontal cursor input bound to InputAction.AXIS_LOOK_LEFTRIGHT_VEHICLE.
function IngameMapElement:onHorizontalCursorInput(_, inputValue)
    if not self:checkAndResetMouse() and not self.isFixedHorizontal then
        self.accumHorizontalInput = self.accumHorizontalInput + inputValue
    end
end


---Event function for vertical cursor input bound to InputAction.AXIS_LOOK_UPDOWN_VEHICLE.
function IngameMapElement:onVerticalCursorInput(_, inputValue)
    if not self:checkAndResetMouse() then
        self.accumVerticalInput = self.accumVerticalInput + inputValue
    end
end


---Event function for gamepad cursor accept input bound to InputAction.INGAMEMAP_ACCEPT.
function IngameMapElement:onAccept()
    if self.cursorElement then
        local cursorElement = self.cursorElement
        local posX, posY = cursorElement.absPosition[1] + cursorElement.size[1]*0.5, cursorElement.absPosition[2] + cursorElement.size[2]*0.5
        local localX, localY = self:getLocalPointerTarget()

        -- save state locally to avoid issues if activating/deactivating selection in the onClickMap callback
        local isHotspotSelectionActive = self.isHotspotSelectionActive

        self:onClickMap(localX, localY)

        if isHotspotSelectionActive then
            -- trigger hot spot selection after map clicking because it's the more specific event
            self:selectHotspotAt(posX, posY)
        end
    end
end


---Event function for map zoom input bound to InputAction.AXIS_ACCELERATE_VEHICLE and InputAction.AXIS_BRAKE_VEHICLE.
-- @param inputValue Zoom input value
-- @param direction Zoom input sign value, 1 for zoom in, -1 for zoom out
function IngameMapElement:onZoomInput(_, inputValue, direction)
    if not self:hasMouseOverlapWithTabHeader() or not self.useMouse then
        self.accumZoomInput = self.accumZoomInput - direction*inputValue
    end
end


---Check if mouse input was active before a bound input was triggered and queue a reset of the mouse state for the next
frame.
Mouse input continuously sets the mouse input flag (self.useMouse) but does not receive any events when the mouse
is inert. Therefore we need to set and reset the state each frame to make sure we can seamlessly switch between mouse
and gamepad input on the map element while at the same time preventing any player bindings from interfering with the
custom mouse input logic of this class.
function IngameMapElement:checkAndResetMouse()
    local useMouse = self.useMouse
    if useMouse then
        self.resetMouseNextFrame = true
    end

    return useMouse
end
