---Specialization for tools with switchable work modes by providing grouping of different animations and work areas
















---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function WorkMode.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(WorkArea, specializations)
       and SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations)
end


---Called on specialization initializing
function WorkMode.initSpecialization()
    g_configurationManager:addConfigurationType("workMode", g_i18n:getText("configuration_workMode"), "workModes", nil, nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION)

    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("WorkMode")

    WorkMode.registerWorkModeXMLPaths(schema, "vehicle.workModes")
    WorkMode.registerWorkModeXMLPaths(schema, "vehicle.workModes.workModeConfigurations.workModeConfiguration(?)")

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, "vehicle.workModes.workModeConfigurations.workModeConfiguration(?)")

    schema:setXMLSpecializationType()

    local schemaSavegame = Vehicle.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?).workMode#state", "Current work mode", 1)
end



---Called on specialization initializing
function WorkMode.registerWorkModeXMLPaths(schema, basePath)
    schema:register(XMLValueType.FLOAT, basePath .. "#foldMaxLimit", "Fold max. limit to change mode", 1)
    schema:register(XMLValueType.FLOAT, basePath .. "#foldMinLimit", "Fold min. limit to change mode", 0)
    schema:register(XMLValueType.BOOL, basePath .. "#allowChangeOnLowered", "Allow change while lowered", true)
    schema:register(XMLValueType.BOOL, basePath .. "#allowChangeWhileTurnedOn", "Allow change while turned on", true)

    schema:register(XMLValueType.L10N_STRING, basePath .. ".workMode(?)#name", "Work mode name")
    schema:register(XMLValueType.STRING, basePath .. ".workMode(?)#inputBindingName", "Input action name for quick access")
    schema:register(XMLValueType.STRING, basePath .. ".workMode(?).turnedOnAnimations.turnedOnAnimation(?)#name", "Turned on animation name")
    schema:register(XMLValueType.FLOAT, basePath .. ".workMode(?).turnedOnAnimations.turnedOnAnimation(?)#turnOnFadeTime", "Turn on fade time (sec.)", 1)
    schema:register(XMLValueType.FLOAT, basePath .. ".workMode(?).turnedOnAnimations.turnedOnAnimation(?)#turnOffFadeTime", "Turn off fade time (sec.)", 1)
    schema:register(XMLValueType.FLOAT, basePath .. ".workMode(?).turnedOnAnimations.turnedOnAnimation(?)#speedScale", "Speed scale", 1)

    schema:register(XMLValueType.STRING, basePath .. ".workMode(?).loweringAnimations.loweringAnimation(?)#name", "Lowering animation name")
    schema:register(XMLValueType.FLOAT, basePath .. ".workMode(?).loweringAnimations.loweringAnimation(?)#speed", "Speed scale", 1)

    schema:register(XMLValueType.INT, basePath .. ".workMode(?).workAreas.workArea(?)#workAreaIndex", "Work area index")
    schema:register(XMLValueType.INT, basePath .. ".workMode(?).workAreas.workArea(?)#dropAreaIndex", "Drop area index")

    schema:register(XMLValueType.STRING, basePath .. ".workMode(?).animation(?)#name", "Mode change animation name")
    schema:register(XMLValueType.FLOAT, basePath .. ".workMode(?).animation(?)#speed", "Mode change animation speed", 1)
    schema:register(XMLValueType.FLOAT, basePath .. ".workMode(?).animation(?)#stopTime", "Mode change animation stop time")
    schema:register(XMLValueType.BOOL, basePath .. ".workMode(?).animation(?)#repeatAfterUnfolding", "Repeat animation after unfolding", false)
    schema:register(XMLValueType.FLOAT, basePath .. ".workMode(?).animation(?)#repeatStartTime", "Repeat start time")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".workMode(?).movingToolLimit#node", "Target moving tool node")
    schema:register(XMLValueType.ANGLE, basePath .. ".workMode(?).movingToolLimit#minRot", "Min. rotation", 0)
    schema:register(XMLValueType.ANGLE, basePath .. ".workMode(?).movingToolLimit#maxRot", "Max. rotation", 0)

    EffectManager.registerEffectXMLPaths(schema, basePath .. ".workMode(?).windrowerEffect")
    AnimationManager.registerAnimationNodesXMLPaths(schema, basePath .. ".workMode(?).animationNodes")

    schema:register(XMLValueType.INT, Sprayer.SPRAY_TYPE_XML_KEY .. "#workModeIndex", "Index of work mode to activate spray type")
    schema:register(XMLValueType.BOOL, Cylindered.MOVING_TOOL_XML_KEY .. "#allowWhileChangingWorkMode", "Allow movement while changing work mode", true)
