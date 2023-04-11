---Class for shop triggers to open shop gui






local ShopTrigger_mt = Class(ShopTrigger)


---On create shop trigger
-- @param integer id trigger node id
function ShopTrigger:onCreate(id)
    g_currentMission:addNonUpdateable(ShopTrigger.new(id))
end


---Creating shop trigger object
-- @param integer node trigger node id
-- @return table instance instance of object
function ShopTrigger.new(node)
    local self = setmetatable({}, ShopTrigger_mt)

    if g_currentMission:getIsClient() then
        self.triggerId = node

        if not CollisionFlag.getHasFlagSet(node, CollisionFlag.TRIGGER_PLAYER) then
            Logging.warning("Missing collision mask bit '%d'. Please add this bit to shop trigger node '%s'", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER), I3DUtil.getNodePath(node))
        end

        addTrigger(node, "triggerCallback", self)
    end

    self.shopSymbol = getChildAt(node, 0)
    self.shopPlayerSpawn = getChildAt(node, 1)
    self.isEnabled = true

    g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, self.playerFarmChanged, self)
    g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.SHOW_TRIGGER_MARKER], self.onTriggerVisbilityChanged, self)

    self:updateIconVisibility()

    self.activatable = ShopTriggerActivatable.new(self)

    return self
end


---Deleting shop trigger
function ShopTrigger:delete()
    g_messageCenter:unsubscribeAll(self)
    if self.triggerId ~= nil then
        removeTrigger(self.triggerId)
    end
    self.shopSymbol = nil
    g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
end


---Called on activate object
function ShopTrigger:openShop()
    g_gui:changeScreen(nil, ShopMenu)

    local x,y,z = getWorldTranslation(self.shopPlayerSpawn)
    local dx, _, dz = localDirectionToWorld(self.shopPlayerSpawn, 0, 0, -1)
    g_currentMission.player:moveToAbsolute(x,y,z)
    g_currentMission.player.rotY = MathUtil.getYRotationFromDirection(dx, dz)
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherId id of actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
function ShopTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
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
function ShopTrigger:updateIconVisibility()
    if self.shopSymbol ~= nil then
        local isAvailable = self.isEnabled and g_currentMission.missionInfo:isa(FSCareerMissionInfo)
        local farmId = g_currentMission:getFarmId()
        local visibleForFarm = farmId ~= FarmManager.SPECTATOR_FARM_ID
        local settingVisible = g_gameSettings:getValue(GameSettings.SETTING.SHOW_TRIGGER_MARKER)

        setVisibility(self.shopSymbol, isAvailable and visibleForFarm and settingVisible)
    end
end


---
function ShopTrigger:playerFarmChanged(player)
    if player == g_currentMission.player then
        self:updateIconVisibility()
    end
end


---
function ShopTrigger:onTriggerVisbilityChanged()
    self:updateIconVisibility()
end
