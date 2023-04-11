


local AnimalHusbandryNoMorePalletSpaceEvent_mt = Class(AnimalHusbandryNoMorePalletSpaceEvent, Event)





---Creating empty instance
-- @return table instance instance of object
function AnimalHusbandryNoMorePalletSpaceEvent.emptyNew()
    local self = Event.new(AnimalHusbandryNoMorePalletSpaceEvent_mt)
    return self
end


---Creating instance
-- @param table animalHusbandry instance of animal husbandry
-- @return table instance instance of object
function AnimalHusbandryNoMorePalletSpaceEvent.new(animalHusbandry)
    local self = AnimalHusbandryNoMorePalletSpaceEvent.emptyNew()

    self.animalHusbandry = animalHusbandry

    return self
end



---Reads from network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function AnimalHusbandryNoMorePalletSpaceEvent:readStream(streamId, connection)
    self.animalHusbandry = NetworkUtil.readNodeObject(streamId)

    self:run(connection)
end


---Writes in network stream
-- @param integer streamId network stream identification
-- @param table connection connection information
function AnimalHusbandryNoMorePalletSpaceEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.animalHusbandry)
end


---Run event
-- @param table connection connection information
function AnimalHusbandryNoMorePalletSpaceEvent:run(connection)
    if connection:getIsServer() then
        if self.animalHusbandry ~= nil then
            self.animalHusbandry:showPalletBlockedWarning()
        end
    end
end
