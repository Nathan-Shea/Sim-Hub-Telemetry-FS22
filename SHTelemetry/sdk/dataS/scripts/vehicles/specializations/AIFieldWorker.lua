---Specialization for extending vehicles to by used by AI helpers


















































---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function AIFieldWorker.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIJobVehicle, specializations)
       and SpecializationUtil.hasSpecialization(Drivable, specializations)
end




























































































































---
function AIFieldWorker:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_aiFieldWorker
    xmlFile:setValue(key.."#lastTurnDirection", spec.lastTurnDirection)
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function AIFieldWorker:onReadStream(streamId, connection)
    if streamReadBool(streamId) then
        self:startFieldWorker()
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function AIFieldWorker:onWriteStream(streamId, connection)
    local spec = self.spec_aiFieldWorker
    streamWriteBool(streamId, spec.isActive)
end














































































---Updates the AI logic that is needed to be called at a regular frequency (by default every 2 frames)
Primarly this is wheel turning / motor logic
-- @param float dt time since last call in ms
function AIFieldWorker:updateAIFieldWorker(dt)
    local spec = self.spec_aiFieldWorker
    if spec.aiDriveParams.valid then
        local moveForwards = spec.aiDriveParams.moveForwards
        local tX = spec.aiDriveParams.tX
        local tY = spec.aiDriveParams.tY
        local tZ = spec.aiDriveParams.tZ
        local maxSpeed = spec.aiDriveParams.maxSpeed

        local pX, _, pZ = worldToLocal(self:getAISteeringNode(), tX,tY,tZ)
        if not moveForwards and self.spec_articulatedAxis ~= nil then
            if self.spec_articulatedAxis.aiRevereserNode ~= nil then
                pX, _, pZ = worldToLocal(self.spec_articulatedAxis.aiRevereserNode, tX,tY,tZ)
            end
        end

        if not moveForwards and self:getAIReverserNode() ~= nil then
            pX, _, pZ = worldToLocal(self:getAIReverserNode(), tX,tY,tZ)
        end

        local acceleration = 1.0
        local isAllowedToDrive = maxSpeed ~= 0

        AIVehicleUtil.driveToPoint(self, dt, acceleration, isAllowedToDrive, moveForwards, pX, pZ, maxSpeed)
    end
end











































































































































































---Set drive strategies depending on the vehicle
function AIFieldWorker:updateAIFieldWorkerDriveStrategies()
    local spec = self.spec_aiFieldWorker

    if #spec.aiImplementList > 0 then
        if spec.driveStrategies ~= nil and #spec.driveStrategies > 0 then
            for i=#spec.driveStrategies,1,-1 do
                spec.driveStrategies[i]:delete()
                table.remove(spec.driveStrategies, i)
            end
            spec.driveStrategies = {}
        end

        local foundCombine = false
        local foundBaler = false
        local foundStonePicker = false
        for _, childVehicle in pairs(self.rootVehicle.childVehicles) do -- using all vehicles since the combine can also be standalone without cutter - so no ai implement
            if SpecializationUtil.hasSpecialization(Combine, childVehicle.specializations) then
                foundCombine = true
            end
            if SpecializationUtil.hasSpecialization(Baler, childVehicle.specializations) then
                foundBaler = true
            end
            if SpecializationUtil.hasSpecialization(StonePicker, childVehicle.specializations) then
                foundStonePicker = true
            end
        end

        foundCombine = foundCombine or SpecializationUtil.hasSpecialization(Combine, spec.specializations)
        if foundCombine then
            local driveStrategyCombine = AIDriveStrategyCombine.new()
            driveStrategyCombine:setAIVehicle(self)
            table.insert(spec.driveStrategies, driveStrategyCombine)
        end

        foundBaler = foundBaler or SpecializationUtil.hasSpecialization(Baler, spec.specializations)
        if foundBaler then
            local driveStrategyBaler = AIDriveStrategyBaler.new()
            driveStrategyBaler:setAIVehicle(self)
            table.insert(spec.driveStrategies, driveStrategyBaler)
        end

        foundStonePicker = foundStonePicker or SpecializationUtil.hasSpecialization(StonePicker, spec.specializations)
        if foundStonePicker then
            local driveStrategyStonePicker = AIDriveStrategyStonePicker.new()
            driveStrategyStonePicker:setAIVehicle(self)
            table.insert(spec.driveStrategies, driveStrategyStonePicker)
        end

        local driveStrategyStraight = AIDriveStrategyStraight.new()
        local driveStrategyCollision = AIDriveStrategyCollision.new(driveStrategyStraight)

        driveStrategyCollision:setAIVehicle(self)
        driveStrategyStraight:setAIVehicle(self)

        table.insert(spec.driveStrategies, driveStrategyCollision)
        table.insert(spec.driveStrategies, driveStrategyStraight)
    end
