


local PlayerThrowObjectEvent_mt = Class(PlayerThrowObjectEvent, Event)




---Create an empty instance
-- @return table instance Instance of object
function PlayerThrowObjectEvent.emptyNew()
    local self = Event.new(PlayerThrowObjectEvent_mt)
    return self
end


---Create an instance
-- @param table player player instance
-- @return table instance Instance of object
function PlayerThrowObjectEvent.new(player)
    local self = PlayerThrowObjectEvent.emptyNew()
    self.player = player
    return self
end


---Reads network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerThrowObjectEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end


---Writes network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerThrowObjectEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
end


---Run event
-- @param table connection connection information
function PlayerThrowObjectEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.player)
    end

    self.player:throwObject(true)
end


---
function PlayerThrowObjectEvent.sendEvent(player, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PlayerThrowObjectEvent.new(player), nil, nil, player)
        else
            g_client:getServerConnection():sendEvent(PlayerThrowObjectEvent.new(player))
        end
    end
end
