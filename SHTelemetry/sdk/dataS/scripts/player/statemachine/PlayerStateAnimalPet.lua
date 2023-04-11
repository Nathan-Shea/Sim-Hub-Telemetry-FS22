










local PlayerStateAnimalPet_mt = Class(PlayerStateAnimalPet, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateAnimalPet.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateAnimalPet_mt)

    self.dog = nil

    return self
end


---Check if we can pet an animal.
-- @return bool returns true if player can pet an animal
function PlayerStateAnimalPet:isAvailable()
    self.dog = nil
    if self.player.isClient and self.player.isEntered and not g_gui:getIsGuiVisible() then
        local playerHandsEmpty = self.player.baseInformation.currentHandtool == nil and not self.player.isCarryingObject
        local dogHouse = g_currentMission:getDoghouse(self.player.farmId)
        if dogHouse == nil then
            return false
        end

        local dog = dogHouse:getDog()
        if dog == nil then
            return false
        end

        local _, playerY, _ = getWorldTranslation(self.player.rootNode)
        playerY = playerY - self.player.model.capsuleTotalHeight * 0.5
        local deltaWater = playerY - self.player.waterY
        local playerInWater = deltaWater < 0.0
        local playerInDogRange = dog.playersInRange[self.player.rootNode] ~= nil

        if playerHandsEmpty and not playerInWater and playerInDogRange then
            self.dog = dog
            return true
        end
    end
    return false
end


---Activate method
function PlayerStateAnimalPet:activate()
    PlayerStateAnimalPet:superClass().activate(self)

    if self.dog ~= nil then
        self.dog:pet()
    end

    self:deactivate()
end


---Deactivate method
function PlayerStateAnimalPet:deactivate()
    PlayerStateAnimalPet:superClass().deactivate(self)
    self.dog = nil
end