end


---Updates the AI logic that is possible to be run at a lower frequency (by default every 4 frames)
Primarly this is the evaluation of the drive strategies (collsion, etc.)
-- @param float dt time since last call in ms
function AIFieldWorker:updateAIFieldWorkerLowFrequency(dt)
    local spec = self.spec_aiFieldWorker

    self:clearAIDebugTexts()
    self:clearAIDebugLines()

    if self:getIsFieldWorkActive() then
        if spec.driveStrategies ~= nil and #spec.driveStrategies > 0 then
            local vX,vY,vZ = getWorldTranslation(self:getAISteeringNode())

            local tX, tZ, moveForwards, maxSpeedStra, maxSpeed, distanceToStop
            for i=1,#spec.driveStrategies do
                local driveStrategy = spec.driveStrategies[i]
                tX, tZ, moveForwards, maxSpeedStra, distanceToStop = driveStrategy:getDriveData(dt, vX,vY,vZ)
                maxSpeed = math.min(maxSpeedStra or math.huge, maxSpeed or math.huge)
                if tX ~= nil or not self:getIsFieldWorkActive() then
                    break
                end
            end

            if tX == nil then
                if self:getIsFieldWorkActive() then -- check if AI is still active, because it might have been kicked by a strategy
                    self:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
                end
            end

            if not self:getIsFieldWorkActive() then
                return
            end

            local minimumSpeed = 5
            local lookAheadDistance = 5

            -- use different settings while turning
            -- so we are more pricise when stopping at end point in small turning segments
            if self:getAIFieldWorkerIsTurning() then
                minimumSpeed = 1.5
                lookAheadDistance = 2
            end

            local distSpeed = math.max(minimumSpeed, maxSpeed * math.min(1, distanceToStop/lookAheadDistance))
            local speedLimit, _ = self:getSpeedLimit(true)
            maxSpeed = math.min(maxSpeed, distSpeed, speedLimit)
            maxSpeed = math.min(maxSpeed, self:getCruiseControlMaxSpeed())

            if VehicleDebug.state == VehicleDebug.DEBUG_AI then
                self:addAIDebugText(string.format("===> maxSpeed = %.2f", maxSpeed))
            end

            local isAllowedToDrive = maxSpeed ~= 0

            -- set drive values
            spec.aiDriveParams.moveForwards = moveForwards
            spec.aiDriveParams.tX = tX
            spec.aiDriveParams.tY = vY
            spec.aiDriveParams.tZ = tZ
            spec.aiDriveParams.maxSpeed = maxSpeed
            spec.aiDriveParams.valid = true

            -- worst case check: did not move but should have moved
            if isAllowedToDrive and self:getLastSpeed() < 0.5 then
                spec.didNotMoveTimer = spec.didNotMoveTimer - dt
            else
                spec.didNotMoveTimer = spec.didNotMoveTimeout
            end

            if spec.didNotMoveTimer < 0 then
                if self:getAIFieldWorkerIsTurning() then
                    if spec.lastTurnStrategy ~= nil then
                        spec.lastTurnStrategy:skipTurnSegment()
                    end
                else
                    self:stopCurrentAIJob(AIMessageErrorBlockedByObject.new())
                end

                spec.didNotMoveTimer = spec.didNotMoveTimeout
            end
        end

        self:raiseAIEvent("onAIFieldWorkerActive", "onAIImplementActive")
    end
end


















































---
function AIFieldWorker:aiContinue(superFunc)
    superFunc(self)

    local spec = self.spec_aiFieldWorker
    if spec.isActive and not spec.isTurning then
        self:raiseAIEvent("onAIFieldWorkerContinue", "onAIImplementContinue")
    end
end
