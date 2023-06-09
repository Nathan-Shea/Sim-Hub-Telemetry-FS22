---Specialization for placeables













---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PlaceableTriggerMarkers.prerequisitesPresent(specializations)
    return true
end


---
function PlaceableTriggerMarkers.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableTriggerMarkers)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableTriggerMarkers)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableTriggerMarkers)
    SpecializationUtil.registerEventListener(placeableType, "onOwnerChanged", PlaceableTriggerMarkers)
end


---
function PlaceableTriggerMarkers.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "onPlayerFarmChanged", PlaceableTriggerMarkers.onPlayerFarmChanged)
    SpecializationUtil.registerFunction(placeableType, "onMarkerFileLoaded", PlaceableTriggerMarkers.onMarkerFileLoaded)
    SpecializationUtil.registerFunction(placeableType, "getTriggerMarkerPosition", PlaceableTriggerMarkers.getTriggerMarkerPosition)
    SpecializationUtil.registerFunction(placeableType, "setShowMarkers", PlaceableTriggerMarkers.setShowMarkers)
end


---
function PlaceableTriggerMarkers.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("TriggerMarkers")
    schema:register(XMLValueType.NODE_INDEX,    basePath .. ".triggerMarkers.triggerMarker(?)#node", "Trigger marker node")
    schema:register(XMLValueType.STRING,        basePath .. ".triggerMarkers.triggerMarker(?)#filename", "Trigger marker config file")
    schema:register(XMLValueType.STRING,        basePath .. ".triggerMarkers.triggerMarker(?)#id", "Trigger marker config file identifier")
    schema:register(XMLValueType.BOOL,          basePath .. ".triggerMarkers.triggerMarker(?)#adjustToGround", "Trigger marker adjusted to ground")
    schema:register(XMLValueType.FLOAT,         basePath .. ".triggerMarkers.triggerMarker(?)#groundOffset", "Height of the trigger marker above the ground if adjustToGround is enabled", 0.03)
    schema:register(XMLValueType.BOOL,          basePath .. ".triggerMarkers.triggerMarker(?)#showAllPlayers", "Show marker for all players even if they do not have access to the placeable", false)
    schema:setXMLSpecializationType()
end


---Called on loading
-- @param table savegame savegame
function PlaceableTriggerMarkers:onLoad(savegame)
    local spec = self.spec_triggerMarkers
    local xmlFile = self.xmlFile

    spec.sharedLoadRequestIds = {}

    spec.triggerMarkers = {}
    xmlFile:iterate("placeable.triggerMarkers.triggerMarker", function(_, key)
        local node = xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
        if node ~= nil then
            local adjustToGround = xmlFile:getValue(key .. "#adjustToGround", false)
            local groundOffset = xmlFile:getValue(key .. "#groundOffset")

            if groundOffset ~= nil and not adjustToGround then
                Logging.xmlWarning(xmlFile, "'groundOffset=%.2f' given but 'adjustToGround' is false for '%s'", groundOffset, key)
            end
            groundOffset = groundOffset or 0.03  -- 3cm as default to prevent clipping of flat markers with terrain

            --#debug if not getEffectiveVisibility(getParent(node)) then
            --#debug     Logging.xmlWarning(xmlFile, "Parent of triggerMarker link node '%s' (%s) is not visible", getName(node), key .. "#node")
            --#debug end

            local xmlFilename = self.xmlFile:getValue(key .. "#filename")
            local i3dFilename
            if xmlFilename ~= nil then
                local id = self.xmlFile:getValue(key .. "#id")
                if id == nil then
                    Logging.xmlWarning(xmlFile, "Missing marker id for '%s'", key)
                    return
                end

                id = string.upper(id)

                xmlFilename = Utils.getFilename(xmlFilename, self.baseDirectory)
                local markerXMLFile = XMLFile.load("triggerNode", xmlFilename, nil)
                if markerXMLFile == nil then
                    Logging.xmlWarning(xmlFile, "Could not load marker config file '%s'", xmlFilename)
                    return
                end

                i3dFilename = markerXMLFile:getString("markerIcons.filename")
                if i3dFilename == nil then
                    Logging.xmlWarning(xmlFile, "Missing marker i3d file in '%s'", markerXMLFile)
                    return
                end

                local loadingTask = self:createLoadingTask()
                i3dFilename = Utils.getFilename(i3dFilename, self.baseDirectory)
                local args = {}
                args.markerXMLFile = markerXMLFile
                args.node = node
                args.markerId = id
                args.loadingTask = loadingTask

                local sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(i3dFilename, false, false, self.onMarkerFileLoaded, self, args)
                table.insert(spec.sharedLoadRequestIds, sharedLoadRequestId)
            end

            local showAllPlayers = self.xmlFile:getValue(key .. "#showAllPlayers", false)

            table.insert(spec.triggerMarkers, {node=node, i3dFilename=i3dFilename, adjustToGround=adjustToGround, groundOffset=groundOffset, showAllPlayers=showAllPlayers})
        else
            Logging.xmlWarning(xmlFile, "Missing trigger marker node for '%s'", key)
        end
    end)
end


---
function PlaceableTriggerMarkers:onMarkerFileLoaded(i3dNode, failedReason, args)
    local markerXMLFile = args.markerXMLFile
    local node = args.node
    local markerId = args.markerId
    local loadingTask = args.loadingTask

    if i3dNode ~= 0 then
        local found = false
        markerXMLFile:iterate("markerIcons.variations.variation", function(_, key)
            local variationId = markerXMLFile:getString(key .. "#id")
            if variationId ~= nil then
                variationId = string.upper(variationId)
                if variationId == markerId then
                    local markerNode = I3DUtil.indexToObject(i3dNode, markerXMLFile:getString(key .. "#node"))
                    if markerNode ~= nil then
                        link(node, markerNode)
                        found = true
                        return false
                    else
                        Logging.xmlWarning(markerXMLFile, "Could not load marker node for marker id '%s'", markerId)
                    end
                end
            end
            return
        end)
        if not found then
            Logging.xmlWarning(markerXMLFile, "Could not find marker id '%s'", markerId)
        end

        delete(i3dNode)
    end

    markerXMLFile:delete()

    self:finishLoadingTask(loadingTask)
end


---
function PlaceableTriggerMarkers:onDelete()
    local spec = self.spec_triggerMarkers
    if spec.sharedLoadRequestIds ~= nil then
        for _, sharedLoadRequestId in ipairs(spec.sharedLoadRequestIds) do
            g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
        end
        spec.sharedLoadRequestIds = nil
    end

    if spec.triggerMarkers ~= nil then
        for _, marker in ipairs(spec.triggerMarkers) do
            g_currentMission:removeTriggerMarker(marker.node)
        end
    end

    g_messageCenter:unsubscribe(MessageType.PLAYER_FARM_CHANGED, self)
    g_messageCenter:unsubscribe(MessageType.PLAYER_CREATED, self)
end


---
function PlaceableTriggerMarkers:onFinalizePlacement()
    local spec = self.spec_triggerMarkers
    for _, marker in ipairs(spec.triggerMarkers) do
        if marker.adjustToGround and g_currentMission.terrainRootNode ~= nil then
            local x, _, z = getWorldTranslation(marker.node)
            local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + marker.groundOffset
            setWorldTranslation(marker.node, x, y, z)
        end
    end

    self:setShowMarkers(g_currentMission.accessHandler:canPlayerAccess(self))

    -- Get notified when the player visibility state changes
    g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, self.onPlayerFarmChanged, self)
    g_messageCenter:subscribe(MessageType.PLAYER_CREATED, self.onPlayerFarmChanged, self)
end
