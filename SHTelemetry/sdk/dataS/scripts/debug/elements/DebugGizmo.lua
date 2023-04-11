









local DebugGizmo_mt = Class(DebugGizmo)


---
function DebugGizmo.new(customMt)
    local self = setmetatable({}, customMt or DebugGizmo_mt)

--    Y   Z
--    ^  /
--    | /
--    |/____> X

    self.x, self.y, self.z = 0, 0, 0
    self.normX, self.normY, self.normZ = 1, 0, 0
    self.upX, self.upY, self.upZ    = 0, 1, 0
    self.dirX, self.dirY, self.dirZ = 0, 0, 1
    self.scale = 1
    self.solid = true

    self.text = nil
    self.textOffset = {x=0, y=0, z=0}
    self.textColor = nil
    self.alignToGround = false
    self.hideWhenGuiIsOpen = false

    return self
end








---
function DebugGizmo:draw()
    if self.hideWhenGuiIsOpen and g_gui:getIsGuiVisible() then
        return
    end
    local x, y, z = self.x, self.y, self.z
    local normX, normY, normZ = self.normX, self.normY, self.normZ
    local upX, upY, upZ = self.upX, self.upY, self.upZ
    local dirX, dirY, dirZ = self.dirX, self.dirY, self.dirZ
    local scale = self.scale
    local solid = self.solid

    drawDebugLine(x, y, z, 1, 0, 0, x + scale*normX, y + scale*normY, z + scale*normZ, 1, 0, 0, solid)
    drawDebugLine(x, y, z, 0, 1, 0, x + scale*upX,   y + scale*upY,   z + scale*upZ,   0, 1, 0, solid)
    drawDebugLine(x, y, z, 0, 0, 1, x + scale*dirX,  y + scale*dirY,  z + scale*dirZ,  0, 0, 1, solid)

    if self.text ~= nil then
        Utils.renderTextAtWorldPosition(x + self.textOffset.x, y + self.textOffset.y, z + self.textOffset.z, tostring(self.text), getCorrectTextSize(0.012), 0, self.textColor)
    end
end


---
function DebugGizmo:createWithNode(node, text, alignToGround, textOffset, scale, solid, hideWhenGUIOpen)
    local x, y, z = getWorldTranslation(node)
    local upX, upY, upZ    = localDirectionToWorld(node, 0, 1, 0)
    local dirX, dirY, dirZ = localDirectionToWorld(node, 0, 0, 1)

    return self:createWithWorldPosAndDir(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, text, alignToGround, textOffset, scale, solid, hideWhenGUIOpen)
end


---
function DebugGizmo:createWithWorldPosAndDir(x, y, z, dirX, dirY, dirZ, upX, upY, upZ, text, alignToGround, textOffset, scale, solid, hideWhenGUIOpen)

    if alignToGround and g_currentMission.terrainRootNode ~= nil then
        y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 0.1
    end

    self.x, self.y, self.z = x, y, z
    self.dirX, self.dirY, self.dirZ = dirX, dirY, dirZ
    self.upX, self.upY, self.upZ = upX, upY, upZ
    self.normX, self.normY, self.normZ = MathUtil.crossProduct(upX, upY, upZ, dirX, dirY, dirZ)
    self.text = text
    self.scale = scale or 1
    self.solid = Utils.getNoNil(solid, self.solid)

    if textOffset then
        self.textOffset.x = textOffset.x or self.textOffset.x
        self.textOffset.y = textOffset.y or self.textOffset.y
        self.textOffset.z = textOffset.z or self.textOffset.z
    end
    self.alignToGround = Utils.getNoNil(alignToGround, self.alignToGround)
    self.hideWhenGuiIsOpen = Utils.getNoNil(hideWhenGUIOpen, self.hideWhenGuiIsOpen)

    return self
end


---
function DebugGizmo:setColor(r, g, b, a)

    self.textColor = {r or 1, g or 1, b or 1, a or 1}

    return self
end
