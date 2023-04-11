---Event for leaving





local VehicleLeaveEvent_mt = Class(VehicleLeaveEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function VehicleLeaveEvent.emptyNew()
    local self = Event.new(VehicleLeaveEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @return table instance instance of event
function VehicleLeaveEvent.new(object)
    local self = VehicleLeaveEvent.emptyNew()
    self.object = object
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function VehicleLeaveEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function VehicleLeaveEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
end


---Run action on receiving side
-- @param integer connection connection
function VehicleLeaveEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        if not connection:getIsServer() then
            if self.object.owner ~= nil then
                self.object:setOwner(nil)
                self.object.controllerFarmId = nil
            end
            g_server:broadcastEvent(VehicleLeaveEvent.new(self.object), nil, connection, self.object)
        end

        self.object:leaveVehicle()
    end
end
