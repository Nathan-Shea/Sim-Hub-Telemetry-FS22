---Specialization for placeables













---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PlaceableInfoTrigger.prerequisitesPresent(specializations)
    return true
end


---
function PlaceableInfoTrigger.registerEvents(placeableType)
    SpecializationUtil.registerEvent(placeableType, "onInfoTriggerEnter")
    SpecializationUtil.registerEvent(placeableType, "onInfoTriggerLeave")
end


---
function PlaceableInfoTrigger.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableInfoTrigger)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableInfoTrigger)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableInfoTrigger)
    SpecializationUtil.registerEventListener(placeableType, "onDraw", PlaceableInfoTrigger)
end


---
function PlaceableInfoTrigger.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "updateInfo", PlaceableInfoTrigger.updateInfo)
    SpecializationUtil.registerFunction(placeableType, "onInfoTriggerCallback", PlaceableInfoTrigger.onInfoTriggerCallback)
end


---
function PlaceableInfoTrigger.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("InfoTrigger")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".infoTrigger#triggerNode", "Info trigger", nil, false)
    schema:register(XMLValueType.BOOL, basePath .. ".infoTrigger#showAllPlayers", "Show info to all players", false, false)
    schema:setXMLSpecializationType()
end


---Called on loading
-- @param table savegame savegame
function PlaceableInfoTrigger:onLoad(savegame)
    local spec = self.spec_infoTrigger

    spec.info = {}
    spec.showInfo = false
    spec.showAllPlayers = self.xmlFile:getValue("placeable.infoTrigger#showAllPlayers", false)
    spec.infoTrigger = self.xmlFile:getValue("placeable.infoTrigger#triggerNode", nil, self.components, self.i3dMappings)
    if spec.infoTrigger ~= nil then
        if not CollisionFlag.getHasFlagSet(spec.infoTrigger, CollisionFlag.TRIGGER_PLAYER) then
            Logging.xmlWarning(self.xmlFile, "Info trigger collison mask is missing bit 'TRIGGER_PLAYER' (%d)", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER))
        end
    end

    spec.hudBox = g_currentMission.hud.infoDisplay:createBox(KeyValueInfoHUDBox)
end


---
function PlaceableInfoTrigger:onDelete()
    local spec = self.spec_infoTrigger

    if spec.infoTrigger ~= nil then
        removeTrigger(spec.infoTrigger)
        spec.infoTrigger = nil
    end

    spec.showInfo = false
    g_currentMission:removeDrawable(self)

    if spec.hudBox ~= nil then
        g_currentMission.hud.infoDisplay:destroyBox(spec.hudBox)
    end
end


---
function PlaceableInfoTrigger:onFinalizePlacement()
    local spec = self.spec_infoTrigger
    if spec.infoTrigger ~= nil then
        addTrigger(spec.infoTrigger, "onInfoTriggerCallback", self)
    end
end


---
function PlaceableInfoTrigger:onDraw()
    local spec = self.spec_infoTrigger
    if spec.showInfo then
        if spec.showAllPlayers or self:getOwnerFarmId() == g_currentMission:getFarmId() then
            -- Gather info
            self:updateInfo(spec.info)

            if #spec.info > 0 then
                local box = spec.hudBox
                box:clear()
                box:setTitle(self:getName())

                for i = 1, #spec.info do
                    local element = spec.info[i]

                    box:addLine(element.title, element.text, element.accentuate)

                    spec.info[i] = nil
                end

                box:showNextFrame()
            end
        end
    end
end


---
function PlaceableInfoTrigger:onInfoTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local spec = self.spec_infoTrigger
    if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
        if onEnter then
            spec.showInfo = true
            g_currentMission:addDrawable(self)
            SpecializationUtil.raiseEvent(self, "onInfoTriggerEnter", otherId)

        else
            spec.showInfo = false
            g_currentMission:removeDrawable(self)
            SpecializationUtil.raiseEvent(self, "onInfoTriggerLeave", otherId)
        end
    end
end


---
function PlaceableInfoTrigger:updateInfo(info)
end
