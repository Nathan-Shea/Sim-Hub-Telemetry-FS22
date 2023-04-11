










local PlayerStateThrow_mt = Class(PlayerStateThrow, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateThrow.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateThrow_mt)

    return self
end


---
-- @return bool true if player can idle
function PlayerStateThrow:isAvailable()
    if self.player.isClient and self.player.isEntered and not self.player:hasHandtoolEquipped() then
        if self.player.isCarryingObject or (not self.player.isCarryingObject and (self.player.isObjectInRange and self.player.lastFoundObject ~= nil)) then
            if self.player.lastFoundObjectMass <= self.player.maxPickableMass then
                return true
            end
        end
    end
    return false
end


---Activate method.
function PlayerStateThrow:activate()
    PlayerStateThrow:superClass().activate(self)

    self.player:throwObject()
    self:deactivate()
end
