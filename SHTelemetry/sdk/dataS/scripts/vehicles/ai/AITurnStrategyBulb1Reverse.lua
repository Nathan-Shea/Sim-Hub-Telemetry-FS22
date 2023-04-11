---|   |
--|   |
--| - |
--/|   |\
--| |   | |
--\|   |/
--|   |
--|   |
--Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.



local AITurnStrategyBulb1Reverse_mt = Class(AITurnStrategyBulb1Reverse, AITurnStrategy)


---
function AITurnStrategyBulb1Reverse.new(customMt)
    if customMt == nil then
        customMt = AITurnStrategyBulb1Reverse_mt
    end

    local self = AITurnStrategy.new(customMt)
    self.strategyName = "AITurnStrategyBulb1Reverse"
    self.isReverseStrategy = true

    self.turnBox = self:createTurningSizeBox()

    return self
end


---
function AITurnStrategyBulb1Reverse:delete()
    AITurnStrategyBulb1Reverse:superClass().delete(self)

    self.maxTurningSizeBox = {}
    self.maxTurningSizeBox2 = {}
end


---
function AITurnStrategyBulb1Reverse:startTurn(driveStrategyStraight)
    if not AITurnStrategyBulb1Reverse:superClass().startTurn(self, driveStrategyStraight) then
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

    -- center of first circle
    local c1X,c1Y,c1Z
    if sideOffset >= 0 then
        c1X,c1Y,c1Z = -turnData.radius,0,turnData.zOffsetTurn
    else
        c1X,c1Y,c1Z = turnData.radius,0,turnData.zOffsetTurn
    end

    -- center of second circle
    local a = turnData.radius+math.abs(sideOffset)
    local z = math.sqrt( 2*turnData.radius*2*turnData.radius - a*a )
    local c2X,c2Y,c2Z = sideOffset,0,z+turnData.zOffsetTurn

    -- center of third circle
    local c3X,c3Y,c3Z
    if sideOffset >= 0 then
        c3X,c3Y,c3Z = 2*sideOffset+turnData.radius,0,turnData.zOffsetTurn
    else
        c3X,c3Y,c3Z = 2*sideOffset-turnData.radius,0,turnData.zOffsetTurn
    end

    --
    local alpha = math.atan( z / a )
    local rvX,rvY,rvZ = getWorldRotation(self.vehicle:getAIDirectionNode(), 0,0,0)

    -- now shift segments by length of bulb
    local xb = math.max(turnData.toolOverhang.front.xb, turnData.toolOverhang.back.xb)
    local zb = 0 --math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb)
    local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
    local zt = 0 --math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    local delta = math.max(xb, zb, turnData.radius + xt, turnData.radius + zt)
    --print(" delta="..tostring(delta))

    --local maxZ = turnData.toolOverhang.front.zt
    --local maxZ = math.max(turnData.toolOverhang.front.zt, turnData.zOffset + turnData.toolOverhang.back.zt)

    local fullBulbLength = c2Z + delta --box0.size[3] --delta
    --print(" fullBulbLength="..tostring(fullBulbLength))

    local bulbLength = math.max(0, fullBulbLength - zOffset) -- - maxZ) --self.distanceToCollision - maxZ)
    --print(" bulbLength="..tostring(bulbLength))

    self:addNoFullCoverageSegment(self.turnSegments)

    --# first straight
    local segment = {}
    segment.isCurve = false
    segment.moveForward = (c1Z-bulbLength) > 0
    segment.slowDown = true
    if segment.moveForward then
        segment.skipToNextSegmentDistanceThreshold = 3
    end
    segment.startPoint = self:getVehicleToWorld(0, 0, 0, true)
    segment.endPoint = self:getVehicleToWorld(0, 0, c1Z-bulbLength, true)
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
    setTranslation(segment.o, self:getVehicleToWorld(c2X,c2Y,c2Z-bulbLength) )
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
    segment.o = createTransformGroup("segment3")
    link(getRootNode(), segment.o)
    setTranslation(segment.o, self:getVehicleToWorld(c3X,c3Y,c3Z-bulbLength) )
    setRotation(segment.o, rvX,rvY,rvZ)
    if sideOffset >= 0 then
        segment.startAngle = math.rad(180) - alpha
        segment.endAngle = math.rad(180)
    else
        segment.startAngle = alpha
        segment.endAngle = 0
    end
    table.insert(self.turnSegments, segment)

    --# pre final straight
    local segment = {}
    segment.isCurve = false
    --segment.moveForward = true
    segment.moveForward = (c3Z-bulbLength) > (c3Z-2*fullBulbLength)
    segment.slowDown = true
    segment.checkAlignmentToSkipSegment = true
    --segment.checkForValidArea = not self.vehicle.aiAlignedProcessing --true
    local x = 2*sideOffset
    segment.startPoint = self:getVehicleToWorld(x, 0, c3Z-bulbLength, true)
    segment.endPoint = self:getVehicleToWorld(x, 0, c3Z-2*fullBulbLength, true)
    table.insert(self.turnSegments, segment)

    --# final straight
    local zFinal = turnData.zOffset
    local segment = {}
    segment.isCurve = false
    segment.moveForward = (c3Z-2*fullBulbLength) > zFinal
    segment.slowDown = true
    --segment.findEndOfField = true
    segment.startPoint = self:getVehicleToWorld(x, 0, c3Z-2*fullBulbLength, true)
    segment.endPoint = self:getVehicleToWorld(x, 0, zFinal, true)
    table.insert(self.turnSegments, segment)

    self:startTurnFinalization()

    return true
end



---
function AITurnStrategyBulb1Reverse:updateTurningSizeBox(box, turnLeft, turnData, lookAheadDistance)

    local sideOffset
    if turnLeft then
        sideOffset = turnData.sideOffsetLeft
    else
        sideOffset = turnData.sideOffsetRight
    end

    local a = turnData.radius+math.abs(sideOffset)
    local z = math.sqrt( 2*turnData.radius*2*turnData.radius - a*a )

    local c2X,c2Y,c2Z = sideOffset, 0, z+turnData.zOffsetTurn

    --local bulbLength = c2Z + math.max(math.abs(turnData.sideOffsetLeft), math.abs(turnData.sideOffsetRight), turnData.toolOverhang.back.xt, turnData.toolOverhang.back.zt, turnData.toolOverhang.front.xt, turnData.toolOverhang.front.zt)
    --c2Z = c2Z - bulbLength

    local xb = math.max(turnData.toolOverhang.front.xb, turnData.toolOverhang.back.xb)
    --local zb = math.max(turnData.toolOverhang.front.zb, turnData.toolOverhang.back.zb)
    local xt = math.max(turnData.toolOverhang.front.xt, turnData.toolOverhang.back.xt)
    --local zt = math.max(turnData.toolOverhang.front.zt, turnData.toolOverhang.back.zt)
    --local delta = math.max(xb, zb, turnData.radius + xt)
    local delta = math.max(xb, turnData.radius + xt)

    local maxX = c2X + delta
    local minX = c2X - delta

    --local maxZ = turnData.toolOverhang.front.zt
    local maxZ = math.max(turnData.toolOverhang.front.zt, turnData.zOffset + turnData.toolOverhang.back.zt)

    --print(" Bulb1reverse maxZ = "..tostring(maxZ))

    box.center[1], box.center[2], box.center[3] = maxX - (maxX-minX)/2, 0, maxZ/2 + lookAheadDistance/2
    box.size[1], box.size[2], box.size[3] = (maxX-minX)/2, 5, maxZ/2 + lookAheadDistance/2

    self:adjustHeightOfTurningSizeBox(box)
end
