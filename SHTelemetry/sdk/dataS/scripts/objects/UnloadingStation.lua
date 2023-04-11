













local UnloadingStation_mt = Class(UnloadingStation, Object)





























































































---Called on client side on join
-- @param integer streamId stream ID
-- @param table connection connection
function UnloadingStation:readStream(streamId, connection)
    UnloadingStation:superClass().readStream(self, streamId, connection)
    if connection:getIsServer() then
        for _, unloadTrigger in ipairs(self.unloadTriggers) do
            local unloadTriggerId = NetworkUtil.readNodeObjectId(streamId)
            unloadTrigger:readStream(streamId, connection)
            g_client:finishRegisterObject(unloadTrigger, unloadTriggerId)
        end
    end
end


---Called on server side on join
-- @param integer streamId stream ID
-- @param table connection connection
function UnloadingStation:writeStream(streamId, connection)
    UnloadingStation:superClass().writeStream(self, streamId, connection)
    if not connection:getIsServer() then
        for _, unloadTrigger in ipairs(self.unloadTriggers) do
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(unloadTrigger))
            unloadTrigger:writeStream(streamId, connection)
            g_server:registerObjectInStream(connection, unloadTrigger)
        end
    end
end




































































































































































































































---
function UnloadingStation.registerXMLPaths(schema, basePath)
    schema:register(XMLValueType.NODE_INDEX, basePath .. "#node", "Unloading station node")
    schema:register(XMLValueType.STRING,     basePath .. "#stationName", "Station name", "LoadingStation")
    schema:register(XMLValueType.FLOAT,      basePath .. "#storageRadius", "Inside of this radius storages can be placed", 50)
    schema:register(XMLValueType.BOOL,       basePath .. "#hideFromPricesMenu", "Hide station from prices menu", false)
    schema:register(XMLValueType.BOOL,       basePath .. "#supportsExtension", "Supports extensions", false)

    UnloadTrigger.registerXMLPaths(schema, basePath .. ".unloadTrigger(?)")
    schema:register(XMLValueType.STRING, basePath .. ".unloadTrigger(?)#class", "Name of unload trigger class")

    SoundManager.registerSampleXMLPaths(schema,  basePath .. ".sounds", "active")
    SoundManager.registerSampleXMLPaths(schema,  basePath .. ".sounds", "idle")
    AnimationManager.registerAnimationNodesXMLPaths(schema, basePath .. ".animationNodes")
    EffectManager.registerEffectXMLPaths(schema, basePath .. ".effectNodes")
end
