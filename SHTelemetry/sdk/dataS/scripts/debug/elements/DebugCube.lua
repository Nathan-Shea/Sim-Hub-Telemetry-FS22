









local DebugCube_mt = Class(DebugCube)


---
function DebugCube.new(customMt)
    local self = setmetatable({}, customMt or DebugCube_mt)


--      8_________7
--     / |      / |
--   5/__|____6/  |           Y   Z
--    |  |     |  |           ^  /
--    | 4|_____|__|3          | /
--    | /      | /            |/____> X
--    |/_______|/
--    1        2

    self.color = {1, 1, 1}

    self.x, self.y, self.z = 0, 0, 0
    self.normX, self.normY, self.normZ = 1, 0, 0
    self.upX, self.upY, self.upZ    = 0, 1, 0
    self.dirX, self.dirY, self.dirZ = 0, 0, 1

    self.positionNodes = {
        {-1, -1, -1},
        {1, -1, -1},
        {1, -1, 1},
        {-1, -1, 1},
        {-1, 1, -1},
        {1, 1, -1},
        {1, 1, 1},
        {-1, 1, 1}
    }

    return self
end








---
function DebugCube:draw()
    local r, g, b = unpack(self.color)
    local pos = self.positionNodes

    drawDebugLine(pos[1][1], pos[1][2], pos[1][3], r, g, b, pos[2][1], pos[2][2], pos[2][3], r, g, b)
    drawDebugLine(pos[2][1], pos[2][2], pos[2][3], r, g, b, pos[3][1], pos[3][2], pos[3][3], r, g, b)
    drawDebugLine(pos[3][1], pos[3][2], pos[3][3], r, g, b, pos[4][1], pos[4][2], pos[4][3], r, g, b)
    drawDebugLine(pos[4][1], pos[4][2], pos[4][3], r, g, b, pos[1][1], pos[1][2], pos[1][3], r, g, b)

    drawDebugLine(pos[5][1], pos[5][2], pos[5][3], r, g, b, pos[6][1], pos[6][2], pos[6][3], r, g, b)
    drawDebugLine(pos[6][1], pos[6][2], pos[6][3], r, g, b, pos[7][1], pos[7][2], pos[7][3], r, g, b)
    drawDebugLine(pos[7][1], pos[7][2], pos[7][3], r, g, b, pos[8][1], pos[8][2], pos[8][3], r, g, b)
    drawDebugLine(pos[8][1], pos[8][2], pos[8][3], r, g, b, pos[5][1], pos[5][2], pos[5][3], r, g, b)

    drawDebugLine(pos[1][1], pos[1][2], pos[1][3], r, g, b, pos[5][1], pos[5][2], pos[5][3], r, g, b)
    drawDebugLine(pos[2][1], pos[2][2], pos[2][3], r, g, b, pos[6][1], pos[6][2], pos[6][3], r, g, b)
    drawDebugLine(pos[3][1], pos[3][2], pos[3][3], r, g, b, pos[7][1], pos[7][2], pos[7][3], r, g, b)
    drawDebugLine(pos[4][1], pos[4][2], pos[4][3], r, g, b, pos[8][1], pos[8][2], pos[8][3], r, g, b)

    local x, y, z = self.x, self.y, self.z
    local sideX, sideY, sideZ = self.normX, self.normY, self.normZ
    local upX, upY, upZ = self.upX, self.upY, self.upZ
    local dirX, dirY, dirZ = self.dirX, self.dirY, self.dirZ

    drawDebugLine(x, y, z, 1, 0, 0, x + sideX, y + sideY, z + sideZ, 1, 0, 0)
    drawDebugLine(x, y, z, 0, 1, 0, x + upX,   y + upY,   z + upZ,   0, 1, 0)
    drawDebugLine(x, y, z, 0, 0, 1, x + dirX,  y + dirY,  z + dirZ,  0, 0, 1)
end


