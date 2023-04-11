---Specialization for tree planters providing possibility to pick up seedling pallets and create trees






























---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function TreePlanter.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(TurnOnVehicle, specializations)
       and SpecializationUtil.hasSpecialization(FillUnit, specializations)
       and SpecializationUtil.hasSpecialization(GroundReference, specializations)
end


---
function TreePlanter.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("TreePlanter")

    schema:register(XMLValueType.NODE_INDEX, "vehicle.treePlanter#node", "Node index")
    schema:register(XMLValueType.FLOAT, "vehicle.treePlanter#minDistance", "Min. distance between trees", 20)
    schema:register(XMLValueType.NODE_INDEX, "vehicle.treePlanter#palletTrigger", "Pallet trigger")
    schema:register(XMLValueType.INT, "vehicle.treePlanter#refNodeIndex", "Ground reference node index", 1)
    schema:register(XMLValueType.NODE_INDEX, "vehicle.treePlanter#saplingPalletGrabNode", "Sapling pallet grab node")
    schema:register(XMLValueType.NODE_INDEX, "vehicle.treePlanter#saplingPalletMountNode", "Sapling pallet mount node")
    schema:register(XMLValueType.INT, "vehicle.treePlanter#fillUnitIndex", "Fill unit index")
    schema:register(XMLValueType.FLOAT, "vehicle.treePlanter#palletMountingRange", "Min. distance from saplingPalletGrabNode to pallet to mount it", 6)

    SoundManager.registerSampleXMLPaths(schema, "vehicle.treePlanter.sounds", "work")
    AnimationManager.registerAnimationNodesXMLPaths(schema, "vehicle.treePlanter.animationNodes")

    schema:setXMLSpecializationType()

    local schemaSavegame = Vehicle.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.VECTOR_TRANS, "vehicles.vehicle(?).treePlanter#lastTreePos", "Position of last tree")
    schemaSavegame:register(XMLValueType.BOOL, "vehicles.vehicle(?).treePlanter#palletHadBeenMounted", "Pallet is mounted")
end


---
function TreePlanter.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "removeMountedObject",       TreePlanter.removeMountedObject)
    SpecializationUtil.registerFunction(vehicleType, "setPlantLimitToField",      TreePlanter.setPlantLimitToField)
    SpecializationUtil.registerFunction(vehicleType, "createTree",                TreePlanter.createTree)
    SpecializationUtil.registerFunction(vehicleType, "loadPallet",                TreePlanter.loadPallet)
    SpecializationUtil.registerFunction(vehicleType, "palletTriggerCallback",     TreePlanter.palletTriggerCallback)
    SpecializationUtil.registerFunction(vehicleType, "onDeleteTreePlanterObject", TreePlanter.onDeleteTreePlanterObject)
    SpecializationUtil.registerFunction(vehicleType, "getCanPlantOutsideSeason",  TreePlanter.getCanPlantOutsideSeason)
end


---
function TreePlanter.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDirtMultiplier",                TreePlanter.getDirtMultiplier)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getWearMultiplier",                TreePlanter.getWearMultiplier)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsSpeedRotatingPartActive",     TreePlanter.getIsSpeedRotatingPartActive)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsWorkAreaActive",              TreePlanter.getIsWorkAreaActive)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit",                TreePlanter.doCheckSpeedLimit)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSelected",                 TreePlanter.getCanBeSelected)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsOnField",                     TreePlanter.getIsOnField)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addNodeObjectMapping",             TreePlanter.addNodeObjectMapping)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "removeNodeObjectMapping",          TreePlanter.removeNodeObjectMapping)

    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addFillUnitFillLevel",             TreePlanter.addFillUnitFillLevel)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillUnitFillLevel",             TreePlanter.getFillUnitFillLevel)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillUnitFillLevelPercentage",   TreePlanter.getFillUnitFillLevelPercentage)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillUnitFillType",              TreePlanter.getFillUnitFillType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillUnitCapacity",              TreePlanter.getFillUnitCapacity)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillUnitAllowsFillType",        TreePlanter.getFillUnitAllowsFillType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillUnitFreeCapacity",          TreePlanter.getFillUnitFreeCapacity)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getFillLevelInformation",          TreePlanter.getFillLevelInformation)
end


---
function TreePlanter.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", TreePlanter)
    SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", TreePlanter)
end


