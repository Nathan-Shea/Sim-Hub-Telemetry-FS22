










local DebugBitVectorMap_mt = Class(DebugBitVectorMap)


---
function DebugBitVectorMap.new(radius, resolution, opacity, yOffset, customMt)
    local self = setmetatable({}, customMt or DebugBitVectorMap_mt)

    self.radius = radius or 15
    self.resolution = resolution or 0.5

    self.colorPos = {0, 1, 0, opacity}
    self.colorNeg = {1, 0, 0, opacity}

    self.yOffset = yOffset or 0.1

    return self
end































































---
function DebugBitVectorMap:drawDebugAreaRectangleFilled(x, z, x1, z1, x2, z2, r, g, b, a)
    local x3, z3 = x1, z2

    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + self.yOffset
    local y1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 0, z1) + self.yOffset
    local y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2, 0, z2) + self.yOffset
    local y3 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x3, 0, z3) + self.yOffset

    drawDebugTriangle(x, y, z, x2, y2, z2, x1, y1, z1, r, g, b, a, false)
    drawDebugTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, false)
end
