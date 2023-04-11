---Class for RainDropFactorTriggers






local RainDropFactorTrigger_mt = Class(RainDropFactorTrigger)


---On create RainDropFactorTrigger
-- @param integer id id of trigger node
function RainDropFactorTrigger:onCreate(id)
    local trigger = RainDropFactorTrigger.new()
    if trigger:load(id) then
        g_currentMission:addNonUpdateable(trigger)
    else
        trigger:delete()
    end
end


---Creating RainDropFactorTrigger object
-- @param table mt custom metatable (optional)
-- @return table instance instance of basket trigger object
function RainDropFactorTrigger.new(mt)
    local self = {}
    if mt == nil then
        mt = RainDropFactorTrigger_mt
    end
    setmetatable(self, mt)

    self.triggerId = 0
    self.nodeId = 0

    return self
end


---Load RainDropFactorTrigger
-- @param integer nodeId id of node
-- @return boolean success success
function RainDropFactorTrigger:load(nodeId)
    self.nodeId = nodeId

    self.triggerId = I3DUtil.indexToObject(nodeId, getUserAttribute(nodeId, "triggerIndex"))
    if self.triggerId == nil then
        self.triggerId = nodeId
    end
    addTrigger(self.triggerId, "triggerCallback", self)

    self.triggerObjects = {}

    self.isEnabled = true

    return true
end


---Delete RainDropFactorTrigger
function RainDropFactorTrigger:delete()
    removeTrigger(self.triggerId)
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherId id of actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
function RainDropFactorTrigger:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    -- if self.isEnabled then
    --     if onEnter then
    --         if g_currentMission.environment ~= nil then
    --            g_currentMission.environment.globalRainDropFactor = 0.0
    --         end
    --     elseif onLeave then
    --         if g_currentMission.environment ~= nil then
    --            g_currentMission.environment.globalRainDropFactor = 1.0
    --         end
    --     end
    -- end
end
