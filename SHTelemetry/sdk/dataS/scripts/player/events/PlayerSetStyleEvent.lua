


local PlayerSetStyleEvent_mt = Class(PlayerSetStyleEvent, Event)




---Create an empty instance
-- @return table instance Instance of object
function PlayerSetStyleEvent.emptyNew()
    local self = Event.new(PlayerSetStyleEvent_mt)
    return self
end


---Create an instance
function PlayerSetStyleEvent.new(player, style)
    local self = PlayerSetStyleEvent.emptyNew()

    self.player = player
    self.style = style

    return self
end


---Writes network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerSetStyleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
    self.style:writeStream(streamId, connection)
end


---Reads network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function PlayerSetStyleEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)

    self.style = PlayerStyle.new()
    self.style:readStream(streamId, connection)

    self:run(connection)
end


---Run event
-- @param table connection connection information
function PlayerSetStyleEvent:run(connection)
    if not connection:getIsServer() then --server side
        self.player:setStyleAsync(self.style, nil, false)
    else -- client side
        self.player:setStyleAsync(self.style, nil, true) -- do not send to server again
    end
end


---Create an instance
-- @param table player player instance
-- @param integer farmId farm identification
-- @param bool noEventSend if false will send the event
function PlayerSetStyleEvent.sendEvent(player, style, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PlayerSetStyleEvent.new(player, style), nil, nil, player)
        else
            g_client:getServerConnection():sendEvent(PlayerSetStyleEvent.new(player, style))
        end
    end
end
