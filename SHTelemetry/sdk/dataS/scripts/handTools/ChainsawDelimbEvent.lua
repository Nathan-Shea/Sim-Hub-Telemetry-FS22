---Event for delimb





local ChainsawDelimbEvent_mt = Class(ChainsawDelimbEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function ChainsawDelimbEvent.emptyNew()
    local self = Event.new(ChainsawDelimbEvent_mt)
    return self
end


---Create new instance of event
-- @param table player player
-- @param float x x
-- @param float y y
-- @param float z z
-- @param float nx nx
-- @param float ny ny
-- @param float nz nz
-- @param float yx yx
-- @param float yy yy
-- @param float yz yz
-- @param boolean onDelimb on delimb
-- @return table instance instance of event
function ChainsawDelimbEvent.new(player, x,y,z, nx,ny,nz, yx,yy,yz, onDelimb)
    local self = ChainsawDelimbEvent.emptyNew()
    self.player = player
    self.x, self.y, self.z = x, y, z
    self.nx, self.ny, self.nz = nx, ny, nz
    self.yx, self.yy, self.yz = yx, yy, yz
    self.onDelimb = onDelimb
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChainsawDelimbEvent:readStream(streamId, connection)
    if not connection:getIsServer() then                                -- server side
        self.player = NetworkUtil.readNodeObject(streamId)
        self.x = streamReadFloat32(streamId)
        self.y = streamReadFloat32(streamId)
        self.z = streamReadFloat32(streamId)
        self.nx = streamReadFloat32(streamId)
        self.ny = streamReadFloat32(streamId)
        self.nz = streamReadFloat32(streamId)
        self.yx = streamReadFloat32(streamId)
        self.yy = streamReadFloat32(streamId)
        self.yz = streamReadFloat32(streamId)
        self.onDelimb = false
        if self.player ~= nil then
            local chainsaw = self.player.baseInformation.currentHandtool
            if chainsaw ~= nil then
                local ret = findAndRemoveSplitShapeAttachments(self.x,self.y,self.z, self.nx,self.ny,self.nz, self.yx,self.yy,self.yz, 0.7, chainsaw.cutSizeY, chainsaw.cutSizeZ)
                if ret then
                    self.onDelimb = true
                    connection:sendEvent(self)
                end
            end
        end
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChainsawDelimbEvent:writeStream(streamId, connection)
    if connection:getIsServer() then                                    -- client
        NetworkUtil.writeNodeObject(streamId, self.player)
        streamWriteFloat32(streamId, self.x)
        streamWriteFloat32(streamId, self.y)
        streamWriteFloat32(streamId, self.z)
        streamWriteFloat32(streamId, self.nx)
        streamWriteFloat32(streamId, self.ny)
        streamWriteFloat32(streamId, self.nz)
        streamWriteFloat32(streamId, self.yx)
        streamWriteFloat32(streamId, self.yy)
        streamWriteFloat32(streamId, self.yz)
    else
        NetworkUtil.writeNodeObject(streamId, self.player)
        streamWriteBool(streamId, self.onDelimb)
    end
end


---Run action on receiving side
-- @param integer connection connection
function ChainsawDelimbEvent:run(connection)
    print("Error: ChainsawDelimbEvent is not allowed to be executed on a local client")
end