---Called on loading
-- @param table savegame savegame
function TreePlanter:onLoad(savegame)
    local spec = self.spec_treePlanter

    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.treePlanterSound", "vehicle.treePlanter.sounds.work") --FS17 to FS19
    XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.turnedOnRotationNodes.turnedOnRotationNode(0)", "vehicle.treePlanter.animationNodes.animationNode") --FS17 to FS19

    local baseKey = "vehicle.treePlanter"

    if self.isClient then
        spec.samples = {}
        spec.samples.work = g_soundManager:loadSampleFromXML(self.xmlFile, baseKey..".sounds", "work", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
        spec.isWorkSamplePlaying = false

        spec.animationNodes = g_animationManager:loadAnimations(self.xmlFile, baseKey..".animationNodes", self.components, self, self.i3dMappings)
    end

    spec.node = self.xmlFile:getValue( baseKey.."#node", nil, self.components, self.i3dMappings)
    spec.minDistance = self.xmlFile:getValue( baseKey.."#minDistance", 20) -- distance to next tree

    spec.palletTrigger = self.xmlFile:getValue( baseKey.."#palletTrigger", nil, self.components, self.i3dMappings)
    if spec.palletTrigger ~= nil then
        addTrigger(spec.palletTrigger, "palletTriggerCallback", self)
    else
        Logging.xmlWarning(self.xmlFile, "TreePlanter requires a palletTrigger!")
    end
    spec.palletsInTrigger = {}

    local refNodeIndex = self.xmlFile:getValue( baseKey.."#refNodeIndex", 1)
    spec.groundReferenceNode = self:getGroundReferenceNodeFromIndex(refNodeIndex)
    if spec.groundReferenceNode == nil then
        Logging.xmlWarning(self.xmlFile, "No groundReferenceNode specified or invalid groundReferenceNode index in '%s'",  baseKey.."#refNodeIndex")
    end

    spec.activatable = TreePlanterActivatable.new(self)

    spec.saplingPalletGrabNode = self.xmlFile:getValue(baseKey.."#saplingPalletGrabNode", self.rootNode, self.components, self.i3dMappings)
    spec.saplingPalletMountNode = self.xmlFile:getValue(baseKey.."#saplingPalletMountNode", self.rootNode, self.components, self.i3dMappings)
    spec.mountedSaplingPallet = nil

    spec.fillUnitIndex = self.xmlFile:getValue( baseKey.."#fillUnitIndex", 1)
    spec.nearestPalletDistance = self.xmlFile:getValue( baseKey.."#palletMountingRange", 6.0)

    spec.currentTree = 1
    spec.lastTreePos = nil

    spec.showFieldNotOwnedWarning = false
    spec.showRestrictedZoneWarning = false
    spec.showTooManyTreesWarning = false
    spec.hasGroundContact = false
    spec.showWrongPlantingTimeWarning = false

    spec.limitToField = true
    spec.forceLimitToField = false

    -- attributes for AI
    if self.addAIGroundTypeRequirements ~= nil then
        self:addAIGroundTypeRequirements(TreePlanter.AI_REQUIRED_GROUND_TYPES)

        if self.setAIFruitProhibitions ~= nil then
            self:setAIFruitProhibitions(FruitType.POPLAR, 1, 5)
        end
    end

    spec.dirtyFlag = self:getNextDirtyFlag()

    if savegame ~= nil and not savegame.resetVehicles then
        spec.lastTreePos = savegame.xmlFile:getValue(savegame.key..".treePlanter#lastTreePos", nil, true)

        spec.palletHadBeenMounted = savegame.xmlFile:getValue(savegame.key .. ".treePlanter#palletHadBeenMounted")
    end
end


---Called on deleting
function TreePlanter:onDelete()
    local spec = self.spec_treePlanter

    g_soundManager:deleteSamples(spec.samples)
    g_animationManager:deleteAnimations(spec.animationNodes)

    if spec.activatable ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
    end

    if spec.mountedSaplingPallet ~= nil then
        spec.mountedSaplingPallet:unmount()
        spec.mountedSaplingPallet = nil
    end

    if spec.palletTrigger ~= nil then
        removeTrigger(spec.palletTrigger)
    end
end


---
function TreePlanter:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_treePlanter

    if spec.lastTreePos ~= nil then
        xmlFile:setValue(key.."#lastTreePos", unpack(spec.lastTreePos))
    end
    if spec.mountedSaplingPallet ~= nil then
        xmlFile:setValue(key.."#palletHadBeenMounted", true)
    end
end


---Remove mounted object
-- @param integer object object to remove
-- @param boolean isDeleting called on delete
function TreePlanter:removeMountedObject(object, isDeleting)
    local spec = self.spec_treePlanter

    if spec.mountedSaplingPallet == object then
        spec.mountedSaplingPallet:unmount()
        spec.mountedSaplingPallet = nil
    end
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function TreePlanter:onReadStream(streamId, connection)
    if streamReadBool(streamId) then
        local spec = self.spec_treePlanter
        spec.palletIdToMount = NetworkUtil.readNodeObjectId(streamId)
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function TreePlanter:onWriteStream(streamId, connection)
    local spec = self.spec_treePlanter
    streamWriteBool(streamId, spec.mountedSaplingPallet ~= nil)
    if spec.mountedSaplingPallet ~= nil then
        local palletId = NetworkUtil.getObjectId(spec.mountedSaplingPallet)
        NetworkUtil.writeNodeObjectId(streamId, palletId)
    end
end


---Called on on update
-- @param integer streamId stream ID
-- @param integer timestamp timestamp
-- @param table connection connection
function TreePlanter:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_treePlanter
        if streamReadBool(streamId) then
            spec.hasGroundContact = streamReadBool(streamId)
            spec.showFieldNotOwnedWarning = streamReadBool(streamId)
            spec.showRestrictedZoneWarning = streamReadBool(streamId)
        end
    end
end


---Called on on update
-- @param integer streamId stream ID
-- @param table connection connection
-- @param integer dirtyMask dirty mask
function TreePlanter:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_treePlanter
        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            streamWriteBool(streamId, spec.hasGroundContact)
            streamWriteBool(streamId, spec.showFieldNotOwnedWarning)
            streamWriteBool(streamId, spec.showRestrictedZoneWarning)
        end
    end
end


---Called on update
-- @param float dt time since last call in ms
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function TreePlanter:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_treePlanter

    if self.finishedFirstUpdate then
        local pallet
        if spec.palletIdToMount ~= nil then
            pallet = NetworkUtil.getObject(spec.palletIdToMount)
        elseif spec.palletHadBeenMounted then
            spec.palletHadBeenMounted = nil
            pallet = TreePlanter.getSaplingPalletInRange(self, spec.saplingPalletMountNode, spec.palletsInTrigger)
        end

        if pallet ~= nil then
            pallet:mount(self, spec.saplingPalletMountNode, 0,0,0, 0,0,0)
            spec.mountedSaplingPallet = pallet
            g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
            spec.palletIdToMount = nil
        end
    end

    if self.isClient then
        local nearestSaplingPallet = nil
        if spec.mountedSaplingPallet == nil then
            nearestSaplingPallet = TreePlanter.getSaplingPalletInRange(self, spec.saplingPalletGrabNode, spec.palletsInTrigger)
        end

        if spec.nearestSaplingPallet ~= nearestSaplingPallet then
            spec.nearestSaplingPallet = nearestSaplingPallet

            if nearestSaplingPallet ~= nil then
                g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
            else
                g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
            end
        end
    end

    if spec.mountedSaplingPallet ~= nil then
        if spec.mountedSaplingPallet.isDeleted then
            spec.palletsInTrigger[spec.mountedSaplingPallet] = nil
            spec.mountedSaplingPallet = nil
        else
            spec.mountedSaplingPallet:raiseActive()
        end
    end
end


---Called on update tick
-- @param float dt time since last call in ms
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function TreePlanter:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_treePlanter

    spec.showTooManyTreesWarning = false
    local showFieldNotOwnedWarning = false
    local showRestrictedZoneWarning = false

    if self.isServer then
        local hasGroundContact = false
         if spec.groundReferenceNode ~= nil then
            hasGroundContact = self:getIsGroundReferenceNodeActive(spec.groundReferenceNode)
        end

        if spec.hasGroundContact ~= hasGroundContact then
            self:raiseDirtyFlags(spec.dirtyFlag)
            spec.hasGroundContact = hasGroundContact
        end
    end

    if self:getIsAIActive() then
        if not g_currentMission.missionInfo.helperBuySeeds then
            if spec.mountedSaplingPallet == nil then
                local rootVehicle = self.rootVehicle
                rootVehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
            end
        end
    end

    spec.showWrongPlantingTimeWarning = false

    if spec.hasGroundContact then
        if self:getIsTurnedOn() then
            local isPlantingSeason = true
            if not self:getCanPlantOutsideSeason() then
                local fillType = self:getFillUnitFillType(spec.fillUnitIndex)

                local fruitType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(fillType)
                isPlantingSeason = fruitType == nil or g_currentMission.growthSystem:canFruitBePlanted(fruitType)
            end
            spec.showWrongPlantingTimeWarning = not isPlantingSeason

            if self.isServer and isPlantingSeason then
                local fillLevel = self:getFillUnitFillLevel(spec.fillUnitIndex)
                local fillType = self:getFillUnitFillType(spec.fillUnitIndex)

                if g_currentMission.missionInfo.helperBuySeeds then
                    if self:getIsAIActive() then
                        if spec.mountedSaplingPallet ~= nil then
                            fillType = spec.mountedSaplingPallet:getFillUnitFillType(1)
                        else
                            fillType = FillType.POPLAR
                        end
                    end
                end

                if fillLevel == 0 and (not self:getIsAIActive() or not g_currentMission.missionInfo.helperBuySeeds) then
                    fillType = FillType.UNKNOWN
                end

                if fillType == FillType.TREESAPLINGS then
                    if self:getLastSpeed() > 1 then
                        local x,y,z = getWorldTranslation(spec.node)
                        if g_currentMission.accessHandler:canFarmAccessLand(self:getActiveFarm(), x, z) then
                            if not PlacementUtil.isInsideRestrictedZone(g_currentMission.restrictedZones, x, y, z, true) then
                                if spec.lastTreePos ~= nil then
                                    local distance = MathUtil.vector3Length(x-spec.lastTreePos[1], y-spec.lastTreePos[2], z-spec.lastTreePos[3])
                                    if distance > spec.minDistance then
                                        self:createTree()
                                    end
                                else
                                    self:createTree()
                                end
                            else
                                showRestrictedZoneWarning = true
                            end
                        else
                            showFieldNotOwnedWarning = true
                        end
                    end
                elseif fillType ~= FillType.UNKNOWN then
                    local x,_,z = getWorldTranslation(spec.node)
                    if g_currentMission.accessHandler:canFarmAccessLand(self:getActiveFarm(), x, z) then
                        local width = math.sqrt( g_currentMission:getFruitPixelsToSqm() ) * 0.5

                        local sx,_,sz = localToWorld(spec.node, -width,0,width)
                        local wx,_,wz = localToWorld(spec.node,  width,0,width)
                        local hx,_,hz = localToWorld(spec.node, -width,0,3*width)

                        local fruitType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(fillType)
                        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitType)

                        local dx,_,dz = localDirectionToWorld(spec.node, 0, 0, 1)
                        local angleRad = MathUtil.getYRotationFromDirection(dx, dz)
                        if fruitDesc ~= nil and fruitDesc.directionSnapAngle ~= 0 then
                            angleRad = math.floor(angleRad / fruitDesc.directionSnapAngle + 0.5) * fruitDesc.directionSnapAngle
                        end
                        local angle = FSDensityMapUtil.convertToDensityMapAngle(angleRad, g_currentMission.fieldGroundSystem:getGroundAngleMaxValue())

                        -- cultivate
                        local limitToField = spec.limitToField or spec.forceLimitToField
                        local limitFruitDestructionToField = spec.limitToField or spec.forceLimitToField
                        FSDensityMapUtil.updateCultivatorArea(sx,sz, wx,wz, hx,hz, not limitToField, limitFruitDestructionToField, angle, nil)
                        FSDensityMapUtil.eraseTireTrack(sx,sz, wx,wz, hx,hz)

                        -- plant, shift area
                        sx,_,sz = localToWorld(spec.node, -width,0,-3*width)
                        wx,_,wz = localToWorld(spec.node,  width,0,-3*width)
                        hx,_,hz = localToWorld(spec.node, -width,0,-width)

                        local sowingValue = g_currentMission.fieldGroundSystem:getFieldGroundValue(FieldGroundType.SOWN)
                        local area, _ = FSDensityMapUtil.updateSowingArea(fruitType, sx,sz, wx,wz, hx,hz, sowingValue, angle, 2)

                        local usage = fruitDesc.seedUsagePerSqm * area

                        local stats = g_farmManager:getFarmById(self:getActiveFarm()).stats
                        if self:getIsAIActive() and g_currentMission.missionInfo.helperBuySeeds then
                            local price = usage * g_currentMission.economyManager:getCostPerLiter(FillType.SEEDS, false) * 1.5  -- increase price if AI is active to reward the player's manual work
                            stats:updateStats("expenses", price)
                            g_currentMission:addMoney(-price, self:getActiveFarm(), MoneyType.PURCHASE_SEEDS)
                        else
                            self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, -usage, fillType, ToolType.UNDEFINED)
                        end

                        local lastHa = MathUtil.areaToHa(area, g_currentMission:getFruitPixelsToSqm())
                        stats:updateStats("seedUsage", usage)
                        stats:updateStats("sownHectares", lastHa)
                        stats:updateStats("sownTime", dt/(1000*60))

                        self:updateLastWorkedArea(area)
                    else
                        showFieldNotOwnedWarning = true
                    end
                end
            end
        end
    end

    if self.isServer then
        if spec.showFieldNotOwnedWarning ~= showFieldNotOwnedWarning or spec.showRestrictedZoneWarning ~= showRestrictedZoneWarning then
            spec.showFieldNotOwnedWarning = showFieldNotOwnedWarning
            spec.showRestrictedZoneWarning = showRestrictedZoneWarning
            self:raiseDirtyFlags(spec.dirtyFlag)
        end
    end

    if self.isClient then
        if self:getIsTurnedOn() and spec.hasGroundContact and self:getLastSpeed() > 1 then
            if not spec.isWorkSamplePlaying then
                g_soundManager:playSample(spec.samples.work)
                spec.isWorkSamplePlaying = true
            end
        else
            if spec.isWorkSamplePlaying then
                g_soundManager:stopSample(spec.samples.work)
                spec.isWorkSamplePlaying = false
            end
        end

        local actionEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA3]
        if actionEvent ~= nil then
            local showAction = false

            if isActiveForInputIgnoreSelection then
                local fillType = self:getFillUnitFillType(spec.fillUnitIndex)
                if fillType ~= FillType.UNKNOWN and fillType ~= FillType.TREESAPLINGS then
                    if g_currentMission:getHasPlayerPermission("createFields", self:getOwner()) then
                        if not spec.forceLimitToField then
                            showAction = true
                        end
                    end
                end

                if showAction then
                    if spec.limitToField then
                        g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("action_allowCreateFields"))
                    else
                        g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("action_limitToFields"))
                    end
                end
            end

            g_inputBinding:setActionEventActive(actionEvent.actionEventId, showAction)
        end
    end
