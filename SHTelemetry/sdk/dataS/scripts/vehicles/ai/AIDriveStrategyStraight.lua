---Class for a drive strategy just driving straight lines
--
--Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.



local AIDriveStrategyStraight_mt = Class(AIDriveStrategyStraight, AIDriveStrategy)


---
function AIDriveStrategyStraight.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyStraight_mt
    end

    local self = AIDriveStrategy.new(customMt)

    return self
end


---
function AIDriveStrategyStraight:delete()
    AIDriveStrategyStraight:superClass().delete(self)

    for _, implement in ipairs(self.vehicle:getAttachedAIImplements()) do
        implement.object:aiImplementEndLine()

        local rootVehicle = implement.object.rootVehicle
        rootVehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
    end

    for _,strategy in pairs(self.turnStrategies) do
        strategy:delete()
    end
end


---
function AIDriveStrategyStraight:setAIVehicle(vehicle)
    AIDriveStrategyStraight:superClass().setAIVehicle(self, vehicle)

    --# set AI direction acccording to current orientation
    local dx,_,dz = localDirectionToWorld(self.vehicle:getAIDirectionNode(), 0, 0, 1)
    if g_currentMission.snapAIDirection then
        local snapAngle = self.vehicle:getDirectionSnapAngle()
        local terrainAngle = math.pi / math.max(g_currentMission.fieldGroundSystem:getGroundAngleMaxValue() + 1, 4) -- snap at least in 45deg angles
        snapAngle = math.max(snapAngle, terrainAngle)

        local angleRad = MathUtil.getYRotationFromDirection(dx, dz)
        angleRad = math.floor(angleRad / snapAngle + 0.5) * snapAngle

        dx, dz = MathUtil.getDirectionFromYRotation(angleRad)
    else
        local length = MathUtil.vector2Length(dx,dz)
        dx = dx / length
        dz = dz / length
    end
    self.vehicle.aiDriveDirection = {dx, dz}

    local x,_,z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    self.vehicle.aiDriveTarget = {x, z}

    --# create turn strategy
    local useDefault = true

    -- check if all attached implements allow turning backward
    self.allowTurnBackward = AIVehicleUtil.getAttachedImplementsAllowTurnBackward(vehicle)

    if not self.allowTurnBackward then
        useDefault = false
    end

    for _, implement in ipairs(self.vehicle:getAttachedAIImplements()) do
        implement.aiLastStateChangeDistance = nil
    end

    self.aiToolReverserDirectionNode = AIVehicleUtil.getAIToolReverserDirectionNode(self.vehicle)
    self.vehicleAIReverserNode = self.vehicle:getAIReverserNode()

    self.turnStrategies = {}

    local usedStrategies = ''

    if useDefault then
        usedStrategies = usedStrategies .. "   +DEFAULT "
        table.insert(self.turnStrategies, AITurnStrategyDefault.new())

        usedStrategies = usedStrategies .. "   +DEFAULT (reverse)"
        table.insert(self.turnStrategies, AITurnStrategyDefaultReverse.new())
    end

    if self.aiToolReverserDirectionNode ~= nil or useDefault or self.vehicleAIReverserNode then
        usedStrategies = usedStrategies .. "   +BULBs (reverse)"
        table.insert(self.turnStrategies, AITurnStrategyBulb1Reverse.new())
        table.insert(self.turnStrategies, AITurnStrategyBulb2Reverse.new())
        table.insert(self.turnStrategies, AITurnStrategyBulb3Reverse.new())
    else
        usedStrategies = usedStrategies .. "   +BULBs"
        table.insert(self.turnStrategies, AITurnStrategyBulb1.new())
        table.insert(self.turnStrategies, AITurnStrategyBulb2.new())
        table.insert(self.turnStrategies, AITurnStrategyBulb3.new())
    end

    if self.aiToolReverserDirectionNode ~= nil or useDefault or self.vehicleAIReverserNode then
        usedStrategies = usedStrategies .. "   +HALFCIRCLE (reverse)"
        table.insert(self.turnStrategies, AITurnStrategyHalfCircleReverse.new())
    else
        usedStrategies = usedStrategies .. " +HALFCIRCLE"
        table.insert(self.turnStrategies, AITurnStrategyHalfCircle.new())
    end

    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
        print("AI is using strategies: "..usedStrategies.." for "..tostring(self.vehicle.configFileName))
    end

    for _,turnStrategy in ipairs(self.turnStrategies) do
        turnStrategy:setAIVehicle(self.vehicle, self)
    end

    self.activeTurnStrategy = nil

    self.turnDataIsStable = false
    self.turnDataIsStableCounter = 0

    self.fieldEndGabDetected = false
    self.fieldEndGabLastPos = {}
    self.gabAllowTurnLeft = true
    self.gabAllowTurnRight = true
    self.resetGabDetection = true
    self.fieldEndGabDetectedByBits = false

    self.lastValidTurnLeftPosition = {0,0,0}
    self.lastValidTurnLeftValue = 0
    self.lastValidTurnRightPosition = {0,0,0}
    self.lastValidTurnRightValue = 0
    self.lastValidTurnCheckPosition = {0,0,0}

    self.useCorridor = false
    self.useCorridorStart = nil
    self.useCorridorTimeOut = 0

    self.rowStartTranslation = nil

    self.lastLookAheadDistance = 5

    self.driveExtraDistanceToFieldBorder = false

    self.toolLineStates = {}

    self.isTurning = false
    self.isFirstRow = true
    self.isFirstRun = true
end


---
function AIDriveStrategyStraight:update(dt)
    for _,strategy in ipairs(self.turnStrategies) do
        strategy:update(dt)
    end

    -- check for valid field on first run to be independent of the getDriveData function
    -- getDriveData might not be called since it's blocked by other strategies
    -- e.g. wwhen the AIDriveStrategyCombine is waiting for a trailer to get in range
    if self.isFirstRun then
        local vX, vY, vZ = getWorldTranslation(self.vehicle:getAISteeringNode())
        local _, hasField, ownedField = self:getDistanceToEndOfField(dt, vX, vY, vZ)
        if not hasField then
            if ownedField then
                self.vehicle:stopCurrentAIJob(AIMessageErrorNoFieldFound.new())
                self:debugPrint("Stopping AIVehicle - unable to find field (initial)")
            else
                self.vehicle:stopCurrentAIJob(AIMessageErrorFieldNotOwned.new())
                self:debugPrint("Stopping AIVehicle - field not owned (initial)")
            end
        end

        self.isFirstRun = false
    end
end


