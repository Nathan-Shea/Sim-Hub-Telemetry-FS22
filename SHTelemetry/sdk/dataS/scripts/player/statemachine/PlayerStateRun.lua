










local PlayerStateRun_mt = Class(PlayerStateRun, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateRun.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateRun_mt)

    return self
end


---Check if state is available.
-- @return bool true if player can run
function PlayerStateRun:isAvailable()
    return self:canRun()
end


---Update method. Will deactivate if player stops moving, is not on the ground or if the run input is not pressed.
-- @param float dt delta time in ms
function PlayerStateRun:update(dt)
    local playerInputsCheck = (self.player.inputInformation.runAxis ~= 0.0) and ((math.abs(self.player.inputInformation.moveForward) > 0.01) or (math.abs(self.player.inputInformation.moveRight) > 0.01))

    if (self:canRun() == false) or (playerInputsCheck == false) then
        self:deactivate()
    end
end


---Check that player is on the ground.
-- @return bool true if player can run
function PlayerStateRun:canRun()
    return self.player.baseInformation.isOnGround
end
