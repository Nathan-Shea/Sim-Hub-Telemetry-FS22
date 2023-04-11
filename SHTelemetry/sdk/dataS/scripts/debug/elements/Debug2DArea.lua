










local Debug2DArea_mt = Class(Debug2DArea)


---
function Debug2DArea.new(filled, doubleSided, color, alignToTerrain, customMt)
    local self = setmetatable({}, customMt or Debug2DArea_mt)

    self.color = color or {1, 1, 1, 1}
    self.filled = Utils.getNoNil(filled, false)
    self.alignToTerrain = Utils.getNoNil(alignToTerrain, true)
    self.doubleSided = Utils.getNoNil(doubleSided, false)

    self.positionNodes = {
        {-1, 0, -1},
        { 1, 0, -1},
        { 1, 0,  1},
        {-1, 0,  1},
        {-1, 0, -1},
        { 1, 0, -1},
        { 1, 0,  1},
        {-1, 0,  1}
    }

    return self
end
































































































---
function Debug2DArea:createSimple(x, y, z, size)
    return self:createFromPosAndDir(x, y, z, 0, 0, 1, 0, 1, 0, size, size)
end


---
function Debug2DArea:createWithSizeAndOffset(node, width, length, widthOffset, lengthOffset)
    local dirX, dirY, dirZ = localDirectionToWorld(node, 0, 0, 1)
    local upX, upY, upZ = localDirectionToWorld(node, 0, 1, 0)
    local x, y, z = getWorldTranslation(node)

    x, y, z = MathUtil.transform(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, widthOffset, 0, lengthOffset)

    return self:createFromPosAndDir(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, width, length)
end


---
function Debug2DArea:createFromPosAndDir(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, width, length)
    local halfWidth = width*0.5
    local halfLength = length*0.5

    local pos = self.positionNodes
    pos[1] = {MathUtil.transform(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, -halfWidth, 0, -halfLength)}
    pos[2] = {MathUtil.transform(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, -halfWidth, 0,  halfLength)}
    pos[3] = {MathUtil.transform(x, y, z, dirX, dirY, dirZ, upX, upY, upZ,  halfWidth, 0,  halfLength)}
    pos[4] = {MathUtil.transform(x, y, z, dirX, dirY, dirZ, upX, upY, upZ,  halfWidth, 0, -halfLength)}

    return self
end
