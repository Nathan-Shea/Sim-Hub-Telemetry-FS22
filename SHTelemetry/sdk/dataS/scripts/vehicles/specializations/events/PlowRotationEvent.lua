---Event for plow rotation




local PlowRotationEvent_mt = Class(PlowRotationEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function PlowRotationEvent.emptyNew()
    local self = Event.new(PlowRotationEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean rotationMax rotation max
function PlowRotationEvent.new(object, rotationMax)
    local self = PlowRotationEvent.emptyNew()
    self.object = object
    self.rotationMax = rotationMax
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function PlowRotationEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.rotationMax = streamReadBool(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function PlowRotationEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.rotationMax)
end


---Run action on receiving side
-- @param integer connection connection
function PlowRotationEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:setRotationMax(self.rotationMax, true)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(PlowRotationEvent.new(self.object, self.rotationMax), nil, connection, self.object)
    end
end
