---class to handle the animal load triggers










local AnimalLoadingTrigger_mt = Class(AnimalLoadingTrigger)




---Callback of scenegraph object
-- @param integer id nodeid that the trigger is created from
function AnimalLoadingTrigger:onCreate(id)
    local trigger = AnimalLoadingTrigger.new(g_server ~= nil, g_client ~= nil)
    if trigger ~= nil then
        if trigger:load(id) then
            g_currentMission:addNonUpdateable(trigger)
        else
            trigger:delete()
        end
    end
end


---Creates an instance of the class
-- @param bool isServer 
-- @param bool isClient 
-- @return table self instance
function AnimalLoadingTrigger.new(isServer, isClient)
    local self = Object.new(isServer, isClient, AnimalLoadingTrigger_mt)

    self.customEnvironment = g_currentMission.loadingMapModName
    self.isDealer = false
    self.triggerNode = nil
    self.title = g_i18n:getText("ui_farm")

    self.animals = nil

    self.activatable = AnimalLoadingTriggerActivatable.new(self)
    self.isPlayerInRange = false

    self.isEnabled = false

    self.loadingVehicle = nil
    self.activatedTarget = nil

    return self
end


---Loads information from scenegraph node.
-- @param integer id nodeid that the trigger is created from
function AnimalLoadingTrigger:load(node, husbandry)
    self.husbandry = husbandry
    self.isDealer = Utils.getNoNil(getUserAttribute(node, "isDealer"), false)

    if self.isDealer then
        local animalTypesString = getUserAttribute(node, "animalTypes")
        if animalTypesString ~= nil then
            local animalTypes = animalTypesString:split(" ")
            for _, animalTypeStr in pairs(animalTypes) do
                local animalTypeIndex = g_currentMission.animalSystem:getTypeIndexByName(animalTypeStr)
                if animalTypeIndex ~= nil then
                    if self.animalTypes == nil then
                        self.animalTypes = {}
                    end

                    table.insert(self.animalTypes, animalTypeIndex)
                else
                    Logging.warning("Invalid animal type '%s' for animalLoadingTrigger '%s'!", animalTypeStr, getName(node))
                end
            end
        end
    end

    self.triggerNode = node
    addTrigger(self.triggerNode, "triggerCallback", self)

    self.title = g_i18n:getText(Utils.getNoNil(getUserAttribute(node, "title"), "ui_farm"), self.customEnvironment)
    self.isEnabled = true

    return true
end


---Deletes instance
function AnimalLoadingTrigger:delete()
    g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)

    if self.triggerNode ~= nil then
        removeTrigger(self.triggerNode)
        self.triggerNode = nil
    end

    self.husbandry = nil
end


---Callback when trigger changes state
-- @param integer triggerId 
-- @param integer otherId 
-- @param bool onEnter 
-- @param bool onLeave 
-- @param bool onStay 
function AnimalLoadingTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if self.isEnabled and (onEnter or onLeave) then
        local vehicle = g_currentMission.nodeToObject[otherId]
        if vehicle ~= nil and vehicle.getSupportsAnimalType ~= nil then
            if onEnter then
                self:setLoadingTrailer(vehicle)
            elseif onLeave then
                if vehicle == self.loadingVehicle then
                    self:setLoadingTrailer(nil)
                end
                if vehicle == self.activatedTarget then
                    -- close dialog!
                    g_animalScreen:onVehicleLeftTrigger()
                end
            end

            if GS_IS_MOBILE_VERSION then
                if onEnter and self.activatable:getIsActivatable() then
                    self:openAnimalMenu()
                    local rootVehicle = vehicle.rootVehicle
                    if rootVehicle.brakeToStop ~= nil then
                        rootVehicle:brakeToStop()
                    end
                end
            end
        elseif g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
            if onEnter then
                self.isPlayerInRange = true

                if GS_IS_MOBILE_VERSION then
                    self:openAnimalMenu()
                end
            else
                self.isPlayerInRange = false
            end
            self:updateActivatableObject()
        end
    end
end


---Adds or removes the trigger as an activable object to the mission
function AnimalLoadingTrigger:updateActivatableObject()
    if self.loadingVehicle ~= nil or self.isPlayerInRange then
        g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
    elseif self.loadingVehicle == nil and not self.isPlayerInRange then
        g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
    end
end


---Sets the loading trailer
-- @param table loadingVehicle 
function AnimalLoadingTrigger:setLoadingTrailer(loadingVehicle)
    if self.loadingVehicle ~= nil and self.loadingVehicle.setLoadingTrigger ~= nil then
        self.loadingVehicle:setLoadingTrigger(nil)
    end

    self.loadingVehicle = loadingVehicle

    if self.loadingVehicle ~= nil and self.loadingVehicle.setLoadingTrigger ~= nil then
        self.loadingVehicle:setLoadingTrigger(self)
    end

    self:updateActivatableObject()
end


---
function AnimalLoadingTrigger:showAnimalScreen(husbandry)
    if husbandry == nil and self.loadingVehicle == nil then
        g_gui:showInfoDialog({text=g_i18n:getText("shop_messageNoHusbandries")})
        return
    end

    local controller
    if husbandry ~= nil and self.loadingVehicle == nil then
        controller = AnimalScreenDealerFarm.new(husbandry)
    elseif husbandry == nil and self.loadingVehicle ~= nil then
        controller = AnimalScreenDealerTrailer.new(self.loadingVehicle)
    else
        controller = AnimalScreenTrailerFarm.new(husbandry, self.loadingVehicle)
    end

    if controller ~= nil then
        controller:init()
        g_animalScreen:setController(controller)
        g_gui:showGui("AnimalScreen")
    end
end


---
function AnimalLoadingTrigger:onSelectedHusbandry(husbandry)
    if husbandry ~= nil then
        self:showAnimalScreen(husbandry)
    else
        self:updateActivatableObject()
    end
end


---
function AnimalLoadingTrigger:getAnimals()
    return self.animalTypes
end


---
function AnimalLoadingTrigger:openAnimalMenu()
    local husbandry = self.husbandry
    if self.isDealer and self.loadingVehicle == nil then
        local husbandries = g_currentMission.husbandrySystem:getPlaceablesByFarm()
        if #husbandries > 1 then
            g_gui:showAnimalDialog({title=g_i18n:getText("category_animalpens"), husbandries=husbandries, callback=self.onSelectedHusbandry, target=self})
            return
        elseif #husbandries == 1 then
            husbandry = husbandries[1]
        end
    end

    self:showAnimalScreen(husbandry)
    self.activatedTarget = self.loadingVehicle
end
