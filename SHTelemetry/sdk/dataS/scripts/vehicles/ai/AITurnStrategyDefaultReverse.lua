---Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.






local AITurnStrategyDefaultReverse_mt = Class(AITurnStrategyDefaultReverse, AITurnStrategy)


---
function AITurnStrategyDefaultReverse.new(customMt)
    if customMt == nil then
        customMt = AITurnStrategyDefaultReverse_mt
    end

    local self = AITurnStrategy.new(customMt)
    self.strategyName = "AITurnStrategyDefaultReverse"
    self.isReverseStrategy = true

    self.turnBox = self:createTurningSizeBox()

    return self
end


---
function AITurnStrategyDefaultReverse:startTurn(driveStrategyStraight)
    if not AITurnStrategyDefaultReverse:superClass().startTurn(self, driveStrategyStraight) then
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

    -- shall we check for free space ?
    local zOffset = self.distanceToCollision
    self:updateTurningSizeBox(self.turnBox, self.turnLeft, turnData, 0)

    -- always go the turn size box length back, so we want touch untested area with the vehicle or tool
    zOffset = zOffset + 2*self.turnBox.size[3]

    -- center of first circle
    local c1X,c1Y,c1Z
    if sideOffset >= 0 then
        c1X,c1Y,c1Z = radius, 0, 0
    else
        c1X,c1Y,c1Z = -radius, 0, 0
    end

    -- center of second circle
    local c2X,c2Y,c2Z
    local a = 2*math.abs(sideOffset)
    local b = math.sqrt( (2*radius)*(2*radius) - a*a )
    if sideOffset >= 0 then
        c2X,c2Y,c2Z = radius + a, 0, -b
    else
        c2X,c2Y,c2Z = -radius - a, 0, -b
    end

    local alpha = math.acos(a/(2*radius))

    --
    local rvX,rvY,rvZ = getWorldRotation(self.vehicle:getAIDirectionNode(), 0,0,0)

    self:addNoFullCoverageSegment(self.turnSegments)

    --# pre turn straight - only used to get combine harvester after straw drop back to turn start
    local segment = {}
    segment.isCurve = false
    segment.moveForward = true
    segment.slowDown = true
    segment.startPoint = self:getVehicleToWorld(0,0,-1, true)
    segment.endPoint = self:getVehicleToWorld(0,0,0, true)
    table.insert(self.turnSegments, segment)

    --# first curve
    segment = {}
    segment.isCurve = true
    segment.moveForward = false
    segment.slowDown = true
    segment.usePredictionToSkipToNextSegment = false
    segment.radius = radius
    segment.o = createTransformGroup("segment1")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c1X,c1Y,c1Z))
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.rad(180)
        segment.endAngle = math.rad(360) - alpha
    else
        segment.startAngle = 0
        segment.endAngle = -math.rad(180) + alpha
    end
    table.insert(self.turnSegments, segment)

    --# second curve
    segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.slowDown = true
    --segment.usePredictionToSkipToNextSegment = false
    segment.radius = radius
    segment.o = createTransformGroup("segment2")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c2X,c2Y,c2Z))
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.rad(180) - alpha
        segment.endAngle = math.rad(180)
    else
        segment.startAngle = alpha
        segment.endAngle = 0
    end
    table.insert(self.turnSegments, segment)

    --# third straight
    segment = {}
    segment.isCurve = false
    segment.moveForward = c2Z > turnData.zOffset
    if not segment.moveForward then
        self.turnSegments[#self.turnSegments].usePredictionToSkipToNextSegment = false
    end
    segment.slowDown = true
    --segment.findEndOfField = true
    segment.skipToNextSegmentDistanceThreshold = 0.001
    local x = 2*sideOffset
    segment.startPoint = self:getVehicleToWorld(x,0,c2Z, true)
    segment.endPoint = self:getVehicleToWorld(x,0,turnData.zOffset, true)
    table.insert(self.turnSegments, segment)

    self:startTurnFinalization()

    return true
end


---
function AITurnStrategyDefaultReverse:updateTurningSizeBox(box, turnLeft, turnData, lookAheadDistance)
--print("function AITurnStrategyDefaultReverse:updateTurningSizeBox("..tostring(turnLeft)..", "..tostring(turnData)..", "..tostring(lookAheadDistance))

    local sideOffset
    if turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    local radius = self:getTurnRadius(turnData.radius, sideOffset)

    -- center of first circle
    local c1X,c1Y,c1Z
    if sideOffset >= 0 then
        c1X,c1Y,c1Z = radius, 0, turnData.minZOffset
    else
        c1X,c1Y,c1Z = -radius, 0, turnData.minZOffset
    end

    -- center of second circle
    local c2X,c2Y,c2Z
    c2Y = 0
    if sideOffset >= 0 then
        c2X = radius + 2*sideOffset
        c2Z = -2*radius + turnData.minZOffset
    else
        c2X = -radius + 2*sideOffset
        c2Z = -2*radius + turnData.minZOffset
    end

    --# 4)
    local maxX
    local minX
    if sideOffset >= 0 then
        local xt = -math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
        minX = math.min(xt, c1X - math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.front.xt, turnData.toolOverhang.front.xb, turnData.toolOverhang.front.zb))

        maxX = c2X + turnData.toolOverhang.back.zt
    else
        local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
        maxX = math.max(xt, c1X + math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.front.xt, turnData.toolOverhang.front.xb, turnData.toolOverhang.front.zb))

        minX = c2X - turnData.toolOverhang.back.zt
    end

    --local maxZ = math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    --local xb = math.max(turnData.toolOverhang.front.xb, turnData.toolOverhang.back.xb)
    --local zb = math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb)
    --local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
    --local zt = math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    --local maxZ = math.max(xb, zb, turnData.radius + xt, turnData.radius + zt)
    --local maxZ = math.max(xb, zb, xt, zt, turnData.maxZOffset)

    local maxZ = math.max(turnData.toolOverhang.front.zt, turnData.zOffset + turnData.toolOverhang.back.zt)
    --local maxZ = turnData.toolOverhang.front.zt

    box.center[1], box.center[2], box.center[3] = maxX - (maxX-minX)/2, 0, maxZ/2 + lookAheadDistance/2
    box.size[1], box.size[2], box.size[3] = (maxX-minX)/2, 5, maxZ/2 + lookAheadDistance/2

    self:adjustHeightOfTurningSizeBox(box)
end
