










local AIMessageErrorCouldNotPrepare_mt = Class(AIMessageErrorCouldNotPrepare, AIMessage)


---
function AIMessageErrorCouldNotPrepare.new(vehicle, customMt)
    local self = AIMessage.new(customMt or AIMessageErrorCouldNotPrepare_mt)

    self.vehicle = vehicle

    return self
end


---
function AIMessageErrorCouldNotPrepare:getMessage()
    return g_i18n:getText("ai_messageErrorCouldNotPrepare")
end












---
function AIMessageErrorCouldNotPrepare:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
end


---
function AIMessageErrorCouldNotPrepare:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
end
