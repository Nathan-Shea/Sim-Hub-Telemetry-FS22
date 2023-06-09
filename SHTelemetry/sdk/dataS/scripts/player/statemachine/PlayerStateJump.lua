










local PlayerStateJump_mt = Class(PlayerStateJump, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateJump.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateJump_mt)

    -- debug code
    self.playerPos = {}
    self.jumpDuration = 0.0

    return self
end


---
function PlayerStateJump:delete()
    if self.player.isOwner then
        removeConsoleCommand("gsPlayerFsmStateJumpDebug")
    end
end


---Load method
function PlayerStateJump:load()
    if self.player.isOwner then
        addConsoleCommand("gsPlayerFsmStateJumpDebug", "Toggle debug mode for Jump", "consoleCommandDebugStateJump", self)
    end
end


---Check if state is available. Check that player is on the ground.
-- @return bool true if player can jump
function PlayerStateJump:isAvailable()
    if self.player:hasHandtoolEquipped() and self.player.baseInformation.currentHandtool:isBeingUsed() then
        return false
    end
    local isOnGround = self.player.baseInformation.isOnGround
    return isOnGround and not g_currentMission:isInGameMessageActive()
end


---Activate method. Set vertical velocity.
function PlayerStateJump:activate()
    PlayerStateJump:superClass().activate(self)

    local velY = math.sqrt(-2.0 * self.player.motionInformation.gravity * self.player.motionInformation.jumpHeight)
    local jumpFactor = 2.0
    self.player.motionInformation.currentSpeedY = velY * jumpFactor

    if self:inDebugMode() then
        self.playerPos = {}
        self.jumpDuration = 0.0
    end
end


---Deactivate method.
function PlayerStateJump:deactivate()
    PlayerStateJump:superClass().deactivate(self)

    self.jumpWeight = 0
end


---Update method. If the fall player state is available, we deactive this state.
-- @param float dt delta time in ms
function PlayerStateJump:update(dt)
    if self.stateMachine:isAvailable("fall") or (self.player.baseInformation.isOnGround and self.player.motionInformation.currentSpeedY <= 0.0) then
        if self:inDebugMode() then
            local startPos = self.playerPos[1]
            local endPos = self.playerPos[#self.playerPos]
            local delta = endPos[2] - startPos[2]
            print(string.format("[PlayerStateJump:update] End jump / duration(%.4f s) / height(%.4f).", self.jumpDuration * 0.001, delta))
        end
        self:deactivate()
    end

    -- debug code
    if self:inDebugMode() then
        local posX, posY, posZ = getWorldTranslation(g_currentMission.player.rootNode)
        local newEntry = {posX, posY, posZ}

        table.insert(self.playerPos, newEntry)
        self.jumpDuration = self.jumpDuration + dt
    end
end


---Debug draw method.
-- @param float dt delta time in ms
function PlayerStateJump:debugDraw(dt)
    for i=1, #self.playerPos do
        DebugUtil.drawDebugCircle( self.playerPos[i][1], self.playerPos[i][2], self.playerPos[i][3], 0.1, 10)
    end
end


---Console command to debug draw the jump state
function PlayerStateJump:consoleCommandDebugStateJump()
    self:toggleDebugMode()
    if self:inDebugMode() then
        self.playerPos = {}
    end
end
