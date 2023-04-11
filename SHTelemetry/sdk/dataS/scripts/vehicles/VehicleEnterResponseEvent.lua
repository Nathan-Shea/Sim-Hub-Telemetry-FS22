---Event for enter response





local VehicleEnterResponseEvent_mt = Class(VehicleEnterResponseEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function VehicleEnterResponseEvent.emptyNew()
    local self = Event.new(VehicleEnterResponseEvent_mt)
    return self
end


---Create new instance of event
-- @param table id id
-- @param boolean isOwner is owner
-- @param table playerStyle 
-- @return table instance instance of event
function VehicleEnterResponseEvent.new(id, isOwner, playerStyle, farmId, userId)
    local self = VehicleEnterResponseEvent.emptyNew()

    self.id = id
    self.isOwner = isOwner
    self.playerStyle = playerStyle
    self.farmId = farmId
    self.userId = userId

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function VehicleEnterResponseEvent:readStream(streamId, connection)
    self.id = NetworkUtil.readNodeObjectId(streamId)
    self.isOwner = streamReadBool(streamId)

    if self.playerStyle == nil then
        self.playerStyle = PlayerStyle.new()
    end
    self.playerStyle:readStream(streamId, connection)

    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self.userId = streamReadInt32(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function VehicleEnterResponseEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObjectId(streamId, self.id)
    streamWriteBool(streamId, self.isOwner)

    self.playerStyle:writeStream(streamId, connection)

    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    streamWriteInt32(streamId, self.userId)
end


---Run action on receiving side
-- @param integer connection connection
function VehicleEnterResponseEvent:run(connection)
    local object = NetworkUtil.getObject(self.id)

    if object ~= nil and object:getIsSynchronized() then
        if self.isOwner then
            g_currentMission:onEnterVehicle(object, self.playerStyle, self.farmId, self.userId)
        else
            local enterableSpec = object.spec_enterable
            if enterableSpec ~= nil then
                if not enterableSpec.isEntered then
                    object:enterVehicle(false, self.playerStyle, self.farmId, self.userId)
                end
            end
        end
    end
end
