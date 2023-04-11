---This class wraps all Field data










local Field_mt = Class(Field)


---Create ai field definition object
-- @return table instance Instance of object
function Field.new(customMt)
    local self = {}
    setmetatable(self, customMt or Field_mt)

    self.fieldId = 0
    self.posX = 0
    self.posZ = 0
    self.rootNode = nil
    self.name = nil
    self.mapHotspot = nil
    self.fieldMissionAllowed = true
    self.fieldGrassMission = false
    self.fieldAngle = 0.0
    self.fieldDimensions = nil
    self.fieldArea = 1.0
    self.getFieldStatusPartitions = {}
    self.setFieldStatusPartitions = {}
    self.maxFieldStatusPartitions = {}
    self.isAIActive = true
    self.fruitType = nil -- current fruit in the field, as seen by FJM
    self.lastCheckedTime = nil
    self.plannedFruit = 0

    self.currentMission = nil

    return self
end


---Load Field data from node
-- @param integer id ai field node id
-- @return boolean true if loading was successful else false
function Field:load(id)
    self.rootNode = id
    local name = getUserAttribute(id, "name")
    if name ~= nil then
        self.name = g_i18n:convertText(name, g_currentMission.loadingMapModName)
    end

    self.fieldMissionAllowed = Utils.getNoNil(getUserAttribute(id, "fieldMissionAllowed"), true)
    self.fieldGrassMission = Utils.getNoNil(getUserAttribute(id, "fieldGrassMission"), false)

    local fieldDimensions = I3DUtil.indexToObject(id, getUserAttribute(id, "fieldDimensionIndex"))
    if fieldDimensions == nil then
       print("Warning: No fieldDimensionIndex defined for Field '"..getName(id).."'!")
       return false
    end
    local angleRad = math.rad(Utils.getNoNil(tonumber(getUserAttribute(id, "fieldAngle")), 0))

    self.fieldAngle = FSDensityMapUtil.convertToDensityMapAngle(angleRad, g_currentMission.fieldGroundSystem:getGroundAngleMaxValue())
    self.fieldDimensions = fieldDimensions

    FieldUtil.updateFieldPartitions(self, self.getFieldStatusPartitions, 900)
    FieldUtil.updateFieldPartitions(self, self.setFieldStatusPartitions, 400)
    FieldUtil.updateFieldPartitions(self, self.maxFieldStatusPartitions, 10000000)

    self.posX, self.posZ = FieldUtil.getCenterOfField(self)

    self.nameIndicator = I3DUtil.indexToObject(id, getUserAttribute(id, "nameIndicatorIndex")) -- this is where the field number appears on the ingamemap
    if self.nameIndicator ~= nil then
        local x, _, z = getWorldTranslation(self.nameIndicator)
        self.posX, self.posZ = x, z
    end

    self.farmland = nil

    return true
end


---Delete field definition object
function Field:delete()
    if self.mapHotspot == nil then
        g_currentMission:removeMapHotspot(self.mapHotspot)
        self.mapHotspot:delete()
        self.mapHotspot = nil
    end
end
