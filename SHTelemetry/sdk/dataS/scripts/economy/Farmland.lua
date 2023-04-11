---This class wraps all farmland data

















local Farmland_mt = Class(Farmland)


---Create field definition object
-- @return table instance Instance of object
function Farmland.new(customMt)
    local self = setmetatable({}, customMt or Farmland_mt)

    self.isOwned = false
    self.xWorldPos = 0
    self.zWorldPos = 0

    return self
end


---Load farmland data from xml
-- @param integer xmlFile handle of xml file
-- @param string key current xml element key
-- @return boolean true if loading was successful else false
function Farmland:load(xmlFile, key)
    self.id = getXMLInt(xmlFile, key.."#id")

    if self.id == nil or self.id == 0 then
        print("Error: Invalid farmland id '"..tostring(self.id).."'!")
        return false
    end

    self.name = Utils.getNoNil(getXMLString(xmlFile, key.."#name"), "")
    self.areaInHa = Utils.getNoNil(getXMLFloat(xmlFile, key.."#areaInHa"), 2.5)

    self.fixedPrice = getXMLFloat(xmlFile, key.."#price")
    if self.fixedPrice == nil then
        self.priceFactor = Utils.getNoNil(getXMLFloat(xmlFile, key.."#priceScale"), 1)
    end
    self.price = self.fixedPrice or 1

    self:updatePrice()

    self.npcIndex = g_npcManager:getRandomIndex()

    local npcByIndex = g_npcManager:getNPCByIndex(getXMLInt(xmlFile, key.."#npcIndex"))
    if npcByIndex ~= nil then
        self.npcIndex = npcByIndex.index
    else
        -- Names are used with custom NPC sets
        local npcByName = g_npcManager:getNPCByName(getXMLString(xmlFile, key.."#npcName"))
        if npcByName ~= nil then
            self.npcIndex = npcByName.index
        end
    end

    self.isOwned = false
    self.showOnFarmlandsScreen = Utils.getNoNil(getXMLBool(xmlFile, key.."#showOnFarmlandsScreen"), true)
    self.defaultFarmProperty = Utils.getNoNil(getXMLBool(xmlFile, key.."#defaultFarmProperty"), false)

    return true
end


---Delete field definition object
function Farmland:delete()
end


---Set farmland area indicator world position
-- @param float xWorldPos farmland indicator x world position
-- @param float zWorldPos farmland size in ha
function Farmland:setFarmlandIndicatorPosition(xWorldPos, zWorldPos)
    self.xWorldPos, self.zWorldPos = xWorldPos, zWorldPos
end


---Set farmland area
-- @param float areaInHa farmland size in ha
function Farmland:setArea(areaInHa)
    self.areaInHa = areaInHa
    if self.fixedPrice == nil then
        self:updatePrice()
    end
end