end


---
function WorkMode.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setWorkMode",                WorkMode.setWorkMode)
    SpecializationUtil.registerFunction(vehicleType, "getIsWorkModeChangeAllowed", WorkMode.getIsWorkModeChangeAllowed)
    SpecializationUtil.registerFunction(vehicleType, "deactivateWindrowerEffects", WorkMode.deactivateWindrowerEffects)
end


---
function WorkMode.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsWorkAreaActive",   WorkMode.getIsWorkAreaActive)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSelected",      WorkMode.getCanBeSelected)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAllowsLowering",     WorkMode.getAllowsLowering)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadSprayTypeFromXML",  WorkMode.loadSprayTypeFromXML)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsSprayTypeActive",  WorkMode.getIsSprayTypeActive)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadMovingToolFromXML", WorkMode.loadMovingToolFromXML)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsMovingToolActive", WorkMode.getIsMovingToolActive)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAreEffectsVisible",  WorkMode.getAreEffectsVisible)
end


---
function WorkMode.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onDeactivate", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onSetLowered", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", WorkMode)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", WorkMode)
end


---Called on loading
-- @param table savegame savegame
function WorkMode:onLoad(savegame)
    local spec = self.spec_workMode

    local baseKey = "vehicle.workModes"
    local configurationId = Utils.getNoNil(self.configurations["workMode"], 1)
    local configKey = string.format(baseKey .. ".workModeConfigurations.workModeConfiguration(%d)", configurationId -1)
    ObjectChangeUtil.updateObjectChanges(self.xmlFile, baseKey .. ".workModeConfigurations.workModeConfiguration", configurationId , self.components, self)

    if not self.xmlFile:hasProperty(configKey) then
        configKey = baseKey
    end

    spec.state = 1
    spec.stateMax = 0

    spec.foldMaxLimit = self.xmlFile:getValue(configKey .. "#foldMaxLimit", 1)
    spec.foldMinLimit = self.xmlFile:getValue(configKey .. "#foldMinLimit", 0)
    spec.allowChangeOnLowered = self.xmlFile:getValue(configKey .. "#allowChangeOnLowered", true)
    spec.allowChangeWhileTurnedOn = self.xmlFile:getValue(configKey .. "#allowChangeWhileTurnedOn", true)

    spec.workModes = {}
    local i = 0
    while true do
        local key = string.format("%s.workMode(%d)", configKey, i)
        if not self.xmlFile:hasProperty(key) then
            break
        end

        local entry = {}
        entry.name = self.xmlFile:getValue(key .. "#name", nil, self.customEnvironment)
        local inputBindingName = self.xmlFile:getValue(key .. "#inputBindingName")
        if inputBindingName ~= nil then
            if InputAction[inputBindingName] ~= nil then
                entry.inputAction = InputAction[inputBindingName]
            end
        end

        entry.turnedOnAnimations = {}
        local j = 0
        while true do
            local key2 = string.format("%s.turnedOnAnimations.turnedOnAnimation(%d)", key, j)
            if not self.xmlFile:hasProperty(key2) then
                break
            end

            local turnedOnAnimation = {}
            turnedOnAnimation.name = self.xmlFile:getValue(key2.."#name")
            turnedOnAnimation.turnOnFadeTime = self.xmlFile:getValue(key2.."#turnOnFadeTime", 1) * 1000
            turnedOnAnimation.turnOffFadeTime = self.xmlFile:getValue(key2.."#turnOffFadeTime", 1) * 1000
            turnedOnAnimation.speedScale = self.xmlFile:getValue(key2.."#speedScale", 1)

            turnedOnAnimation.speedDirection = 0
            turnedOnAnimation.currentSpeed = 0

            if self:getAnimationExists(turnedOnAnimation.name) then
                table.insert(entry.turnedOnAnimations, turnedOnAnimation)
            end

            j = j + 1
        end

        entry.loweringAnimations = {}
        j = 0
        while true do
            local key2 = string.format("%s.loweringAnimations.loweringAnimation(%d)", key, j)
            if not self.xmlFile:hasProperty(key2) then
                break
            end

            local loweringAnimation = {}
            loweringAnimation.name = self.xmlFile:getValue(key2.."#name")
            loweringAnimation.speed = self.xmlFile:getValue(key2.."#speed", 1)

            if self:getAnimationExists(loweringAnimation.name) then
                table.insert(entry.loweringAnimations, loweringAnimation)
            end

            j = j + 1
        end

        entry.workAreas = {}
        j = 0
        while true do
            local key2 = string.format("%s.workAreas.workArea(%d)", key, j)
            if not self.xmlFile:hasProperty(key2) then
                break
            end

            local workArea = {}
            workArea.workAreaIndex = self.xmlFile:getValue(key2.."#workAreaIndex", j+1)
            workArea.dropAreaIndex = self.xmlFile:getValue(key2.."#dropAreaIndex", j+1)

            table.insert(entry.workAreas, workArea)

            j = j + 1
        end

        entry.animations = {}
        j = 0
        while true do
            local animKey = string.format("%s.animation(%d)", key, j)
            if not self.xmlFile:hasProperty(animKey) then
                break
            end

            local animation = {}
            animation.animName = self.xmlFile:getValue(animKey .. "#name")
            animation.animSpeed = self.xmlFile:getValue(animKey .. "#speed", 1.0)
            animation.stopTime = self.xmlFile:getValue(animKey .. "#stopTime")
            animation.repeatAfterUnfolding = self.xmlFile:getValue(animKey .. "#repeatAfterUnfolding", false)
            animation.repeatStartTime = self.xmlFile:getValue(animKey .. "#repeatStartTime")
            animation.repeated = false

            if self:getAnimationExists(animation.animName) then
                table.insert(entry.animations, animation)
            end

            j = j + 1
        end

        local movingToolLimitNode = self.xmlFile:getValue(key .. ".movingToolLimit#node", nil, self.components, self.i3dMappings)
        if movingToolLimitNode ~= nil then
            entry.movingTool = self:getMovingToolByNode(movingToolLimitNode)
            entry.movingToolMinRot = self.xmlFile:getValue(key .. ".movingToolLimit#minRot", 0)
            entry.movingToolMaxRot = self.xmlFile:getValue(key .. ".movingToolLimit#maxRot", 0)
        end

        entry.windrowerEffects = g_effectManager:loadEffect(self.xmlFile, string.format("%s.windrowerEffect", key), self.components, self, self.i3dMappings)
        entry.animationNodes = g_animationManager:loadAnimations(self.xmlFile, key..".animationNodes", self.components, self, self.i3dMappings)

        table.insert(spec.workModes, entry)
        i = i + 1
    end

    spec.stateMax = table.getn(spec.workModes)
    if spec.stateMax > ((2^WorkMode.WORKMODE_SEND_NUM_BITS) - 1) then
        print("Error: WorkMode only supports "..((2^WorkMode.WORKMODE_SEND_NUM_BITS) - 1).." modes!")
    end

    if spec.stateMax > 0 then
        self:setWorkMode(1, true)
    end

    spec.accumulatedFruitType = FruitType.UNKNOWN
    spec.dirtyFlag = self:getNextDirtyFlag()

    if spec.stateMax == 0 then
        SpecializationUtil.removeEventListener(self, "onReadStream", WorkMode)
        SpecializationUtil.removeEventListener(self, "onWriteStream", WorkMode)
        SpecializationUtil.removeEventListener(self, "onReadUpdateStream", WorkMode)
        SpecializationUtil.removeEventListener(self, "onWriteUpdateStream", WorkMode)
        SpecializationUtil.removeEventListener(self, "onUpdate", WorkMode)
        SpecializationUtil.removeEventListener(self, "onUpdateTick", WorkMode)
        SpecializationUtil.removeEventListener(self, "onDraw", WorkMode)
        SpecializationUtil.removeEventListener(self, "onTurnedOn", WorkMode)
        SpecializationUtil.removeEventListener(self, "onTurnedOff", WorkMode)
        SpecializationUtil.removeEventListener(self, "onDeactivate", WorkMode)
        SpecializationUtil.removeEventListener(self, "onSetLowered", WorkMode)
        SpecializationUtil.removeEventListener(self, "onFoldStateChanged", WorkMode)
        SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", WorkMode)
    end
