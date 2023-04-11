---HUD vehicle schema display.
--
--Displays a schematic view of the current vehicle configuration.









local VehicleSchemaDisplay_mt = Class(VehicleSchemaDisplay, HUDDisplayElement)






---Create a new instance of VehicleSchemaDisplay.
-- @param table modManager ModManager reference
function VehicleSchemaDisplay.new(modManager)
    local backgroundOverlay = VehicleSchemaDisplay.createBackground()
    local self = VehicleSchemaDisplay:superClass().new(backgroundOverlay, nil, VehicleSchemaDisplay_mt)

    self:createBackgroundBar()

    self.modManager = modManager

    self.vehicle = nil -- currently controlled vehicle
    self.isDocked = false -- If true, the schema display is docked to the input help display
    self.vehicleSchemaOverlays = {} -- schema name -> overlay

    self.iconSizeX, self.iconSizeY = 0, 0 -- schema overlay icon size
    self.maxSchemaWidth = 0 -- maximum width of vehicle configuration schema

    return self
end


---Delete this element.
Also deletes all loaded vehicle schema overlays.
function VehicleSchemaDisplay:delete()
    VehicleSchemaDisplay:superClass().delete(self)

    if self.overlayFront ~= nil then
        self.overlayFront:delete()
    end
    if self.overlayMiddle ~= nil then
        self.overlayMiddle:delete()
    end
    if self.overlayBack ~= nil then
        self.overlayBack:delete()
    end

    for k, v in pairs(self.vehicleSchemaOverlays) do
        v:delete()
        self.vehicleSchemaOverlays[k] = nil
    end
end


---Load vehicle schema overlays from global and mod definitions.
function VehicleSchemaDisplay:loadVehicleSchemaOverlays()
    local xmlFile = loadXMLFile("VehicleSchemaDisplayOverlays", VehicleSchemaDisplay.SCHEMA_OVERLAY_DEFINITIONS_PATH)
    self:loadVehicleSchemaOverlaysFromXML(xmlFile)
    delete(xmlFile)

    for _, modDesc in ipairs(self.modManager:getActiveMods()) do
        xmlFile = loadXMLFile("VehicleSchemaDisplay ModFile", modDesc.modFile)
        if xmlFile ~= 0 then
            self:loadVehicleSchemaOverlaysFromXML(xmlFile, modDesc.modFile)
            delete(xmlFile)
        end
    end

    self:storeScaledValues()
end


---Load and create vehicle schema overlays from XML definitions.
-- @param int xmlFile XML file handle of vehicle schema definitions
-- @param string modPath Path to the current mod description or nil for the base game
function VehicleSchemaDisplay:loadVehicleSchemaOverlaysFromXML(xmlFile, modPath)
    local rootPath = "vehicleSchemaOverlays"
    local baseDirectory = ""
    local prefix = ""
    if modPath then
        rootPath = "modDesc.vehicleSchemaOverlays"
        local modName, dir = Utils.getModNameAndBaseDirectory(modPath)
        baseDirectory = dir
        prefix = modName
    end

    local atlasPath = getXMLString(xmlFile, rootPath .. "#filename")
    local imageSize = GuiUtils.get2DArray(getXMLString(xmlFile, rootPath .. "#imageSize"), {1024, 1024})

    local i = 0
    while true do
        local baseName = string.format("%s.overlay(%d)", rootPath, i)
        if not hasXMLProperty(xmlFile, baseName) then
            break -- no more overlay definitions
        end

        local baseOverlayName = getXMLString(xmlFile, baseName .. "#name")
        local uvString = getXMLString(xmlFile, baseName .. "#uvs") or string.format("0px 0px %ipx %ipx", imageSize[1], imageSize[2])
        local uvs = GuiUtils.getUVs(uvString, imageSize)

        local sizeString = getXMLString(xmlFile, baseName .. "#size") or string.format("%ipx %ipx",
            VehicleSchemaDisplay.SIZE.ICON[1], VehicleSchemaDisplay.SIZE.ICON[1])
        local size = GuiUtils.getNormalizedValues(sizeString, {1, 1}) -- remove pixel units but do not change numbers

        if baseOverlayName then
            local overlayName = prefix .. baseOverlayName

            local atlasFileName = Utils.getFilename(atlasPath, baseDirectory)
            local schemaOverlay = Overlay.new(atlasFileName, 0, 0, size[1], size[2]) -- store pixel size to be scaled later
            schemaOverlay:setUVs(uvs)

            self.vehicleSchemaOverlays[overlayName] = schemaOverlay
        end

        i = i + 1
    end
end


---Set the currently controlled vehicle to display its schematic view.
-- @param table vehicle Vehicle reference
function VehicleSchemaDisplay:setVehicle(vehicle)
    self.vehicle = vehicle
