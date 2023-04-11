










local PlayerStateMachine_mt = Class(PlayerStateMachine)


---Creating instance of player state machine. Initializing member variables: player states and a table containing those states.
-- @param table player instance of player
-- @param table custom_mt meta table
-- @return table instance instance of object
function PlayerStateMachine.new(player, custom_mt)
    if custom_mt == nil then
        custom_mt = PlayerStateMachine_mt
    end
    local self = setmetatable({}, custom_mt)
    self.player = player

    -- State Machine information
    self.playerStateIdle            = PlayerStateIdle.new(self.player, self)
    self.playerStateWalk            = PlayerStateWalk.new(self.player, self)
    self.playerStateRun             = PlayerStateRun.new(self.player, self)
    self.playerStateJump            = PlayerStateJump.new(self.player, self)
    self.playerStateSwim            = PlayerStateSwim.new(self.player, self)
    self.playerStateFall            = PlayerStateFall.new(self.player, self)
    self.playerStateCrouch          = PlayerStateCrouch.new(self.player, self)
    self.playerStateAnimalInteract  = PlayerStateAnimalInteract.new(self.player, self)
    self.playerStateAnimalRide      = PlayerStateAnimalRide.new(self.player, self)
    self.playerStateAnimalPet       = PlayerStateAnimalPet.new(self.player, self)
    self.playerStatePickup          = PlayerStatePickup.new(self.player, self)
    self.playerStateDrop            = PlayerStateDrop.new(self.player, self)
    self.playerStateThrow           = PlayerStateThrow.new(self.player, self)
    self.playerStateUseLight        = PlayerStateUseLight.new(self.player, self)
    self.playerStateCycleHandtool   = PlayerStateCycleHandtool.new(self.player, self)

    self.stateList = {  ["idle"]            = self.playerStateIdle,
                        ["walk"]            = self.playerStateWalk,
                        ["run"]             = self.playerStateRun,
                        ["jump"]            = self.playerStateJump,
                        ["swim"]            = self.playerStateSwim,
                        ["fall"]            = self.playerStateFall,
                        ["crouch"]          = self.playerStateCrouch,
                        ["animalInteract"]  = self.playerStateAnimalInteract,
                        ["animalRide"]      = self.playerStateAnimalRide,
                        ["animalPet"]       = self.playerStateAnimalPet,
                        ["pickup"]          = self.playerStatePickup,
                        ["drop"]            = self.playerStateDrop,
                        ["throw"]           = self.playerStateThrow,
                        ["useLight"]        = self.playerStateUseLight,
                        ["cycleHandtool"]   = self.playerStateCycleHandtool,
                    }

    -- field [from][to] : allowed
    self.fsmTable = {}
    self.fsmTable["walk"] = {}
    self.fsmTable["walk"]["jump"]   = true
    self.fsmTable["walk"]["run"]    = true
    self.fsmTable["walk"]["swim"]   = true
    self.fsmTable["walk"]["crouch"] = true
    self.fsmTable["walk"]["pickup"] = true
    self.fsmTable["walk"]["drop"] = true
    self.fsmTable["walk"]["throw"] = true
    self.fsmTable["walk"]["useLight"] = true
    self.fsmTable["walk"]["cycleHandtool"] = true
    self.fsmTable["run"] = {}
    self.fsmTable["run"]["jump"]    = true
    self.fsmTable["run"]["swim"]   = true
    self.fsmTable["run"]["pickup"] = true
    self.fsmTable["run"]["drop"] = true
    self.fsmTable["run"]["throw"] = true
    self.fsmTable["run"]["useLight"] = true
    self.fsmTable["run"]["cycleHandtool"] = true
    self.fsmTable["run"]["crouch"] = true
    self.fsmTable["crouch"] = {}
    self.fsmTable["crouch"]["walk"] = true
    self.fsmTable["crouch"]["jump"] = true
    self.fsmTable["crouch"]["swim"] = true
    self.fsmTable["crouch"]["animalInteract"] = true
    self.fsmTable["crouch"]["animalRide"] = true
    self.fsmTable["crouch"]["animalPet"] = true
    self.fsmTable["crouch"]["pickup"] = true
    self.fsmTable["crouch"]["drop"] = true
    self.fsmTable["crouch"]["throw"] = true
    self.fsmTable["crouch"]["useLight"] = true
    self.fsmTable["crouch"]["cycleHandtool"] = true
    self.fsmTable["fall"] = {}
    self.fsmTable["fall"]["swim"]   = true
    self.fsmTable["fall"]["useLight"] = true
    self.fsmTable["jump"] = {}
    self.fsmTable["idle"] = {}
    self.fsmTable["idle"]["jump"]  = true
    self.fsmTable["idle"]["crouch"] = true
    self.fsmTable["idle"]["walk"] = true
    self.fsmTable["idle"]["run"] = true
    self.fsmTable["idle"]["animalInteract"] = true
    self.fsmTable["idle"]["animalRide"] = true
    self.fsmTable["idle"]["animalPet"] = true
    self.fsmTable["idle"]["pickup"] = true
    self.fsmTable["idle"]["drop"] = true
    self.fsmTable["idle"]["throw"] = true
    self.fsmTable["idle"]["useLight"] = true
    self.fsmTable["idle"]["cycleHandtool"] = true
    self.fsmTable["swim"] = {}
    self.fsmTable["swim"]["walk"] = true
    self.fsmTable["swim"]["run"] = true
    self.fsmTable["swim"]["useLight"] = true
    self.fsmTable["animalInteract"] = {}
    self.fsmTable["animalInteract"]["crouch"] = true
    self.fsmTable["animalInteract"]["idle"] = true
    self.fsmTable["animalInteract"]["walk"] = true
    self.fsmTable["animalInteract"]["run"] = true
    self.fsmTable["animalPet"] = {}
    self.fsmTable["animalPet"]["crouch"] = true
    self.fsmTable["animalPet"]["idle"] = true
    self.fsmTable["animalPet"]["walk"] = true
    self.fsmTable["animalPet"]["run"] = true

    self.debugMode = false
    return self