end


---
function WorkMode:onPostLoad(savegame)
    if savegame ~= nil and not savegame.resetVehicles then
        local spec = self.spec_workMode
        if spec.stateMax > 0 then
            if savegame.xmlFile:hasProperty(savegame.key..".workMode#state") then
                local workMode = savegame.xmlFile:getValue(savegame.key..".workMode#state", 1)
                workMode = MathUtil.clamp(workMode, 1, spec.stateMax)

                self:setWorkMode(workMode, true)
                AnimatedVehicle.updateAnimations(self, 99999999, true)

                if self.getFoldAnimTime ~= nil then
                    if self.spec_foldable.foldMoveDirection == 0 then
                        if self:getFoldAnimTime() <= 0 then
                            self.spec_foldable.foldMoveDirection = -1
                        else
                            self.spec_foldable.foldMoveDirection = 1
                        end
                    end
                end
            end
        end
    end
end


---
function WorkMode:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_workMode

    xmlFile:setValue(key.."#state", spec.state)
end


---
function WorkMode:onDelete()
    local spec = self.spec_workMode
    if spec.workModes ~= nil then
        for _, mode in ipairs(spec.workModes) do
            g_effectManager:deleteEffects(mode.windrowerEffects)
            g_animationManager:deleteAnimations(mode.animationNodes)
        end
    end
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function WorkMode:onReadStream(streamId, connection)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    local state = streamReadUIntN(streamId, WorkMode.WORKMODE_SEND_NUM_BITS)
    self:setWorkMode(state, true)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function WorkMode:onWriteStream(streamId, connection)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    streamWriteUIntN(streamId, spec.state, WorkMode.WORKMODE_SEND_NUM_BITS)
