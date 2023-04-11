---Specialization for placeables













---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PlaceableIncomePerHour.prerequisitesPresent(specializations)
    return true
end


---
function PlaceableIncomePerHour.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "getIncomePerHourFactor", PlaceableIncomePerHour.getIncomePerHourFactor)
end


---
function PlaceableIncomePerHour.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "getNeedHourChanged", PlaceableIncomePerHour.getNeedHourChanged)
end


---
function PlaceableIncomePerHour.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableIncomePerHour)
    SpecializationUtil.registerEventListener(placeableType, "onHourChanged", PlaceableIncomePerHour)
end


---
function PlaceableIncomePerHour.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("IncomePerHour")
    schema:register(XMLValueType.FLOAT, basePath .. ".incomePerHour", "Income per hour")
    schema:setXMLSpecializationType()
end


---
function PlaceableIncomePerHour.initSpecialization()
    g_storeManager:addSpecType("incomePerHour", "shopListAttributeIconIncomePerHour", PlaceableIncomePerHour.loadSpecValueIncomePerHour, PlaceableIncomePerHour.getSpecValueIncomePerHour, "placeable")
end


---Called on loading
-- @param table savegame savegame
function PlaceableIncomePerHour:onLoad(savegame)
    local spec = self.spec_incomePerHour
    local xmlFile = self.xmlFile

    spec.incomePerHour = xmlFile:getValue("placeable.incomePerHour", 0)
    spec.incomePerHourFactor = 1
end


---
function PlaceableIncomePerHour:getNeedHourChanged(superFunc)
    return true
end


---Called if hour changed
function PlaceableIncomePerHour:onHourChanged()
    if self.isServer then
        local ownerFarmId = self:getOwnerFarmId()
        if ownerFarmId ~= FarmlandManager.NO_OWNER_FARM_ID then
            local spec = self.spec_incomePerHour
            local incomePerHour = spec.incomePerHour * self:getIncomePerHourFactor() * g_currentMission.environment.timeAdjustment
            if incomePerHour ~= 0 then
                g_currentMission:addMoney(incomePerHour, ownerFarmId, MoneyType.PROPERTY_INCOME, true)
            end
        end
    end
end


---
function PlaceableIncomePerHour:getIncomePerHourFactor()
    return 1
end


---Loads capacity spec value
-- @param integer xmlFile id of xml object
-- @param string customEnvironment custom environment
-- @return table capacityAndUnit capacity and unit
function PlaceableIncomePerHour.loadSpecValueIncomePerHour(xmlFile, customEnvironment, baseDir)
    if not xmlFile:hasProperty("placeable.incomePerHour") then
        return nil
    end

    local incomePerHour = xmlFile:getValue("placeable.incomePerHour", 0)

    return incomePerHour
end


---Returns value of income per hour
-- @param table storeItem store item
-- @param table realItem real item
-- @return integer incomePerHour income per hour
function PlaceableIncomePerHour.getSpecValueIncomePerHour(storeItem, realItem)
    if storeItem.specs.incomePerHour == nil then
        return nil
    end

    local perMonth = storeItem.specs.incomePerHour * 24-- 24 hours in an un-adjusted month
    return string.format("%s / %s", g_i18n:formatMoney(perMonth), g_i18n:getText("ui_month"))
end
