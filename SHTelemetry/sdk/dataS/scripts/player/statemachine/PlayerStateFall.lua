










local PlayerStateFall_mt = Class(PlayerStateFall, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateFall.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateFall_mt)

    return self
end


---Check if state is available. If player is not on the ground and is not in water and vertical velocity lower than
-- @return bool true if state is available
function PlayerStateFall:isAvailable()
    local isOnGround = self.player.baseInformation.isOnGround
    local isInWater = self.player.baseInformation.isInWater
    local verticalVelocity = self.player.motionInformation.currentSpeedY

    if not isOnGround and not isInWater and (verticalVelocity < self.player.motionInformation.minimumFallingSpeed) then
        return true
    end
    return false
end


---Update method. Will deactivate when player hits the ground or is in water
-- @param float dt delta time in ms
function PlayerStateFall:update(dt)
    local isOnGround = self.player.baseInformation.isOnGround
    local isInWater = self.player.baseInformation.isInWater

    if isOnGround or isInWater then
        self:deactivate()
    end
end