end


---Animation method to set docked state at a delayed time by callback.
function VehicleSchemaDisplay:lateSetDocked(isDocked)
    self.isDocked = isDocked
end


---Set the schema's docking state.
This element's position is updated based on the docking state.
-- @param bool isDocked If true, the schema should be display docked to the HUD input help display. Otherwise, it will
take the input help's place in the top left corner.
function VehicleSchemaDisplay:setDocked(isDocked, animate)
    local targetX, targetY = VehicleSchemaDisplay.getBackgroundPosition(isDocked, self:getScale())
    if animate and self.animation:getFinished() then
        local startX, startY = self:getPosition()

        self:animateDocking(startX, startY, targetX, targetY, isDocked)
    else
        self.animation:stop()
        self.isDocked = isDocked
        self:setPosition(targetX, targetY)
    end
end






---Draw the vehicle schema display.
Only draws the schema if a controlled vehicle is set.
function VehicleSchemaDisplay:draw()
    if self.vehicle ~= nil then
        VehicleSchemaDisplay:superClass().draw(self)
        self:drawVehicleSchemaOverlays(self.vehicle)
    end
end


---Animate docking / undocking from input help display.
-- @param float startX Screen space starting X position of animation
-- @param float startY Screen space starting Y position of animation
-- @param float targetX Screen space target X position of animation
-- @param float targetY Screen space target Y position of animation
-- @param bool isDocking If true, moving to docking position. If false, moving to stand-alone position.
function VehicleSchemaDisplay:animateDocking(startX, startY, targetX, targetY, isDocking)
    local sequence = TweenSequence.new(self)
    local lateDockInstant = HUDDisplayElement.MOVE_ANIMATION_DURATION * 0.5
    if not isDocking then
        sequence:addInterval(HUDDisplayElement.MOVE_ANIMATION_DURATION) -- synchronize with input help element
        lateDockInstant = lateDockInstant + HUDDisplayElement.MOVE_ANIMATION_DURATION
    end

    sequence:addTween(MultiValueTween.new(self.setPosition, {startX, startY}, {targetX, targetY}, HUDDisplayElement.MOVE_ANIMATION_DURATION))
    -- set docked state in the middle of the animation:
    sequence:insertCallback(self.lateSetDocked, isDocking, lateDockInstant)

    sequence:start()
    self.animation = sequence
end


---Recursively get vehicle schema overlay parts for a vehicle configuration.
function VehicleSchemaDisplay:collectVehicleSchemaDisplayOverlays(overlays, depth, vehicle, rootVehicle, parentOverlay, x, y, rotation, invertingX)
    if vehicle.getAttachedImplements == nil then
        return
    end

    local attachedImplements = vehicle:getAttachedImplements()
    for _, implement in pairs(attachedImplements) do
        local object = implement.object
        if object ~= nil and object.schemaOverlay ~= nil then
            local selected = object:getIsSelected()
            local turnedOn = object:getUseTurnedOnSchema()
            local jointDesc = vehicle.schemaOverlay.attacherJoints[implement.jointDescIndex]

            if jointDesc ~= nil then
                local invertX = invertingX ~= jointDesc.invertX
                local overlay = self:getSchemaOverlayForState(object.schemaOverlay, true)

                local baseY = y + jointDesc.y * parentOverlay.height
                local baseX
                if invertX then
                    baseX = x + jointDesc.x * parentOverlay.width
                else
                    baseX = x - overlay.width + (1 - jointDesc.x) * parentOverlay.width
                end

                local rot = rotation + jointDesc.rotation

                local offsetX, offsetY
                if invertX then
                    offsetX = -object.schemaOverlay.offsetX * overlay.width
                else
                    offsetX = object.schemaOverlay.offsetX * overlay.width
                end

                offsetY = object.schemaOverlay.offsetY * overlay.height
                local rotatedX = offsetX * math.cos(rot) - offsetY * math.sin(rot)
                local rotatedY = offsetX * math.sin(rot) + offsetY * math.cos(rot)
                baseX = baseX - rotatedX
                baseY = baseY - rotatedY

                local isLowered = object.getIsLowered ~= nil and object:getIsLowered(true)
                if not isLowered then
                    local widthOffset, heightOffset = getNormalizedScreenValues(jointDesc.liftedOffsetX, jointDesc.liftedOffsetY)
                    baseX = baseX + widthOffset
                    baseY = baseY + heightOffset * 0.5
                end

                local additionalText = object:getAdditionalSchemaText()

                table.insert(overlays, {
                    overlay = overlay,
                    additionalText = additionalText,
                    x = baseX,
                    y = baseY,
                    rotation = rot,
                    invertX = not invertX,
                    invisibleBorderRight = object.schemaOverlay.invisibleBorderRight,
                    invisibleBorderLeft = object.schemaOverlay.invisibleBorderLeft,
                    selected = selected,
                    turnedOn = turnedOn
                })

                if depth <= VehicleSchemaDisplay.MAX_SCHEMA_COLLECTION_DEPTH then
                    self:collectVehicleSchemaDisplayOverlays(overlays, depth + 1, object, rootVehicle, overlay, baseX, baseY, rot, invertX)
                end
            end
        end
    end