end


---Called on on update
-- @param integer streamId stream ID
-- @param integer timestamp timestamp
-- @param table connection connection
function WorkMode:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        if streamReadBool(streamId) then
            local spec = self.spec_workMode

            local mode = spec.workModes[spec.state]
            for _, effect in ipairs(mode.windrowerEffects) do
                if streamReadBool(streamId) then
                    effect.lastChargeTime = g_currentMission.time
                end
            end

            spec.accumulatedFruitType = streamReadUIntN(streamId, FruitTypeManager.SEND_NUM_BITS)
        end
    end
end


---Called on on update
-- @param integer streamId stream ID
-- @param table connection connection
-- @param integer dirtyMask dirty mask
function WorkMode:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_workMode
        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            local mode = spec.workModes[spec.state]

            for _, effect in ipairs(mode.windrowerEffects) do
                streamWriteBool(streamId, effect.lastChargeTime + 500 > g_currentMission.time)
            end

            streamWriteUIntN(streamId, spec.accumulatedFruitType, FruitTypeManager.SEND_NUM_BITS)
        end
    end
end


---Called on update
-- @param float dt time since last call in ms
function WorkMode:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    if self.isClient then
        local mode = spec.workModes[spec.state]

        for i=1, #spec.workModes do
            for _, turnedOnAnimation in pairs(spec.workModes[i].turnedOnAnimations) do
                if turnedOnAnimation.speedDirection ~= 0 then
                    local duration = turnedOnAnimation.turnOnFadeTime
                    if turnedOnAnimation.speedDirection == -1 then
                        duration = turnedOnAnimation.turnOffFadeTime
                    end
                    local min, max = 0, 1
                    if turnedOnAnimation.speedDirection == 1 then
                        min, max = -1, 1
                    end

                    turnedOnAnimation.currentSpeed = MathUtil.clamp(turnedOnAnimation.currentSpeed + turnedOnAnimation.speedDirection * dt/duration, min, max)

                    if not self:getIsAnimationPlaying(turnedOnAnimation.name) then
                        self:playAnimation(turnedOnAnimation.name, turnedOnAnimation.currentSpeed*turnedOnAnimation.speedScale, self:getAnimationTime(turnedOnAnimation.name), true)
                    else
                        self:setAnimationSpeed(turnedOnAnimation.name, turnedOnAnimation.currentSpeed*turnedOnAnimation.speedScale)
                    end

                    if turnedOnAnimation.speedDirection == -1 and turnedOnAnimation.currentSpeed == 0 then
                        self:stopAnimation(turnedOnAnimation.name, true)
                    end

                    if turnedOnAnimation.currentSpeed == 1 or turnedOnAnimation.currentSpeed == 0 then
                        turnedOnAnimation.speedDirection = 0
                    end
                end
            end
        end

        for _, effect in pairs(mode.windrowerEffects) do
            if effect.lastChargeTime + 500 > g_currentMission.time then
                local fillType = g_fruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(spec.accumulatedFruitType)
                if fillType ~= nil then
                    effect:setFillType(fillType)
                    if not effect:isRunning() then
                        g_effectManager:startEffect(effect)
                    end
                end
            else
                if effect.turnOffRequiredEffect == 0 or (effect.turnOffRequiredEffect ~= 0 and not mode.windrowerEffects[effect.turnOffRequiredEffect]:isRunning()) then
                    g_effectManager:stopEffect(effect)
                end
            end
        end
    end

    if self.isServer then
        local mode = spec.workModes[spec.state]

        local fruitType
        local workAreaCharge
        for _, area in ipairs(mode.workAreas) do
            local workArea = self.spec_workArea.workAreas[area.workAreaIndex]
            if workArea ~= nil then
                if workArea.lastValidPickupFruitType ~= FruitType.UNKNOWN then
                    fruitType = workArea.lastValidPickupFruitType
                end
                workAreaCharge = workAreaCharge or workArea.lastPickupLiters ~= 0
            end
        end

        if fruitType ~= nil then
            if fruitType ~= spec.accumulatedFruitType then
                spec.accumulatedFruitType = fruitType
                self:raiseDirtyFlags(spec.dirtyFlag)
            end
        end

        for _, effect in pairs(mode.windrowerEffects) do
            if workAreaCharge then
                effect.lastChargeTime = g_currentMission.time
                self:raiseDirtyFlags(spec.dirtyFlag)
            end
        end
    end
