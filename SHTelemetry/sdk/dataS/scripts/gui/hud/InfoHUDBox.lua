---Info box









local InfoHUDBox_mt = Class(InfoHUDBox)


---
function InfoHUDBox.new(classMt, uiScale)
    local self = setmetatable({}, classMt or InfoHUDBox_mt)

    self.uiScale = uiScale

    self:setScale(uiScale)

    return self
end


---
function InfoHUDBox:delete()
end






---
function InfoHUDBox:canDraw()
    return true
end


---Get this HUD extension's display height.
-- @return float Display height in screen space
function InfoHUDBox:getDisplayHeight()
    return 0
end


---
function InfoHUDBox:draw(posX, posY)
end






---
function InfoHUDBox:setScale(uiScale)
end


---
function InfoHUDBox:storeScaledValues()
end
