---Class for InsideBuildingTriggers






local InsideBuildingTrigger_mt = Class(InsideBuildingTrigger)


---On create InsideBuildingTrigger
-- @param integer id id of trigger node
function InsideBuildingTrigger.onCreate(_, id)
    local trigger = InsideBuildingTrigger.new()
    if trigger:load(id) then
        g_currentMission:addNonUpdateable(trigger)
    else
        trigger:delete()
    end
end


---Creating InsideBuildingTrigger object
-- @param table customMt custom metatable (optional)
-- @return table instance instance of basket trigger object
function InsideBuildingTrigger.new(customMt)
    local self = {}
    setmetatable(self, customMt or InsideBuildingTrigger_mt)

    self.triggerId = 0
    self.nodeId = 0

    return self
end


---Load InsideBuildingTrigger
-- @param integer nodeId id of node
-- @return boolean success success
function InsideBuildingTrigger:load(nodeId)
    self.nodeId = nodeId

    self.triggerId = I3DUtil.indexToObject(nodeId, getUserAttribute(nodeId, "triggerIndex"))
    if self.triggerId == nil then
        self.triggerId = nodeId
    end
    addTrigger(self.triggerId, "insideBuildingTriggerCallback", self)

    self.isEnabled = true

    return true
end


---Delete InsideBuildingTrigger
function InsideBuildingTrigger:delete()
    removeTrigger(self.triggerId)
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherId id of actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
function InsideBuildingTrigger:insideBuildingTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    -- log(g_currentMission.player.rootNode, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if g_currentMission.player ~= nil and g_currentMission.player.rootNode == otherActorId then
        if self.isEnabled then
            if onEnter then
                g_currentMission:setIsInsideBuilding(true)
            elseif onLeave then
                g_currentMission:setIsInsideBuilding(false)
            end
        end
    end
end
