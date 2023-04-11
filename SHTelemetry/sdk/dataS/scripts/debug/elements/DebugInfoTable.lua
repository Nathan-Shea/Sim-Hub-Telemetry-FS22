









local DebugInfoTable_mt = Class(DebugInfoTable)


---
function DebugInfoTable.new(customMt)
    local self = setmetatable({}, customMt or DebugInfoTable_mt)

    self.x, self.y, self.z = 0, 0, 0
    self.rotX, self.rotY, self.rotZ = 0, 0, 0
    self.r, self.g, self.b, self.a = 1, 1, 1, 1
    self.size = 0.25

    self.text = nil
    self.alignToGround = false

    return self
end








---
function DebugInfoTable:draw()
    setTextDepthTestEnabled(false)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextColor(self.r, self.g, self.b, self.a)
    setTextBold(false)

    local yOffset = 0
    for i=#self.information, 1, -1 do
        local info = self.information[i]
        local title = info.title
        local content = info.content

        for j=#content, 1, -1 do
            local pair = content[j]
            local key = pair.name
            local value = pair.value

            setTextAlignment(RenderText.ALIGN_RIGHT)
            renderText3D(self.x, self.y+yOffset, self.z, self.rotX, self.rotY, self.rotZ, self.size, key)
            setTextAlignment(RenderText.ALIGN_LEFT)
            if type(value) == "number" then
                renderText3D(self.x, self.y+yOffset, self.z, self.rotX, self.rotY, self.rotZ, self.size, " " ..string.format("%.4f", value))
            else
                renderText3D(self.x, self.y+yOffset, self.z, self.rotX, self.rotY, self.rotZ, self.size, " " ..tostring(value))
            end
            yOffset = yOffset + self.size
        end

        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        renderText3D(self.x, self.y+yOffset, self.z, self.rotX, self.rotY, self.rotZ, self.size, title)
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
        yOffset = yOffset + 2*self.size
    end

    setTextDepthTestEnabled(true)
end


---
function DebugInfoTable:createWithNode(node, info, size)
    local x, y, z = getWorldTranslation(node)
    local rotX, rotY, rotZ = getWorldRotation(node)

    return self:createWithWorldPosAndRot(x, y, z, rotX, rotY, rotZ, info, size)
end


---
function DebugInfoTable:createWithNodeToCamera(node, yOffset, info, size)
    local x, y, z = localToWorld(node, 0, yOffset, 0)
    local cx, cy, cz = getWorldTranslation(getCamera())
    local dirX, _, dirZ = MathUtil.vector3Normalize(cx-x, cy-y, cz-z)
    local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ)

    return self:createWithWorldPosAndRot(x, y, z, 0, rotY, 0, info, size)
end


---
function DebugInfoTable:createWithWorldPosAndRot(x, y, z, rotX, rotY, rotZ, info, size)
    self.x, self.y, self.z = x, y, z
    self.rotX, self.rotY, self.rotZ = rotX, rotY, rotZ
    self.information = info
    self.size = size * 2.5

    return self
end
