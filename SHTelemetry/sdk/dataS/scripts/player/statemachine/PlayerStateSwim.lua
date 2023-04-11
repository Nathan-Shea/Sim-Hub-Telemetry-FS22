










local PlayerStateSwim_mt = Class(PlayerStateSwim, PlayerStateBase)



---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateSwim.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateSwim_mt)

    return self
end


---Check if state is available if player is in water
-- @return bool true if player can swim
function PlayerStateSwim:isAvailable()
    local isInWater = self.player.baseInformation.isInWater

    if isInWater then
        return true
    end
    return false
end


---Update method. Will deactivate if player is not in water anymore
-- @param float dt delta time in ms
function PlayerStateSwim:update(dt)
    if not self.player.baseInformation.isInWater then
        self:deactivate()
    end
end
