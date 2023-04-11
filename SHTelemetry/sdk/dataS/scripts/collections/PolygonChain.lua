---A polygon chain datastructure









local PolygonChain_mt = Class(PolygonChain)


---Creating data grid
-- @param integer numRows number of rows
-- @param integer numColumns number of columns
-- @param table customMt custom metatable
-- @return table instance instance of object
function PolygonChain.new(customMt)
    local self = {}
    setmetatable(self, customMt or PolygonChain_mt)

    self.controlNodes = {}

    return self
end


---Deletes data grid
function PolygonChain:delete()
    self.controlNodes = nil
end
