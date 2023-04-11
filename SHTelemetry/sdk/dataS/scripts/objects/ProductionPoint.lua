









































local ProductionPoint_mt = Class(ProductionPoint, Object)


---
function ProductionPoint.registerXMLPaths(schema, basePath)
    schema:register(XMLValueType.STRING,      basePath .. "#name", "Name of the Production Point", "unnamed production point")
    schema:register(XMLValueType.BOOL,        basePath .. ".productions#sharedThroughputCapacity", "Productions slow each other down if active at the same time", true)
    schema:register(XMLValueType.STRING,      basePath .. ".productions.production(?)#id", "Unique string used for identifying the production", nil, true)
    schema:register(XMLValueType.L10N_STRING, basePath .. ".productions.production(?)#name", "Name of the production used inside the UI", "unnamed production")
    schema:register(XMLValueType.STRING,      basePath .. ".productions.production(?)#params", "Optional parameters formatted into #name")
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?)#cyclesPerMonth", "Number of performed production cycles per ingame month (divided by the number of enabled productions, unless sharedThroughputCapacity is set to false)", 1440)
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?)#cyclesPerHour", "Number of production cycles per ingame hour per day (==month) (divided by the number of enabled productions, unless sharedThroughputCapacity is set to false)", 60)
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?)#cyclesPerMinute", "Number of performed production cycles per ingame minute (divided by the number of enabled productions)", 1)
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?)#costsPerActiveMonth", "Costs per ingame hour if this production is enabled per ingame month (regardless of whether it is producing or not)", 1440)
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?)#costsPerActiveHour", "Costs per ingame hour if this production is enabled per day (==month) (regardless of whether it is producing or not)", 60)
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?)#costsPerActiveMinute", "Costs per ingame minute if this production is enabled (regardless of whether it is producing or not)", 1)
    schema:register(XMLValueType.STRING,      basePath .. ".productions.production(?).inputs.input(?)#fillType", "Input fillType", nil, true)
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?).inputs.input(?)#amount", "Used amount per cycle", 1)
    schema:register(XMLValueType.STRING,      basePath .. ".productions.production(?).outputs.output(?)#fillType", "Output fillType", nil, true)
    schema:register(XMLValueType.FLOAT,       basePath .. ".productions.production(?).outputs.output(?)#amount", "Produced amount per cycle", 1)
    schema:register(XMLValueType.BOOL,        basePath .. ".productions.production(?).outputs.output(?)#sellDirectly", "Directly sell produced amount", false)

    schema:register(XMLValueType.NODE_INDEX,  basePath .. ".playerTrigger#node", "", "")

    SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "active")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "idle")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".productions.production(?).sounds", "active")

    AnimationManager.registerAnimationNodesXMLPaths(schema, basePath .. ".animationNodes")
    AnimationManager.registerAnimationNodesXMLPaths(schema, basePath .. ".productions.production(?).animationNodes")

    EffectManager.registerEffectXMLPaths(schema, basePath .. ".effectNodes")
    EffectManager.registerEffectXMLPaths(schema, basePath .. ".productions.production(?).effectNodes")

    SellingStation.registerXMLPaths(schema, basePath .. ".sellingStation")
    LoadingStation.registerXMLPaths(schema, basePath .. ".loadingStation")
    PalletSpawner.registerXMLPaths(schema, basePath .. ".palletSpawner")
    Storage.registerXMLPaths(schema , basePath .. ".storage")
end


---
function ProductionPoint.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.INT,     basePath .. "#palletSpawnCooldown", "remaining cooldown duration of pallet spawner")
    schema:register(XMLValueType.FLOAT,   basePath .. "#productionCostsToClaim", "production costs yet to be claimed from the owning player")
    schema:register(XMLValueType.STRING,  basePath .. ".directSellFillType(?)", "fillType currently configured to be directly sold")
    schema:register(XMLValueType.STRING,  basePath .. ".autoDeliverFillType(?)", "fillType currently configured to be automatically delivered")
    schema:register(XMLValueType.STRING,  basePath .. ".production(?)#id", "Unique id of the production")
    schema:register(XMLValueType.BOOL,    basePath .. ".production(?)#isEnabled", "State of the production")
    Storage.registerSavegameXMLPaths(schema ,  basePath .. ".storage")
end


















































































































































































































































































































































































































