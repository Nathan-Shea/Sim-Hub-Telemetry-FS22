---Placement callback





local VehiclePlacementCallback_mt = Class(VehiclePlacementCallback)


---Create instance of class
function VehiclePlacementCallback.new()
    local instance = {}
    setmetatable(instance, VehiclePlacementCallback_mt)

    return instance
end


---Raycast callback
-- @param integer transformId id raycasted object
-- @param float x x raycast position
-- @param float y y raycast position
-- @param float z z raycast position
-- @param float distance distance to raycast position
-- @return boolean continue continue
function VehiclePlacementCallback:callback(transformName, x, y, z, distance)
    self.raycastHitName = transformName
    self.x = x
    self.y = y
    self.z = z
    self.distance = distance

    return true
end