end


---
function WorkMode:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    if self.getFoldAnimTime ~= nil then
        local foldAnimTime = self:getFoldAnimTime()
        if foldAnimTime == 0 or foldAnimTime == self.spec_foldable.foldMiddleAnimTime then
            local mode = spec.workModes[spec.state]
            for _, anim in pairs(mode.animations) do
                if anim.repeatAfterUnfolding then
                    if not anim.repeated then
                        local curTime = self:getAnimationTime(anim.animName)
                        if anim.stopTime ~= nil then
                            self:setAnimationStopTime(anim.animName, anim.stopTime)
                            local speed = math.abs(anim.animSpeed)
                            if curTime > anim.stopTime then
                                speed = -math.abs(anim.animSpeed)
                            end
                            self:playAnimation(anim.animName, speed, Utils.getNoNil(anim.repeatStartTime, curTime), true)
                        else
                            self:playAnimation(anim.animName, anim.animSpeed, Utils.getNoNil(anim.repeatStartTime, curTime), true)
                        end

                        anim.repeated = true
                    end
                end
            end
        end

        if spec.playDelayedLoweringAnimation ~= nil then
            if foldAnimTime == 1 or foldAnimTime == 0 or foldAnimTime == self.spec_foldable.foldMiddleAnimTime then
                WorkMode.onSetLowered(self, spec.playDelayedLoweringAnimation)
                spec.playDelayedLoweringAnimation = nil
            end
        end
    end
