----
--/   \
--|     |
--|    /
--|   |
--|   |
--Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.



local AITurnStrategyBulb2_mt = Class(AITurnStrategyBulb2, AITurnStrategy)


---
function AITurnStrategyBulb2.new(customMt)
    if customMt == nil then
        customMt = AITurnStrategyBulb2_mt
    end

    local self = AITurnStrategy.new(customMt)
    self.strategyName = "AITurnStrategyBulb2"

    return self
end


---
function AITurnStrategyBulb2:delete()
    AITurnStrategyBulb2:superClass().delete(self)

    self.maxTurningSizeBox = {}
    self.maxTurningSizeBox2 = {}
end


---
function AITurnStrategyBulb2:startTurn(driveStrategyStraight)
    if not AITurnStrategyBulb2:superClass().startTurn(self, driveStrategyStraight) then
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

    -- start with centre of second circle
    local c2X,c2Y,c2Z
    if sideOffset >= 0 then
        c2X,c2Y,c2Z = turnData.radius+2*sideOffset,0,0
    else
        c2X,c2Y,c2Z = -turnData.radius+2*sideOffset,0,0
    end

    local alpha = math.acos(math.abs(sideOffset)/turnData.radius)

    -- center of first circle
    local c1X,c1Y,c1Z
    if sideOffset >= 0 then
        c1X = turnData.radius
    else
        c1X = -turnData.radius
    end
    c1Y = 0
    c1Z = math.sin(alpha)*2*turnData.radius

    c1Z = c1Z + turnData.zOffsetTurn
    c2Z = c2Z + turnData.zOffsetTurn

    local rvX,rvY,rvZ = getWorldRotation(self.vehicle:getAIDirectionNode())

    --# first straight
    local segment = {}
    segment.isCurve = false
    segment.moveForward = true
    segment.slowDown = true
    segment.startPoint = self:getVehicleToWorld(0,0,0, true)
    segment.endPoint = self:getVehicleToWorld(0,0,c1Z, true)
    table.insert(self.turnSegments, segment)

    --# first curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.radius = turnData.radius
    segment.o = createTransformGroup("segment1")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c1X,c1Y,c1Z) )
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.pi
        segment.endAngle = -alpha
    else
        segment.startAngle = 0
        segment.endAngle = math.pi + alpha
    end
    table.insert(self.turnSegments, segment)

    --# second curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.radius = turnData.radius
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    segment.o = createTransformGroup("segment2")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c2X,c2Y,c2Z) )
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.pi - alpha
        segment.endAngle = math.pi
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
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    local x = 2*sideOffset
    segment.startPoint = self:getVehicleToWorld(x,0,c2Z, true)
    segment.endPoint = self:getVehicleToWorld(x,0,math.min(turnData.zOffset, c2Z-0.1), true)
    table.insert(self.turnSegments, segment)

    self:startTurnFinalization()

    return true
end



---
function AITurnStrategyBulb2:updateTurningSizeBox(box, turnLeft, turnData, lookAheadDistance)

    local sideOffset
    if turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    -- start with centre of second circle
    local c2X,c2Y,c2Z
    if sideOffset >= 0 then
        c2X,c2Y,c2Z = turnData.radius+2*sideOffset,0,0
    else
        c2X,c2Y,c2Z = -turnData.radius+2*sideOffset,0,0
    end

    local alpha = math.acos(math.abs(sideOffset)/turnData.radius)

    -- center of first circle
    local c1X,c1Y,c1Z
    if sideOffset >= 0 then
        c1X = turnData.radius
    else
        c1X = -turnData.radius
    end
    c1Y = 0
    c1Z = math.sin(alpha)*2*turnData.radius

    c1Z = c1Z + turnData.zOffsetTurn
    c2Z = c2Z + turnData.zOffsetTurn

    --# 3) estimate final size of bounding box

    local xb = math.max(turnData.toolOverhang.front.xb, turnData.toolOverhang.back.xb)
    --local zb = math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb)
    local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
    --local zt = math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    local delta = math.max(xb, turnData.radius + xt)

    local maxX = c1X + delta
    local minX = c1X - delta
    local maxZ = c1Z + delta

    box.center[1], box.center[2], box.center[3] = maxX - (maxX-minX)/2, 0, maxZ/2 + lookAheadDistance/2
    box.size[1], box.size[2], box.size[3] = (maxX-minX)/2, 5, maxZ/2 + lookAheadDistance/2

    self:adjustHeightOfTurningSizeBox(box)
end