end


---Called on draw
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function TreePlanter:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_treePlanter

    if isActiveForInputIgnoreSelection then
        if self:getFillUnitFillLevel(spec.fillUnitIndex) <= 0 then
            g_currentMission:addExtraPrintText(g_i18n:getText("info_firstFillTheTool"))
        end
    end

    if spec.showFieldNotOwnedWarning then
        g_currentMission:showBlinkingWarning(g_i18n:getText("warning_youDontHaveAccessToThisLand"))
    end

    if spec.showRestrictedZoneWarning then
        g_currentMission:showBlinkingWarning(g_i18n:getText("warning_actionNotAllowedHere"))
    end

    if spec.showTooManyTreesWarning then
        g_currentMission:showBlinkingWarning(g_i18n:getText("warning_tooManyTrees"))
    end

    if spec.showWrongPlantingTimeWarning then
        g_currentMission:showBlinkingWarning(string.format(g_i18n:getText("warning_theSelectedFruitTypeCantBePlantedInThisPeriod"), g_i18n:formatPeriod()), 100)
    end
end


---Called on turn off
-- @param boolean noEventSend no event send
function TreePlanter:onTurnedOn()
    if self.isClient then
        local spec = self.spec_treePlanter
        g_animationManager:startAnimations(spec.animationNodes)
    end
