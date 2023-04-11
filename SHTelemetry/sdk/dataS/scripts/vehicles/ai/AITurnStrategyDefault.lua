---Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.






local AITurnStrategyDefault_mt = Class(AITurnStrategyDefault, AITurnStrategy)


---
function AITurnStrategyDefault.new(customMt)
    if customMt == nil then
        customMt = AITurnStrategyDefault_mt
    end

    local self = AITurnStrategy.new(customMt)
    self.strategyName = "AITurnStrategyDefault"

    return self
end


---
function AITurnStrategyDefault:startTurn(driveStrategyStraight)
    if not AITurnStrategyDefault:superClass().startTurn(self, driveStrategyStraight) then
        return false
    end
    local turnData = driveStrategyStraight.turnData

    local sideOffset
    if self.turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    local radius = self:getTurnRadius(turnData.radius, sideOffset)

    --#
    --self.usePredictionToSkipToNextSegment = false

    -- center of first circle
    local c1X,c1Y,c1Z
    if sideOffset >= 0 then
        c1X,c1Y,c1Z = radius, 0, turnData.zOffsetTurn
    else
        c1X,c1Y,c1Z = -radius, 0, turnData.zOffsetTurn
    end

    -- center of second circle
    local c2X,c2Y,c2Z
    local a = 2*math.abs(sideOffset)
    local b = math.sqrt( (2*radius)*(2*radius) - a*a )
    if sideOffset >= 0 then
        c2X,c2Y,c2Z = radius + a, 0, b+turnData.zOffsetTurn
    else
        c2X,c2Y,c2Z = -radius - a, 0, b+turnData.zOffsetTurn
    end

    local alpha = math.acos(a/(2*radius))

    -- center of fourth circle
    local c4X,c4Y,c4Z
    if sideOffset >= 0 then
        c4X,c4Y,c4Z = radius + a, 0, turnData.zOffsetTurn
    else
        c4X,c4Y,c4Z = -radius - a, 0, turnData.zOffsetTurn
    end

    -- center of third circle
    local c3X,c3Y,c3Z
    c3Z = c4Z + (c2Z - c4Z)/2
    c3Y = 0

    local b = math.sqrt( (2*radius)*(2*radius) - (b/2)*(b/2) )
    if sideOffset >= 0 then
        c3X = c2X - b
    else
        c3X = c2X + b
    end

    local beta = math.acos(b/(2*radius))

    --
    local rvX,rvY,rvZ = getWorldRotation(self.vehicle:getAIDirectionNode(), 0,0,0)

    self:addNoFullCoverageSegment(self.turnSegments)

    --# first straight
    if turnData.zOffsetTurn > 0 then
        local segment = {}
        segment.isCurve = false
        segment.moveForward = true
        segment.slowDown = true
        segment.startPoint = self:getVehicleToWorld(0,0,0, true)
        segment.endPoint = self:getVehicleToWorld(0,0,turnData.zOffsetTurn, true)
        table.insert(self.turnSegments, segment)
    end

    --# first curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.slowDown = true
    segment.usePredictionToSkipToNextSegment = false
    segment.radius = radius
    segment.o = createTransformGroup("segment1")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c1X,c1Y,c1Z))
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.rad(180)
        segment.endAngle = alpha
    else
        segment.startAngle = math.rad(0)
        segment.endAngle = math.rad(180) - alpha
    end
    table.insert(self.turnSegments, segment)


    --# second curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = false
    segment.slowDown = true
    segment.usePredictionToSkipToNextSegment = false
    segment.radius = radius
    segment.o = createTransformGroup("segment2")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c2X,c2Y,c2Z))
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.rad(180) + alpha
        segment.endAngle = math.rad(180) + beta
    else
        segment.startAngle = -alpha
        segment.endAngle = -beta
    end
    table.insert(self.turnSegments, segment)

    --# third curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.slowDown = true
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    segment.radius = radius
    segment.o = createTransformGroup("segment3")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c3X,c3Y,c3Z))
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = beta
        segment.endAngle = -beta
    else
        segment.startAngle = math.pi-beta
        segment.endAngle = math.pi+beta
    end
    table.insert(self.turnSegments, segment)

    --# fourth curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.slowDown = true
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    segment.radius = radius
    segment.o = createTransformGroup("segment4")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c4X,c4Y,c4Z))
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.pi-beta
        segment.endAngle = math.pi
    else
        segment.startAngle = beta
        segment.endAngle = 0
    end
    table.insert(self.turnSegments, segment)

    --# final straight
    local segment = {}
    segment.isCurve = false
    -- segment.moveForward = true  -- not true for e.g. mex5
    --segment.moveForward = turnData.zOffset < c4Z
    local zTarget = math.min(c4Z - 0.05, turnData.zOffset)
    segment.moveForward = zTarget < c4Z
    segment.slowDown = true
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    local x = 2*sideOffset
    segment.startPoint = self:getVehicleToWorld(x,0,c4Z, true)
    segment.endPoint = self:getVehicleToWorld(x,0,zTarget, true)
    table.insert(self.turnSegments, segment)

    self:startTurnFinalization()

    return true
end


---
function AITurnStrategyDefault:updateTurningSizeBox(box, turnLeft, turnData, lookAheadDistance)

    local sideOffset
    if turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    local radius = self:getTurnRadius(turnData.radius, sideOffset)

    --# 2) get turn data, center of first circle and radius
    --local xr,_,zr = radius,0,turnData.zOffsetTurn

    local c1X, c1Z
    if sideOffset >= 0 then
        c1X, c1Z = radius, turnData.zOffsetTurn
    else
        c1X, c1Z = -radius, turnData.zOffsetTurn
    end

    --# 3)
    local a = 2*math.abs(sideOffset)
    local b = math.sqrt( (2*radius)*(2*radius) - a*a )
    local c2Z = b + turnData.zOffsetTurn

    local alpha = math.acos(a/(2*radius))

    b = math.sqrt( (2*radius)*(2*radius) - (b/2)*(b/2) )

    local beta = math.acos(b/(2*radius))

    local alphaAddition = turnData.toolOverhang.front.zt / (2 * math.pi * radius) * 2 * math.pi
    alpha = math.max(alpha - alphaAddition, 0)

    --# 4)
    local maxX
    local minX
    local safetyOffset = 1 -- add a bit of savety offset since this calculation is not always accurate and fully depends on the vehicle orientation
    if sideOffset >= 0 then
        maxX = c1X + math.cos(alpha)*radius + turnData.toolOverhang.front.xt + safetyOffset

        minX = math.min(-turnData.toolOverhang.front.xt, -turnData.toolOverhang.back.xt)
        if not turnData.allToolsAtFront then
            minX = math.min(minX, c1X - turnData.toolOverhang.back.xb)
        end
    else
        --minX = c1X + math.cos(math.pi - alpha)*radius - turnData.toolOverhang.front.zt
        minX = c1X - math.cos(alpha)*radius - turnData.toolOverhang.front.xt - safetyOffset

        maxX = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
        if not turnData.allToolsAtFront then
            maxX = math.max(maxX, c1X + turnData.toolOverhang.back.xb)
        end
    end

    local maxZ = math.max(c1Z + math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb), c2Z - math.sin(beta)*radius + turnData.toolOverhang.back.zt)

    box.center[1], box.center[2], box.center[3] = maxX - (maxX-minX)/2, 0, maxZ/2 + lookAheadDistance/2
    box.size[1], box.size[2], box.size[3] = (maxX-minX)/2, 5, maxZ/2 + lookAheadDistance/2

    self:adjustHeightOfTurningSizeBox(box)
end
