---Event for enter request





local VehicleEnterRequestEvent_mt = Class(VehicleEnterRequestEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function VehicleEnterRequestEvent.emptyNew()
    local self = Event.new(VehicleEnterRequestEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param table playerStyle info
-- @return table instance instance of event
function VehicleEnterRequestEvent.new(object, playerStyle, farmId)
    local self = VehicleEnterRequestEvent.emptyNew()
    self.object = object
    self.objectId = NetworkUtil.getObjectId(self.object)
    self.farmId = farmId
    self.playerStyle = playerStyle
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function VehicleEnterRequestEvent:readStream(streamId, connection)
    self.objectId = NetworkUtil.readNodeObjectId(streamId)
    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

    if self.playerStyle == nil then
        self.playerStyle = PlayerStyle.new()
    end
    self.playerStyle:readStream(streamId, connection)

    self.object = NetworkUtil.getObject(self.objectId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function VehicleEnterRequestEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObjectId(streamId, self.objectId)
    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.playerStyle:writeStream(streamId, connection)
end


---Run action on receiving side
-- @param integer connection connection
function VehicleEnterRequestEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        local enterableSpec = self.object.spec_enterable
        if enterableSpec ~= nil and enterableSpec.isControlled == false then
            self.object:setOwner(connection)
            self.object.controllerFarmId = self.farmId

            local userId = g_currentMission.userManager:getUserIdByConnection(connection)
            self.object.controllerUserId = userId
            g_server:broadcastEvent(VehicleEnterResponseEvent.new(self.objectId, false, self.playerStyle, self.farmId, userId), true, connection, self.object, false, nil, true)
            connection:sendEvent(VehicleEnterResponseEvent.new(self.objectId, true, self.playerStyle, self.farmId, userId))
        end
    end
end