end


---Called on turn off
-- @param boolean noEventSend no event send
function TreePlanter:onTurnedOff()
    if self.isClient then
        local spec = self.spec_treePlanter
        g_animationManager:stopAnimations(spec.animationNodes)
        g_soundManager:stopSamples(spec.samples)
        spec.isWorkSamplePlaying = false
    end
end


---
function TreePlanter:addFillUnitFillLevel(superFunc, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)
    local spec = self.spec_treePlanter
    if fillUnitIndex == spec.fillUnitIndex then
        local pallet = spec.mountedSaplingPallet
        if pallet ~= nil then
            local fillUnits = pallet:getFillUnits()
            for palletFillUnitIndex, _ in pairs(fillUnits) do
                if pallet:getFillUnitFillType(fillUnitIndex) == fillTypeIndex then
                    return pallet:addFillUnitFillLevel(self:getOwnerFarmId(), palletFillUnitIndex, fillLevelDelta, fillTypeIndex, ToolType.UNDEFINED)
                end
            end
        end
    end

    return superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData)
end


---
function TreePlanter:getFillUnitFillLevel(superFunc, fillUnitIndex)
    local spec = self.spec_treePlanter
    if fillUnitIndex == spec.fillUnitIndex then
        local pallet = spec.mountedSaplingPallet
        if pallet ~= nil then
            local fillLevel = 0
            local fillUnits = pallet:getFillUnits()
            for palletFillUnitIndex, _ in pairs(fillUnits) do
                fillLevel = fillLevel + pallet:getFillUnitFillLevel(palletFillUnitIndex)
            end

            return fillLevel
        end
    end

    return superFunc(self, fillUnitIndex)