---
function AIDriveStrategyStraight:getDriveData(dt, vX, vY, vZ)

    -- during turn
    if self.activeTurnStrategy ~= nil then
        if not self.isTurning then
            self.fieldEndGabDetected = false
            self.fieldEndGabDetectedByBits = false
            self.fieldEndGabLastPos = {}

            self.lastValidTurnLeftPosition = {0,0,0}
            self.lastValidTurnLeftValue = 0
            self.lastValidTurnRightPosition = {0,0,0}
            self.lastValidTurnRightValue = 0

            self.gabAllowTurnLeft = true
            self.gabAllowTurnRight = true
            self.resetGabDetection = true

            self.rowStartTranslation = nil
        end

        self.isTurning = true
        self.isFirstRow = false

        local tX, tZ, moveForwards, maxSpeed, distanceToStop = self.activeTurnStrategy:getDriveData(dt, vX,vY,vZ, self.turnData)
        if tX ~= nil then
            if VehicleDebug.state == VehicleDebug.DEBUG_AI then
                self.vehicle:addAIDebugText("===> distanceToStop = "..distanceToStop)
            end
            return tX, tZ, moveForwards, maxSpeed, distanceToStop
        else
            for _,turnStrategy in ipairs(self.turnStrategies) do
                turnStrategy:onEndTurn(self.activeTurnStrategy.turnLeft)
            end
            self.turnLeft = self.activeTurnStrategy.turnLeft

            self.activeTurnStrategy = nil
            self.idealTurnStrategy = nil

            -- ToDo: decide wether to measure again ?! (yes for plows, no for all other tools?)
            self.turnDataIsStable = false
            self.turnDataIsStableCounter = 0

            self.lastLookAheadDistance = 5 -- 30
            self.foundField = false
            self.foundNoBetterTurnStrategy = false

            self.lastHasNoField = false
        end
    else
        self.isTurning = false
    end

    if self.rowStartTranslation == nil then
        local x, y, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
        self.rowStartTranslation = {x, y, z}
    end

    --
    local distanceToEndOfField, hasField, ownedField = self:getDistanceToEndOfField(dt, vX,vY,vZ)
    local attachedAIImplements = self.vehicle:getAttachedAIImplements()

    if hasField and distanceToEndOfField > 0 then
        self.foundField = true
    end

    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
        self.vehicle:addAIDebugText(string.format("==(I)=> distanceToEndOfField: %.1f", distanceToEndOfField))
    end

    -- this is the case when turn is finished and tool is too far away from field
    if self.foundField == false and distanceToEndOfField <= 0 and self.turnLeft ~= nil then
        local _,_,lz = worldToLocal(self.vehicle:getAIDirectionNode(), self.vehicle.aiDriveTarget[1], 0, self.vehicle.aiDriveTarget[2])
        if lz > 0 then
            distanceToEndOfField = self.lookAheadDistanceField
            self.lastHasNoField = false
        end
    end

    if not hasField and self.foundField ~= true and self.turnLeft == nil then
        if ownedField then
            self.vehicle:stopCurrentAIJob(AIMessageErrorNoFieldFound.new())
            self:debugPrint("Stopping AIVehicle - unable to find field")
        else
            self.vehicle:stopCurrentAIJob(AIMessageErrorFieldNotOwned.new())
            self:debugPrint("Stopping AIVehicle - field not owned")
        end

        return nil
    end

    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
        self.vehicle:addAIDebugText(string.format("==(II)=> distanceToEndOfField: %.1f", distanceToEndOfField))
        self.vehicle:addAIDebugText(string.format("===> foundField: %s", tostring(self.foundField)))
        self.vehicle:addAIDebugText(string.format("===> lastHasNoField: %s", tostring(self.lastHasNoField)))
        if self.turnData ~= nil then
            self.vehicle:addAIDebugText(string.format("===> useExtraStraight: %s %s", tostring(self.turnData.useExtraStraightLeft), tostring(self.turnData.useExtraStraightRight)))
        end
    end

    -- if the field border is found in front of us we continue to drive straight until we reach the field border on the side we turn (or on both sides if we have not decided the direction yet)
    -- this helps us to complete fields with a 45 degress field border to 100%
    if distanceToEndOfField <= 0 then
        for _, implement in ipairs(attachedAIImplements) do
            local leftMarker, rightMarker, _ = implement.object:getAIMarkers()
            local hasNoFullCoverageArea, _ = implement.object:getAIHasNoFullCoverageArea()

            local allowCheck = self.turnLeft == nil or (self.turnLeft and self.gabAllowTurnRight) or (self.turnLeft == false and self.gabAllowTurnLeft)
            allowCheck = allowCheck and not hasNoFullCoverageArea
            allowCheck = allowCheck and not self.fieldEndGabDetectedByBits

            if allowCheck then
                local dir = self.turnLeft and -1 or 1
                local width = calcDistanceFrom(leftMarker, rightMarker)
                local sX, sZ, wX, wZ, hX, hZ = AIVehicleUtil.getAreaDimensions(self.vehicle.aiDriveDirection[1], self.vehicle.aiDriveDirection[2], leftMarker, rightMarker, dir*width, 0, 1, false)
                local area, _ = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX,sZ, wX,wZ, hX,hZ, false)
                if area > 0 then
                    if not AIVehicleUtil.getIsAreaOwned(self.vehicle, sX, sZ, wX, wZ, hX, hZ) then
                        area = 0
                    end
                end

                if self.turnLeft == nil then
                    if not self.gabAllowTurnLeft then
                        area = 0
                    end

                    if area <= 0 then
                        if self.gabAllowTurnRight then
                            dir = -dir
                            sX, sZ, wX, wZ, hX, hZ = AIVehicleUtil.getAreaDimensions(self.vehicle.aiDriveDirection[1], self.vehicle.aiDriveDirection[2], leftMarker, rightMarker, dir*width, 0, 1, false)
                            area, _ = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX,sZ, wX,wZ, hX,hZ, false)

                            if area > 0 then
                                if not AIVehicleUtil.getIsAreaOwned(self.vehicle, sX, sZ, wX, wZ, hX, hZ) then
                                    area = 0
                                end
                            end
                        end
                    end
                end

                if area > 0 then
                    distanceToEndOfField = 5
                    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
                        self.vehicle:addAIDebugText(string.format("===> continue until field border on left/right (area: %d)", area))
                    end
                    self.driveExtraDistanceToFieldBorder = true
                end
            end
        end
    else
        self.driveExtraDistanceToFieldBorder = false
    end

    local lookAheadDistance = self.lastLookAheadDistance

    local distanceToCollision = 0

    if distanceToEndOfField > 0 and not self.useCorridor then
        if VehicleDebug.state == VehicleDebug.DEBUG_AI then
            self.vehicle:addAIDebugText(string.format(" turnDataIsStable: %s | %d", tostring(self.turnDataIsStable), self.turnDataIsStableCounter))

            if self.turnData ~= nil then
                self.vehicle:addAIDebugText(string.format(" turn radius: %.2f", self.turnData.radius or 0))
            end
        end
        if not self.turnDataIsStable then
            self:updateTurnData()
        end

        local searchForTurnStrategy = self.idealTurnStrategy == nil

        if self.idealTurnStrategy ~= nil then
            distanceToCollision = self.idealTurnStrategy:getDistanceToCollision(dt, vX,vY,vZ, self.turnData, lookAheadDistance)
            if distanceToCollision < lookAheadDistance then
                searchForTurnStrategy = true
            else
                self.foundNoBetterTurnStrategy = false
            end
        end

        if VehicleDebug.state == VehicleDebug.DEBUG_AI then
            self.vehicle:addAIDebugText(string.format(" searchForTurnStrategy: %s", tostring(searchForTurnStrategy)))
        end

        if searchForTurnStrategy and self.foundNoBetterTurnStrategy ~= true then
            for i,turnStrategy in ipairs(self.turnStrategies) do
                if turnStrategy ~= self.idealTurnStrategy then
                    local colDist = turnStrategy:getDistanceToCollision(dt, vX,vY,vZ, self.turnData, lookAheadDistance)

                    if colDist >= lookAheadDistance and not turnStrategy.collisionDetected then
                        self.idealTurnStrategy = turnStrategy
                        distanceToCollision = colDist
                        break
                    end
                end
            end
        end

        if VehicleDebug.state == VehicleDebug.DEBUG_AI then
            self.vehicle:addAIDebugText(string.format("===> distanceToCollision: %.1f", distanceToCollision))
        end

        if self.idealTurnStrategy ~= nil then
            -- reset valid position of opposite turn side since there is a reason why not to turn into this direction
            if self.idealTurnStrategy.turnLeft ~= self.turnLeft then
                if self.idealTurnStrategy.turnLeft then
                    self.lastValidTurnRightPosition[1] = 0
                    self.lastValidTurnRightPosition[2] = 0
                    self.lastValidTurnRightPosition[3] = 0
                    self.lastValidTurnRightValue = 0
                else
                    self.lastValidTurnLeftPosition[1] = 0
                    self.lastValidTurnLeftPosition[2] = 0
                    self.lastValidTurnLeftPosition[3] = 0
                    self.lastValidTurnLeftValue = 0
                end
            end

            self.turnLeft = self.idealTurnStrategy.turnLeft
        end
    end

    local distanceToTurn = math.min(distanceToEndOfField, distanceToCollision)
    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
        self.vehicle:addAIDebugText(string.format("===> Distance to turn: %.1f", distanceToTurn))
        self.vehicle:addAIDebugText(string.format("===> turnLeft: %s", tostring(self.turnLeft)))
    end

    if distanceToCollision < lookAheadDistance and distanceToCollision < distanceToEndOfField then
        if self.turnLeft ~= nil or self.idealTurnStrategy == nil then
            AIVehicleUtil.updateInvertLeftRightMarkers(self.vehicle, self.vehicle)
            for _,implement in pairs(attachedAIImplements) do
                AIVehicleUtil.updateInvertLeftRightMarkers(self.vehicle, implement.object)
            end

            local leftAreaPercentage, rightAreaPercentage = AIVehicleUtil.getValidityOfTurnDirections(self.vehicle, self.turnData)

            if (self.turnLeft and rightAreaPercentage < AIVehicleUtil.VALID_AREA_THRESHOLD) or (not self.turnLeft and leftAreaPercentage < AIVehicleUtil.VALID_AREA_THRESHOLD) or self.idealTurnStrategy == nil then
                self.foundNoBetterTurnStrategy = false

                local collision = self.turnStrategies[1]:checkCollisionInFront(self.turnData)
                if collision or distanceToEndOfField <= 0 then
                    self.foundNoBetterTurnStrategy = false
                    self.idealTurnStrategy = nil

                    if self.turnLeft == nil then
                        self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
                        self:debugPrint("Stopping AIVehicle - turn direction undefined")
                        return nil
                    end

                else
                    distanceToTurn = lookAheadDistance
                end
            end

        end
    end

    -- if we collide to the left or to the right and we still got some area to work in front of us
    -- we check if there is no collision and still valid ground in the front and continue to work
    -- as soon as we reach the field end or a collision we will start to reverse and turn in front of the collision
    if self.allowTurnBackward or self.aiToolReverserDirectionNode ~= nil then
        if distanceToTurn <= 0 and distanceToEndOfField > 0 then
            local collision = self.turnStrategies[1]:checkCollisionInFront(self.turnData, 0)

            -- if the vehicle is somehow blocked and can not move (slopes etc.) we cancel the corridor and start to reverse
            if not collision then
                if self.vehicle:getLastSpeed() < 1.5 then
                    self.useCorridorTimeOut = self.useCorridorTimeOut + dt
                else
                    self.useCorridorTimeOut = 0
                end

                if self.useCorridorTimeOut > 3000 then
                    collision = true
                end
            end

            if not collision then
                distanceToTurn = distanceToEndOfField
                self.useCorridor = true
                if self.useCorridorStart == nil then
                    self.useCorridorStart = {vX, vY, vZ}
                else
                    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
                        local distance = MathUtil.vector3Length(self.useCorridorStart[1]-vX, self.useCorridorStart[2]-vY,self.useCorridorStart[3]-vZ)
                        self.vehicle:addAIDebugText(string.format("===> is using a corridor (%.1fm)", distance))
                    end
                end
            else
                self.useCorridor = false
            end
        else
            self.useCorridor = false
        end
    end

    if distanceToTurn <= 0 and not self.useCorridor then
        -- call end line for all tools that were still 'on field'
        for _, implement in ipairs(attachedAIImplements) do
            if implement.aiEndLineCalled == nil or not implement.aiEndLineCalled then
                implement.aiEndLineCalled = true
                implement.aiStartLineCalled = nil

                implement.object:aiImplementEndLine()

                local rootVehicle = implement.object.rootVehicle
                rootVehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
            end
        end

        self.lastHasNoField = false -- reset state for end of field check

        self.activeTurnStrategy = self.idealTurnStrategy
        if self.turnData ~= nil and self.activeTurnStrategy ~= nil then
            if self.useCorridorStart ~= nil then
                local distance = MathUtil.vector3Length(self.useCorridorStart[1]-vX, self.useCorridorStart[2]-vY,self.useCorridorStart[3]-vZ)
                self.corridorDistance = distance
                self.useCorridorStart = nil
                self:debugPrint(string.format("start turn with corridor offset: %.2f", distance))
            end
            local canTurn = self.activeTurnStrategy:startTurn(self)
            self.activeTurnStrategy.lastValidTurnPositionOffset = 0
            self.corridorDistance = 0
            if not canTurn then
                self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
                self:debugPrint("Stopping AIVehicle - could not start to turn (%s)", self.activeTurnStrategy.strategyName)

                return nil
            end
            return self.activeTurnStrategy:getDriveData(dt, vX,vY,vZ, self.turnData)
        else
            self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
            self:debugPrint("Stopping AIVehicle - no turn data found")
        end
        return nil
    else
        self.vehicle:addAIDebugText("===> Drive straight")
        return self:getDriveStraightData(dt, vX,vY,vZ, distanceToTurn, distanceToEndOfField)
    end

