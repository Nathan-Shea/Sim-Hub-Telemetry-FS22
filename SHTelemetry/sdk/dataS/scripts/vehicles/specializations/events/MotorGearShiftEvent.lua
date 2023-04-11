---Event for sending shifting inputs from client to server














local MotorGearShiftEvent_mt = Class(MotorGearShiftEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function MotorGearShiftEvent.emptyNew()
    local self = Event.new(MotorGearShiftEvent_mt)
    return self
end


---Create new instance of event
-- @param table vehicle vehicle
-- @param boolean turnedOn is turned on
function MotorGearShiftEvent.new(vehicle, shiftType, shiftValue)
    local self = MotorGearShiftEvent.emptyNew()
    self.vehicle = vehicle
    self.shiftType = shiftType
    self.shiftValue = shiftValue
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function MotorGearShiftEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.shiftType = streamReadUIntN(streamId, 4)

    if self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GEAR or self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GROUP then
        self.shiftValue = streamReadUIntN(streamId, 3)
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function MotorGearShiftEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.shiftType, 4)

    if self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GEAR or self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GROUP then
        streamWriteUIntN(streamId, self.shiftValue, 3)
    end
end


---Run action on receiving side
-- @param integer connection connection
function MotorGearShiftEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        local spec = self.vehicle.spec_motorized
        if spec ~= nil and spec.isMotorStarted then
            if self.shiftType == MotorGearShiftEvent.TYPE_SHIFT_UP then
                spec.motor:shiftGear(true)
            elseif self.shiftType == MotorGearShiftEvent.TYPE_SHIFT_DOWN then
                spec.motor:shiftGear(false)
            elseif self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GEAR then
                spec.motor:selectGear(self.shiftValue, self.shiftValue ~= 0)
            elseif self.shiftType == MotorGearShiftEvent.TYPE_SHIFT_GROUP_UP then
                spec.motor:shiftGroup(true)
            elseif self.shiftType == MotorGearShiftEvent.TYPE_SHIFT_GROUP_DOWN then
                spec.motor:shiftGroup(false)
            elseif self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GROUP then
                spec.motor:selectGroup(self.shiftValue, self.shiftValue ~= 0)
            elseif self.shiftType == MotorGearShiftEvent.TYPE_DIRECTION_CHANGE then
                spec.motor:changeDirection()
            elseif self.shiftType == MotorGearShiftEvent.TYPE_DIRECTION_CHANGE_POS then
                spec.motor:changeDirection(1)
            elseif self.shiftType == MotorGearShiftEvent.TYPE_DIRECTION_CHANGE_NEG then
                spec.motor:changeDirection(-1)
            end
        end
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table vehicle vehicle
-- @param integer shiftType type of shifting event
-- @param integer shiftValue additional value for shifting event
function MotorGearShiftEvent.sendEvent(vehicle, shiftType, shiftValue)
    if g_client ~= nil then
        g_client:getServerConnection():sendEvent(MotorGearShiftEvent.new(vehicle, shiftType, shiftValue))
    end
end
