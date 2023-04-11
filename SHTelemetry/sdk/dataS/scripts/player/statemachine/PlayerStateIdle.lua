










local PlayerStateIdle_mt = Class(PlayerStateIdle, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateIdle.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateIdle_mt)

    return self
end


---Check if state is available. Always true
-- @return bool true if player can idle
function PlayerStateIdle:isAvailable()
    return true
end


---Update method. Will deactivate if player moves or if not on the ground.
-- @param float dt delta time in ms
function PlayerStateIdle:update(dt)
    local playerInputsCheck = (math.abs(self.player.inputInformation.moveForward) > 0.01) or (math.abs(self.player.inputInformation.moveRight) > 0.01)

    if playerInputsCheck or not self.player.baseInformation.isOnGround then
        self:deactivate()
    end
end
