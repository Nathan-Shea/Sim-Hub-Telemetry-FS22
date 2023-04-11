---Class for vehicle selling point






local VehicleSellingPoint_mt = Class(VehicleSellingPoint)



---
function VehicleSellingPoint.registerXMLPaths(schema, basePath)
    schema:register(XMLValueType.NODE_INDEX, basePath .. "#playerTriggerNode", "Player trigger node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. "#iconNode", "Icon node")
    schema:register(XMLValueType.NODE_INDEX, basePath .. "#sellTriggerNode", "Sell trigger node")
    schema:register(XMLValueType.BOOL, basePath .. "#ownWorkshop", "Owned by player", false)
    schema:register(XMLValueType.BOOL, basePath .. "#mobileWorkshop", "Workshop is on vehicle", false)
end


---Creating vehicle selling point
-- @param integer id node id
-- @return table instance Instance of object
function VehicleSellingPoint.new()
    local self = setmetatable({}, VehicleSellingPoint_mt)

    self.vehicleShapesInRange = {}

    self.activateText = ""

    self.isEnabled = true

    return self
end


---
function VehicleSellingPoint:load(components, xmlFile, key, i3dMappings)
    self.playerTrigger = xmlFile:getValue(key.."#playerTriggerNode", nil, components, i3dMappings)
    self.sellIcon = xmlFile:getValue(key.."#iconNode", nil, components, i3dMappings)
    self.sellTriggerNode = xmlFile:getValue(key.."#sellTriggerNode", nil, components, i3dMappings)
    self.ownWorkshop = xmlFile:getValue(key.."#ownWorkshop", false)
    self.mobileWorkshop = xmlFile:getValue(key.."#mobileWorkshop", false)

    if not CollisionFlag.getHasFlagSet(self.playerTrigger, CollisionFlag.TRIGGER_PLAYER) then
        Logging.xmlWarning(xmlFile, "Missing collision mask bit '%d'. Please add this bit to vehicle selling player trigger node '%s'", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER), I3DUtil.getNodePath(self.playerTrigger))
    end
    addTrigger(self.playerTrigger, "triggerCallback", self)

    if not CollisionFlag.getHasFlagSet(self.sellTriggerNode, CollisionFlag.TRIGGER_VEHICLE) then
        Logging.xmlWarning(xmlFile, "Missing collision mask bit '%d'. Please add this bit to vehicle sell area trigger node '%s'", CollisionFlag.getBit(CollisionFlag.TRIGGER_VEHICLE), I3DUtil.getNodePath(self.sellTriggerNode))
    end
    addTrigger(self.sellTriggerNode, "sellAreaTriggerCallback", self)

    self.activatable = VehicleSellingPointActivatable.new(self, self.ownWorkshop)

    g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, self.playerFarmChanged, self)
    g_messageCenter:subscribe(MessageType.PLAYER_CREATED, self.playerFarmChanged, self)

    self:updateIconVisibility()
end


---Deleting vehicle selling point
function VehicleSellingPoint:delete()
    g_messageCenter:unsubscribeAll(self)

    if self.playerTrigger ~= nil then
        removeTrigger(self.playerTrigger)
        self.playerTrigger = nil
    end
    if self.sellTriggerNode ~= nil then
        removeTrigger(self.sellTriggerNode)
        self.sellTriggerNode = nil
    end

    g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)

    self.sellIcon = nil
end


---On activate object
function VehicleSellingPoint:openMenu()
    local vehicles = self:determineCurrentVehicles()

    g_workshopScreen:setSellingPoint(self, not self.ownWorkshop, self.ownWorkshop, self.mobileWorkshop)
    g_workshopScreen:setVehicles(vehicles)
    g_gui:showGui("WorkshopScreen")
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherId id of actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
function VehicleSellingPoint:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if self.isEnabled and g_currentMission.missionInfo:isa(FSCareerMissionInfo) then
        if onEnter or onLeave then
            if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
                if onEnter then
                    g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
                else
                    g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
                    self:determineCurrentVehicles()
                end
            end
        end
    end
end


---Sell area trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherId id of actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
function VehicleSellingPoint:sellAreaTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if otherShapeId ~= nil and (onEnter or onLeave) then
        if onEnter then
            self.vehicleShapesInRange[otherShapeId] = true
        elseif onLeave then
            self.vehicleShapesInRange[otherShapeId] = nil
        end

        g_workshopScreen:updateVehicles(self, self:determineCurrentVehicles())
    end
end


---Determine current vehicle
function VehicleSellingPoint:determineCurrentVehicles()
    local vehicles = {}

    local playerFarmId = g_currentMission:getFarmId()
    if playerFarmId ~= FarmManager.SPECTATOR_FARM_ID then

        -- Find first vehicle, then get its rood and all children
        for shapeId, inRange in pairs(self.vehicleShapesInRange) do
            if inRange ~= nil and entityExists(shapeId) then
                local vehicle = g_currentMission.nodeToObject[shapeId]
                if vehicle ~= nil then
                    local isRidable = SpecializationUtil.hasSpecialization(Rideable, vehicle.specializations)
                    if not isRidable and not vehicle.isPallet and vehicle.getSellPrice ~= nil and vehicle.price ~= nil then
                        local items = vehicle.rootVehicle:getChildVehicles()
                        for _, item in ipairs(items) do
                            local ownerFarmId = item:getOwnerFarmId()
                            -- only show owned items
                            if ownerFarmId == playerFarmId then
                                -- uniqueness check builtin
                                table.addElement(vehicles, item)
                            end
                        end
                    end
                end
            else
                self.vehicleShapesInRange[shapeId] = nil
            end
        end

        -- Consistent order independent on which piece of the vehicle entered the trigger first
        table.sort(vehicles, function(a, b)
            return a.rootNode < b.rootNode
        end)
    end

    return vehicles
end


---Turn the icon on or off depending on the current game and the players farm
function VehicleSellingPoint:updateIconVisibility()
    if self.sellIcon ~= nil then
        local isAvailable = self.isEnabled and g_currentMission.missionInfo:isa(FSCareerMissionInfo)
        local farmId = g_currentMission:getFarmId()
        local visibleForFarm = farmId ~= FarmManager.SPECTATOR_FARM_ID and (self:getOwnerFarmId() == AccessHandler.EVERYONE or farmId == self:getOwnerFarmId())

        setVisibility(self.sellIcon, isAvailable and visibleForFarm)
    end
end


---
function VehicleSellingPoint:playerFarmChanged(player)
    if player == g_currentMission.player then
        self:updateIconVisibility()
    end
end


---
function VehicleSellingPoint:setOwnerFarmId(ownerFarmId)
    self.ownerFarmId = ownerFarmId
    self:updateIconVisibility()
end


---
function VehicleSellingPoint:getOwnerFarmId()
    return self.ownerFarmId
end
