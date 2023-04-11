










local PlayerStateAnimalInteract_mt = Class(PlayerStateAnimalInteract, PlayerStateBase)


---Creating instance of state.
-- @param table player instance of player
-- @param table stateMachine instance of the state machine manager
-- @return table instance instance of object
function PlayerStateAnimalInteract.new(player, stateMachine)
    local self = PlayerStateBase.new(player, stateMachine, PlayerStateAnimalInteract_mt)

    self.dog = nil
    self.husbandry = nil
    self.cluster = nil

    self.castDistance = 1.5 -- in m
    self.interactText = ""
    return self
end


---Check if we can interact with an animal.
-- @return bool returns true if player can interact with an animal
function PlayerStateAnimalInteract:isAvailable()
    self.dog = nil

    if self.player.isClient and self.player.isEntered and not g_gui:getIsGuiVisible() then
        local playerHandsEmpty = self.player.baseInformation.currentHandtool == nil and not self.player.isCarryingObject
        local dogHouse = g_currentMission:getDoghouse(self.player.farmId)
        if playerHandsEmpty and dogHouse ~= nil then
            local dog = dogHouse:getDog()
            if dog ~= nil and dog.playersInRange[self.player.rootNode] ~= nil then
                self.dog = dog
                if dog.entityFollow == self.player.rootNode then
                    self.interactText = g_i18n:getText("action_interactAnimalStopFollow")
                else
                    self.interactText = g_i18n:getText("action_interactAnimalFollow")
                end

                return true
            end
        end
    end

    self:detectAnimal()

    if self.husbandry ~= nil then
        self.interactText = string.format(g_i18n:getText("action_interactAnimalClean"), self.cluster:getName())
        return true
    end

    self.interactText = ""
    return false
end


---Activate method. If animal is a dog, we pet him.
function PlayerStateAnimalInteract:activate()
    PlayerStateAnimalInteract:superClass().activate(self)

    if self.dog ~= nil then
        if self.dog.entityFollow == self.player.rootNode then
            self.dog:goToSpawn()
        else
            self.dog:followEntity(self.player)
        end

        self:deactivate()

    else
        if self.husbandry ~= nil and self.cluster ~= nil then
            g_client:getServerConnection():sendEvent(AnimalCleanEvent.new(self.husbandry, self.cluster.id))
            g_soundManager:playSample(self.player.model.soundInformation.samples.horseBrush)
            self:deactivate()
        end
    end
end


---Deactivate method
function PlayerStateAnimalInteract:deactivate()
    PlayerStateAnimalInteract:superClass().deactivate(self)
    self.dog = nil
    self.husbandry = nil
    self.cluster = nil
end











---Update method
-- @param float dt delta time in ms
function PlayerStateAnimalInteract:update(dt)
    self:detectAnimal()
end