end


---Get a vehicle configuration's schema overlays, including the root vehicle.
-- @return table Array of overlay descriptions: {overlay=overlay, x=0, y=0, rotation=0, invertX=false, invisibleBorderRight=vehicle.schemaOverlay.invisibleBorderRight, invisibleBorderLeft=vehicle.schemaOverlay.invisibleBorderLeft}
-- @return float Screen space height of root vehicle schema overlay
function VehicleSchemaDisplay:getVehicleSchemaOverlays(vehicle)
    local overlay = self:getSchemaOverlayForState(vehicle.schemaOverlay, false)
    local additionalText = vehicle:getAdditionalSchemaText()
    local overlays = {}

    table.insert(overlays, {
        overlay = overlay,
        additionalText = additionalText,
        x = 0,
        y = 0,
        rotation = 0,
        invertX = false,
        invisibleBorderRight = vehicle.schemaOverlay.invisibleBorderRight,
        invisibleBorderLeft = vehicle.schemaOverlay.invisibleBorderLeft,
        turnedOn = vehicle:getUseTurnedOnSchema(),
        selected = vehicle:getIsSelected()
    })

    self:collectVehicleSchemaDisplayOverlays(overlays, 1, vehicle, vehicle, overlay, 0, 0, 0, false)

    return overlays, overlay.height
end


---Get minimum and maximum screen space X positions of vehicle schema overlay descriptions.
The returned positions are relative to the position of the root vehicle schema overlay.
-- @param table overlayDescriptions Array of overlay descriptions, see VehicleSchemaDisplay:getVehicleSchemaOverlays()
-- @return float Minimum X position (left)
-- @return float Maximum X position (right)
function VehicleSchemaDisplay:getSchemaDelimiters(overlayDescriptions)
    local minX = math.huge
    local maxX = -math.huge
    for _, overlayDesc in pairs(overlayDescriptions) do
        local overlay = overlayDesc.overlay

        local cosRot = math.cos(overlayDesc.rotation)
        local sinRot = math.sin(overlayDesc.rotation)

        local offX = overlayDesc.invisibleBorderLeft * overlay.width
        local dx = overlay.width + (overlayDesc.invisibleBorderRight + overlayDesc.invisibleBorderLeft) * overlay.width

        local dy = overlay.height
        local x = overlayDesc.x + offX * cosRot
        local dx2 = dx * cosRot
        local dx3 = -dy * sinRot
        local dx4 = dx2 + dx3

        maxX = math.max(maxX, x, x + dx2, x + dx3, x + dx4)
        minX = math.min(minX, x, x + dx2, x + dx3, x + dx4)
    end

    return minX, maxX
end


---Draw vehicle schema icons for a given vehicle.
-- @param table vehicle Current vehicle
function VehicleSchemaDisplay:drawVehicleSchemaOverlays(vehicle)
    vehicle = vehicle.rootVehicle

    if vehicle.schemaOverlay ~= nil then
        local overlays, overlayHeight = self:getVehicleSchemaOverlays(vehicle)

        local x, y = self:getPosition()
        local baseX, baseY = x, y

        baseY = baseY + (self:getHeight() - overlayHeight) * 0.5 -- vertically center icon base in panel
        if self.isDocked then
            baseX = baseX + self:getWidth() -- right-align when docked to input help
        end

        local minX, maxX = self:getSchemaDelimiters(overlays)

        -- dynamically scale schemas if going over size limit:
        local scale = 1
        local sizeX = maxX - minX
        if sizeX > self.maxSchemaWidth then
            scale = self.maxSchemaWidth / sizeX
        end

        local barOffsetX = self:updateBarComponents(baseX, y, sizeX, self.overlay.height * self.uiScale, self.isDocked)
        self.overlayFront:render()
        self.overlayMiddle:render()
        self.overlayBack:render()

        local newPosX = baseX
        if self.isDocked then
            newPosX = newPosX - maxX * scale - barOffsetX
        else
            newPosX = newPosX - minX * scale + barOffsetX
        end

        for _, overlayDesc in pairs(overlays) do
            local overlay = overlayDesc.overlay
            local width, height = overlay.width, overlay.height

            overlay:setInvertX(overlayDesc.invertX)
            overlay:setPosition(newPosX + overlayDesc.x, baseY + overlayDesc.y)
            overlay:setRotation(overlayDesc.rotation, 0, 0)
            overlay:setDimension(width * scale, height * scale)

            local color = overlayDesc.turnedOn and VehicleSchemaDisplay.COLOR.TURNED_ON or VehicleSchemaDisplay.COLOR.DEFAULT
            overlay:setColor(color[1], color[2], color[3], overlayDesc.selected and 1 or 0.5)

            overlay:render()

            if overlayDesc.additionalText ~= nil then
                local posX = newPosX + overlayDesc.x + (width * scale) * 0.5
                local posY = baseY + overlayDesc.y + (height * scale * 0.85)
                setTextBold(false)
                setTextColor(1, 1, 1, 1)
                setTextAlignment(RenderText.ALIGN_CENTER)
                renderText(posX, posY, getCorrectTextSize(0.008), overlayDesc.additionalText)
                setTextAlignment(RenderText.ALIGN_LEFT)
                setTextColor(1, 1, 1, 1)
            end

            -- reset dimension
            overlay:setDimension(width, height)
        end
    end
