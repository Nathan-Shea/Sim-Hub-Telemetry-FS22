---Event for toggle lower all




local DrivableToggleLowerAllEvent_mt = Class(DrivableToggleLowerAllEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function DrivableToggleLowerAllEvent.emptyNew()
    local self = Event.new(DrivableToggleLowerAllEvent_mt)
    return self
end


---Create new instance of event
-- @param table vehicle vehicle
function DrivableToggleLowerAllEvent.new(vehicle)
    local self = DrivableToggleLowerAllEvent.emptyNew()
    self.vehicle = vehicle
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function DrivableToggleLowerAllEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function DrivableToggleLowerAllEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
end


---Run action on receiving side
-- @param integer connection connection
function DrivableToggleLowerAllEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:toggleLowerAllImplements(true)
    end
    if not connection:getIsServer() then
        g_server:broadcastEvent(DrivableToggleLowerAllEvent.new(self.vehicle), nil, connection, self.object)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table vehicle vehicle
-- @param boolean noEventSend no event send
function DrivableToggleLowerAllEvent.sendEvent(vehicle, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(DrivableToggleLowerAllEvent.new(vehicle), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(DrivableToggleLowerAllEvent.new(vehicle))
        end
    end
end
