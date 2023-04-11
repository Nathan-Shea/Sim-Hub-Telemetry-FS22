---Event for hpw turn on state





local PlaceableHighPressureWasherStateEvent_mt = Class(PlaceableHighPressureWasherStateEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function PlaceableHighPressureWasherStateEvent.emptyNew()
    local self = Event.new(PlaceableHighPressureWasherStateEvent_mt)
    return self
end


---Create new instance of event
-- @param table placeable placeable
-- @param boolean isTurnedOn is turned on
-- @param table player player
-- @return table instance instance of event
function PlaceableHighPressureWasherStateEvent.new(placeable, isTurnedOn, player)
    local self = PlaceableHighPressureWasherStateEvent.emptyNew()
    self.placeable = placeable
    self.isTurnedOn = isTurnedOn
    self.player = player

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function PlaceableHighPressureWasherStateEvent:readStream(streamId, connection)
    self.placeable = NetworkUtil.readNodeObject(streamId)
    self.isTurnedOn = streamReadBool(streamId)
    if self.isTurnedOn then
        self.player = NetworkUtil.readNodeObject(streamId)
    end
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function PlaceableHighPressureWasherStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.placeable)
    streamWriteBool(streamId, self.isTurnedOn)
    if self.isTurnedOn then
        NetworkUtil.writeNodeObject(streamId, self.player)
    end
end


---Run action on receiving side
-- @param integer connection connection
function PlaceableHighPressureWasherStateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.placeable)
    end

    if self.placeable ~= nil and self.placeable:getIsSynchronized() then
        self.placeable:setIsHighPressureWasherTurnedOn(self.isTurnedOn, self.player, true)
    end
end