end


---Called on draw
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function WorkMode:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    else
        local mode = spec.workModes[spec.state]
        g_currentMission:addExtraPrintText(string.format(g_i18n:getText("action_workModeSelected"), mode.name))

        local allowWorkModeChange = self:getIsWorkModeChangeAllowed()

        local actionEvent = spec.actionEvents[InputAction.TOGGLE_WORKMODE]
        if actionEvent ~= nil then
            g_inputBinding:setActionEventActive(actionEvent.actionEventId, allowWorkModeChange)
        end

        for _, workMode in ipairs(spec.workModes) do
            if workMode.inputAction ~= nil then
                actionEvent = spec.actionEvents[workMode.inputAction]
                if actionEvent ~= nil then
                    g_inputBinding:setActionEventActive(actionEvent.actionEventId, allowWorkModeChange)
                end
            end
        end
    end
end


---Called on deactivate
function WorkMode:onDeactivate()
    WorkMode.deactivateWindrowerEffects(self)
end


---Called on deactivate
function WorkMode:deactivateWindrowerEffects()
    if self.isClient then
        local spec = self.spec_workMode
        for _, mode in pairs(spec.workModes) do
            if mode.windrowerEffects ~= nil then
                g_effectManager:stopEffects(mode.windrowerEffects)
            end
        end
    end
end


---Change work mode
-- @param integer state new state
-- @param boolean noEventSend no event send
function WorkMode:setWorkMode(state, noEventSend)
    local spec = self.spec_workMode

    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetWorkModeEvent.new(self, state), nil, nil, self)
        else
            g_client:getServerConnection():sendEvent(SetWorkModeEvent.new(self, state))
        end
    end

    if state ~= spec.state then
        local currentMode = spec.workModes[spec.state]
        if currentMode.animations ~= nil then
            for _,anim in pairs(currentMode.animations) do
                local curTime = self:getAnimationTime(anim.animName)
                if anim.stopTime == nil then
                    self:playAnimation(anim.animName, -anim.animSpeed, curTime, noEventSend)
                end
            end
            g_animationManager:stopAnimations(currentMode.animationNodes)
        end

        local newMode = spec.workModes[state]
        if newMode.animations ~= nil then
            for _,anim in pairs(newMode.animations) do
                local curTime = self:getAnimationTime(anim.animName)
                if anim.stopTime ~= nil then
                    self:setAnimationStopTime(anim.animName, anim.stopTime)
                    local speed = math.abs(anim.animSpeed)
                    if curTime > anim.stopTime then
                        speed = -math.abs(anim.animSpeed)
                    end
                    self:playAnimation(anim.animName, speed, curTime, noEventSend)
                else
                    self:playAnimation(anim.animName, anim.animSpeed, curTime, noEventSend)
                end
            end
            if self:getIsTurnedOn() then
                g_animationManager:startAnimations(newMode.animationNodes)
            end
        end

        if self:getIsTurnedOn() then
            for _, turnedOnAnimation in pairs(newMode.turnedOnAnimations) do
                if self:getIsAnimationPlaying(turnedOnAnimation.name) then
                    for i=1, #spec.workModes do
                        local otherMode = spec.workModes[i]
                        if otherMode ~= newMode then
                            for j=1, #otherMode.turnedOnAnimations do
                                local otherAnimation = otherMode.turnedOnAnimations[j]
                                if otherAnimation.name == turnedOnAnimation.name then
                                    local animationSpeed = self.spec_animatedVehicle.animations[turnedOnAnimation.name].currentSpeed
                                    if animationSpeed ~= 0 then
                                        local alpha = animationSpeed / turnedOnAnimation.speedScale
                                        turnedOnAnimation.currentSpeed = alpha
                                        otherAnimation.currentSpeed = 0
                                        otherAnimation.speedDirection = 0
                                    end
                                end
                            end
                        end
                    end
                end

                turnedOnAnimation.speedDirection = 1
            end
        end

        for _, effect in pairs(currentMode.windrowerEffects) do
            g_effectManager:stopEffect(effect)
        end

        if newMode.movingTool ~= nil then
            local movingTool = newMode.movingTool
            if newMode.movingToolMinRot ~= nil then
                movingTool.rotMin = newMode.movingToolMinRot
            end

            if newMode.movingToolMaxRot ~= nil then
                movingTool.rotMax = newMode.movingToolMaxRot
            end

            if self.isClient then
                movingTool.networkInterpolators.rotation:setMinMax(movingTool.rotMin, movingTool.rotMax)
            end
        end
    end

    local workAreaSpec = self.spec_workArea
    if workAreaSpec ~= nil then
        local workAreas = workAreaSpec.workAreas
        for _, workArea in pairs(spec.workModes[state].workAreas) do
            local workAreaToSet = workAreas[workArea.workAreaIndex]
            if workAreaToSet ~= nil then
                workAreaToSet.dropWindrowWorkAreaIndex = workArea.dropAreaIndex -- windrower
                workAreaToSet.dropAreaIndex = workArea.dropAreaIndex -- mower
            end
        end
    end

    spec.state = state
