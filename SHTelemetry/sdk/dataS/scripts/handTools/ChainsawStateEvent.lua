---Event for chainsaw state





local ChainsawStateEvent_mt = Class(ChainsawStateEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function ChainsawStateEvent.emptyNew()
    local self = Event.new(ChainsawStateEvent_mt)
    return self
end


---Create new instance of event
-- @param table player player
-- @param boolean isCutting is cutting
-- @param boolean isHorizontalCut is horizontal cutting
-- @return table instance instance of event
function ChainsawStateEvent.new(player, isCutting, isHorizontalCut, hasBeencut)
    local self = ChainsawStateEvent.emptyNew()
    self.player = player
    self.isCutting = isCutting
    self.isHorizontalCut = isHorizontalCut
    self.hasBeenCut = hasBeencut
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChainsawStateEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)
    self.isCutting = streamReadBool(streamId)
    self.isHorizontalCut = streamReadBool(streamId)
    self.hasBeenCut = streamReadBool(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChainsawStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
    streamWriteBool(streamId, self.isCutting)
    streamWriteBool(streamId, self.isHorizontalCut)
    streamWriteBool(streamId, self.hasBeenCut)
end


---Run action on receiving side
-- @param integer connection connection
function ChainsawStateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.player)
    end

    local currentTool = self.player.baseInformation.currentHandtool
    if currentTool ~= nil and currentTool.setCutting ~= nil then
        currentTool:setCutting(self.isCutting, self.isHorizontalCut, self.hasBeenCut, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table player player
-- @param boolean isCutting is cutting
-- @param boolean isHorizontalCut is horizontal cutting
-- @param boolean noEventSend no event send
function ChainsawStateEvent.sendEvent(player, isCutting, isHorizontalCut, hasBeenCut, noEventSend)
    local currentTool = player.baseInformation.currentHandtool
    if currentTool ~= nil and currentTool.setCutting ~= nil and (currentTool.isCutting ~= isCutting or currentTool.hasBeenCut ~= hasBeenCut) then
        if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(ChainsawStateEvent.new(player, isCutting, isHorizontalCut, hasBeenCut), nil, nil, player)
            else
                g_client:getServerConnection():sendEvent(ChainsawStateEvent.new(player, isCutting, isHorizontalCut, hasBeenCut))
            end
        end
    end
end
