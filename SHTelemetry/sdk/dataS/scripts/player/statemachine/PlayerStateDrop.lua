










local PlayerStateDrop_mt = Class(PlayerStateDrop, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateDrop.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateDrop_mt)

    return self
end


---
-- @return bool true if player can idle
function PlayerStateDrop:isAvailable()
    if self.player.isCarryingObject then
        return true
    end
    return false
end


---Activate method.
function PlayerStateDrop:activate()
    PlayerStateDrop:superClass().activate(self)

    self.player:pickUpObject(false)
    self:deactivate()
end
