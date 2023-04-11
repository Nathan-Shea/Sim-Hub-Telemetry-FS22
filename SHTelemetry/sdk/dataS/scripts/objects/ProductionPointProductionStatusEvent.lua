---Event for production point production state change




local ProductionPointProductionStatusEvent_mt = Class(ProductionPointProductionStatusEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function ProductionPointProductionStatusEvent.emptyNew()
    local self = Event.new(ProductionPointProductionStatusEvent_mt)
    return self
end


---Create new instance of event
function ProductionPointProductionStatusEvent.new(productionPoint, productionId, status)
    local self = ProductionPointProductionStatusEvent.emptyNew()
    self.productionPoint = productionPoint
    self.productionId = productionId
    self.status = status
    return self
end


---Called on client side on join
function ProductionPointProductionStatusEvent:readStream(streamId, connection)
    self.productionPoint = NetworkUtil.readNodeObject(streamId)
    self.productionId = streamReadString(streamId)
    self.status = streamReadUIntN(streamId, ProductionPoint.PROD_STATUS_NUM_BITS)
    self:run(connection)
end


---Called on server side on join
function ProductionPointProductionStatusEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.productionPoint)
    streamWriteString(streamId, self.productionId)
    streamWriteUIntN(streamId, self.status, ProductionPoint.PROD_STATUS_NUM_BITS)
end


---Run action on receiving side
function ProductionPointProductionStatusEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection)
    end

    if self.productionPoint ~= nil then
        self.productionPoint:setProductionStatus(self.productionId, self.status, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
function ProductionPointProductionStatusEvent.sendEvent(productionPoint, productionId, status, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ProductionPointProductionStatusEvent.new(productionPoint, productionId, status))
        else
            g_client:getServerConnection():sendEvent(ProductionPointProductionStatusEvent.new(productionPoint, productionId, status))
        end
    end
end