end


---
function TreePlanter:getFillUnitFillLevelPercentage(superFunc, fillUnitIndex)
    local spec = self.spec_treePlanter
    if fillUnitIndex == spec.fillUnitIndex then
        local pallet = spec.mountedSaplingPallet
        if pallet ~= nil then
            local capacity = self:getFillUnitCapacity(fillUnitIndex)
            local fillLevel = self:getFillUnitFillLevel(fillUnitIndex)
            if capacity > 0 then
                return fillLevel / capacity
            end
        end
    end

    return superFunc(self, fillUnitIndex)
end


---
function TreePlanter:getFillUnitFillType(superFunc, fillUnitIndex)
    local spec = self.spec_treePlanter
    if fillUnitIndex == spec.fillUnitIndex then
        local pallet = spec.mountedSaplingPallet
        if pallet ~= nil then
            local fillUnits = pallet:getFillUnits()
            for palletFillUnitIndex, _ in pairs(fillUnits) do
                if pallet:getFillUnitFillLevel(palletFillUnitIndex) > 0 then
                    return pallet:getFillUnitFillType(palletFillUnitIndex)
                end
            end
        end
    end

    return superFunc(self, fillUnitIndex)
end


---
function TreePlanter:getFillUnitCapacity(superFunc, fillUnitIndex)
    local spec = self.spec_treePlanter
    if fillUnitIndex == spec.fillUnitIndex then
        local pallet = spec.mountedSaplingPallet
        if pallet ~= nil then
            local capacity = 0
            local fillUnits = pallet:getFillUnits()
            for palletFillUnitIndex, _ in pairs(fillUnits) do
                capacity = capacity + pallet:getFillUnitCapacity(palletFillUnitIndex)
            end

            return capacity
        end
    end

    return superFunc(self, fillUnitIndex)