end


---Methods for deleting player state machine
function PlayerStateMachine:delete()
    if self.player.isOwner then
        removeConsoleCommand("gsPlayerFsmDebug")
    end

    for _, stateInstance in pairs(self.stateList) do
        stateInstance:delete()
        stateInstance = {}
    end
end


---Returns a player state
-- @param string stateName name of the state to search for
-- @return table player state
function PlayerStateMachine:getState(stateName)
    return self.stateList[stateName]
end


---Check if a player state is available and not already active.
-- @param string stateName 
-- @return bool true if player state is available
function PlayerStateMachine:isAvailable(stateName)
    if self.stateList[stateName] ~= nil  then
        local result = (self.stateList[stateName].isActive == false) and self.stateList[stateName]:isAvailable()

        return result
    end
    return false
end


---Check if a player state is active
-- @param string stateName 
-- @return bool true if player state is active
function PlayerStateMachine:isActive(stateName)
    if self.stateList[stateName] ~= nil  then
        return self.stateList[stateName].isActive
    end
    return false
end


---Execute all update methods of active player states
-- @param float dt delta time in ms
function PlayerStateMachine:update(dt)
    for stateName, stateInstance in pairs(self.stateList) do
        if stateInstance.isActive then
            stateInstance:update(dt)
        end
    end
end


---Execute all update methods when network tick of active player states
-- @param float dt delta time in ms
function PlayerStateMachine:updateTick(dt)
    for stateName, stateInstance in pairs(self.stateList) do
        if stateInstance.isActive then
            stateInstance:updateTick(dt)
        end
    end
end


---Execute all debug draw methods. Displays is states are active and available. Also draw internal player state debug method.
-- @param float dt delta time in ms
function PlayerStateMachine:debugDraw(dt)
    if self.debugMode then
        setTextColor(1, 1, 0, 1)
        renderText(0.05, 0.60, 0.02, "[state machine]")
        local i = 0
        for stateName, stateInstance in pairs(self.stateList) do
            renderText(0.05, 0.58 - i * 0.02 , 0.02, string.format("- %s active(%s) isAvailable(%s)", stateName, tostring(stateInstance.isActive), tostring(stateInstance:isAvailable())))
            i = i + 1
        end
    end

    for stateName, stateInstance in pairs(self.stateList) do
        if stateInstance.inDebugMode(self) then
            stateInstance:debugDraw(dt)
        end
    end
end


---Activates a player state. Checks if active states allows to use the player state we want to activate. If allowed, the state is activated.
-- @param string stateNameTo the player state we want to activate
function PlayerStateMachine:activateState(stateNameTo)
    local allowed = true

    for stateNameFrom, stateInstance in pairs(self.stateList) do
        if stateInstance.isActive and (self.fsmTable[stateNameFrom] == nil or not self.fsmTable[stateNameFrom][stateNameTo]) then
            allowed = false
            break
        end
    end

    -- if self.debugMode then
    --     print(string.format("-- [PlayerStateMachine:activateState] state(%s) allowed(%s) active(%s)", stateNameTo, tostring(allowed), tostring(self.stateList[stateNameTo].isActive)))
    -- end
    if allowed and (self.stateList[stateNameTo] ~= nil) and (self.stateList[stateNameTo].isActive == false) then
        self.stateList[stateNameTo]:activate()
    end
end


---Deactivates a player state
-- @param string stateName 
function PlayerStateMachine:deactivateState(stateName)
    if (self.stateList[stateName] ~= nil) and (self.stateList[stateName].isActive == true) then
        self.stateList[stateName]:deactivate()
    end
end


---Loads states
function PlayerStateMachine:load()
    for _, stateInstance in pairs(self.stateList) do
        stateInstance:load()
    end

    -- Console commands
    -- self.player.isOwner is init at this point
    if self.player.isOwner then
        addConsoleCommand("gsPlayerFsmDebug", "Toggle debug mode for player state machine", "consoleCommandDebugFinalStateMachine", self)
    end
end


---Console command to toggle debug of player state machine
function PlayerStateMachine:consoleCommandDebugFinalStateMachine()
    if self.debugMode then
        self.debugMode = false
    else
        self.debugMode = true
    end
end
