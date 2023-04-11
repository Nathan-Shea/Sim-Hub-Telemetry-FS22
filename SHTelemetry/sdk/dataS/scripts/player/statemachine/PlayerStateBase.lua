










local PlayerStateBase_mt = Class(PlayerStateBase)


---Creating instance of player state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @param table custom_mt meta table
-- @return table instance instance of object
function PlayerStateBase.new(player, stateMachine, custom_mt)
    if custom_mt == nil then
        custom_mt = PlayerStateBase_mt
    end
    local self = setmetatable({}, custom_mt)

    self.isActive = false
    self.isInDebugMode = false
    self.player = player
    self.stateMachine = stateMachine

    return self
end


---Load method
function PlayerStateBase:delete()
end


---Load method
function PlayerStateBase:load()
end


---Activate method
function PlayerStateBase:activate()
    self.isActive = true
end


---Deactivate method
function PlayerStateBase:deactivate()
    self.isActive = false
end


---Toggle debug mode
function PlayerStateBase:toggleDebugMode()
    if self.isInDebugMode then
        self.isInDebugMode= false
    else
        self.isInDebugMode= true
    end
end


---Check if we are in debug mode
function PlayerStateBase:inDebugMode()
    return self.isInDebugMode
end


---
function PlayerStateBase:debugDraw(dt)
end


---Get manager
function PlayerStateBase:getStateMachine()
    return self.stateMachine
end


---Update method
-- @param float dt delta time in ms
function PlayerStateBase:update(dt)
end


---Network tick update method
-- @param float dt delta time in ms
function PlayerStateBase:updateTick(dt)
end
