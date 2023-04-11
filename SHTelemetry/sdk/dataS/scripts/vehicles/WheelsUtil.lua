---Wheels util
--Util class to manage wheels of a vehicle






















---Register new tire type
-- @param string name name of new tire type
-- @param table frictionCoeffs friction coeffs
-- @param table frictionCoeffsWer friction coeffs wet
function WheelsUtil.registerTireType(name, frictionCoeffs, frictionCoeffsWet, frictionCoeffsSnow)
    name = name:upper()
    if WheelsUtil.getTireType(name) ~= nil then
        print("Warning: Tire type '"..name.."' already registered, ignoring this definition")
        return
    end

    local function getNoNilCoeffs(frictionCoeffs)
        local localCoeffs = {}
        if frictionCoeffs[1] == nil then
            localCoeffs[1] = 1.15
            for i=2,WheelsUtil.NUM_GROUNDS do
                if frictionCoeffs[i] ~= nil then
                    localCoeffs[1] = frictionCoeffs[i]
                    break
                end
            end
        else
            localCoeffs[1] = frictionCoeffs[1]
        end
        for i=2,WheelsUtil.NUM_GROUNDS do
            localCoeffs[i] = frictionCoeffs[i] or frictionCoeffs[i-1]
        end
        return localCoeffs
    end

    local tireType = {}
    tireType.name = name
    tireType.frictionCoeffs = getNoNilCoeffs(frictionCoeffs)
    tireType.frictionCoeffsWet = getNoNilCoeffs(frictionCoeffsWet or frictionCoeffs)
    tireType.frictionCoeffsSnow = getNoNilCoeffs(frictionCoeffsSnow or tireType.frictionCoeffsWet)
    table.insert(WheelsUtil.tireTypes, tireType)
end


---Remove a tire type
function WheelsUtil.unregisterTireType(name)
    name = name:upper()
    for i, tireType in ipairs(WheelsUtil.tireTypes) do
        if tireType.name == name then
            table.remove(WheelsUtil.tireTypes, i)
            break
        end
    end
end


---Returns tire type index
-- @param string name name of tire type
-- @return Integer i index of tire type
function WheelsUtil.getTireType(name)
    name = name:upper()
    for i, t in pairs(WheelsUtil.tireTypes) do
        if t.name == name then
            return i
        end
    end
    return nil
end


---Returns tire type name by index
-- @param integer i index of tire type
-- @return string name name of tire type
function WheelsUtil.getTireTypeName(index)
    if WheelsUtil.tireTypes[index] ~= nil then
        return WheelsUtil.tireTypes[index].name
    end

    return "unknown"
end































































































































