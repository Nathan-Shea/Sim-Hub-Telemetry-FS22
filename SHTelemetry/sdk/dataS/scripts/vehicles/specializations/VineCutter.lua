---Specialization for vine cutters













---
function VineCutter.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("VineCutter")
    schema:register(XMLValueType.STRING, "vehicle.vineCutter#fruitType", "Fruit type")
    schema:setXMLSpecializationType()
end


---
function VineCutter.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(VineDetector, specializations)
end


---
function VineCutter.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getCombine", VineCutter.getCombine)
    SpecializationUtil.registerFunction(vehicleType, "harvestCallback", VineCutter.harvestCallback)
end


---
function VineCutter.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit", VineCutter.doCheckSpeedLimit)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanStartVineDetection", VineCutter.getCanStartVineDetection)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsValidVinePlaceable", VineCutter.getIsValidVinePlaceable)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "handleVinePlaceable", VineCutter.handleVinePlaceable)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "clearCurrentVinePlaceable", VineCutter.clearCurrentVinePlaceable)
end


---
function VineCutter.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", VineCutter)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", VineCutter)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", VineCutter)
    SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", VineCutter)
end


---
function VineCutter:onLoad(savegame)
    local spec = self.spec_vineCutter

    local fruitTypeName = self.xmlFile:getValue("vehicle.vineCutter#fruitType")
    local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitTypeName)
    if fruitType ~= nil then
        spec.inputFruitTypeIndex = fruitType.index
    else
        spec.inputFruitTypeIndex = FruitType.GRAPE
    end

    spec.outputFillTypeIndex = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(spec.inputFruitTypeIndex)

    spec.showFarmlandNotOwnedWarning = false
    spec.warningYouDontHaveAccessToThisLand = g_i18n:getText("warning_youDontHaveAccessToThisLand")
end









---Called on draw
-- @param boolean isActiveForInput true if vehicle is active for input
-- @param boolean isSelected true if vehicle is selected
function VineCutter:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_vineCutter
    if spec.showFarmlandNotOwnedWarning then
        g_currentMission:showBlinkingWarning(spec.warningYouDontHaveAccessToThisLand)
    end
end