end


---
function AIDriveStrategyStraight:getDriveStraightData(dt, vX, vY, vZ, distanceToTurn, distanceToEndOfField)
    if self.vehicle.aiDriveDirection == nil then
        return nil, nil, true, 0, 0
    end

    -- drive along the desired direction
    local pX, pZ = MathUtil.projectOnLine(vX, vZ, self.vehicle.aiDriveTarget[1], self.vehicle.aiDriveTarget[2], self.vehicle.aiDriveDirection[1], self.vehicle.aiDriveDirection[2])
    local tX = pX + self.vehicle.aiDriveDirection[1] * self.vehicle.maxTurningRadius
    local tZ = pZ + self.vehicle.aiDriveDirection[2] * self.vehicle.maxTurningRadius

    local maxSpeed = self.vehicle:getSpeedLimit(true)
    local attachedAIImplements = self.vehicle:getAttachedAIImplements()


    -- 1: raise, nil: stay, -1: lower
    for i=#self.toolLineStates, 1, -1 do
        self.toolLineStates[i] = nil
    end


    local nrOfImplements = #attachedAIImplements
    for i=nrOfImplements,1,-1 do
        local implement = attachedAIImplements[i]

        if self.toolLineStates[i+1] == -1 and attachedAIImplements[i+1].object:getAttacherVehicle() == implement.object then
            self.toolLineStates[i] = -1
        else
            local leftMarker, rightMarker, backMarker, markersInverted = implement.object:getAIMarkers()
            -- we apply a savety offset here cause on same implements the markers are moved on x axis while lifting the tool
            -- with this offset we don't check the next row
            local safetyOffset = 0.2

            local markerZOffset = 0
            local _, _, areaLength = localToLocal(backMarker, leftMarker, 0,0,0)
            local size = 1
            local doAdditionalFieldEndChecks = false
            local hasNoFullCoverageArea, hasNoFullCoverageAreaOffset = implement.object:getAIHasNoFullCoverageArea()
            if hasNoFullCoverageArea then
                markerZOffset = areaLength
                size = math.abs(markerZOffset) + hasNoFullCoverageAreaOffset
                doAdditionalFieldEndChecks = true
            end

            local getAreaDimensions = function(leftNode, rightNode, xOffset, zOffset, areaSize, invertXOffset)
                local xOffsetLeft, xOffsetRight = xOffset, xOffset
                if invertXOffset == nil or invertXOffset then
                    xOffsetLeft = -xOffsetLeft
                end

                if markersInverted then
                    xOffsetLeft = -xOffsetLeft
                    xOffsetRight = -xOffsetRight
                end

                local lX, _, lZ = localToWorld(leftNode, xOffsetLeft, 0, zOffset)
                local rX, _, rZ = localToWorld(rightNode, xOffsetRight, 0, zOffset)

                local sX = lX - (0.5 * self.vehicle.aiDriveDirection[1])
                local sZ = lZ - (0.5 * self.vehicle.aiDriveDirection[2])
                local wX = rX - (0.5 * self.vehicle.aiDriveDirection[1])
                local wZ = rZ - (0.5 * self.vehicle.aiDriveDirection[2])
                local hX = lX + (areaSize * self.vehicle.aiDriveDirection[1])
                local hZ = lZ + (areaSize * self.vehicle.aiDriveDirection[2])

                return sX, sZ, wX, wZ, hX, hZ
            end

            local sX, sZ, wX, wZ, hX, hZ = getAreaDimensions(leftMarker, rightMarker, safetyOffset, markerZOffset, size)

            local area, totalArea = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX,sZ, wX,wZ, hX,hZ, false)
            if totalArea > 0 and area / totalArea > 0.01 then
                if not self.fieldEndGabDetected then
                    self.toolLineStates[i] = -1
                end

                -- detect gab at the end of the field to another field
                -- needed since the plow check area is as long as the plow is and this length can be longer than the distance between fields
                -- so if the back of the plow is on a field, the center not and the front also on a field we reached the headland
                if doAdditionalFieldEndChecks then
                    local distance1 = 0
                    local distance2 = 0

                    local sX1, sZ1, wX1, wZ1, hX1, hZ1 = getAreaDimensions(leftMarker, rightMarker, safetyOffset, 1, 1)
                    local area2, _ = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX1,sZ1, wX1,wZ1, hX1,hZ1, false)
                    if #self.fieldEndGabLastPos > 0 then
                        distance1 = math.abs(MathUtil.vector2Length(sX1-self.fieldEndGabLastPos[1], sZ1-self.fieldEndGabLastPos[2]))
                    end

                    local sX2, sZ2, wX2, wZ2, hX2, hZ2 = getAreaDimensions(leftMarker, rightMarker, safetyOffset, -1, 1)
                    local area3, _ = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX2,sZ2, wX2,wZ2, hX2,hZ2, false)
                    if #self.fieldEndGabLastPos > 0 then
                        distance2 = math.abs(MathUtil.vector2Length(sX2-self.fieldEndGabLastPos[1], sZ2-self.fieldEndGabLastPos[2]))
                    end

                    if area3 == 0 and area2 > 0 and distance1 > 0 and distance2 > 0 then
                        if distance1 > 3 then
                            if distance1 > distance2 then
                                self.fieldEndGabDetected = true
                                self.toolLineStates[i] = 1
                            end
                        end
                    end

                    if area2 > 0 then
                        self.fieldEndGabLastPos[1] = sX1
                        self.fieldEndGabLastPos[2] = sZ1
                    end
                end

                -- check the left and right side of the tool for valid ground
                -- in case we got a "L" field we save the last valid position and reverse to that position if we reach the headland but don't have valid ground
                if not self.driveExtraDistanceToFieldBorder then
                    local usedAreaLength = math.abs(areaLength)
                    if markerZOffset ~= 0 then
                        usedAreaLength = 0
                    end

                    local dir = self.turnLeft and -1 or 1
                    local width = calcDistanceFrom(leftMarker, rightMarker)
                    sX, sZ, wX, wZ, hX, hZ = getAreaDimensions(leftMarker, rightMarker, dir*width, markerZOffset-usedAreaLength, size, false)
                    area, _ = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX,sZ, wX,wZ, hX,hZ, false)
                    local x, y, z = 0, 0, 0

                    if not AIVehicleUtil.getIsAreaOwned(self.vehicle, sX, sZ, wX, wZ, hX, hZ) then
                        area = 0
                    end

                    if area > 0 then
                        x, y, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
                    end

                    -- eather check the other side if we found nothing
                    -- or if we don't have a turn direction set yet so we check in both directions to be able to turn in both
                    if area == 0 or self.turnLeft == nil then
                        sX, sZ, wX, wZ, hX, hZ = getAreaDimensions(leftMarker, rightMarker, -dir*width, markerZOffset-usedAreaLength, size, false)
                        local areaOpp, _ = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX,sZ, wX,wZ, hX,hZ, false)

                        if not AIVehicleUtil.getIsAreaOwned(self.vehicle, sX, sZ, wX, wZ, hX, hZ) then
                            areaOpp = 0
                        end

                        if areaOpp > 0 then
                            x, y, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
                        end

                        if self.turnLeft ~= nil then
                            area = areaOpp
                            dir = -dir
                        else
                            -- if we don't have a turn direction set yet we check in both directions for valid ground and set the lastValidPosition on both sides
                            if area > 0 then
                                self.lastValidTurnLeftPosition[1], self.lastValidTurnLeftPosition[2], self.lastValidTurnLeftPosition[3] = x, y, z
                                self.lastValidTurnLeftValue = math.max(area, self.lastValidTurnLeftValue)
                            end

                            if areaOpp > 0 then
                                self.lastValidTurnRightPosition[1], self.lastValidTurnRightPosition[2], self.lastValidTurnRightPosition[3] = x, y, z
                                self.lastValidTurnRightValue = math.max(areaOpp, self.lastValidTurnRightValue)
                            end
                        end
                    end

                    if self.turnLeft ~= nil then
                        if area > 0 then
                            if dir > 0 then
                                if area > self.lastValidTurnRightValue then
                                    self.lastValidTurnLeftPosition[1], self.lastValidTurnLeftPosition[2], self.lastValidTurnLeftPosition[3] = x, y, z
                                    self.lastValidTurnLeftValue = math.max(area, self.lastValidTurnLeftValue)
                                    self.lastValidTurnRightPosition[1], self.lastValidTurnRightPosition[2], self.lastValidTurnRightPosition[3] = 0, 0, 0
                                end
                            else
                                if area > self.lastValidTurnLeftValue then
                                    self.lastValidTurnRightPosition[1], self.lastValidTurnRightPosition[2], self.lastValidTurnRightPosition[3] = x, y, z
                                    self.lastValidTurnRightValue = math.max(area, self.lastValidTurnRightValue)
                                    self.lastValidTurnLeftPosition[1], self.lastValidTurnLeftPosition[2], self.lastValidTurnLeftPosition[3] = 0, 0, 0
                                end
                            end
                        end
                    end

                    self.lastValidTurnCheckPosition[1], self.lastValidTurnCheckPosition[2], self.lastValidTurnCheckPosition[3] = getWorldTranslation(self.vehicle:getAIDirectionNode())

                    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
                        DebugUtil.drawDebugGizmoAtWorldPos(self.lastValidTurnLeftPosition[1], self.lastValidTurnLeftPosition[2], self.lastValidTurnLeftPosition[3], 0, 1, 0, 0, 1, 0, "last valid left", true)
                        DebugUtil.drawDebugGizmoAtWorldPos(self.lastValidTurnRightPosition[1], self.lastValidTurnRightPosition[2], self.lastValidTurnRightPosition[3], 0, 1, 0, 0, 1, 0, "last valid right", true)
                    end
                end
            else
                -- If we don't need to lower, check if we need to raise it, either not on field or nothing close by (check slightly further ahead than for lowering)
                if self.lastHasNoField then
                    self.toolLineStates[i] = 1
                else
                    local lX, _, lZ = localToWorld(leftMarker, -safetyOffset, 0, markerZOffset)
                    local hX2 = lX + (math.max(distanceToTurn, 2.5) * self.vehicle.aiDriveDirection[1])
                    local hZ2 = lZ + (math.max(distanceToTurn, 2.5) * self.vehicle.aiDriveDirection[2])

                    local area2, _ = AIVehicleUtil.getAIAreaOfVehicle(implement.object, sX,sZ, wX,wZ, hX2,hZ2, false)
                    if area2 <= 0 then
                        self.toolLineStates[i] = 1
                    end
                end
            end
        end
    end

    for i=nrOfImplements,1,-1 do
        local implement = attachedAIImplements[i]

        if implement.aiLastStateChangeDistance == nil then
            -- force some slight movement when starting the AI
            -- this makes sure the start line event is not directly called after the ai start event
            implement.aiLastStateChangeDistance = 0.249
        end

        -- allow state changes only after the vehicle has been moved at least 25cm
        -- this helps us if the area position slightly changes while lowering/lifting
        -- and the result of the ai area checks is then different -> this can result in an endless lower/lift cycle [Bug #32754]
        implement.aiLastStateChangeDistance = implement.aiLastStateChangeDistance + implement.object.lastMovedDistance
        if implement.aiLastStateChangeDistance > 0.25 then
            if self.toolLineStates[i] == -1 then
                if implement.aiStartLineCalled == nil or not implement.aiStartLineCalled then
                    implement.aiStartLineCalled = true
                    implement.aiEndLineCalled = nil

                    implement.object:aiImplementStartLine()
                    implement.aiLastStateChangeDistance = 0

                    local rootVehicle = implement.object:getRootVehicle()
                    rootVehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)
                end
            elseif self.toolLineStates[i] == 1 then
                if implement.aiEndLineCalled == nil or not implement.aiEndLineCalled then
                    implement.aiEndLineCalled = true
                    implement.aiStartLineCalled = nil

                    implement.object:aiImplementEndLine()
                    implement.aiLastStateChangeDistance = 0

                    local rootVehicle = implement.object:getRootVehicle()
                    rootVehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
                end
            end
        end
    end

    -- while the attached tools are only partly lowered we limit the speed to 10kph
    -- this gives more time to detect the area and break early enough
    local anyToolLowered = false
    local anyToolLifted = false
    for i=1, #attachedAIImplements do
        local implement = attachedAIImplements[i]
        if implement.aiStartLineCalled then
            anyToolLowered = true
        elseif implement.aiEndLineCalled then
            anyToolLifted = true
        end
    end
    if anyToolLowered and anyToolLifted then
        maxSpeed = math.min(maxSpeed, 10)
        self.vehicle:addAIDebugText(string.format("===> Tools only partly lowered, limit speed to 10kph"))
    end

    local canContinueWork, stopAI, stopReason = self.vehicle:getCanAIFieldWorkerContinueWork()
    if not canContinueWork then
        maxSpeed = 0

        if stopAI then
            self.vehicle:stopCurrentAIJob(stopReason or AIMessageErrorUnknown.new())
            self:debugPrint("Stopping AIVehicle - cannot continue work")
        end
    end

    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
        self.vehicle:addAIDebugText(string.format("===> canContinueWork: %s", tostring(canContinueWork)))
        self.vehicle:addAIDebugLine({vX,vY,vZ}, {tX,vY,tZ}, {1,1,1})
    end

    --detect gabs to other fields
    if canContinueWork and self.vehicle:getLastSpeed() > 1 and self.vehicle.movingDirection > 0 then
        self.gabAllowTurnLeft = true
        self.gabAllowTurnRight = true
        local changeCounter = 0
        local lastBit = false
        local gabBits = ""
        local gabPos = -1
        local fieldEndBits = ""
        for _, implement in ipairs(attachedAIImplements) do
            if implement.aiStartLineCalled then
                local hasNoFullCoverageArea, _ = implement.object:getAIHasNoFullCoverageArea()
                local leftMarker, rightMarker, _, markersInverted = implement.object:getAIMarkers()
                local markerDir = markersInverted and -1 or 1

                local width = calcDistanceFrom(leftMarker, rightMarker) + 0.8
                local divisions = 2.5
                if width < 8.5 then
                    divisions = 1.5
                end
                if width < 4.5 then
                    divisions = 1
                end

                local checkpoints = implement.object.aiImplementGabCheckpoints or (MathUtil.round(width / divisions, 0) + 1)
                if implement.object.aiImplementGabCheckpoints == nil then
                    implement.object.aiImplementGabCheckpoints = checkpoints
                end
                if implement.object.aiImplementGabCheckpointValues == nil or implement.object.aiImplementFieldEndCheckpointValues == nil or self.resetGabDetection then
                    implement.object.aiImplementGabCheckpointValues = {}
                    implement.object.aiImplementFieldEndCheckpointValues = {}
                end
                local values = implement.object.aiImplementGabCheckpointValues
                local valuesFieldEnd = implement.object.aiImplementFieldEndCheckpointValues

                implement.object.aiImplementCurCheckpoint = (implement.object.aiImplementCurCheckpoint or -1) + 1
                if implement.object.aiImplementCurCheckpoint >= checkpoints then
                    implement.object.aiImplementCurCheckpoint = 0
                end
                local currentCheckpoint = implement.object.aiImplementCurCheckpoint


                if checkpoints > 2 then
                    local checkpointWidth = width / (checkpoints - 1)
                    local valueIndex = currentCheckpoint + 1

                    local x1, y1, z1 = localToWorld(leftMarker, 0.4 * markerDir, 0, 0)
                    local x2, y2, z2 = localToWorld(rightMarker, -0.4 * markerDir, 0, 0)

                    local x = x1 - ((x1 - x2) * ((currentCheckpoint*checkpointWidth) / width))
                    local y = y1 - ((y1 - y2) * ((currentCheckpoint*checkpointWidth) / width))
                    local z = z1 - ((z1 - z2) * ((currentCheckpoint*checkpointWidth) / width))

                    local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
                    local bit = values[valueIndex]
                    bit = bit or isOnField

                    if hasNoFullCoverageArea then
                        if valuesFieldEnd[valueIndex] == 2 and isOnField then
                            valuesFieldEnd[valueIndex] = 3
                        end
                    end

                    if valuesFieldEnd[valueIndex] == 1 and not isOnField then
                        valuesFieldEnd[valueIndex] = 2
                    end

                    if valuesFieldEnd[valueIndex] == nil and isOnField then
                        local allowed = true
                        for i=1, checkpoints do
                            if valuesFieldEnd[i] ~= nil and valuesFieldEnd[i] >= 2 then
                                allowed = false
                                break
                            end
                        end

                        if allowed then
                            valuesFieldEnd[valueIndex] = 1
                        end
                    end

                    values[valueIndex] = bit

                    for i=1, checkpoints do
                        if values[i] ~= lastBit then
                            changeCounter = changeCounter + 1
                            if changeCounter > 2 then
                                gabPos = (i-1) / checkpoints
                            end
                            lastBit = values[i]
                        end

                        if VehicleDebug.state == VehicleDebug.DEBUG_AI then
                            gabBits = gabBits .. tostring((values[i] and 1) or 0)
                            fieldEndBits = fieldEndBits .. tostring((valuesFieldEnd[i] == 3 and "-") or (valuesFieldEnd[i] == nil and "?" or (valuesFieldEnd[i] == 1 and "O" or "_")))
                        end
                    end

                    if self.isFirstRow then
                        local hasLeftGab = gabPos > 0 and gabPos < 0.5
                        local hasRightGab = gabPos >= 0.5
                        self.gabAllowTurnLeft = self.gabAllowTurnLeft and values[1] and not hasLeftGab
                        self.gabAllowTurnRight = self.gabAllowTurnRight and values[#values] and not hasRightGab
                    else
                        -- if we haved turned once and have a fixed driving direction we do not allow any gab
                        -- do not use self.turnLeft ~= nil here to check since the turn direction could already be fixed in the first row (due to collisions etc.)
                        self.gabAllowTurnLeft = self.gabAllowTurnLeft and values[1] and gabPos < 0
                        self.gabAllowTurnRight = self.gabAllowTurnRight and values[#values] and gabPos < 0
                    end
                end

                local hasHadFieldContact = false
                for i=1, checkpoints do
                    if valuesFieldEnd[i] ~= nil then
                        hasHadFieldContact = true
                        break
                    end
                end

                local allOutOfField = true
                for i=1, checkpoints do
                    if valuesFieldEnd[i] == 1 then
                        allOutOfField = false
                        break
                    end
                end

                -- tools with no full coverage area check when one of the checks enters a new field since the full work area needs to be out of the field
                -- for the others we check if all checks have just left the field
                local reEnteringField = false
                if hasNoFullCoverageArea then
                    for i=1, checkpoints do
                        if valuesFieldEnd[i] == 3 then
                            reEnteringField = true
                            break
                        end
                    end
                else
                    reEnteringField = true
                end

                self.fieldEndGabDetectedByBits = checkpoints > 0 and hasHadFieldContact and allOutOfField and reEnteringField
            else
                -- still make use of resetGabDetection variable while not active
                if implement.object.aiImplementGabCheckpointValues == nil or implement.object.aiImplementFieldEndCheckpointValues == nil or self.resetGabDetection then
                    implement.object.aiImplementGabCheckpointValues = {}
                    implement.object.aiImplementFieldEndCheckpointValues = {}
                end
            end
        end

        if self.resetGabDetection then
            self.resetGabDetection = false
        end

        if VehicleDebug.state == VehicleDebug.DEBUG_AI then
            self.vehicle:addAIDebugText(string.format("===> gab bits: %s", gabBits))
            if gabPos > 0 then
                self.vehicle:addAIDebugText(string.format("===> gab pos: %s%% side: %s", gabPos*100, (gabPos < 0.5 and "left") or "right"))
            end
            self.vehicle:addAIDebugText(string.format("===> gab allow Left: %s", self.gabAllowTurnLeft))
            self.vehicle:addAIDebugText(string.format("===> gab allow right: %s", self.gabAllowTurnRight))
            self.vehicle:addAIDebugText(string.format("===> field end detection: %s (%s)", fieldEndBits, self.fieldEndGabDetectedByBits))
        end
    end

    return tX, tZ, true, maxSpeed, distanceToTurn
end



---
function AIDriveStrategyStraight:updateTurnData()
    -- calculate basic data, which is needed by turn strategies
    self.turnData = Utils.getNoNil(self.turnData, {})

    local attachedAIImplements = self.vehicle:getAttachedAIImplements()
    local vehicleDirectionNode = self.vehicle:getAIDirectionNode()
    local minTurningRadius = self.vehicle:getAIMinTurningRadius()

    -- determine turning radius
    self.turnData.radius = self.vehicle.maxTurningRadius * 1.1                     -- needs ackermann steering
    if minTurningRadius ~= nil then
        self.turnData.radius = math.max(self.turnData.radius, minTurningRadius)
    end

    local maxToolRadius = 0
    for _,implement in pairs(attachedAIImplements) do
        maxToolRadius = math.max(maxToolRadius, AIVehicleUtil.getMaxToolRadius(implement))
    end
    self.turnData.radius = math.max(self.turnData.radius, maxToolRadius)

    -- determine tool with smallest AI area and zOffsets for estimation of waypoints/segments
    local minWidthOfAIArea = math.huge
    self.turnData.maxZOffset = -math.huge
    self.turnData.minZOffset = math.huge
    self.turnData.aiAreaMaxX = -math.huge
    self.turnData.aiAreaMinX = math.huge

    local lastTypeName = nil
    local allImplementsOfSameType = true
    local maxOverlap = -math.huge

    for _,implement in pairs(attachedAIImplements) do
        if lastTypeName == nil then
            lastTypeName = implement.object.typeName
        end
        local lastVehicleType = g_vehicleTypeManager:getTypeByName(lastTypeName)
        local vehicleType = g_vehicleTypeManager:getTypeByName(implement.object.typeName)

        allImplementsOfSameType = allImplementsOfSameType and (vehicleType == lastVehicleType
                                                            or vehicleType.parent == lastVehicleType
                                                            or vehicleType == lastVehicleType.parent
                                                            or vehicleType.parent == lastVehicleType.parent)

        local leftMarker, rightMarker, backMarker = implement.object:getAIMarkers()

        local xL,_,zL = localToLocal(leftMarker, vehicleDirectionNode, 0,0,0)
        local xR,_,zR = localToLocal(rightMarker, vehicleDirectionNode, 0,0,0)
        local xB,_,zB = localToLocal(backMarker, vehicleDirectionNode, 0,0,0)

        local lrDistance = math.abs(xL - xR)
        if lrDistance < minWidthOfAIArea then
            minWidthOfAIArea = lrDistance
            self.turnData.minAreaImplement = implement
        end

        self.turnData.aiAreaMinX = math.min(self.turnData.aiAreaMinX, xL, xR, xB)
        self.turnData.aiAreaMaxX = math.max(self.turnData.aiAreaMaxX, xL, xR, xB)

        self.turnData.maxZOffset = math.max(self.turnData.maxZOffset, zL, zR)
        self.turnData.minZOffset = math.min(self.turnData.minZOffset, zL, zR)

        maxOverlap = math.max(maxOverlap, math.min(lrDistance * 0.02, implement.object:getAIAreaOverlap() or AIVehicleUtil.AREA_OVERLAP))
    end

    self.turnData.allImplementsOfSameType = allImplementsOfSameType

    if self.turnData.maxZOffset == self.turnData.minZOffset then
        self.turnData.zOffset = 2 * self.turnData.maxZOffset
        self.turnData.zOffsetTurn = math.max(1, 2 * self.turnData.maxZOffset)
    else
        if self.turnData.maxZOffset > 0 and self.turnData.minZOffset < 0 then
            self.turnData.zOffset = self.turnData.minZOffset + self.turnData.maxZOffset
            self.turnData.zOffsetTurn = math.max(1, self.turnData.minZOffset + self.turnData.maxZOffset)
        elseif self.turnData.maxZOffset > 0 and self.turnData.minZOffset > 0 then
            self.turnData.zOffset = 2 * self.turnData.maxZOffset
            self.turnData.zOffsetTurn = math.max(1, 2 * self.turnData.maxZOffset)
        elseif self.turnData.maxZOffset < 0 and self.turnData.minZOffset < 0 then
            self.turnData.zOffset = self.turnData.minZOffset + self.turnData.maxZOffset
            self.turnData.zOffsetTurn = math.max(1, self.turnData.minZOffset + self.turnData.maxZOffset)
        end
    end

    local minLeftMarker, minRightMarker, _ = self.turnData.minAreaImplement.object:getAIMarkers()
    self.turnData.sideOffsetLeft = localToLocal(minLeftMarker, vehicleDirectionNode, 0,0,0)
    self.turnData.sideOffsetRight = localToLocal(minRightMarker, vehicleDirectionNode, 0,0,0)

    if allImplementsOfSameType then
        self.turnData.sideOffsetLeft = self.turnData.aiAreaMaxX
        self.turnData.sideOffsetRight = self.turnData.aiAreaMinX
    end

    -- shrink area size to force overlap (0.26m default)
    local overlapPerSide = maxOverlap / 2
    self.turnData.sideOffsetLeft = self.turnData.sideOffsetLeft - overlapPerSide
    self.turnData.sideOffsetRight = self.turnData.sideOffsetRight + overlapPerSide

    -- turn radius should be always higher than the side offset (otherwise some calculation in the strategies won't work)
    self.turnData.radius = math.max(self.turnData.radius, self.turnData.sideOffsetLeft, -self.turnData.sideOffsetRight)

    -- check if we need to invert the side offset (happens on plows that are rotating)
    if self.turnLeft ~= nil then
        local canInvertMarkerOnTurn = false
        for _, implement in pairs(attachedAIImplements) do
            canInvertMarkerOnTurn = canInvertMarkerOnTurn or implement.object:getAIInvertMarkersOnTurn(self.turnLeft)
        end

        if canInvertMarkerOnTurn then
            local offset = math.abs(self.turnData.sideOffsetLeft - self.turnData.sideOffsetRight)/2
            self.turnData.sideOffsetLeft = offset
            self.turnData.sideOffsetRight = -offset
        end
    end

    self.turnData.useExtraStraightLeft = self.turnData.sideOffsetLeft > self.turnData.radius
    self.turnData.useExtraStraightRight = self.turnData.sideOffsetRight < -self.turnData.radius

    self.turnData.toolOverhang = {}
    self.turnData.toolOverhang['front'] = {}
    self.turnData.toolOverhang['back'] = {}


    self.turnData.allToolsAtFront = true

    -- ToDo: ? improve this fallback estimation of overhang ...
    local xt = self.vehicle.size.width * 0.5
    local zt = self.vehicle.size.length * 0.75
    local alphaX = math.atan(-zt /(xt + self.turnData.radius))
    local alphaZ = math.atan((xt + self.turnData.radius) / zt)
    local xb = math.cos(alphaX)*xt - math.sin(alphaX)*zt + math.cos(alphaX)*self.turnData.radius
    local zb = math.sin(alphaZ)*xt + math.cos(alphaZ)*zt + math.sin(alphaZ)*self.turnData.radius
    for _,side in pairs({'front', 'back'}) do
        self.turnData.toolOverhang[side].xt = xt
        self.turnData.toolOverhang[side].zt = zt
        self.turnData.toolOverhang[side].xb = xb
        self.turnData.toolOverhang[side].zb = zb
    end

    -- overhang for tools in hydraulic
    for _,implement in pairs(attachedAIImplements) do
        local staticObject = implement.object
        local isStaticImplement = staticObject:getAIAllowTurnBackward()
        if isStaticImplement then
            if staticObject.getAttacherVehicle ~= nil then
                local attacherVehicle = staticObject:getAttacherVehicle()
                if attacherVehicle ~= nil and attacherVehicle.getAIAllowTurnBackward ~= nil then
                    if not attacherVehicle:getAIAllowTurnBackward() then
                        isStaticImplement = false
                    end
                end
            end
        end

        if isStaticImplement then
            local leftMarker, rightMarker, backMarker = staticObject:getAIMarkers()
            local leftSizeMarker, rightSizeMarker, backSizeMarker = staticObject:getAISizeMarkers()

            local xL,_,zL = localToLocal(leftSizeMarker or leftMarker, vehicleDirectionNode, 0,0,0)
            local xR,_,zR = localToLocal(rightSizeMarker or rightMarker, vehicleDirectionNode, 0,0,0)
            local xB,_,zB = localToLocal(backSizeMarker or backMarker, vehicleDirectionNode, 0,0,0)

            self.turnData.allToolsAtFront = self.turnData.allToolsAtFront and zB > 0

            local xt = math.max(math.abs(xL), math.abs(xR), math.abs(xB))
            local zt = math.max(math.abs(zL), math.abs(zR), math.abs(zB))

            --local alphaX = math.atan(-zt /(xt + self.turnData.radius))
            --local alphaZ = math.atan((xt + self.turnData.radius) / zt)
            --
            --local xb = math.cos(alphaX)*xt - math.sin(alphaX)*zt + math.cos(alphaX)*self.turnData.radius
            --local zb = math.sin(alphaZ)*xt + math.cos(alphaZ)*zt + math.sin(alphaZ)*self.turnData.radius
            --
            ----print(" --------------------------------------------------- ")
            ----print( string.format(" OLD :: alphaX=%.2f   alphaZ=%.2f ", math.deg(alphaX), math.deg(alphaZ)) )
            ----print( string.format("        -> xb /zb = %.2f / %.2f ", xb, zb) )
            ----
            ----
            ----local alphaX = math.atan( -(self.turnData.radius + xt) / zt )
            ----local alphaZ = math.atan( xt / (self.turnData.radius + zt) )
            ----
            ----local xb = math.cos(alphaX)*xt - math.sin(alphaX)*zt + math.cos(alphaX)*self.turnData.radius
            ----local zb = math.sin(alphaZ)*xt + math.cos(alphaZ)*zt + math.sin(alphaZ)*self.turnData.radius
            ----
            ----print( string.format(" NEW :: alphaX=%.2f  alphaZ=%.2f ", math.deg(alphaX), math.deg(alphaZ)) )
            ----print( string.format("        -> xb /zb = %.2f / %.2f ", xb, zb) )
            ----print( string.format("        -> xt /zt = %.2f / %.2f ", xt, zt) )
            ----
            ----print( string.format("        -> c = %.2f / r = %.2f / c+r = %.2f", math.sqrt(xt*xt + zt*zt), self.turnData.radius, math.sqrt(xt*xt + zt*zt)+self.turnData.radius) )

            -- dismiss all the math, just take the worst case
            local xb = math.sqrt(xt*xt + zt*zt) + self.turnData.radius
            local zb = math.sqrt(xt*xt + zt*zt) + self.turnData.radius


            local side = 'back'
            if zB > 0 then
                side = 'front'
            end

            self.turnData.toolOverhang[side].xb = math.max(xb, self.turnData.toolOverhang[side].xb)
            self.turnData.toolOverhang[side].zb = math.max(zb, self.turnData.toolOverhang[side].zb)
            self.turnData.toolOverhang[side].xt = math.max(xt, self.turnData.toolOverhang[side].xt)
            self.turnData.toolOverhang[side].zt = math.max(zt, self.turnData.toolOverhang[side].zt)
        end
    end

    -- overhang for trailer implements
    local rotTime = 1/self.vehicle.wheelSteeringDuration * math.atan(1/self.turnData.radius) / math.atan(1/self.vehicle.maxTurningRadius)
    local angle
    if rotTime >= 0 then
        angle = (rotTime / self.vehicle.maxRotTime) * self.vehicle.maxRotation
    else
        angle = (rotTime / self.vehicle.minRotTime) * self.vehicle.maxRotation
    end

    for _,implement in pairs(attachedAIImplements) do
        local dynamicObject = implement.object
        local isDynamicImplement = not dynamicObject:getAIAllowTurnBackward()
        if not isDynamicImplement then
            if dynamicObject.getAttacherVehicle ~= nil then
                local attacherVehicle = dynamicObject:getAttacherVehicle()
                if attacherVehicle ~= nil and attacherVehicle.getAIAllowTurnBackward ~= nil then
                    if not attacherVehicle:getAIAllowTurnBackward() then
                        isDynamicImplement = true
                        dynamicObject = attacherVehicle
                    end
                end
            end
        end

        if isDynamicImplement then
            local leftMarker, rightMarker, backMarker = implement.object:getAIMarkers()
            local leftSizeMarker, rightSizeMarker, backSizeMarker = implement.object:getAISizeMarkers()

            local lX,_,lZ = localToLocal(leftSizeMarker or leftMarker, dynamicObject.components[1].node, 0,0,0)
            local rX,_,rZ = localToLocal(rightSizeMarker or rightMarker, dynamicObject.components[1].node, 0,0,0)
            local bX,_,bZ = localToLocal(backSizeMarker or backMarker, dynamicObject.components[1].node, 0,0,0)

            local nX = math.max( math.abs(lX), math.abs(rX), math.abs(bX) )
            local nZ = math.min( -math.abs(lZ), -math.abs(rZ), -math.abs(bZ) )

            if dynamicObject.getActiveInputAttacherJoint then
                local inputAttacherJoint = dynamicObject:getActiveInputAttacherJoint()

                local xAtt,_,zAtt = localToLocal(dynamicObject.components[1].node, inputAttacherJoint.node, nX,0,nZ)
                xAtt, zAtt = zAtt, -xAtt

                local xRot = xAtt*math.cos(-angle) - zAtt*math.sin(-angle)
                local zRot = xAtt*math.sin(-angle) + zAtt*math.cos(-angle)

                local xFin,_,_ = localToLocal(dynamicObject.components[1].node, vehicleDirectionNode, xRot,0,zRot)

                xFin = xFin + self.turnData.radius

                self.turnData.toolOverhang.back.xb = math.max(self.turnData.toolOverhang.back.xb, xFin)

                local xL,_,_ = localToLocal(leftSizeMarker or leftMarker, vehicleDirectionNode, 0,0,0)
                local xR,_,_ = localToLocal(rightSizeMarker or rightMarker, vehicleDirectionNode, 0,0,0)
                local _,_,zB = localToLocal(backSizeMarker or backMarker, vehicleDirectionNode, 0,0,0)
                self.turnData.toolOverhang.back.xt = math.max(self.turnData.toolOverhang.back.xt, math.abs(xL), math.abs(xR))
                self.turnData.toolOverhang.back.zt = math.max(self.turnData.toolOverhang.back.zt, -zB)

                local _, rotationJoint, wheels = dynamicObject:getAITurnRadiusLimitation()


                local angleSteer = 0
                if rotationJoint ~= nil then
                    for _, wheel in pairs(wheels) do
                        if wheel.steeringAxleScale ~= 0 and wheel.steeringAxleRotMax ~= 0 then
                            angleSteer = math.max(angleSteer, math.abs(wheel.steeringAxleRotMax))
                        end
                    end
                end

                if angleSteer ~= 0 and rotationJoint ~= nil then
                    local wheelIndexCount = #wheels
                    if rotationJoint ~= nil and wheelIndexCount > 0 then
                        local cx,cz = 0,0
                        for _, wheel in pairs(wheels) do
                            local x,_,z = localToLocal(wheel.repr, dynamicObject.components[1].node, 0,0,0)
                            cx = cx + x
                            cz = cz + z
                        end

                        cx = cx / wheelIndexCount
                        cz = cz / wheelIndexCount

                        local dx = nX - cx
                        local dz = nZ - cz

                        local delta = math.sqrt(dx*dx + dz*dz)
                        local xFin = delta + self.turnData.radius

                        self.turnData.toolOverhang.back.xb = math.max(self.turnData.toolOverhang.back.xb, xFin)
                    end
                end
            end
        end
    end

    for _,implement in pairs(attachedAIImplements) do
        local leftMarker, _, _ = implement.object:getAIMarkers()
        local _,_,z = localToLocal(leftMarker, vehicleDirectionNode, 0,0,0)
        implement.distToVehicle = z
    end

    local sortImplementsByDistance = function(arg1, arg2)
        return arg1.distToVehicle > arg2.distToVehicle
    end

    table.sort(attachedAIImplements, sortImplementsByDistance)

    -- check if turn data is stable
    if self.lastTurnData == nil then
        self.lastTurnData = {}
        self.lastTurnData.radius = self.turnData.radius
        self.lastTurnData.maxZOffset = self.turnData.maxZOffset
        self.lastTurnData.minZOffset = self.turnData.minZOffset
        self.lastTurnData.aiAreaMaxX = self.turnData.aiAreaMaxX
        self.lastTurnData.aiAreaMinX = self.turnData.aiAreaMinX
        self.lastTurnData.sideOffsetLeft = self.turnData.sideOffsetLeft
        self.lastTurnData.sideOffsetRight = self.turnData.sideOffsetRight
    else
        if self.vehicle:getLastSpeed() > 2 and
            math.abs(self.lastTurnData.radius - self.turnData.radius) < 0.03 and
            math.abs(self.lastTurnData.maxZOffset - self.turnData.maxZOffset) < 0.03 and
            math.abs(self.lastTurnData.minZOffset - self.turnData.minZOffset) < 0.03 and
            math.abs(self.lastTurnData.aiAreaMaxX - self.turnData.aiAreaMaxX) < 0.03 and
            math.abs(self.lastTurnData.aiAreaMinX - self.turnData.aiAreaMinX) < 0.03 and
            math.abs(self.lastTurnData.sideOffsetLeft - self.turnData.sideOffsetLeft) < 0.03 and
            math.abs(self.lastTurnData.sideOffsetRight - self.turnData.sideOffsetRight) < 0.03
            then
            self.turnDataIsStableCounter = self.turnDataIsStableCounter + 1
            if self.turnDataIsStableCounter > 120 then
                self.turnDataIsStable = true
            end
        else
            self.lastTurnData.radius = self.turnData.radius
            self.lastTurnData.maxZOffset = self.turnData.maxZOffset
            self.lastTurnData.minZOffset = self.turnData.minZOffset
            self.lastTurnData.aiAreaMaxX = self.turnData.aiAreaMaxX
            self.lastTurnData.aiAreaMinX = self.turnData.aiAreaMinX
            self.lastTurnData.sideOffsetLeft = self.turnData.sideOffsetLeft
            self.lastTurnData.sideOffsetRight = self.turnData.sideOffsetRight
            self.turnDataIsStableCounter = 0
        end
    end
end
