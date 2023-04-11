










local PlayerStatePickup_mt = Class(PlayerStatePickup, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStatePickup.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStatePickup_mt)

    return self
end


---
-- @return bool true if player can idle
function PlayerStatePickup:isAvailable()
    if self.player.isClient and self.player.isEntered and not self.player:hasHandtoolEquipped() then
        if not self.player.isCarryingObject and self.player.isObjectInRange then
            if self.player.lastFoundObjectMass <= self.player.maxPickableMass then
                return true
            else
                g_currentMission:addExtraPrintText(g_i18n:getText("warning_objectTooHeavy"))
            end
        end
    end
    return false
end


---Activate method.
function PlayerStatePickup:activate()
    PlayerStatePickup:superClass().activate(self)

    self.player:pickUpObject(true)
    self:deactivate()
end
