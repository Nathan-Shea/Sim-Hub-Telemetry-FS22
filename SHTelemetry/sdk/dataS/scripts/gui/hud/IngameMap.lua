---In-game map display element.
--
--This class is used to display the game map both in the HUD as well as in the in-game menu.









local IngameMap_mt = Class(IngameMap, HUDElement)























---Create a new instance of IngameMap.
-- @param string hudAtlasPath Path to the HUD atlas texture
-- @param table inputDisplayManager InputDisplayManager reference
function IngameMap.new(hud, hudAtlasPath, inputDisplayManager, customMt)
    local self = IngameMap:superClass().new(nil, nil, customMt or IngameMap_mt)
    self.overlay = self:createBackground(hudAtlasPath)

    self.hud = hud
    self.hudAtlasPath = hudAtlasPath
    self.inputDisplayManager = inputDisplayManager

    self.uiScale = 1.0

    self.isVisible = true

    self.layouts = {
        IngameMapLayoutNone.new(),
        IngameMapLayoutCircle.new(),
        IngameMapLayoutSquare.new(),
        IngameMapLayoutSquareLarge.new(),
        IngameMapLayoutFullscreen.new(),
    }
    self.fullScreenLayout = self.layouts[#self.layouts]
    self.state = 1
    self.layout = self.layouts[self.state]

    self.mapOverlay = Overlay.new(nil, 0, 0, 1, 1) -- null-object, obsoletes defensive checks
    self.mapElement = HUDElement.new(self.mapOverlay) -- null-object

    self:createComponents(hudAtlasPath)
    for _, layout in ipairs(self.layouts) do
        layout:createComponents(self, hudAtlasPath)
    end

    self.filter = {}
    self.filter[MapHotspot.CATEGORY_FIELD] = true
    self.filter[MapHotspot.CATEGORY_ANIMAL] = true
    self.filter[MapHotspot.CATEGORY_MISSION] = true
    self.filter[MapHotspot.CATEGORY_TOUR] = true
    self.filter[MapHotspot.CATEGORY_STEERABLE] = true
    self.filter[MapHotspot.CATEGORY_COMBINE] = true
    self.filter[MapHotspot.CATEGORY_TRAILER] = true
    self.filter[MapHotspot.CATEGORY_TOOL] = true
    self.filter[MapHotspot.CATEGORY_UNLOADING] = true
    self.filter[MapHotspot.CATEGORY_LOADING] = true
    self.filter[MapHotspot.CATEGORY_PRODUCTION] = true
    self.filter[MapHotspot.CATEGORY_SHOP] = true
    self.filter[MapHotspot.CATEGORY_OTHER] = true
    self.filter[MapHotspot.CATEGORY_AI] = true
    self.filter[MapHotspot.CATEGORY_PLAYER] = true

    self:setWorldSize(2048, 2048)

    self.hotspots = {}
    self.selectedHotspot = nil

    self.mapExtensionOffsetX = 0.25
    self.mapExtensionOffsetZ = 0.25
    self.mapExtensionScaleFactor = 0.5

    self.allowToggle = true

    self.topDownCamera = nil -- set by screen views which use a top down view, used for map position update

    return self
end


---Delete this element and all of its components.
function IngameMap:delete()
    IngameMap:superClass().delete(self)

    g_inputBinding:removeActionEventsByTarget(self)

    self.mapElement:delete()
    self:setSelectedHotspot(nil)

    for _, layout in ipairs(self.layouts) do
        layout:delete()
    end

    if self.mapOverlayGenerator ~= nil then
        self.mapOverlayGenerator:delete()
    end
end






---Set full-screen mode (for map overview) without affecting the mini-map state.
function IngameMap:setFullscreen(isFullscreen)
    if self.isFullscreen == isFullscreen then
        return
    end

    self.layout:deactivate()

    self.isFullscreen = isFullscreen
    if isFullscreen then
        self.layout = self.fullScreenLayout
    else
        self.layout = self.layouts[self.state]
    end

    self.layout:activate()

    g_inputBinding:setActionEventTextVisibility(self.toggleMapSizeEventId, self.layout:getShowsToggleActionText())
end


---
function IngameMap:toggleSize(state, force)
--#profile     g_remoteProfiler.ZoneBeginN("IngameMap_toggleSize")
    self.layout:deactivate()

    if state ~= nil then
        self.state = math.max(math.min(state, #self.layouts - 1), 1)
    else
        self.state = (self.state % (#self.layouts - 1)) + 1
    end

    self.layout = self.layouts[self.state]
    self.layout:activate()

    g_inputBinding:setActionEventTextVisibility(self.toggleMapSizeEventId, self.layout:getShowsToggleActionText())
    g_gameSettings:setValue("ingameMapState", self.state)
--#profile     g_remoteProfiler.ZoneEnd()
end

























---
function IngameMap:resetSettings()
    if self.overlay == nil then
        return -- instance has been deleted, ignore reset
    end

    -- self:setScale(self.uiScale) -- resets scaled values

    -- local baseX, baseY = self:getBackgroundPosition()
    -- self:setPosition(baseX + self.mapOffsetX, baseY + self.mapOffsetY)
    -- self:setSize(self.mapWidth, self.mapHeight)

    self:setSelectedHotspot(nil)
end


















---
function IngameMap:setAllowToggle(isAllowed)
    self.allowToggle = isAllowed
end

















---
function IngameMap:loadMap(filename, worldSizeX, worldSizeZ, fieldColor, grassFieldColor)
    self.mapElement:delete() -- will also delete the wrapped Overlay

    self:setWorldSize(worldSizeX, worldSizeZ)

    self.mapOverlay = Overlay.new(filename, 0, 0, 1, 1)

    self.mapElement = HUDElement.new(self.mapOverlay)
    self:addChild(self.mapElement)

    self:setScale(self.uiScale)

    self.mapOverlayGenerator = MapOverlayGenerator.new(g_i18n, g_fruitTypeManager, g_fillTypeManager, g_farmlandManager, g_farmManager, g_currentMission.weedSystem)
    self.mapOverlayGenerator:setColorBlindMode(false)
    self.mapOverlayGenerator:setFieldColor(fieldColor, grassFieldColor)
    self.fieldRefreshTimer = IngameMap.FIELD_REFRESH_INTERVAL
end











---
function IngameMap:setWorldSize(worldSizeX, worldSizeZ)
    self.worldSizeX = worldSizeX
    self.worldSizeZ = worldSizeZ
    self.worldCenterOffsetX = self.worldSizeX * 0.5
    self.worldCenterOffsetZ = self.worldSizeZ * 0.5

    for _, layout in ipairs(self.layouts) do
        layout:setWorldSize(worldSizeX, worldSizeZ)
    end
end










---
function IngameMap:determinePlayerPosition(player)
    return player:getPositionData()
end


---
function IngameMap:determineVehiclePosition(enterable)
    local posX, posY, posZ = getTranslation(enterable.rootNode)

    -- set arrow rotation
    local dx, _, dz = localDirectionToWorld(enterable.rootNode, 0, 0, 1)
    local yRot
    if enterable.spec_drivable ~= nil and enterable.spec_drivable.reverserDirection == -1 then
        yRot = MathUtil.getYRotationFromDirection(dx, dz)
    else
        yRot = MathUtil.getYRotationFromDirection(dx, dz) + math.pi
    end

    local vel = enterable:getLastSpeed()

    return posX, posY, posZ, yRot, vel
end






---
function IngameMap:addMapHotspot(mapHotspot)
    table.insert(self.hotspots, mapHotspot)

    -- On mobile we sort spatially
    if GS_IS_MOBILE_VERSION then
        local mapSize = 1024
        table.sort(self.hotspots, function(v1, v2)
            -- Split into 6 horizontal bands (must be an even number because map changes position based on the 0.5 split)
            -- Sort horizontall within bands and vertically per band

            local band1 = math.ceil((v1.worldZ + mapSize * 0.5) / (mapSize * 0.16666))
            local band2 = math.ceil((v2.worldZ + mapSize * 0.5) / (mapSize * 0.16666))

            if band1 == band2 then
                return v1.worldX < v2.worldX or (v1.worldX == v2.worldX and v1.worldZ < v2.worldZ)
            else
                return (band1 - band2) < 0
            end
        end)
    else
        table.sort(self.hotspots, function(v1, v2) return v1:getCategory() > v2:getCategory() end)
    end
    self.hotspotsSorted = nil

    return mapHotspot
end


---
function IngameMap:removeMapHotspot(mapHotspot)
    if mapHotspot ~= nil then
        for i=1, #self.hotspots do
            if self.hotspots[i] == mapHotspot then
                table.remove(self.hotspots, i)
                break
            end
        end

        if self.selectedHotspot == mapHotspot then
            self:setSelectedHotspot(nil)
        end

        if g_currentMission ~= nil then
            if g_currentMission.currentMapTargetHotspot == mapHotspot then
                g_currentMission:setMapTargetHotspot(nil)
            end
        end

        self.hotspotsSorted = nil
    end
end


---
function IngameMap:setSelectedHotspot(hotspot)
    if self.selectedHotspot ~= nil then
        self.selectedHotspot:setSelected(false)
    end
    self.selectedHotspot = hotspot
    if self.selectedHotspot ~= nil then
        self.selectedHotspot:setSelected(true)
    end
end




































































---
function IngameMap:updateHotspotFilters()
    for category, _ in pairs(self.filter) do
        if category == MapHotspot.CATEGORY_SHOP then
            -- Make shop and 'other' equal to each other
            self:setHotspotFilter(category, not Utils.isBitSet(g_gameSettings:getValue("ingameMapFilter"), MapHotspot.CATEGORY_OTHER))
        else
            self:setHotspotFilter(category, not Utils.isBitSet(g_gameSettings:getValue("ingameMapFilter"), category))
        end
    end
end


---
function IngameMap:setHotspotFilter(category, isActive)
    if category ~= nil then
        if isActive then
            g_gameSettings:setValue("ingameMapFilter", Utils.clearBit(g_gameSettings:getValue("ingameMapFilter"), category))
        else
            g_gameSettings:setValue("ingameMapFilter", Utils.setBit(g_gameSettings:getValue("ingameMapFilter"), category))
        end
        self.filter[category] = isActive
        self.hotspotsSorted = nil
    end
end





















































































































































---Draw the player's current coordinates as text.
function IngameMap:drawPlayersCoordinates()
    local renderString = string.format("%.1f°, %d, %d", math.deg(-self.playerRotation % (2*math.pi)), self.normalizedPlayerPosX * self.worldSizeX, self.normalizedPlayerPosZ * self.worldSizeZ)

    self.layout:drawCoordinates(renderString)
end


---Draw current latency to server as text.
function IngameMap:drawLatencyToServer()
    if g_client ~= nil and g_client.currentLatency ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.missionDynamicInfo.isClient then
        local color
        if g_client.currentLatency <= 50 then
            color = IngameMap.COLOR.LATENCY_GOOD
        elseif g_client.currentLatency < 100 then
            color = IngameMap.COLOR.LATENCY_MEDIUM
        else
            color = IngameMap.COLOR.LATENCY_BAD
        end

        self.layout:drawLatency(string.format("%dms", math.max(g_client.currentLatency, 10)), color)
    end
end








































---Draw a single hotspot on the map.
function IngameMap:drawHotspot(hotspot, smallVersion)
    if hotspot == nil then
        return
    end

    local worldX, worldZ = hotspot:getWorldPosition()
    local rotation = hotspot:getWorldRotation()

    local objectX = (worldX + self.worldCenterOffsetX) / self.worldSizeX * self.mapExtensionScaleFactor + self.mapExtensionOffsetX
    local objectZ = (worldZ + self.worldCenterOffsetZ) / self.worldSizeZ * self.mapExtensionScaleFactor + self.mapExtensionOffsetZ

    local zoom = self.layout:getIconZoom()
    hotspot:setScale(self.uiScale * zoom)

    local x, y, yRot, visible = self.layout:getMapObjectPosition(objectX, objectZ, hotspot:getWidth(), hotspot:getHeight(), rotation, hotspot:getIsPersistent())
    if visible then
        hotspot:setLastRenderInfo(x, y, yRot, self.layout)
--         drawFilledRect(x, y, hotspot:getWidth(), hotspot:getHeight(), 1, 0, 0, 0.2)
        hotspot:render(x, y, yRot, smallVersion)
    end
end






---Set this element's scale.
-- @param float uiScale Current UI scale applied to both width and height of elements
function IngameMap:setScale(uiScale)
    IngameMap:superClass().setScale(self, uiScale, uiScale)
    self.uiScale = uiScale

    self:storeScaledValues(uiScale)
end


---Store scaled positioning, size and offset values.
function IngameMap:storeScaledValues(uiScale)
    for _, layout in ipairs(self.layouts) do
        layout:storeScaledValues(self, uiScale)
    end
end






---Get the base position of the entire element.
function IngameMap:getBackgroundPosition()
    return g_safeFrameOffsetX, g_safeFrameOffsetY
end


---Create the empty background overlay.
function IngameMap:createBackground(hudAtlasPath)
    local width, height = getNormalizedScreenValues(unpack(IngameMap.SIZE.SELF))
    local posX, posY = self:getBackgroundPosition()

    local overlay = Overlay.new(hudAtlasPath, posX, posY, width, height)
    overlay:setUVs(GuiUtils.getUVs(IngameMap.UV.BACKGROUND_ROUND))
    overlay:setColor(0,0,0,0.75)

    return overlay
end


---Create required display components.
-- @param string hudAtlasPath Path to the HUD texture atlas
function IngameMap:createComponents(hudAtlasPath)
    local baseX, baseY = self:getPosition()
    local width, height = self:getWidth(), self:getHeight()

    self:createToggleMapSizeGlyph(hudAtlasPath, baseX, baseY, width, height)
end


---Create the input glyph for map size toggling.
function IngameMap:createToggleMapSizeGlyph(hudAtlasPath, baseX, baseY, baseWidth, baseHeight)
    local width, height = getNormalizedScreenValues(unpack(IngameMap.SIZE.INPUT_ICON))
    local offX, offY = getNormalizedScreenValues(unpack(IngameMap.POSITION.INPUT_ICON))

    local element = InputGlyphElement.new(self.inputDisplayManager, width, height)
    local posX, posY = baseX + offX, baseY + offY

    element:setPosition(posX, posY)
    element:setKeyboardGlyphColor(IngameMap.COLOR.INPUT_ICON)
    element:setAction(InputAction.TOGGLE_MAP_SIZE)

    self.toggleMapSizeGlyph = element
    self:addChild(element)
end