end


---
function WorkMode:getIsWorkAreaActive(superFunc, workArea)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return superFunc(self, workArea)
    end

    for _, workArea2 in pairs(spec.workModes[spec.state].workAreas) do
        if workArea.index == workArea2.workAreaIndex then
            if workArea2.dropAreaIndex == 0 then
                return false
            end
        end
    end

    return superFunc(self, workArea)
end


---
function WorkMode:getCanBeSelected(superFunc)
    return true
end


---
function WorkMode:getAllowsLowering(superFunc)
    local allowLowering, warning = superFunc(self)

    local spec = self.spec_workMode
    local hasLoweringAnimations = false
    if #spec.workModes > 0 then
        hasLoweringAnimations = #spec.workModes[spec.state].loweringAnimations > 0
    end

    return allowLowering or hasLoweringAnimations, warning
end


---
function WorkMode:loadSprayTypeFromXML(superFunc, xmlFile, key, sprayType)
    sprayType.workModeIndex = self.xmlFile:getValue(key.. "#workModeIndex")

    return superFunc(self, xmlFile, key, sprayType)
end


---
function WorkMode:getIsSprayTypeActive(superFunc, sprayType)
    if sprayType.workModeIndex ~= nil then
        if self.spec_workMode.state ~= sprayType.workModeIndex then
            return false
        end
    end

    return superFunc(self, sprayType)
end


---
function WorkMode:loadMovingToolFromXML(superFunc, xmlFile, key, entry)
    if not superFunc(self, xmlFile, key, entry) then
        return false
    end

    entry.allowWhileChangingWorkMode = self.xmlFile:getValue(key.. "#allowWhileChangingWorkMode", true)

    return true
end


---
function WorkMode:getIsMovingToolActive(superFunc, movingTool)
    if not movingTool.allowWhileChangingWorkMode then
        local spec = self.spec_workMode
        for i=1, #spec.workModes do
            local workMode = spec.workModes[i]

            for j=1, #workMode.animations do
                if self:getIsAnimationPlaying(workMode.animations[j].animName) then
                    return false
                end
            end
        end
    end

    return superFunc(self, movingTool)
end


---
function WorkMode:getAreEffectsVisible(superFunc)
    if not superFunc(self) then
        return false
    end

    local spec = self.spec_workMode
    if spec.stateMax > 0 then
        for i=1, #spec.workModes do
            local workMode = spec.workModes[i]

            for j=1, #workMode.animations do
                if self:getIsAnimationPlaying(workMode.animations[j].animName) then
                    return false
                end
            end
        end
    end

    return true
end


