


local PlayerToggleLightEvent_mt = Class(PlayerToggleLightEvent, Event)




---Create an empty instance
-- @return table instance Instance of object
function PlayerToggleLightEvent.emptyNew()
    local self = Event.new(PlayerToggleLightEvent_mt)
    return self
end


---Create an instance
-- @param table player player instance
-- @return table instance Instance of object
function PlayerToggleLightEvent.new(player, isActive)
    local self = PlayerToggleLightEvent.emptyNew()
    self.player = player
    self.isActive = isActive
    return self
end


---Reads network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerToggleLightEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)
    self.isActive = streamReadBool(streamId)
    self:run(connection)
end


---Writes network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerToggleLightEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
    streamWriteBool(streamId, self.isActive)
end


---Run event
-- @param table connection connection information
function PlayerToggleLightEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.player)
    end

    self.player:setLightIsActive(self.isActive, true)
end


---
function PlayerToggleLightEvent.sendEvent(player, active, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PlayerToggleLightEvent.new(player, active), nil, nil, player)
        else
            g_client:getServerConnection():sendEvent(PlayerToggleLightEvent.new(player, active))
        end
    end
end
