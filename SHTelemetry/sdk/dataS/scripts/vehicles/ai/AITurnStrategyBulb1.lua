----
--/     \
--|       |
--\     /
--|   |
--|   |
--Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.



local AITurnStrategyBulb1_mt = Class(AITurnStrategyBulb1, AITurnStrategy)


---
function AITurnStrategyBulb1.new(customMt)
    if customMt == nil then
        customMt = AITurnStrategyBulb1_mt
    end

    local self = AITurnStrategy.new(customMt)
    self.strategyName = "AITurnStrategyBulb1"

    return self
end


---
function AITurnStrategyBulb1:delete()
    AITurnStrategyBulb1:superClass().delete(self)

    self.maxTurningSizeBox = {}
    self.maxTurningSizeBox2 = {}
end


---
function AITurnStrategyBulb1:startTurn(driveStrategyStraight)
    if not AITurnStrategyBulb1:superClass().startTurn(self, driveStrategyStraight) then
        return false
    end
    local turnData = driveStrategyStraight.turnData

    local sideOffset
    if self.turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    --#
    --self.usePredictionToSkipToNextSegment = true

    -- center of first circle
    local c1X,c1Y,c1Z
    if sideOffset >= 0 then
        c1X,c1Y,c1Z = self:getVehicleToWorld(-turnData.radius,0,turnData.zOffsetTurn)
    else
        c1X,c1Y,c1Z = self:getVehicleToWorld(turnData.radius,0,turnData.zOffsetTurn)
    end

    -- center of second circle
    local a = turnData.radius+math.abs(sideOffset)
    local z = math.sqrt( 2*turnData.radius*2*turnData.radius - a*a )
    local c2X,c2Y,c2Z = self:getVehicleToWorld(sideOffset,0,z+turnData.zOffsetTurn)

    -- center of third circle
    local c3X,c3Y,c3Z
    if sideOffset >= 0 then
        c3X,c3Y,c3Z = self:getVehicleToWorld(2*sideOffset+turnData.radius,0,turnData.zOffsetTurn)
    else
        c3X,c3Y,c3Z = self:getVehicleToWorld(2*sideOffset-turnData.radius,0,turnData.zOffsetTurn)
    end

    --
    local alpha = math.atan( z / a )
    local rvX,rvY,rvZ = getWorldRotation(self.vehicle:getAIDirectionNode(), 0,0,0)

    self:addNoFullCoverageSegment(self.turnSegments)

    --# first straight
    local segment = {}
    segment.isCurve = false
    segment.moveForward = true
    segment.slowDown = true
    segment.startPoint = self:getVehicleToWorld(0,0,0, true)
    segment.endPoint = self:getVehicleToWorld(0,0,turnData.zOffsetTurn, true)
    table.insert(self.turnSegments, segment)

    --# first curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.radius = turnData.radius
    segment.o = createTransformGroup("segment1")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, c1X,c1Y,c1Z)
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = 0
        segment.endAngle = alpha
    else
        segment.startAngle = math.rad(180)
        segment.endAngle = math.rad(180) - alpha
    end
    table.insert(self.turnSegments, segment)

    --# second curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.radius = turnData.radius
    segment.o = createTransformGroup("segment2")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, c2X,c2Y,c2Z)
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.rad(180) + alpha
        segment.endAngle = -alpha
    else
        segment.startAngle = -alpha
        segment.endAngle = math.rad(180) + alpha
    end
    table.insert(self.turnSegments, segment)

    --# third curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.radius = turnData.radius
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    segment.o = createTransformGroup("segment3")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, c3X,c3Y,c3Z)
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.rad(180) - alpha
        segment.endAngle = math.rad(180)
    else
        segment.startAngle = alpha
        segment.endAngle = 0
    end
    table.insert(self.turnSegments, segment)

    --# final straight
    local segment = {}
    segment.isCurve = false
    segment.moveForward = true
    segment.slowDown = true
    --segment.checkForValidArea = true --not self.vehicle.aiAlignedProcessing --true
    local x = 2*sideOffset
    segment.startPoint = self:getVehicleToWorld(x,0,turnData.zOffsetTurn, true)
    segment.endPoint = self:getVehicleToWorld(x,0,math.min(turnData.zOffset, turnData.zOffsetTurn-0.1), true)
    table.insert(self.turnSegments, segment)

    self:startTurnFinalization()

    return true
end



---
function AITurnStrategyBulb1:updateTurningSizeBox(box, turnLeft, turnData, lookAheadDistance)

    local sideOffset
    if turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    --# 2) get turn data, center of circle and radius
    local a = turnData.radius+math.abs(sideOffset)
    local z = math.sqrt( 2*turnData.radius*2*turnData.radius - a*a )

    local c2X,c2Y,c2Z = sideOffset, 0, z+turnData.zOffsetTurn

    --# 3) estimate final size of bounding box

    local xb = math.max(turnData.toolOverhang.front.xb, turnData.toolOverhang.back.xb)
    --local zb = math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb)
    local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
    --local zt = math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    local delta = math.max(xb, turnData.radius + xt)

    local maxX = c2X + xb
    local minX = c2X - xb
    local maxZ = c2Z + delta

    --print(" Bulb1 maxZ = "..tostring(maxZ))

    box.center[1], box.center[2], box.center[3] = maxX - (maxX-minX)/2, 0, maxZ/2 + lookAheadDistance/2
    box.size[1], box.size[2], box.size[3] = (maxX-minX)/2, 5, maxZ/2 + lookAheadDistance/2

    self:adjustHeightOfTurningSizeBox(box)
end
