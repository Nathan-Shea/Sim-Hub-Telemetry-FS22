


local PlayerSetHandToolEvent_mt = Class(PlayerSetHandToolEvent, Event)




---Create an empty instance
-- @return table instance Instance of object
function PlayerSetHandToolEvent.emptyNew()
    local self = Event.new(PlayerSetHandToolEvent_mt)
    return self
end


---Create an instance
-- @param table player player instance
-- @param string tool identification
-- @return table instance Instance of object
function PlayerSetHandToolEvent.new(player, handtoolFileName, force)
    local self = PlayerSetHandToolEvent.emptyNew()
    self.player = player
    self.handtoolFileName = handtoolFileName
    self.force = force
    return self
end


---Reads network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerSetHandToolEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)
    self.handtoolFileName = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId))
    self.force = streamReadBool(streamId)
    self:run(connection)
end


---Writes network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerSetHandToolEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
    streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(self.handtoolFileName))
    streamWriteBool(streamId, self.force)
end


---Run event
-- @param table connection connection information
function PlayerSetHandToolEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.player)
    end

    self.player:equipHandtool(self.handtoolFileName, self.force, true)
end


---Create an instance
-- @param table player player instance
-- @param integer handtoolFileName tool identification
-- @param bool noEventSend if false will send the event
function PlayerSetHandToolEvent.sendEvent(player, handtoolFileName, force, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PlayerSetHandToolEvent.new(player, handtoolFileName, force), nil, nil, player)
        else
            g_client:getServerConnection():sendEvent(PlayerSetHandToolEvent.new(player, handtoolFileName, force))
        end
    end
end
