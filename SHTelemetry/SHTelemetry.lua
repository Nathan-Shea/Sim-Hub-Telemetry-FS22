--
-- SimHub Telemetry mod
-- 2020 - Wotever
-- This mod can be freely modified as long as it stays used in conjonction with SimHub
-- Simhub will automatically discover any new telemetry data being added to the output
--

SHTelemetry = {}
SHTelemetryContext = {}
SHTelemetryContext.isLoaded = false
SHTelemetryContext.updateCount = 0
SHTelemetryContext.pipeName = "\\\\.\\pipe\\SHTelemetry"
SHTelemetryContext.tabdata = {}
SHTelemetryContext.tabLength = 1

function SHTelemetry:buildTelemetry()
    SHTelemetryContext.tabdata = {}
    SHTelemetryContext.tabLength = 1
    -- Start
    self:addRawStringToTelemetry("{")

    local mission = g_currentMission

    -- Mission / Environment
    self:addNumberToTelemetry("money", mission.missionInfo.money)  --Only updates on game restart??
    self:addNumberToTelemetry("dayTime", mission.environment.currentHour * 60 + mission.environment.currentMinute ) --Changed to output in minutes instead of seconds
    self:addNumberToTelemetry("day", mission.environment.currentDay)
    self:addNumberToTelemetry("timeScale", mission.missionInfo.timeScale)
    self:addNumberToTelemetry("playTime", mission.missionInfo.playTime)

    -- Vehicle
    if (g_currentMission.controlledVehicle ~= nil) then
        local vehicle = g_currentMission.controlledVehicle
        local engine = vehicle:getMotor()
        local level, capacity = self:getVehicleFuelLevelAndCapacity(vehicle)
        

        -- Content
        tabLength = self:addBoolToTelemetry("isInVehicle", true)
        tabLength = self:addStringToTelemetry("vehicleName", mission.currentVehicleName)
        if (vehicle.spec_motorized ~= nil) then
            local spec_motorized = vehicle.spec_motorized
            local spec_lights = vehicle.spec_lights
            local motorFan = vehicle.spec_motorized.motorFan
            local motorTemperature = vehicle.spec_motorized.motorTemperature
            local cruiseControl = vehicle.spec_drivable.cruiseControl
            local cruiseControlSpeed = cruiseControl.speed
            local reverserDirection = vehicle.getReverserDirection == nil and 1 or vehicle:getReverserDirection()
            local isReverseDriving = vehicle:getLastSpeed() > spec_motorized.reverseDriveThreshold and vehicle.movingDirection ~= reverserDirection
            

            -- Moves and basic engine                                                       
            self:addBoolToTelemetry("isMotorStarted", spec_motorized.isMotorStarted)
            self:addBoolToTelemetry("isReverseDriving", isReverseDriving)
            self:addBoolToTelemetry("isReverseDirection", vehicle.movingDirection == reverserDirection)
            self:addNumberToTelemetry("maxRpm", engine:getMaxRpm())
            self:addNumberToTelemetry("minRpm", engine:getMinRpm()) 

            self.addNumberToTelemetry("runtime", vehicle.operatingTime)

            

            self:addNumberToTelemetry("Rpm", engine.lastRealMotorRpm)
            self:addNumberToTelemetry("speed", vehicle:getLastSpeed())
            self:addNumberToTelemetry("fuelLevel", level)
            self:addNumberToTelemetry("fuelCapacity", capacity)

            -- Temps
            self:addNumberToTelemetry("motorTemperature", motorTemperature.value)
            self:addBoolToTelemetry("motorFanEnabled", motorFan.enabled)

            -- Cruise control
            self:addNumberToTelemetry("cruiseControlMaxSpeed", cruiseControlSpeed)
            self:addBoolToTelemetry("cruiseControlActive", cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_OFF)

            -- Lights
            local alpha = MathUtil.clamp((math.cos(7 * getShaderTimeSec()) + 0.2), 0, 1)
            local leftIndicator = spec_lights ~= nil and (spec_lights.turnLightState == Lights.TURNLIGHT_LEFT or spec_lights.turnLightState == Lights.TURNLIGHT_HAZARD) and alpha > 0.5
            local rightIndicator = spec_lights ~= nil and (spec_lights.turnLightState == Lights.TURNLIGHT_RIGHT or spec_lights.turnLightState == Lights.TURNLIGHT_HAZARD) and alpha > 0.5
            self:addBoolToTelemetry("leftTurnIndicator", leftIndicator)
            self:addBoolToTelemetry("rightTurnIndicator", rightIndicator)
            self:addBoolToTelemetry("beaconLightsActive", spec_lights.beaconLightsActive)
            self:addNumberToTelemetry("lightType", spec_lights.lightsTypesMask)  --lots of numbers here will work out after.


            -- Adding new stuff here
            -- Engine related
            -- Fill types

            -- Implements
            


        end
        self:addNumberToTelemetry("vehiclePrice", vehicle:getPrice())
        self:addNumberToTelemetry("vehicleSellPrice", vehicle:getSellPrice())
    else
        self:addBoolToTelemetry("isInVehicle", false)
    end

    -- End
    self:addRawStringToTelemetry('"pluginVersion": "1.0"}')

    -- Send content
    local res = table.concat(SHTelemetryContext.tabdata)
    SHTelemetryContext.shfile:write(res)
    SHTelemetryContext.shfile:flush()