---Called on client side on join
-- @param integer streamId stream ID
-- @param table connection connection
function ProductionPoint:readStream(streamId, connection)
    ProductionPoint:superClass().readStream(self, streamId, connection)

    if connection:getIsServer() then
        -- direct sell fillTypes
        for i=1, streamReadUInt8(streamId) do
            self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.DIRECT_SELL)
        end

        -- auto deliver fillTypes
        for i=1, streamReadUInt8(streamId) do
            self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.AUTO_DELIVER)
        end

        -- unloading station
        local unloadingStationId = NetworkUtil.readNodeObjectId(streamId)
        self.unloadingStation:readStream(streamId, connection)
        g_client:finishRegisterObject(self.unloadingStation, unloadingStationId)

        -- loading station
        if self.loadingStation ~= nil then
            local loadingStationId = NetworkUtil.readNodeObjectId(streamId)
            self.loadingStation:readStream(streamId, connection)
            g_client:finishRegisterObject(self.loadingStation, loadingStationId)
        end

        -- storage
        local storageId = NetworkUtil.readNodeObjectId(streamId)
        self.storage:readStream(streamId, connection)
        g_client:finishRegisterObject(self.storage, storageId)

        -- active productions + status
        for i=1, streamReadUInt8(streamId) do
            local productionId = streamReadString(streamId)
            self:setProductionState(productionId, true)

            self:setProductionStatus(productionId, streamReadUIntN(streamId, ProductionPoint.PROD_STATUS_NUM_BITS))
        end

        self.palletLimitReached = streamReadBool(streamId)
    end
end


---Called on server side on join
-- @param integer streamId stream ID
-- @param table connection connection
function ProductionPoint:writeStream(streamId, connection)
    ProductionPoint:superClass().writeStream(self, streamId, connection)

    if not connection:getIsServer() then
        -- direct sell fillTypes
        streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsDirectSell))
        for directSellFillTypeId in pairs(self.outputFillTypeIdsDirectSell) do
            streamWriteUIntN(streamId, directSellFillTypeId, FillTypeManager.SEND_NUM_BITS)
        end

        -- auto deliver fillTypes
        streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsAutoDeliver))
        for autoDeliverFillTypeId in pairs(self.outputFillTypeIdsAutoDeliver) do
            streamWriteUIntN(streamId, autoDeliverFillTypeId, FillTypeManager.SEND_NUM_BITS)
        end

        -- unloading station
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.unloadingStation))
        self.unloadingStation:writeStream(streamId, connection)
        g_server:registerObjectInStream(connection, self.unloadingStation)

        -- loading station
        if self.loadingStation ~= nil then
            NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.loadingStation))
            self.loadingStation:writeStream(streamId, connection)
            g_server:registerObjectInStream(connection, self.loadingStation)
        end

        -- storage
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.storage))
        self.storage:writeStream(streamId, connection)
        g_server:registerObjectInStream(connection, self.storage)

        -- active productions + status
        streamWriteUInt8(streamId, #self.activeProductions)
        for i=1, #self.activeProductions do
            local production = self.activeProductions[i]
            streamWriteString(streamId, production.id)
            streamWriteUIntN(streamId, production.status, ProductionPoint.PROD_STATUS_NUM_BITS)
        end

        streamWriteBool(streamId, self.palletLimitReached)
    end
end


---
function ProductionPoint:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        self.palletLimitReached = streamReadBool(streamId)
    end
end


---
function ProductionPoint:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        streamWriteBool(streamId, self.palletLimitReached)
    end
end












































































































































































































































































































































---Loading from attributes and nodes
-- @param integer xmlFile id of xml object
-- @param string key key
-- @return boolean success success
function ProductionPoint:loadFromXMLFile(xmlFile, key)
    local palletSpawnCooldown = xmlFile:getValue(key .. "#palletSpawnCooldown")
    if palletSpawnCooldown then
        self.palletSpawnCooldown = g_time + palletSpawnCooldown
    end

    self.productionCostsToClaim = xmlFile:getValue(key .. "#productionCostsToClaim") or self.productionCostsToClaim

    if self.owningPlaceable.ownerFarmId == AccessHandler.EVERYONE then
        for n=1, #self.productions do
            self:setProductionState(self.productions[n].id, true)
        end
    end

    xmlFile:iterate(key..".production", function(index, productionKey)
        local prodId = xmlFile:getValue(productionKey .. "#id")
        local isEnabled = xmlFile:getValue(productionKey .. "#isEnabled")
        if self.productionsIdToObj[prodId] == nil then
            Logging.xmlWarning(xmlFile, "Unknown production id '%s'", prodId)
        else
            self:setProductionState(prodId, isEnabled)
        end
    end)

    xmlFile:iterate(key..".directSellFillType", function(index, directSellKey)
        local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(directSellKey))
        if fillType then
            self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.DIRECT_SELL)
        end
    end)

    xmlFile:iterate(key..".autoDeliverFillType", function(index, autoDeliverKey)
        local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(autoDeliverKey))
        if fillType then
            self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.AUTO_DELIVER)
        end
    end)

    if not self.storage:loadFromXMLFile(xmlFile, key .. ".storage") then
        return false
    end
    return true
