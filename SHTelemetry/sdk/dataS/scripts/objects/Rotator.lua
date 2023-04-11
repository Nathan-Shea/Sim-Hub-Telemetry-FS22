---s rotate around their y axis






local Rotator_mt = Class(Rotator)


---Creating rotator
-- @param integer id node id
function Rotator:onCreate(id)
    g_currentMission:addUpdateable(Rotator.new(id))
end


---Creating rotator
-- @param integer name node id
-- @return table instance Instance of object
function Rotator.new(name)
    local self = {}
    setmetatable(self, Rotator_mt)

    self.axisTable = {0, 0, 0}
    self.me = name
    self.speed = Utils.getNoNil(getUserAttribute(name, "speed"), 0.0012)
    local axis = Utils.getNoNil(getUserAttribute(name, "axis"), 3)
    self.axisTable[axis] = 1

    return self
end





---Update
-- @param float dt time since last call in ms
function Rotator:update(dt)
    rotate(self.me, self.axisTable[1] * self.speed * dt, self.axisTable[2] * self.speed * dt, self.axisTable[3] * self.speed * dt)
end
