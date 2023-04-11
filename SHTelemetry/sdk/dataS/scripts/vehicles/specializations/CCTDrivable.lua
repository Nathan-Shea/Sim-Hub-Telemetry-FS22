---Specialization class for CCTDrivables















---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function CCTDrivable.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Enterable, specializations)
end


---
function CCTDrivable.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("CCTDrivable")

    schema:register(XMLValueType.FLOAT, "vehicle.cctDrivable#cctRadius", "CCT radius", 1.0)
    schema:register(XMLValueType.FLOAT, "vehicle.cctDrivable#cctHeight", "CCT height", 1.0)
    schema:register(XMLValueType.FLOAT, "vehicle.cctDrivable#cctSlopeLimit", "CCT slope limit", 25.0)
    schema:register(XMLValueType.FLOAT, "vehicle.cctDrivable#cctStepOffset", "CCT step offset", 0.35)
    schema:register(XMLValueType.FLOAT, "vehicle.cctDrivable#customOffset", "CCT custom offset", 0)

    schema:setXMLSpecializationType()
end


---Registers functions
-- @param string vehicleType type of vehicle
function CCTDrivable.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "moveCCT",                CCTDrivable.moveCCT)
    SpecializationUtil.registerFunction(vehicleType, "getIsCCTOnGround",       CCTDrivable.getIsCCTOnGround)
    SpecializationUtil.registerFunction(vehicleType, "getCCTCollisionMask",    CCTDrivable.getCCTCollisionMask)
    SpecializationUtil.registerFunction(vehicleType, "getCCTWorldTranslation", CCTDrivable.getCCTWorldTranslation)
end


---
function CCTDrivable.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "setWorldPosition", CCTDrivable.setWorldPosition)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "setWorldPositionQuaternion", CCTDrivable.setWorldPositionQuaternion)
end


---Registers event listeners
-- @param string vehicleType type of vehicle
function CCTDrivable.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", CCTDrivable)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", CCTDrivable)
end


---Called on loading
-- @param table savegame savegame
function CCTDrivable:onLoad(savegame)
    local spec = self.spec_cctdrivable

    spec.cctRadius =  self.xmlFile:getValue("vehicle.cctDrivable#cctRadius", 1.0)
    spec.cctHeight =  self.xmlFile:getValue("vehicle.cctDrivable#cctHeight", 1.0)
    spec.cctSlopeLimit =  self.xmlFile:getValue("vehicle.cctDrivable#cctSlopeLimit", 25)
    spec.cctStepOffset =  self.xmlFile:getValue("vehicle.cctDrivable#cctStepOffset", 0.3)
    spec.customOffset =  self.xmlFile:getValue("vehicle.cctDrivable#customOffset", 0)
    spec.cctCenterOffset = spec.cctRadius + spec.cctHeight*0.5

    spec.kinematicCollisionMask = 4     -- 2147483648 + 1048576 + 4
    spec.movementCollisionMask = 31     -- 2147483648 + 1048576 + 31
    if self.isServer then
        -- CCT
        local mass = self.components[1].defaultMass * 1000
        spec.cctNode = createTransformGroup("cctDrivable")
        link(getRootNode(), spec.cctNode)
        spec.controllerIndex = createCCT(spec.cctNode, spec.cctRadius, spec.cctHeight, spec.cctStepOffset, spec.cctSlopeLimit, 0.1, spec.kinematicCollisionMask, mass)
    end
end


---Called on deleting
function CCTDrivable:onDelete()
    local spec = self.spec_cctdrivable

    if spec.controllerIndex ~= nil then
        removeCCT(spec.controllerIndex)
        delete(spec.cctNode)
    end
end


---
function CCTDrivable:moveCCT(moveX, moveY, moveZ)
    if self.isServer then
        local spec = self.spec_cctdrivable
        -- move cct
        -- print(string.format("-- [CCTDrivable:moveCCT][%d] physIndex(%d) move(%.6f, %.6f, %.6f) physDt(%.6f) physDtNoInterp(%.6f) physDtUnclamp(%.6f)", g_updateLoopIndex, getPhysicsUpdateIndex(), moveX, moveY, moveZ, g_physicsDt, g_physicsDtNonInterpolated, g_physicsDtUnclamped))
        moveCCT(spec.controllerIndex, moveX, moveY, moveZ, spec.movementCollisionMask)
        self:raiseActive()
    end
end


---
-- @return int returns the CCT index
function CCTDrivable:getIsCCTOnGround()
    local spec = self.spec_cctdrivable
    if self.isServer then
        local _, _, isOnGround = getCCTCollisionFlags(spec.controllerIndex)
        return isOnGround
    end
    return false
end


---
-- @return int returns the collision mask
function CCTDrivable:getCCTCollisionMask()
    local spec = self.spec_cctdrivable
    return spec.kinematicCollisionMask
end


---
-- @return float x position of center of CCT
-- @return float y position of center of CCT
-- @return float z position of center of CCT
function CCTDrivable:getCCTWorldTranslation()
    local spec = self.spec_cctdrivable
    local cctX, cctY, cctZ = getTranslation(spec.cctNode)
    cctY = cctY-spec.cctCenterOffset
    return cctX, cctY, cctZ
end


---Set world position and rotation of component
-- @param float x x position
-- @param float y y position
-- @param float z z position
-- @param float xRot x rotation
-- @param float yRot y rotation
-- @param float zRot z rotation
-- @param integer i index if component
-- @param boolean changeInterp change interpolation
function CCTDrivable:setWorldPosition(superFunc, x,y,z, xRot,yRot,zRot, i, changeInterp)
    superFunc(self, x,y,z, xRot,yRot,zRot, i, changeInterp)
    if self.isServer and i == 1 then
        local spec = self.spec_cctdrivable
        setTranslation(spec.cctNode, x, y + spec.cctCenterOffset, z)
    end
end


---Set world position and quaternion rotation of component
-- @param float x x position
-- @param float y y position
-- @param float z z position
-- @param float qx x rotation
-- @param float qy y rotation
-- @param float qz z rotation
-- @param float qw w rotation
-- @param Integer i index if component
-- @param boolean changeInterp change interpolation
function CCTDrivable:setWorldPositionQuaternion(superFunc, x, y, z, qx, qy, qz, qw, i, changeInterp)
    superFunc(self, x, y, z, qx, qy, qz, qw, i, changeInterp)
    if self.isServer and i == 1 then
        local spec = self.spec_cctdrivable
        setTranslation(spec.cctNode, x, y + spec.cctCenterOffset, z)
    end
end