end
























































































































































































































---
function ProductionPoint.loadSpecValueInputFillTypes(xmlFile, customEnvironment, baseDir)
    local fillTypeNames = nil
    xmlFile:iterate("placeable.productionPoint.productions.production", function(_, productionKey)
        xmlFile:iterate(productionKey .. ".inputs.input", function(_, inputKey)
            local fillTypeName = xmlFile:getValue(inputKey .. "#fillType")
            fillTypeNames = fillTypeNames or {}
            fillTypeNames[fillTypeName] = true
        end)
    end)

    return fillTypeNames
end


---
function ProductionPoint.getSpecValueInputFillTypes(storeItem, realItem)
    if storeItem.specs.prodPointInputFillTypes == nil then
        return nil
    end

    return g_fillTypeManager:getFillTypesByNames(table.concatKeys(storeItem.specs.prodPointInputFillTypes, " "))
end


---
function ProductionPoint.loadSpecValueOutputFillTypes(xmlFile, customEnvironment, baseDir)
    local fillTypeNames = nil
    xmlFile:iterate("placeable.productionPoint.productions.production", function(_, productionKey)
        xmlFile:iterate(productionKey .. ".outputs.output", function(_, inputKey)
            local fillTypeName = xmlFile:getValue(inputKey .. "#fillType")
            fillTypeNames = fillTypeNames or {}
            fillTypeNames[fillTypeName] = true
        end)
    end)

    return fillTypeNames
end


---
function ProductionPoint.getSpecValueOutputFillTypes(storeItem, realItem)
    if storeItem.specs.prodPointOutputFillTypes == nil then
        return nil
    end

    return g_fillTypeManager:getFillTypesByNames(table.concatKeys(storeItem.specs.prodPointOutputFillTypes, " "))
end


---
function ProductionPoint:interactionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        if self.mission.player and self.mission.player.rootNode == otherId then
            if onEnter then
                -- automatically perform action without manual activation on mobile
                if Platform.isMobile and self.activatable:getIsActivatable() then
                    self.activatable:run()
                    return
                end

                self.activatable:updateText()

                self.mission.activatableObjectsSystem:addActivatable(self.activatable)
            end
            if onLeave then
                self.mission.activatableObjectsSystem:removeActivatable(self.activatable)
            end
        end
    end
end



---when player activates trigger on self-owned production point
function ProductionPoint:openMenu()
    g_gui:showGui("InGameMenu")
    g_messageCenter:publishDelayed(MessageType.GUI_INGAME_OPEN_PRODUCTION_SCREEN, self)
end


---when player activates trigger on not-owned production point
function ProductionPoint:buyRequest()

    local storeItem = g_storeManager:getItemByXMLFilename(self.owningPlaceable.configFileName)
    local price = g_currentMission.economyManager:getBuyPrice(storeItem) or self.owningPlaceable:getPrice()
    if self.owningPlaceable.buysFarmland and self.owningPlaceable.farmlandId ~= nil then
        local farmland = g_farmlandManager:getFarmlandById(self.owningPlaceable.farmlandId)
        if farmland ~= nil and g_farmlandManager:getFarmlandOwner(self.owningPlaceable.farmlandId) ~= self.mission:getFarmId() then
            price = price + farmland.price
        end
    end

    local activatable = self.activatable
    local productionPoint = self
    local buyingEventCallback = function(statusCode)
        if statusCode ~= nil then
            local dialogArgs = BuyExistingPlaceableEvent.DIALOG_MESSAGES[statusCode]
            if dialogArgs ~= nil then
                g_gui:showInfoDialog({text=g_i18n:getText(dialogArgs.text), dialogType=dialogArgs.dialogType})
            end
        end
        g_messageCenter:unsubscribe(BuyExistingPlaceableEvent, productionPoint)
        activatable:updateText()
    end

    local text = string.format(g_i18n:getText("dialog_buyBuildingFor"), self:getName(), g_i18n:formatMoney(price, 0, true))
    local dialogCallback = function(yes)
        if yes then
            g_messageCenter:subscribe(BuyExistingPlaceableEvent, buyingEventCallback)

            g_client:getServerConnection():sendEvent(BuyExistingPlaceableEvent.new(self.owningPlaceable, self.mission:getFarmId()))
        end
    end

    g_gui:showYesNoDialog({text=text, callback=dialogCallback})
end