end

function SHTelemetry:getVehicleFuelLevelAndCapacity(vehicle)
    local fuelFillType = vehicle:getConsumerFillUnitIndex(FillType.DIESEL)
    local level = vehicle:getFillUnitFillLevel(fuelFillType)
    local capacity = vehicle:getFillUnitCapacity(fuelFillType)

    return level, capacity
end


function SHTelemetry:initPipe(dt)
    -- Re/Init file
    if (SHTelemetryContext.updateCount == 0) then
        if (SHTelemetryContext.shfile ~= nil) then
            SHTelemetryContext.shfile:flush()
            SHTelemetryContext.shfile:close()
        end

        local newfile = io.open(SHTelemetryContext.pipeName, "w")
        SHTelemetryContext.shfile = newfile
    end

    SHTelemetryContext.updateCount = SHTelemetryContext.updateCount + 1
    if (SHTelemetryContext.updateCount == 300) then
        SHTelemetryContext.updateCount = 0
    end
end

function SHTelemetry:update(dt)
    -- Init file
    self:initPipe(dt)

    -- If pipe is ready
    if (SHTelemetryContext.shfile ~= nil) then
        self:buildTelemetry()
    end
end

function SHTelemetry:addBoolToTelemetry(name, value)
    if (value ~= nil) then
        if (value) then
            SHTelemetryContext.tabdata[SHTelemetryContext.tabLength] = string.format('"%s": true, ', name)
        else
            SHTelemetryContext.tabdata[SHTelemetryContext.tabLength] = string.format('"%s": false, ', name)
        end
        self:incrementTablePosition()
    end
end

function SHTelemetry:addStringToTelemetry(name, value)
    if (value ~= nil) then
        SHTelemetryContext.tabdata[SHTelemetryContext.tabLength] = string.format('"%s": "%s", ', name, value:gsub('"', '\\"'))
        self:incrementTablePosition()
    end
end

function SHTelemetry:addRawStringToTelemetry(value)
    SHTelemetryContext.tabdata[SHTelemetryContext.tabLength] = value
    self:incrementTablePosition()
end

function SHTelemetry:addNumberToTelemetry(name, value)
    if (value ~= nil) then
        SHTelemetryContext.tabdata[SHTelemetryContext.tabLength] = string.format('"%s": %d, ', name, value)
        self:incrementTablePosition()
    end
end

function SHTelemetry:incrementTablePosition()
    SHTelemetryContext.tabLength = SHTelemetryContext.tabLength + 1
end

addModEventListener(SHTelemetry)