---Returns if work mode change is allowed
-- @return boolean isAllowed is allowed
function WorkMode:getIsWorkModeChangeAllowed()
    local spec = self.spec_workMode

    if self.getFoldAnimTime ~= nil then
        if self:getFoldAnimTime() > spec.foldMaxLimit or self:getFoldAnimTime() < spec.foldMinLimit then
            return false
        end
    end

    if not spec.allowChangeOnLowered then
        local attacherVehicle = self:getAttacherVehicle()
        if attacherVehicle ~= nil then
            local index = attacherVehicle:getAttacherJointIndexFromObject(self)
            local attacherJoint = attacherVehicle:getAttacherJointByJointDescIndex(index)

            if attacherJoint.moveDown then
                return false
            end
        end
    end

    return true
end


---Called on turn off
-- @param boolean noEventSend no event send
function WorkMode:onTurnedOff()
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    if self.isClient then
        WorkMode.deactivateWindrowerEffects(self)
        local mode = spec.workModes[spec.state]

        for _, turnedOnAnimation in pairs(mode.turnedOnAnimations) do
            turnedOnAnimation.speedDirection = -1
        end
        g_animationManager:stopAnimations(mode.animationNodes)
    end
end


---Called on turn on
-- @param boolean noEventSend no event send
function WorkMode:onTurnedOn()
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    if self.isClient then
        local mode = spec.workModes[spec.state]

        for _, turnedOnAnimation in pairs(mode.turnedOnAnimations) do
            turnedOnAnimation.speedDirection = 1
        end

        g_animationManager:startAnimations(mode.animationNodes)
    end
end


---Called on change lowering state
-- @param boolean lowered attachable is lowered
function WorkMode:onSetLowered(lowered)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    if self.getFoldAnimTime ~= nil then
        local foldAnimTime = self:getFoldAnimTime()
        if foldAnimTime ~= 1 and foldAnimTime ~= 0 and foldAnimTime ~= self.foldMiddleAnimTime then
            spec.playDelayedLoweringAnimation = lowered
            return
        end
    end

    local mode = spec.workModes[spec.state]

    for _, loweringAnimation in pairs(mode.loweringAnimations) do
        if lowered then
            if self:getAnimationTime(loweringAnimation.name) < 1 then
                self:playAnimation(loweringAnimation.name, loweringAnimation.speed, nil, true)
            end
        else
            if self:getAnimationTime(loweringAnimation.name) > 0 then
                self:playAnimation(loweringAnimation.name, -loweringAnimation.speed, nil, true)
            end
        end
    end
end


---Called on fold state change
-- @param integer direction direction of folding
function WorkMode:onFoldStateChanged(direction, moveToMiddle)
    local spec = self.spec_workMode
    if spec.stateMax == 0 then
        return
    end

    if direction > 0 then
        local mode = spec.workModes[spec.state]

        for _, anim in pairs(mode.animations) do
            if anim.repeatAfterUnfolding then
                anim.repeated = false
            end
        end

        -- if the tool is still lowered while folding we lift it
        if self:getIsLowered() then
            if self.getAttacherVehicle ~= nil then
                local attacherVehicle = self:getAttacherVehicle()
                if attacherVehicle ~= nil then
                    attacherVehicle:handleLowerImplementEvent()
                end
            end
        end
    end
end


---
function WorkMode:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_workMode
        if spec.stateMax > 0 then
            self:clearActionEventsTable(spec.actionEvents)

            if isActiveForInputIgnoreSelection then
                local _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, InputAction.TOGGLE_WORKMODE, self, WorkMode.actionEventWorkModeChange, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

                for _, mode in ipairs(spec.workModes) do
                    if mode.inputAction ~= nil then
                        _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, mode.inputAction, self, WorkMode.actionEventWorkModeChangeDirect, false, true, false, true, nil)
                        g_inputBinding:setActionEventTextVisibility(actionEventId, false)
                    end
                end
            end
        end
    end
end


---
function WorkMode.actionEventWorkModeChange(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_workMode
    local state = spec.state + 1
    if state > spec.stateMax then
        state = 1
    end

    if state ~= spec.state then
        self:setWorkMode(state)
    end
end


---
function WorkMode.actionEventWorkModeChangeDirect(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_workMode

    for state, mode in ipairs(spec.workModes) do
        if mode.inputAction == InputAction[actionName] then
            if state ~= spec.state then
                self:setWorkMode(state)
            end
        end
    end
end
