












local YieldMap_mt = Class(YieldMap, ValueMap)

























































































































































































































































































---
function YieldMap:setMapFrame(mapFrame)
    self.mapFrame = mapFrame

    self:updateResetButton()
end


---
function YieldMap:getIsResetButtonActive()
    return (self.selectedFarmland ~= nil and self.selectedFieldArea ~= nil and self.selectedFieldArea > 0) and self.yieldMapSelected
end


---
function YieldMap:updateResetButton()
    self.mapFrame:updateAdditionalFunctionButton()
end
