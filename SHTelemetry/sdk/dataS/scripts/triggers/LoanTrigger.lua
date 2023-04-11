---Class for loan triggers






local LoanTrigger_mt = Class(LoanTrigger)


---On create loan trigger
-- @param Integer id id of trigger node
function LoanTrigger:onCreate(id)
    g_currentMission:addNonUpdateable(LoanTrigger.new(id))
end


---Create loan trigger object
-- @param Integer name id of trigger node
-- @return table instance instance
function LoanTrigger.new(name)
    local self = {}
    setmetatable(self, LoanTrigger_mt)

    if g_currentMission:getIsClient() then
        self.triggerId = name
        addTrigger(name, "triggerCallback", self)
    end

    self.loanSymbol = getChildAt(name, 0)

    self.activatable = LoanTriggerActivatable.new(self)

    self.isEnabled = true

    g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, self.playerFarmChanged, self)

    self:updateIconVisibility()

    return self
end


---Delete loan trigger
function LoanTrigger:delete()
    g_messageCenter:unsubscribeAll(self)

    if self.triggerId ~= nil then
        removeTrigger(self.triggerId)
    end
    self.loanSymbol = nil
    g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
end


---Called on activate object
function LoanTrigger:openFinanceMenu()
    g_gui:showGui("InGameMenu")
    g_messageCenter:publish(MessageType.GUI_INGAME_OPEN_FINANCES_SCREEN)
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherId id of actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
function LoanTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if self.isEnabled and g_currentMission.missionInfo:isa(FSCareerMissionInfo) then
        if onEnter or onLeave then
            if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
                if onEnter then
                    g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
                else
                    g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
                end
            end
        end
    end
end


---Turn the icon on or off depending on the current game and the players farm
function LoanTrigger:updateIconVisibility()
    if self.loanSymbol ~= nil then
        local isAvailable = self.isEnabled and g_currentMission.missionInfo:isa(FSCareerMissionInfo)
        local farmId = g_currentMission:getFarmId()
        local visibleForFarm = farmId ~= FarmManager.SPECTATOR_FARM_ID

        setVisibility(self.loanSymbol, isAvailable and visibleForFarm)
    end
end


---
function LoanTrigger:playerFarmChanged(player)
    if player == g_currentMission.player then
        self:updateIconVisibility()
    end
end
