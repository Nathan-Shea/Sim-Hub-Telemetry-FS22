










local PlayerStateWalk_mt = Class(PlayerStateWalk, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateWalk.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateWalk_mt)

    return self
end


---Check if state is available
-- @return bool true if player can swim
function PlayerStateWalk:isAvailable()
    return self:canWalk()
end


---Update method. Will deactivate if player is not moving anymore or if he starts running.
-- @param float dt delta time in ms
function PlayerStateWalk:update(dt)
    local playerInputsCheck = (math.abs(self.player.inputInformation.moveForward) > 0.01) or (math.abs(self.player.inputInformation.moveRight) > 0.01)

    if not self:canWalk() or not playerInputsCheck then
        self:deactivate()
    end
end


---Check if player is on the ground and he is not running
-- @return bool true if player can swim
function PlayerStateWalk:canWalk()
    local isRunning = (self.player.inputInformation.runAxis ~= 0.0)

    return self.player.baseInformation.isOnGround and not isRunning
end
