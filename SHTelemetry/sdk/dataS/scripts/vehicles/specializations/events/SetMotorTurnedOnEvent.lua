---Event for motor turned on state




local SetMotorTurnedOnEvent_mt = Class(SetMotorTurnedOnEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function SetMotorTurnedOnEvent.emptyNew()
    local self = Event.new(SetMotorTurnedOnEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean turnedOn is turned on
function SetMotorTurnedOnEvent.new(object, turnedOn)
    local self = SetMotorTurnedOnEvent.emptyNew()
    self.object = object
    self.turnedOn = turnedOn
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function SetMotorTurnedOnEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.turnedOn = streamReadBool(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function SetMotorTurnedOnEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.turnedOn)
end


---Run action on receiving side
-- @param integer connection connection
function SetMotorTurnedOnEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        if self.turnedOn then
            self.object:startMotor(true)
        else
            self.object:stopMotor(true)
        end
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(SetMotorTurnedOnEvent.new(self.object, self.turnedOn), nil, connection, self.object)
    end
end
