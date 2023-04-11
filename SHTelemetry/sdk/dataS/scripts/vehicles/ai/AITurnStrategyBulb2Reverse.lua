----
--/   \
--|     |
--|    /
--|   |
--|   |
--Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.



local AITurnStrategyBulb2Reverse_mt = Class(AITurnStrategyBulb2Reverse, AITurnStrategy)


---
function AITurnStrategyBulb2Reverse.new(customMt)
    if customMt == nil then
        customMt = AITurnStrategyBulb2Reverse_mt
    end

    local self = AITurnStrategy.new(customMt)
    self.strategyName = "AITurnStrategyBulb2Reverse"
    self.isReverseStrategy = true

    self.turnBox = self:createTurningSizeBox()

    return self
end


---
function AITurnStrategyBulb2Reverse:delete()
    AITurnStrategyBulb2Reverse:superClass().delete(self)

    self.maxTurningSizeBox = {}
    self.maxTurningSizeBox2 = {}
end


---
function AITurnStrategyBulb2Reverse:startTurn(driveStrategyStraight)
    if not AITurnStrategyBulb2Reverse:superClass().startTurn(self, driveStrategyStraight) then
        return false
    end
    local turnData = driveStrategyStraight.turnData

    local sideOffset
    if self.turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    -- shall we check for free space ?
    local zOffset = self.distanceToCollision
    self:updateTurningSizeBox(self.turnBox, self.turnLeft, turnData, 0)

    -- always go the turn size box length back, so we want touch untested area with the vehicle or tool
    zOffset = zOffset + 2*self.turnBox.size[3]

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

    -- now shift segments by length of bulb
    local xb = math.max(turnData.toolOverhang.front.xb, turnData.toolOverhang.back.xb)
    local zb = 0 --math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb)
    local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
    local zt = 0 --math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    local delta = math.max(xb, zb, turnData.radius + xt, turnData.radius + zt)

    local fullBulbLength = c1Z + delta
    local bulbLength = math.max(0, fullBulbLength - zOffset) --self.distanceToCollision - maxZ)

    --# first straight
    local segment = {}
    segment.isCurve = false
    segment.moveForward = (c1Z-bulbLength) > 0
    segment.slowDown = true
    if segment.moveForward then
        segment.skipToNextSegmentDistanceThreshold = 3
    end
    segment.startPoint = self:getVehicleToWorld(0,0,0, true)
    segment.endPoint = self:getVehicleToWorld(0,0,c1Z-bulbLength, true)
    table.insert(self.turnSegments, segment)

    --# first curve
    local segment = {}
    segment.isCurve = true
    segment.moveForward = true
    segment.radius = turnData.radius
    segment.o = createTransformGroup("segment1")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c1X,c1Y,c1Z-bulbLength) )
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
    segment.o = createTransformGroup("segment2")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c2X,c2Y,c2Z-bulbLength) )
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.pi - alpha
        segment.endAngle = math.pi
    else
        segment.startAngle = alpha
        segment.endAngle = 0
    end
    table.insert(self.turnSegments, segment)

    --# pre final straight
    local segment = {}
    segment.isCurve = false
    --segment.moveForward = true
    segment.moveForward = (c2Z-bulbLength) > (c2Z-2*fullBulbLength)
    segment.slowDown = true
    segment.checkAlignmentToSkipSegment = true
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    local x = 2*sideOffset
    segment.startPoint = self:getVehicleToWorld(x,0,c2Z-bulbLength, true)
    segment.endPoint = self:getVehicleToWorld(x,0,c2Z-2*fullBulbLength, true)
    table.insert(self.turnSegments, segment)

    --# final straight
    --local zFinal = math.min(turnData.zOffset, turnData.toolOverhang.front.zt - turnData.toolOverhang.back.zt)
    local zFinal = turnData.zOffset
    local segment = {}
    segment.isCurve = false
    segment.moveForward = (c2Z-2*fullBulbLength) > zFinal
    segment.slowDown = true
    --segment.findEndOfField = true
    segment.startPoint = self:getVehicleToWorld(x,0,c2Z-2*fullBulbLength, true)
    segment.endPoint = self:getVehicleToWorld(x,0,zFinal, true)
    table.insert(self.turnSegments, segment)

    self:startTurnFinalization()

    return true
end



---
function AITurnStrategyBulb2Reverse:updateTurningSizeBox(box, turnLeft, turnData, lookAheadDistance)

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

    --local bulbLength = c1Z + math.max(turnData.sideOffsetLeft, turnData.sideOffsetRight, turnData.toolOverhang.back.xt, turnData.toolOverhang.back.zt, turnData.toolOverhang.front.xt, turnData.toolOverhang.front.zt)
    --c1Z = c1Z - bulbLength
    --c2Z = c2Z - bulbLength

    --# 3) estimate final size of bounding box

    local xb = math.max(turnData.toolOverhang.front.xb, turnData.toolOverhang.back.xb)
    --local zb = math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb)
    local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
    --local zt = math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    --local delta = math.max(xb, zb, turnData.radius + xt, turnData.radius + zt)
    local delta = math.max(xb, turnData.radius + xt)

    local maxX = c1X + delta
    local minX = c1X - delta

    local maxZ = math.max(turnData.toolOverhang.front.zt, turnData.zOffset + turnData.toolOverhang.back.zt)
    --local maxZ = turnData.toolOverhang.front.zt

    box.center[1], box.center[2], box.center[3] = maxX - (maxX-minX)/2, 0, maxZ/2 + lookAheadDistance/2
    box.size[1], box.size[2], box.size[3] = (maxX-minX)/2, 5, maxZ/2 + lookAheadDistance/2

    self:adjustHeightOfTurningSizeBox(box)
end