---
function WheelsUtil.getSmoothedAcceleratorAndBrakePedals(self, acceleratorPedal, brakePedal, dt)

    if self.wheelsUtilSmoothedAcceleratorPedal == nil then
        self.wheelsUtilSmoothedAcceleratorPedal = 0
    end

    local appliedAcc = 0
    if acceleratorPedal > 0 then
        if acceleratorPedal > self.wheelsUtilSmoothedAcceleratorPedal then
            appliedAcc = math.min(math.max(self.wheelsUtilSmoothedAcceleratorPedal + SMOOTHING_SPEED_SCALE * dt, SMOOTHING_SPEED_SCALE), acceleratorPedal)
        else
            appliedAcc = acceleratorPedal
        end
        self.wheelsUtilSmoothedAcceleratorPedal = appliedAcc
    elseif acceleratorPedal < 0 then
        if acceleratorPedal < self.wheelsUtilSmoothedAcceleratorPedal then
            appliedAcc = math.max(math.min(self.wheelsUtilSmoothedAcceleratorPedal - SMOOTHING_SPEED_SCALE * dt, -SMOOTHING_SPEED_SCALE), acceleratorPedal)
        else
            appliedAcc = acceleratorPedal
        end
        self.wheelsUtilSmoothedAcceleratorPedal = appliedAcc
    else
        -- Decrease smoothed acceleration towards 0 with different speeds based on if we are braking
        local decSpeed = 0.0005 + 0.001 * brakePedal -- scale between 2sec and 0.66s (full brake)
        if self.wheelsUtilSmoothedAcceleratorPedal > 0 then
            self.wheelsUtilSmoothedAcceleratorPedal = math.max(self.wheelsUtilSmoothedAcceleratorPedal - decSpeed*dt, 0)
        else
            self.wheelsUtilSmoothedAcceleratorPedal = math.min(self.wheelsUtilSmoothedAcceleratorPedal + decSpeed*dt, 0)
        end
    end

    if self.wheelsUtilSmoothedBrakePedal == nil then
        self.wheelsUtilSmoothedBrakePedal = 0
    end

    local appliedBrake = 0
    if brakePedal > 0 then
        if brakePedal > self.wheelsUtilSmoothedBrakePedal then
            appliedBrake = math.min(self.wheelsUtilSmoothedBrakePedal + 0.0025*dt, brakePedal) -- full brake in 0.4sec
        else
            appliedBrake = brakePedal
        end
        self.wheelsUtilSmoothedBrakePedal = appliedBrake
    else
        -- Decrease smoothed brake towards 0 with different speeds based on if we are accelerating
        local decSpeed = 0.0005 + 0.001 * acceleratorPedal -- scale between 2sec and 0.66s (full acceleration)
        self.wheelsUtilSmoothedBrakePedal = math.max(self.wheelsUtilSmoothedBrakePedal - decSpeed*dt, 0)
    end

    --print(string.format("input: %.2f %.2f applied: %.2f %.2f", acceleratorPedal, brakePedal, appliedAcc, appliedBrake))

    return appliedAcc, appliedBrake
end


