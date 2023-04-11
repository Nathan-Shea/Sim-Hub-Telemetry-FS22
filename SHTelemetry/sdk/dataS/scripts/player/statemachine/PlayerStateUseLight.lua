










local PlayerStateUseLight_mt = Class(PlayerStateUseLight, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateUseLight.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateUseLight_mt)

    return self
end


---
-- @return bool true if player can idle
function PlayerStateUseLight:isAvailable()
    if self.player.model:getHasTorch() and not g_currentMission:isInGameMessageActive() then
        return true
    end
    return false
end


---Activate method.
function PlayerStateUseLight:activate()
    PlayerStateUseLight:superClass().activate(self)

    self.player:setLightIsActive(not self.player.isTorchActive)
    self:deactivate()
end
