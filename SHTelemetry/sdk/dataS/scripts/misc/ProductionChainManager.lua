---This class handles the interaction between Production- and/or SellingPoints











local ProductionChainManager_mt = Class(ProductionChainManager, AbstractManager)


---Creating manager
-- @return table instance instance of object
function ProductionChainManager.new(isServer, customMt)
    local self = AbstractManager.new(customMt or ProductionChainManager_mt)

    self.isServer = isServer

--#debug     self.debugEnabled = false

--#debug     addConsoleCommand("gsProductionPointToggleDebug", "Toggle production point debugging", "consoleCommandToggleProdPointDebug", self)
    addConsoleCommand("gsProductionPointsList", "List all production points on map", "commandListProductionPoints", self)
    addConsoleCommand("gsProductionPointsPrintAutoDeliverMapping", "Prints which fillTypes are required by which production points", "commandPrintAutoDeliverMapping", self)
    addConsoleCommand("gsProductionPointSetOwner", "", "commandSetOwner", self)
    addConsoleCommand("gsProductionPointSetProductionState", "", "commandSetProductionState", self)
    addConsoleCommand("gsProductionPointSetOutputMode", "", "commandSetOutputMode", self)
    addConsoleCommand("gsProductionPointSetFillLevel", "", "commandSetFillLevel", self)

    if self.isServer then
        g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.hourChanged, self)
    end

    return self
end


---Initialize data structures
function ProductionChainManager:initDataStructures()
    self.productionPoints = {}
    self.reverseProductionPoint = {}

    self.farmIds = {}

    self.currentUpdateIndex = 1
    self.hourChangedDirty = false
    self.hourChangeUpdating = false
end


---
function ProductionChainManager:unloadMapData()
--#debug     removeConsoleCommand("gsProductionPointToggleDebug")
    removeConsoleCommand("gsProductionPointsList")
    removeConsoleCommand("gsProductionPointsPrintAutoDeliverMapping")
    removeConsoleCommand("gsProductionPointSetOwner")
    removeConsoleCommand("gsProductionPointSetProductionState")
    removeConsoleCommand("gsProductionPointSetOutputMode")
    removeConsoleCommand("gsProductionPointSetFillLevel")

    if self.isServer then
        g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
    end

    ProductionChainManager:superClass().unloadMapData(self)
end


---
function ProductionChainManager:addProductionPoint(productionPoint)
    if self.reverseProductionPoint[productionPoint] then
        printf("Warning: Production point '%s' already registered.", productionPoint:tableId())
        return false
    end
    if #self.productionPoints >= ProductionChainManager.NUM_MAX_PRODUCTION_POINTS then
        printf("Maximum number of %i Production Points reached.", ProductionChainManager.NUM_MAX_PRODUCTION_POINTS)
        return false
    end

    if #self.productionPoints == 0 and self.isServer then
        g_currentMission:addUpdateable(self)
    end

    self.reverseProductionPoint[productionPoint] = true
    table.insert(self.productionPoints, productionPoint)

--#debug     if self.debugEnabled then
--#debug         g_currentMission:addDrawable(productionPoint)
--#debug     end

    local farmId = productionPoint:getOwnerFarmId()
    if farmId ~= AccessHandler.EVERYONE then
        if not self.farmIds[farmId] then
            self.farmIds[farmId] = {}
        end
        self:addProductionPointToFarm(productionPoint, self.farmIds[farmId])
    end
    return true
end


---
function ProductionChainManager:addProductionPointToFarm(productionPoint, farmTable)
    if not farmTable.productionPoints then
        farmTable.productionPoints = {}
    end
    table.insert(farmTable.productionPoints, productionPoint)

    if not farmTable.inputTypeToProductionPoints then
        farmTable.inputTypeToProductionPoints = {}
    end

    for inputType in pairs(productionPoint.inputFillTypeIds) do
        if not farmTable.inputTypeToProductionPoints[inputType] then
            farmTable.inputTypeToProductionPoints[inputType] = {}
        end
        table.insert(farmTable.inputTypeToProductionPoints[inputType], productionPoint)
    end
end


---
function ProductionChainManager:removeProductionPoint(productionPoint)
    self.reverseProductionPoint[productionPoint] = nil

    if table.removeElement(self.productionPoints, productionPoint) then
        local farmId = productionPoint:getOwnerFarmId()
        if farmId ~= AccessHandler.EVERYONE then
            self.farmIds[farmId] = self:removeProductionPointFromFarm(productionPoint, self.farmIds[farmId])
        end

--#debug         if self.debugEnabled then
--#debug             g_currentMission:removeDrawable(productionPoint)
--#debug         end
    end

    if #self.productionPoints == 0 and self.isServer then
        g_currentMission:removeUpdateable(self)
    end
end


---
function ProductionChainManager:removeProductionPointFromFarm(productionPoint, farmTable)
    table.removeElement(farmTable.productionPoints, productionPoint)

    local inputTypeToProductionPoints = farmTable.inputTypeToProductionPoints
    for inputType in pairs(productionPoint.inputFillTypeIds) do
        if inputTypeToProductionPoints[inputType] then
            if not table.removeElement(inputTypeToProductionPoints[inputType], productionPoint) then
                log("Error: ProductionChainManager:removeProductionPoint(): Unable to remove production point from input type mapping")
            end
            if #inputTypeToProductionPoints[inputType] == 0 then
                inputTypeToProductionPoints[inputType] = nil
            end
        end
    end
    if #farmTable.productionPoints == 0 then
        farmTable = nil
    end
    return farmTable
end


---
function ProductionChainManager:getProductionPointsForFarmId(farmId)
    return self.farmIds[farmId] and self.farmIds[farmId].productionPoints or {}
end


---
function ProductionChainManager:getNumOfProductionPoints()
    return #self.productionPoints
end


---
function ProductionChainManager:getHasFreeSlots()
    return #self.productionPoints < ProductionChainManager.NUM_MAX_PRODUCTION_POINTS
end









































---
function ProductionChainManager:hourChanged()
    self.hourChangedDirty = true
end


























































---
function ProductionChainManager:updateBalance()

end