---
function DebugCube:setColor(r, g, b)
    self.color = {r, g, b}

    return self
end


---
function DebugCube:createSimple(x, y, z, size)
    self:createWithWorldPosAndRot(x, y, z, 0, 0, 0, size, size, size)
end














---
function DebugCube:createWithPlacementSize(node, sizeWidth, sizeLength, widthOffset, lengthOffset, updatePosition)
    local rotX, rotY, rotZ = getWorldRotation(node)
    local x, y, z = localToWorld(node, widthOffset, 0, lengthOffset)
    self:createWithWorldPosAndRot(x, y, z, rotX, rotY, rotZ, sizeWidth, 1, sizeLength)

    return self
end


---
function DebugCube:createWithNode(node, sizeX, sizeY, sizeZ, offsetX, offsetY, offsetZ)
    local x, y, z = localToWorld(node, offsetX or 0, offsetY or 0, offsetZ or 0)
    local normX, normY, normZ = localDirectionToWorld(node, 1, 0, 0)
    local upX, upY, upZ    = localDirectionToWorld(node, 0, 1, 0)
    local dirX, dirY, dirZ = localDirectionToWorld(node, 0, 0, 1)

    self.x, self.y, self.z = x, y, z
    self.normX, self.normY, self.normZ = normX*sizeX, normY*sizeX, normZ*sizeX
    self.upX, self.upY, self.upZ = upX*sizeY, upY*sizeY, upZ*sizeY
    self.dirX, self.dirY, self.dirZ = dirX*sizeZ, dirY*sizeZ, dirZ*sizeZ

    local pos = self.positionNodes
    pos[1] = { x - self.normX - self.upX - self.dirX,
               y - self.normY - self.upY - self.dirY,
               z - self.normZ - self.upZ - self.dirZ}

    pos[2] = { x + self.normX - self.upX - self.dirX,
               y + self.normY - self.upY - self.dirY,
               z + self.normZ - self.upZ - self.dirZ}

    pos[3] = { x + self.normX - self.upX + self.dirX,
               y + self.normY - self.upY + self.dirY,
               z + self.normZ - self.upZ + self.dirZ}

    pos[4] = { x - self.normX - self.upX + self.dirX,
               y - self.normY - self.upY + self.dirY,
               z - self.normZ - self.upZ + self.dirZ}

    pos[5] = { x - self.normX + self.upX - self.dirX,
               y - self.normY + self.upY - self.dirY,
               z - self.normZ + self.upZ - self.dirZ}

    pos[6] = { x + self.normX + self.upX - self.dirX,
               y + self.normY + self.upY - self.dirY,
               z + self.normZ + self.upZ - self.dirZ}

    pos[7] = { x + self.normX + self.upX + self.dirX,
               y + self.normY + self.upY + self.dirY,
               z + self.normZ + self.upZ + self.dirZ}

    pos[8] = { x - self.normX + self.upX + self.dirX,
               y - self.normY + self.upY + self.dirY,
               z - self.normZ + self.upZ + self.dirZ}

    return self
end





















































---
function DebugCube:createWithWorldPosAndDir(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, sizeX, sizeY, sizeZ)
    local temp = createTransformGroup("temp_drawDebugCubeAtWorldPos")
    link(getRootNode(), temp)
    setTranslation(temp, x, y, z)
    setDirection(temp, dirX, dirY, dirZ, upX, upY, upZ)
    self:createWithNode(temp, sizeX, sizeY, sizeZ)
    delete(temp)

    return self
end


---
function DebugCube:createWithWorldPosAndRot(x, y, z, rotX, rotY, rotZ, sizeX, sizeY, sizeZ)
    local temp = createTransformGroup("temp_drawDebugCubeAtWorldPos")
    link(getRootNode(), temp)
    setTranslation(temp, x, y, z)
    setRotation(temp, rotX, rotY, rotZ)
    self:createWithNode(temp, sizeX, sizeY, sizeZ)
    delete(temp)

    return self
end