end


---
function TreePlanter:getFillUnitAllowsFillType(superFunc, fillUnitIndex, fillType)
    local spec = self.spec_treePlanter
    if fillUnitIndex == spec.fillUnitIndex then
        local pallet = spec.mountedSaplingPallet
        if pallet ~= nil then
            return false
        end
    end

    return superFunc(self, fillUnitIndex, fillType)
end


---
function TreePlanter:getFillUnitFreeCapacity(superFunc, fillUnitIndex, fillTypeIndex, farmId)
    local spec = self.spec_treePlanter
    if fillUnitIndex == spec.fillUnitIndex then
        local pallet = spec.mountedSaplingPallet
        if pallet ~= nil then
            return 0
        end
    end

    return superFunc(self, fillUnitIndex, fillTypeIndex, farmId)
end


---
function TreePlanter:getFillLevelInformation(superFunc, display)
    local spec = self.spec_treePlanter
    local pallet = spec.mountedSaplingPallet

    if pallet ~= nil then
        local capacity = self:getFillUnitCapacity(spec.fillUnitIndex)
        local fillLevel = self:getFillUnitFillLevel(spec.fillUnitIndex)
        local fillType = self:getFillUnitFillType(spec.fillUnitIndex)

        display:addFillLevel(fillType, fillLevel, capacity)
    end

    superFunc(self, display)
