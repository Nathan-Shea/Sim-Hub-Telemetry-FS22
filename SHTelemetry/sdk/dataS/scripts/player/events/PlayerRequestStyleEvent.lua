


local PlayerRequestStyleEvent_mt = Class(PlayerRequestStyleEvent, Event)




---Create an empty instance
-- @return table instance Instance of object
function PlayerRequestStyleEvent.emptyNew()
    local self = Event.new(PlayerRequestStyleEvent_mt)
    return self
end


---Create an instance
function PlayerRequestStyleEvent.new(playerObjectId)
    local self = PlayerRequestStyleEvent.emptyNew()

    self.playerObjectId = playerObjectId

    return self
end


---Writes network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerRequestStyleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObjectId(streamId, self.playerObjectId)
end


---Reads network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerRequestStyleEvent:readStream(streamId, connection)
    self.playerObjectId = NetworkUtil.readNodeObjectId(streamId)
    self.player = NetworkUtil.getObject(self.playerObjectId)

    self:run(connection)
end


---Run event
-- @param table connection connection information
function PlayerRequestStyleEvent:run(connection)
    if not connection:getIsServer() then --server side
        local style = g_currentMission.playerInfoStorage:getPlayerStyle(self.player.userId)
        connection:sendEvent(PlayerSetStyleEvent.new(self.player, style))
    end
end