---Updates wheel physics
-- @param float dt time since last call in ms
-- @param float currentSpeed signed current speed (m/ms)
-- @param float acceleration target acceleration [-1,1]
-- @param boolean doHandbrake do handbrake
-- @param boolean stopAndGoBraking if false, the acceleration needs to be 0 before a change of direction is allowed
function WheelsUtil.updateWheelsPhysics(self, dt, currentSpeed, acceleration, doHandbrake, stopAndGoBraking)
--print("function WheelsUtil.updateWheelsPhysics("..tostring(self)..", "..tostring(dt)..", "..tostring(currentSpeed)..", "..tostring(acceleration)..", "..tostring(doHandbrake)..", "..tostring(stopAndGoBraking))

    local acceleratorPedal = 0
    local brakePedal = 0

    local reverserDirection = 1
    if self.spec_drivable ~= nil then
        reverserDirection = self.spec_drivable.reverserDirection
    end

    local motor = self.spec_motorized.motor
    local isManualTransmission = motor.backwardGears ~= nil or motor.forwardGears ~= nil
    local useManualDirectionChange = (isManualTransmission and motor.gearShiftMode ~= VehicleMotor.SHIFT_MODE_AUTOMATIC)
                                  or motor.directionChangeMode == VehicleMotor.DIRECTION_CHANGE_MODE_MANUAL
    useManualDirectionChange = useManualDirectionChange and self:getIsManualDirectionChangeAllowed()
    if useManualDirectionChange then
        acceleration = acceleration * motor.currentDirection
    else
        acceleration = acceleration * reverserDirection
    end

    local absCurrentSpeed = math.abs(currentSpeed)
    local accSign = MathUtil.sign(acceleration)

    self.nextMovingDirection = self.nextMovingDirection or 0
    self.nextMovingDirectionTimer = self.nextMovingDirectionTimer or 0

    local automaticBrake = false
    if math.abs(acceleration) < 0.001 then
        automaticBrake = true

        -- Non-stop&go only allows change of direction if the vehicle speed is smaller than 1km/h or the direction has already changed (e.g. because the brakes are not hard enough)
        if stopAndGoBraking or currentSpeed * self.nextMovingDirection < 0.0003 then
            self.nextMovingDirection = 0
        end
    else
        -- Disable the known moving direction if the vehicle is driving more than 5km/h (0.0014 * 3600 =  5.04km/h) in the opposite direction
        if self.nextMovingDirection * currentSpeed < -0.0014 then
            self.nextMovingDirection = 0
        end

        -- Continue accelerating if we want to go in the same direction
        -- or if the vehicle is only moving slowly in the wrong direction (0.0003 * 3600 = 1.08 km/h) and we are allowed to change direction
        if accSign == self.nextMovingDirection or (currentSpeed * accSign > -0.0003 and (stopAndGoBraking or self.nextMovingDirection == 0)) then
            self.nextMovingDirectionTimer = math.max(self.nextMovingDirectionTimer - dt, 0)
            if self.nextMovingDirectionTimer == 0 then
                acceleratorPedal = acceleration
                brakePedal = 0
                self.nextMovingDirection = accSign
            else
                acceleratorPedal = 0
                brakePedal = math.abs(acceleration)
            end
        else
            acceleratorPedal = 0
            brakePedal = math.abs(acceleration)
            if stopAndGoBraking then
                self.nextMovingDirectionTimer = 100
            end
        end
    end

    if useManualDirectionChange then
        if acceleratorPedal ~= 0 and MathUtil.sign(acceleratorPedal) ~= motor.currentDirection then
            brakePedal = math.abs(acceleratorPedal)
            acceleratorPedal = 0
        end
    end

    if automaticBrake then
        acceleratorPedal = 0
    end

    acceleratorPedal, brakePedal = motor:updateGear(acceleratorPedal, brakePedal, dt)

    if motor.gear == 0 and motor.targetGear ~= 0 then
        -- brake automatically if the vehicle is rolling backwards while shifting
        if currentSpeed * MathUtil.sign(motor.targetGear) < 0 then
            automaticBrake = true
        end
    end

    if motor.gearShiftMode == VehicleMotor.SHIFT_MODE_MANUAL_CLUTCH then
        if isManualTransmission then
            automaticBrake = false
        end
    end

    if automaticBrake then
        local isSlow = absCurrentSpeed < motor.lowBrakeForceSpeedLimit
        local isArticulatedSteering = self.spec_articulatedAxis ~= nil and self.spec_articulatedAxis.componentJoint ~= nil and math.abs(self.rotatedTime) > 0.01

        if (isSlow or doHandbrake) and not isArticulatedSteering then
            brakePedal = 1
        else
            -- interpolate between lowBrakeForce and 1 if speed is below 3.6 km/h
            local factor = math.min(absCurrentSpeed / 0.001, 1)
            brakePedal = MathUtil.lerp(1, motor.lowBrakeForceScale, factor)
        end
    end

    SpecializationUtil.raiseEvent(self, "onVehiclePhysicsUpdate", acceleratorPedal, brakePedal, automaticBrake, currentSpeed)

    acceleratorPedal, brakePedal = WheelsUtil.getSmoothedAcceleratorAndBrakePedals(self, acceleratorPedal, brakePedal, dt)

    local maxSpeed = motor:getMaximumForwardSpeed() * 3.6
    if self.movingDirection < 0 then
        maxSpeed = motor:getMaximumBackwardSpeed() * 3.6
    end

    --active braking if over the speed limit
    local overSpeedLimit = self:getLastSpeed() - math.min(motor:getSpeedLimit(), maxSpeed)
    if overSpeedLimit > 0 then
        if overSpeedLimit > 0.3 then
            motor.overSpeedTimer = math.min(motor.overSpeedTimer + dt, 2000)
        else
            motor.overSpeedTimer = math.max(motor.overSpeedTimer - dt, 0)
        end

        -- the longer we exceed the speed limit by min. 0.3km/h, the harder we brake
        -- so we have a smooth braking when the speed limit changes and a harder brake when driving downhill with a full trailer
        local factor = 0.5 + (motor.overSpeedTimer / 2000 * 1)

        brakePedal = math.max(math.min(math.pow(overSpeedLimit * factor, 2), 1), brakePedal)
        acceleratorPedal = 0.2 * math.max(1 - overSpeedLimit/0.2, 0) * acceleratorPedal -- fadeout the accelerator pedal over 0.2km/h, but immediately reduce to 20% (don't set to 0 directly so that the physics engine can still compensate if the brakes are too hard)
    else
        acceleratorPedal = acceleratorPedal * math.min(math.abs(overSpeedLimit) / 0.3 + 0.2, 1)
        motor.overSpeedTimer = 0
    end

    if next(self.spec_motorized.differentials) ~= nil and self.spec_motorized.motorizedNode ~= nil then

        local absAcceleratorPedal = math.abs(acceleratorPedal)
        local minGearRatio, maxGearRatio = motor:getMinMaxGearRatio()

        local maxSpeed
        if maxGearRatio >= 0 then
            maxSpeed = motor:getMaximumForwardSpeed()
        else
            maxSpeed = motor:getMaximumBackwardSpeed()
        end

        local acceleratorPedalControlsSpeed = false
        if acceleratorPedalControlsSpeed then
            maxSpeed = maxSpeed * absAcceleratorPedal
            if absAcceleratorPedal > 0.001 then
                absAcceleratorPedal = 1
            end
        end
        maxSpeed = math.min(maxSpeed, motor:getSpeedLimit() / 3.6)
        local maxAcceleration = motor:getAccelerationLimit()
        local maxMotorRotAcceleration = motor:getMotorRotationAccelerationLimit()
        local minMotorRpm, maxMotorRpm = motor:getRequiredMotorRpmRange()

        local neededPtoTorque, ptoTorqueVirtualMultiplicator = PowerConsumer.getTotalConsumedPtoTorque(self)
        neededPtoTorque = neededPtoTorque / motor:getPtoMotorRpmRatio()
        local neutralActive = (minGearRatio == 0 and maxGearRatio == 0) or motor:getManualClutchPedal() > 0.90

        motor:setExternalTorqueVirtualMultiplicator(ptoTorqueVirtualMultiplicator)

        --print(string.format("set vehicle props:   accPed=%.1f   speed=%.1f gearRatio=[%.1f %.1f] rpm=[%.1f %.1f], ptoTorque=[%.1f]", absAcceleratorPedal, maxSpeed, minGearRatio, maxGearRatio, minMotorRpm, maxMotorRpm, neededPtoTorque))
        if not neutralActive then
            self:controlVehicle(absAcceleratorPedal, maxSpeed, maxAcceleration, minMotorRpm*math.pi/30, maxMotorRpm*math.pi/30, maxMotorRotAcceleration, minGearRatio, maxGearRatio, motor:getMaxClutchTorque(), neededPtoTorque)
        else
            self:controlVehicle(0.0, 0.0, 0.0, 0.0, math.huge, 0.0, 0.0, 0.0, 0.0, 0.0)

            -- slightly break while using manual + clutch and in neutral position
            -- to simulate a bit of rolling resistance
            brakePedal = math.max(brakePedal, 0.03)
        end
    end

    self:brake(brakePedal)
end



---Update wheel physics
-- @param table wheel wheel
-- @param boolean doHandbrake doHandbrake
-- @param float brakePedal brake pedal
-- @param float dt dt
function WheelsUtil.updateWheelPhysics(self, wheel, brakePedal, dt)
    WheelsUtil.updateWheelSteeringAngle(self, wheel, dt)

    if self.isServer and self.isAddedToPhysics then
        local brakeForce = self:getBrakeForce() * brakePedal
        setWheelShapeProps(wheel.node, wheel.wheelShape, wheel.torque, brakeForce*wheel.brakeFactor, wheel.steeringAngle, wheel.rotationDamping)
    end
end


---Update wheel steering angle
-- @param table wheel wheel
-- @param float dt time since last call in ms
function WheelsUtil.updateWheelSteeringAngle(self, wheel, dt)

    local steeringAngle = wheel.steeringAngle
    local rotatedTime = self.rotatedTime

    if wheel.steeringAxleScale ~= nil and wheel.steeringAxleScale ~= 0 then
        local steeringAxleAngle = 0
        if self.spec_attachable ~= nil then
            steeringAxleAngle = self.spec_attachable.steeringAxleAngle
        end
        steeringAngle = MathUtil.clamp(steeringAxleAngle * wheel.steeringAxleScale, wheel.steeringAxleRotMin, wheel.steeringAxleRotMax)
    elseif wheel.versatileYRot and self:getIsVersatileYRotActive(wheel) then
        if self.isServer then
            if wheel.forceVersatility or wheel.hasGroundContact then
                steeringAngle = Utils.getVersatileRotation(wheel.repr, wheel.node, dt, wheel.positionX, wheel.positionY, wheel.positionZ, wheel.steeringAngle, wheel.rotMin, wheel.rotMax)
            end
        end
    elseif (wheel.rotSpeed ~= 0 and wheel.rotMax ~= nil and wheel.rotMin ~= nil) or wheel.forceSteeringAngleUpdate then
        if rotatedTime > 0 or wheel.rotSpeedNeg == nil then
            steeringAngle = rotatedTime * wheel.rotSpeed
        else
            steeringAngle = rotatedTime * wheel.rotSpeedNeg
        end
        if steeringAngle > wheel.rotMax then
            steeringAngle = wheel.rotMax
        elseif steeringAngle < wheel.rotMin then
            steeringAngle = wheel.rotMin
        end
        if self.customSteeringAngleFunction then
            steeringAngle = self:updateSteeringAngle(wheel, dt, steeringAngle)
        end
    end

    wheel.steeringAngle = steeringAngle
end


---Compute differential rot speed from properties of vehicle other than the motor, e.g. rot speed of wheels or linear speed of vehicle
-- @return float diffRotSpeed rot speed [rad/sec]
function WheelsUtil.computeDifferentialRotSpeedNonMotor(self)
    if self.isServer and self.spec_wheels ~= nil and #self.spec_wheels.wheels ~= 0 then
        local wheelSpeed = 0
        local numWheels = 0
        for _, wheel in pairs(self.spec_wheels.wheels) do
            local axleSpeed = getWheelShapeAxleSpeed(wheel.node, wheel.wheelShape) -- rad/sec
            if wheel.hasGroundContact then
                wheelSpeed = wheelSpeed + axleSpeed * wheel.radius
                numWheels = numWheels+1
            end
        end

        if numWheels > 0 then
            return wheelSpeed/numWheels
        end
        return 0
    else
        -- v = w*r  =>  w = v/r
        -- differentials have embeded gear so that r can be considered 1
        return self.lastSpeedReal*1000
    end
end


---
function WheelsUtil.updateWheelNetInfo(self, wheel)
    if wheel.updateWheel then
        local x, y, z, xDrive, suspensionLength = getWheelShapePosition(wheel.node, wheel.wheelShape)
        xDrive = xDrive + wheel.xDriveOffset

        if wheel.dirtyFlag ~= nil and (wheel.netInfo.x ~= x or wheel.netInfo.z ~= z) then
            self:raiseDirtyFlags(wheel.dirtyFlag)
        end

        --fill netinfo (on server)
        wheel.netInfo.x = x
        wheel.netInfo.y = y
        wheel.netInfo.z = z
        wheel.netInfo.xDrive = xDrive
        wheel.netInfo.suspensionLength = suspensionLength
    else
        wheel.updateWheel = true
    end
end


---
function WheelsUtil.updateWheelGraphics(self, wheel, dt)
    local x, y, z = wheel.netInfo.x, wheel.netInfo.y, wheel.netInfo.z
    local xDrive = wheel.netInfo.xDrive
    local suspensionLength = wheel.netInfo.suspensionLength

    if x ~= nil then
        -- calculate xDriveSpeed
        if wheel.netInfo.xDriveBefore == nil then
            wheel.netInfo.xDriveBefore = xDrive
        end

        local xDriveDiff = xDrive - wheel.netInfo.xDriveBefore
        if xDriveDiff > math.pi then
            wheel.netInfo.xDriveBefore = wheel.netInfo.xDriveBefore + (2*math.pi)
        elseif xDriveDiff < -math.pi then
            wheel.netInfo.xDriveBefore = wheel.netInfo.xDriveBefore - (2*math.pi)
        end
        wheel.netInfo.xDriveDiff = xDrive - wheel.netInfo.xDriveBefore
        wheel.netInfo.xDriveSpeed = wheel.netInfo.xDriveDiff / (0.001 * dt)
        wheel.netInfo.xDriveBefore = xDrive

        -- update visual wheel node
        return WheelsUtil.updateVisualWheel(self, wheel, x, y, z, xDrive, suspensionLength)
    end

    return false
end





---Update wheel graphics
-- @param table wheel wheel
-- @param float x x position
-- @param float y y position
-- @param float z z position
-- @param float x x drive rotation
-- @param float suspensionLength length of suspension
function WheelsUtil.updateVisualWheel(self, wheel, x, y, z, xDrive, suspensionLength)
    local changed = false

    local steeringAngle = wheel.steeringAngle
    if not wheel.showSteeringAngle then
        steeringAngle = 0
    end

    if math.abs(steeringAngle-wheel.lastSteeringAngle) > STEERING_ANGLE_THRESHOLD then
        setRotation(wheel.repr, 0, steeringAngle, 0)
        wheel.lastSteeringAngle = steeringAngle
        changed = true
    end

    if math.abs(xDrive-wheel.lastXDrive) > STEERING_ANGLE_THRESHOLD then
        setRotation(wheel.driveNode, xDrive, 0, 0)
        wheel.lastXDrive = xDrive
        changed = true
    end

    if wheel.wheelTire ~= nil then
        if self.spec_wheels.wheelVisualPressureActive then
            local deformation = MathUtil.clamp((wheel.deltaY + wheel.initialDeformation - suspensionLength), 0, wheel.maxDeformation)
            local prevDeformation, curDeformation
            if math.abs(deformation - wheel.deformation) > 0.003 then
                prevDeformation = wheel.deformation
                curDeformation = deformation

                wheel.deformation = deformation
                wheel.derformationPrevDirty = true

                changed = true
            end

            -- one frame delayed we update prev deformation to match cur deformation (TAA)
            if wheel.derformationPrevDirty then
                prevDeformation = wheel.deformation
                curDeformation = wheel.deformation

                wheel.derformationPrevDirty = false
            end

            if curDeformation ~= nil then
                local mx, my, mz, _ = I3DUtil.getShaderParameterRec(wheel.wheelTire, "morphPosition")
                I3DUtil.setShaderParameterRec(wheel.wheelTire, "morphPosition", mx, my, mz, curDeformation, false)
                I3DUtil.setShaderParameterRec(wheel.wheelTire, "prevMorphPosition", mx, my, mz, prevDeformation, false)

                if wheel.additionalWheels ~= nil then
                    for _, additionalWheel in pairs(wheel.additionalWheels) do
                        mx, my, mz, _ = I3DUtil.getShaderParameterRec(additionalWheel.wheelTire, "morphPosition")
                        I3DUtil.setShaderParameterRec(additionalWheel.wheelTire, "morphPosition", mx, my, mz, curDeformation, false)
                        I3DUtil.setShaderParameterRec(additionalWheel.wheelTire, "prevMorphPosition", mx, my, mz, prevDeformation, false)
                    end
                end
            end

            -- increase suspension length a bit to make sure the wheel sides are touching the ground and not only the center
            -- temporary disabled until we find a final solution
            local sideOffset = 0--math.min((1-wheel.sideDeformOffset) * (wheel.radius-deformation), wheel.maxDeformation)

            suspensionLength = suspensionLength + deformation + sideOffset
        end
    end

    suspensionLength = suspensionLength - wheel.deltaY

    if math.abs(wheel.lastMovement-suspensionLength) > SUSPENSION_THRESHOLD then
        local dirX, dirY, dirZ = localDirectionToLocal(wheel.repr, getParent(wheel.repr), 0, -1, 0)
        local transRatio = wheel.transRatio
        local movement = suspensionLength * transRatio
        setTranslation(wheel.repr, wheel.startPositionX + dirX*movement, wheel.startPositionY + dirY*movement, wheel.startPositionZ + dirZ*movement)
        changed = true
        if transRatio < 1 then
            movement = suspensionLength*(1-transRatio)
            setTranslation(wheel.driveNode, wheel.driveNodeStartPosX + dirX*movement, wheel.driveNodeStartPosY + dirY*movement, wheel.driveNodeStartPosZ + dirZ*movement)
        end

        wheel.lastMovement = suspensionLength
    end

    if wheel.steeringNode ~= nil then
        local refAngle = wheel.steeringNodeMaxRot
        local refTrans = wheel.steeringNodeMaxTransX
        local refRot = wheel.steeringNodeMaxRotY
        if steeringAngle < 0 then
            refAngle = wheel.steeringNodeMinRot
            refTrans = wheel.steeringNodeMinTransX
            refRot = wheel.steeringNodeMinRotY
        end
        local steering = 0
        if refAngle ~= 0 then
            steering = steeringAngle / refAngle
        end

        if wheel.steeringNodeMinTransX ~= nil then
            local x,y,z = getTranslation(wheel.steeringNode)
            x = refTrans * steering
            setTranslation(wheel.steeringNode, x, y, z)
        end
        if wheel.steeringNodeMinRotY ~= nil then
            local rotX,rotY,rotZ = getRotation(wheel.steeringRotNode or wheel.steeringNode)
            rotY = refRot * steering
            setRotation(wheel.steeringRotNode or wheel.steeringNode, rotX, rotY, rotZ)
        end
    end

    for i=1, #wheel.fenders do
        local fender = wheel.fenders[i]

        local angleDif = 0
        if steeringAngle > fender.rotMax then
            angleDif = fender.rotMax - steeringAngle
        elseif steeringAngle < fender.rotMin then
            angleDif = fender.rotMin - steeringAngle
        end
        setRotation(fender.node, 0, angleDif, 0)
    end

    return changed
end


---Returns tire friction
-- @param Integer tireType tire type index
-- @param Integer groundType ground type index
-- @param float wetScale wet scale
-- @return float tireFriction tire friction
function WheelsUtil.getTireFriction(tireType, groundType, wetScale, snowScale)
    if wetScale == nil then
        wetScale = 0
    end
    local coeff = WheelsUtil.tireTypes[tireType].frictionCoeffs[groundType]
    local coeffWet = WheelsUtil.tireTypes[tireType].frictionCoeffsWet[groundType]
    local coeffSnow = WheelsUtil.tireTypes[tireType].frictionCoeffsSnow[groundType]
    return coeff + (coeffWet-coeff)*wetScale + (coeffSnow-coeff)*snowScale
end


---Get ground type
-- @param boolean isField is on field
-- @param boolean isRoad is on road
-- @param float depth depth of terrain
-- @return Integer groundType ground type
function WheelsUtil.getGroundType(isField, isRoad, depth)
    -- terrain softness:
    -- [  0, 0.1]: road
    -- [0.1, 0.8]: hard terrain
    -- [0.8, 1  ]: soft terrain
    if isField then
        return WheelsUtil.GROUND_FIELD
    elseif isRoad or depth < 0.1 then
        return WheelsUtil.GROUND_ROAD
    else
        if depth > 0.8 then
            return WheelsUtil.GROUND_SOFT_TERRAIN
        else
            return WheelsUtil.GROUND_HARD_TERRAIN
        end
    end
end