end


---
function TreePlanter:getCanPlantOutsideSeason()
    return false
end


---Set plant limit to field state
-- @param boolean plantLimitToField plant limit to field state
-- @param boolean noEventSend no event send
function TreePlanter:setPlantLimitToField(plantLimitToField, noEventSend)
    local spec = self.spec_treePlanter

    if spec.limitToField ~= plantLimitToField then
        spec.limitToField = plantLimitToField

        PlantLimitToFieldEvent.sendEvent(self, plantLimitToField, noEventSend)
    end
end


---Create tree on current position
function TreePlanter:createTree()
    local spec = self.spec_treePlanter

    if not g_treePlantManager:canPlantTree() then
        spec.showTooManyTreesWarning = true
        return
    end

    if self.isServer and spec.mountedSaplingPallet ~= nil then
        local pallet = spec.mountedSaplingPallet
        local x, y, z = getWorldTranslation(spec.node)
        local yRot = math.random() * 2*math.pi

        local fillType = pallet:getFillUnitFillType(1)
        local treeTypeIndex = 1
        if fillType == FillType.TREESAPLINGS then
            local treeTypeName = pallet:getTreeType()
            if treeTypeName ~= nil then
                local desc = g_treePlantManager:getTreeTypeDescFromName(treeTypeName)
                if desc ~= nil then
                    treeTypeIndex = desc.index
                end
            end
        end

        g_treePlantManager:plantTree(treeTypeIndex, x, y, z, 0, yRot, 0, 0)
        spec.lastTreePos = {x,y,z}

        local stats = g_farmManager:getFarmById(self:getActiveFarm()).stats

        if g_currentMission.missionInfo.helperBuySeeds and self:getIsAIActive() then
            local storeItem = g_storeManager:getItemByXMLFilename(pallet.configFileName)
            local pricePerSapling = 1.5 * (storeItem.price / pallet:getFillUnitCapacity(1))

            stats:updateStats("expenses", pricePerSapling)
            g_currentMission:addMoney(-pricePerSapling, self:getActiveFarm(), MoneyType.PURCHASE_SEEDS)
        else
            -- use 0.9999 instead of 1 to compansate float precision on mp sync
            local fillLevelChange = -0.9999
            if self:getFillUnitFillLevel(spec.fillUnitIndex) < 1.5 then
                fillLevelChange = -math.huge
            end

            self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, fillLevelChange, self:getFillUnitFillType(spec.fillUnitIndex), ToolType.UNDEFINED)
        end

        -- increase tree plant counter for achievements
        stats:updateStats("plantedTreeCount", 1)
    end
end


---Called on loading
-- @param table savegame savegame
function TreePlanter:loadPallet(palletObjectId, noEventSend)
    local spec = self.spec_treePlanter

    TreePlanterLoadPalletEvent.sendEvent(self, palletObjectId, noEventSend)

    spec.palletIdToMount = palletObjectId
end


---Returns current dirt multiplier
-- @return float dirtMultiplier current dirt multiplier
function TreePlanter:getDirtMultiplier(superFunc)
    local multiplier = superFunc(self)

    local spec = self.spec_treePlanter
    if spec.hasGroundContact then
        multiplier = multiplier + self:getWorkDirtMultiplier() * self:getLastSpeed() / self.speedLimit
    end

    return multiplier
end


---Returns current wear multiplier
-- @return float dirtMultiplier current wear multiplier
function TreePlanter:getWearMultiplier(superFunc)
    local multiplier = superFunc(self)

    local spec = self.spec_treePlanter
    if spec.hasGroundContact then
        multiplier = multiplier + self:getWorkWearMultiplier() * self:getLastSpeed() / self.speedLimit
    end

    return multiplier
end


---Returns true if speed rotating part is active
-- @param table speedRotatingPart speedRotatingPart
-- @return boolean isActive speed rotating part is active
function TreePlanter:getIsSpeedRotatingPartActive(superFunc, speedRotatingPart)
    local spec = self.spec_treePlanter

    if not spec.hasGroundContact then
        return false
    end

    return superFunc(self, speedRotatingPart)
end


