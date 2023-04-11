










local DebugDensityMap_mt = Class(DebugDensityMap)


---
function DebugDensityMap.new(densityMap, firstChannel, numChannels, radius, yOffset, colors, customMt)
    local self = setmetatable({}, customMt or DebugDensityMap_mt)

    local size = getDensityMapSize(densityMap)
    self.resolution = g_currentMission.terrainSize / size
    self.firsChannel = firstChannel
    self.numChannels = numChannels

    self.colors = colors

    self.radius = radius
    self.yOffset = yOffset or 0.1

    self.modifier = DensityMapModifier.new(densityMap, firstChannel, numChannels, g_currentMission.terrainNode)
    self.filter = DensityMapFilter.new(self.modifier)

    return self
end






















































































---
function DebugDensityMap:drawDebugAreaRectangleFilled(x, z, x1, z1, x2, z2, r, g, b, a)
    local x3, z3 = x1, z2

    local y =  getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)   + self.yOffset
    local y1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 0, z1) + self.yOffset
    local y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2, 0, z2) + self.yOffset
    local y3 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x3, 0, z3) + self.yOffset

    drawDebugTriangle(x, y, z, x2, y2, z2, x1, y1, z1, r, g, b, a, false)
    drawDebugTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, false)
end