end


---Get a schema overlay for a given vehicle's schema overlay data and current state.
-- @param table schemaOverlayData VehicleSchemaOverlayData instance of the current vehicle
-- @param bool isTurnedOn True if the vehicle is currently turned on, i.e. its function is active
-- @param bool isSelected True if the vehicle is currently selected for input
-- @param bool isImplement True if the vehicle is an implement (i.e. attached to a motorized vehicle), false if it's the root vehicle
-- @return table Schema Overlay instance
function VehicleSchemaDisplay:getSchemaOverlayForState(schemaOverlayData, isImplement, iconOverride)
    local schemaName

    schemaName = schemaOverlayData.schemaName

    -- Backwards compatibility
    if schemaName == "DEFAULT_IMPLEMENT" then
        schemaName = "IMPLEMENT"
    elseif schemaName == "DEFAULT_VEHICLE" then
        schemaName = "VEHICLE"
    end

    if not schemaName or schemaName == "" or self.vehicleSchemaOverlays[schemaName] == nil then
        schemaName = isImplement and VehicleSchemaOverlayData.SCHEMA_OVERLAY.IMPLEMENT or VehicleSchemaOverlayData.SCHEMA_OVERLAY.VEHICLE
    end

    return self.vehicleSchemaOverlays[schemaName]
end






---Set this element's UI scale.
-- @param float uiScale UI scale factor
function VehicleSchemaDisplay:setScale(uiScale)
    VehicleSchemaDisplay:superClass().setScale(self, uiScale, uiScale)

    local posX, posY = VehicleSchemaDisplay.getBackgroundPosition(self.isDocked, uiScale)
    self:setPosition(posX, posY)

    self:storeScaledValues()

    self.uiScale = uiScale
end


---Store scaled positioning, size and offset values.
function VehicleSchemaDisplay:storeScaledValues()
    self.iconSizeX, self.iconSizeY = self:scalePixelToScreenVector(VehicleSchemaDisplay.SIZE.ICON)
    self.maxSchemaWidth = self:scalePixelToScreenWidth(VehicleSchemaDisplay.MAX_SCHEMA_WIDTH)

    for _, overlay in pairs(self.vehicleSchemaOverlays) do
        overlay:resetDimensions()

        local pixelSize = {overlay.defaultWidth, overlay.defaultHeight}
        local width, height = self:scalePixelToScreenVector(pixelSize)
        overlay:setDimension(width, height)
    end
end


---Get the vehicle schema's base background position.
-- @param bool isDocked If true, the vehicle schema is docked to the input help display
-- @param float uiScale Current UI scale
function VehicleSchemaDisplay.getBackgroundPosition(isDocked, uiScale)
    local width, height = getNormalizedScreenValues(unpack(VehicleSchemaDisplay.SIZE.SELF))

    local posX, posY = g_safeFrameOffsetX, 1 - g_safeFrameOffsetY - height * uiScale -- top left anchored
    if isDocked then
        local offX, offY = getNormalizedScreenValues(unpack(VehicleSchemaDisplay.POSITION.SELF_DOCKED))
        posX = posX + (offX - width) * uiScale
        posY = posY + offY * uiScale
    end

    return posX, posY
end






---Create an empty background positioning overlay.
function VehicleSchemaDisplay.createBackground()
    local width, height = getNormalizedScreenValues(unpack(VehicleSchemaDisplay.SIZE.SELF))
    local posX, posY = VehicleSchemaDisplay.getBackgroundPosition(false, 1.0)

    return Overlay.new(nil, posX, posY, width, height)
end