---
function TreePlanter:getIsWorkAreaActive(superFunc, workArea)
    local spec = self.spec_treePlanter

    local isActive = superFunc(self, workArea)
    if workArea.groundReferenceNode == spec.groundReferenceNode then
        if not self:getIsTurnedOn() then
            isActive = false
        end
    end

    return isActive
end


---Returns if speed limit should be checked
-- @return boolean checkSpeedlimit check speed limit
function TreePlanter:doCheckSpeedLimit(superFunc)
    return superFunc(self) or (self:getIsTurnedOn() and self:getIsImplementChainLowered())
end


---
function TreePlanter:getCanBeSelected(superFunc)
    return true
end


---
function TreePlanter:onDeleteTreePlanterObject(object)
    local spec = self.spec_treePlanter
    if spec.mountedSaplingPallet == object then
        spec.mountedSaplingPallet = nil
    end

    spec.palletsInTrigger[object] = nil
end


---
function TreePlanter:getIsOnField(superFunc)
    if superFunc(self) then
        return true
    end

    -- since we don't need to be on a field to work we check only for ground contract
    if self.spec_treePlanter.hasGroundContact then
        return true
    end

    return false
end


---
function TreePlanter:addNodeObjectMapping(superFunc, list)
    superFunc(self, list)

    local spec = self.spec_treePlanter
    if spec.palletTrigger ~= nil then
        list[spec.palletTrigger] = self
    end
end


---
function TreePlanter:removeNodeObjectMapping(superFunc, list)
    superFunc(self, list)

    local spec = self.spec_treePlanter
    if spec.palletTrigger ~= nil then
        list[spec.palletTrigger] = nil
    end
end


---
function TreePlanter:palletTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    local spec = self.spec_treePlanter

    if otherId ~= 0 then
        local object = g_currentMission:getNodeObject(otherId)
        if object ~= nil and object.isa ~= nil then
            if object:isa(Vehicle) then
                if object.isPallet and g_currentMission.accessHandler:canFarmAccess(self:getActiveFarm(), object) then
                    local currentValue = Utils.getNoNil(spec.palletsInTrigger[object], 0)

                    if onEnter then
                        spec.palletsInTrigger[object] = currentValue + 1

                        if currentValue == 0 and object.addDeleteListener ~= nil then
                            object:addDeleteListener(self, "onDeleteTreePlanterObject")
                        end
                    elseif onLeave then
                        spec.palletsInTrigger[object] = math.max(currentValue - 1, 0)
                    end

                    if spec.palletsInTrigger[object] == 0 then
                        spec.palletsInTrigger[object] = nil
                    end
                end
            end
        end
    end
end


---
function TreePlanter:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_treePlanter
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection and not spec.forceLimitToField then
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA3, self, TreePlanter.actionEventToggleTreePlanterFieldLimitation, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
        end
    end
end


---
function TreePlanter.actionEventToggleTreePlanterFieldLimitation(self, actionName, inputValue, callbackState, isAnalog)
    self:setPlantLimitToField(not self.spec_treePlanter.limitToField)
end


---Returns default speed limit
-- @return float speedLimit speed limit
function TreePlanter.getDefaultSpeedLimit()
    return 5
end


---Returns nearest sapling pallet in range
-- @param integer refNode id of reference node
-- @return table object object of sapling pallet
function TreePlanter.getSaplingPalletInRange(self, refNode, palletsInTrigger)
    local spec = self.spec_treePlanter

    local nearestDistance = spec.nearestPalletDistance
    local nearestSaplingPallet = nil

    for object, state in pairs(palletsInTrigger) do
        if state ~= nil and state > 0 then

            if object ~= spec.mountedSaplingPallet then

                local distance = calcDistanceFrom(refNode, object.rootNode)
                if distance < nearestDistance then
                    local validPallet = false

                    local fillUnits = object:getFillUnits()
                    for fillUnitIndex, _ in pairs(fillUnits) do
                        local filltype = object:getFillUnitFillType(fillUnitIndex)
                        if filltype ~= FillType.UNKNOWN then
                            if self:getFillUnitSupportsFillType(spec.fillUnitIndex, filltype) then
                                if object:getFillUnitFillLevel(fillUnitIndex) > 0 then
                                    validPallet = true
                                    break
                                end
                            end
                        end
                    end

                    if validPallet then
                        nearestSaplingPallet = object
                    end
                end

            end
        end
    end
    return nearestSaplingPallet
end
