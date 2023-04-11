---Event for turned on state




local FillUnitUnloadEvent_mt = Class(FillUnitUnloadEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function FillUnitUnloadEvent.emptyNew()
    local self = Event.new(FillUnitUnloadEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function FillUnitUnloadEvent.new(object)
    local self = FillUnitUnloadEvent.emptyNew()
    self.object = object
    return self
end


---
function FillUnitUnloadEvent.newServerToClient()
    local self = FillUnitUnloadEvent.emptyNew()
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function FillUnitUnloadEvent:readStream(streamId, connection)
    if not connection:getIsServer() then
        self.object = NetworkUtil.readNodeObject(streamId)
    end
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function FillUnitUnloadEvent:writeStream(streamId, connection)
    if connection:getIsServer() then
        NetworkUtil.writeNodeObject(streamId, self.object)
    end
end


---Run action on receiving side
-- @param integer connection connection
function FillUnitUnloadEvent:run(connection)
    if not connection:getIsServer() then
        if self.object ~= nil and self.object:getIsSynchronized() then
            local success = self.object:unloadFillUnits(true)
            if not success then
                connection:sendEvent(FillUnitUnloadEvent.newServerToClient())
            end
        end
    else
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("fillUnit_unload_nospace"))
    end
end
