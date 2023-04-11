---Event for hpw state




local HPWLanceStateEvent_mt = Class(HPWLanceStateEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function HPWLanceStateEvent.emptyNew()
    local self = Event.new(HPWLanceStateEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean doWashing do washing
-- @return table instance instance of event
function HPWLanceStateEvent.new(player, doWashing)
    local self = HPWLanceStateEvent.emptyNew()
    self.player = player
    self.doWashing = doWashing
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function HPWLanceStateEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)
    self.doWashing = streamReadBool(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function HPWLanceStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
    streamWriteBool(streamId, self.doWashing)
end


---Run action on receiving side
-- @param integer connection connection
function HPWLanceStateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.player)
    end
    local currentTool = self.player.baseInformation.currentHandtool
    if currentTool ~= nil and currentTool.setIsWashing ~= nil then
        currentTool:setIsWashing(self.doWashing, false, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean doWashing do washing
-- @param boolean noEventSend no event send
function HPWLanceStateEvent.sendEvent(player, doWashing, noEventSend)
    local currentTool = player.baseInformation.currentHandtool
    if currentTool ~= nil and currentTool.setIsWashing ~= nil and doWashing ~= currentTool.doWashing then
        if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(HPWLanceStateEvent.new(player, doWashing), nil, nil, player)
            else
                g_client:getServerConnection():sendEvent(HPWLanceStateEvent.new(player, doWashing))
            end
        end
    end
end
